#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${1:-}"
REPO_URL="${2:-https://github.com/zaojiapaiwuhao/skyvault-drive.git}"
SITE_DIR="/var/www/skyvault-drive"
TMP_DIR="/tmp/skyvault-drive-deploy"
CONFIG_FILE="/etc/skyvault-drive.conf"

if [ -z "$DOMAIN" ]; then
  echo "用法:"
  echo "  sudo bash install.sh 你的域名"
  echo ""
  echo "示例:"
  echo "  sudo bash install.sh drive.example.com"
  echo ""
  echo "如果你想指定其他 Git 仓库，也可以这样:"
  echo "  sudo bash install.sh drive.example.com https://github.com/other/repo.git"
  exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "请使用 root 权限运行，例如：sudo bash install.sh $DOMAIN"
  exit 1
fi

echo "================================================="
echo " SkyVault Drive 静态站点部署脚本"
echo "-------------------------------------------------"
echo " 域名: $DOMAIN"
echo " 仓库: $REPO_URL"
echo " 网站目录: $SITE_DIR"
echo "================================================="

echo ""
echo "[1/8] 安装基础依赖..."
apt update
apt install -y curl git ca-certificates gnupg lsb-release debian-keyring debian-archive-keyring apt-transport-https

echo ""
echo "[2/8] 检查 80 / 443 端口占用..."
PORT_USED="$(ss -tulpn 2>/dev/null | grep -E ':80|:443' || true)"

if echo "$PORT_USED" | grep -qE 'nginx|apache2|httpd|openresty'; then
  echo "检测到 80/443 端口可能被其他 Web 服务占用："
  echo "$PORT_USED"
  echo ""
  echo "如果你要继续使用 Caddy，请先停止 Nginx / Apache / OpenResty / 宝塔相关 Web 服务。"
  echo "常用命令示例："
  echo "  sudo systemctl stop nginx"
  echo "  sudo systemctl disable nginx"
  echo ""
  echo "如果你确认不影响，也可以手动处理后重新运行本脚本。"
  exit 1
fi

echo ""
echo "[3/8] 安装 Caddy..."
if ! command -v caddy >/dev/null 2>&1; then
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
    | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg

  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
    > /etc/apt/sources.list.d/caddy-stable.list

  apt update
  apt install -y caddy
else
  echo "Caddy 已安装，跳过安装。"
fi

echo ""
echo "[4/8] 拉取网站代码..."
rm -rf "$TMP_DIR"
git clone --depth=1 "$REPO_URL" "$TMP_DIR"

echo ""
echo "[5/8] 部署静态文件..."
mkdir -p "$SITE_DIR"

if [ -d "$TMP_DIR/public" ]; then
  rm -rf "$SITE_DIR"/*
  cp -a "$TMP_DIR/public/." "$SITE_DIR/"
elif [ -f "$TMP_DIR/index.html" ]; then
  rm -rf "$SITE_DIR"/*
  cp "$TMP_DIR/index.html" "$SITE_DIR/index.html"
else
  echo "错误：仓库里没有 public/index.html 或 index.html"
  echo "请确认仓库结构类似："
  echo "  public/index.html"
  exit 1
fi

if [ ! -f "$SITE_DIR/index.html" ]; then
  echo "错误：部署后没有找到 $SITE_DIR/index.html"
  exit 1
fi

chown -R caddy:caddy "$SITE_DIR" || true
chmod -R 755 "$SITE_DIR"

echo ""
echo "[6/8] 写入 Caddy 配置..."
cat > /etc/caddy/Caddyfile <<EOF
$DOMAIN {
    root * $SITE_DIR
    file_server
    encode gzip zstd
}
EOF

caddy fmt --overwrite /etc/caddy/Caddyfile

echo ""
echo "[7/8] 保存部署配置..."
cat > "$CONFIG_FILE" <<EOF
DOMAIN="$DOMAIN"
REPO_URL="$REPO_URL"
SITE_DIR="$SITE_DIR"
EOF

echo ""
echo "[8/8] 创建更新命令 skyvault-update..."
cat > /usr/local/bin/skyvault-update <<'EOS'
#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="/etc/skyvault-drive.conf"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "未找到配置文件: $CONFIG_FILE"
  exit 1
fi

source "$CONFIG_FILE"

TMP_DIR="/tmp/skyvault-drive-update"

echo "================================================="
echo " SkyVault Drive 更新脚本"
echo "-------------------------------------------------"
echo " 仓库: $REPO_URL"
echo " 网站目录: $SITE_DIR"
echo "================================================="

rm -rf "$TMP_DIR"
git clone --depth=1 "$REPO_URL" "$TMP_DIR"

mkdir -p "$SITE_DIR"

if [ -d "$TMP_DIR/public" ]; then
  rm -rf "$SITE_DIR"/*
  cp -a "$TMP_DIR/public/." "$SITE_DIR/"
elif [ -f "$TMP_DIR/index.html" ]; then
  rm -rf "$SITE_DIR"/*
  cp "$TMP_DIR/index.html" "$SITE_DIR/index.html"
else
  echo "错误：仓库里没有 public/index.html 或 index.html"
  exit 1
fi

if [ ! -f "$SITE_DIR/index.html" ]; then
  echo "错误：更新后没有找到 $SITE_DIR/index.html"
  exit 1
fi

chown -R caddy:caddy "$SITE_DIR" || true
chmod -R 755 "$SITE_DIR"

systemctl reload caddy

echo ""
echo "更新完成。"
echo "你可以访问："
echo "  https://$DOMAIN"
EOS

chmod +x /usr/local/bin/skyvault-update

echo ""
echo "启动 Caddy..."
systemctl enable caddy
systemctl restart caddy

echo ""
echo "================================================="
echo "部署完成！"
echo ""
echo "访问地址:"
echo "  https://$DOMAIN"
echo ""
echo "以后更新网站，只需要在 VPS 执行:"
echo "  sudo skyvault-update"
echo ""
echo "检查 Caddy 状态:"
echo "  sudo systemctl status caddy"
echo ""
echo "查看 Caddy 日志:"
echo "  sudo journalctl -u caddy --no-pager -n 100"
echo ""
echo "注意："
echo "  1. 域名 A 记录必须已经指向当前 VPS IP"
echo "  2. VPS 安全组 / 防火墙必须开放 80 和 443"
echo "  3. Caddy 会自动申请和续订 HTTPS 证书"
echo "================================================="
