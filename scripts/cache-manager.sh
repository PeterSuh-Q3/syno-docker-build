#!/usr/bin/env bash

# Cache Management Tool for Synology Docker Build
# Optimizes cache usage and manages download artifacts

CACHE_DIR="cache"
LOG_FILE="cache/cache_management.log"

mkdir -p ${CACHE_DIR}

###############################################################################
function log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a ${LOG_FILE}
}

###############################################################################
function show_cache_status() {
    log_message "=== Cache Status Report ==="
    
    if [ ! -d "${CACHE_DIR}" ] || [ -z "$(ls -A ${CACHE_DIR} 2>/dev/null)" ]; then
        log_message "📁 Cache directory is empty"
        return 0
    fi
    
    local total_size=$(du -sh ${CACHE_DIR} 2>/dev/null | cut -f1)
    local file_count=$(find ${CACHE_DIR} -type f | wc -l)
    
    log_message "📊 Cache Statistics:"
    log_message "   Total Size: ${total_size}"
    log_message "   File Count: ${file_count}"
    log_message ""
    log_message "📋 Cached Files:"
    
    find ${CACHE_DIR} -type f -name "*.txz" | while read file; do
        local size=$(du -sh "$file" 2>/dev/null | cut -f1)
        local age=$(stat -c %Y "$file" 2>/dev/null)
        local current_time=$(date +%s)
        local days_old=$(( (current_time - age) / 86400 ))
        
        log_message "   $(basename "$file") - ${size} (${days_old} days old)"
    done
}

###############################################################################
function validate_cache() {
    log_message "=== Cache Validation ==="
    
    local corrupted_files=()
    local validation_passed=0
    local validation_failed=0
    
    find ${CACHE_DIR} -type f -name "*.txz" | while read file; do
        if tar -tf "$file" >/dev/null 2>&1; then
            log_message "✅ Valid: $(basename "$file")"
            ((validation_passed++))
        else
            log_message "❌ Corrupted: $(basename "$file")"
            corrupted_files+=("$file")
            ((validation_failed++))
        fi
    done
    
    if [ ${#corrupted_files[@]} -gt 0 ]; then
        log_message "🚨 Found ${#corrupted_files[@]} corrupted files"
        log_message "Run 'cache-manager.sh clean-corrupted' to remove them"
        return 1
    else
        log_message "✅ All cache files are valid"
        return 0
    fi
}

###############################################################################
function clean_old_cache() {
    local days=${1:-30}
    log_message "=== Cleaning Cache Older Than ${days} Days ==="
    
    local cleaned_files=0
    local freed_space=0
    
    find ${CACHE_DIR} -type f -name "*.txz" -mtime +${days} | while read file; do
        local size=$(du -b "$file" 2>/dev/null | cut -f1)
        log_message "🗑️  Removing old file: $(basename "$file")"
        rm -f "$file"
        ((cleaned_files++))
        ((freed_space+=size))
    done
    
    if [ $cleaned_files -gt 0 ]; then
        local freed_mb=$((freed_space / 1024 / 1024))
        log_message "✅ Cleaned ${cleaned_files} files, freed ${freed_mb}MB"
    else
        log_message "✅ No old files to clean"
    fi
}

###############################################################################
function clean_corrupted() {
    log_message "=== Removing Corrupted Files ==="
    
    local removed_files=0
    
    find ${CACHE_DIR} -type f -name "*.txz" | while read file; do
        if ! tar -tf "$file" >/dev/null 2>&1; then
            log_message "🗑️  Removing corrupted: $(basename "$file")"
            rm -f "$file"
            ((removed_files++))
        fi
    done
    
    if [ $removed_files -gt 0 ]; then
        log_message "✅ Removed ${removed_files} corrupted files"
    else
        log_message "✅ No corrupted files found"
    fi
}

###############################################################################
function optimize_cache() {
    log_message "=== Cache Optimization ==="
    
    # Remove duplicates (if any)
    log_message "🔍 Checking for duplicate files..."
    find ${CACHE_DIR} -type f -name "*.txz" -exec md5sum {} \; | \
    sort | uniq -d -w32 | while read hash file; do
        log_message "🗑️  Found duplicate: $(basename "$file")"
        # Keep first occurrence, remove others
        find ${CACHE_DIR} -type f -exec md5sum {} \; | \
        grep "^$hash" | tail -n +2 | cut -d' ' -f3- | while read dup_file; do
            log_message "   Removing duplicate: $(basename "$dup_file")"
            rm -f "$dup_file"
        done
    done
    
    # Compress logs if they get too large
    if [ -f "${LOG_FILE}" ] && [ $(stat -c%s "${LOG_FILE}") -gt 1048576 ]; then
        log_message "📦 Compressing large log file"
        gzip "${LOG_FILE}"
        touch "${LOG_FILE}"
    fi
    
    log_message "✅ Cache optimization completed"
}

###############################################################################
function warm_cache() {
    log_message "=== Cache Warming ==="
    log_message "🔥 Pre-downloading frequently used toolkits..."
    
    # Use the build script to prepare cache
    if [ -x "./build-parallel.sh" ]; then
        ./build-parallel.sh prepare
    else
        log_message "⚠️  build-parallel.sh not found or not executable"
    fi
}

###############################################################################
function show_help() {
    cat << EOF
🛠️  Cache Manager for Synology Docker Build

Usage: $0 [command]

Commands:
  status          Show cache status and statistics
  validate        Check cache file integrity
  clean [days]    Remove files older than [days] (default: 30)
  clean-corrupted Remove corrupted cache files
  optimize        Remove duplicates and optimize cache
  warm           Pre-download cache files
  help           Show this help message

Performance Tips:
  - Run 'status' regularly to monitor cache health
  - Use 'validate' before important builds
  - Run 'optimize' weekly to maintain efficiency
  - Use 'warm' before batch builds

Examples:
  $0 status                    # Show current cache status
  $0 clean 7                   # Clean files older than 7 days
  $0 validate && $0 optimize   # Validate then optimize cache

EOF
}

###############################################################################
# Main execution
case "${1:-status}" in
    "status")
        show_cache_status
        ;;
    "validate")
        validate_cache
        ;;
    "clean")
        clean_old_cache "$2"
        ;;
    "clean-corrupted")
        clean_corrupted
        ;;
    "optimize")
        optimize_cache
        ;;
    "warm")
        warm_cache
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        log_message "❌ Unknown command: $1"
        show_help
        exit 1
        ;;
esac