FROM alpine:3.20

RUN apk add --no-cache wget unzip bash

WORKDIR /opt
RUN wget -q https://github.com/chemicallang/chemical/releases/download/v0.0.25/linux-alpine-x64.zip \
    && unzip linux-alpine-x64.zip \
    && rm linux-alpine-x64.zip

ENV PATH="/opt/linux-alpine:${PATH}"

RUN chmod -R +x linux-alpine

RUN chemical --configure