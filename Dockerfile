# syntax=docker/dockerfile:1
ARG bashver=latest

FROM bash:${bashver}  AS base

ARG TINI_VERSION=v0.19.0
ARG TARGETPLATFORM
ARG LIBS_VER_SUPPORT=0.3.0
ARG LIBS_VER_FILE=0.4.0
ARG LIBS_VER_ASSERT=2.2.4
ARG LIBS_VER_DETIK=1.3.2
ARG UID=1001
ARG GID=115


# https://github.com/opencontainers/image-spec/blob/main/annotations.md
LABEL maintainer="Bats-core Team"
LABEL org.opencontainers.image.authors="Bats-core Team"
LABEL org.opencontainers.image.title="Bats"
LABEL org.opencontainers.image.description="Bash Automated Testing System"
LABEL org.opencontainers.image.url="https://hub.docker.com/r/bats/bats"
LABEL org.opencontainers.image.source="https://github.com/bats-core/bats-core"
LABEL org.opencontainers.image.base.name="docker.io/bash"

COPY ./docker /tmp/docker
# default to amd64 when not running in buildx environment that provides target platform
RUN /tmp/docker/install_tini.sh "${TARGETPLATFORM-linux/amd64}"
# Install bats libs
RUN /tmp/docker/install_libs.sh support ${LIBS_VER_SUPPORT}
RUN /tmp/docker/install_libs.sh file ${LIBS_VER_FILE}
RUN /tmp/docker/install_libs.sh assert ${LIBS_VER_ASSERT}
RUN /tmp/docker/install_libs.sh detik ${LIBS_VER_DETIK}

# Install parallel and accept the citation notice (we aren't using this in a
# context where it make sense to cite GNU Parallel).
RUN apk add --no-cache parallel ncurses && \
    mkdir -p ~/.parallel && touch ~/.parallel/will-cite \
    && mkdir /code

RUN ln -s "$(/usr/bin/env which bash)" "/bin/bash"

RUN ln -s /opt/bats/bin/bats /usr/local/bin/bats
COPY . /opt/bats/

WORKDIR /code/

ENTRYPOINT ["/tini", "--", "/usr/local/bin/bash", "/usr/local/bin/bats"]

FROM base AS test

RUN apk add --no-cache util-linux # get script

FROM base AS prod
