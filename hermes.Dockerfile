FROM nousresearch/hermes-agent:latest

USER root

# Garante permissão total no diretório de dados do hermes
RUN mkdir -p /opt/data/.hermes && \
    chmod -R 777 /opt/data && \
    chmod -R 777 /opt/data/.hermes

# Copia entrypoint
COPY --chmod=755 hermes-entrypoint.sh /usr/local/bin/hermes-entrypoint.sh

USER hermes

ENTRYPOINT ["/usr/local/bin/hermes-entrypoint.sh"]
CMD ["gateway", "run"]
