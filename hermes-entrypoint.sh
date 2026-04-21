#!/bin/sh

echo "=== Hermes Agent Entrypoint ==="

# Carrega .env do dashboard se existir
if [ -f /opt/hermes_project/.env ]; then
  echo "=== Carregando .env do dashboard ==="
  set -a
  . /opt/hermes_project/.env
  set +a
fi

# Garante diretório de config com caminho absoluto
mkdir -p /root/.hermes

# Escreve .env interno do hermes
printenv | grep -E '^(GROQ_API_KEY|GEMINI_API_KEY|OPENROUTER_API_KEY|NOUS_API_KEY|ANTHROPIC_API_KEY|HERMES_MODEL|TELEGRAM_TOKEN|TELEGRAM_ALLOWED_USERS|DISCORD_TOKEN|TERMINAL_TIMEOUT|TERMINAL_LIFETIME_SECONDS|BROWSER_SESSION_TIMEOUT|BROWSER_INACTIVITY_TIMEOUT|WEB_TOOLS_DEBUG|VISION_TOOLS_DEBUG|MOA_TOOLS_DEBUG)=' > /root/.hermes/.env

echo "=== /root/.hermes/.env criado ==="
cat /root/.hermes/.env | sed 's/=.*/=***/'
echo "=============================="

# Detecta o binário correto do hermes na imagem
HERMES_BIN=""

if command -v hermes-agent > /dev/null 2>&1; then
  HERMES_BIN="hermes-agent"
  echo "=== Binário encontrado: hermes-agent ==="
elif command -v hermes > /dev/null 2>&1; then
  HERMES_BIN="hermes"
  echo "=== Binário encontrado: hermes ==="
elif python3 -c "import hermes" > /dev/null 2>&1; then
  HERMES_BIN="python3 -m hermes"
  echo "=== Binário encontrado: python3 -m hermes ==="
else
  echo "=== ERRO: Nenhum binário hermes encontrado. Listando /usr/local/bin: ==="
  ls /usr/local/bin/ | grep -i hermes || echo "(nenhum encontrado)"
  echo "=== Listando site-packages: ==="
  python3 -c "import sys; print('\n'.join(sys.path))" 2>/dev/null
  exit 1
fi

echo "=== Iniciando: $HERMES_BIN $@ ==="
exec $HERMES_BIN "$@"
