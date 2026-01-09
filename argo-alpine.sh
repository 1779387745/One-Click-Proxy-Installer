#!/bin/sh
set -eu

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

[ "$(id -u)" -eq 0 ] || die "必须 root 运行（Alpine + OpenRC）"
apk add --no-cache curl wget ca-certificates >/dev/null

# =========================
# 安装 argo 快捷方式
# =========================
install_shortcut() {
  if [ ! -f "$SELF_PATH" ]; then
    curl -fsSL https://raw.githubusercontent.com/shangguancaiyun/One-Click-Proxy-Installer/main/argo-alpine.sh \
      -o "$SELF_PATH"
    chmod +x "$SELF_PATH"
  fi
  ln -sf "$SELF_PATH" /usr/local/bin/argo
}
install_shortcut

# =========================
# 安装 cloudflared
# =========================
install_cloudflared() {
  command -v cloudflared >/dev/null && return
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64) FILE="cloudflared-linux-amd64" ;;
    aarch64) FILE="cloudflared-linux-arm64" ;;
    *) die "不支持架构" ;;
  esac
  wget -O "$CLOUD_BIN" \
    "https://github.com/cloudflare/cloudflared/releases/latest/download/$FILE"
  chmod +x "$CLOUD_BIN"
}

# =========================
# 安装 Tunnel
# =========================
install_tunnel() {
  install_cloudflared
  rm -rf "$CRED_DIR"
  mkdir -p "$CRED_DIR"
  chmod 700 "$CRED_DIR"
  : > "$MAP_DB"

  read -p "配置多少个域名: " NUM

  i=1
  while [ "$i" -le "$NUM" ]; do
    read -p "域名: " HOST
    read -p "本地端口(默认443): " PORT
    PORT=${PORT:-443}

    echo "1) WS  2) gRPC"
    read TYPE
    if [ "$TYPE" = "1" ]; then
      STREAM="ws"
      read -p "WS 路径(/): " PATH
      PATH=${PATH:-/}
    else
      STREAM="grpc"
      read -p "gRPC ServiceName: " PATH
    fi

    printf "%s,%s,%s,%s\n" "$HOST" "$PORT" "$PATH" "$STREAM" >> "$MAP_DB"
    i=$((i+1))
  done

  echo "凭证方式：1) Token  2) credentials.json"
  read MODE

  if [ "$MODE" = "1" ]; then
    read -p "Tunnel Token: " TOKEN
    printf "%s" "$TOKEN" > "$TOKEN_FILE"
    EXEC_ARGS="tunnel run --token-file $TOKEN_FILE --config $CONFIG_FILE"
  else
    : > "$CRED_FILE"
    while IFS= read -r line; do
      [ -z "$line" ] && break
      printf "%s\n" "$line" >> "$CRED_FILE"
    done
    EXEC_ARGS="tunnel run --credentials-file $CRED_FILE --config $CONFIG_FILE"
  fi

  {
    printf "ingress:\n"
    while IFS=',' read -r H P _ _; do
      printf "  - hostname: %s\n    service: http://127.0.0.1:%s\n" "$H" "$P"
    done < "$MAP_DB"
    printf "  - service: http_status:404\n"
  } > "$CONFIG_FILE"

  printf '%s\n' \
"#!/sbin/openrc-run
command=\"$CLOUD_BIN\"
command_args=\"$EXEC_ARGS\"
command_background=true
directory=\"$CRED_DIR\"
pidfile=\"/run/cloudflared.pid\"" > "$RC_FILE"

  chmod +x "$RC_FILE"
  rc-update add cloudflared default
  rc-service cloudflared restart
}

# =========================
# 生成节点
# =========================
gen_nodes() {
  UUID=$(uuidgen 2>/dev/null || date +%s)
  : > "$NODE_FILE"

  while IFS=',' read -r HOST _ PATH STREAM; do
    if [ "$STREAM" = "ws" ]; then
      printf "vless://%s@%s:443?security=tls&type=ws&path=%s#%s-ws\n" \
        "$UUID" "$HOST" "$PATH" "$HOST" >> "$NODE_FILE"
    else
      printf "vless://%s@%s:443?security=tls&type=grpc&serviceName=%s#%s-grpc\n" \
        "$UUID" "$HOST" "$PATH" "$HOST" >> "$NODE_FILE"
    fi
  done < "$MAP_DB"
}

show_nodes() {
  sed -n '1,$p' "$NODE_FILE"
}

uninstall_tunnel() {
  rc-service cloudflared stop 2>/dev/null || true
  rc-update del cloudflared default 2>/dev/null || true
  rm -rf "$CRED_DIR" "$RC_FILE" "$CLOUD_BIN" /usr/local/bin/argo "$SELF_PATH"
}

while true; do
  echo "1) 安装 Tunnel"
  echo "2) 生成节点"
  echo "3) 查看节点"
  echo "4) 卸载"
  echo "0) 退出"
  read CH
  case "$CH" in
    1) install_tunnel ;;
    2) gen_nodes ;;
    3) show_nodes ;;
    4) uninstall_tunnel ;;
    0) exit 0 ;;
  esac
done