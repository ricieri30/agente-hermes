FROM nousresearch/hermes-agent:latest

COPY --chmod=755 hermes-entrypoint.sh /usr/local/bin/hermes-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/hermes-entrypoint.sh"]
CMD ["gateway", "run"]
