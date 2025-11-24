#!/bin/bash

#==============================================================================
# Dae 订阅自动更新一键配置脚本
# 功能：自动创建订阅更新脚本、systemd服务和定时器，实现订阅自动更新
#==============================================================================

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 配置变量
DAE_CONFIG_DIR="/usr/local/etc/dae"
UPDATE_SCRIPT="/usr/local/bin/update-dae-subs.sh"
SYSTEMD_SERVICE="/etc/systemd/system/update-subs.service"
SYSTEMD_TIMER="/etc/systemd/system/update-subs.timer"
SUBLIST_FILE="${DAE_CONFIG_DIR}/sublist"
CONFIG_FILE="${DAE_CONFIG_DIR}/config.dae"

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

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行，请使用 sudo 执行"
        exit 1
    fi
}

# 检查dae是否已安装
check_dae() {
    if ! command -v dae &> /dev/null; then
        log_error "未检测到 dae 命令，请先安装 dae"
        exit 1
    fi
    log_info "检测到 dae 版本: $(dae --version | head -n 1)"
}

# 检查systemd
check_systemd() {
    if ! command -v systemctl &> /dev/null; then
        log_error "未检测到 systemd，此脚本需要 systemd 支持"
        exit 1
    fi
}

# 创建配置目录
create_config_dir() {
    if [[ ! -d "$DAE_CONFIG_DIR" ]]; then
        log_info "创建配置目录: $DAE_CONFIG_DIR"
        mkdir -p "$DAE_CONFIG_DIR"
    fi
}

# 备份现有配置
backup_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        local backup_file="${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        log_info "备份现有配置文件到: $backup_file"
        cp "$CONFIG_FILE" "$backup_file"
    fi
    
    if [[ -f "$SUBLIST_FILE" ]]; then
        local backup_file="${SUBLIST_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        log_info "备份现有订阅列表到: $backup_file"
        cp "$SUBLIST_FILE" "$backup_file"
    fi
}

# 创建订阅更新脚本
create_update_script() {
    log_info "创建订阅更新脚本: $UPDATE_SCRIPT"
    
    cat > "$UPDATE_SCRIPT" << 'EOF'
#!/bin/bash

# Change the path to suit your needs
cd /usr/local/etc/dae || exit 1
version="$(dae --version | head -n 1 | sed 's/dae version //')"
UA="dae/${version} (like v2rayA/1.0 WebRequestHelper) (like v2rayN/1.0 WebRequestHelper)"
fail=false

while IFS=':' read -r name url
do
        curl --retry 3 --retry-delay 5 -fL -A "$UA" "$url" -o "${name}.sub.new"
        if [[ $? -eq 0 ]]; then
                mv "${name}.sub.new" "${name}.sub"
                chmod 0600 "${name}.sub"
                echo "Downloaded $name"
        else
                if [ -f "${name}.sub.new" ]; then
                        rm "${name}.sub.new"
                fi
                fail=true
                echo "Failed to download $name"
        fi
done < sublist

dae reload

if $fail; then
        echo "Failed to update some subs"
        exit 2
fi
EOF

    chmod +x "$UPDATE_SCRIPT"
    log_info "订阅更新脚本创建完成并已设置可执行权限"
}

# 创建 systemd service 文件
create_systemd_service() {
    log_info "创建 systemd service: $SYSTEMD_SERVICE"
    
    cat > "$SYSTEMD_SERVICE" << 'EOF'
[Unit]
Description=Update dae subscriptions
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/update-dae-subs.sh
Restart=on-failure
EOF

    log_info "systemd service 文件创建完成"
}

# 创建 systemd timer 文件
create_systemd_timer() {
    log_info "创建 systemd timer: $SYSTEMD_TIMER"
    
    cat > "$SYSTEMD_TIMER" << 'EOF'
[Unit]
Description=Auto-update dae subscriptions

[Timer]
OnBootSec=15min
OnUnitActiveSec=12h

[Install]
WantedBy=timers.target
EOF

    log_info "systemd timer 文件创建完成"
}

# 创建订阅列表模板
create_sublist_template() {
    if [[ -f "$SUBLIST_FILE" ]]; then
        log_warn "订阅列表文件已存在，跳过创建模板"
        return
    fi
    
    log_info "创建订阅列表模板: $SUBLIST_FILE"
    
    cat > "$SUBLIST_FILE" << 'EOF'
# 订阅列表格式: 名称:订阅链接
# 示例:
# sub1:https://mysub1.com/subscribe?token=xxx
# sub2:https://mysub2.com/subscribe?token=yyy
# 
# 请在下方添加你的订阅链接（删除 # 注释符号）：
# sub1:https://your-subscription-url-here
EOF

    chmod 0600 "$SUBLIST_FILE"
    log_info "订阅列表模板创建完成，权限已设置为 0600"
    log_warn "请编辑 $SUBLIST_FILE 文件，添加你的订阅链接"
}

# 更新 config.dae 配置文件
update_config_dae() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_warn "未找到 config.dae 文件，跳过自动配置"
        log_warn "请手动在 $CONFIG_FILE 中配置 subscription 部分"
        return
    fi
    
    log_info "检查 config.dae 中的 subscription 配置"
    
    # 检查是否已经配置为 file:// 格式
    if grep -q "file://" "$CONFIG_FILE"; then
        log_warn "检测到 config.dae 已包含 file:// 订阅配置，跳过自动修改"
        log_warn "如需修改，请手动编辑 $CONFIG_FILE"
        return
    fi
    
    log_warn "需要手动修改 $CONFIG_FILE 中的 subscription 配置"
    log_warn "请将 subscription 部分修改为以下格式："
    echo ""
    echo -e "${YELLOW}subscription {${NC}"
    echo -e "${YELLOW}    # 根据你的 sublist 文件中的订阅名称修改${NC}"
    echo -e "${YELLOW}    sub1:'file://sub1.sub'${NC}"
    echo -e "${YELLOW}    sub2:'file://sub2.sub'${NC}"
    echo -e "${YELLOW}    sub3:'file://sub3.sub'${NC}"
    echo -e "${YELLOW}}${NC}"
    echo ""
}

# 重载 systemd 并启动服务
enable_and_start_timer() {
    log_info "重载 systemd daemon"
    systemctl daemon-reload
    
    log_info "启用并启动 update-subs.timer"
    systemctl enable --now update-subs.timer
    
    log_info "检查 timer 状态"
    systemctl status update-subs.timer --no-pager || true
}

# 提示手动测试
prompt_manual_test() {
    echo ""
    log_info "=========================================="
    log_info "安装完成！后续步骤："
    log_info "=========================================="
    echo ""
    echo -e "${GREEN}1.${NC} 编辑订阅列表文件，添加你的订阅链接："
    echo -e "   ${YELLOW}nano $SUBLIST_FILE${NC}"
    echo ""
    echo -e "${GREEN}2.${NC} 修改 dae 配置文件中的 subscription 部分："
    echo -e "   ${YELLOW}nano $CONFIG_FILE${NC}"
    echo -e "   将订阅改为: sub1:'file://sub1.sub' 格式"
    echo ""
    echo -e "${GREEN}3.${NC} 手动运行一次订阅更新测试："
    echo -e "   ${YELLOW}systemctl start update-subs.service${NC}"
    echo ""
    echo -e "${GREEN}4.${NC} 查看订阅更新日志："
    echo -e "   ${YELLOW}journalctl -u update-subs.service -f${NC}"
    echo ""
    echo -e "${GREEN}5.${NC} 查看定时器状态："
    echo -e "   ${YELLOW}systemctl status update-subs.timer${NC}"
    echo ""
    echo -e "${GREEN}6.${NC} 查看下次执行时间："
    echo -e "   ${YELLOW}systemctl list-timers | grep update-subs${NC}"
    echo ""
}

# 主函数
main() {
    echo ""
    log_info "=========================================="
    log_info "Dae 订阅自动更新一键配置脚本"
    log_info "=========================================="
    echo ""
    
    check_root
    check_dae
    check_systemd
    create_config_dir
    backup_config
    create_update_script
    create_systemd_service
    create_systemd_timer
    create_sublist_template
    update_config_dae
    enable_and_start_timer
    prompt_manual_test
    
    log_info "脚本执行完成！"
}

# 执行主函数
main
