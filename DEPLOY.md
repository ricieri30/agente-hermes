# Hermes Agent — Deploy Definitivo

## PRÉ-REQUISITO: 2 chaves necessárias

### 1. Chave Groq (gratuita)
1. Acesse: https://console.groq.com/keys
2. Clique "Create API Key"
3. Copie — começa com `gsk_` e tem 56 caracteres

### 2. Token do Telegram
1. Abra @BotFather no Telegram
2. Mande `/newbot`
3. Siga as instruções e copie o token (formato: `1234567890:AAF...`)

---

## DEPLOY — 4 comandos

```bash
# 1. Destrói volume corrompido (só na primeira vez)
cd agente-hermes
docker-compose down -v
docker volume rm agente-hermes_hermes_data 2>/dev/null || true

# 2. Edita o .env com as 2 chaves
nano .env
# Preencha: GROQ_API_KEY=gsk_... e TELEGRAM_TOKEN=...

# 3. Sobe tudo do zero
docker-compose up --build -d

# 4. Acompanha os logs
docker-compose logs -f hermes
```

---

## Log de sucesso esperado

```
[OK] ~/ .hermes/.env escrito com groq/llama-3.3-70b-versatile
[OK] auth.json: provider=groq, api_key=gsk_xxxx...
[OK] Groq API OK! Modelos: ['llama-3.3-70b-versatile', ...]
[OK] API Key    : 56 chars
[OK] API Test   : PASSOU
=== SETUP CONCLUÍDO — INICIANDO GATEWAY ===
🤖 AI Agent initialized with model: groq:llama-3.3-70b-versatile
```

---

## Como testar o Telegram

1. Abra o bot que você criou no @BotFather
2. Mande `/start`
3. Mande qualquer mensagem — o hermes deve responder

---

## O que mudou nesta versão

| Problema anterior | Correção |
|---|---|
| Patch em `auth.json` ignorado | Agora escreve em `~/.hermes/.env` (fonte real) |
| Placeholder `COLE_SUA_CHAVE` aceito | Validação obriga chave com 40+ chars |
| Erros silenciosos | Setup aborta com mensagem clara se algo falhar |
| Loop infinito de restart | `sleep 30` antes de reiniciar em caso de erro |
| Um bug corrigido por vez | Setup.py corrige todos os pontos de config de uma vez |
