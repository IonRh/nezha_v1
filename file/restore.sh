#!/bin/bash
set -e

WORK_DIR=/app

# 检查必要环境变量
if [ -z "$GITHUB_USERNAME" ] || [ -z "$REPO_NAME" ] || [ -z "$GITHUB_TOKEN" ] || [ -z "$ZIP_PASSWORD" ]; then
    echo "Restore: 缺少备份相关环境变量，跳过恢复"
    exit 0
fi

GITHUB_REPO="https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com/${GITHUB_USERNAME}/${REPO_NAME}.git"

# 获取最新备份文件名
LATEST_BACKUP=$(curl -s -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3.raw" \
    "https://api.github.com/repos/$GITHUB_USERNAME/$REPO_NAME/contents/README.md" 2>/dev/null | tr -d '[:space:]')

if [ -z "$LATEST_BACKUP" ] || [ "$LATEST_BACKUP" = "backup" ]; then
    echo "Restore: 无有效备份文件，跳过"
    exit 0
fi

echo "Restore: 正在恢复 $LATEST_BACKUP ..."

# 克隆仓库
rm -rf "$WORK_DIR/temp_repo"
git clone --depth 1 "$GITHUB_REPO" "$WORK_DIR/temp_repo"

if [ ! -f "$WORK_DIR/temp_repo/$LATEST_BACKUP" ]; then
    echo "Restore: 备份文件不存在，跳过"
    rm -rf "$WORK_DIR/temp_repo"
    exit 0
fi

# 解压恢复
rm -rf "$WORK_DIR/data" "$WORK_DIR/config.yml"
unzip -P "$ZIP_PASSWORD" "$WORK_DIR/temp_repo/$LATEST_BACKUP" -d "$WORK_DIR"

# 清理
rm -rf "$WORK_DIR/temp_repo"
echo "Restore: 恢复完成"
