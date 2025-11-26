#!/bin/bash

#==============================================================================
# Dae GeoIP/GeoSite 自动更新脚本
# 功能：自动下载并更新 GeoIP 和 GeoSite 数据库文件
# 基于：dae-installer 项目拆解
#==============================================================================

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置变量
DAE_DATA_DIR="/usr/local/share/dae"
GEOIP_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
GEOSITE_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"
TEMP_DIR="/tmp/dae-geodata-$$"

# curl 超时设置（秒）
CURL_TIMEOUT=120
CURL_CONNECT_TIMEOUT=30

# curl 重试设置
CURL_RETRY_TIMES=5
CURL_RETRY_DELAY=10

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 检查必要工具
check_dependencies() {
    if ! command -v curl > /dev/null 2>&1; then
        log_error "缺少 curl 工具"
        exit 1
    fi
}

# 创建必要目录
create_directories() {
    mkdir -p "$DAE_DATA_DIR"
    mkdir -p "$TEMP_DIR"
}

# 检查文件是否需要更新（比较SHA256）
check_file_needs_update() {
    local target_file=$1
    local sha256_url=$2
    local name=$3
    
    if [[ ! -f "$target_file" ]]; then
        log_info "${name} 本地文件不存在，需要下载"
        return 0
    fi
    
    local temp_sha256="${TEMP_DIR}/${name}.sha256sum"
    log_info "正在获取 ${name} 远程 SHA256..."
    
    if ! curl -L --connect-timeout $CURL_CONNECT_TIMEOUT --max-time $CURL_TIMEOUT \
         --retry $CURL_RETRY_TIMES --retry-delay $CURL_RETRY_DELAY -f -s -o "${temp_sha256}" "${sha256_url}" 2>/dev/null; then
        log_warn "无法获取 ${name} 远程 SHA256，将强制更新"
        return 0
    fi
    
    local remote_hash=$(cat "${temp_sha256}" 2>/dev/null | awk '{print $1}' | head -1)
    
    if [[ -z "$remote_hash" ]]; then
        log_warn "${name} SHA256 文件为空，将强制更新"
        rm -f "${temp_sha256}"
        return 0
    fi
    
    local local_hash=$(sha256sum "${target_file}" 2>/dev/null | awk '{print $1}')
    
    rm -f "${temp_sha256}"
    
    if [[ "$remote_hash" == "$local_hash" ]]; then
        log_info "${name} 已是最新版本（SHA256 匹配），跳过更新"
        return 1
    else
        log_info "${name} 发现新版本，需要更新"
        return 0
    fi
}

# 下载文件并验证SHA256
download_and_verify_file() {
    local url=$1
    local output=$2
    local name=$3
    local sha256_url="${url}.sha256sum"
    local sha256_file="${output}.sha256sum"
    
    log_info "正在下载 ${name}..."
    log_info "URL: ${url}"
    log_info "重试配置: ${CURL_RETRY_TIMES} 次，间隔 ${CURL_RETRY_DELAY} 秒"
    log_info "重试配置: ${CURL_RETRY_TIMES} 次，间隔 ${CURL_RETRY_DELAY} 秒"
    
    # 下载数据文件，带有进度条但无详细输出
    if ! curl -L --connect-timeout $CURL_CONNECT_TIMEOUT --max-time $CURL_TIMEOUT \
         --retry $CURL_RETRY_TIMES --retry-delay $CURL_RETRY_DELAY -f --progress-bar -o "${output}" "${url}"; then
        log_error "${name} 下载失败（已重试 ${CURL_RETRY_TIMES} 次）"
        [[ -f "${output}" ]] && rm -f "${output}"
        return 1
    fi
    
    # 验证文件大小
    local file_size=$(stat -c%s "$output" 2>/dev/null || stat -f%z "$output" 2>/dev/null)
    if [[ $file_size -lt 1000 ]]; then
        log_error "${name} 文件大小异常 (${file_size} bytes)，可能下载不完整"
        rm -f "${output}"
        return 1
    fi
    
    log_info "${name} 下载完成，文件大小: $(numfmt --to=iec-i --suffix=B $file_size 2>/dev/null || echo "$file_size bytes")"
    
    # 下载 SHA256 校验文件
    log_info "正在下载 ${name} SHA256 校验文件..."
    if ! curl -L --connect-timeout $CURL_CONNECT_TIMEOUT --max-time $CURL_TIMEOUT \
         --retry $CURL_RETRY_TIMES --retry-delay $CURL_RETRY_DELAY -f -s -o "${sha256_file}" "${sha256_url}"; then
        log_warn "${name} SHA256 校验文件下载失败，跳过验证"
        return 0
    fi
    
    # 验证 SHA256
    log_info "正在验证 ${name} SHA256..."
    local expected_hash=$(cat "${sha256_file}" 2>/dev/null | awk '{print $1}' | head -1)
    
    if [[ -z "$expected_hash" ]]; then
        log_warn "${name} SHA256 值为空，跳过验证"
        rm -f "${sha256_file}"
        return 0
    fi
    
    local actual_hash=$(sha256sum "${output}" | awk '{print $1}')
    
    if [[ "$expected_hash" == "$actual_hash" ]]; then
        log_info "${name} SHA256 校验通过 ✓"
        rm -f "${sha256_file}"
        return 0
    else
        log_error "${name} SHA256 校验失败"
        log_error "期望: ${expected_hash}"
        log_error "实际: ${actual_hash}"
        rm -f "${output}" "${sha256_file}"
        return 1
    fi
}

# 更新 GeoIP
update_geoip() {
    local temp_file="${TEMP_DIR}/geoip.dat"
    local target_file="${DAE_DATA_DIR}/geoip.dat"
    local sha256_url="${GEOIP_URL}.sha256sum"
    
    log_step "处理 GeoIP 文件..."
    
    # 检查是否需要更新
    if ! check_file_needs_update "$target_file" "$sha256_url" "GeoIP"; then
        return 0
    fi
    
    # 下载并验证
    if download_and_verify_file "$GEOIP_URL" "$temp_file" "GeoIP"; then
        mv "$temp_file" "$target_file"
        chmod 644 "$target_file"
        log_info "GeoIP 已成功更新"
        return 0
    fi
    return 1
}

# 更新 GeoSite
update_geosite() {
    local temp_file="${TEMP_DIR}/geosite.dat"
    local target_file="${DAE_DATA_DIR}/geosite.dat"
    local sha256_url="${GEOSITE_URL}.sha256sum"
    
    log_step "处理 GeoSite 文件..."
    
    # 检查是否需要更新
    if ! check_file_needs_update "$target_file" "$sha256_url" "GeoSite"; then
        return 0
    fi
    
    # 下载并验证
    if download_and_verify_file "$GEOSITE_URL" "$temp_file" "GeoSite"; then
        mv "$temp_file" "$target_file"
        chmod 644 "$target_file"
        log_info "GeoSite 已成功更新"
        return 0
    fi
    return 1
}

# 重载 dae 服务
reload_dae() {
    if command -v dae > /dev/null 2>&1 && systemctl is-active --quiet dae 2>/dev/null; then
        log_step "重载 dae 服务..."
        if systemctl reload dae 2>/dev/null; then
            log_info "dae 服务已重载"
        elif systemctl restart dae 2>/dev/null; then
            log_info "dae 服务已重启"
        else
            log_warn "dae 服务重载/重启失败"
        fi
    else
        log_warn "dae 服务未运行或未安装，跳过重载"
    fi
}

# 清理
cleanup() {
    [[ -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
}

# 主函数
main() {
    echo ""
    echo "=========================================="
    log_info "Dae GeoIP/GeoSite 自动更新"
    log_info "时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=========================================="
    echo ""
    
    trap cleanup EXIT
    
    check_dependencies
    create_directories
    
    local geoip_success=true
    local geosite_success=true
    
    update_geoip || geoip_success=false
    update_geosite || geosite_success=false
    
    echo ""
    echo "=========================================="
    
    if [[ "$geoip_success" == true ]] || [[ "$geosite_success" == true ]]; then
        reload_dae
        echo ""
        log_info "更新完成！"
        echo "=========================================="
        exit 0
    else
        log_error "更新失败"
        echo "=========================================="
        exit 1
    fi
}

main "$@"
