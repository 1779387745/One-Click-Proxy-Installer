#!/bin/sh
# Alpine 2.0 compatible Xray installer + ss manager
# VMess + VLESS | WS | No TLS | No apk | No bash

set -e

BASE="$HOME/xray"
BIN="$BASE/xray"
CONF="$BASE/config.json"
PID="$BASE/xray.pid"
INFO="$BASE/nodes.txt"
CTL="$BASE/ss"

mkdir -p "$BASE"

### 端口（保证不冲突）
BASE_PORT=$(( ( $(date +%s) % 40000 ) + 10000 ))
VLESS_PORT=$BASE_PORT
VMESS_PORT=$((BASE_PORT + 1))

### UUID
uuid() {
  cat /proc/sys/kernel/random/uuid
}

VLESS_UUID=$(uuid)
VMESS_UUID=$(uuid)

### IP
IP=$(wget -qO- https://api.ipify.org || echo "YOUR_IP")

### 下载 Xray
if [ ! -x "$BIN" ]; then
  echo "[+] Downloading Xray core..."
  wget -O "$BASE/xray.tar.gz" \
    https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.tar.gz
  tar -xzf "$BASE/xray.tar.gz" -C "$BASE"
  chmod +x "$BIN"
fi

### 配置文件
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

### 节点信息（保存，供 ss nodes 使用）
VLESS_LINK="vless://$VLESS_UUID@$IP:$VLESS_PORT?type=ws&path=/#VLESS-WS"
VMESS_JSON=$(printf '{"v":"2","ps":"VMess-WS","add":"%s","port":"%s","id":"%s","aid":"0","net":"ws","type":"none","host":"","path":"/","tls":""}' \
"$IP" "$VMESS_PORT" "$VMESS_UUID")
VMESS_LINK="vmess://$(echo "$VMESS_JSON" | base64 | tr -d '\n')"

cat > "$INFO" <<EOF
$VLESS_LINK
$VMESS_LINK
EOF

### ss 管理脚本
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
    if [ -f "$PID" ] && ps | grep "$(cat "$PID")" | grep -v grep >/dev/null; then
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

### 首次输出节点
echo ""
echo "========= 节点（首次输出） ========="
cat "$INFO"
echo "==================================="
echo ""
echo "管理命令：ss start | stop | restart | status | nodes | uninstall"