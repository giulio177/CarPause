#!/usr/bin/env bash
# =============================================================================
# update_infotainment.sh - One-Click Git Updater for Mito Automotive Infotainment
# Pulls latest commits from GitHub, updates Python dependencies, and exits.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

echo "=== Verifica aggiornamenti software da GitHub ==="

# 1. Verifica connettività internet
if ! ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1 && ! ping -c 1 -W 2 github.com >/dev/null 2>&1; then
    echo "ERRORE: Connessione internet non disponibile. Connettiti al Wi-Fi o Hotspot."
    exit 2
fi

# 2. Controllo se è un repository Git
if [ ! -d ".git" ]; then
    echo "ERRORE: Directory non configurata come repository Git valido."
    exit 3
fi

# 3. Rilevamento branch attivo
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")"
echo ">> Branch attivo: $BRANCH"

# 4. Aggiornamento dal remote Git
echo ">> Recupero modifiche dal repository remoto..."
git fetch origin "$BRANCH" --quiet

LOCAL_HASH="$(git rev-parse HEAD)"
REMOTE_HASH="$(git rev-parse "origin/$BRANCH")"

if [ "$LOCAL_HASH" = "$REMOTE_HASH" ]; then
    echo ">> Il software è già aggiornato all'ultima versione ($LOCAL_HASH)."
    exit 0
fi

echo ">> Nuova versione trovata! Aggiornamento da $LOCAL_HASH a $REMOTE_HASH..."
git reset --hard "origin/$BRANCH"

# 5. Aggiornamento dipendenze Python nel virtualenv se presente
if [ -f "venv/bin/activate" ] && [ -f "requirements.txt" ]; then
    echo ">> Verifica ed installazione dipendenze Python..."
    source venv/bin/activate
    pip install -q -r requirements.txt
fi

# 6. Assicura permessi di esecuzione su tutti gli script
chmod +x scripts/*.sh 2>/dev/null || true

echo ">> Aggiornamento completato con successo alla versione $REMOTE_HASH."
exit 0
