# syntax=docker/dockerfile:1.4
ARG BASE_IMAGE=ubuntu:24.04
FROM ${BASE_IMAGE}

ARG RELEASE_PLATFORM=linux # linux | linux-alpine | macos | windows    
ARG VARIANT=             # empty or tcc or lsp
ARG VERSION=v0.0.26
ARG ARCH_OVERRIDE=       # optional override: amd64 | arm64 | x64
ARG TARGETARCH

# Expose ARGs to run
ENV VERSION="${VERSION}" \
    RELEASE_PLATFORM="${RELEASE_PLATFORM}" \
    VARIANT="${VARIANT}" \
    ARCH_OVERRIDE="${ARCH_OVERRIDE:-${TARGETARCH}}"

# use sh, fail on error, show commands
SHELL ["/bin/sh", "-euxc"]

# Quick package installation depending on distro
RUN if grep -q -i alpine /etc/os-release 2>/dev/null; then \
      apk add --no-cache wget unzip bash build-base ; \
    else \
      apt-get update && apt-get install -y wget unzip ca-certificates build-essential --no-install-recommends && rm -rf /var/lib/apt/lists/* ; \
    fi

# copy installer script and make sure it's executable
COPY scripts/install-chemical.sh /usr/local/bin/install-chemical.sh
RUN chmod +x /usr/local/bin/install-chemical.sh

# build args forwarded to script; use TARGETARCH from buildkit if available
RUN /usr/local/bin/install-chemical.sh

ENV PATH="/opt/chemical:${PATH}"

CMD ["chemical", "--help"]