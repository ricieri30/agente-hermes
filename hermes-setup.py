#!/usr/bin/env python3
"""
Hermes Agent — Auto Setup & Self-Healing
Roda ANTES do gateway. Configura tudo via hermes internals.
"""
import os, sys, json, subprocess, time, urllib.request

HERMES_BIN  = "/opt/hermes/.venv/bin/hermes-agent"
HERMES_PY   = "/opt/hermes/.venv/bin/python3"
DATA_DIR    = os.environ.get("HOME", "/opt/data")
HERMES_DIR  = os.path.join(DATA_DIR, ".hermes")
AUTH_FILE   = os.path.join(DATA_DIR, "auth.json")
ENV_FILE    = os.path.join(HERMES_DIR, ".env")

RED    = "\033[91m"
GREEN  = "\033[92m"
YELLOW = "\033[93m"
BLUE   = "\033[94m"
RESET  = "\033[0m"

def ok(msg):  print(f"{GREEN}[OK]{RESET} {msg}")
def err(msg): print(f"{RED}[ERRO]{RESET} {msg}")
def warn(msg):print(f"{YELLOW}[WARN]{RESET} {msg}")
def info(msg):print(f"{BLUE}[INFO]{RESET} {msg}")

# ── 1. LÊ VARIÁVEIS DE AMBIENTE ──────────────────────────────────────────────
def load_env(path):
    """Lê .env com suporte a valores com ':' e '='"""
    if not os.path.exists(path):
        return {}
    result = {}
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            if '=' not in line:
                continue
            key, _, val = line.partition('=')
            val = val.strip().strip('"').strip("'")
            result[key.strip()] = val
    return result

# Carrega do .env do projeto (dashboard)
project_env = load_env("/opt/hermes_project/.env")
for k, v in project_env.items():
    if k not in os.environ or not os.environ[k]:
        os.environ[k] = v

MODEL    = os.environ.get("HERMES_MODEL", "groq:llama-3.3-70b-versatile")
PROVIDER = MODEL.split(":")[0] if ":" in MODEL else "groq"
MODEL_ID = MODEL.split(":")[1] if ":" in MODEL else MODEL

KEYS = {
    "groq":       os.environ.get("GROQ_API_KEY", ""),
    "openrouter": os.environ.get("OPENROUTER_API_KEY", ""),
    "anthropic":  os.environ.get("ANTHROPIC_API_KEY", ""),
    "gemini":     os.environ.get("GEMINI_API_KEY", ""),
}
API_KEY      = KEYS.get(PROVIDER, "")
TG_TOKEN     = os.environ.get("TELEGRAM_TOKEN", "")
TG_USERS     = os.environ.get("TELEGRAM_ALLOWED_USERS", "")

print(f"\n{'='*55}")
print(f"  Hermes Auto-Setup — {time.strftime('%Y-%m-%d %H:%M:%S')}")
print(f"{'='*55}")
info(f"HOME       : {DATA_DIR}")
info(f"HERMES_DIR : {HERMES_DIR}")
info(f"Provider   : {PROVIDER}")
info(f"Model      : {MODEL_ID}")
info(f"API Key    : {API_KEY[:8]}... ({len(API_KEY)} chars)" if API_KEY else "API Key    : AUSENTE")
info(f"Telegram   : {'OK' if TG_TOKEN else 'AUSENTE'}")

# ── 2. VALIDAÇÕES ────────────────────────────────────────────────────────────
errors = []
if not API_KEY:
    errors.append(f"API key para '{PROVIDER}' está vazia. Preencha {PROVIDER.upper()}_API_KEY no .env")
if len(API_KEY) < 20:
    errors.append(f"API key parece inválida ({len(API_KEY)} chars). Chaves Groq têm 56 chars (gsk_...)")
if not TG_TOKEN:
    warn("TELEGRAM_TOKEN vazio — gateway subirá mas Telegram não funcionará")

if errors:
    for e in errors:
        err(e)
    print(f"\n{RED}SETUP ABORTADO — corrija os erros acima no .env{RESET}\n")
    sys.exit(1)

# ── 3. GARANTE DIRETÓRIOS ────────────────────────────────────────────────────
os.makedirs(HERMES_DIR, mode=0o777, exist_ok=True)
ok(f"Diretório: {HERMES_DIR}")

# ── 4. LIMPA CACHES CORROMPIDOS ───────────────────────────────────────────────
for stale in ["models_dev_cache.json", "models_cache.json"]:
    path = os.path.join(DATA_DIR, stale)
    if os.path.exists(path):
        os.remove(path)
        ok(f"Cache removido: {stale}")

# ── 5. ESCREVE ~/.hermes/.env (fonte primária de config do hermes) ────────────
hermes_env_content = f"""# Auto-gerado pelo hermes-setup.py — {time.strftime('%Y-%m-%d %H:%M:%S')}
HERMES_MODEL={MODEL}
{PROVIDER.upper()}_API_KEY={API_KEY}
GROQ_API_KEY={KEYS['groq']}
OPENROUTER_API_KEY={KEYS['openrouter']}
GEMINI_API_KEY=
ANTHROPIC_API_KEY={KEYS['anthropic']}
TELEGRAM_TOKEN={TG_TOKEN}
TELEGRAM_ALLOWED_USERS={TG_USERS}
TERMINAL_TIMEOUT={os.environ.get('TERMINAL_TIMEOUT', '60')}
TERMINAL_LIFETIME_SECONDS={os.environ.get('TERMINAL_LIFETIME_SECONDS', '300')}
BROWSER_SESSION_TIMEOUT={os.environ.get('BROWSER_SESSION_TIMEOUT', '300')}
BROWSER_INACTIVITY_TIMEOUT={os.environ.get('BROWSER_INACTIVITY_TIMEOUT', '120')}
WEB_TOOLS_DEBUG=false
VISION_TOOLS_DEBUG=false
MOA_TOOLS_DEBUG=false
API_SERVER_ENABLED=true
API_SERVER_HOST=0.0.0.0
API_SERVER_PORT=8642
"""
with open(ENV_FILE, "w") as f:
    f.write(hermes_env_content)
ok(f"~/.hermes/.env escrito com {PROVIDER}/{MODEL_ID}")

# ── 6. PATCHA auth.json (fonte secundária) ────────────────────────────────────
try:
    auth = json.load(open(AUTH_FILE)) if os.path.exists(AUTH_FILE) else {}
except:
    auth = {}

auth.update({
    "provider":           PROVIDER,
    "api_key":            API_KEY,
    "model":              MODEL_ID,
    "default_model":      MODEL,
    "groq_api_key":       KEYS["groq"],
    "openrouter_api_key": KEYS["openrouter"],
    "gemini_api_key":     "",
    "llm": {"provider": PROVIDER, "api_key": API_KEY, "model": MODEL_ID},
})
if TG_TOKEN:
    users = [int(u) for u in TG_USERS.replace(",", " ").split() if u.strip().isdigit()]
    auth["telegram"] = {"token": TG_TOKEN, "allowed_users": users}

with open(AUTH_FILE, "w") as f:
    json.dump(auth, f, indent=2)
ok(f"auth.json: provider={PROVIDER}, model={MODEL_ID}, api_key={API_KEY[:8]}...")

# ── 7. CONFIGURA VIA hermes-agent model (método oficial) ─────────────────────
info("Tentando configurar via 'hermes-agent model' (método oficial)...")
try:
    # Tenta descobrir a sintaxe correta do comando
    result = subprocess.run(
        [HERMES_BIN, "model", "--help"],
        capture_output=True, text=True, timeout=10
    )
    help_text = result.stdout + result.stderr
    info(f"hermes-agent model --help:\n{help_text[:400]}")

    # Tenta diferentes sintaxes
    attempts = [
        [HERMES_BIN, "model", "set", PROVIDER, "--api-key", API_KEY, "--model", MODEL_ID],
        [HERMES_BIN, "model", PROVIDER, API_KEY],
        [HERMES_BIN, "config", "set", "provider", PROVIDER],
    ]
    for attempt in attempts:
        r = subprocess.run(attempt, capture_output=True, text=True, timeout=10,
                          env={**os.environ, "HOME": DATA_DIR})
        if r.returncode == 0:
            ok(f"Configurado via CLI: {' '.join(attempt[2:])}")
            break
        else:
            warn(f"CLI {attempt[2]}: {(r.stderr or r.stdout)[:100]}")
except Exception as e:
    warn(f"CLI config falhou (não crítico): {e}")

# ── 8. TESTA A API ────────────────────────────────────────────────────────────
info(f"Testando API {PROVIDER}...")
test_passed = False
try:
    if PROVIDER == "groq":
        req = urllib.request.Request(
            "https://api.groq.com/openai/v1/models",
            headers={"Authorization": f"Bearer {API_KEY}"}
        )
        with urllib.request.urlopen(req, timeout=8) as r:
            data = json.loads(r.read())
            models = [m["id"] for m in data.get("data", [])[:3]]
            ok(f"Groq API OK! Modelos: {models}")
            test_passed = True
    elif PROVIDER == "openrouter":
        req = urllib.request.Request(
            "https://openrouter.ai/api/v1/models",
            headers={"Authorization": f"Bearer {API_KEY}"}
        )
        with urllib.request.urlopen(req, timeout=8) as r:
            ok("OpenRouter API OK!")
            test_passed = True
except Exception as e:
    warn(f"Teste de API falhou: {e}")
    if "403" in str(e) or "401" in str(e):
        err(f"API Key inválida para {PROVIDER}! Verifique no .env")
        sys.exit(1)
    warn("Continuando mesmo assim (pode ser bloqueio de rede temporário)...")

# ── 9. DIAGNÓSTICO FINAL ──────────────────────────────────────────────────────
print(f"\n{'='*55}")
print("  Diagnóstico Final")
print(f"{'='*55}")
ok(f"~/.hermes/.env  : escrito") if os.path.exists(ENV_FILE) else err("~/.hermes/.env  : FALTANDO")
ok(f"auth.json       : escrito") if os.path.exists(AUTH_FILE) else err("auth.json       : FALTANDO")
ok(f"API Key         : {len(API_KEY)} chars") if len(API_KEY) >= 40 else err(f"API Key         : suspeita ({len(API_KEY)} chars)")
ok(f"API Test        : PASSOU") if test_passed else warn(f"API Test        : PULADO")
ok(f"Telegram        : configurado") if TG_TOKEN else warn(f"Telegram        : sem token")

print(f"\n{GREEN}{'='*55}")
print("  SETUP CONCLUÍDO — INICIANDO GATEWAY")
print(f"{'='*55}{RESET}\n")
sys.exit(0)
