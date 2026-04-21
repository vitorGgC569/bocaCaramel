FROM ghcr.io/joaofazolo/boca-docker/boca-jail:latest

USER root

COPY docker/jail-languages/install-languages.sh /usr/local/bin/install-jail-languages

RUN chmod 755 /usr/local/bin/install-jail-languages

ENTRYPOINT ["/usr/local/bin/install-jail-languages"]
