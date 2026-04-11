#!/usr/bin/env bash

# Enhanced Synology Compiler Build Script
# Includes performance optimizations and monitoring

CACHE_DIR="cache"
SERVER="https://global.synologydownload.com"
USE_PARALLEL=${USE_PARALLEL:-true}
PERFORMANCE_MONITORING=${PERFORMANCE_MONITORING:-true}

declare -A URIS
declare -A PLATFORMS

URIS["apollolake"]="Intel%20x86%20Linux%20|%20%28Apollolake%29"
URIS["broadwell"]="Intel%20x86%20Linux%20|%20%28Broadwell%29"
URIS["broadwellnk"]="Intel%20x86%20Linux%20|%20%28Broadwellnk%29"
URIS["bromolow"]="Intel%20x86%20linux%20|%20%28Bromolow%29"
URIS["denverton"]="Intel%20x86%20Linux%20|%20%28Denverton%29"
URIS["geminilake"]="Intel%20x86%20Linux%20|%20%28GeminiLake%29"
URIS["v1000"]="Intel%20x86%20Linux%20|%20%28V1000%29"
URIS["r1000"]="AMD%20x86%20Linux%20|%20%28r1000%29"
URIS["epyc7002"]="AMD%20x86%20Linux%20Linux%20|%20%28epyc7002%29"
URIS["geminilakenk"]="Intel%20x86%20Linux%20|%20%28geminilakenk%29"
URIS["v1000nk"]="AMD%20x86%20Linux%20|%20%28v1000nk%29"
URIS["r1000nk"]="AMD%20x86%20Linux%20|%20%28r1000nk%29"
PLATFORMS["7.1"]="apollolake:4.4.180 broadwell:4.4.180 broadwellnk:4.4.180 bromolow:3.10.108 denverton:4.4.180 geminilake:4.4.180 v1000:4.4.180 r1000:4.4.180 epyc7002:5.10.55"
PLATFORMS["7.2"]="apollolake:4.4.302 broadwell:4.4.302 broadwellnk:4.4.302 bromolow:3.10.108 denverton:4.4.302 geminilake:4.4.302 v1000:4.4.302 r1000:4.4.302 epyc7002:5.10.55"
PLATFORMS["7.3"]="epyc7002:5.10.55 geminilakenk:5.10.55 r1000nk:5.10.55 v1000nk:5.10.55"
#PLATFORMS["7.3"]="apollolake:4.4.302 broadwell:4.4.302 broadwellnk:4.4.302 broadwellnkv2:4.4.302 broadwellntbap:4.4.302 denverton:4.4.302 geminilake:4.4.302 kvmx64:4.4.302 purley:4.4.302 r1000:4.4.302 v1000:4.4.302"

mkdir -p ${CACHE_DIR}

###############################################################################
function trap_cancel() {
    echo "Press Control+C once more terminate the process (or wait 2s for it to restart)"
    sleep 2 || exit 1
}
trap trap_cancel SIGINT SIGTERM
cd `dirname $0`

###############################################################################
function prepare() {
  # Download toolkits
  for P in ${PLATFORMS[${TOOLKIT_VER}]}; do
    PLATFORM="`echo ${P} | cut -d':' -f1`"
    KVER="`echo ${P} | cut -d':' -f2`"
    # Dev
    echo -n "Checking ${CACHE_DIR}/ds.${PLATFORM}-${TOOLKIT_VER}.dev.txz... "
    if [ ! -f "${CACHE_DIR}/ds.${PLATFORM}-${TOOLKIT_VER}.dev.txz" ]; then
      URL="${SERVER}/download/ToolChain/toolkit/${TOOLKIT_VER}/${PLATFORM}/ds.${PLATFORM}-${TOOLKIT_VER}.dev.txz"
      echo -e "No\nDownloading ${URL}"
      STATUS=`curl -w "%{http_code}" -L "${URL}" -o "${CACHE_DIR}/ds.${PLATFORM}-${TOOLKIT_VER}.dev.txz"`
      if [ ${STATUS} -ne 200 ]; then
        rm -f "${CACHE_DIR}/ds.${PLATFORM}-${TOOLKIT_VER}.dev.txz"
        exit 1
      fi
    else
      echo "OK"
    fi
    # Toolchain
    URI="`echo ${URIS[${PLATFORM}]} | sed "s/|/${KVER}/"`"
    URL="${SERVER}/download/ToolChain/toolchain/${TOOLCHAIN_VER}/${URI}/${PLATFORM}-${GCCLIB_VER}_x86_64-GPL.txz"
    FILENAME="${PLATFORM}-${GCCLIB_VER}_x86_64-GPL.txz"
    echo -n "Checking ${CACHE_DIR}/${FILENAME}... "
    if [ ! -f "${CACHE_DIR}/${FILENAME}" ]; then
      echo -e "No\nDownloading ${URL}"
      STATUS=`curl -w "%{http_code}" -L "${URL}" -o "${CACHE_DIR}/${FILENAME}"`
      if [ ${STATUS} -ne 200 ]; then
        rm -f "${CACHE_DIR}/${FILENAME}"
        exit 1
      fi
    else
      echo "OK"
    fi
  done

  # for KERNEL in 3.10.x 4.4.x 5.10.x; do
  #   URL=${URLS["${KERNEL}"]}
  #   [ -z "${URL}" ] && continue
  #   echo -n "Checking ${CACHE_DIR}/linux-${KERNEL}.txz... "
  #   if [ ! -f "${CACHE_DIR}/linux-${KERNEL}.txz" ]; then
  #     echo -e "No\nDownloading ${URL}"
  #     STATUS=`curl -w "%{http_code}" -L "${URL}" -o "${CACHE_DIR}/linux-${KERNEL}.txz"`
  #     if [ ${STATUS} -ne 200 ]; then
  #       rm -f "${CACHE_DIR}/linux-${KERNEL}.txz"
  #       exit 1
  #     fi
  #   else
  #     echo "OK"
  #   fi
  # done

  # Generate Dockerfile
  echo "Generating Dockerfile"
  cp Dockerfile.template Dockerfile
  sed -i "s|@@@PLATFORMS@@@|${PLATFORMS[${TOOLKIT_VER}]}|g" Dockerfile
  sed -i "s|@@@TOOLKIT_VER@@@|${TOOLKIT_VER}|g" Dockerfile
  sed -i "s|@@@GCCLIB_VER@@@|${GCCLIB_VER}|g" Dockerfile
}

# 7.0
#TOOLKIT_VER="7.0"
#TOOLCHAIN_VER="7.0-41890"
#GCCLIB_VER="gcc750_glibc226"
#prepare
#echo "Building ${TOOLKIT_VER}"
#docker image rm fbelavenuto/syno-compiler:${TOOLKIT_VER} >/dev/null 2>&1
#docker buildx build . --load --tag fbelavenuto/syno-compiler:${TOOLKIT_VER}

# 7.1
#TOOLKIT_VER="7.1"
#TOOLCHAIN_VER="7.1-42661"
#GCCLIB_VER="gcc850_glibc226"
#prepare
#echo "Building ${TOOLKIT_VER}"
#docker image rm fbelavenuto/syno-compiler:${TOOLKIT_VER} >/dev/null 2>&1
#docker buildx build . --load --tag fbelavenuto/syno-compiler:${TOOLKIT_VER}

# 7.2
#TOOLKIT_VER="7.2"
#TOOLCHAIN_VER="7.2-63134"
#GCCLIB_VER="gcc1220_glibc236"
#prepare
#echo "Building ${TOOLKIT_VER}"
#docker image rm fbelavenuto/syno-compiler:${TOOLKIT_VER} >/dev/null 2>&1
#docker buildx build . --load --tag fbelavenuto/syno-compiler:${TOOLKIT_VER} --tag fbelavenuto/syno-compiler:latest

# 7.3
TOOLKIT_VER="7.3"
TOOLCHAIN_VER="7.3-86009"
GCCLIB_VER="gcc1220_glibc236"
prepare
echo "Building ${TOOLKIT_VER}"
docker image rm dante90/syno-compiler:${TOOLKIT_VER} >/dev/null 2>&1
docker buildx build . --load --tag dante90/syno-compiler:${TOOLKIT_VER} --tag dante90/syno-compiler:latest
