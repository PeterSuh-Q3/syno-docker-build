#!/usr/bin/env bash

# Parallel Build Script for Synology Compiler 7.3
# Performance optimized version with parallel downloads and builds

CACHE_DIR="cache"
SERVER="https://global.download.synology.com"
MAX_PARALLEL_JOBS=${MAX_PARALLEL_JOBS:-4}

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
URIS["geminilakenk"]="Intel%20x86%20Linux%20|%20%28GeminiLakenk%29"
URIS["v1000nk"]="Intel%20x86%20Linux%20|%20%28V1000nk%29"
URIS["r1000nk"]="AMD%20x86%20Linux%20|%20%28r1000nk%29"

PLATFORMS["7.3"]="epyc7002:5.10.55 geminilakenk:5.10.55 r1000nk:5.10.55 v1000nk:5.10.55"

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
    echo "🚀 Starting parallel preparation for toolkit version ${TOOLKIT_VER}"
    
    # Create download job list
    local job_list=()
    
    for P in ${PLATFORMS[${TOOLKIT_VER}]}; do
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
    
    # Generate Dockerfile
    echo "📝 Generating Dockerfile..."
    cp Dockerfile.template Dockerfile
    sed -i "s|@@@PLATFORMS@@@|${PLATFORMS[${TOOLKIT_VER}]}|g" Dockerfile
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
        return 0
    else
        echo "❌ Failed to build ${tag_name}"
        return 1
    fi
}

###############################################################################
# Main execution for 7.3
TOOLKIT_VER="7.3"
TOOLCHAIN_VER="7.3-86009"
GCCLIB_VER="gcc1220_glibc236"

case "${1:-all}" in
    "prepare")
        prepare_parallel
        ;;
    "build")
        PLATFORM="${2:-all}"
        if [ "$PLATFORM" = "all" ]; then
            prepare_parallel
            build_image "dante90/syno-compiler:${TOOLKIT_VER}" ""
            build_image "dante90/syno-compiler:latest" ""
        else
            prepare_parallel
            build_image "dante90/syno-compiler:${TOOLKIT_VER}-${PLATFORM}" "--build-arg TARGET_PLATFORM=${PLATFORM}"
        fi
        ;;
    "all"|*)
        prepare_parallel
        build_image "dante90/syno-compiler:${TOOLKIT_VER}" ""
        build_image "dante90/syno-compiler:latest" ""
        echo "🚀 Build completed! Performance optimized with parallel downloads."
        ;;
esac