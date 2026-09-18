#!/usr/bin/env python3
"""
touch_killer.py - Emergency Touch Watchdog for Automotive Infotainment.
Continuously monitors all /dev/input/event* touch devices.
If the driver/user presses and holds the screen continuously for 5 seconds,
it immediately executes 'killall -9 uxplay' and 'pkill -9 -f uxplay' to force-kill UxPlay
and return the display to the Mito Infotainment system.
"""

import os
import sys
import time
import glob
import select
import logging
import subprocess

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] [TouchKiller] %(message)s"
)
logger = logging.getLogger("TouchKiller")

try:
    import evdev
except ImportError:
    # If the active virtualenv doesn't have evdev, try re-executing with system python3
    if sys.executable != "/usr/bin/python3" and os.path.exists("/usr/bin/python3"):
        try:
            os.execv("/usr/bin/python3", ["/usr/bin/python3"] + sys.argv)
        except Exception:
            pass
    logger.error("Python 'evdev' module not found! Please run: pip install evdev")
    sys.exit(1)

HOLD_THRESHOLD_SEC = 5.0
POLL_INTERVAL_SEC = 0.05


def get_touch_devices():
    """Finds all input event devices capable of touch or mouse clicks."""
    devices = []
    for path in glob.glob("/dev/input/event*"):
        try:
            if not os.access(path, os.R_OK):
                continue
            dev = evdev.InputDevice(path)
            caps = dev.capabilities()
            
            # Extract capabilities keys and absolute axes
            key_caps = caps.get(evdev.ecodes.EV_KEY, [])
            raw_abs = caps.get(evdev.ecodes.EV_ABS, [])
            abs_caps = [c[0] if isinstance(c, tuple) else c for c in raw_abs]

            # Match touchscreens, touch panels, and pointers
            is_touch = (
                evdev.ecodes.BTN_TOUCH in key_caps
                or evdev.ecodes.ABS_MT_POSITION_X in abs_caps
                or evdev.ecodes.ABS_MT_TRACKING_ID in abs_caps
                or evdev.ecodes.BTN_LEFT in key_caps
            )
            if is_touch:
                devices.append(dev)
        except Exception:
            continue
    return devices


def kill_uxplay():
    """Forcefully kills any running uxplay instances."""
    logger.warning(">>> 5-SECOND TOUCH HOLD DETECTED! FORCE KILLING UXPLAY (killall -9 uxplay)! <<<")
    try:
        subprocess.run(["killall", "-9", "uxplay"], capture_output=True)
    except Exception:
        pass
    try:
        subprocess.run(["pkill", "-9", "-f", "uxplay"], capture_output=True)
    except Exception:
        pass
    try:
        subprocess.run(["killall", "-9", "gst-launch-1.0"], capture_output=True)
    except Exception:
        pass


def main():
    logger.info("Starting 5-second Emergency Touch Watchdog...")

    try:
        import evdev
    except ImportError:
        logger.error("evdev is required for touch_killer.py. Exiting.")
        sys.exit(1)

    devices = []
    touch_active = False
    touch_start_time = 0.0
    triggered_for_current_hold = False

    while True:
        if not devices:
            devices = get_touch_devices()
            if devices:
                logger.info("Monitoring %d touch device(s): %s", len(devices), [d.path for d in devices])
            else:
                time.sleep(2.0)
                continue

        try:
            # Poll open file descriptors with timeout
            r, _, _ = select.select(devices, [], [], POLL_INTERVAL_SEC)

            now = time.time()

            if r:
                for dev in r:
                    try:
                        for event in dev.read():
                            # Touch down detection
                            if event.type == evdev.ecodes.EV_KEY:
                                if event.code in (evdev.ecodes.BTN_TOUCH, evdev.ecodes.BTN_LEFT):
                                    if event.value == 1:
                                        if not touch_active:
                                            touch_active = True
                                            touch_start_time = now
                                            triggered_for_current_hold = False
                                            logger.debug("Touch DOWN at %.2f", touch_start_time)
                                    elif event.value == 0:
                                        touch_active = False
                                        triggered_for_current_hold = False
                                        logger.debug("Touch UP")

                            elif event.type == evdev.ecodes.EV_ABS:
                                if event.code in (evdev.ecodes.ABS_PRESSURE, evdev.ecodes.ABS_MT_PRESSURE):
                                    if event.value > 0:
                                        if not touch_active:
                                            touch_active = True
                                            touch_start_time = now
                                            triggered_for_current_hold = False
                                    else:
                                        touch_active = False
                                        triggered_for_current_hold = False

                                elif event.code in (evdev.ecodes.ABS_MT_TRACKING_ID,):
                                    if event.value >= 0:
                                        if not touch_active:
                                            touch_active = True
                                            touch_start_time = now
                                            triggered_for_current_hold = False
                                    else:
                                        touch_active = False
                                        triggered_for_current_hold = False

                    except OSError:
                        # Device disconnected
                        logger.warning("Device error or disconnect on %s", dev.path)
                        devices = []
                        break

            # Check hold duration
            if touch_active and not triggered_for_current_hold:
                elapsed = now - touch_start_time
                if elapsed >= HOLD_THRESHOLD_SEC:
                    triggered_for_current_hold = True
                    kill_uxplay()

        except Exception as exc:
            logger.debug("Watchdog loop exception: %s", exc)
            time.sleep(1.0)
            devices = []


if __name__ == "__main__":
    main()
