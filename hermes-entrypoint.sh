#!/bin/sh
# Hermes Entrypoint — FINAL — delega toda lógica ao hermes-setup.py
echo "=== Hermes Entrypoint — $(date) ==="
echo "=== Usuario: $(whoami) | HOME: $HOME ==="

HERMES_BIN="/opt/hermes/.venv/bin/hermes-agent"
HERMES_PY="/opt/hermes/.venv/bin/python3"
SETUP_SCRIPT="/usr/local/bin/hermes-setup.py"

# Roda o auto-setup (valida, configura, testa)
$HERMES_PY $SETUP_SCRIPT
SETUP_EXIT=$?

if [ $SETUP_EXIT -ne 0 ]; then
  echo "[ERRO] Setup falhou (código $SETUP_EXIT). Verifique o .env e reinicie."
  echo "[ERRO] Aguardando 30s antes de tentar novamente..."
  sleep 30
  exit $SETUP_EXIT
fi

# Inicia o gateway
echo "=== Executando: $HERMES_BIN gateway run ==="
exec $HERMES_BIN gateway run
