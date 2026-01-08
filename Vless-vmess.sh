#!/bin/bash
# 一键安装 Xray + VMess/VLESS WS (无 TLS) + 随机端口 (Alpine 2.0 适用)

# 检查 root
if [[ $EUID -ne 0 ]]; then
    echo "请使用 root 用户运行此脚本"
    exit 1
fi

echo "=== 安装必要依赖 ==="
apk update
apk add bash curl tar coreutils lsof

# 安装 Xray
echo "=== 安装 Xray ==="
bash <(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)

# 生成 UUID
VMESS_UUID=$(xray uuid)
VLESS_UUID=$(xray uuid)

# 随机端口函数
get_random_port() {
    while :; do
        PORT=$((RANDOM % 55535 + 10000))
        if ! lsof -i:$PORT &>/dev/null; then
            echo $PORT
            return
        fi
    done
}

VMESS_PORT=$(get_random_port)
VLESS_PORT=$(get_random_port)

# 获取服务器公网 IP
SERVER_IP=$(curl -s ifconfig.me)

CONFIG_PATH="/usr/local/etc/xray/config.json"

echo "=== 生成 Xray 配置 ==="
cat > $CONFIG_PATH <<EOF
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": $VLESS_PORT,
      "listen": "0.0.0.0",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$VLESS_UUID",
            "flow": "xtls-rprx-direct"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/"
        },
        "security": "none"
      }
    },
    {
      "port": $VMESS_PORT,
      "listen": "0.0.0.0",
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "$VMESS_UUID",
            "alterId": 0
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/"
        },
        "security": "none"
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF

# OpenRC 设置 Xray 自启并启动
echo "=== 设置 Xray 自启并启动 ==="
rc-update add xray
rc-service xray restart

# 生成客户端节点链接
# VMess 节点
VMESS_CONFIG=$(cat <<EOF
{
  "v": "2",
  "ps": "VMess-WS",
  "add": "$SERVER_IP",
  "port": "$VMESS_PORT",
  "id": "$VMESS_UUID",
  "aid": "0",
  "net": "ws",
  "type": "none",
  "host": "",
  "path": "/",
  "tls": ""
}
EOF
)

VMESS_LINK=$(echo $VMESS_CONFIG | base64 -w0 | sed 's/$/==/')
VLESS_LINK="vless://$VLESS_UUID@$SERVER_IP:$VLESS_PORT?type=ws&path=/#VLESS-WS"

echo -e "\n=== 安装完成 ==="
echo "服务器 IP/域名: $SERVER_IP"
echo "VLESS 节点: $VLESS_LINK"
echo "VMess 节点: vmess://$VMESS_LINK"
echo "WebSocket 路径: /"
echo "VLESS 端口: $VLESS_PORT, VMess 端口: $VMESS_PORT"