#!/bin/sh
mkdir -p ~/.hermes
printenv | grep -E '^(GROQ_API_KEY|GEMINI_API_KEY|OPENROUTER_API_KEY|NOUS_API_KEY|HERMES_MODEL|TELEGRAM_TOKEN|TELEGRAM_ALLOWED_USERS|TERMINAL_TIMEOUT|TERMINAL_LIFETIME_SECONDS|BROWSER_SESSION_TIMEOUT|BROWSER_INACTIVITY_TIMEOUT|WEB_TOOLS_DEBUG|VISION_TOOLS_DEBUG)=' > ~/.hermes/.env
echo "=== ~/.hermes/.env criado ==="
cat ~/.hermes/.env | sed 's/=.*/=***/'
echo "=============================="
exec hermes "$@"
