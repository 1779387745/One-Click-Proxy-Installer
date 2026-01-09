#!/bin/bash
# Xray 单节点交互安装脚本
# 支持用户选择服务器公网 IP（IPv4/IPv6）和输出优化，适配 Alpine 系统

# 检查 root 权限
if [[ $EUID -ne 0 ]]; then
    echo "请以 root 用户运行此脚本。"
    exit 1
fi

# 安装依赖
echo "正在安装依赖..."
apk update
apk add --no-cache bash curl unzip lsof qrencode

# 定义路径
XRAY_BIN="/usr/local/bin/xray"
CONFIG_PATH="/usr/local/etc/xray/config.json"

# 下载 Xray
echo "正在下载 Xray..."
mkdir -p /usr/local/etc/xray
curl -L -o /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip -o /tmp/xray.zip -d /usr/local/bin/
chmod +x $XRAY_BIN
rm -f /tmp/xray.zip

# 用户选择节点协议
echo "请选择节点类型："
echo "1. VLESS"
echo "2. VMess"
read -p "输入选项 (1 或 2): " NODE_TYPE
if [[ "$NODE_TYPE" == "1" ]]; then
    PROTOCOL="vless"
    read -p "请输入 VLESS 节点的 UUID（回车生成随机 UUID）: " NODE_UUID
    NODE_UUID=${NODE_UUID:-$($XRAY_BIN uuid)}
elif [[ "$NODE_TYPE" == "2" ]]; then
    PROTOCOL="vmess"
    read -p "请输入 VMess 节点的 UUID（回车生成随机 UUID）: " NODE_UUID
    NODE_UUID=${NODE_UUID:-$($XRAY_BIN uuid)}
else
    echo "无效选项，退出脚本。"
    exit 1
fi

# 用户配置输入
read -p "请输入节点使用的端口（回车随机生成）: " NODE_PORT
NODE_PORT=${NODE_PORT:-$((RANDOM % 55535 + 10000))}

read -p "请输入 WebSocket 路径（默认 /）: " WS_PATH
WS_PATH=${WS_PATH:-/}

# 选择公网 IP 地址类型
echo "尝试获取服务器的公网 IP..."
SERVER_IPV4=$(curl -s4 ifconfig.me)
SERVER_IPV6=$(curl -s6 ifconfig.me)

if [[ -n "$SERVER_IPV4" ]] && [[ -n "$SERVER_IPV6" ]]; then
    echo "检测到以下公网 IP："
    echo "1. IPv4: $SERVER_IPV4 (默认)"
    echo "2. IPv6: $SERVER_IPV6"
    read -p "请选择 IP 类型 (1 或 2，默认 1): " IP_TYPE
    if [[ "$IP_TYPE" == "2" ]]; then
        SERVER_IP=$SERVER_IPV6
    else
        SERVER_IP=$SERVER_IPV4
    fi
elif [[ -n "$SERVER_IPV4" ]]; then
    echo "仅检测到公网 IPv4：$SERVER_IPV4，使用 IPv4。"
    SERVER_IP=$SERVER_IPV4
elif [[ -n "$SERVER_IPV6" ]]; then
    echo "仅检测到公网 IPv6：$SERVER_IPV6，使用 IPv6。"
    SERVER_IP=$SERVER_IPV6
else
    echo "无法检测公网 IP，请检查网络连接。"
    exit 1
fi

# 配置文件生成
echo "正在生成 Xray 配置文件..."
cat > $CONFIG_PATH <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "port": $NODE_PORT,
      "protocol": "$PROTOCOL",
      "settings": {
        "clients": [
          { "id": "$NODE_UUID" }
        ]${PROTOCOL:+,"alterId": 0}
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "$WS_PATH" }
      }
    }
  ],
  "outbounds": [ { "protocol": "freedom", "settings": {} } ]
}
EOF

# 启动 Xray
echo "正在启动 Xray..."
nohup $XRAY_BIN -config $CONFIG_PATH >/dev/null 2>&1 &

# 节点信息展示
echo -e "\n========== 节点信息 =========="
if [[ "$PROTOCOL" == "vless" ]]; then
    # 优化输出 VLESS 节点链接
    VLESS_LINK="vless://$NODE_UUID@$SERVER_IP:$NODE_PORT?type=ws&path=$WS_PATH"
    echo "$VLESS_LINK"
elif [[ "$PROTOCOL" == "vmess" ]]; then
    # 优化输出 VMess 节点链接
    VMESS_JSON=$(cat <<EOF
{
  "v": "2",
  "ps": "VMess-WS",
  "add": "$SERVER_IP",
  "port": "$NODE_PORT",
  "id": "$NODE_UUID",
  "aid": "0",
  "net": "ws",
  "type": "none",
  "path": "$WS_PATH",
  "tls": ""
}
EOF
)
    VMESS_LINK="vmess://$(echo $VMESS_JSON | base64 -w 0)"
    echo "$VMESS_LINK"
fi
echo "============================="