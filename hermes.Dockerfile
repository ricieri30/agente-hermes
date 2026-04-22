FROM nousresearch/hermes-agent:latest

USER root

# Garante permissões corretas no diretório de dados
RUN chmod -R 777 /opt/data 2>/dev/null || true && \
    mkdir -p /opt/data/.hermes && \
    chmod 777 /opt/data/.hermes

COPY --chmod=755 hermes-entrypoint.sh /usr/local/bin/hermes-entrypoint.sh

USER hermes

ENTRYPOINT ["/usr/local/bin/hermes-entrypoint.sh"]
CMD ["gateway", "run"]
