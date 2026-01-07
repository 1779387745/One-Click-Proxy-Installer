#!/bin/sh
# Alpine / BusyBox / No root Xray Installer
# VMess + VLESS | WS | No TLS | No apk | No bash

set -e

### 基础路径
BASE="$HOME/xray"
BIN="$BASE/xray"
CONF="$BASE/config.json"
PID="$BASE/xray.pid"
INFO="$BASE/nodes.txt"
CTL="$BASE/ss"

mkdir -p "$BASE"

### 端口（BusyBox 兼容）
BASE_PORT=$(( ( $$ % 40000 ) + 10000 ))
VLESS_PORT="$BASE_PORT"
VMESS_PORT=$((BASE_PORT + 1))

### UUID
uuid() {
  cat /proc/sys/kernel/random/uuid
}

VLESS_UUID="$(uuid)"
VMESS_UUID="$(uuid)"

### IP
IP="$(wget -qO- https://api.ipify.org --no-check-certificate || echo 127.0.0.1)"

### 架构识别
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64) XRAY_ARCH="64" ;;
  aarch64|arm64) XRAY_ARCH="arm64-v8a" ;;
  *) echo "Unsupported arch: $ARCH"; exit 1 ;;
esac

### 下载 Xray
if [ ! -x "$BIN" ]; then
  echo "[+] Downloading Xray core..."
  wget --no-check-certificate -O "$BASE/xray.tar.gz" \
    "https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-$XRAY_ARCH.tar.gz"
  tar -xzf "$BASE/xray.tar.gz" -C "$BASE"
  chmod +x "$BIN"
fi

### 配置文件
cat > "$CONF" <<EOF
{
  "inbounds": [
    {
      "listen": "0.0.0.0",
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
      "listen": "0.0.0.0",
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

### base64（BusyBox / OpenSSL 兜底）
b64() {
  if command -v base64 >/dev/null 2>&1; then
    base64 | tr -d '\n\r'
  else
    openssl base64 | tr -d '\n\r'
  fi
}

### 节点信息
VLESS_LINK="vless://$VLESS_UUID@$IP:$VLESS_PORT?type=ws&path=/#VLESS-WS"

VMESS_JSON=$(printf '{"v":"2","ps":"VMess-WS","add":"%s","port":"%s","id":"%s","aid":"0","net":"ws","type":"none","host":"","path":"/","tls":""}' \
"$IP" "$VMESS_PORT" "$VMESS_UUID")

VMESS_LINK="vmess://$(printf '%s' "$VMESS_JSON" | b64)"

cat > "$INFO" <<EOF
$VLESS_LINK
$VMESS_LINK
EOF

### ss 管理命令
cat > "$CTL" <<'EOF'
#!/bin/sh
BASE="$HOME/xray"
BIN="$BASE/xray"
CONF="$BASE/config.json"
PID="$BASE/xray.pid"
INFO="$BASE/nodes.txt"

case "$1" in
  start)
    nohup "$BIN" run -config "$CONF" >/dev/null 2>&1 &
    echo $! > "$PID"
    echo "Xray started"
    ;;
  stop)
    [ -f "$PID" ] && kill "$(cat "$PID")" 2>/dev/null && rm -f "$PID"
    echo "Xray stopped"
    ;;
  restart)
    $0 stop
    sleep 1
    $0 start
    ;;
  status)
    if [ -f "$PID" ] && kill -0 "$(cat "$PID")" 2>/dev/null; then
      echo "Xray running (PID $(cat "$PID"))"
    else
      echo "Xray stopped"
    fi
    ;;
  nodes)
    echo "====== 节点（批量复制）======"
    cat "$INFO"
    echo "============================"
    ;;
  uninstall)
    echo "Uninstalling Xray..."
    $0 stop
    rm -rf "$BASE"
    echo "Done. Xray fully removed."
    ;;
  *)
    echo "Usage: ss {start|stop|restart|status|nodes|uninstall}"
    ;;
esac
EOF

chmod +x "$CTL"

### 启动
"$CTL" start

### 输出节点
echo ""
echo "========= 节点（首次输出） ========="
cat "$INFO"
echo "==================================="
echo ""
echo "管理命令：ss start | stop | restart | status | nodes | uninstall"