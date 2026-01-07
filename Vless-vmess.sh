#!/bin/sh
# Alpine 2.0 Xray VMess/VLESS 管理脚本（无 TLS, WS, 随机端口）
# 一键操作：启动/停止/重启/查看节点/卸载

set -e

BASE="$HOME/xray"
BIN="$BASE/xray"
CONF="$BASE/config.json"
PID="$BASE/xray.pid"
INFO="$BASE/nodes.txt"

WS_PATH="/ws/api/v1"

mkdir -p "$BASE"

# 随机端口
BASE_PORT=$(( ( $(date +%s) % 40000 ) + 10000 ))
VLESS_PORT=$BASE_PORT
VMESS_PORT=$((BASE_PORT + 1))

# 生成 UUID
uuid() { cat /proc/sys/kernel/random/uuid; }
VLESS_UUID=$(uuid)
VMESS_UUID=$(uuid)

# 获取外网 IP
IP=$(wget -qO- https://api.ipify.org || echo "YOUR_IP")

# 下载 Xray 最新 ZIP
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

# 生成节点
VLESS_LINK="vless://$VLESS_UUID@$IP:$VLESS_PORT?type=ws&path=$WS_PATH#VLESS-WS"
VMESS_JSON=$(printf '{"v":"2","ps":"VMess-WS","add":"%s","port":"%s","id":"%s","aid":"0","net":"ws","path":"%s","tls":""}' \
"$IP" "$VMESS_PORT" "$VMESS_UUID" "$WS_PATH")
VMESS_LINK="vmess://$(echo "$VMESS_JSON" | base64 | tr -d '\n')"

echo "$VLESS_LINK" > "$INFO"
echo "$VMESS_LINK" >> "$INFO"

# 一键管理脚本
manage() {
  echo "==== Xray 管理器 ===="
  echo "1) 启动 Xray"
  echo "2) 停止 Xray"
  echo "3) 重启 Xray"
  echo "4) 查看状态"
  echo "5) 查看节点"
  echo "6) 卸载 Xray"
  echo "0) 退出"
  echo "====================="
  printf "请选择操作: "
  read -r choice

  case "$choice" in
    1)
      nohup "$BIN" run -config "$CONF" >/dev/null 2>&1 &
      echo $! > "$PID"
      echo "[+] Xray 已启动"
      ;;
    2)
      [ -f "$PID" ] && kill "$(cat "$PID")" 2>/dev/null && rm -f "$PID"
      echo "[+] Xray 已停止"
      ;;
    3)
      [ -f "$PID" ] && kill "$(cat "$PID")" 2>/dev/null && rm -f "$PID"
      sleep 1
      nohup "$BIN" run -config "$CONF" >/dev/null 2>&1 &
      echo $! > "$PID"
      echo "[+] Xray 已重启"
      ;;
    4)
      if [ -f "$PID" ] && ps | grep "$(cat "$PID")" | grep -v grep >/dev/null; then
        echo "Xray 正在运行"
      else
        echo "Xray 未运行"
      fi
      ;;
    5)
      echo "===== 节点 ====="
      cat "$INFO"
      echo "================"
      ;;
    6)
      [ -f "$PID" ] && kill "$(cat "$PID")" 2>/dev/null && rm -f "$PID"
      rm -rf "$BASE"
      echo "[+] Xray 已完全卸载"
      ;;
    0)
      echo "退出"
      exit 0
      ;;
    *)
      echo "无效选项"
      ;;
  esac
  echo ""
  manage
}

# 自动启动 Xray 并进入管理菜单
nohup "$BIN" run -config "$CONF" >/dev/null 2>&1 &
echo $! > "$PID"
echo "[+] Xray 已启动，节点已生成"

manage