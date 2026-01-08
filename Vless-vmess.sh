#!/bin/bash
# 一键安装 Xray VMess/VLESS WS (随机端口，无 TLS)
# 同时兼容 Alpine 2.0 有 root & 无 root 容器

# 生成随机端口函数
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

# 生成随机端口
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

# 启动 Xray
if [ "$IS_ROOT" = true ]; then
    echo "=== 启动 Xray (OpenRC) ==="
    rc-update add xray
    rc-service xray restart
else
    echo "=== 非 root 模式，使用用户模式启动 Xray ==="
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

# 输出节点信息
echo -e "\n=== 安装完成 ==="
echo "服务器 IP/域名: $SERVER_IP"
echo "VLESS 节点: $VLESS_LINK"
echo "VMess 节点: $VMESS_LINK"
echo "WebSocket 路径: /"
echo "VLESS 端口: $VLESS_PORT, VMess 端口: $VMESS_PORT"

# 显示二维码
echo -e "\n=== VLESS QR码 ==="
echo "$VLESS_LINK" | qrencode -t UTF8

echo -e "\n=== VMess QR码 ==="
echo "$VMESS_LINK" | qrencode -t UTF8

echo -e "\n=== 完成 === 可以直接用客户端扫码导入 ==="