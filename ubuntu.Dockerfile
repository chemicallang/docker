FROM ubuntu:22.04

RUN apt-get update && apt-get install -y wget unzip \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /opt
RUN wget -q https://github.com/chemicallang/chemical/releases/download/v0.0.20/linux-x86-64.zip \
    && unzip linux-x86-64.zip \
    && rm linux-x86-64.zip

ENV PATH="/opt/linux-x86-64:${PATH}"
CMD ["chemical", "--version"]