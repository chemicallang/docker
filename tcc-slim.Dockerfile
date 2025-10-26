FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y wget unzip build-essential \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /opt
RUN wget -q https://github.com/chemicallang/chemical/releases/download/v0.0.25/linux-x64-tcc.zip \
    && unzip linux-x64-tcc.zip \
    && rm linux-x64-tcc.zip

ENV PATH="/opt/linux-tcc:${PATH}"

RUN chmod -R +x linux-tcc

RUN chemical --configure