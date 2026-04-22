# Instruções de Deploy — Hermes Agent

## Antes de tudo — Regenere a chave Groq!
A chave anterior foi exposta. Acesse:
https://console.groq.com/keys → Delete a antiga → Crie nova

## Passo a passo

### 1. Edite o .env com suas chaves reais:
```
GROQ_API_KEY=gsk_SUA_NOVA_CHAVE_AQUI
TELEGRAM_TOKEN=SEU_TOKEN_DO_BOTFATHER
```

### 2. No servidor, destrua tudo e recomece do zero:
```bash
cd agente-hermes
docker-compose down -v
docker volume rm agente-hermes_hermes_data 2>/dev/null || true
```

### 3. Substitua os 4 arquivos:
- hermes-entrypoint.sh → raiz do projeto
- hermes.Dockerfile    → raiz do projeto
- docker-compose.yml   → raiz do projeto
- .env                 → raiz do projeto (com suas chaves preenchidas)

### 4. Suba:
```bash
docker-compose up --build -d
docker-compose logs -f hermes
```

### 5. Log de sucesso esperado:
```
[OK] Groq API respondeu! Modelos disponíveis: [...]
[OK] Validação: provider=groq api_key=gsk_6eXQ...
=== TUDO OK — INICIANDO GATEWAY ===
🤖 AI Agent initialized with model: groq:llama-3.3-70b-versatile
```

### 6. Teste no Telegram:
- Abra o bot que você criou com o BotFather
- Mande /start
- Depois mande qualquer mensagem

## Problemas resolvidos nesta versão
- ✅ models_dev_cache.json era o responsável por cachear Gemini — agora é deletado no startup
- ✅ .env com valor "groq:llama-3.3-70b-versatile" quebrava o shell — parsing corrigido
- ✅ auth.json patch agora atualiza TODOS os 8 campos incluindo llm.provider e llm.api_key
- ✅ docker-compose não tem mais variáveis hardcoded — tudo vem do .env
- ✅ Volume corrigido para /opt/data (onde hermes realmente grava)
- ✅ Healthcheck corrigido para verificar processo real
- ✅ Teste de conectividade com Groq antes de subir o gateway
