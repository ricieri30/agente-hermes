#!/bin/sh

echo "=== Hermes Agent Entrypoint v3 ==="
echo "=== Usuario: $(whoami) | HOME: $HOME ==="

# Carrega .env do dashboard se existir
if [ -f /opt/hermes_project/.env ]; then
  echo "=== Carregando .env do dashboard ==="
  set -a
  . /opt/hermes_project/.env
  set +a
fi

# Usa diretorio gravavel — nao assume /root
HERMES_DIR="${HOME}/.hermes"
if ! mkdir -p "$HERMES_DIR" 2>/dev/null; then
  HERMES_DIR="/tmp/.hermes"
  mkdir -p "$HERMES_DIR"
fi
echo "=== Config dir: $HERMES_DIR ==="

# Escreve .env interno
printenv | grep -E '^(GROQ_API_KEY|GEMINI_API_KEY|OPENROUTER_API_KEY|NOUS_API_KEY|ANTHROPIC_API_KEY|HERMES_MODEL|TELEGRAM_TOKEN|TELEGRAM_ALLOWED_USERS|DISCORD_TOKEN|TERMINAL_TIMEOUT|TERMINAL_LIFETIME_SECONDS|BROWSER_SESSION_TIMEOUT|BROWSER_INACTIVITY_TIMEOUT|WEB_TOOLS_DEBUG|VISION_TOOLS_DEBUG)=' > "$HERMES_DIR/.env" 2>/dev/null
cat "$HERMES_DIR/.env" 2>/dev/null | sed 's/=.*/=***/' || true
echo "=============================="

# Adiciona caminhos de pip ao PATH
export PATH="$PATH:$HOME/.local/bin:/usr/local/bin:/usr/bin:/opt/hermes/bin:/app/.venv/bin"

# Busca binario hermes
HERMES_BIN=""
for candidate in hermes-agent hermes; do
  if command -v "$candidate" > /dev/null 2>&1; then
    HERMES_BIN="$candidate"
    echo "=== Binario encontrado: $HERMES_BIN ==="
    break
  fi
done

# Busca por modulo Python
if [ -z "$HERMES_BIN" ]; then
  for mod in hermes_agent hermes; do
    if python3 -c "import $mod" > /dev/null 2>&1; then
      HERMES_BIN="python3 -m $mod"
      echo "=== Modulo Python encontrado: $HERMES_BIN ==="
      break
    fi
  done
fi

# Busca manual no sistema
if [ -z "$HERMES_BIN" ]; then
  echo "=== Busca manual... ==="
  FOUND=$(find /usr /opt /app /home -maxdepth 8 -name "hermes*" -type f 2>/dev/null | grep -v ".pyc" | head -10)
  echo "Encontrados: $FOUND"
  for f in $FOUND; do
    if [ -x "$f" ]; then
      HERMES_BIN="$f"
      echo "=== Usando: $f ==="
      break
    fi
  done
fi

# Tenta instalar via pip como ultimo recurso
if [ -z "$HERMES_BIN" ]; then
  echo "=== Tentando instalar hermes-agent via pip... ==="
  pip install hermes-agent --quiet 2>&1 | tail -5
  export PATH="$PATH:$HOME/.local/bin"
  if command -v hermes-agent > /dev/null 2>&1; then
    HERMES_BIN="hermes-agent"
  elif command -v hermes > /dev/null 2>&1; then
    HERMES_BIN="hermes"
  fi
fi

if [ -z "$HERMES_BIN" ]; then
  echo "=== ERRO FATAL: hermes nao encontrado ==="
  echo "--- /usr/local/bin ---"
  ls /usr/local/bin/ 2>/dev/null
  echo "--- $HOME/.local/bin ---"
  ls $HOME/.local/bin/ 2>/dev/null
  echo "--- pip list hermes ---"
  pip list 2>/dev/null | grep -i hermes || echo "(nenhum)"
  exit 1
fi

echo "=== INICIANDO: $HERMES_BIN $@ ==="
exec $HERMES_BIN "$@"
