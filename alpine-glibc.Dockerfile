# Use Alpine base that includes glibc so glibc-linked binaries work
FROM frolvlad/alpine-glibc:alpine-3.20

RUN apk add --no-cache wget unzip bash

WORKDIR /opt
RUN wget -q https://github.com/chemicallang/chemical/releases/download/v0.0.20/linux-x86-64.zip \
    && unzip linux-x86-64.zip \
    && rm linux-x86-64.zip

ENV PATH="/opt/linux-x86-64:${PATH}"
CMD ["chemical", "--help"]