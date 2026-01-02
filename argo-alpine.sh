#!/bin/sh
set -eu

die(){ echo "✖ $*" >&2; exit 1; }
info(){ echo "→ $*"; }

IS_ROOT=false
[ "$(id -u)" -eq 0 ] && IS_ROOT=true

[ "$IS_ROOT" = true ] || die "Alpine 版必须 root 运行（OpenRC 需要）"

# =========================
# 依赖
# =========================
apk add --no-cache curl wget ca-certificates

# =========================
# 安装 cloudflared
# =========================
if ! command -v cloudflared >/dev/null 2>&1; then
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64) FILE="cloudflared-linux-amd64" ;;
    aarch64) FILE="cloudflared-linux-arm64" ;;
    *) die "不支持架构: $ARCH" ;;
  esac

  wget -O /usr/local/bin/cloudflared \
    "https://github.com/cloudflare/cloudflared/releases/latest/download/$FILE"
  chmod +x /usr/local/bin/cloudflared
fi

CLOUD_BIN="/usr/local/bin/cloudflared"

# =========================
# 目录
# =========================
CRED_DIR="/root/.cloudflared"
CONFIG_FILE="$CRED_DIR/config.yml"
TOKEN_FILE="$CRED_DIR/token"

mkdir -p "$CRED_DIR"
chmod 700 "$CRED_DIR"

# =========================
# 域名映射
# =========================
while true; do
  printf "需要配置多少个域名->端口？: "
  read NUM
  case "$NUM" in
    ''|*[!0-9]*) ;;
    *) [ "$NUM" -gt 0 ] && break ;;
  esac
done

MAPPINGS=""

i=1
while [ "$i" -le "$NUM" ]; do
  echo
  echo "=== 域名 $i ==="

  read -r -p "域名 (Public Hostname): " DOMAIN
  [ -n "$DOMAIN" ] || die "域名不能为空"

  read -r -p "本地端口 (默认443): " PORT
  PORT=${PORT:-443}

  echo "传输方式：1) WS  2) gRPC  3) TCP"
  read -r TYPE
  TYPE=${TYPE:-1}

  STREAM_TYPE=""
  WS_PATH="-"

  case "$TYPE" in
    1)
      STREAM_TYPE="ws"
      read -r -p "WebSocket 路径 (默认 /): " WS_PATH
      WS_PATH=${WS_PATH:-/}
      ;;
    2)
      STREAM_TYPE="grpc"
      read -r -p "gRPC ServiceName (默认 vmess-grpc): " WS_PATH
      WS_PATH=${WS_PATH:-vmess-grpc}
      ;;
    3)
      STREAM_TYPE="tcp"
      WS_PATH="-"
      ;;
    *)
      die "无效选择"
      ;;
  esac

  read -r -p "协议 (http/https/tcp，默认 http): " PROTO
  PROTO=${PROTO:-http}
  case "$PROTO" in http|https|tcp) ;; *) PROTO="http" ;; esac

  MAPPINGS="${MAPPINGS}${DOMAIN},${PORT},${WS_PATH},${PROTO},${STREAM_TYPE}\n"
  i=$((i+1))
done

# =========================
# 凭证
# =========================
echo
echo "凭证方式：1) Token  2) credentials JSON"
read -r MODE
MODE=${MODE:-1}

CREDENTIAL_FILE=""

if [ "$MODE" = "1" ]; then
  read -r -p "Tunnel Token: " TOKEN
  printf "%s" "$TOKEN" > "$TOKEN_FILE"
  chmod 600 "$TOKEN_FILE"
else
  echo "粘贴 credentials JSON（空行结束）："
  JSON=""
  while IFS= read -r line; do
    [ -z "$line" ] && break
    JSON="${JSON}${line}\n"
  done
  CREDENTIAL_FILE="$CRED_DIR/credentials.json"
  printf "%b" "$JSON" > "$CREDENTIAL_FILE"
  chmod 600 "$CREDENTIAL_FILE"
fi

# =========================
# 生成 config.yml
# =========================
info "生成 $CONFIG_FILE"

{
  echo "ingress:"
  echo -e "$MAPPINGS" | while IFS=',' read -r HOST PORT PATH PROTO STREAM; do
    [ -z "$HOST" ] && continue

    case "$PROTO" in
      tcp) SERVICE="tcp://localhost:$PORT" ;;
      http) SERVICE="http://localhost:$PORT" ;;
      https) SERVICE="https://localhost:$PORT" ;;
    esac

    echo "  - hostname: $HOST"
    echo "    service: $SERVICE"
    echo "    originRequest:"
    echo "      noTLSVerify: true"
    echo "      httpHostHeader: $HOST"

    if [ "$STREAM" = "ws" ] && [ "$PROTO" != "tcp" ]; then
      echo "      headers:"
      echo "        Connection: Upgrade"
      echo "        Upgrade: websocket"
    fi
    echo
  done
  echo "  - service: http_status:404"
} > "$CONFIG_FILE"

chmod 600 "$CONFIG_FILE"

# =========================
# cloudflared 启动命令（新旧兼容）
# =========================
EXEC_CMD=""

if [ "$MODE" = "1" ]; then
  if "$CLOUD_BIN" tunnel run --help 2>&1 | grep -q -- '--token-file'; then
    EXEC_CMD="$CLOUD_BIN tunnel run --token-file $TOKEN_FILE"
  else
    TOKEN_CONTENT=$(tr -d '\r\n' < "$TOKEN_FILE")
    EXEC_CMD="$CLOUD_BIN tunnel run --token $TOKEN_CONTENT --config $CONFIG_FILE"
  fi
else
  EXEC_CMD="$CLOUD_BIN tunnel run --credentials-file $CREDENTIAL_FILE"
fi

# =========================
# OpenRC 服务
# =========================
RC_FILE="/etc/init.d/cloudflared"

cat > "$RC_FILE" <<EOF
#!/sbin/openrc-run
description="Cloudflare Tunnel"
command="$CLOUD_BIN"
command_args="$(echo "$EXEC_CMD" | sed "s|$CLOUD_BIN||")"
command_background=true
pidfile="/run/cloudflared.pid"
directory="$CRED_DIR"
EOF

chmod +x "$RC_FILE"
rc-update add cloudflared default
rc-service cloudflared restart

info "✅ Cloudflared 已在 Alpine 启动"

echo
echo "配置文件: $CONFIG_FILE"
[ -f "$TOKEN_FILE" ] && echo "Token: $TOKEN_FILE"
[ -f "$CREDENTIAL_FILE" ] && echo "Credentials: $CREDENTIAL_FILE"
echo
echo "映射："
echo -e "$MAPPINGS"