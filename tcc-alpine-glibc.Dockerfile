FROM frolvlad/alpine-glibc

RUN apk add --no-cache wget unzip bash

WORKDIR /opt
RUN wget -q https://github.com/chemicallang/chemical/releases/download/v0.0.25/linux-x64-tcc.zip \
    && unzip linux-x64-tcc.zip \
    && rm linux-x64-tcc.zip

ENV PATH="/opt/linux-tcc:${PATH}"

RUN chmod -R +x linux-tcc

RUN chemical --configure