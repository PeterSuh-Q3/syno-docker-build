# Synology Compiler 7.3 Dockerfile
# Multi-stage build for efficient toolchain compilation
# Build: docker build -t dante90/syno-compiler:7.3 .
# Run: docker run -v /source:/input -v /output:/output dante90/syno-compiler:7.3 compile-module {platform}

# Stage 1: Extract and prepare toolchains
FROM alpine:3.14 AS stage
ARG PLATFORMS="apollolake:4.4.180 avoton:3.10.108 braswell:3.10.108 broadwell:4.4.180 broadwellnk:4.4.302 broadwellnkv2:4.4.302 broadwellntbap:4.4.302 bromolow:3.10.108 denverton:4.4.302 epyc7002:5.10.55 geminilake:4.4.302 geminilakenk:5.10.55 grantley:3.10.108 kvmx64:4.4.302 purley:4.4.302 r1000:4.4.302 r1000nk:5.10.55 v1000:4.4.302 v1000nk:5.10.55"
ARG TOOLKIT_VER="7.3"
ARG GCCLIB_VER="gcc1220_glibc236"

# Copy downloaded toolkits from cache directory
ADD opt /cache

# Create /opt directory and extract toolkits
RUN mkdir -p /opt && \
    for V in ${PLATFORMS}; do \
      echo "${V}" | while IFS=':' read PLATFORM KVER; do \
        echo "Processing platform: ${PLATFORM} kernel: ${KVER}"; \
        echo -e "${PLATFORM}\t${KVER}" >> /opt/platforms && \
        mkdir -p "/opt/${PLATFORM}" && \
        \
        if [ -f "/cache/ds.${PLATFORM}-${TOOLKIT_VER}.dev.txz" ]; then \
          echo "Extracting ds.${PLATFORM}-${TOOLKIT_VER}.dev.txz" && \
          tar -xaf "/cache/ds.${PLATFORM}-${TOOLKIT_VER}.dev.txz" -C "/opt/${PLATFORM}" --strip-components=9 \
            "usr/local/x86_64-pc-linux-gnu/x86_64-pc-linux-gnu/sys-root/usr/lib/modules/DSM-${TOOLKIT_VER}" 2>/dev/null || \
            echo "Warning: Module path not found in ds.${PLATFORM}-${TOOLKIT_VER}.dev.txz"; \
        fi && \
        \
        if [ -f "/cache/${PLATFORM}-${GCCLIB_VER}_x86_64-GPL.txz" ]; then \
          echo "Extracting ${PLATFORM}-${GCCLIB_VER}_x86_64-GPL.txz" && \
          tar -xaf "/cache/${PLATFORM}-${GCCLIB_VER}_x86_64-GPL.txz" -C "/opt/${PLATFORM}" --strip-components=1; \
        fi && \
        \
        KVER_MAJOR="`echo ${KVER} | rev | cut -d. -f2- | rev`" && \
        if [ ! -d "/opt/linux-${KVER_MAJOR}.x" ] && [ -f "/cache/linux-${KVER_MAJOR}.x.txz" ]; then \
          echo "Extracting linux-${KVER_MAJOR}.x.txz" && \
          tar -xaf "/cache/linux-${KVER_MAJOR}.x.txz" -C "/opt"; \
          rm -rf "/opt/${PLATFORM}/source" 2>/dev/null || true; \
          ln -s "/opt/linux-${KVER_MAJOR}.x" "/opt/${PLATFORM}/source"; \
        fi; \
      done; \
    done

# Stage 2: Final image
FROM debian:9-slim

ENV SHELL=/bin/bash \
    ARCH=x86_64 \
    TOOLCHAIN_VERSION=7.3

LABEL maintainer="dante90" \
      toolchain_version="7.3" \
      arch="x86_64" \
      description="Synology Compiler 7.3 - Multi-platform cross-compilation environment"

# Install required packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends --no-install-suggests \
      ca-certificates nano curl bc kmod git gettext texinfo autopoint gawk sudo \
      build-essential make ncurses-dev libssl-dev autogen automake pkg-config libtool xsltproc gperf && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    \
    # Create build user
    useradd --create-home --shell /bin/bash --uid 1000 --user-group arpl && \
    echo "arpl ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/arpl && \
    mkdir -p /output && chown 1000:1000 /output

# Copy toolchains and supporting files from stage 1
COPY --from=stage --chown=1000:1000 /opt /opt
COPY files/ /

# Set permissions
RUN chmod +x /opt/do.sh && \
    chmod 755 /opt

# Set working directory and volumes
USER arpl
WORKDIR /input
VOLUME ["/input", "/output"]

# Entrypoint
ENTRYPOINT ["/opt/do.sh"]
CMD [""]
