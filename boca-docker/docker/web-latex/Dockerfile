FROM ghcr.io/joaofazolo/boca-docker/boca-web:latest

USER root

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        texlive-latex-base \
        texlive-latex-recommended \
        texlive-lang-portuguese \
    && rm -rf /var/lib/apt/lists/*

USER www-data
