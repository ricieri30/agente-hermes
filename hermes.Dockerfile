FROM nousresearch/hermes-agent:latest

# Copia e garante permissão de execução no entrypoint
COPY --chmod=755 hermes-entrypoint.sh /usr/local/bin/hermes-entrypoint.sh

# Debug: lista binários disponíveis no build para diagnóstico
RUN echo "=== Binários disponíveis ===" && \
    ls /usr/local/bin/ && \
    echo "=== Verificando hermes ===" && \
    (command -v hermes-agent && echo "hermes-agent OK") || \
    (command -v hermes && echo "hermes OK") || \
    (python3 -c "import hermes; print('python module OK')" 2>/dev/null) || \
    echo "AVISO: binario nao encontrado ainda (pode ser instalado em runtime)"

ENTRYPOINT ["/usr/local/bin/hermes-entrypoint.sh"]

# gateway run = modo messaging (Telegram/WhatsApp/Discord)
CMD ["gateway", "run"]
