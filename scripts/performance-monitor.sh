#!/usr/bin/env bash

# Performance Monitoring Tool for Synology Docker Build
# Tracks build times, resource usage, and optimization metrics

PERF_LOG_DIR="logs/performance"
CURRENT_LOG="${PERF_LOG_DIR}/build_$(date +%Y%m%d_%H%M%S).log"

mkdir -p ${PERF_LOG_DIR}

###############################################################################
function log_perf() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a ${CURRENT_LOG}
}

###############################################################################
function start_monitoring() {
    local build_type="$1"
    
    log_perf "=== Performance Monitoring Started ==="
    log_perf "Build Type: ${build_type}"
    log_perf "Host: $(hostname)"
    log_perf "CPU Cores: $(nproc)"
    log_perf "Memory: $(free -h | grep Mem | awk '{print $2}')"
    log_perf "Disk Space: $(df -h . | tail -1 | awk '{print $4}') available"
    
    # System info
    log_perf "Docker Version: $(docker --version)"
    if command -v docker buildx >/dev/null 2>&1; then
        log_perf "Buildx Available: Yes"
    else
        log_perf "Buildx Available: No"
    fi
    
    # Start system monitoring in background
    monitor_system &
    local monitor_pid=$!
    echo $monitor_pid > ${PERF_LOG_DIR}/monitor.pid
    
    # Record start time
    echo $(date +%s) > ${PERF_LOG_DIR}/start_time
    
    log_perf "Monitoring started (PID: $monitor_pid)"
}

###############################################################################
function monitor_system() {
    while [ -f ${PERF_LOG_DIR}/monitor.pid ]; do
        local timestamp=$(date +%s)
        local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
        local mem_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
        local disk_io=$(iostat -d 1 2 | tail -1 | awk '{print $4","$5}' 2>/dev/null || echo "N/A,N/A")
        
        echo "${timestamp},${cpu_usage:-N/A},${mem_usage},${disk_io}" >> ${PERF_LOG_DIR}/system_metrics.csv
        sleep 5
    done
}

###############################################################################
function stop_monitoring() {
    local build_result="$1"
    
    # Stop system monitoring
    if [ -f ${PERF_LOG_DIR}/monitor.pid ]; then
        local monitor_pid=$(cat ${PERF_LOG_DIR}/monitor.pid)
        kill $monitor_pid 2>/dev/null
        rm -f ${PERF_LOG_DIR}/monitor.pid
    fi
    
    # Calculate total time
    if [ -f ${PERF_LOG_DIR}/start_time ]; then
        local start_time=$(cat ${PERF_LOG_DIR}/start_time)
        local end_time=$(date +%s)
        local total_seconds=$((end_time - start_time))
        local minutes=$((total_seconds / 60))
        local seconds=$((total_seconds % 60))
        
        log_perf "=== Performance Summary ==="
        log_perf "Build Result: ${build_result}"
        log_perf "Total Time: ${minutes}m ${seconds}s"
        log_perf "End Time: $(date)"
        
        rm -f ${PERF_LOG_DIR}/start_time
    fi
    
    # Generate performance report
    generate_report
}

###############################################################################
function measure_download_speed() {
    local url="$1"
    local description="$2"
    
    log_perf "📊 Measuring download speed for: ${description}"
    
    local start_time=$(date +%s.%N)
    local temp_file=$(mktemp)
    
    if curl -w "%{speed_download},%{time_total},%{size_download}\n" \
           -s -L "${url}" -o "${temp_file}" -r 0-1048576; then  # Download first 1MB for speed test
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc)
        
        # Clean up
        rm -f "${temp_file}"
        
        log_perf "   Speed test completed in ${duration}s"
    else
        log_perf "   ❌ Speed test failed"
        rm -f "${temp_file}"
    fi
}

###############################################################################
function benchmark_parallel_vs_sequential() {
    log_perf "=== Parallel vs Sequential Benchmark ==="
    
    local test_urls=(
        "https://httpbin.org/delay/1"
        "https://httpbin.org/delay/2"
        "https://httpbin.org/delay/1"
        "https://httpbin.org/delay/2"
    )
    
    # Sequential test
    log_perf "🔄 Testing sequential downloads..."
    local seq_start=$(date +%s.%N)
    for url in "${test_urls[@]}"; do
        curl -s "${url}" > /dev/null
    done
    local seq_end=$(date +%s.%N)
    local seq_time=$(echo "$seq_end - $seq_start" | bc)
    
    # Parallel test
    log_perf "⚡ Testing parallel downloads..."
    local par_start=$(date +%s.%N)
    (
        for url in "${test_urls[@]}"; do
            curl -s "${url}" > /dev/null &
        done
        wait
    )
    local par_end=$(date +%s.%N)
    local par_time=$(echo "$par_end - $par_start" | bc)
    
    # Calculate improvement
    local improvement=$(echo "scale=1; ($seq_time - $par_time) / $seq_time * 100" | bc)
    
    log_perf "📈 Benchmark Results:"
    log_perf "   Sequential: ${seq_time}s"
    log_perf "   Parallel:   ${par_time}s"
    log_perf "   Improvement: ${improvement}% faster"
}

###############################################################################
function generate_report() {
    local report_file="${PERF_LOG_DIR}/performance_report.md"
    
    cat > ${report_file} << EOF
# 🚀 Synology Docker Build Performance Report

**Generated:** $(date)  
**Build Log:** $(basename ${CURRENT_LOG})

## ⏱️ Build Timeline

$(tail -20 ${CURRENT_LOG})

## 📊 System Metrics

$(if [ -f ${PERF_LOG_DIR}/system_metrics.csv ]; then
    echo "| Time | CPU % | Memory % | Disk I/O |"
    echo "|------|--------|----------|----------|"
    tail -10 ${PERF_LOG_DIR}/system_metrics.csv | while IFS=',' read timestamp cpu mem io; do
        local readable_time=$(date -d @${timestamp} +"%H:%M:%S")
        echo "| ${readable_time} | ${cpu}% | ${mem}% | ${io} |"
    done
else
    echo "No system metrics available"
fi)

## 💡 Performance Recommendations

EOF

    # Add recommendations based on metrics
    if [ -f ${PERF_LOG_DIR}/system_metrics.csv ]; then
        local avg_cpu=$(awk -F',' '{sum+=$2; count++} END {print sum/count}' ${PERF_LOG_DIR}/system_metrics.csv 2>/dev/null)
        local avg_mem=$(awk -F',' '{sum+=$3; count++} END {print sum/count}' ${PERF_LOG_DIR}/system_metrics.csv 2>/dev/null)
        
        if (( $(echo "$avg_cpu > 80" | bc -l) )); then
            echo "- ⚠️ High CPU usage detected (${avg_cpu}%). Consider reducing parallel jobs." >> ${report_file}
        fi
        
        if (( $(echo "$avg_mem > 80" | bc -l) )); then
            echo "- ⚠️ High memory usage detected (${avg_mem}%). Monitor memory limits." >> ${report_file}
        fi
    fi
    
    echo "- ✅ Use \`build-parallel.sh\` for optimal performance" >> ${report_file}
    echo "- 📦 Run \`cache-manager.sh optimize\` regularly" >> ${report_file}
    echo "- 🔄 Enable Docker BuildKit: \`export DOCKER_BUILDKIT=1\`" >> ${report_file}
    
    log_perf "📋 Performance report generated: ${report_file}"
}

###############################################################################
function show_historical_performance() {
    log_perf "=== Historical Performance Analysis ==="
    
    local log_files=($(find ${PERF_LOG_DIR} -name "build_*.log" | sort))
    
    if [ ${#log_files[@]} -eq 0 ]; then
        log_perf "No historical data available"
        return
    fi
    
    log_perf "📈 Build History (last 10 builds):"
    log_perf "| Date | Duration | Result |"
    log_perf "|------|----------|---------|"
    
    for log_file in "${log_files[@]: -10}"; do
        local date_str=$(basename "$log_file" .log | cut -d'_' -f2- | sed 's/_/ /')
        local duration=$(grep "Total Time:" "$log_file" | awk '{print $4" "$5}')
        local result=$(grep "Build Result:" "$log_file" | awk '{print $3}')
        
        log_perf "| ${date_str} | ${duration:-N/A} | ${result:-Unknown} |"
    done
}

###############################################################################
function cleanup_old_logs() {
    local days=${1:-7}
    log_perf "🧹 Cleaning performance logs older than ${days} days"
    
    find ${PERF_LOG_DIR} -name "*.log" -mtime +${days} -delete
    find ${PERF_LOG_DIR} -name "*.csv" -mtime +${days} -delete
    
    log_perf "✅ Old logs cleanup completed"
}

###############################################################################
# Main execution
case "${1:-help}" in
    "start")
        start_monitoring "$2"
        ;;
    "stop")
        stop_monitoring "$2"
        ;;
    "benchmark")
        benchmark_parallel_vs_sequential
        ;;
    "report")
        generate_report
        ;;
    "history")
        show_historical_performance
        ;;
    "cleanup")
        cleanup_old_logs "$2"
        ;;
    "help"|*)
        cat << EOF
🔍 Performance Monitor for Synology Docker Build

Usage: $0 [command] [options]

Commands:
  start [build_type]    Start monitoring (run before build)
  stop [result]         Stop monitoring and generate report
  benchmark            Run parallel vs sequential benchmark
  report               Generate current performance report
  history              Show historical performance data
  cleanup [days]       Clean logs older than [days] (default: 7)

Integration Example:
  ./performance-monitor.sh start "parallel-build"
  ./build-parallel.sh all
  ./performance-monitor.sh stop "success"

EOF
        ;;
esac