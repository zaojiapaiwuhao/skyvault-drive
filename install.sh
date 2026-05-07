#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${1:-}"
REPO_URL="${2:-}"
SITE_DIR="/var/www/skyvault-drive"
TMP_DIR="/tmp/skyvault-drive-deploy"
CONFIG_FILE="/etc/skyvault-drive.conf"

if [ -z "$DOMAIN" ] || [ -z "$REPO_URL" ]; then
  echo "用法:"
  echo "  sudo bash install.sh 你的域名 Git仓库地址"
  echo ""
  echo "示例:"
  echo "  sudo bash install.sh drive.example.com https://github.com/yourname/skyvault-drive.git"
  exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "请使用 root 权限运行，例如：sudo bash install.sh ..."
  exit 1
fi

echo "================================================="
echo " SkyVault Drive 静态站点部署脚本"
echo " 域名: $DOMAIN"
echo " 仓库: $REPO_URL"
echo " 网站目录: $SITE_DIR"
echo "================================================="

echo "[1/7] 安装基础依赖..."
apt update
apt install -y curl git ca-certificates gnupg lsb-release

echo "[2/7] 安装 Caddy..."
if ! command -v caddy >/dev/null 2>&1; then
  apt install -y debian-keyring debian-archive-keyring apt-transport-https

  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
    | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg

  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
    > /etc/apt/sources.list.d/caddy-stable.list

  apt update
  apt install -y caddy
else
  echo "Caddy 已安装，跳过。"
fi

echo "[3/7] 拉取网站代码..."
rm -rf "$TMP_DIR"
git clone --depth=1 "$REPO_URL" "$TMP_DIR"

echo "[4/7] 部署静态文件..."
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

chown -R caddy:caddy "$SITE_DIR" || true
chmod -R 755 "$SITE_DIR"

echo "[5/7] 写入 Caddy 配置..."
cat > /etc/caddy/Caddyfile <<EOF
$DOMAIN {
    root * $SITE_DIR
    file_server
    encode gzip zstd
}
EOF

caddy fmt --overwrite /etc/caddy/Caddyfile

echo "[6/7] 保存部署配置..."
cat > "$CONFIG_FILE" <<EOF
DOMAIN="$DOMAIN"
REPO_URL="$REPO_URL"
SITE_DIR="$SITE_DIR"
EOF

echo "[7/7] 创建更新命令 skyvault-update..."
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

echo "开始更新 SkyVault Drive..."
echo "仓库: $REPO_URL"
echo "目录: $SITE_DIR"

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

chown -R caddy:caddy "$SITE_DIR" || true
chmod -R 755 "$SITE_DIR"

systemctl reload caddy

echo "更新完成。"
EOS

chmod +x /usr/local/bin/skyvault-update

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
echo "注意：请确保域名 A 记录已经指向当前 VPS IP，并且 80/443 端口已开放。"
echo "================================================="
