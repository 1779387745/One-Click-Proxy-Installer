#!/bin/sh
# Alpine 2.0 compatible Xray installer (no apk, no bash)

set -e

# ===== 基础路径 =====
BASE="$HOME/xray"
BIN="$BASE/xray"
CONF="$BASE/config.json"

mkdir -p "$BASE"

# ===== 随机端口 =====
rand_port() {
  echo $(( ( $$ + $(date +%s) ) % 20000 + 10000 ))
}

VLESS_PORT=$(rand_port)
VMESS_PORT=$(rand_port)

# ===== UUID =====
uuid() {
  cat /proc/sys/kernel/random/uuid
}

VLESS_UUID=$(uuid)
VMESS_UUID=$(uuid)

# ===== 获取 IP =====
IP=$(wget -qO- https://api.ipify.org || echo "YOUR_IP")

# ===== 下载 Xray（tar.gz）=====
if [ ! -x "$BIN" ]; then
  echo "[+] Downloading Xray..."
  wget -O "$BASE/xray.tar.gz" \
    https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.tar.gz
  tar -xzf "$BASE/xray.tar.gz" -C "$BASE"
  chmod +x "$BIN"
fi

# ===== 生成配置 =====
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
  "outbounds": [{ "protocol": "freedom" }]
}
EOF

# ===== 启动 =====
echo "[+] Starting Xray..."
nohup "$BIN" run -config "$CONF" >/dev/null 2>&1 &

# ===== 节点输出 =====
VLESS_LINK="vless://$VLESS_UUID@$IP:$VLESS_PORT?type=ws&path=/#VLESS-WS"
VMESS_JSON=$(printf '{"v":"2","ps":"VMess-WS","add":"%s","port":"%s","id":"%s","aid":"0","net":"ws","type":"none","host":"","path":"/","tls":""}' \
"$IP" "$VMESS_PORT" "$VMESS_UUID")
VMESS_LINK="vmess://$(echo "$VMESS_JSON" | base64 | tr -d '\n')"

echo ""
echo "========= 节点信息 ========="
echo "VLESS  : $VLESS_LINK"
echo "VMess  : $VMESS_LINK"
echo "路径   : /"
echo "============================"