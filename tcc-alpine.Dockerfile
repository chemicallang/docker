FROM alpine:3.20

RUN apk add --no-cache wget unzip bash build-essential

WORKDIR /opt
RUN wget -q https://github.com/chemicallang/chemical/releases/download/v0.0.25/linux-alpine-x64-tcc.zip \
    && unzip inux-alpine-x64-tcc.zip \
    && rm inux-alpine-x64-tcc.zip

ENV PATH="/opt/linux-alpine-tcc:${PATH}"

RUN chmod -R +x linux-alpine-tcc

RUN chemical --configure