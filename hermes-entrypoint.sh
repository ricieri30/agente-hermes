#!/bin/sh

echo "=== Hermes Agent Entrypoint FINAL ==="
echo "=== Usuario: $(whoami) | HOME: $HOME ==="

# Carrega .env do dashboard
if [ -f /opt/hermes_project/.env ]; then
  echo "=== Carregando .env ==="
  set -a
  . /opt/hermes_project/.env
  set +a
fi

# Adiciona o venv do hermes ao PATH (caminho descoberto pelos logs)
export PATH="/opt/hermes/.venv/bin:$PATH"

# Diretorio de config gravavel
HERMES_DIR="/tmp/.hermes"
mkdir -p "$HERMES_DIR"
echo "=== Config dir: $HERMES_DIR ==="

# Escreve .env interno
printenv | grep -E '^(GROQ_API_KEY|GEMINI_API_KEY|OPENROUTER_API_KEY|NOUS_API_KEY|ANTHROPIC_API_KEY|HERMES_MODEL|TELEGRAM_TOKEN|TELEGRAM_ALLOWED_USERS|DISCORD_TOKEN|TERMINAL_TIMEOUT|TERMINAL_LIFETIME_SECONDS|BROWSER_SESSION_TIMEOUT|BROWSER_INACTIVITY_TIMEOUT|WEB_TOOLS_DEBUG|VISION_TOOLS_DEBUG)=' > "$HERMES_DIR/.env"
cat "$HERMES_DIR/.env" | sed 's/=.*/=***/'
echo "=============================="

echo "=== INICIANDO: hermes-agent $@ ==="
exec /opt/hermes/.venv/bin/hermes-agent "$@"
