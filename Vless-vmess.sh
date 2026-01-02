#!/bin/bash
# 一键安装 Xray VMess/VLESS WS (随机端口，无 TLS) + sb 管理命令
# 兼容 Alpine 2.0 有 root & 无 root 容器

get_random_port() {
    while :; do
        PORT=$((RANDOM % 55535 + 10000))
        if ! lsof -i:$PORT &>/dev/null 2>/dev/null; then
            echo $PORT
            return
        fi
    done
}

# 判断是否 root
if [[ $EUID -eq 0 ]]; then
    IS_ROOT=true
else
    IS_ROOT=false
fi

# 安装依赖（有 root 才能 apk 安装）
if [ "$IS_ROOT" = true ]; then
    echo "=== 安装必要依赖 ==="
    apk update
    apk add bash curl tar coreutils lsof qrencode -y
else
    echo "非 root 模式，跳过依赖安装，确保 bash/curl/tar/lsof/qrencode 已存在"
fi

# 设置 Xray 路径
if [ "$IS_ROOT" = true ]; then
    XRAY_BIN="/usr/local/bin/xray"
    CONFIG_PATH="/usr/local/etc/xray/config.json"
else
    mkdir -p "$HOME/xray"
    XRAY_BIN="$HOME/xray/xray"
    CONFIG_PATH="$HOME/xray/config.json"
fi

# 下载 Xray
if [ ! -f "$XRAY_BIN" ]; then
    echo "=== 下载 Xray ==="
    mkdir -p "$(dirname $XRAY_BIN)"
    curl -L -o /tmp/xray-linux.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
    unzip -o /tmp/xray-linux.zip -d /tmp/xray_temp
    mv /tmp/xray_temp/xray "$XRAY_BIN"
    chmod +x "$XRAY_BIN"
    rm -rf /tmp/xray_temp /tmp/xray-linux.zip
fi

# 生成 UUID
VMESS_UUID=$($XRAY_BIN uuid)
VLESS_UUID=$($XRAY_BIN uuid)

# 随机端口
VMESS_PORT=$(get_random_port)
VLESS_PORT=$(get_random_port)

# 获取服务器公网 IP
SERVER_IP=$(curl -s ifconfig.me)

# 写入配置文件
mkdir -p "$(dirname $CONFIG_PATH)"
cat > "$CONFIG_PATH" <<EOF
{
  "log": { "access": "/var/log/xray/access.log", "error": "/var/log/xray/error.log", "loglevel": "warning" },
  "inbounds": [
    {
      "port": $VLESS_PORT,
      "listen": "0.0.0.0",
      "protocol": "vless",
      "settings": { "clients": [ { "id": "$VLESS_UUID", "flow": "xtls-rprx-direct" } ], "decryption": "none" },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/" }, "security": "none" }
    },
    {
      "port": $VMESS_PORT,
      "listen": "0.0.0.0",
      "protocol": "vmess",
      "settings": { "clients": [ { "id": "$VMESS_UUID", "alterId": 0 } ] },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/" }, "security": "none" }
    }
  ],
  "outbounds": [ { "protocol": "freedom", "settings": {} } ]
}
EOF

# 初始启动
if [ "$IS_ROOT" = true ]; then
    echo "=== 启动 Xray (OpenRC) ==="
    rc-update add xray
    rc-service xray restart
else
    echo "=== 非 root 模式，用户模式启动 Xray ==="
    nohup "$XRAY_BIN" run -config "$CONFIG_PATH" >/dev/null 2>&1 &
fi

# 生成客户端节点
VLESS_LINK="vless://$VLESS_UUID@$SERVER_IP:$VLESS_PORT?type=ws&path=/#VLESS-WS"
VMESS_JSON=$(cat <<EOF
{
  "v":"2",
  "ps":"VMess-WS",
  "add":"$SERVER_IP",
  "port":"$VMESS_PORT",
  "id":"$VMESS_UUID",
  "aid":"0",
  "net":"ws",
  "type":"none",
  "host":"",
  "path":"/",
  "tls":""
}
EOF
)
VMESS_LINK="vmess://$(echo $VMESS_JSON | base64 -w0)"

echo -e "\n=== 安装完成 ==="
echo "服务器 IP/域名: $SERVER_IP"
echo "VLESS 节点: $VLESS_LINK"
echo "VMess 节点: $VMESS_LINK"
echo "WebSocket 路径: /"
echo "VLESS 端口: $VLESS_PORT, VMess 端口: $VMESS_PORT"

echo -e "\n=== VLESS QR码 ==="
echo "$VLESS_LINK" | qrencode -t UTF8
echo -e "\n=== VMess QR码 ==="
echo "$VMESS_LINK" | qrencode -t UTF8

# 创建快捷管理命令 sb
if [ "$IS_ROOT" = true ]; then
    SB_PATH="/usr/local/bin/sb"
else
    SB_PATH="$HOME/bin/sb"
    mkdir -p "$(dirname $SB_PATH)"
fi

cat > "$SB_PATH" <<'EOF'
#!/bin/bash
# sb 小型管理工具
XRAY_BIN="__XRAY_BIN__"
CONFIG_PATH="__CONFIG_PATH__"

function start_xray() {
    if [ "$(id -u)" -eq 0 ]; then
        rc-service xray restart
    else
        nohup "$XRAY_BIN" run -config "$CONFIG_PATH" >/dev/null 2>&1 &
    fi
    echo "Xray 已启动"
}

function stop_xray() {
    if [ "$(id -u)" -eq 0 ]; then
        pkill -f "$XRAY_BIN"
    else
        pkill -f "$XRAY_BIN"
    fi
    echo "Xray 已停止"
}

function status_xray() {
    if pgrep -f "$XRAY_BIN" >/dev/null 2>&1; then
        echo "Xray 正在运行"
    else
        echo "Xray 未运行"
    fi
}

case "$1" in
    start) start_xray ;;
    stop) stop_xray ;;
    status) status_xray ;;
    *) echo "用法: sb {start|stop|status}" ;;
esac
EOF

# 替换路径
sed -i "s#__XRAY_BIN__#$XRAY_BIN#g" "$SB_PATH"
sed -i "s#__CONFIG_PATH__#$CONFIG_PATH#g" "$SB_PATH"
chmod +x "$SB_PATH"

echo -e "\n快捷管理命令已创建："
echo "输入 sb start  → 启动 Xray"
echo "输入 sb stop   → 停止 Xray"
echo "输入 sb status → 查看 Xray 状态"

if [ "$IS_ROOT" = false ]; then
    echo "请确保 \$HOME/bin 在 PATH 中，否则 sb 命令不可用"
    echo "可执行： export PATH=\$HOME/bin:\$PATH"
fi