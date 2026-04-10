# Synology Compiler Dockerfile
# Build: docker build -t dante90/syno-compiler:7.3-{platform} .
# Run: docker run -v /source:/input -v /output:/output dante90/syno-compiler:7.3-{platform} compile-module {platform}

FROM debian:11-slim

ARG PLATFORM=broadwell
ARG TOOLCHAIN_VERSION=7.3

ENV SHELL=/bin/bash \
    ARCH=x86_64 \
    PLATFORM=${PLATFORM} \
    TOOLCHAIN_VERSION=${TOOLCHAIN_VERSION}

LABEL maintainer="dante90" \
      platform="${PLATFORM}" \
      toolchain_version="${TOOLCHAIN_VERSION}" \
      arch="x86_64"

# Install required packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    wget \
    curl \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy toolchain to /opt
COPY opt /opt

# Copy supporting files
COPY files/ /

# Create build user
RUN useradd -m -s /bin/bash arpl && \
    chmod -R 755 /opt && \
    chmod +x /opt/do.sh

# Set working directory and volumes
USER arpl
WORKDIR /input
VOLUME ["/input", "/output"]

# Entrypoint
ENTRYPOINT ["/opt/do.sh"]
CMD [""]
