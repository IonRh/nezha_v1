#!/bin/bash
# 设置错误退出
set -e
# 创建临时目录
TEMP_DIR="temp_file"
mkdir -p "$TEMP_DIR"
cp -R /app/data "$TEMP_DIR"
cp config.yml "$TEMP_DIR"
cd "$TEMP_DIR/data"
# 清空 SQLite 数据库中的 service_histories 表
sqlite3 sqlite.db "DELETE FROM service_histories;"
cd ..
# 检查环境变量
if [ -z "$GITHUB_USERNAME" ] || [ -z "$REPO_NAME" ] || [ -z "$GITHUB_TOKEN" ] || [ -z "$ZIP_PASSWORD" ]; then
    echo "错误：请设置 GITHUB_USERNAME, REPO_NAME, GITHUB_TOKEN 和 ZIP_PASSWORD 环境变量"
    exit 1
fi
# 生成上海时间戳
TIMESTAMP=$(TZ='Asia/Shanghai' date +"%Y-%m-%d-%H-%M-%S")
BACKUP_FILE="data-${TIMESTAMP}.zip"
echo "$BACKUP_FILE" > README.md
# 压缩数据目录和 config.yml
zip -r -P "$ZIP_PASSWORD" "$BACKUP_FILE" data config.yml
# GitHub 仓库配置
GITHUB_REPO="https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com/${GITHUB_USERNAME}/${REPO_NAME}.git"
REPO_DIR="temp_repo"
# 克隆或更新仓库
if [ ! -d "$REPO_DIR" ]; then
    git clone "$GITHUB_REPO" "$REPO_DIR"
fi
cd "$REPO_DIR"
# 拉取远程最新数据（尝试合并）
git pull origin main || {
    echo "警告：git pull 失败，可能有冲突。将重置历史。"
}
# 删除旧历史，创建新仓库
cd ..
rm -rf "$REPO_DIR/.git"
cd "$REPO_DIR"
git init
git branch -M main
# 复制新备份文件和 README.md
cp "../$BACKUP_FILE" "../README.md" .
# 删除旧备份文件，保留最新 5 个
BACKUPS=$(ls data-*.zip 2>/dev/null | sort -r)
BACKUPS_TO_REMOVE=$(echo "$BACKUPS" | tail -n +6)
for backup in $BACKUPS_TO_REMOVE; do
    rm -f "$backup"
done
# 配置 Git 用户
git config user.name "Backup Script"
git config user.email "backup@localhost"
# 提交新文件
git add .
git commit -m "添加备份：$BACKUP_FILE"
# 设置远程仓库并强制推送（重写历史）
git remote add origin "$GITHUB_REPO"
git push -u --force origin main
# 清理临时文件
cd ..
rm "$BACKUP_FILE"
rm -rf /app/temp_file
echo "备份完成，历史提交已删除"
