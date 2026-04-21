#!/bin/sh

echo "=== Hermes Agent Entrypoint FINAL v4 ==="
echo "=== Usuario: $(whoami) | HOME: $HOME ==="

# Carrega .env do dashboard
if [ -f /opt/hermes_project/.env ]; then
  echo "=== Carregando .env ==="
  set -a
  . /opt/hermes_project/.env
  set +a
fi

# Diretorio de config
HERMES_DIR="/tmp/.hermes"
mkdir -p "$HERMES_DIR"

# Escreve .env interno
printenv | grep -E '^(GROQ_API_KEY|GEMINI_API_KEY|OPENROUTER_API_KEY|NOUS_API_KEY|ANTHROPIC_API_KEY|HERMES_MODEL|TELEGRAM_TOKEN|TELEGRAM_ALLOWED_USERS|DISCORD_TOKEN|TERMINAL_TIMEOUT|TERMINAL_LIFETIME_SECONDS|BROWSER_SESSION_TIMEOUT|BROWSER_INACTIVITY_TIMEOUT|WEB_TOOLS_DEBUG|VISION_TOOLS_DEBUG)=' > "$HERMES_DIR/.env"

# Garante que o modelo padrao é Groq se nao estiver definido
MODEL="${HERMES_MODEL:-groq:llama-3.3-70b-versatile}"

echo "=== Modelo selecionado: $MODEL ==="
echo "=== GROQ_API_KEY presente: $([ -n "$GROQ_API_KEY" ] && echo SIM || echo NAO) ==="
echo "=== TELEGRAM_TOKEN presente: $([ -n "$TELEGRAM_TOKEN" ] && echo SIM || echo NAO) ==="

# Escreve config.yaml para o hermes-agent
cat > "$HERMES_DIR/config.yaml" << YAML
model: "$MODEL"
data_dir: "/opt/data"
YAML

echo "=== config.yaml criado ==="

# Limpa GEMINI para evitar conflito se nao for o modelo escolhido
case "$MODEL" in
  gemini*) ;;  # mantem gemini se for o modelo escolhido
  *)
    # Para outros modelos, desativa gemini para nao interferir
    unset GEMINI_API_KEY
    echo "=== GEMINI_API_KEY desativada (modelo é $MODEL) ==="
    ;;
esac

echo "=============================="
echo "=== INICIANDO: hermes-agent --model $MODEL $@ ==="
echo "=============================="

exec /opt/hermes/.venv/bin/hermes-agent --model "$MODEL" "$@"
