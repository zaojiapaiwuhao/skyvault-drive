# SkyVault Drive

SkyVault Drive 是一个纯静态的云盘风格网站页面，支持中英文切换、搜索、分类导航、网格/列表视图。

项目自带 VPS 菜单式部署脚本，支持部署静态网站、安装 Caddy、申请 HTTPS 证书、安装 `sk` 快捷命令和卸载清理。

支持 Debian / Ubuntu 系统。

## 安装和使用

在 VPS 上执行：

curl -fsSL https://raw.githubusercontent.com/zaojiapaiwuhao/skyvault-drive/main/skyvault-drive -o skyvault-drive

chmod +x skyvault-drive

sudo ./skyvault-drive


=================================================
 SkyVault Drive 一键部署管理菜单
=================================================
 仓库: https://github.com/zaojiapaiwuhao/skyvault-drive.git
 目录: /var/www/skyvault-drive
=================================================
 1) 部署 / 更新静态网站
 2) 证书 / Caddy 管理
 3) 完全卸载：静态网站 + Caddy + 证书
 4) 查看状态
 5) 安装 sk 快捷命令
 0) 退出
=================================================
