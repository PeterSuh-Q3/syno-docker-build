#!/usr/bin/env bash

# Parallel Build Script for Synology Compiler - DSM 6.2 Only
# Performance optimized version with parallel downloads and builds
#
# Download sources (mixed):
#   - Toolchain (.txz)   : SourceForge (DSM 6.2.4 Tool Chains)
#   - Dev toolkit (.txz) : Synology global download server
#
# Usage: ./build-parallel-62.sh [COMMAND] [PLATFORM]
#   COMMAND: prepare, build, platforms, all (default: all)
#   PLATFORM: platform name for single build (default: all)

CACHE_DIR="cache"
MAX_PARALLEL_JOBS=${MAX_PARALLEL_JOBS:-4}

# DSM 6.2 fixed constants
TOOLKIT_VER="6.2"
GCCLIB_VER="gcc493_glibc220_linaro"

# Toolchain source: SourceForge (DSM 6.2.4 Tool Chains)
SF_BASE="https://sourceforge.net/projects/dsgpl/files/Tool%20Chain/DSM%206.2.4%20Tool%20Chains"

# Dev toolkit source: Synology global download server
SYNO_SERVER="https://global.synologydownload.com"

# SourceForge directory names per platform (kernel version already embedded)
declare -A SF_DIRS
SF_DIRS["apollolake"]="Intel%20x86%20Linux%204.4.59%20%28Apollolake%29"
SF_DIRS["avoton"]="Intel%20x86%20Linux%203.10.105%20%28Avoton%29"
SF_DIRS["braswell"]="Intel%20x86%20Linux%203.10.105%20%28Braswell%29"
SF_DIRS["broadwell"]="Intel%20x86%20Linux%203.10.105%20%28Broadwell%29"
SF_DIRS["broadwellnk"]="Intel%20x86%20Linux%204.4.59%20%28Broadwellnk%29"
SF_DIRS["broadwellntbap"]="Intel%20x86%20Linux%204.4.59%20%28Broadwellntbap%29"
SF_DIRS["bromolow"]="Intel%20x86%20linux%203.10.105%20%28Bromolow%29"
SF_DIRS["cedarview"]="Intel%20x86%20Linux%203.10.105%20%28Cedarview%29"
SF_DIRS["denverton"]="Intel%20x86%20Linux%204.4.59%20%28Denverton%29"
SF_DIRS["geminilake"]="Intel%20x86%20Linux%204.4.59%20%28GeminiLake%29"
SF_DIRS["purley"]="Intel%20x86%20Linux%204.4.59%20%28Purley%29"
SF_DIRS["v1000"]="Intel%20x86%20Linux%204.4.59%20%28V1000%29"

# DSM 6.2 platform list (platform:kernel_version)
PLATFORM_LIST="apollolake:4.4.59 avoton:3.10.105 braswell:3.10.105 broadwell:3.10.105 broadwellnk:4.4.59 broadwellntbap:4.4.59 bromolow:3.10.105 cedarview:3.10.105 denverton:4.4.59 geminilake:4.4.59 purley:4.4.59 v1000:4.4.59"

###############################################################################
function print_info() {
    echo "📋 DSM Version: ${TOOLKIT_VER}" >&2
    echo "   GCC/glibc:   ${GCCLIB_VER}" >&2
    echo "   Toolchain:   SourceForge (DSM 6.2.4 Tool Chains)" >&2
    echo "   Dev toolkit: Synology global download server" >&2
    echo "   Platforms:   $(echo ${PLATFORM_LIST} | wc -w | tr -d ' ') platform(s)" >&2
}

###############################################################################
# Output platform list as JSON array (for GitHub Actions dynamic matrix)
function list_platforms_json() {
    local platforms=""
    for P in ${PLATFORM_LIST}; do
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
cd "$(dirname $0)"

###############################################################################
# Parallel download function
function download_file() {
    local url="$1"
    local output_file="$2"
    local description="$3"

    echo "📥 Downloading ${description}..."
    if curl -L --fail --progress-bar "${url}" -o "${output_file}.tmp"; then
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
    echo "🚀 Starting parallel preparation for DSM ${TOOLKIT_VER}"
    print_info

    # Create download job list
    local job_list=()

    for P in ${PLATFORM_LIST}; do
        local PLATFORM="$(echo ${P} | cut -d':' -f1)"

        # --- Dev toolkit (Synology server) ---
        # URL: {SYNO_SERVER}/download/ToolChain/toolkit/{TOOLKIT_VER}/{PLATFORM}/ds.{PLATFORM}-{TOOLKIT_VER}.dev.txz
        local dev_file="${CACHE_DIR}/ds.${PLATFORM}-${TOOLKIT_VER}.dev.txz"
        if [ ! -f "${dev_file}" ]; then
            local dev_url="${SYNO_SERVER}/download/ToolChain/toolkit/${TOOLKIT_VER}/${PLATFORM}/ds.${PLATFORM}-${TOOLKIT_VER}.dev.txz"
            job_list+=("download_file|${dev_url}|${dev_file}|${PLATFORM} dev toolkit [Synology]")
        else
            echo "✅ ${PLATFORM} dev toolkit already exists"
        fi

        # --- Toolchain (SourceForge) ---
        # URL: {SF_BASE}/{SF_DIR}/{PLATFORM}-{GCCLIB_VER}_x86_64-GPL.txz/download
        local tc_filename="${PLATFORM}-${GCCLIB_VER}_x86_64-GPL.txz"
        local tc_file="${CACHE_DIR}/${tc_filename}"
        local tc_url="${SF_BASE}/${SF_DIRS[${PLATFORM}]}/${tc_filename}/download"

        if [ ! -f "${tc_file}" ]; then
            job_list+=("download_file|${tc_url}|${tc_file}|${PLATFORM} toolchain [SourceForge]")
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
    for P in ${PLATFORM_LIST}; do
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

    local plat_count=$(echo ${PLATFORM_LIST} | wc -w | tr -d ' ')
    if [ ${missing} -gt 0 ]; then
        echo "❌ Verification failed: ${missing} file(s) missing or empty!"
        exit 1
    else
        echo "✅ All required files verified (${plat_count} platforms, $((plat_count * 2)) files)"
    fi
    echo ""

    # Generate Dockerfile
    echo "📝 Generating Dockerfile..."
    cp Dockerfile.template Dockerfile
    sed -i "s|@@@PLATFORMS@@@|${PLATFORM_LIST}|g" Dockerfile
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
# Main
print_info

case "${1:-all}" in
    "prepare")
        prepare_parallel
        ;;
    "build")
        TARGET_PLATFORM="${2:-all}"
        if [ "$TARGET_PLATFORM" = "all" ]; then
            prepare_parallel
            build_image "dante90/syno-compiler:${TOOLKIT_VER}" ""
            if [ "${TAG_LATEST}" = "true" ]; then
                build_image "dante90/syno-compiler:latest" ""
            fi
        else
            prepare_parallel
            build_image "dante90/syno-compiler:${TOOLKIT_VER}-${TARGET_PLATFORM}" \
                "--build-arg TARGET_PLATFORM=${TARGET_PLATFORM}"
        fi
        ;;
    "platforms")
        list_platforms_json
        ;;
    "all"|*)
        prepare_parallel
        build_image "dante90/syno-compiler:${TOOLKIT_VER}" ""
        if [ "${TAG_LATEST}" = "true" ]; then
            build_image "dante90/syno-compiler:latest" ""
        fi
        echo "🚀 Build completed! Performance optimized with parallel downloads."
        ;;
esac
