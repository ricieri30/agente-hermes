FROM nousresearch/hermes-agent:latest

USER root

# Permissões corretas em /opt/data (HOME do usuário hermes)
RUN chmod -R 777 /opt/data 2>/dev/null || true

# Copia scripts
COPY --chmod=755 hermes-entrypoint.sh /usr/local/bin/hermes-entrypoint.sh
COPY --chmod=755 hermes-setup.py      /usr/local/bin/hermes-setup.py

USER hermes

ENTRYPOINT ["/usr/local/bin/hermes-entrypoint.sh"]
CMD ["gateway", "run"]
