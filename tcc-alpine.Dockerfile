FROM alpine:3.20

RUN apk add --no-cache wget unzip bash

WORKDIR /opt
RUN wget -q https://github.com/chemicallang/chemical/releases/download/v0.0.24/linux-x86-64-tcc.zip \
    && unzip linux-x86-64-tcc.zip \
    && rm linux-x86-64-tcc.zip

ENV PATH="/opt/linux-x86-64-tcc:${PATH}"
CMD ["chemical", "--version"]
