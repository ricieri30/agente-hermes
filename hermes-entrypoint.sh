#!/bin/sh
echo "=== Hermes Agent Entrypoint v5 ==="
echo "=== Usuario: $(whoami) | HOME: $HOME ==="

# Carrega .env
if [ -f /opt/hermes_project/.env ]; then
  set -a; . /opt/hermes_project/.env; set +a
fi

MODEL="${HERMES_MODEL:-groq:llama-3.3-70b-versatile}"
VENV="/opt/hermes/.venv/bin"
HERMES="$VENV/hermes-agent"

echo "=== Modelo: $MODEL ==="
echo "=== GROQ_API_KEY presente: $([ -n "$GROQ_API_KEY" ] && echo SIM || echo NAO) ==="

# -------------------------------------------------------
# Descobre onde o hermes guarda o config
# -------------------------------------------------------
CONFIG_DIR="$HOME/.hermes"

echo "=== Criando config em: $CONFIG_DIR ==="
mkdir -p "$CONFIG_DIR" 2>/dev/null || {
  CONFIG_DIR="/opt/data/.hermes"
  mkdir -p "$CONFIG_DIR" 2>/dev/null || {
    CONFIG_DIR="/tmp/.hermes"
    mkdir -p "$CONFIG_DIR"
  }
}
echo "=== Config dir OK: $CONFIG_DIR ==="

# -------------------------------------------------------
# Inspeciona formato do config via Python
# -------------------------------------------------------
echo "=== Inspecionando config hermes via Python ==="
python3 << PYINSPECT
import os, sys
sys.path.insert(0, '/opt/hermes/.venv/lib/python3.13/site-packages')

config_dir = os.environ.get('HOME', '/opt/data') + '/.hermes'
os.makedirs(config_dir, exist_ok=True)

model = os.environ.get('HERMES_MODEL', 'groq:llama-3.3-70b-versatile')
groq_key = os.environ.get('GROQ_API_KEY', '')
telegram_token = os.environ.get('TELEGRAM_TOKEN', '')
telegram_users = os.environ.get('TELEGRAM_ALLOWED_USERS', '')

# Tenta importar o modulo de config do hermes para saber o formato exato
try:
    # Tenta diferentes caminhos de import
    for mod in ['hermes_agent.config', 'hermes.config', 'hermesagent.config']:
        try:
            m = __import__(mod, fromlist=['*'])
            print(f'[OK] Modulo config encontrado: {mod}')
            print(f'[OK] Arquivo: {m.__file__}')
            # Lista atributos do modulo
            attrs = [a for a in dir(m) if not a.startswith('_')]
            print(f'[OK] Atributos: {attrs[:20]}')
            break
        except ImportError:
            continue
except Exception as e:
    print(f'[WARN] Erro importando config: {e}')

# Escreve config.yaml em varios formatos possiveis
import json

# Formato 1 — chave direta do provider
config_v1 = f"""model: "{model}"
groq_api_key: "{groq_key}"
telegram_token: "{telegram_token}"
telegram_allowed_users: "{telegram_users}"
"""

# Formato 2 — aninhado por provider
provider = model.split(':')[0] if ':' in model else 'groq'
model_name = model.split(':')[1] if ':' in model else model

config_v2 = f"""llm:
  provider: "{provider}"
  model: "{model_name}"
  api_key: "{groq_key}"
messaging:
  telegram:
    token: "{telegram_token}"
    allowed_users: [{telegram_users}]
"""

# Formato 3 — providers list
config_v3 = f"""default_model: "{model}"
providers:
  groq:
    api_key: "{groq_key}"
    models:
      - llama-3.3-70b-versatile
telegram_token: "{telegram_token}"
"""

# Escreve todos os formatos para diagnostico
for i, cfg in enumerate([config_v1, config_v2, config_v3], 1):
    path = f'{config_dir}/config_v{i}.yaml'
    with open(path, 'w') as f:
        f.write(cfg)
    print(f'[OK] Escrito: {path}')

# Escreve o config principal (tenta formato 1 primeiro)
with open(f'{config_dir}/config.yaml', 'w') as f:
    f.write(config_v2)
print(f'[OK] config.yaml principal escrito (formato v2)')

# Tambem escreve .env no formato que hermes espera
env_content = f"""HERMES_MODEL={model}
GROQ_API_KEY={groq_key}
TELEGRAM_TOKEN={telegram_token}
TELEGRAM_ALLOWED_USERS={telegram_users}
"""
with open(f'{config_dir}/.env', 'w') as f:
    f.write(env_content)
print('[OK] .env escrito')

PYINSPECT

# -------------------------------------------------------
# Tenta configurar o provider via CLI antes do gateway
# -------------------------------------------------------
echo "=== Tentando configurar provider via hermes-agent model ==="

# Mostra help do comando model para entender opcoes
$HERMES model --help 2>&1 | head -30 || echo "(sem --help)"

# Tenta configurar groq diretamente
$HERMES model set groq --api-key "$GROQ_API_KEY" 2>&1 | head -10 || \
$HERMES model groq "$GROQ_API_KEY" 2>&1 | head -10 || \
$HERMES config set provider groq 2>&1 | head -10 || \
echo "(config via CLI nao disponivel — usando config.yaml)"

echo "=============================="
echo "=== INICIANDO GATEWAY ==="
echo "=============================="

exec $HERMES gateway run
