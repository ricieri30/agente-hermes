FROM nousresearch/hermes-agent:latest

# Mostra usuario e estrutura da imagem para diagnostico
RUN echo "=== Usuario na imagem ===" && whoami && \
    echo "=== HOME ===" && echo $HOME && \
    echo "=== /usr/local/bin ===" && ls /usr/local/bin/ && \
    echo "=== pip hermes ===" && (pip list 2>/dev/null | grep -i hermes || echo "nenhum") && \
    echo "=== find hermes binarios ===" && \
    (find /usr /opt /app /home -maxdepth 6 -name "hermes*" -type f 2>/dev/null | grep -v ".pyc" || echo "nenhum encontrado")

# Copia entrypoint
COPY --chmod=755 hermes-entrypoint.sh /usr/local/bin/hermes-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/hermes-entrypoint.sh"]
CMD ["gateway", "run"]
