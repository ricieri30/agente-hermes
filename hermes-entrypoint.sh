#!/bin/sh
echo "=== Hermes Entrypoint v7 — auth.json fix ==="
echo "=== Usuario: $(whoami) | HOME: $HOME ==="

# Carrega .env
if [ -f /opt/hermes_project/.env ]; then
  set -a; . /opt/hermes_project/.env; set +a
fi

MODEL="${HERMES_MODEL:-groq:llama-3.3-70b-versatile}"
DATA_DIR="/opt/data"
AUTH_FILE="$DATA_DIR/auth.json"

echo "=== Modelo: $MODEL ==="
echo "=== GROQ_API_KEY: $([ -n "$GROQ_API_KEY" ] && echo OK || echo AUSENTE) ==="
echo "=== TELEGRAM_TOKEN: $([ -n "$TELEGRAM_TOKEN" ] && echo OK || echo AUSENTE) ==="

# Mostra auth.json atual (sem expor keys)
echo "=== auth.json atual (formato): ==="
if [ -f "$AUTH_FILE" ]; then
  cat "$AUTH_FILE" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    # Mostra estrutura sem expor keys
    def redact(obj, depth=0):
        if isinstance(obj, dict):
            return {k: ('***' if any(x in k.lower() for x in ['key','token','secret','pass']) else redact(v, depth+1)) for k,v in obj.items()}
        elif isinstance(obj, list):
            return [redact(i, depth+1) for i in obj]
        return obj
    print(json.dumps(redact(d), indent=2))
    print('KEYS_TOP:', list(d.keys()))
except Exception as e:
    print('Erro lendo auth.json:', e)
    print('Conteudo raw (primeiros 200 chars):')
    sys.stdin = open('$AUTH_FILE')
    print(open('$AUTH_FILE').read()[:200])
"
else
  echo "(auth.json nao existe ainda)"
fi

# Patch do auth.json com Python
echo "=== Aplicando patch no auth.json ==="
python3 - << PYEOF
import os, json

auth_file = '/opt/data/auth.json'
groq_key  = os.environ.get('GROQ_API_KEY', '')
tg_token  = os.environ.get('TELEGRAM_TOKEN', '')
tg_users  = os.environ.get('TELEGRAM_ALLOWED_USERS', '8039948294')
model     = os.environ.get('HERMES_MODEL', 'groq:llama-3.3-70b-versatile')

provider  = model.split(':')[0] if ':' in model else 'groq'
model_id  = model.split(':')[1] if ':' in model else model

# Le auth.json existente para entender o formato
existing = {}
if os.path.exists(auth_file):
    try:
        with open(auth_file) as f:
            existing = json.load(f)
        print(f'[OK] auth.json lido. Chaves: {list(existing.keys())}')
    except Exception as e:
        print(f'[WARN] Erro lendo auth.json: {e}')

# Detecta o formato e aplica patch
patched = dict(existing)

# Formato 1: {provider, api_key, model}
if 'api_key' in existing or 'provider' in existing:
    patched['provider'] = provider
    patched['api_key']  = groq_key
    patched['model']    = model_id
    print('[OK] Formato detectado: {provider, api_key, model}')

# Formato 2: {gemini: {api_key:...}, groq: {api_key:...}, default:...}
elif any(p in existing for p in ['gemini', 'groq', 'openai', 'anthropic']):
    patched['groq']    = {'api_key': groq_key}
    patched['gemini']  = {'api_key': ''}  # zera gemini
    patched['default'] = 'groq'
    patched['model']   = model_id
    print('[OK] Formato detectado: providers dict')

# Formato 3: {llm: {provider, api_key, model}}
elif 'llm' in existing:
    patched['llm'] = {
        'provider': provider,
        'api_key':  groq_key,
        'model':    model_id
    }
    print('[OK] Formato detectado: {llm: {...}}')

# Formato desconhecido - escreve todos os campos possiveis
else:
    print(f'[WARN] Formato desconhecido, escrevendo todos os campos. Keys: {list(existing.keys())}')
    patched.update({
        'provider':       provider,
        'api_key':        groq_key,
        'model':          model_id,
        'default_model':  model,
        'groq_api_key':   groq_key,
        'gemini_api_key': '',
        'llm': {
            'provider': provider,
            'api_key':  groq_key,
            'model':    model_id
        }
    })

# Adiciona telegram se tiver campos de mensagem no auth
if 'telegram' in existing or 'telegram_token' in existing:
    patched['telegram_token'] = tg_token
    patched['telegram'] = {'token': tg_token, 'allowed_users': tg_users.split(',')}

# Salva
try:
    with open(auth_file, 'w') as f:
        json.dump(patched, f, indent=2)
    print(f'[OK] auth.json atualizado!')
    # Mostra resultado sem keys
    safe = json.loads(json.dumps(patched))
    for k in safe:
        if any(x in str(k).lower() for x in ['key','token','secret']):
            if isinstance(safe[k], str):
                safe[k] = safe[k][:8] + '...' if safe[k] else ''
    print(f'[OK] Resultado: {json.dumps(safe, indent=2)}')
except Exception as e:
    print(f'[ERRO] Nao conseguiu salvar auth.json: {e}')
    import traceback; traceback.print_exc()

PYEOF

echo "=============================="
echo "=== INICIANDO GATEWAY ==="
echo "=============================="
exec /opt/hermes/.venv/bin/hermes-agent gateway run
