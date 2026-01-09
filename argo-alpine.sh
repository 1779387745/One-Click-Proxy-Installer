#!/bin/sh
set -eu

# ==================================================
# 基本变量
# ==================================================
CLOUD_BIN="/usr/local/bin/cloudflared"
SELF_PATH="/usr/local/bin/argo-menu"
CRED_DIR="/root/.cloudflared"
CONFIG_FILE="$CRED_DIR/config.yml"
TOKEN_FILE="$CRED_DIR/token"
CRED_FILE="$CRED_DIR/credentials.json"
MAP_DB="$CRED_DIR/map.db"
NODE_FILE="$CRED_DIR/nodes.txt"
RC_FILE="/etc/init.d/cloudflared"

die(){ echo "✖ $*" >&2; exit 1; }
info(){ echo "→ $*"; }

# ==================================================
# 环境检查
# ==================================================
[ "$(id -u)" -eq 0 ] || die "必须 root 运行（Alpine + OpenRC）"
apk add --no-cache curl wget ca-certificates >/dev/null

# ==================================================
# 安装 argo 快捷命令
# ==================================================
install_shortcut() {
  if [ ! -f "$SELF_PATH" ]; then
    info "安装 argo 快捷命令"
    curl -fsSL https://raw.githubusercontent.com/shangguancaiyun/One-Click-Proxy-Installer/main/argo-alpine.sh \
      -o "$SELF_PATH"
    chmod +x "$SELF_PATH"
  fi
  ln -sf "$SELF_PATH" /usr/local/bin/argo
}
install_shortcut

# ==================================================
# 安装 cloudflared
# ==================================================
install_cloudflared() {
  command -v cloudflared >/dev/null && return
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64) FILE="cloudflared-linux-amd64" ;;
    aarch64) FILE="cloudflared-linux-arm64" ;;
    *) die "不支持的架构: $ARCH" ;;
  esac
  wget -O "$CLOUD_BIN" \
    "https://github.com/cloudflare/cloudflared/releases/latest/download/$FILE"
  chmod +x "$CLOUD_BIN"
}

# ==================================================
# 安装 / 重建 Tunnel
# ==================================================
install_tunnel() {
  install_cloudflared
  rm -rf "$CRED_DIR"
  mkdir -p "$CRED_DIR"
  chmod 700 "$CRED_DIR"
  : > "$MAP_DB"

  echo
  read -p "配置多少个域名: " NUM

  i=1
  while [ "$i" -le "$NUM" ]; do
    echo
    echo "=== 域名 $i ==="
    read -p "域名 (Public Hostname): " HOST
    read -p "本地端口 (默认443): " PORT
    PORT=${PORT:-443}

    echo "传输方式：1) WS  2) gRPC"
    read TYPE
    case "$TYPE" in
      1)
        STREAM="ws"
        read -p "WS 路径 (默认 /): " PATH
        PATH=${PATH:-/}
        ;;
      2)
        STREAM="grpc"
        read -p "gRPC ServiceName (默认 vmess-grpc): " PATH
        PATH=${PATH:-vmess-grpc}
        ;;
      *) die "无效选择" ;;
    esac

    echo "$HOST,$PORT,$PATH,$STREAM" >> "$MAP_DB"
    i=$((i+1))
  done

  echo
  echo "凭证方式：1) Token  2) credentials.json"
  read MODE

  if [ "$MODE" = "1" ]; then
    read -p "Tunnel Token: " TOKEN
    echo "$TOKEN" > "$TOKEN_FILE"
    EXEC_ARGS="tunnel run --token-file $TOKEN_FILE --config $CONFIG_FILE"
  else
    echo "粘贴 credentials.json（空行结束）："
    cat > "$CRED_FILE"
    EXEC_ARGS="tunnel run --credentials-file $CRED_FILE --config $CONFIG_FILE"
  fi

  {
    echo "ingress:"
    while IFS=',' read -r H P _ _; do
      echo "  - hostname: $H"
      echo "    service: http://127.0.0.1:$P"
    done < "$MAP_DB"
    echo "  - service: http_status:404"
  } > "$CONFIG_FILE"

  cat > "$RC_FILE" <<EOF
#!/sbin/openrc-run
description="Cloudflare Tunnel"
command="$CLOUD_BIN"
command_args="$EXEC_ARGS"
command_background=true
directory="$CRED_DIR"
pidfile="/run/cloudflared.pid"
EOF

  chmod +x "$RC_FILE"
  rc-update add cloudflared default
  rc-service cloudflared restart

  info "✅ Tunnel 已启动"
}

# ==================================================
# 生成节点
# ==================================================
gen_nodes() {
  [ -f "$MAP_DB" ] || die "未找到映射信息，请先安装 Tunnel"
  UUID=$(cat /proc/sys/kernel/random/uuid)
  : > "$NODE_FILE"

  while IFS=',' read -r HOST PORT PATH STREAM; do
    case "$STREAM" in
      ws)
        VMESS_JSON=$(printf '{"v":"2","ps":"%s-ws","add":"%s","port":"443","id":"%s","aid":"0","net":"ws","type":"none","host":"%s","path":"%s","tls":"tls"}' \
          "$HOST" "$HOST" "$UUID" "$HOST" "$PATH")
        echo "vmess://$(echo "$VMESS_JSON" | base64 -w0)" >> "$NODE_FILE"

        echo "vless://$UUID@$HOST:443?encryption=none&security=tls&type=ws&host=$HOST&path=$(echo "$PATH" | sed 's|/|%2F|g')#$HOST-ws" >> "$NODE_FILE"
        ;;
      grpc)
        echo "vless://$UUID@$HOST:443?encryption=none&security=tls&type=grpc&serviceName=$PATH#$HOST-grpc" >> "$NODE_FILE"
        ;;
    esac
  done < "$MAP_DB"

  info "✅ 节点已生成: $NODE_FILE"
}

# ==================================================
# 查看节点
# ==================================================
show_nodes() {
  [ -f "$NODE_FILE" ] || die "尚未生成节点"
  cat "$NODE_FILE"
}

# ==================================================
# 卸载
# ==================================================
uninstall_tunnel() {
  rc-service cloudflared stop 2>/dev/null || true
  rc-update del cloudflared default 2>/dev/null || true
  rm -f "$RC_FILE"
  rm -rf "$CRED_DIR"
  rm -f "$CLOUD_BIN"
  rm -f /usr/local/bin/argo
  rm -f "$SELF_PATH"
  info "✅ Cloudflare Tunnel 已卸载"
}

# ==================================================
# 菜单
# ==================================================
while true; do
  echo
  echo "===== Argo Tunnel (Alpine) ====="
  echo "1) 安装 / 重建 Tunnel"
  echo "2) 生成 WS / gRPC 节点"
  echo "3) 查看节点"
  echo "4) 卸载 Tunnel"
  echo "0) 退出"
  read -p "请选择: " CHOICE

  case "$CHOICE" in
    1) install_tunnel ;;
    2) gen_nodes ;;
    3) show_nodes ;;
    4) uninstall_tunnel ;;
    0) exit 0 ;;
    *) echo "无效选择" ;;
  esac
done