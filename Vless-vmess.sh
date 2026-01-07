#!/bin/sh
# Alpine 2.0 Xray VMess/VLESS 管理脚本
# 支持管道执行 & 直接下载执行，菜单 + 节点管理 + 自动创建 ss 快捷命令 + 节点修改功能

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
  if ! grep -q "alias ss=" "$SHELL_RC"; then
    echo "alias ss=\"$SS_CMD\"" >> "$SHELL_RC"
    echo "[+] 已将 ss 别名写入 $SHELL_RC，输入 'source ~/.bashrc' 生效"
  fi
fi

IP=$(wget -qO- https://api.ipify.org || echo "YOUR_IP")

# 下载 Xray
if [ ! -x "$BIN" ]; then
  wget -O "$BASE/xray.zip" \
    https://github.com/XTLS/Xray-core/releases/download/v25.12.8/Xray-linux-64.zip
  unzip -o "$BASE/xray.zip" -d "$BASE"
  chmod +x "$BIN"
fi

# 初始化配置
if [ ! -f "$CONF" ]; then
  cat > "$CONF" <<EOF
{
  "inbounds": [],
  "outbounds": [{"protocol":"freedom"}]
}
EOF
fi

uuid() { cat /proc/sys/kernel/random/uuid; }

start_xray() { [ -f "$PID" ] && ps | grep "$(cat "$PID")" | grep -v grep >/dev/null && echo "Xray 已经运行" || (nohup "$BIN" run -config "$CONF" >/dev/null 2>&1 & echo $! > "$PID" && echo "[+] Xray 已启动"); }
stop_xray() { [ -f "$PID" ] && kill "$(cat "$PID")" 2>/dev/null && rm -f "$PID"; echo "[+] Xray 已停止"; }
restart_xray() { stop_xray; sleep 1; start_xray; }
status_xray() { [ -f "$PID" ] && ps | grep "$(cat "$PID")" | grep -v grep >/dev/null && echo "Xray 正在运行" || echo "Xray 未运行"; }

view_nodes() { [ -s "$INFO" ] && (echo "===== 节点 ====="; cat "$INFO"; echo "================") || echo "没有节点，请先生成节点"; }

generate_node() {
  VLESS_PORT=$(( ( $(date +%s) % 40000 ) + 10000 ))
  VMESS_PORT=$((VLESS_PORT + 1))
  VLESS_UUID=$(uuid)
  VMESS_UUID=$(uuid)
  TMP=$(mktemp)
  jq ".inbounds += [
    {\"port\": $VLESS_PORT,\"protocol\": \"vless\",\"settings\": {\"clients\": [{\"id\": \"$VLESS_UUID\"}],\"decryption\": \"none\"},\"streamSettings\": {\"network\": \"ws\",\"wsSettings\": {\"path\": \"$WS_PATH\"}}},
    {\"port\": $VMESS_PORT,\"protocol\": \"vmess\",\"settings\": {\"clients\": [{\"id\": \"$VMESS_UUID\",\"alterId\":0}]},\"streamSettings\": {\"network\": \"ws\",\"wsSettings\": {\"path\": \"$WS_PATH\"}}}
  ]" "$CONF" > "$TMP" && mv "$TMP" "$CONF"
  VLESS_LINK="vless://$VLESS_UUID@$IP:$VLESS_PORT?type=ws&path=$WS_PATH#VLESS-WS"
  VMESS_JSON=$(printf '{"v":"2","ps":"VMess-WS","add":"%s","port":"%s","id":"%s","aid":"0","net":"ws","path":"%s","tls":""}' "$IP" "$VMESS_PORT" "$VMESS_UUID" "$WS_PATH")
  VMESS_LINK="vmess://$(echo "$VMESS_JSON" | base64 | tr -d '\n')"
  echo "$VLESS_LINK" >> "$INFO"
  echo "$VMESS_LINK" >> "$INFO"
  echo "[+] 新节点已生成:"; echo "$VLESS_LINK"; echo "$VMESS_LINK"
  restart_xray
}

delete_node() {
  [ ! -s "$INFO" ] && echo "没有节点可删除" && return
  echo "===== 当前节点 ====="; nl "$INFO"; echo "输入要删除的节点编号，用空格分隔:"; read -r numbers </dev/tty
  TMP=$(mktemp)
  grep -v -E "^($(echo $numbers | sed 's/ /|/g')):" <(nl "$INFO") | sed 's/^[0-9]\+\t//' > "$TMP"
  mv "$TMP" "$INFO"
  TMP_CONF=$(mktemp); jq '.inbounds=[]' "$CONF" > "$TMP_CONF"; mv "$TMP_CONF" "$CONF"
  while read -r line; do
    if echo "$line" | grep -q "^vless://"; then
      UUID=$(echo "$line" | cut -d: -f3 | cut -d@ -f1)
      PORT=$(echo "$line" | cut -d@ -f2 | cut -d? -f1)
      TMP_CONF=$(mktemp)
      jq ".inbounds += [{\"port\": $PORT,\"protocol\": \"vless\",\"settings\": {\"clients\":[{\"id\":\"$UUID\"}],\"decryption\":\"none\"},\"streamSettings\": {\"network\":\"ws\",\"wsSettings\":{\"path\":\"$WS_PATH\"}}}]" "$CONF" > "$TMP_CONF" && mv "$TMP_CONF" "$CONF"
    else
      JSON=$(echo "$line" | base64 -d)
      PORT=$(echo "$JSON" | jq -r .port)
      UUID=$(echo "$JSON" | jq -r .id)
      TMP_CONF=$(mktemp)
      jq ".inbounds += [{\"port\": $PORT,\"protocol\": \"vmess\",\"settings\": {\"clients\":[{\"id\":\"$UUID\",\"alterId\":0}]},\"streamSettings\": {\"network\":\"ws\",\"wsSettings\":{\"path\":\"$WS_PATH\"}}}]" "$CONF" > "$TMP_CONF" && mv "$TMP_CONF" "$CONF"
    fi
  done < "$INFO"
  restart_xray; echo "[+] 选定节点已删除"
}

edit_node() {
  [ ! -s "$INFO" ] && echo "没有节点可修改" && return
  echo "===== 当前节点 ====="; nl "$INFO"; echo "输入要修改的节点编号:"; read -r num </dev/tty
  LINE=$(sed -n "${num}p" "$INFO")
  [ -z "$LINE" ] && echo "无效编号" && return
  echo "当前节点: $LINE"
  echo "输入新端口(回车保持不变):"; read -r NEW_PORT </dev/tty
  echo "输入新 WebSocket 路径(回车保持不变):"; read -r NEW_PATH </dev/tty
  [ -z "$NEW_PATH" ] && NEW_PATH="$WS_PATH"
  if echo "$LINE" | grep -q "^vless://"; then
    UUID=$(echo "$LINE" | cut -d: -f3 | cut -d@ -f1)
    PORT=$(echo "$LINE" | cut -d@ -f2 | cut -d? -f1)
    TMP=$(mktemp)
    sed "${num}s|.*|vless://$UUID@$([ -n "$NEW_PORT" ] && echo "$NEW_PORT" || echo $PORT)?type=ws&path=$NEW_PATH#VLESS-WS|" "$INFO" > "$TMP"
    mv "$TMP" "$INFO"
  else
    JSON=$(echo "$LINE" | base64 -d)
    PORT=$(echo "$JSON" | jq -r .port)
    UUID=$(echo "$JSON" | jq -r .id)
    TMP_JSON=$(jq --arg port "${NEW_PORT:-$PORT}" --arg path "$NEW_PATH" '.port=$port | .path=$path' <<<"$JSON")
    TMP=$(mktemp)
    echo "vmess://$(echo $TMP_JSON | base64 | tr -d '\n')" | sed "${num}s|.*|&|" > "$TMP"
    mv "$TMP" "$INFO"
  fi
  echo "[+] 节点信息已修改"
  restart_xray
}

uninstall_xray() { stop_xray; rm -rf "$BASE"; [ -f "$SS_CMD" ] && rm -f "$SS_CMD"; echo "[+] Xray 已卸载"; }

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

# 命令行参数模式
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

# 自动启动一次 Xray 并进入菜单
start_xray
menu