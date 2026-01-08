#!/bin/sh
# =========================================================
# Xray Alpine / 非 root 终极稳定版管理脚本
# VMess + VLESS (WS)
# =========================================================

set -e

# ---------- 基础路径 ----------
BASE="$HOME/xray"
BIN="$BASE/xray"
CONF="$BASE/config.json"
PID="$BASE/xray.pid"
INFO="$BASE/nodes.txt"
WS_PATH="/ws/api/v1"

mkdir -p "$BASE"
touch "$INFO"

# ---------- 依赖检测 ----------
for cmd in jq wget unzip ss; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "[-] 缺少依赖: $cmd"
    echo "    Alpine 请执行: apk add jq wget unzip iproute2"
    exit 1
  }
done

# ---------- 获取 IP ----------
IP=$(wget -qO- https://api.ipify.org || echo "YOUR_IP")

# ---------- 下载 Xray ----------
if [ ! -x "$BIN" ]; then
  echo "[+] 下载 Xray core..."
  wget -qO "$BASE/xray.zip" \
    https://github.com/XTLS/Xray-core/releases/download/v25.12.8/Xray-linux-64.zip
  unzip -qo "$BASE/xray.zip" -d "$BASE"
  chmod +x "$BIN"
fi

# ---------- 初始化配置 ----------
if [ ! -f "$CONF" ]; then
  cat >"$CONF" <<EOF
{
  "inbounds": [],
  "outbounds": [
    { "protocol": "freedom" }
  ]
}
EOF
fi

uuid() { cat /proc/sys/kernel/random/uuid; }

# ---------- 安全端口生成 ----------
gen_port() {
  while :; do
    PORT=$((RANDOM % 40000 + 10000))
    ! ss -lnt | grep -q ":$PORT " && {
      echo "$PORT"
      return
    }
  done
}

# ---------- Xray 控制 ----------
start_xray() {
  if [ -f "$PID" ] && kill -0 "$(cat "$PID")" 2>/dev/null; then
    echo "[=] Xray 已运行"
  else
    "$BIN" run -config "$CONF" >/dev/null 2>&1 &
    echo $! > "$PID"
    echo "[+] Xray 已启动"
  fi
}

stop_xray() {
  [ -f "$PID" ] && kill "$(cat "$PID")" 2>/dev/null || true
  rm -f "$PID"
  echo "[+] Xray 已停止"
}

restart_xray() { stop_xray; sleep 1; start_xray; }

status_xray() {
  [ -f "$PID" ] && kill -0 "$(cat "$PID")" 2>/dev/null \
    && echo "[+] Xray 正在运行" || echo "[-] Xray 未运行"
}

# ---------- 查看节点 ----------
view_nodes() {
  [ -s "$INFO" ] || { echo "暂无节点"; return; }
  nl -w2 -s'. ' "$INFO"
}

# ---------- 生成节点 ----------
generate_node() {
  VLESS_PORT=$(gen_port)
  VMESS_PORT=$(gen_port)
  VLESS_UUID=$(uuid)
  VMESS_UUID=$(uuid)

  jq ".inbounds += [
    {
      \"port\": $VLESS_PORT,
      \"protocol\": \"vless\",
      \"settings\": {
        \"clients\": [{\"id\": \"$VLESS_UUID\"}],
        \"decryption\": \"none\"
      },
      \"streamSettings\": {
        \"network\": \"ws\",
        \"wsSettings\": {\"path\": \"$WS_PATH\"}
      }
    },
    {
      \"port\": $VMESS_PORT,
      \"protocol\": \"vmess\",
      \"settings\": {
        \"clients\": [{\"id\": \"$VMESS_UUID\",\"alterId\":0}]
      },
      \"streamSettings\": {
        \"network\": \"ws\",
        \"wsSettings\": {\"path\": \"$WS_PATH\"}
      }
    }
  ]" "$CONF" >"$CONF.tmp" && mv "$CONF.tmp" "$CONF"

  VLESS="vless://$VLESS_UUID@$IP:$VLESS_PORT?type=ws&path=$WS_PATH#VLESS-WS"
  VMESS_JSON=$(printf '{"v":"2","ps":"VMess-WS","add":"%s","port":"%s","id":"%s","aid":"0","net":"ws","path":"%s"}' \
    "$IP" "$VMESS_PORT" "$VMESS_UUID" "$WS_PATH")
  VMESS="vmess://$(echo "$VMESS_JSON" | base64 | tr -d '\n')"

  echo "$VLESS" >>"$INFO"
  echo "$VMESS" >>"$INFO"

  echo "[+] 节点已生成"
  echo "$VLESS"
  echo "$VMESS"

  restart_xray
}

# ---------- 删除节点 ----------
delete_node() {
  view_nodes
  echo "输入要删除的编号（空格分隔）:"
  read nums </dev/tty

  for n in $nums; do
    LINE=$(sed -n "${n}p" "$INFO")
    UUID=$(echo "$LINE" | sed -nE 's/.*\/\/([0-9a-f\-]+)@.*/\1/p')
    jq "del(.inbounds[] | select(.settings.clients[].id==\"$UUID\"))" \
      "$CONF" >"$CONF.tmp" && mv "$CONF.tmp" "$CONF"
  done

  TMP=$(mktemp)
  nl "$INFO" | awk '{print $1}' | grep -vwE "$(echo "$nums" | tr ' ' '|')" |
  while read i; do sed -n "${i}p" "$INFO"; done >"$TMP"
  mv "$TMP" "$INFO"

  restart_xray
  echo "[+] 节点已删除"
}

# ---------- 修改节点 ----------
edit_node() {
  view_nodes
  echo "选择编号:"
  read n </dev/tty
  LINE=$(sed -n "${n}p" "$INFO") || return
  UUID=$(echo "$LINE" | sed -nE 's/.*\/\/([0-9a-f\-]+)@.*/\1/p')

  echo "新端口(回车跳过):"
  read NEW_PORT </dev/tty
  echo "新 WS 路径(回车跳过):"
  read NEW_PATH </dev/tty

  jq '
    (.inbounds[] | select(.settings.clients[].id=="'"$UUID"'") | .port) |= '"${NEW_PORT:-.}"' |
    (.inbounds[] | select(.settings.clients[].id=="'"$UUID"'") | .streamSettings.wsSettings.path) |= "'"${NEW_PATH:-$WS_PATH}"'"
  ' "$CONF" >"$CONF.tmp" && mv "$CONF.tmp" "$CONF"

  restart_xray
  echo "[+] 节点已修改"
}

# ---------- 卸载 ----------
uninstall_xray() {
  stop_xray
  rm -rf "$BASE"
  echo "[+] 已卸载 Xray"
}

# ---------- 菜单 ----------
menu() {
  while :; do
    echo "====== Xray 管理 ======"
    echo "1) 启动"
    echo "2) 停止"
    echo "3) 重启"
    echo "4) 状态"
    echo "5) 查看节点"
    echo "6) 生成节点"
    echo "7) 删除节点"
    echo "8) 修改节点"
    echo "9) 卸载"
    echo "0) 退出"
    read c </dev/tty
    case $c in
      1) start_xray ;;
      2) stop_xray ;;
      3) restart_xray ;;
      4) status_xray ;;
      5) view_nodes ;;
      6) generate_node ;;
      7) delete_node ;;
      8) edit_node ;;
      9) uninstall_xray ;;
      0) exit ;;
    esac
    echo
  done
}

[ $# -gt 0 ] && "$1" || menu