#!/bin/sh
# Alpine 2.0 compatible Xray installer + ss manager
# VMess + VLESS | WS/伪装路径 | No TLS | No root

set -e

BASE="$HOME/xray"
BIN="$BASE/xray"
CONF="$BASE/config.json"
PID="$BASE/xray.pid"
INFO="$BASE/nodes.txt"
CTL="$BASE/ss"

# WebSocket 伪装路径
WS_PATH="/ws/api/v1"

mkdir -p "$BASE"

# 随机端口（避免冲突）
BASE_PORT=$(( ( $(date +%s) % 40000 ) + 10000 ))
VLESS_PORT=$BASE_PORT
VMESS_PORT=$((BASE_PORT + 1))

# 生成 UUID
uuid() { cat /proc/sys/kernel/random/uuid; }
VLESS_UUID=$(uuid)
VMESS_UUID=$(uuid)

# 获取外网 IP
IP=$(wget -qO- https://api.ipify.org || echo "YOUR_IP")

# 下载 Xray（官方 ZIP，修正了下载链接）
if [ ! -x "$BIN" ]; then
  echo "[+] Downloading Xray core..."
  wget -O "$BASE/xray.zip" \
    https://github.com/XTLS/Xray-core/releases/download/v25.12.8/Xray-linux-64.zip
  unzip -o "$BASE/xray.zip" -d "$BASE"
  chmod +x "$BIN"
fi

# 生成配置文件
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
        "wsSettings": { "path": "$WS_PATH" }
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
        "wsSettings": { "path": "$WS_PATH" }
      }
    }
  ],
  "outbounds": [{ "protocol": "freedom" }]
}
EOF

# 生成节点链接
VLESS_LINK="vless://$VLESS_UUID@$IP:$VLESS_PORT?type=ws&path=$WS_PATH#VLESS-WS"
VMESS_JSON=$(printf '{"v":"2","ps":"VMess-WS","add":"%s","port":"%s","id":"%s","aid":"0","net":"ws","path":"%s","tls":""}' \
"$IP" "$VMESS_PORT" "$VMESS_UUID" "$WS_PATH")
VMESS_LINK="vmess://$(echo "$VMESS_JSON" | base64 | tr -d '\n')"

echo "$VLESS_LINK" > "$INFO"
echo "$VMESS_LINK" >> "$INFO"

# 管理脚本 ss
cat > "$CTL" << 'EOF'
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
    ;;
  stop)
    [ -f "$PID" ] && kill "$(cat "$PID")" 2>/dev/null && rm -f "$PID"
    ;;
  restart)
    $0 stop
    sleep 1
    $0 start
    ;;
  status)
    [ -f "$PID" ] && ps | grep "$(cat "$PID")" | grep -v grep && echo "running" || echo "stopped"
    ;;
  nodes)
    echo "====== 节点信息 ======"
    cat "$INFO"
    echo "====================="
    ;;
  uninstall)
    $0 stop
    rm -rf "$BASE"
    echo "Xray 已完全卸载"
    ;;
  *)
    echo "Usage: ss {start|stop|restart|status|nodes|uninstall}"
    ;;
esac
EOF

chmod +x "$CTL"

# 启动 Xray
"$CTL" start

# 输出节点
echo ""
echo "===== 节点（复制这两行） ====="
cat "$INFO"
echo "=============================="
echo ""
echo "管理命令：ss start | stop | restart | status | nodes | uninstall"