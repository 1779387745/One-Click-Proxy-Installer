#!/bin/sh
# =============================================================================
#  Cloudflared Tunnel 一键部署脚本（Alpine Linux 优化版）
#  适用于 3x-ui / x-ui / v2ray / xray 等面板
#  重点优化：正确选择 service 类型（tcp/http），避免 WS/gRPC 超时
#  最后更新：2026年常用做法
# =============================================================================

set -eu

# -------------------------------
# 颜色与辅助函数
# -------------------------------
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[1;33m'
reset='\033[0m'

die()    { echo -e "${red}✖ $*\n${reset}" >&2; exit 1; }
info()   { echo -e "${yellow}→ $*${reset}"; }
success() { echo -e "${green}√ $*${reset}"; }

# 必须 root 运行（OpenRC 需要）
[ "$(id -u)" -eq 0 ] || die "此脚本必须以 root 身份运行（Alpine OpenRC 需要）"

# -------------------------------
# 安装必要依赖
# -------------------------------
info "安装基本依赖..."
apk add --no-cache curl wget ca-certificates >/dev/null

# -------------------------------
# 安装/更新 cloudflared
# -------------------------------
install_cloudflared() {
  if ! command -v cloudflared >/dev/null 2>&1; then
    info "正在安装 cloudflared..."
    ARCH=$(uname -m)
    case "$ARCH" in
      x86_64)  FILE="cloudflared-linux-amd64" ;;
      aarch64) FILE="cloudflared-linux-arm64" ;;
      *)       die "不支持的架构: $ARCH" ;;
    esac

    LATEST_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/$FILE"
    wget -O /usr/local/bin/cloudflared "$LATEST_URL" || die "下载 cloudflared 失败"
    chmod +x /usr/local/bin/cloudflared
    success "cloudflared 安装完成"
  else
    info "cloudflared 已存在，跳过安装"
  fi
}

install_cloudflared
CLOUD_BIN="/usr/local/bin/cloudflared"

# -------------------------------
# 目录准备
# -------------------------------
CRED_DIR="/root/.cloudflared"
mkdir -p "$CRED_DIR"
chmod 700 "$CRED_DIR"

CONFIG_FILE="$CRED_DIR/config.yml"
TOKEN_FILE="$CRED_DIR/token"
CRED_JSON="$CRED_DIR/credentials.json"

# -------------------------------
# 用户输入：域名与端口映射
# -------------------------------
printf "\n${yellow}需要配置几个域名->端口映射？（例如 1 或 2）： ${reset}"
read -r NUM
case "$NUM" in ''|*[!0-9]*) NUM=1 ;; esac
[ "$NUM" -lt 1 ] && NUM=1

MAPPINGS=""

for i in $(seq 1 "$NUM"); do
  echo -e "\n${yellow}=== 配置第 $i 个域名 ===${reset}"

  printf "域名 (如：v2ray.example.com): "
  read -r DOMAIN
  [ -z "$DOMAIN" ] && die "域名不能为空！"

  printf "本地端口 (默认 443): "
  read -r PORT
  PORT=${PORT:-443}
  [ -z "$PORT" ] && PORT=443

  echo -e "\n${yellow}你的节点传输方式（重要！选错会导致超时）：${reset}"
  echo "  1) WS / websocket（最常见，VMess/VLESS+WS）         ★★★★★"
  echo "  2) gRPC（VLESS+gRPC 主流）                            ★★★★☆"
  echo "  3) 纯 TCP（Trojan TCP / Shadowsocks TCP 等）          ★★★★☆"
  echo "  4) http / httpupgrade / 回落伪装（极少用）            ★☆☆☆☆"
  printf "\n请选择 [1-4]（默认 1，最推荐）： "
  read -r TYPE
  TYPE=${TYPE:-1}

  case "$TYPE" in
    1)   STREAM="ws"    ;;
    2)   STREAM="grpc"  ;;
    3)   STREAM="tcp"   ;;
    4)   STREAM="http"  ;;
    *)   STREAM="ws"; echo -e "${yellow}无效选项，默认使用 WS${reset}" ;;
  esac

  # 绝大多数情况下使用 tcp 协议映射最稳定
  echo -e "\n${yellow}Cloudflared service 类型推荐（99% 情况选 tcp）：${reset}"
  echo "  tcp   → WS / gRPC / TCP 都推荐（最稳定）"
  echo "  http  → 只有 httpupgrade 或回落伪装才考虑"
  echo "  https → 极少数情况（本地是 https 服务）"
  printf "请选择 service 类型 [tcp/http/https]（默认 tcp）： "
  read -r PROTO
  PROTO=${PROTO:-tcp}
  case "$PROTO" in
    tcp|http|https) ;;
    *) PROTO="tcp"; echo -e "${yellow}无效输入，默认使用 tcp（最安全）${reset}" ;;
  esac

  MAPPINGS="${MAPPINGS}${DOMAIN},${PORT},${STREAM},${PROTO}\n"
done

# -------------------------------
# 凭证方式选择
# -------------------------------
echo -e "\n${yellow}凭证方式：${reset}"
echo "  1) 使用 Tunnel Token（推荐，新版 cloudflared 支持）"
echo "  2) 使用 credentials JSON 文件（旧方式）"
printf "请选择 [1/2]（默认 1）： "
read -r MODE
MODE=${MODE:-1}

case "$MODE" in
  1)
    printf "请输入 Tunnel Token: "
    read -r TOKEN
    [ -z "$TOKEN" ] && die "Token 不能为空"
    printf "%s" "$TOKEN" > "$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE"
    ;;
  2)
    echo "请粘贴完整的 credentials JSON（输入空行结束）："
    JSON=""
    while IFS= read -r line; do
      [ -z "$line" ] && break
      JSON="${JSON}${line}\n"
    done
    [ -z "$JSON" ] && die "JSON 内容不能为空"
    printf "%b" "$JSON" > "$CRED_JSON"
    chmod 600 "$CRED_JSON"
    ;;
  *)
    die "无效选择"
    ;;
esac

# -------------------------------
# 生成 config.yml
# -------------------------------
info "生成配置文件：$CONFIG_FILE"

{
  echo "ingress:"
  echo -e "$MAPPINGS" | while IFS=',' read -r HOST PORT STREAM PROTO; do
    [ -z "$HOST" ] && continue

    case "$PROTO" in
      tcp)   SERVICE="tcp://localhost:$PORT" ;;
      http)  SERVICE="http://localhost:$PORT" ;;
      https) SERVICE="https://localhost:$PORT" ;;
      *)     SERVICE="tcp://localhost:$PORT" ;;
    esac

    echo "  - hostname: $HOST"
    echo "    service: $SERVICE"
    echo "    originRequest:"
    echo "      noTLSVerify: true"
    echo "      httpHostHeader: $HOST"

    # 只有 http/https + WS 时才添加 Upgrade 头（gRPC 和纯 tcp 不需要）
    if [ "$STREAM" = "ws" ] && [ "$PROTO" != "tcp" ]; then
      echo "      headers:"
      echo "        Connection: Upgrade"
      echo "        Upgrade: websocket"
    fi
    echo ""
  done

  # 兜底规则
  echo "  - service: http_status:404"
} > "$CONFIG_FILE"

chmod 600 "$CONFIG_FILE"
success "配置文件生成完成"

# -------------------------------
# 生成 OpenRC 服务文件
# -------------------------------
RC_FILE="/etc/init.d/cloudflared"

cat > "$RC_FILE" <<EOF
#!/sbin/openrc-run

description="Cloudflare Tunnel Client"
command="$CLOUD_BIN"
command_args="--config $CONFIG_FILE"
${MODE:+# Token/credentials already in config or env}
command_background="yes"
pidfile="/run/cloudflared.pid"
directory="$CRED_DIR"

depend() {
        need net
        after firewall
}
EOF

chmod +x "$RC_FILE"
rc-update add cloudflared default 2>/dev/null || true

# -------------------------------
# 启动服务
# -------------------------------
info "尝试启动 cloudflared 服务..."
rc-service cloudflared restart || {
  info "OpenRC 启动失败，尝试前台运行测试..."
  echo -e "${yellow}请观察是否有错误，按 Ctrl+C 退出测试${reset}\n"
  "$CLOUD_BIN" tunnel --config "$CONFIG_FILE" run
}

success "部署完成！"

echo -e "\n${green}重要文件位置：${reset}"
echo "  配置文件     : $CONFIG_FILE"
[ -f "$TOKEN_FILE" ]  && echo "  Token 文件    : $TOKEN_FILE"
[ -f "$CRED_JSON" ]   && echo "  Credentials   : $CRED_JSON"
echo
echo "${yellow}映射概览：${reset}"
echo -e "$MAPPINGS" | sed '/^$/d'

echo -e "\n${green}温馨提示：${reset}"
echo "  • 绝大多数 WS / gRPC / TCP 节点 → 必须使用 tcp:// 映射"
echo "  • 如果节点仍然超时 → 99% 是 service 类型选错了，改成 tcp 再试"
echo "  • 祝你节点稳定，流量飞起！"