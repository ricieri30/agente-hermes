#!/bin/sh
echo "=== Hermes Entrypoint v6 ==="
echo "=== Usuario: $(whoami) | HOME: $HOME ==="

# Carrega .env
if [ -f /opt/hermes_project/.env ]; then
  set -a; . /opt/hermes_project/.env; set +a
fi

MODEL="${HERMES_MODEL:-groq:llama-3.3-70b-versatile}"
CONFIG_DIR="/opt/data/.hermes"

echo "=== Modelo: $MODEL ==="
echo "=== GROQ_API_KEY: $([ -n "$GROQ_API_KEY" ] && echo OK || echo AUSENTE) ==="
echo "=== TELEGRAM_TOKEN: $([ -n "$TELEGRAM_TOKEN" ] && echo OK || echo AUSENTE) ==="

# Garante permissões e cria config
mkdir -p "$CONFIG_DIR" 2>/dev/null
chmod 777 "$CONFIG_DIR" 2>/dev/null

echo "=== Permissões: $(ls -la /opt/data/ | grep .hermes) ==="

# Apaga config antigo (Gemini corrompido)
rm -f "$CONFIG_DIR/config.yaml" "$CONFIG_DIR/.env" "$CONFIG_DIR"/*.yaml 2>/dev/null
echo "=== Config antigo removido ==="

# Descobre formato correto via Python
python3 - << PYEOF
import os, sys

sys.path.insert(0, '/opt/hermes/.venv/lib/python3.13/site-packages')

config_dir = '/opt/data/.hermes'
model      = os.environ.get('HERMES_MODEL', 'groq:llama-3.3-70b-versatile')
groq_key   = os.environ.get('GROQ_API_KEY', '')
tg_token   = os.environ.get('TELEGRAM_TOKEN', '')
tg_users   = os.environ.get('TELEGRAM_ALLOWED_USERS', '')

# Tenta encontrar o modulo de config para saber o schema exato
config_class = None
for mod_name in ['hermes_agent.config', 'hermes.config', 'hermesagent.config']:
    try:
        mod = __import__(mod_name, fromlist=['Config','Settings','LLMConfig'])
        print(f'[OK] Config module: {mod.__file__}')
        # Inspeciona o schema
        import inspect
        for name, cls in inspect.getmembers(mod, inspect.isclass):
            print(f'  Classe: {name} -> {[f for f in getattr(cls, "__fields__", {}).keys()]}')
        config_class = mod
        break
    except Exception as e:
        print(f'[--] {mod_name}: {e}')

# Escreve config.yaml no formato mais provável
provider = model.split(':')[0] if ':' in model else 'groq'
model_id  = model.split(':')[1] if ':' in model else model

config_yaml = f"""# Hermes Agent Config — gerado pelo entrypoint
llm:
  provider: "{provider}"
  model: "{model_id}"
  api_key: "{groq_key}"

model: "{model}"

providers:
  groq:
    api_key: "{groq_key}"
  gemini:
    api_key: ""

telegram:
  token: "{tg_token}"
  allowed_users: [{tg_users}]

data_dir: "/opt/data"
"""

path = f'{config_dir}/config.yaml'
try:
    with open(path, 'w') as f:
        f.write(config_yaml)
    print(f'[OK] config.yaml escrito: {path}')
except Exception as e:
    print(f'[ERRO] Nao conseguiu escrever config: {e}')

# Tambem tenta via sqlite se houver db
import glob
dbs = glob.glob(f'{config_dir}/*.db') + glob.glob(f'{config_dir}/*.sqlite')
print(f'Databases encontrados: {dbs}')
for db in dbs:
    try:
        import sqlite3
        conn = sqlite3.connect(db)
        tables = conn.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()
        print(f'  DB {db} tabelas: {tables}')
        for (t,) in tables:
            rows = conn.execute(f'SELECT * FROM {t} LIMIT 3').fetchall()
            cols = [d[0] for d in conn.execute(f'SELECT * FROM {t} LIMIT 0').description]
            print(f'    {t} colunas: {cols}')
            print(f'    {t} dados: {rows}')
        conn.close()
    except Exception as e:
        print(f'  Erro lendo {db}: {e}')

PYEOF

echo "=== Config escrito. Iniciando gateway... ==="
echo "=== Conteudo do config.yaml: ==="
cat "$CONFIG_DIR/config.yaml" 2>/dev/null | grep -v api_key || echo "(nao existe)"

exec /opt/hermes/.venv/bin/hermes-agent gateway run
