#!/bin/sh
echo "=== Hermes Entrypoint v9 — DEFINITIVO ==="
echo "=== Usuario: $(whoami) | DATA: $(date) ==="

# ─── 1. CARREGA .env com suporte a valores com ':' e '=' ───────────────────
if [ -f /opt/hermes_project/.env ]; then
  echo "=== Carregando .env ==="
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in '#'*|'') continue ;; esac
    key="${line%%=*}"
    val="${line#*=}"
    val="${val%\"}" ; val="${val#\"}"
    val="${val%\'}" ; val="${val#\'}"
    [ -n "$key" ] && export "$key=$val" 2>/dev/null || true
  done < /opt/hermes_project/.env
fi

MODEL="${HERMES_MODEL:-groq:llama-3.3-70b-versatile}"
PROVIDER="${MODEL%%:*}"
MODEL_ID="${MODEL#*:}"
HERMES_BIN="/opt/hermes/.venv/bin/hermes-agent"

echo "=== Provider: $PROVIDER | Model: $MODEL_ID ==="
echo "=== GROQ_API_KEY   : $([ -n "$GROQ_API_KEY"    ] && echo 'OK ['${#GROQ_API_KEY}' chars]' || echo 'AUSENTE ← ERRO!')==="
echo "=== TELEGRAM_TOKEN : $([ -n "$TELEGRAM_TOKEN"  ] && echo 'OK' || echo 'AUSENTE ← bot nao vai funcionar')==="

# ─── 2. APAGA CACHE CORROMPIDO ─────────────────────────────────────────────
echo "=== Limpando caches antigos ==="
rm -f /opt/data/models_dev_cache.json 2>/dev/null && echo "  models_dev_cache.json removido" || echo "  (cache nao existia)"
rm -f /opt/data/.hermes/config.yaml   2>/dev/null || true
rm -f /opt/data/.hermes/*.yaml        2>/dev/null || true

# ─── 3. PATCH COMPLETO DO auth.json ────────────────────────────────────────
echo "=== Patchando auth.json ==="
python3 - << PYEOF
import os, json, sys

auth_file = '/opt/data/auth.json'
groq_key  = os.environ.get('GROQ_API_KEY', '')
tg_token  = os.environ.get('TELEGRAM_TOKEN', '')
tg_users  = os.environ.get('TELEGRAM_ALLOWED_USERS', '8039948294')
model     = os.environ.get('HERMES_MODEL', 'groq:llama-3.3-70b-versatile')
provider  = model.split(':')[0] if ':' in model else 'groq'
model_id  = model.split(':')[1] if ':' in model else model

if not groq_key:
    print('[ERRO FATAL] GROQ_API_KEY está vazia! Defina no .env')
    sys.exit(1)

# Seleciona a key certa por provider
key_map = {
    'groq':       groq_key,
    'openrouter': os.environ.get('OPENROUTER_API_KEY', ''),
    'anthropic':  os.environ.get('ANTHROPIC_API_KEY', ''),
    'gemini':     '',
}
api_key = key_map.get(provider, groq_key)

# Lê ou cria auth.json
try:
    with open(auth_file) as f:
        auth = json.load(f)
    print(f'[OK] auth.json lido — keys: {list(auth.keys())}')
except:
    auth = {}
    print('[INFO] Criando auth.json do zero')

# Patch COMPLETO de todos os campos conhecidos
auth.update({
    'provider':       provider,
    'api_key':        api_key,
    'model':          model_id,
    'default_model':  model,
    'groq_api_key':   groq_key,
    'gemini_api_key': '',
    'openrouter_api_key': os.environ.get('OPENROUTER_API_KEY', ''),
    'llm': {
        'provider': provider,
        'api_key':  api_key,
        'model':    model_id
    }
})

# Adiciona telegram se token disponível
if tg_token:
    auth['telegram'] = {
        'token':         tg_token,
        'allowed_users': [int(u.strip()) for u in tg_users.split(',') if u.strip().isdigit()]
    }

with open(auth_file, 'w') as f:
    json.dump(auth, f, indent=2)

# Validação final
with open(auth_file) as f:
    saved = json.load(f)

ok = saved.get('provider') == provider and saved.get('api_key') == api_key
print(f'[{"OK" if ok else "ERRO"}] Validação: provider={saved.get("provider")} api_key={saved.get("api_key","")[:8]}...')
print(f'[OK] llm.provider={saved.get("llm",{}).get("provider")} llm.api_key={saved.get("llm",{}).get("api_key","")[:8]}...')
if not ok:
    print('[ERRO] Patch falhou!')
    import sys; sys.exit(1)
PYEOF

PATCH_EXIT=$?
if [ $PATCH_EXIT -ne 0 ]; then
  echo "=== ERRO no patch do auth.json — abortando ==="
  exit 1
fi

# ─── 4. TESTA CONEXÃO COM A API ANTES DE SUBIR ─────────────────────────────
echo "=== Testando API Groq ==="
python3 - << PYEOF
import os, urllib.request, json, sys

groq_key = os.environ.get('GROQ_API_KEY', '')
if not groq_key:
    print('[SKIP] Sem GROQ_API_KEY')
    sys.exit(0)

try:
    req = urllib.request.Request(
        'https://api.groq.com/openai/v1/models',
        headers={'Authorization': f'Bearer {groq_key}', 'Content-Type': 'application/json'}
    )
    with urllib.request.urlopen(req, timeout=5) as r:
        data = json.loads(r.read())
        models = [m['id'] for m in data.get('data', [])[:3]]
        print(f'[OK] Groq API respondeu! Modelos disponíveis: {models}')
except Exception as e:
    print(f'[WARN] Groq API teste falhou: {e}')
    print('[WARN] Continuando mesmo assim...')
PYEOF

# ─── 5. INICIA O GATEWAY ───────────────────────────────────────────────────
echo "=============================="
echo "=== TUDO OK — INICIANDO GATEWAY ==="
echo "=============================="
exec $HERMES_BIN gateway run
