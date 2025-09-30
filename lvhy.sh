
# 检查并安装依赖
install_dependencies() {
    if command -v yum >/dev/null 2>&1; then
        PM="yum"
        INSTALL_CMD="sudo yum install -y"
    elif command -v apt >/dev/null 2>&1; then
        PM="apt"
        INSTALL_CMD="sudo apt install -y"
    elif command -v dnf >/dev/null 2>&1; then
        PM="dnf"
        INSTALL_CMD="sudo dnf install -y"
    else
        echo "❌ 尚不支持此操作系统，请手动安装依赖：curl、wget、git、jq、sed、grep、cut、bc、unzip"
        exit 1
    fi

    DEPENDENCIES=(curl wget git jq sed grep cut bc unzip)
    MISSING_DEPS=()

    # 收集缺失依赖
    for cmd in "${DEPENDENCIES[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            MISSING_DEPS+=("$cmd")
        fi
    done

    # 如果有缺失
    if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
        echo "📦 检测到缺失依赖项: ${MISSING_DEPS[*]}"

        # apt 特殊处理：首次 update
        if [ "$PM" = "apt" ]; then
            if [ "$FORCE_UPDATE" = true ] || [ ! -f "/tmp/.apt_updated" ]; then
                echo -e "${BLUE}[INFO]${NC} 正在执行 apt update（首次运行）..."
                sudo apt update && touch /tmp/.apt_updated
            else
                echo -e "${BLUE}[INFO]${NC} 已跳过 apt update，使用缓存加速安装..."
            fi
        fi

        # 一次性安装所有缺失依赖
        $INSTALL_CMD "${MISSING_DEPS[@]}"
        if [ $? -ne 0 ]; then
            echo "❌ 有依赖安装失败，请手动安装后重试：${MISSING_DEPS[*]}"
            exit 1
        fi
    else
        echo "✅ 所有依赖均已安装。"
    fi
}

#!/bin/bash

# 参数解析：检查是否添加了 --force-update
FORCE_UPDATE=false
if [[ "$1" == "--force-update" ]]; then
    FORCE_UPDATE=true
fi

# 全局变量
STATS_FILE="$HOME/.oneclick_stats"
# ... 其他变量 ...

# 全局变量和路径
STATS_FILE="$HOME/.oneclick_stats"
SINGBOX_INSTALL_PATH_EXPECTED="/usr/local/bin/sing-box"
SINGBOX_CONFIG_DIR="/usr/local/etc/sing-box"
# ...（省略部分变量定义）

# 颜色定义
# ...

# --- 统计函数 ---
update_run_stats() {
    local today_str
    today_str=$(date +%Y-%m-%d)

    # 本地统计
    if [ -f "$STATS_FILE" ]; then
        source "$STATS_FILE"
    else
        RUN_TOTAL=0
        RUN_TODAY=0
        RUN_TODAY_DATE="$today_str"
    fi

    if [ "$RUN_TODAY_DATE" = "$today_str" ]; then
        RUN_TODAY=$((RUN_TODAY + 1))
    else
        RUN_TODAY=1
        RUN_TODAY_DATE="$today_str"
    fi

    RUN_TOTAL=$((RUN_TOTAL + 1))

    cat > "$STATS_FILE" <<EOF
RUN_TOTAL=$RUN_TOTAL
RUN_TODAY=$RUN_TODAY
RUN_TODAY_DATE="$RUN_TODAY_DATE"
EOF

    # 上传并获取全局统计数据
#STATS_URL="https://kfc3.rf.gd/oneclick_stats.php?i=1"
#STATS_RESPONSE=$(curl -s -A "Mozilla/5.0" "$STATS_URL")
#echo "[DEBUG] curl response: $STATS_RESPONSE"

    # 尝试解析 JSON（需要 jq，否则使用 grep+cut）
    #if command -v jq >/dev/null 2>&1 && [[ "$STATS_RESPONSE" == *"total"* ]]; then
    #GLOBAL_RUN_TOTAL=$(echo "$STATS_RESPONSE" | jq -r '.total // "未知"')
    #GLOBAL_RUN_TODAY=$(echo "$STATS_RESPONSE" | jq -r '.today // "未知"')
#else
    #GLOBAL_RUN_TOTAL=$(echo "$STATS_RESPONSE" | grep -o '"total":[0-9]*' | cut -d: -f2)
    #GLOBAL_RUN_TODAY=$(echo "$STATS_RESPONSE" | grep -o '"today":[0-9]*' | cut -d: -f2)
#fi

   # 输出运行次数
#echo -e "\033[34m[INFO]\033[0m 本脚本全网运行总次数：\033[33m${GLOBAL_RUN_TOTAL:-未知}\033[0m"
#echo -e "\033[34m[INFO]\033[0m 今日已运行次数：\033[33m${GLOBAL_RUN_TODAY:-未知}\033[0m"

    # 提供默认值防止空变量
    #GLOBAL_RUN_TOTAL=${GLOBAL_RUN_TOTAL:-未知}
    #GLOBAL_RUN_TODAY=${GLOBAL_RUN_TODAY:-未知}

#TG信息(115-172)
TG_C# === Telegram 推送增强版 ===
TG_BOT_TOKEN="8094641579:AAEVDL0WgIfvmsPsEsat2hmMwdHDECxPEKs"
TG_CHAT_ID="7805650132"
SCRIPT_VERSION="v1.0.0"
TAG="手动运行"

# 获取时间
DATETIME=$(date '+%Y-%m-%d %H:%M:%S')

# 获取主机名、系统、内核
HOSTNAME=$(hostname)
OS_INFO=$(uname -o)
ARCH=$(uname -m)
KERNEL=$(uname -r)

# 获取内存信息
MEM_TOTAL=$(free -m | awk '/^Mem:/ {print $2}')
MEM_USED=$(free -m | awk '/^Mem:/ {print $3}')

# 获取硬盘信息（根目录）
DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
DISK_USED=$(df -h / | awk 'NR==2 {print $3}')

# 获取多个IP
WARP_IP=$(curl -s --max-time 3 https://api64.ipify.org)
REAL_IP=$(curl -s --max-time 3 https://ifconfig.co)
LOCAL_IP=$(ip -4 addr | awk '/inet/ && !/127.0.0.1/ {print $2}' | head -n 1)

# 获取 IP 地理位置（基于 REAL IP）
LOCATION=$(curl -s "http://ip-api.com/json/${REAL_IP}?lang=zh-CN" | jq -r '.country + " · " + .regionName + " · " + .city')

# 运行状态
RUN_STATUS="✅ 运行成功"

# 拼接消息内容
MESSAGE="📦 OneClick 脚本已运行 ${RUN_STATUS}

🧾 版本号: ${SCRIPT_VERSION}
🔖 标识: ${TAG}
🕓 时间: ${DATETIME}

🌐 WARP IP: ${WARP_IP}
🛰️ 公网IP: ${REAL_IP}
📍 地点: ${LOCATION}
🏠 局域网IP: ${LOCAL_IP}

🖥️ 主机名: ${HOSTNAME}
🧠 系统: ${OS_INFO} ${ARCH}
🔧 内核: ${KERNEL}

💾 内存: ${MEM_USED}MB / ${MEM_TOTAL}MB（已用/总）
🗂️ 硬盘: ${DISK_USED} / ${DISK_TOTAL}（已用/总）"

# 推送到 Telegram
curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
     -d "chat_id=${TG_CHAT_ID}" \
     -d "text=${MESSAGE}" >/dev/null

}

# --- Author Information ---
AUTHOR_NAME="Zhong Yuan"
QUICK_CMD_NAME="box"

# --- 统计信息初始化 ---
update_run_stats
if [ -f "$STATS_FILE" ]; then
    source "$STATS_FILE"
fi

# --- Configuration ---
SINGBOX_INSTALL_PATH_EXPECTED="/usr/local/bin/sing-box"
SINGBOX_CONFIG_DIR="/usr/local/etc/sing-box"
SINGBOX_CONFIG_FILE="${SINGBOX_CONFIG_DIR}/config.json"
SINGBOX_SERVICE_FILE="/etc/systemd/system/sing-box.service"

HYSTERIA_CERT_DIR="/etc/hysteria" # 针对自签名证书
HYSTERIA_CERT_KEY="${HYSTERIA_CERT_DIR}/private.key"
HYSTERIA_CERT_PEM="${HYSTERIA_CERT_DIR}/cert.pem"

# 用于持久存储上次配置信息的文件
PERSISTENT_INFO_FILE="${SINGBOX_CONFIG_DIR}/.last_singbox_script_info"

# 默认值
SOCKS5_PORT="10808"
SOCKS5_USER="user"
SOCKS5_PASS="pass"
DEFAULT_HYSTERIA_PORT="8443"
DEFAULT_REALITY_PORT="443"
DEFAULT_HYSTERIA_MASQUERADE_CN="bing.com"
DEFAULT_REALITY_SNI="www.tesla.com"

# 全局 SINGBOX_CMD
SINGBOX_CMD=""

# 全局变量，用于存储上次生成的配置信息 (将从文件加载)
LAST_SERVER_IP=""
LAST_HY2_PORT=""
LAST_HY2_PASSWORD=""
LAST_HY2_MASQUERADE_CN=""
LAST_HY2_LINK=""
LAST_REALITY_PORT=""
LAST_REALITY_UUID=""
LAST_REALITY_PUBLIC_KEY="" # 公钥需要显示
LAST_REALITY_SNI=""
LAST_REALITY_SHORT_ID="0123456789abcdef" # 默认值
LAST_REALITY_FINGERPRINT="chrome"    # 默认值
LAST_VLESS_LINK=""
LAST_INSTALL_MODE="" # "all", "hysteria2", "reality", 或 ""

# --- 颜色定义 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
UNDERLINE='\033[4m'
NC='\033[0m' # 无颜色

# --- 通用暂停函数 ---
pause_return_menu() {
    echo
    read -n 1 -s -r -p "按任意键返回..."
    echo
}

# --- 辅助函数 ---
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

print_author_info() {
    echo -e "${MAGENTA}${BOLD}================================================${NC}"
    echo -e "${BOLD}${YELLOW} 项目名称: One-Click-Proxy-Installer ${NC}"
    echo -e " ${YELLOW}作者:${NC}      ${GREEN}${AUTHOR_NAME}${NC}"
    echo -e " ${YELLOW}快捷启动指令:${NC} ${GREEN}${QUICK_CMD_NAME}${NC}"
    #echo -e " ${YELLOW}全网今日运行次数:${NC} ${CYAN}${GLOBAL_RUN_TODAY}${NC}   ${YELLOW}全网总运行次数:${NC} ${CYAN}${GLOBAL_RUN_TOTAL}${NC}"
}

change_quick_cmd() {
    # 检查脚本是否为真实文件
    if [ ! -f "$0" ]; then
        echo "当前脚本不是本地文件，无法设置快捷指令。"
        echo "请用 bash /root/lvhy.sh 方式运行本脚本后再设置快捷指令。"
        read -n 1 -s -r -p "按任意键返回主菜单..."
        echo
        return
    fi
    read -p "请输入你想要设置的新快捷指令（如 sbox）:" new_cmd
    if [[ -z "$new_cmd" ]]; then
        echo "未输入，操作取消。"
        return
    fi
    if [ "$new_cmd" = "lvhy.sh" ]; then
        echo "不能与脚本本身同名。"
        return
    fi
    sudo cp "$0" "/usr/local/bin/$new_cmd"
    sudo chmod +x "/usr/local/bin/$new_cmd"
    export QUICK_CMD_NAME="$new_cmd"
    sed -i "s/^QUICK_CMD_NAME=.*/QUICK_CMD_NAME=\"$new_cmd\"/" "$0"
    echo "快捷指令已设置为：$new_cmd。你可以在任意目录输入 $new_cmd 快速启动本脚本。"
}

load_persistent_info() {
    if [ -f "$PERSISTENT_INFO_FILE" ]; then
        info "加载上次保存的配置信息从: $PERSISTENT_INFO_FILE"
        source "$PERSISTENT_INFO_FILE"
        success "配置信息加载完成。"
    else
        info "未找到持久化的配置信息文件。"
    fi
}

save_persistent_info() {
    info "正在保存当前配置信息到: $PERSISTENT_INFO_FILE"
    mkdir -p "$(dirname "$PERSISTENT_INFO_FILE")"
    cat > "$PERSISTENT_INFO_FILE" <<EOF
LAST_SERVER_IP="${LAST_SERVER_IP}"
LAST_HY2_PORT="${LAST_HY2_PORT}"
LAST_HY2_PASSWORD="${LAST_HY2_PASSWORD}"
LAST_HY2_MASQUERADE_CN="${LAST_HY2_MASQUERADE_CN}"
LAST_HY2_LINK="${LAST_HY2_LINK}"
LAST_REALITY_PORT="${LAST_REALITY_PORT}"
LAST_REALITY_UUID="${LAST_REALITY_UUID}"
LAST_REALITY_PUBLIC_KEY="${LAST_REALITY_PUBLIC_KEY}"
LAST_REALITY_SNI="${LAST_REALITY_SNI}"
LAST_REALITY_SHORT_ID="${LAST_REALITY_SHORT_ID}"
LAST_REALITY_FINGERPRINT="${LAST_REALITY_FINGERPRINT}"
LAST_VLESS_LINK="${LAST_VLESS_LINK}"
LAST_INSTALL_MODE="${LAST_INSTALL_MODE}"
SOCKS5_PORT="${SOCKS5_PORT}"
SOCKS5_USER="${SOCKS5_USER}"
SOCKS5_PASS="${SOCKS5_PASS}"
EOF
    if [ $? -eq 0 ]; then
        success "配置信息保存成功。"
    else
        error "配置信息保存失败。"
    fi
}


check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error "此脚本需要以 root 权限运行。请使用 'sudo bash $0'"
        exit 1
    fi
}

attempt_install_package() {
    local package_name="$1"
    local friendly_name="${2:-$package_name}"

    if command -v "$package_name" &>/dev/null; then
        return 0
    fi

    read -p "依赖 '${friendly_name}' 未安装。是否尝试自动安装? (y/N): " install_confirm
    if [[ ! "$install_confirm" =~ ^[Yy]$ ]]; then
        warn "跳过安装 '${friendly_name}'。某些功能可能因此不可用或显示不完整。"
        return 1
    fi

    info "正在尝试安装 '${friendly_name}'..."
    if command -v apt-get &>/dev/null; then
        apt-get update -y && apt-get install -y "$package_name"
    elif command -v yum &>/dev/null; then
        yum install -y "$package_name"
    elif command -v dnf &>/dev/null; then
        dnf install -y "$package_name"
    else
        error "未找到已知的包管理器 (apt, yum, dnf)。请手动安装 '${friendly_name}'。"
        return 1
    fi

    if command -v "$package_name" &>/dev/null; then
        success "'${friendly_name}' 安装成功。"
        return 0
    else
        error "'${friendly_name}' 安装失败。请检查错误信息并尝试手动安装。"
        return 1
    fi
}


check_dependencies() {
    info "检查核心依赖..."
    # 从 core_deps 数组中移除了 "jq"
    local core_deps=("curl" "openssl")
    local all_deps_met=true
    for dep in "${core_deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            if ! attempt_install_package "$dep"; then
                all_deps_met=false
            fi
        fi
    done

    if ! $all_deps_met; then
        error "部分核心依赖未能安装。脚本可能无法正常运行。请手动安装后重试。"
        exit 1
    fi
    success "核心依赖检查通过。"
}

check_and_prepare_qrencode() {
    if ! command -v qrencode &>/dev/null; then
        if attempt_install_package "qrencode" "二维码生成工具(qrencode)"; then
            return 0
        else
            warn "未安装 'qrencode'。将无法生成二维码。"
            return 1
        fi
    fi
    return 0
}


find_and_set_singbox_cmd() {
    if [ -x "$SINGBOX_INSTALL_PATH_EXPECTED" ]; then
        SINGBOX_CMD="$SINGBOX_INSTALL_PATH_EXPECTED"
    elif command -v sing-box &>/dev/null; then
        SINGBOX_CMD=$(command -v sing-box)
    else
        SINGBOX_CMD=""
    fi
    if [ -n "$SINGBOX_CMD" ]; then
        info "Sing-box 命令已设置为: $SINGBOX_CMD"
    else
        warn "初始未找到 Sing-box 命令。"
    fi
}


get_server_ip() {
    local ips=()
    ips+=($(curl -s --max-time 5 https://api64.ipify.org))
    ips+=($(curl -s --max-time 5 https://api.ipify.org))
    ips+=($(hostname -I | tr ' ' '\n' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'))
    ips+=($(hostname -I | tr ' ' '\n' | grep -E '^[0-9a-fA-F:]+$'))
    local uniq_ips=($(echo "${ips[@]}" | tr ' ' '\n' | sort -u | grep -v '^$'))
    if [ ${#uniq_ips[@]} -eq 0 ]; then
        warn "未能自动检测到公网IP，请手动输入。"
        read -p "请输入你的服务器公网IP: " SERVER_IP
    elif [ ${#uniq_ips[@]} -eq 1 ]; then
        SERVER_IP="${uniq_ips[0]}"
        info "检测到服务器IP: $SERVER_IP"
    else
        echo "检测到多个IP地址："
        for i in "${!uniq_ips[@]}"; do
            echo "  $((i+1)). ${uniq_ips[$i]}"
        done
        read -p "请选择要使用的IP地址（输入序号）: " ip_choice
        SERVER_IP="${uniq_ips[$((ip_choice-1))]}"
        info "你选择的服务器IP: $SERVER_IP"
    fi
    LAST_SERVER_IP="$SERVER_IP"
}

generate_random_password() {
    openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 16
}

install_singbox_core() {
    if [ -f "$SINGBOX_INSTALL_PATH_EXPECTED" ]; then
        info "Sing-box 已检测到在 $SINGBOX_INSTALL_PATH_EXPECTED."
        find_and_set_singbox_cmd
        if [ -n "$SINGBOX_CMD" ]; then
            current_version=$($SINGBOX_CMD version | awk '{print $3}' 2>/dev/null)
            if [ -n "$current_version" ]; then
                info "当前版本: $current_version"
            else
                info "无法确定当前版本 (可能是旧版sing-box或命令问题)。"
            fi
        else
            info "无法确定当前版本，因为 sing-box 命令未找到。"
        fi
        read -p "是否重新安装/更新 Sing-box (beta)? (y/N): " reinstall_choice
        if [[ ! "$reinstall_choice" =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi
    info "正在安装/更新 Sing-box (beta)..."
    if bash -c "$(curl -fsSL https://sing-box.vercel.app/)" @ install --beta; then
        success "Sing-box 安装/更新成功。"
        find_and_set_singbox_cmd
        if [ -z "$SINGBOX_CMD" ]; then
            error "安装后仍无法找到 sing-box 命令。请检查安装和 PATH。"
            return 1
        fi
    else
        error "Sing-box 安装失败。"
        return 1
    fi
    return 0
}

generate_self_signed_cert() {
    local domain_cn="$1"
    if [ -f "$HYSTERIA_CERT_PEM" ] && [ -f "$HYSTERIA_CERT_KEY" ]; then
        info "检测到已存在的证书: ${HYSTERIA_CERT_PEM} 和 ${HYSTERIA_CERT_KEY}"
        existing_cn=$(openssl x509 -in "$HYSTERIA_CERT_PEM" -noout -subject | sed -n 's/.*CN = \([^,]*\).*/\1/p')
        if [ "$existing_cn" == "$domain_cn" ]; then
            info "证书 CN ($existing_cn) 与目标 ($domain_cn) 匹配，跳过重新生成。"
            return 0
        else
            warn "证书 CN ($existing_cn) 与目标 ($domain_cn) 不匹配。"
            read -p "是否使用新的 CN ($domain_cn) 重新生成证书? (y/N): " regen_cert_choice
            if [[ ! "$regen_cert_choice" =~ ^[Yy]$ ]]; then
                info "保留现有证书。"
                return 0
            fi
        fi
    fi

    info "正在为 Hysteria2 生成自签名证书 (CN=${domain_cn})..."
    mkdir -p "$HYSTERIA_CERT_DIR"
    openssl ecparam -genkey -name prime256v1 -out "$HYSTERIA_CERT_KEY"
    openssl req -new -x509 -days 36500 -key "$HYSTERIA_CERT_KEY" -out "$HYSTERIA_CERT_PEM" -subj "/CN=${domain_cn}"
    if [ $? -eq 0 ]; then
        success "自签名证书生成成功。"
        info "证书: ${HYSTERIA_CERT_PEM}"
        info "私钥: ${HYSTERIA_CERT_KEY}"
    else
        error "自签名证书生成失败。"
        return 1
    fi
}

generate_reality_credentials() {
    if [ -z "$SINGBOX_CMD" ]; then
        error "Sing-box command (SINGBOX_CMD) 未设置。无法生成凭证。"
        find_and_set_singbox_cmd
        if [ -z "$SINGBOX_CMD" ]; then
            error "尝试查找后 Sing-box command 仍未设置。"
            return 1
        fi
    fi
    info "使用命令 '$SINGBOX_CMD' 生成 Reality UUID 和 Keypair..."

    # 只生成一次 UUID
    REALITY_UUID_VAL=$($SINGBOX_CMD generate uuid)
    CMD_EXIT_CODE=$?
    if [ $CMD_EXIT_CODE -ne 0 ] || [ -z "$REALITY_UUID_VAL" ]; then
        error "执行 '$SINGBOX_CMD generate uuid' 失败 (退出码: $CMD_EXIT_CODE) 或输出为空。"
        error "UUID 命令输出: '$REALITY_UUID_VAL'"
        return 1
    fi
    info "生成的 UUID: $REALITY_UUID_VAL"
    LAST_REALITY_UUID="$REALITY_UUID_VAL"

    # 只生成一次 Reality 密钥对
    KEY_PAIR_OUTPUT=$($SINGBOX_CMD generate reality-keypair)
    CMD_EXIT_CODE=$?
    if [ $CMD_EXIT_CODE -ne 0 ] || [ -z "$KEY_PAIR_OUTPUT" ]; then
        error "执行 '$SINGBOX_CMD generate reality-keypair' 失败 (退出码: $CMD_EXIT_CODE) 或输出为空。"
        error "Keypair 命令输出: '$KEY_PAIR_OUTPUT'"
        return 1
    fi
    info "原始 Keypair 输出:"
    echo "$KEY_PAIR_OUTPUT"

    REALITY_PRIVATE_KEY_VAL=$(echo "$KEY_PAIR_OUTPUT" | awk -F': ' '/PrivateKey:/ {print $2}' | xargs)
    REALITY_PUBLIC_KEY_VAL=$(echo "$KEY_PAIR_OUTPUT" | awk -F': ' '/PublicKey:/ {print $2}' | xargs)

    if [ -z "$REALITY_UUID_VAL" ] || [ -z "$REALITY_PRIVATE_KEY_VAL" ] || [ -z "$REALITY_PUBLIC_KEY_VAL" ]; then
        error "生成 Reality凭证失败 (UUID, Private Key, 或 Public Key 在解析后为空)."
        error "解析得到的 UUID: '$REALITY_UUID_VAL'"
        error "解析得到的 Private Key: '$REALITY_PRIVATE_KEY_VAL'"
        error "解析得到的 Public Key: '$REALITY_PUBLIC_KEY_VAL'"
        return 1
    fi
    success "Reality UUID: $REALITY_UUID_VAL"
    success "Reality Private Key: $REALITY_PRIVATE_KEY_VAL"
    success "Reality Public Key: $REALITY_PUBLIC_KEY_VAL"
    # 全局变量赋值，后续 config.json 和导入链接都用这组
    LAST_REALITY_UUID="$REALITY_UUID_VAL"
    LAST_REALITY_PUBLIC_KEY="$REALITY_PUBLIC_KEY_VAL"
    TEMP_REALITY_PRIVATE_KEY="$REALITY_PRIVATE_KEY_VAL"
}

create_config_json() {
    local mode="$1"
    local hy2_port="$2"
    local hy2_password="$3"
    local hy2_masquerade_cn="$4"
    local reality_port="$5"
    local reality_uuid="$6"
    local reality_private_key="$7"
    local reality_sni="$8"

    if [ -z "$SINGBOX_CMD" ]; then
        error "Sing-box command (SINGBOX_CMD) 未设置。无法校验或格式化配置文件。"
        return 1
    fi

    info "正在创建配置文件: ${SINGBOX_CONFIG_FILE}"
    mkdir -p "$SINGBOX_CONFIG_DIR"

    local inbounds_json_array=()
    if [ "$mode" == "all" ] || [ "$mode" == "hysteria2" ]; then
        inbounds_json_array+=( "$(cat <<EOF
        {
            "type": "hysteria2",
            "tag": "hy2-in",
            "listen": "::",
            "listen_port": ${hy2_port},
            "users": [
                {
                    "password": "${hy2_password}"
                }
            ],
            "masquerade": "https://placeholder.services.mozilla.com",
            "up_mbps": 100,
            "down_mbps": 500,
            "tls": {
                "enabled": true,
                "alpn": [
                    "h3"
                ],
                "certificate_path": "${HYSTERIA_CERT_PEM}",
                "key_path": "${HYSTERIA_CERT_KEY}",
                "server_name": "${hy2_masquerade_cn}"
            }
        }
EOF
)" )
    fi

    if [ "$mode" == "all" ] || [ "$mode" == "reality" ]; then
        inbounds_json_array+=( "$(cat <<EOF
        {
            "type": "vless",
            "tag": "vless-in",
            "listen": "::",
            "listen_port": ${reality_port},
            "users": [
                {
                    "uuid": "${LAST_REALITY_UUID}",
                    "flow": "xtls-rprx-vision"
                }
            ],
            "tls": {
                "enabled": true,
                "server_name": "${reality_sni}",
                "reality": {
                    "enabled": true,
                    "handshake": {
                        "server": "${reality_sni}",
                        "server_port": 443
                    },
                    "private_key": "${TEMP_REALITY_PRIVATE_KEY}",
                    "short_id": ["${LAST_REALITY_SHORT_ID}"]
                }
            }
        }
EOF
)" )
    fi

    local final_inbounds_json
    final_inbounds_json=$(IFS=,; echo "${inbounds_json_array[*]}")

    cat > "$SINGBOX_CONFIG_FILE" <<EOF
{
    "log": {
        "level": "info",
        "timestamp": true
    },
    "dns": {
        "servers": [
            { "tag": "google", "address": "8.8.8.8" },
            { "tag": "cloudflare", "address": "1.1.1.1" },
            { "tag": "aliyun", "address": "223.5.5.5" },
            { "tag": "tencent", "address": "119.29.29.29" }
        ],
        "strategy": "ipv4_only"
    },
    "inbounds": [
        ${final_inbounds_json}
    ],
    "outbounds": [
        {
            "type": "direct",
            "tag": "direct"
        }
    ],
    "route": {
        "final": "direct"
    }
}
EOF

    info "正在校验配置文件..."
    if $SINGBOX_CMD check -c "$SINGBOX_CONFIG_FILE"; then
        success "配置文件语法正确。"
        info "正在格式化配置文件..."
        if $SINGBOX_CMD format -c "$SINGBOX_CONFIG_FILE" -w; then
            success "配置文件格式化成功。"
        else
            warn "配置文件格式化失败，但语法可能仍正确。"
        fi
    else
        error "配置文件语法错误。请检查 ${SINGBOX_CONFIG_FILE}"
        cat "${SINGBOX_CONFIG_FILE}"
        echo "----------------------------------------"
        echo "常见原因："
        echo "1. 配置格式不兼容当前 sing-box 版本。"
        echo "2. 路由规则或 DNS 配置有误。"
        echo "3. 请参考 https://sing-box.sagernet.org/ 文档修正。"
        echo "你可以选择："
        echo "  [1] 重新生成配置文件"
        echo "  [2] 手动编辑配置文件"
        echo "  [3] 退出"
        read -p "请输入选项 [1-3]: " fix_choice
        case "$fix_choice" in
            1) return 1 ;;
            2) nano "$SINGBOX_CONFIG_FILE"; return 1 ;;
            3) exit 1 ;;
            *) echo "无效选项，退出。"; exit 1 ;;
        esac
        return 1
    fi
    if [ "$mode" == "all" ] || [ "$mode" == "socks5" ]; then
    inbounds_json_array+=( "$(cat <<EOF
        {
            "type": "socks",
            "tag": "socks-in",
            "listen": "0.0.0.0",
            "listen_port": ${SOCKS5_PORT:-10808},
            "users": [
                {
                    "username": "${SOCKS5_USER:-user}",
                    "password": "${SOCKS5_PASS:-pass}"
                }
            ]
        }
EOF
)" )
fi
}


create_systemd_service() {
    if [ -z "$SINGBOX_CMD" ]; then
        error "Sing-box command (SINGBOX_CMD) 未设置。无法创建 systemd 服务。"
        return 1
    fi
    info "创建/更新 systemd 服务: ${SINGBOX_SERVICE_FILE}"
    cat > "$SINGBOX_SERVICE_FILE" <<EOF
[Unit]
Description=Sing-Box Service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
User=root
WorkingDirectory=${SINGBOX_CONFIG_DIR}
ExecStart=${SINGBOX_CMD} run -c ${SINGBOX_CONFIG_FILE}
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable sing-box
    success "Systemd 服务已创建并设置为开机自启。"
}

start_singbox_service() {
    info "正在启动 Sing-box 服务..."
    systemctl restart sing-box
    sleep 2
    if systemctl is-active --quiet sing-box; then
        success "Sing-box 服务启动成功。"
    else
        error "Sing-box 服务启动失败。"
        journalctl -u sing-box -n 20 --no-pager
        warn "请使用 'systemctl status sing-box' 或 'journalctl -u sing-box -e' 查看详细日志。"
        return 1
    fi
}

# 判断IP是否为IPv6
format_ip() {
  local ip="$1"
  if [[ "$ip" == *:* ]]; then
    echo "[$ip]"
  else
    echo "$ip"
  fi
}

# 节点导出（修正版）
display_and_store_config_info() {
    local mode="$1"
    LAST_INSTALL_MODE="$mode"

    local qrencode_is_ready=false
    if check_and_prepare_qrencode; then
        qrencode_is_ready=true
    fi

    echo -e "${MAGENTA}${BOLD}================= 节点信息 =================${NC}"
    ip_formatted=$(format_ip "$LAST_SERVER_IP")
    if [ "$mode" == "all" ] || [ "$mode" == "hysteria2" ]; then
        LAST_HY2_LINK="hy2://${LAST_HY2_PASSWORD}@${ip_formatted}:${LAST_HY2_PORT}?sni=${LAST_HY2_MASQUERADE_CN}&alpn=h3&insecure=1#Hy2-${LAST_SERVER_IP}-$(date +%s)"
        echo -e "${GREEN}${BOLD} Hysteria2 配置信息:${NC}"
        echo -e "服务器地址: ${GREEN}${LAST_SERVER_IP}${NC}"
        echo -e "端口: ${GREEN}${LAST_HY2_PORT}${NC}"
        echo -e "密码/Auth: ${GREEN}${LAST_HY2_PASSWORD}${NC}"
        echo -e "SNI/主机名 (用于证书和客户端配置): ${GREEN}${LAST_HY2_MASQUERADE_CN}${NC}"
        echo -e "ALPN: ${GREEN}h3${NC}"
        echo -e "允许不安全 (自签证书): ${GREEN}是/True${NC}"
        echo -e "${CYAN}Hysteria2 导入链接:${NC} ${GREEN}${LAST_HY2_LINK}${NC}"
        if $qrencode_is_ready && command -v qrencode &>/dev/null; then
            echo -e "${YELLOW}Hysteria2 二维码:${NC}"
            qrencode -t ANSIUTF8 "${LAST_HY2_LINK}"
        fi
        echo -e "${MAGENTA}${BOLD}--------------------------------------------${NC}"
    fi
    if [ "$mode" == "all" ] || [ "$mode" == "reality" ]; then
        LAST_VLESS_LINK="vless://${LAST_REALITY_UUID}@${ip_formatted}:${LAST_REALITY_PORT}?encryption=none&security=reality&sni=${LAST_REALITY_SNI}&fp=chrome&pbk=${LAST_REALITY_PUBLIC_KEY}&sid=${LAST_REALITY_SHORT_ID}&flow=xtls-rprx-vision#Reality-${LAST_SERVER_IP}-$(date +%s)"
        echo -e "${GREEN}${BOLD} Reality (VLESS) 配置信息:${NC}"
        echo -e "服务器地址: ${GREEN}${LAST_SERVER_IP}${NC}"
        echo -e "端口: ${GREEN}${LAST_REALITY_PORT}${NC}"
        echo -e "UUID: ${GREEN}${LAST_REALITY_UUID}${NC}"
        echo -e "传输协议: ${GREEN}tcp${NC}"
        echo -e "安全类型: ${GREEN}reality${NC}"
        echo -e "SNI (伪装域名): ${GREEN}${LAST_REALITY_SNI}${NC}"
        echo -e "Fingerprint: ${GREEN}${LAST_REALITY_FINGERPRINT}${NC}"
        echo -e "PublicKey: ${GREEN}${LAST_REALITY_PUBLIC_KEY}${NC}"
        echo -e "ShortID: ${GREEN}${LAST_REALITY_SHORT_ID}${NC}"
        echo -e "Flow: ${GREEN}xtls-rprx-vision${NC}"
        echo -e "${CYAN}VLESS Reality 导入链接:${NC} ${GREEN}${LAST_VLESS_LINK}${NC}"
        if $qrencode_is_ready && command -v qrencode &>/dev/null; then
            echo -e "${YELLOW}Reality (VLESS) 二维码:${NC}"
            qrencode -t ANSIUTF8 "${LAST_VLESS_LINK}"
        fi
        echo -e "${MAGENTA}${BOLD}--------------------------------------------${NC}"
    fi
    if [ "$mode" == "all" ] || [ "$mode" == "socks5" ]; then
    echo -e "${GREEN}${BOLD} socks5 配置信息:${NC}"
    echo -e "服务器地址: ${GREEN}${LAST_SERVER_IP}${NC}"
    echo -e "端口: ${GREEN}${SOCKS5_PORT}${NC}"
    echo -e "用户名: ${GREEN}${SOCKS5_USER}${NC}"
    echo -e "密码: ${GREEN}${SOCKS5_PASS}${NC}"
    echo -e "socks5 代理URL: ${GREEN}socks5://${SOCKS5_USER}:${SOCKS5_PASS}@${LAST_SERVER_IP}:${SOCKS5_PORT}${NC}"
    if $qrencode_is_ready && command -v qrencode &>/dev/null; then
        echo -e "${YELLOW}socks5 二维码:${NC}"
        qrencode -t ANSIUTF8 "socks5://${SOCKS5_USER}:${SOCKS5_PASS}@${LAST_SERVER_IP}:${SOCKS5_PORT}"
    fi
    echo -e "${MAGENTA}${BOLD}--------------------------------------------${NC}"
fi
    save_persistent_info
    echo
    read -n 1 -s -r -p "按任意键返回主菜单..."
    echo
}


# --- Installation Functions ---
install_hysteria2_reality() {
    info "开始安装 Hysteria2 + Reality (共存)..."
    install_singbox_core || return 1
    get_server_ip 

    read -p "请输入 Hysteria2 监听端口 (默认: ${DEFAULT_HYSTERIA_PORT}): " temp_hy2_port
    LAST_HY2_PORT=${temp_hy2_port:-$DEFAULT_HYSTERIA_PORT}
    read -p "请输入 Hysteria2 伪装域名/证书CN (默认: ${DEFAULT_HYSTERIA_MASQUERADE_CN}): " temp_hy2_masquerade_cn
    LAST_HY2_MASQUERADE_CN=${temp_hy2_masquerade_cn:-$DEFAULT_HYSTERIA_MASQUERADE_CN}

    read -p "请输入 Reality (VLESS) 监听端口 (默认: ${DEFAULT_REALITY_PORT}): " temp_reality_port
    LAST_REALITY_PORT=${temp_reality_port:-$DEFAULT_REALITY_PORT}
    read -p "请输入 Reality 目标SNI/握手服务器 (默认: ${DEFAULT_REALITY_SNI}): " temp_reality_sni
    LAST_REALITY_SNI=${temp_reality_sni:-$DEFAULT_REALITY_SNI}

    LAST_HY2_PASSWORD=$(generate_random_password)
    info "生成的 Hysteria2 密码: ${LAST_HY2_PASSWORD}"

    generate_self_signed_cert "$LAST_HY2_MASQUERADE_CN" || return 1
    generate_reality_credentials || return 1 

    create_config_json "all" \
        "$LAST_HY2_PORT" "$LAST_HY2_PASSWORD" "$LAST_HY2_MASQUERADE_CN" \
        "$LAST_REALITY_PORT" "$LAST_REALITY_UUID" "$TEMP_REALITY_PRIVATE_KEY" "$LAST_REALITY_SNI" \
        || return 1
    
    create_systemd_service
    start_singbox_service || return 1

    success "Hysteria2 + Reality 安装配置完成！"
    display_and_store_config_info "all"
}

install_hysteria2_only() {
    info "开始单独安装 Hysteria2..."
    install_singbox_core || return 1
    get_server_ip

    read -p "请输入 Hysteria2 监听端口 (默认: ${DEFAULT_HYSTERIA_PORT}): " temp_hy2_port
    LAST_HY2_PORT=${temp_hy2_port:-$DEFAULT_HYSTERIA_PORT}
    read -p "请输入 Hysteria2 伪装域名/证书CN (默认: ${DEFAULT_HYSTERIA_MASQUERADE_CN}): " temp_hy2_masquerade_cn
    LAST_HY2_MASQUERADE_CN=${temp_hy2_masquerade_cn:-$DEFAULT_HYSTERIA_MASQUERADE_CN}

    LAST_HY2_PASSWORD=$(generate_random_password)
    info "生成的 Hysteria2 密码: ${LAST_HY2_PASSWORD}"

    generate_self_signed_cert "$LAST_HY2_MASQUERADE_CN" || return 1
    
    LAST_REALITY_PORT=""
    LAST_REALITY_UUID=""
    LAST_REALITY_PUBLIC_KEY=""
    LAST_REALITY_SNI=""
    LAST_VLESS_LINK=""

    create_config_json "hysteria2" \
        "$LAST_HY2_PORT" "$LAST_HY2_PASSWORD" "$LAST_HY2_MASQUERADE_CN" \
        "" "" "" "" \
        || return 1

    create_systemd_service
    start_singbox_service || return 1

    success "Hysteria2 单独安装配置完成！"
    display_and_store_config_info "hysteria2"
}

install_reality_only() {
    info "开始单独安装 Reality (VLESS)..."
    install_singbox_core || return 1
    get_server_ip

    read -p "请输入 Reality (VLESS) 监听端口 (默认: ${DEFAULT_REALITY_PORT}): " temp_reality_port
    LAST_REALITY_PORT=${temp_reality_port:-$DEFAULT_REALITY_PORT}
    read -p "请输入 Reality 目标SNI/握手服务器 (默认: ${DEFAULT_REALITY_SNI}): " temp_reality_sni
    LAST_REALITY_SNI=${temp_reality_sni:-$DEFAULT_REALITY_SNI}

    generate_reality_credentials || return 1
    
    LAST_HY2_PORT=""
    LAST_HY2_PASSWORD=""
    LAST_HY2_MASQUERADE_CN=""
    LAST_HY2_LINK=""

    create_config_json "reality" \
        "" "" "" \
        "$LAST_REALITY_PORT" "$LAST_REALITY_UUID" "$TEMP_REALITY_PRIVATE_KEY" "$LAST_REALITY_SNI" \
        || return 1
        
    create_systemd_service
    start_singbox_service || return 1

    success "Reality (VLESS) 单独安装配置完成！"
    display_and_store_config_info "reality"
}
install_socks5_only() {
    info "开始单独安装 socks5..."
    install_singbox_core || return 1
    get_server_ip

    # 让用户输入端口、用户名、密码，如果直接回车就用默认值
    read -p "请输入 socks5 监听端口 (默认: 10808): " temp_socks5_port
    SOCKS5_PORT=${temp_socks5_port:-10808}
    read -p "请输入 socks5 用户名 (默认: user): " temp_socks5_user
    SOCKS5_USER=${temp_socks5_user:-user}
    read -p "请输入 socks5 密码 (默认: pass): " temp_socks5_pass
    SOCKS5_PASS=${temp_socks5_pass:-pass}

    # 清空其他协议相关的全局变量
    LAST_HY2_PORT=""
    LAST_HY2_PASSWORD=""
    LAST_HY2_MASQUERADE_CN=""
    LAST_HY2_LINK=""
    LAST_REALITY_PORT=""
    LAST_REALITY_UUID=""
    LAST_REALITY_PUBLIC_KEY=""
    LAST_REALITY_SNI=""
    LAST_VLESS_LINK=""
    LAST_INSTALL_MODE="socks5"

    # 调用配置文件生成函数
    create_config_json "socks5" "" "" "" "" "" "" "" || return 1

    create_systemd_service
    start_singbox_service || return 1

    success "socks5 单独安装配置完成！"
    display_and_store_config_info "socks5"
}

show_current_import_info() {
    if [ -z "$LAST_INSTALL_MODE" ]; then
        warn "尚未通过此脚本安装任何配置，或上次安装信息未保留。"
        info "请先执行安装操作 (选项 1, 2, 或 3)，或者确保 ${PERSISTENT_INFO_FILE} 文件存在且包含信息。"
        pause_return_menu
        return
    fi
    info "显示上次保存的配置信息 (${LAST_INSTALL_MODE}模式):"
    display_and_store_config_info "$LAST_INSTALL_MODE"
    pause_return_menu
}

uninstall_singbox() {
    warn "你确定要卸载 Sing-box 吗?"
    read -p "此操作将停止并禁用服务，删除可执行文件和相关配置文件目录。是否继续卸载? (y/N): " confirm_uninstall
    if [[ ! "$confirm_uninstall" =~ ^[Yy]$ ]]; then
        info "卸载已取消。"
        return
    fi

    info "正在停止 sing-box 服务..."
    systemctl stop sing-box &>/dev/null
    info "正在禁用 sing-box 服务..."
    systemctl disable sing-box &>/dev/null

    if [ -f "$SINGBOX_SERVICE_FILE" ]; then
        info "正在删除 systemd 服务文件: ${SINGBOX_SERVICE_FILE}"
        rm -f "$SINGBOX_SERVICE_FILE"
        systemctl daemon-reload
    fi

    local singbox_exe_to_remove=""
    if [ -n "$SINGBOX_CMD" ] && [ -f "$SINGBOX_CMD" ]; then
        singbox_exe_to_remove="$SINGBOX_CMD"
    elif [ -f "$SINGBOX_INSTALL_PATH_EXPECTED" ]; then
        singbox_exe_to_remove="$SINGBOX_INSTALL_PATH_EXPECTED"
    fi
    
    local official_install_path="/usr/local/bin/sing-box"
    if [ -f "$official_install_path" ]; then
        if [ -n "$singbox_exe_to_remove" ] && [ "$singbox_exe_to_remove" != "$official_install_path" ]; then
            info "正在删除 sing-box 执行文件: $official_install_path (官方脚本位置)"
            rm -f "$official_install_path"
        elif [ -z "$singbox_exe_to_remove" ]; then
             singbox_exe_to_remove="$official_install_path"
        fi
    fi

    if [ -n "$singbox_exe_to_remove" ] && [ -f "$singbox_exe_to_remove" ]; then
        info "正在删除 sing-box 执行文件: $singbox_exe_to_remove"
        rm -f "$singbox_exe_to_remove"
    else
        warn "未找到明确的 sing-box 执行文件进行删除 (已检查 ${SINGBOX_INSTALL_PATH_EXPECTED} 和 ${official_install_path})。"
    fi
    
    read -p "是否删除配置文件目录 ${SINGBOX_CONFIG_DIR} (包含导入信息缓存)? (y/N): " delete_config_dir_confirm
    if [[ "$delete_config_dir_confirm" =~ ^[Yy]$ ]]; then
        if [ -d "$SINGBOX_CONFIG_DIR" ]; then
            info "正在删除配置目录 (包括 ${PERSISTENT_INFO_FILE})..."
            rm -rf "$SINGBOX_CONFIG_DIR"
        fi
    else
        info "配置文件目录 (${SINGBOX_CONFIG_DIR}) 已保留。"
    fi
    
    read -p "是否删除 Hysteria2 证书目录 ${HYSTERIA_CERT_DIR}? (y/N): " delete_cert_dir_confirm
     if [[ "$delete_cert_dir_confirm" =~ ^[Yy]$ ]]; then
        if [ -d "$HYSTERIA_CERT_DIR" ]; then
            info "正在删除 Hysteria2 证书目录..."
            rm -rf "$HYSTERIA_CERT_DIR"
        fi
    else
        info "Hysteria2 证书目录 (${HYSTERIA_CERT_DIR}) 已保留。"
    fi


    success "Sing-box 卸载完成。"
    LAST_INSTALL_MODE="" 
    SINGBOX_CMD=""
}

# --- Management Functions ---
manage_singbox() {
    local action=$1
    if [ -z "$SINGBOX_CMD" ]; then
        warn "Sing-box command 未设置, 尝试查找..."
        find_and_set_singbox_cmd
        if [ -z "$SINGBOX_CMD" ]; then
            error "仍然无法找到 Sing-box command. 操作中止。"
            return 1
        fi
    fi

    case "$action" in
        start)
            systemctl start sing-box
            if systemctl is-active --quiet sing-box; then success "Sing-box 服务已启动。"; else error "Sing-box 服务启动失败。"; fi
            pause_return_menu
            ;;
        stop)
            systemctl stop sing-box
            if ! systemctl is-active --quiet sing-box; then success "Sing-box 服务已停止。"; else error "Sing-box 服务停止失败。"; fi
            pause_return_menu
            ;;
        restart)
            if [ -f "$SINGBOX_CONFIG_FILE" ]; then
                info "重启前检查配置文件..."
                if ! $SINGBOX_CMD check -c "$SINGBOX_CONFIG_FILE"; then
                    error "配置文件检查失败，无法重启。请先修复配置文件。"
                    pause_return_menu
                    return 1
                fi
                success "配置文件检查通过。"
            fi
            systemctl restart sing-box
            sleep 1
            if systemctl is-active --quiet sing-box; then success "Sing-box 服务已重启。"; else error "Sing-box 服务重启失败。"; fi
            pause_return_menu
            ;;
        status)
            systemctl status sing-box --no-pager -l
            pause_return_menu
            ;;
        log)
            journalctl -u sing-box -f --no-pager -n 50
            pause_return_menu
            ;;
        view_config)
            if [ -f "$SINGBOX_CONFIG_FILE" ]; then
                info "当前配置文件 (${SINGBOX_CONFIG_FILE}):"
                cat "$SINGBOX_CONFIG_FILE"
            else
                error "配置文件不存在: ${SINGBOX_CONFIG_FILE}"
            fi
            pause_return_menu
            ;;
        edit_config)
            if [ -f "$SINGBOX_CONFIG_FILE" ]; then
                if command -v nano &> /dev/null; then
                    nano "$SINGBOX_CONFIG_FILE"
                elif command -v vim &> /dev/null; then
                    vim "$SINGBOX_CONFIG_FILE"
                else
                    error "'nano' 或 'vim' 编辑器未安装。请手动编辑: ${SINGBOX_CONFIG_FILE}"
                    pause_return_menu
                    return
                fi
                read -p "配置文件已编辑，是否立即重启 sing-box 服务? (y/N): " restart_confirm
                if [[ "$restart_confirm" =~ ^[Yy]$ ]]; then
                    manage_singbox "restart"
                fi
            else
                error "配置文件不存在: ${SINGBOX_CONFIG_FILE}"
            fi
            pause_return_menu
            ;;
        *)
            error "无效的管理操作: $action"
            pause_return_menu
            ;;
    esac
}

update_script_online() {
    local update_url="https://github.com/shangguancaiyun/One-Click-Proxy-Installer/raw/main/lvhy.sh"
    local tmpfile="/tmp/lvhy_update_$$.sh"
    echo "正在从远程仓库下载最新版脚本..."
    if curl -fsSL "$update_url" -o "$tmpfile"; then
        chmod +x "$tmpfile"
        if [ -f "$0" ] && [ -w "$0" ]; then
            cp "$tmpfile" "$0"
            echo -e "${GREEN}脚本已更新为最新版！${NC}"
        else
            echo -e "${YELLOW}当前脚本不是本地文件，或没有写权限，未自动覆盖。${NC}"
            echo -e "${YELLOW}你可以手动用如下命令更新：${NC}"
            echo -e "${CYAN}curl -fsSL \"$update_url\" -o lvhy.sh && chmod +x lvhy.sh${NC}"
        fi
        rm -f "$tmpfile"
    else
        echo -e "${RED}下载失败，请检查网络或稍后重试。${NC}"
    fi
    echo
    read -n 1 -s -r -p "按任意键返回主菜单..."
    echo
}

toolbox_menu() {
    while true; do
        clear
        echo -e "${MAGENTA}${BOLD}================ 工具箱 ================${NC}"
        echo "  1. 更新 Sing-box 内核 (使用官方beta脚本)"
        echo "  2. 开发所有端口 (一键放行0-65535，风险自负)"
        echo "  3. 本机信息"
        echo "  4. DNS优化（国内/国外分流）"
        echo "  5. BBR管理"
        echo "  6. 组件管理"
        echo "  7. 系统时区调整"
        echo "  8. 切换优先IPv4/IPv6"
        echo "  9. 修改Root密码"
        echo " 10. 开启Root密码登录"
        echo " 11. 重启服务器"
        echo "  0. 返回主菜单"
        echo -e "${MAGENTA}${BOLD}========================================${NC}"
        read -p "请输入选项 [0-13]: " tb_choice
        case "$tb_choice" in
            1)
                install_singbox_core && manage_singbox "restart"
                read -n 1 -s -r -p "按任意键返回工具箱..."
                ;;
            2)
                echo -e "${YELLOW}警告：此操作将放行所有端口（0-65535），有极大安全风险，仅建议在受信任环境下使用！${NC}"
                read -p "确定要继续吗？(y/N): " confirm_open
                if [[ "$confirm_open" =~ ^[Yy]$ ]]; then
                    if command -v ufw &>/dev/null; then
                        sudo ufw allow 0:65535/tcp
                        sudo ufw allow 0:65535/udp
                        sudo ufw reload
                        echo "已通过 ufw 放行全部端口。"
                    elif command -v firewall-cmd &>/dev/null; then
                        sudo firewall-cmd --permanent --add-port=0-65535/tcp
                        sudo firewall-cmd --permanent --add-port=0-65535/udp
                        sudo firewall-cmd --reload
                        echo "已通过 firewalld 放行全部端口。"
                    else
                        echo "未检测到常见防火墙（ufw/firewalld），请手动放行端口。"
                    fi
                else
                    echo "操作已取消。"
                fi
                read -n 1 -s -r -p "按任意键返回工具箱..."
                ;;
            3)
                echo -e "${CYAN}${BOLD}\n========= 本机信息 =========${NC}"
                # 主机名、系统
                echo -e "${YELLOW}主机名:${NC}      $(hostname)"
                echo -e "${YELLOW}系统:${NC}        $(uname -o)"
                echo -e "${YELLOW}Linux版本:${NC}   $(uname -r)"
                echo -e "${YELLOW}发行版:${NC}      $(. /etc/os-release 2>/dev/null; echo $PRETTY_NAME)"
                # CPU
                echo -e "${YELLOW}CPU架构:${NC}     $(uname -m)"
                echo -e "${YELLOW}CPU型号:${NC}     $(awk -F: '/model name/ {print $2; exit}' /proc/cpuinfo | xargs)"
                echo -e "${YELLOW}CPU核心数:${NC}   $(nproc)"
                echo -e "${YELLOW}CPU占用:${NC}     $(top -bn1 | awk '/Cpu/ {print $2"%"; exit}')"
                # 内存
                mem_total=$(free -h | awk '/Mem:/ {print $2}')
                mem_used=$(free -h | awk '/Mem:/ {print $3}')
                swap_total=$(free -h | awk '/Swap:/ {print $2}')
                swap_used=$(free -h | awk '/Swap:/ {print $3}')
                echo -e "${YELLOW}物理内存:${NC}    $mem_used / $mem_total"
                echo -e "${YELLOW}虚拟内存:${NC}    $swap_used / $swap_total"
                # 硬盘
                disk_total=$(df -h --total | awk '/total/ {print $2}')
                disk_used=$(df -h --total | awk '/total/ {print $3}')
                echo -e "${YELLOW}硬盘占用:${NC}    $disk_used / $disk_total"
                # 流量
                rx=$(cat /proc/net/dev | awk '/:/ {sum+=$2} END {print sum/1024/1024 " MB"}')
                tx=$(cat /proc/net/dev | awk '/:/ {sum+=$10} END {print sum/1024/1024 " MB"}')
                echo -e "${YELLOW}总接收流量:${NC}  $rx"
                echo -e "${YELLOW}总发送流量:${NC}  $tx"
                # 拥堵算法
                cc_alg=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
                echo -e "${YELLOW}网络拥堵算法:${NC} $cc_alg"
                # 公网IP
                ipv4=$(curl -s --max-time 3 https://api.ipify.org)
                ipv6=$(curl -s --max-time 3 https://api6.ipify.org)
                echo -e "${YELLOW}公网IPv4:${NC}    $ipv4"
                echo -e "${YELLOW}公网IPv6:${NC}    $ipv6"
                # 运营商与地理位置
                ipinfo=$(curl -s --max-time 5 ipinfo.io/json)
                isp=$(echo "$ipinfo" | grep 'org' | awk -F: '{print $2}' | tr -d ' ",')
                loc=$(echo "$ipinfo" | grep 'city' | awk -F: '{print $2}' | tr -d ' ",')
                country=$(echo "$ipinfo" | grep 'country' | awk -F: '{print $2}' | tr -d ' ",')
                echo -e "${YELLOW}运营商:${NC}      $isp"
                echo -e "${YELLOW}地理位置:${NC}    $loc, $country"
                # 系统时间与运行时长
                echo -e "${YELLOW}系统时间:${NC}    $(date '+%Y-%m-%d %H:%M:%S')"
                echo -e "${YELLOW}运行时长:${NC}    $(uptime -p)"
                echo -e "${CYAN}${BOLD}==============================${NC}\n"
                read -n 1 -s -r -p "按任意键返回工具箱..."
                ;;
            4)
                # DNS优化
                echo -e "${CYAN}请选择DNS优化方案："
                echo "  1. 国外DNS (1.1.1.1, 8.8.8.8)"
                echo "  2. 国内DNS (223.5.5.5, 180.76.76.76, 114.114.114.114)"
                echo "  0. 取消"
                read -p "请输入选项 [0-2]: " dns_opt
                case "$dns_opt" in
                    1)
                        echo -e "nameserver 1.1.1.1\nnameserver 8.8.8.8" | sudo tee /etc/resolv.conf
                        echo "已切换为国外DNS。"
                        ;;
                    2)
                        echo -e "nameserver 223.5.5.5\nnameserver 180.76.76.76\nnameserver 114.114.114.114" | sudo tee /etc/resolv.conf
                        echo "已切换为国内DNS。"
                        ;;
                    *)
                        echo "操作已取消。"
                        ;;
                esac
                read -n 1 -s -r -p "按任意键返回工具箱..."
                ;;
            5)
                if [ -f ./bbr_manage.sh ]; then
                    source ./bbr_manage.sh
                else
                    echo "未找到 bbr_manage.sh，请检查文件是否存在于当前目录。"
                    read -n 1 -s -r -p "按任意键返回工具箱..."
                fi
                ;;
            6)
                # 组件管理
                while true; do
                    clear
                    echo -e "${CYAN}组件管理："
                    echo "  1. 安装curl"
                    echo "  2. 安装wget"
                    echo "  3. 安装sudo"
                    echo "  4. 安装unzip"
                    echo "  0. 返回"
                    read -p "请输入选项 [0-4]: " comp_opt
                    case "$comp_opt" in
                        1)
                            if command -v curl &>/dev/null; then echo "curl已安装。"; else sudo apt-get install -y curl || sudo yum install -y curl; fi
                            ;;
                        2)
                            if command -v wget &>/dev/null; then echo "wget已安装。"; else sudo apt-get install -y wget || sudo yum install -y wget; fi
                            ;;
                        3)
                            if command -v sudo &>/dev/null; then echo "sudo已安装。"; else apt-get install -y sudo || yum install -y sudo; fi
                            ;;
                        4)
                            if command -v unzip &>/dev/null; then echo "unzip已安装。"; else sudo apt-get install -y unzip || sudo yum install -y unzip; fi
                            ;;
                        0)
                            break
                            ;;
                        *)
                            echo "无效选项。"; sleep 1
                            ;;
                    esac
                    read -n 1 -s -r -p "按任意键返回组件管理..."
                done
                ;;
            7)
                # 系统时区调整
                echo -e "${CYAN}请选择时区："
                echo "  1. Asia/Shanghai (中国)"
                echo "  2. UTC (世界标准)"
                echo "  0. 取消"
                read -p "请输入选项 [0-2]: " tz_opt
                case "$tz_opt" in
                    1)
                        sudo timedatectl set-timezone Asia/Shanghai
                        echo "已切换为Asia/Shanghai。"
                        ;;
                    2)
                        sudo timedatectl set-timezone UTC
                        echo "已切换为UTC。"
                        ;;
                    *)
                        echo "操作已取消。"
                        ;;
                esac
                read -n 1 -s -r -p "按任意键返回工具箱..."
                ;;
            8)
                # 切换优先IPv4/IPv6
                echo -e "${CYAN}请选择优先协议："
                echo "  1. 优先IPv4"
                echo "  2. 优先IPv6"
                echo "  0. 取消"
                read -p "请输入选项 [0-2]: " ipver_opt
                case "$ipver_opt" in
                    1)
                        sudo sed -i '/^precedence ::ffff:0:0\/96  100$/d' /etc/gai.conf
                        echo 'precedence ::ffff:0:0/96  100' | sudo tee -a /etc/gai.conf
                        echo "已设置为优先IPv4。"
                        ;;
                    2)
                        sudo sed -i '/^precedence ::ffff:0:0\/96  100$/d' /etc/gai.conf
                        echo "已设置为优先IPv6。"
                        ;;
                    *)
                        echo "操作已取消。"
                        ;;
                esac
                read -n 1 -s -r -p "按任意键返回工具箱..."
                ;;
            9)
                # 修改Root密码
                echo -e "${CYAN}请输入新Root密码："
                sudo passwd root
                read -n 1 -s -r -p "按任意键返回工具箱..."
                ;;
            10)
                # 开启Root密码登录
                sudo sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
                sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
                sudo systemctl restart sshd || sudo systemctl restart ssh
                echo "已开启Root密码登录（请确保已设置Root密码）。"
                read -n 1 -s -r -p "按任意键返回工具箱..."
                ;;
            11)
                # 重启服务器
                echo -e "${YELLOW}警告：即将重启服务器，是否继续？${NC}"
                read -p "输入y确认重启，其他键取消: " reboot_confirm
                if [[ "$reboot_confirm" =~ ^[Yy]$ ]]; then
                    sudo reboot
                else
                    echo "操作已取消。"
                fi
                read -n 1 -s -r -p "按任意键返回工具箱..."
                ;;
            0)
                break
                ;;
            *)
                echo "无效选项，请输入 0-13。"
                sleep 1
                ;;
        esac
    done
}

# --- Main Menu ---
show_menu() {
    clear
    print_author_info
    echo -e "${MAGENTA}${BOLD}=================【安装相关】==================${NC}"
    echo "  1. 安装 Hysteria2 + Reality (共存)"
    echo "  2. 单独安装 Hysteria2"
    echo "  3. 单独安装 Reality (VLESS)"
    echo "  4. 单独安装 socks5"
    echo -e "${MAGENTA}${BOLD}=================【管理相关】==================${NC}"
    echo "  4. 启动 Sing-box 服务"
    echo "  5. 停止 Sing-box 服务"
    echo "  6. 重启 Sing-box 服务"
    echo "  7. 查看 Sing-box 服务状态"
    echo "  8. 查看 Sing-box 实时日志"
    echo "  9. 查看当前配置文件"
    echo " 10. 编辑当前配置文件 (nano/vim)"
    echo " 11. 显示\"节点\"的导入信息 (含二维码)"
    echo " 12. 修改节点参数（端口/IP/UUID等）"
    echo -e "${MAGENTA}${BOLD}=================【工具箱】====================${NC}"
    echo " 13. 工具箱"
    echo -e "${MAGENTA}${BOLD}=================【其他】======================${NC}"
    echo " 14. 卸载 Sing-box"
    echo " 15. 更改快捷指令"
    echo " 16. 在线更新脚本"
    echo "  0. 退出脚本"
    echo -e "${MAGENTA}${BOLD}===============================================${NC}"
    read -p "请输入选项 [0-16]: " choice

    case "$choice" in
        1) install_hysteria2_reality ;;
        2) install_hysteria2_only ;;
        3) install_reality_only ;;
        4) install_socks5_only ;;
        4) manage_singbox "start" ;;
        5) manage_singbox "stop" ;;
        6) manage_singbox "restart" ;;
        7) manage_singbox "status" ;;
        8) manage_singbox "log" ;;
        9) manage_singbox "view_config" ;;
        10) manage_singbox "edit_config" ;;
        11) show_current_import_info ;;
        12)
            bash ./modify_node_params.sh
            ;;
        13) toolbox_menu ;;
        14) uninstall_singbox ;;
        15) change_quick_cmd ;;
        16) update_script_online ;;
        0) exit 0 ;;
        *) error "无效选项，请输入 0 到 16 之间的数字。" ;;
    esac
    echo "" 
}

# --- Script Entry Point ---
check_root
check_dependencies # 已移除 jq 依赖检查
find_and_set_singbox_cmd
load_persistent_info

# Main loop
while true; do
    show_menu
    # 只在需要时 pause，show_menu 内部不再 pause
    # read -n 1 -s -r -p "按任意键返回主菜单 (或按 Ctrl+C 退出)..."
done

# --- 脚本末尾自动化一键设置快捷命令功能 ---
if [ "$(basename $0)" != "$QUICK_CMD_NAME" ] && [ ! -f "/usr/local/bin/$QUICK_CMD_NAME" ]; then
    sudo cp "$0" "/usr/local/bin/$QUICK_CMD_NAME"
    sudo chmod +x "/usr/local/bin/$QUICK_CMD_NAME"
    echo "\n已自动设置快捷命令：box。你可以在任意目录输入 box 快速管理 Sing-Box 节点！"
fi

# --- 参数便捷修改与节点删除功能 ---
modify_node_params() {
    if [ ! -f "$SINGBOX_CONFIG_FILE" ]; then
        error "未检测到配置文件，无法修改参数。"
        pause_return_menu
        return
    fi
    while true; do
        clear
        echo -e "${CYAN}${BOLD}当前节点参数:${NC}"
        echo "  1. Hysteria2 端口: $LAST_HY2_PORT"
        echo "  2. Hysteria2 伪装域名: $LAST_HY2_MASQUERADE_CN"
        echo "  3. Reality 端口: $LAST_REALITY_PORT"
        echo "  4. Reality UUID: $LAST_REALITY_UUID"
        echo "  5. Reality SNI: $LAST_REALITY_SNI"
        echo "  6. 删除当前节点（清空配置）"
        echo "  0. 返回主菜单"
        read -p "请选择要操作的项目 [0-6]: " param_choice
        case "$param_choice" in
            1)
                read -p "请输入新的 Hysteria2 端口: " new_port
                if [[ -n "$new_port" ]]; then
                    sed -i "s/\"listen_port\": $LAST_HY2_PORT/\"listen_port\": $new_port/" "$SINGBOX_CONFIG_FILE"
                    LAST_HY2_PORT="$new_port"
                    save_persistent_info
                    systemctl restart sing-box
                    success "Hysteria2 端口已修改并重启服务。"
                fi
                ;;
            2)
                read -p "请输入新的 Hysteria2 伪装域名: " new_cn
                if [[ -n "$new_cn" ]]; then
                    sed -i "s/\"server_name\": \"$LAST_HY2_MASQUERADE_CN\"/\"server_name\": \"$new_cn\"/" "$SINGBOX_CONFIG_FILE"
                    LAST_HY2_MASQUERADE_CN="$new_cn"
                    save_persistent_info
                    systemctl restart sing-box
                    success "Hysteria2 伪装域名已修改并重启服务。"
                fi
                ;;
            3)
                read -p "请输入新的 Reality 端口: " new_port
                if [[ -n "$new_port" ]]; then
                    sed -i "s/\"listen_port\": $LAST_REALITY_PORT/\"listen_port\": $new_port/" "$SINGBOX_CONFIG_FILE"
                    LAST_REALITY_PORT="$new_port"
                    save_persistent_info
                    systemctl restart sing-box
                    success "Reality 端口已修改并重启服务。"
                fi
                ;;
            4)
                read -p "请输入新的 Reality UUID: " new_uuid
                if [[ -n "$new_uuid" ]]; then
                    sed -i "s/\"uuid\": \"$LAST_REALITY_UUID\"/\"uuid\": \"$new_uuid\"/" "$SINGBOX_CONFIG_FILE"
                    LAST_REALITY_UUID="$new_uuid"
                    save_persistent_info
                    systemctl restart sing-box
                    success "Reality UUID已修改并重启服务。"
                fi
                ;;
            5)
                read -p "请输入新的 Reality SNI: " new_sni
                if [[ -n "$new_sni" ]]; then
                    sed -i "s/\"server_name\": \"$LAST_REALITY_SNI\"/\"server_name\": \"$new_sni\"/" "$SINGBOX_CONFIG_FILE"
                    LAST_REALITY_SNI="$new_sni"
                    save_persistent_info
                    systemctl restart sing-box
                    success "Reality SNI已修改并重启服务。"
                fi
                ;;
            6)
                read -p "确定要删除当前节点配置吗？此操作不可恢复！(y/N): " del_confirm
                if [[ "$del_confirm" =~ ^[Yy]$ ]]; then
                    rm -f "$SINGBOX_CONFIG_FILE"
                    rm -f "$PERSISTENT_INFO_FILE"
                    systemctl stop sing-box
                    LAST_HY2_PORT=""
                    LAST_HY2_MASQUERADE_CN=""
                    LAST_REALITY_PORT=""
                    LAST_REALITY_UUID=""
                    LAST_REALITY_SNI=""
                    LAST_INSTALL_MODE=""
                    success "节点配置已删除，Sing-box 服务已停止。"
                    pause_return_menu
                    break
                else
                    echo "操作已取消。"
                    pause_return_menu
                fi
                ;;
            0)
                pause_return_menu
                break
                ;;
            *)
                echo "无效选项。"
                ;;
        esac
        pause_return_menu
    done
}
