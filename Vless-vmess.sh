#!/bin/bash
# 一键安装 Xray + VMess/VLESS WS（无 TLS） + 随机端口 + 生成客户端可用节点

# 检查 root 权限
if [[ $EUID -ne 0 ]]; then
   echo "请使用 root 用户运行此脚本"
   exit 1
fi

# 安装 Xray
bash <(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)

# 生成 UUID
VMESS_UUID=$(xray uuid)
VLESS_UUID=$(xray uuid)

# 随机端口函数
get_random_port() {
  while :; do
    PORT=$((RANDOM % 55535 + 10000))  # 10000-65535
    if ! lsof -i:$PORT &>/dev/null; then
      echo $PORT
      return
    fi
  done
}

VMESS_PORT=$(get_random_port)
VLESS_PORT=$(get_random_port)

# 服务器 IP 或域名（请自行修改）
SERVER_IP=$(curl -s ifconfig.me)

# 配置文件路径
CONFIG_PATH="/usr/local/etc/xray/config.json"

# 写入配置文件
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

# 启动 Xray
systemctl enable xray
systemctl restart xray

# 生成客户端可用节点
# VMess 节点链接
VMESS_LINK=$(echo "{
  \"v\": \"2\",
  \"ps\": \"VMess-WS\",
  \"add\": \"$SERVER_IP\",
  \"port\": \"$VMESS_PORT\",
  \"id\": \"$VMESS_UUID\",
  \"aid\": \"0\",
  \"net\": \"ws\",
  \"type\": \"none\",
  \"host\": \"\",
  \"path\": \"/\",
  \"tls\": \"\"
}" | base64 -w0 | sed 's/$/==/')

# VLESS 节点链接
VLESS_LINK="vless://$VLESS_UUID@$SERVER_IP:$VLESS_PORT?type=ws&path=/#VLESS-WS"

echo -e "\n=== 安装完成 ==="
echo "服务器 IP/域名: $SERVER_IP"
echo "VLESS 节点: $VLESS_LINK"
echo "VMess 节点 (base64): vmess://$VMESS_LINK"
echo "WebSocket 路径: /"