#!/usr/bin/env bash

# Parallel Build Script for Synology Compiler
# Performance optimized version with parallel downloads and builds
# Usage: ./build-parallel.sh [DSM_VERSION] [COMMAND] [PLATFORM]
#   DSM_VERSION: 6.2, 7.0, 7.1, 7.2, 7.3, or 7.4 (default: from DSM_VERSION env or 7.3)
#   COMMAND: prepare, build, all, platforms (default: all)
#   PLATFORM: platform name for single build (default: all)

# Requires bash 4+ for associative arrays. macOS ships bash 3.2, where
# `declare -A` silently degrades and produces empty version/platform lookups.
if [ -z "${BASH_VERSINFO:-}" ] || [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    echo "❌ This script requires bash 4 or newer (found ${BASH_VERSION:-unknown})." >&2
    echo "   On macOS: brew install bash, then run with the newer bash." >&2
    exit 1
fi

CACHE_DIR="cache"
SERVER="https://global.synologydownload.com"
MAX_PARALLEL_JOBS=${MAX_PARALLEL_JOBS:-4}

declare -A URIS
declare -A PLATFORMS
declare -A TOOLCHAIN_VERS
declare -A GCCLIB_VERS

# URI templates (| is replaced by kernel version)
URIS["apollolake"]="Intel%20x86%20Linux%20|%20%28Apollolake%29"
URIS["avoton"]="Intel%20x86%20Linux%20|%20%28Avoton%29"
URIS["braswell"]="Intel%20x86%20Linux%20|%20%28Braswell%29"
URIS["broadwell"]="Intel%20x86%20Linux%20|%20%28Broadwell%29"
URIS["broadwellnk"]="Intel%20x86%20Linux%20|%20%28Broadwellnk%29"
URIS["broadwellnkv2"]="Intel%20x86%20Linux%20|%20%28Broadwellnkv2%29"
URIS["broadwellntbap"]="Intel%20x86%20Linux%20|%20%28Broadwellntbap%29"
URIS["bromolow"]="Intel%20x86%20linux%20|%20%28Bromolow%29"
URIS["cedarview"]="Intel%20x86%20Linux%20|%20%28Cedarview%29"
URIS["denverton"]="Intel%20x86%20Linux%20|%20%28Denverton%29"
URIS["geminilake"]="Intel%20x86%20Linux%20|%20%28GeminiLake%29"
URIS["purley"]="Intel%20x86%20Linux%20|%20%28Purley%29"
URIS["v1000"]="Intel%20x86%20Linux%20|%20%28V1000%29"
URIS["r1000"]="AMD%20x86%20Linux%20|%20%28r1000%29"
URIS["epyc7002"]="AMD%20x86%20Linux%20Linux%20|%20%28epyc7002%29"
URIS["geminilakenk"]="Intel%20x86%20Linux%20|%20%28geminilakenk%29"
URIS["icelaked"]="Intel%20x86%20Linux%20|%20%28icelaked%29"
URIS["v1000nk"]="AMD%20x86%20Linux%20|%20%28v1000nk%29"
URIS["r1000nk"]="AMD%20x86%20Linux%20|%20%28r1000nk%29"
URIS["epyc7003ntb"]="AMD%20x86%20Linux%20|%20%28epyc7003ntb%29"
# Note the doubled "Linux Linux" in the archive directory name (as with epyc7002)
URIS["epyc7003"]="AMD%20x86%20Linux%20Linux%20|%20%28epyc7003%29"

# Platform definitions per DSM version (platform:kernel_version)
PLATFORMS["6.2"]="apollolake:4.4.59 avoton:3.10.105 braswell:3.10.105 broadwell:3.10.105 broadwellnk:4.4.59 broadwellntbap:4.4.59 bromolow:3.10.105 cedarview:3.10.105 denverton:4.4.59 geminilake:4.4.59 purley:4.4.59 v1000:4.4.59"
PLATFORMS["7.0"]="apollolake:4.4.180 avoton:3.10.108 braswell:3.10.108 broadwell:4.4.180 broadwellnk:4.4.180 broadwellntbap:4.4.180 bromolow:3.10.108 cedarview:3.10.108 denverton:4.4.180 geminilake:4.4.180 purley:4.4.180 v1000:4.4.180"
PLATFORMS["7.1"]="apollolake:4.4.180 avoton:3.10.108 braswell:3.10.108 broadwell:4.4.180 broadwellnk:4.4.180 broadwellnkv2:4.4.180 broadwellntbap:4.4.180 bromolow:3.10.108 cedarview:3.10.108 denverton:4.4.180 geminilake:4.4.180 purley:4.4.180 r1000:4.4.180 v1000:4.4.180 epyc7002:5.10.55"
PLATFORMS["7.2"]="apollolake:4.4.180 avoton:3.10.108 braswell:3.10.108 broadwell:4.4.180 broadwellnk:4.4.302 broadwellnkv2:4.4.302 broadwellntbap:4.4.302 bromolow:3.10.108 denverton:4.4.302 geminilake:4.4.302 purley:4.4.302 r1000:4.4.302 v1000:4.4.302 epyc7002:5.10.55 geminilakenk:5.10.55 r1000nk:5.10.55 v1000nk:5.10.55"
PLATFORMS["7.3"]="apollolake:4.4.180 avoton:3.10.108 braswell:3.10.108 broadwell:4.4.180 broadwellnk:4.4.302 broadwellnkv2:4.4.302 broadwellntbap:4.4.302 bromolow:3.10.108 denverton:4.4.302 geminilake:4.4.302 purley:4.4.302 r1000:4.4.302 v1000:4.4.302 epyc7002:5.10.55 geminilakenk:5.10.55 r1000nk:5.10.55 v1000nk:5.10.55"
# DSM 7.4 (toolchain 7.4-90075): full 7.3 platform set + epyc7003 + epyc7003ntb + icelaked
PLATFORMS["7.4"]="apollolake:4.4.180 avoton:3.10.108 braswell:3.10.108 broadwell:4.4.180 broadwellnk:4.4.302 broadwellnkv2:4.4.302 broadwellntbap:4.4.302 bromolow:3.10.108 denverton:4.4.302 geminilake:4.4.302 purley:4.4.302 r1000:4.4.302 v1000:4.4.302 epyc7002:5.10.55 geminilakenk:5.10.55 r1000nk:5.10.55 v1000nk:5.10.55 epyc7003:5.10.55 epyc7003ntb:5.10.55 icelaked:5.10.55"

# Toolchain versions per DSM version
TOOLCHAIN_VERS["6.2"]="6.1-15284"
TOOLCHAIN_VERS["7.0"]="7.0-41890"
TOOLCHAIN_VERS["7.1"]="7.1-42661"
TOOLCHAIN_VERS["7.2"]="7.2-72806"
TOOLCHAIN_VERS["7.3"]="7.3-86009"
TOOLCHAIN_VERS["7.4"]="7.4-90075"

# GCC/glibc versions per DSM version
GCCLIB_VERS["6.2"]="gcc493_glibc220_linaro"
GCCLIB_VERS["7.0"]="gcc750_glibc226"
GCCLIB_VERS["7.1"]="gcc850_glibc226"
GCCLIB_VERS["7.2"]="gcc1220_glibc236"
GCCLIB_VERS["7.3"]="gcc1220_glibc236"
GCCLIB_VERS["7.4"]="gcc1220_glibc236"

###############################################################################
# Parse DSM version from first argument, env variable, or default
function resolve_dsm_version() {
    local ver="${1:-${DSM_VERSION:-7.3}}"

    # Validate version
    if [[ -z "${PLATFORMS[$ver]}" ]]; then
        echo "❌ Unsupported DSM version: ${ver}" >&2
        echo "   Supported versions: 6.2, 7.0, 7.1, 7.2, 7.3, 7.4" >&2
        exit 1
    fi

    TOOLKIT_VER="${ver}"
    TOOLCHAIN_VER="${TOOLCHAIN_VERS[$ver]}"
    GCCLIB_VER="${GCCLIB_VERS[$ver]}"

    echo "📋 DSM Version: ${TOOLKIT_VER}" >&2
    echo "   Toolchain:   ${TOOLCHAIN_VER}" >&2
    echo "   GCC/glibc:   ${GCCLIB_VER}" >&2
    echo "   Platforms:    $(echo ${PLATFORMS[$TOOLKIT_VER]} | wc -w | tr -d ' ') platform(s)" >&2
}

###############################################################################
# Output platform list as JSON array (for GitHub Actions dynamic matrix)
function list_platforms_json() {
    local platforms=""
    for P in ${PLATFORMS[${TOOLKIT_VER}]}; do
        local name=$(echo ${P} | cut -d':' -f1)
        if [ -n "$platforms" ]; then
            platforms="${platforms},\"${name}\""
        else
            platforms="\"${name}\""
        fi
    done
    echo "[${platforms}]"
}

mkdir -p ${CACHE_DIR}

###############################################################################
function trap_cancel() {
    echo "Press Control+C once more to terminate the process"
    pkill -P $$ 2>/dev/null
    sleep 2 || exit 1
}
trap trap_cancel SIGINT SIGTERM
cd `dirname $0`

###############################################################################
# Parallel download function
function download_file() {
    local url="$1"
    local output_file="$2"
    local description="$3"

    echo "📥 Downloading ${description}..."
    # Timeouts + retries so a stalled connection fails fast instead of hanging
    # the whole parallel batch forever (curl has no default transfer timeout).
    # --speed-time/--speed-limit: abort if <1KB/s for 60s (stall detection).
    if curl -L --fail --progress-bar \
        --connect-timeout 30 --max-time 1800 \
        --retry 3 --retry-delay 5 --retry-all-errors \
        --speed-limit 1024 --speed-time 60 \
        "${url}" -o "${output_file}.tmp"; then
        mv "${output_file}.tmp" "${output_file}"
        echo "✅ ${description} completed"
        return 0
    else
        echo "❌ Failed to download ${description}"
        rm -f "${output_file}.tmp"
        return 1
    fi
}

###############################################################################
function prepare_parallel() {
    # Optional target platform: "all" (default) or a single platform name.
    # When a single platform is given, only that platform's toolkit/toolchain
    # is downloaded, verified and baked into the generated Dockerfile — so the
    # resulting image is truly platform-specific rather than a fat all-in-one.
    local target="${1:-all}"
    local build_list
    if [ "${target}" = "all" ]; then
        build_list="${PLATFORMS[${TOOLKIT_VER}]}"
    else
        build_list=""
        for P in ${PLATFORMS[${TOOLKIT_VER}]}; do
            if [ "$(echo ${P} | cut -d':' -f1)" = "${target}" ]; then
                build_list="${P}"
                break
            fi
        done
        if [ -z "${build_list}" ]; then
            echo "❌ Platform '${target}' not found for DSM ${TOOLKIT_VER}" >&2
            echo "   Available: $(echo ${PLATFORMS[${TOOLKIT_VER}]} | tr ' ' '\n' | cut -d: -f1 | tr '\n' ' ')" >&2
            exit 1
        fi
    fi

    echo "🚀 Starting parallel preparation for toolkit version ${TOOLKIT_VER} (scope: ${target})"

    # Create download job list
    local job_list=()

    for P in ${build_list}; do
        PLATFORM="`echo ${P} | cut -d':' -f1`"
        KVER="`echo ${P} | cut -d':' -f2`"

        # Dev toolkit
        local dev_file="${CACHE_DIR}/ds.${PLATFORM}-${TOOLKIT_VER}.dev.txz"
        if [ ! -f "${dev_file}" ]; then
            local dev_url="${SERVER}/download/ToolChain/toolkit/${TOOLKIT_VER}/${PLATFORM}/ds.${PLATFORM}-${TOOLKIT_VER}.dev.txz"
            job_list+=("download_file|${dev_url}|${dev_file}|${PLATFORM} dev toolkit")
        else
            echo "✅ ${PLATFORM} dev toolkit already exists"
        fi

        # Toolchain
        local uri="`echo ${URIS[${PLATFORM}]} | sed "s/|/${KVER}/"`"
        local tc_url="${SERVER}/download/ToolChain/toolchain/${TOOLCHAIN_VER}/${uri}/${PLATFORM}-${GCCLIB_VER}_x86_64-GPL.txz"
        local tc_filename="${PLATFORM}-${GCCLIB_VER}_x86_64-GPL.txz"
        local tc_file="${CACHE_DIR}/${tc_filename}"

        if [ ! -f "${tc_file}" ]; then
            job_list+=("download_file|${tc_url}|${tc_file}|${PLATFORM} toolchain")
        else
            echo "✅ ${PLATFORM} toolchain already exists"
        fi
    done

    # Execute downloads in parallel
    if [ ${#job_list[@]} -gt 0 ]; then
        echo "📦 Starting ${#job_list[@]} parallel downloads with ${MAX_PARALLEL_JOBS} concurrent jobs"

        local pids=()
        local job_count=0

        for job in "${job_list[@]}"; do
            IFS='|' read -r func url file desc <<< "$job"

            # Wait if we've reached max parallel jobs
            while [ ${#pids[@]} -ge ${MAX_PARALLEL_JOBS} ]; do
                for i in "${!pids[@]}"; do
                    if ! kill -0 "${pids[$i]}" 2>/dev/null; then
                        wait "${pids[$i]}"
                        local exit_code=$?
                        unset "pids[$i]"
                        if [ $exit_code -ne 0 ]; then
                            echo "❌ Download failed, aborting..."
                            pkill -P $$
                            exit 1
                        fi
                    fi
                done
                # Remove finished jobs from array
                pids=($(printf '%s\n' "${pids[@]}" | grep -E '^[0-9]+$'))
                sleep 0.1
            done

            # Start new download in background
            download_file "$url" "$file" "$desc" &
            pids+=($!)
            ((job_count++))
        done

        # Wait for all remaining jobs
        for pid in "${pids[@]}"; do
            wait $pid
            if [ $? -ne 0 ]; then
                echo "❌ Download failed, aborting..."
                pkill -P $$
                exit 1
            fi
        done

        echo "🎉 All downloads completed successfully!"
    else
        echo "✅ All files already cached, skipping downloads"
    fi

    # List all downloaded files
    echo ""
    echo "📂 Downloaded files in ${CACHE_DIR}/:"
    echo "────────────────────────────────────────────────────────"
    local total_size=0
    for f in ${CACHE_DIR}/*.txz; do
        if [ -f "$f" ]; then
            local size=$(stat --printf="%s" "$f" 2>/dev/null || stat -f "%z" "$f" 2>/dev/null || echo 0)
            local size_mb=$(awk "BEGIN {printf \"%.1f\", ${size}/1048576}")
            printf "  %-60s %8s MB\n" "$(basename $f)" "${size_mb}"
            total_size=$((total_size + size))
        fi
    done
    local total_mb=$(awk "BEGIN {printf \"%.1f\", ${total_size}/1048576}")
    echo "────────────────────────────────────────────────────────"
    echo "  Total: ${total_mb} MB"
    echo ""

    # Verify all required files exist
    echo "🔍 Verifying required files for DSM ${TOOLKIT_VER}..."
    local missing=0
    for P in ${build_list}; do
        local plat=$(echo ${P} | cut -d':' -f1)

        # Check dev toolkit
        local dev_file="${CACHE_DIR}/ds.${plat}-${TOOLKIT_VER}.dev.txz"
        if [ ! -f "${dev_file}" ]; then
            echo "  ❌ MISSING: $(basename ${dev_file})"
            ((missing++))
        elif [ ! -s "${dev_file}" ]; then
            echo "  ❌ EMPTY:   $(basename ${dev_file})"
            ((missing++))
        else
            echo "  ✅ $(basename ${dev_file})"
        fi

        # Check toolchain
        local tc_file="${CACHE_DIR}/${plat}-${GCCLIB_VER}_x86_64-GPL.txz"
        if [ ! -f "${tc_file}" ]; then
            echo "  ❌ MISSING: $(basename ${tc_file})"
            ((missing++))
        elif [ ! -s "${tc_file}" ]; then
            echo "  ❌ EMPTY:   $(basename ${tc_file})"
            ((missing++))
        else
            echo "  ✅ $(basename ${tc_file})"
        fi
    done
    echo ""

    if [ ${missing} -gt 0 ]; then
        echo "❌ Verification failed: ${missing} file(s) missing or empty!"
        exit 1
    else
        echo "✅ All required files verified ($(echo ${build_list} | wc -w | tr -d ' ') platform(s), $(($(echo ${build_list} | wc -w | tr -d ' ') * 2)) files)"
    fi
    echo ""

    # Generate Dockerfile
    echo "📝 Generating Dockerfile..."
    cp Dockerfile.template Dockerfile
    sed -i "s|@@@PLATFORMS@@@|${build_list}|g" Dockerfile
    sed -i "s|@@@TOOLKIT_VER@@@|${TOOLKIT_VER}|g" Dockerfile
    sed -i "s|@@@GCCLIB_VER@@@|${GCCLIB_VER}|g" Dockerfile
}

###############################################################################
function build_image() {
    local tag_name="$1"
    local build_args="$2"

    echo "🔨 Building Docker image: ${tag_name}"
    echo "Build arguments: ${build_args}"

    # Remove existing image
    docker image rm "${tag_name}" >/dev/null 2>&1

    # Build with buildx for better performance
    if docker buildx build ${build_args} \
        --load \
        --tag "${tag_name}" \
        --progress=plain \
        --build-arg BUILDKIT_INLINE_CACHE=1 \
        . ; then
        echo "✅ Successfully built ${tag_name}"

        # Check if Docker Hub push is enabled
        if [ "$NO_DOCKER_PUSH" = "true" ]; then
            echo "ℹ️  Skipping Docker Hub push (NO_DOCKER_PUSH=true)"
        else
            echo "📤 Image ready for push to Docker Hub"
            echo "   To push: docker push ${tag_name}"
        fi

        return 0
    else
        echo "❌ Failed to build ${tag_name}"
        return 1
    fi
}

###############################################################################
# Determine DSM version: first arg if it looks like a version, else env/default
if [[ "${1}" =~ ^[0-9]+\.[0-9]+$ ]]; then
    resolve_dsm_version "${1}"
    shift
else
    resolve_dsm_version "${DSM_VERSION:-7.3}"
fi

case "${1:-all}" in
    "prepare")
        # Optional platform scope (default: all)
        prepare_parallel "${2:-all}"
        ;;
    "build")
        PLATFORM="${2:-all}"
        if [ "$PLATFORM" = "all" ]; then
            prepare_parallel all
            build_image "dante90/syno-compiler:${TOOLKIT_VER}" ""
            if [ "${TAG_LATEST}" = "true" ]; then
                build_image "dante90/syno-compiler:latest" ""
            fi
        else
            prepare_parallel "${PLATFORM}"
            build_image "dante90/syno-compiler:${TOOLKIT_VER}-${PLATFORM}" ""
        fi
        ;;
    "platforms")
        # Output platform list as JSON for GitHub Actions
        list_platforms_json
        ;;
    "all"|*)
        prepare_parallel all
        build_image "dante90/syno-compiler:${TOOLKIT_VER}" ""
        if [ "${TAG_LATEST}" = "true" ]; then
            build_image "dante90/syno-compiler:latest" ""
        fi
        echo "🚀 Build completed! Performance optimized with parallel downloads."
        ;;
esac
