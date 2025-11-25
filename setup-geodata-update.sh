#!/bin/bash

#==============================================================================
# Dae GeoIP/GeoSite 自动更新安装脚本
# 功能：一键安装更新脚本并配置 systemd 定时任务（每天早上8点执行）
#==============================================================================

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 配置变量
UPDATE_SCRIPT="/usr/local/bin/update-dae-geodata.sh"
SYSTEMD_SERVICE="/etc/systemd/system/update-geodata.service"
SYSTEMD_TIMER="/etc/systemd/system/update-geodata.timer"

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

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行，请使用 sudo 执行"
        exit 1
    fi
}

# 创建更新脚本
create_update_script() {
    log_info "创建 GeoIP/GeoSite 更新脚本: $UPDATE_SCRIPT"
    
    cat > "$UPDATE_SCRIPT" << 'SCRIPT_EOF'
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
BACKUP_DIR="${DAE_DATA_DIR}/backup"
TEMP_DIR="/tmp/dae-geodata-$$"

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
    if ! command -v curl &> /dev/null; then
        log_error "缺少 curl 工具"
        exit 1
    fi
}

# 创建必要目录
create_directories() {
    mkdir -p "$DAE_DATA_DIR"
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$TEMP_DIR"
}

# 备份现有文件
backup_existing_files() {
    local backup_timestamp=$(date +%Y%m%d_%H%M%S)
    
    [[ -f "${DAE_DATA_DIR}/geoip.dat" ]] && \
        cp "${DAE_DATA_DIR}/geoip.dat" "${BACKUP_DIR}/geoip.dat.${backup_timestamp}"
    
    [[ -f "${DAE_DATA_DIR}/geosite.dat" ]] && \
        cp "${DAE_DATA_DIR}/geosite.dat" "${BACKUP_DIR}/geosite.dat.${backup_timestamp}"
}

# 下载文件
download_and_verify_file() {
    local url=$1
    local output=$2
    local name=$3
    local sha256_url="${url}.sha256sum"
    local sha256_file="${output}.sha256sum"
    
    log_info "正在下载 ${name}..."
    
    if ! curl -L --retry 3 --retry-delay 5 -f -o "${output}" "${url}"; then
        log_error "${name} 下载失败"
        return 1
    fi
    
    local file_size=$(stat -c%s "$output" 2>/dev/null || stat -f%z "$output" 2>/dev/null)
    if [[ $file_size -lt 1000 ]]; then
        log_error "${name} 文件大小异常"
        return 1
    fi
    
    log_info "正在下载 ${name} SHA256 校验文件..."
    if ! curl -L --retry 3 --retry-delay 5 -f -o "${sha256_file}" "${sha256_url}"; then
        log_warn "${name} SHA256 校验文件下载失败，跳过校验"
        return 0
    fi
    
    log_info "正在验证 ${name} SHA256..."
    local expected_hash=$(cat "${sha256_file}" | awk '{print $1}')
    local actual_hash=$(sha256sum "${output}" | awk '{print $1}')
    
    if [[ "$expected_hash" == "$actual_hash" ]]; then
        log_info "${name} SHA256 校验通过"
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

check_file_needs_update() {
    local target_file=$1
    local sha256_url=$2
    local name=$3
    
    if [[ ! -f "$target_file" ]]; then
        log_info "${name} 本地文件不存在，需要下载"
        return 0
    fi
    
    local temp_sha256="${TEMP_DIR}/${name}.sha256sum"
    if ! curl -L --retry 3 --retry-delay 5 -f -o "${temp_sha256}" "${sha256_url}" 2>/dev/null; then
        log_warn "无法获取 ${name} 远程 SHA256，将强制更新"
        return 0
    fi
    
    local remote_hash=$(cat "${temp_sha256}" | awk '{print $1}')
    local local_hash=$(sha256sum "${target_file}" | awk '{print $1}')
    
    rm -f "${temp_sha256}"
    
    if [[ "$remote_hash" == "$local_hash" ]]; then
        log_info "${name} 已是最新版本（SHA256 匹配），跳过更新"
        return 1
    else
        log_info "${name} 发现新版本，需要更新"
        return 0
    fi
}

# 更新 GeoIP
update_geoip() {
    local temp_file="${TEMP_DIR}/geoip.dat"
    local target_file="${DAE_DATA_DIR}/geoip.dat"
    
    if download_file "$GEOIP_URL" "$temp_file" "GeoIP"; then
        mv "$temp_file" "$target_file"
        chmod 644 "$target_file"
        log_info "GeoIP 已更新"
        return 0
    fi
    return 1
}

# 更新 GeoSite
update_geosite() {
    local temp_file="${TEMP_DIR}/geosite.dat"
    local target_file="${DAE_DATA_DIR}/geosite.dat"
    
    if download_file "$GEOSITE_URL" "$temp_file" "GeoSite"; then
        mv "$temp_file" "$target_file"
        chmod 644 "$target_file"
        log_info "GeoSite 已更新"
        return 0
    fi
    return 1
}

# 重载 dae 服务
reload_dae() {
    if command -v dae &> /dev/null && systemctl is-active --quiet dae; then
        log_info "重载 dae 服务..."
        systemctl reload dae || systemctl restart dae
    fi
}

# 清理
cleanup() {
    [[ -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
    
    # 保留最近5个备份
    ls -t "${BACKUP_DIR}"/geoip.dat.* 2>/dev/null | tail -n +6 | xargs -r rm -f
    ls -t "${BACKUP_DIR}"/geosite.dat.* 2>/dev/null | tail -n +6 | xargs -r rm -f
}

# 主函数
main() {
    echo "=========================================="
    log_info "Dae GeoIP/GeoSite 自动更新"
    log_info "时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=========================================="
    
    trap cleanup EXIT
    
    check_dependencies
    create_directories
    backup_existing_files
    
    local success=true
    update_geoip || success=false
    update_geosite || success=false
    
    if [[ "$success" == true ]]; then
        reload_dae
        log_info "更新完成！"
        exit 0
    else
        log_error "更新失败"
        exit 1
    fi
}

main "$@"
SCRIPT_EOF

    chmod +x "$UPDATE_SCRIPT"
    log_info "更新脚本创建完成"
}

# 创建 systemd service
create_systemd_service() {
    log_info "创建 systemd service: $SYSTEMD_SERVICE"
    
    cat > "$SYSTEMD_SERVICE" << 'EOF'
[Unit]
Description=Update Dae GeoIP and GeoSite databases
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/update-dae-geodata.sh
Restart=on-failure
StandardOutput=journal
StandardError=journal
EOF

    log_info "systemd service 文件创建完成"
}

# 创建 systemd timer（每天早上8点执行）
create_systemd_timer() {
    log_info "创建 systemd timer: $SYSTEMD_TIMER"
    
    cat > "$SYSTEMD_TIMER" << 'EOF'
[Unit]
Description=Daily update of Dae GeoIP and GeoSite databases

[Timer]
# 每天早上 8:00 执行
OnCalendar=daily
OnCalendar=*-*-* 08:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

    log_info "systemd timer 文件创建完成（每天早上8点执行）"
}

# 启动服务
enable_and_start_timer() {
    log_info "重载 systemd daemon"
    systemctl daemon-reload
    
    log_info "启用并启动 update-geodata.timer"
    systemctl enable update-geodata.timer
    systemctl start update-geodata.timer
    
    log_info "检查 timer 状态"
    systemctl status update-geodata.timer --no-pager || true
}

# 显示使用说明
show_usage() {
    echo ""
    log_info "=========================================="
    log_info "安装完成！"
    log_info "=========================================="
    echo ""
    echo -e "${GREEN}定时任务：${NC}每天早上 8:00 自动执行"
    echo ""
    echo -e "${GREEN}常用命令：${NC}"
    echo ""
    echo -e "  ${YELLOW}# 手动执行一次更新${NC}"
    echo -e "  sudo systemctl start update-geodata.service"
    echo ""
    echo -e "  ${YELLOW}# 查看更新日志${NC}"
    echo -e "  sudo journalctl -u update-geodata.service -f"
    echo ""
    echo -e "  ${YELLOW}# 查看定时器状态${NC}"
    echo -e "  sudo systemctl status update-geodata.timer"
    echo ""
    echo -e "  ${YELLOW}# 查看下次执行时间${NC}"
    echo -e "  sudo systemctl list-timers update-geodata.timer"
    echo ""
    echo -e "  ${YELLOW}# 修改执行时间（编辑后需重载）${NC}"
    echo -e "  sudo nano /etc/systemd/system/update-geodata.timer"
    echo -e "  sudo systemctl daemon-reload"
    echo -e "  sudo systemctl restart update-geodata.timer"
    echo ""
    echo -e "${GREEN}数据文件位置：${NC}/usr/local/share/dae/"
    echo -e "${GREEN}备份文件位置：${NC}/usr/local/share/dae/backup/"
    echo ""
}

# 主函数
main() {
    echo ""
    log_info "=========================================="
    log_info "Dae GeoIP/GeoSite 自动更新安装向导"
    log_info "=========================================="
    echo ""
    
    check_root
    create_update_script
    create_systemd_service
    create_systemd_timer
    enable_and_start_timer
    show_usage
    
    log_info "脚本执行完成！"
}

main