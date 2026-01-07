#!/bin/sh
# Alpine 2.0 Xray 管理脚本 (改进版)
# 兼容管道执行和交互菜单

BASE="$HOME/xray"
BIN="$BASE/xray"
CONF="$BASE/config.json"
PID="$BASE/xray.pid"
INFO="$BASE/nodes.txt"
WS_PATH="/ws/api/v1"
SS_CMD="$HOME/ss"

mkdir -p "$BASE"
touch "$INFO"

# 自动创建 ss 快捷命令
if [ ! -f "$SS_CMD" ]; then
  cp "$0" "$SS_CMD"
  chmod +x "$SS_CMD"
  SHELL_RC="$HOME/.bashrc"
  grep "alias ss=" "$SHELL_RC" >/dev/null 2>&1 || \
    echo "alias ss=\"$SS_CMD\"" >> "$SHELL_RC"
  echo "[+] 已生成 ss 快捷命令，请输入 'source ~/.bashrc' 生效"
fi

# 获取公网 IP
IP=$(wget -qO- https://api.ipify.org || echo "YOUR_IP")

# 下载 Xray
if [ ! -x "$BIN" ]; then
  echo "[+] 下载 Xray core..."
  wget -qO "$BASE/xray.zip" https://github.com/XTLS/Xray-core/releases/download/v25.12.8/Xray-linux-64.zip
  unzip -o "$BASE/xray.zip" -d "$BASE" >/dev/null 2>&1
  chmod +x "$BIN"
fi

# 初始化配置
if [ ! -f "$CONF" ]; then
  echo '{"inbounds":[],"outbounds":[{"protocol":"freedom"}]}' > "$CONF"
fi

uuid() { cat /proc/sys/kernel/random/uuid; }

# ---- Xray 控制 ----
start_xray() {
  if [ -f "$PID" ] && ps | grep "$(cat "$PID")" | grep -v grep >/dev/null 2>&1; then
    echo "Xray 已经运行"
  else
    "$BIN" run -config "$CONF" >/dev/null 2>&1 &
    echo $! > "$PID"
    echo "[+] Xray 已启动"
  fi
}

stop_xray() {
  [ -f "$PID" ] && kill "$(cat "$PID")" 2>/dev/null
  rm -f "$PID"
  echo "[+] Xray 已停止"
}

restart_xray() {
  stop_xray
  sleep 1
  start_xray
}

status_xray() {
  if [ -f "$PID" ] && ps | grep "$(cat "$PID")" | grep -v grep >/dev/null 2>&1; then
    echo "Xray 正在运行"
  else
    echo "Xray 未运行"
  fi
}

# ---- 节点管理 ----
view_nodes() {
  if [ -s "$INFO" ]; then
    echo "===== 节点 ====="
    cat "$INFO"
    echo "================"
  else
    echo "没有节点，请先生成节点"
  fi
}

generate_node() {
  VLESS_PORT=$(( ( $(date +%s) % 40000 ) + 10000 ))
  VMESS_PORT=$((VLESS_PORT + 1))
  VLESS_UUID=$(uuid)
  VMESS_UUID=$(uuid)

  TMP_CONF="$CONF.tmp"
  cat "$CONF" | \
  jq ".inbounds += [
    {\"port\": $VLESS_PORT,\"protocol\": \"vless\",\"settings\": {\"clients\": [{\"id\": \"$VLESS_UUID\"}],\"decryption\": \"none\"},\"streamSettings\": {\"network\": \"ws\",\"wsSettings\": {\"path\": \"$WS_PATH\"}}},
    {\"port\": $VMESS_PORT,\"protocol\": \"vmess\",\"settings\": {\"clients\": [{\"id\": \"$VMESS_UUID\",\"alterId\":0}]},\"streamSettings\": {\"network\": \"ws\",\"wsSettings\": {\"path\": \"$WS_PATH\"}}}
  ]" > "$TMP_CONF"
  mv "$TMP_CONF" "$CONF"

  VLESS_LINK="vless://$VLESS_UUID@$IP:$VLESS_PORT?type=ws&path=$WS_PATH#VLESS-WS"
  VMESS_JSON=$(printf '{"v":"2","ps":"VMess-WS","add":"%s","port":"%s","id":"%s","aid":"0","net":"ws","path":"%s","tls":""}' "$IP" "$VMESS_PORT" "$VMESS_UUID" "$WS_PATH")
  VMESS_LINK="vmess://$(echo "$VMESS_JSON" | base64 | tr -d '\n')"

  echo "$VLESS_LINK" >> "$INFO"
  echo "$VMESS_LINK" >> "$INFO"

  echo "[+] 新节点已生成:"
  echo "$VLESS_LINK"
  echo "$VMESS_LINK"

  restart_xray
}

delete_node() {
  [ ! -s "$INFO" ] && echo "没有节点可删除" && return
  echo "===== 当前节点 ====="
  nl "$INFO"
  echo "输入要删除的节点编号，用空格分隔:"
  read -r numbers </dev/tty

  TMP=$(mktemp)
  grep -v -E "^($(echo $numbers | sed 's/ /|/g')):" <(nl "$INFO") | sed 's/^[0-9]\+\t//' > "$TMP"
  mv "$TMP" "$INFO"
  restart_xray
  echo "[+] 选定节点已删除"
}

edit_node() {
  [ ! -s "$INFO" ] && echo "没有节点可修改" && return
  echo "===== 当前节点 ====="
  nl "$INFO"
  echo "输入要修改的节点编号:"
  read -r num </dev/tty
  LINE=$(sed -n "${num}p" "$INFO")
  [ -z "$LINE" ] && echo "无效编号" && return

  echo "当前节点: $LINE"
  echo "输入新端口(回车保持不变):"; read -r NEW_PORT </dev/tty
  echo "输入新 WebSocket 路径(回车保持不变):"; read -r NEW_PATH </dev/tty
  [ -z "$NEW_PATH" ] && NEW_PATH="$WS_PATH"

  TMP=$(mktemp)
  sed "${num}s|.*|$LINE|" "$INFO" > "$TMP"
  mv "$TMP" "$INFO"
  echo "[+] 节点信息已修改"
  restart_xray
}

uninstall_xray() {
  stop_xray
  rm -rf "$BASE"
  [ -f "$SS_CMD" ] && rm -f "$SS_CMD"
  echo "[+] Xray 已卸载"
}

# ---- 菜单 ----
menu() {
  while true; do
    echo "==== Xray 管理菜单 ===="
    echo "1) 启动 Xray"
    echo "2) 停止 Xray"
    echo "3) 重启 Xray"
    echo "4) 查看状态"
    echo "5) 查看节点"
    echo "6) 生成新节点"
    echo "7) 删除节点"
    echo "8) 修改节点"
    echo "9) 卸载 Xray"
    echo "0) 退出"
    echo "======================="
    printf "请选择操作: "
    read -r choice </dev/tty
    case "$choice" in
      1) start_xray ;;
      2) stop_xray ;;
      3) restart_xray ;;
      4) status_xray ;;
      5) view_nodes ;;
      6) generate_node ;;
      7) delete_node ;;
      8) edit_node ;;
      9) uninstall_xray ;;
      0) exit 0 ;;
      *) echo "无效选项" ;;
    esac
    echo ""
  done
}

# ---- 命令行参数模式 ----
if [ $# -gt 0 ]; then
  case "$1" in
    start) start_xray ;;
    stop) stop_xray ;;
    restart) restart_xray ;;
    status) status_xray ;;
    nodes) view_nodes ;;
    new) generate_node ;;
    delete) delete_node ;;
    edit) edit_node ;;
    uninstall) uninstall_xray ;;
    *) echo "用法: $0 {start|stop|restart|status|nodes|new|delete|edit|uninstall}" ;;
  esac
  exit 0
fi

# 自动启动一次 Xray 并进入菜单（仅手动执行才会进菜单）
if [ -t 0 ]; then
  start_xray
  menu
fi