#!/bin/bash
set -e

# 检查必要环境变量
if [ -z "$GITHUB_USERNAME" ] || [ -z "$REPO_NAME" ] || [ -z "$GITHUB_TOKEN" ] || [ -z "$ZIP_PASSWORD" ]; then
    echo "Error: 请设置 GITHUB_USERNAME, REPO_NAME, GITHUB_TOKEN, ZIP_PASSWORD"
    exit 1
fi

WORK_DIR=/app
TEMP_DIR="$WORK_DIR/temp_backup"
GITHUB_REPO="https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com/${GITHUB_USERNAME}/${REPO_NAME}.git"
TIMESTAMP=$(TZ='Asia/Shanghai' date +"%Y-%m-%d-%H-%M-%S")
BACKUP_FILE="data-${TIMESTAMP}.zip"

# 清理旧临时目录
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

# 复制数据
cp -R "$WORK_DIR/data" "$TEMP_DIR/"
cp "$WORK_DIR/config.yml" "$TEMP_DIR/" 2>/dev/null || true

# 压缩 sqlite 数据库
if [ -f "$TEMP_DIR/data/sqlite.db" ]; then
    cd "$TEMP_DIR/data"
    sqlite3 sqlite.db ".recover" | sqlite3 sqlite.db.new && mv sqlite.db.new sqlite.db || true
    sqlite3 sqlite.db "DELETE FROM service_histories;" 2>/dev/null || true
    sqlite3 sqlite.db "DELETE FROM transfers;" 2>/dev/null || true
fi

# 打包
cd "$TEMP_DIR"
echo "$BACKUP_FILE" > README.md
zip -r -P "$ZIP_PASSWORD" "$BACKUP_FILE" data config.yml 2>/dev/null || zip -r -P "$ZIP_PASSWORD" "$BACKUP_FILE" data

# 克隆仓库并推送
rm -rf temp_repo
git clone "$GITHUB_REPO" temp_repo
cd temp_repo
cp "../$BACKUP_FILE" "../README.md" ./

# 保留最新 5 个备份
BACKUPS_TO_REMOVE=$(ls data-*.zip 2>/dev/null | sort -r | tail -n +6)
for backup in $BACKUPS_TO_REMOVE; do
    rm -f "$backup"
done

rm -rf .git
git init
git branch -M main
git config user.name "Backup Script"
git config user.email "backup@localhost"
git add .
git commit -m "备份：$BACKUP_FILE"
git remote add origin "$GITHUB_REPO"
git push -u --force origin main

# 清理
cd "$WORK_DIR"
rm -rf "$TEMP_DIR"
echo "备份完成：$BACKUP_FILE"
