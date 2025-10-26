FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y wget unzip build-essential libc6-dev \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /opt
RUN wget -q https://github.com/chemicallang/chemical/releases/download/v0.0.25/linux-x64.zip \
    && unzip linux-x64.zip \
    && rm linux-x64.zip

ENV PATH="/opt/linux:${PATH}"

RUN chmod -R +x linux

RUN chemical --configure