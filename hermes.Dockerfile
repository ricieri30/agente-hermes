FROM nousresearch/hermes-agent:latest

# Mostra help do comando model para saber formato exato de configuracao
RUN echo "=== hermes-agent model help ===" && \
    (/opt/hermes/.venv/bin/hermes-agent model --help 2>&1 || true) && \
    echo "=== hermes-agent setup help ===" && \
    (/opt/hermes/.venv/bin/hermes-agent setup --help 2>&1 || true) && \
    echo "=== hermes-agent --help ===" && \
    (/opt/hermes/.venv/bin/hermes-agent --help 2>&1 || true)

COPY --chmod=755 hermes-entrypoint.sh /usr/local/bin/hermes-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/hermes-entrypoint.sh"]
CMD ["gateway", "run"]
