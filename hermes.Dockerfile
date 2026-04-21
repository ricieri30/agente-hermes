FROM nousresearch/hermes-agent:latest
COPY hermes-entrypoint.sh /usr/local/bin/hermes-entrypoint.sh
  RUN chmod +x /usr/local/bin/hermes-entrypoint.sh
  ENTRYPOINT ["/usr/local/bin/hermes-entrypoint.sh"]
  CMD ["gateway", "run"]
  
