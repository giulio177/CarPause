"""
Thread pool and asynchronous dispatching utility for PyQt6.
Ensures zero blocking operations on the Qt GUI main thread.
"""

from typing import Callable, Any, Optional
from PyQt6.QtCore import QObject, QRunnable, QThreadPool, pyqtSignal, pyqtSlot


class WorkerSignals(QObject):
    """Signals for a background worker runnable."""
    result = pyqtSignal(object)
    error = pyqtSignal(Exception)
    finished = pyqtSignal()


class TaskRunnable(QRunnable):
    """Encapsulates a synchronous callable to run on QThreadPool."""

    def __init__(self, fn: Callable, *args: Any, **kwargs: Any):
        super().__init__()
        self.fn = fn
        self.args = args
        self.kwargs = kwargs
        self.signals = WorkerSignals()
        self.setAutoDelete(True)

    @pyqtSlot()
    def run(self) -> None:
        try:
            res = self.fn(*self.args, **self.kwargs)
            try:
                self.signals.result.emit(res)
            except RuntimeError:
                pass
        except Exception as exc:
            try:
                self.signals.error.emit(exc)
            except RuntimeError:
                pass
        finally:
            try:
                self.signals.finished.emit()
            except RuntimeError:
                pass


class AsyncRunner:
    """Manages thread pool execution and dispatches callbacks to the Qt event loop."""

    def __init__(self, max_threads: int = 4):
        self._pool = QThreadPool.globalInstance()
        self._pool.setMaxThreadCount(max_threads)

    def run_async(
        self,
        fn: Callable,
        *args: Any,
        on_result: Optional[Callable[[Any], None]] = None,
        on_error: Optional[Callable[[Exception], None]] = None,
        on_finished: Optional[Callable[[], None]] = None,
        **kwargs: Any,
    ) -> TaskRunnable:
        """Executes fn(*args, **kwargs) in a worker thread without blocking the GUI."""
        worker = TaskRunnable(fn, *args, **kwargs)
        if on_result:
            worker.signals.result.connect(on_result)
        if on_error:
            worker.signals.error.connect(on_error)
        if on_finished:
            worker.signals.finished.connect(on_finished)

        self._pool.start(worker)
        return worker
