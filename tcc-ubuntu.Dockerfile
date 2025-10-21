FROM ubuntu:22.04

RUN apt-get update && apt-get install -y wget unzip \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /opt
RUN wget -q https://github.com/chemicallang/chemical/releases/download/v0.0.24/linux-x86-64-tcc.zip \
    && unzip linux-x86-64-tcc.zip \
    && rm linux-x86-64-tcc.zip

ENV PATH="/opt/linux-x86-64-tcc:${PATH}"
CMD ["chemical", "--version"]