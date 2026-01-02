#!/bin/sh
# Alpine 2.0 compatible Xray installer
# VMess + VLESS | WebSocket | No TLS | No apk | No bash

set -e

### 基础目录（无 root 也可）
BASE="$HOME/xray"
BIN="$BASE/xray"
CONF="$BASE/config.json"

mkdir -p "$BASE"

### 生成随机端口（10000-60000）
rand_port() {
  echo $(( ( $(date +%s) + $$ ) % 50000 + 10000 ))
}

VLESS_PORT=$(rand_port)
VMESS_PORT=$(rand_port)

### 生成 UUID（BusyBox 兼容）
uuid() {
  cat /proc/sys/kernel/random/uuid
}

VLESS_UUID=$(uuid)
VMESS_UUID=$(uuid)

### 获取公网 IP（失败也不阻断）
IP=$(wget -qO- https://api.ipify.org || echo "YOUR_IP")

### 下载 Xray（tar.gz，避免 unzip）
if [ ! -x "$BIN" ]; then
  echo "[+] Downloading Xray core..."
  wget -O "$BASE/xray.tar.gz" \
    https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.tar.gz
  tar -xzf "$BASE/xray.tar.gz" -C "$BASE"
  chmod +x "$BIN"
fi

### 写入配置文件
cat > "$CONF" <<EOF
{
  "inbounds": [
    {
      "port": $VLESS_PORT,
      "protocol": "vless",
      "settings": {
        "clients": [{ "id": "$VLESS_UUID" }],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "/" }
      }
    },
    {
      "port": $VMESS_PORT,
      "protocol": "vmess",
      "settings": {
        "clients": [{ "id": "$VMESS_UUID", "alterId": 0 }]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "/" }
      }
    }
  ],
  "outbounds": [
    { "protocol": "freedom", "settings": {} }
  ]
}
EOF

### 启动 Xray（后台）
echo "[+] Starting Xray..."
nohup "$BIN" run -config "$CONF" >/dev/null 2>&1 &

### 生成节点
VLESS_LINK="vless://$VLESS_UUID@$IP:$VLESS_PORT?type=ws&path=/#VLESS-WS"

VMESS_JSON=$(printf '{"v":"2","ps":"VMess-WS","add":"%s","port":"%s","id":"%s","aid":"0","net":"ws","type":"none","host":"","path":"/","tls":""}' \
"$IP" "$VMESS_PORT" "$VMESS_UUID")

VMESS_LINK="vmess://$(echo "$VMESS_JSON" | base64 | tr -d '\n')"

### 输出结果
echo ""
echo "================ 节点信息 ================"
echo "VLESS : $VLESS_LINK"
echo "VMess : $VMESS_LINK"
echo "WS路径: /"
echo "=========================================="