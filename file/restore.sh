#!/bin/bash

# 检查必要的环境变量
if [ -z "$GITHUB_USERNAME" ] || [ -z "$REPO_NAME" ] || [ -z "$GITHUB_TOKEN" ] || [ -z "$ZIP_PASSWORD" ]; then
    echo "错误：请设置 GITHUB_USERNAME, REPO_NAME, GITHUB_TOKEN 和 ZIP_PASSWORD 环境变量"
    exit 1
fi

# GitHub 仓库地址
GITHUB_REPO="https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com/${GITHUB_USERNAME}/${REPO_NAME}.git"

# 使用 GitHub API 获取 README.md 内容
readme_content=$(curl -s -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3.raw" \
    "https://api.github.com/repos/$GITHUB_USERNAME/$REPO_NAME/contents/README.md")

# 创建临时目录
TEMP_DIR="temp_repo"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# 初始化 Git 仓库并配置稀疏检出
if [ ! -d ".git" ]; then
    git init
    git remote add origin "$GITHUB_REPO"
    git config core.sparseCheckout true
    # 只检出 README.md 和 data-*.zip 文件
    echo "README.md" >> .git/info/sparse-checkout
    echo "data-*.zip" >> .git/info/sparse-checkout
    git pull origin main
else
    git pull origin main
fi

# 检查 Git LFS 支持（如果使用 LFS）
git lfs install
git lfs pull

# 获取最新的备份文件
LATEST_BACKUP=""
if [ -n "$readme_content" ]; then
    LATEST_BACKUP=$(echo "$readme_content" | grep -o 'data-[^ ]*\.zip' | head -n1)
fi
if [ -z "$LATEST_BACKUP" ]; then
    LATEST_BACKUP=$(ls data-*.zip | sort -r | head -n1)
fi

# 恢复备份
if [ -n "$LATEST_BACKUP" ] && [ -f "$LATEST_BACKUP" ]; then
    # 复制备份到上级目录
    cp "$LATEST_BACKUP" ../
    cd ..
    # 删除旧的数据目录和配置文件
    rm -rf data
    rm -f config.yml
    # 解压备份
    unzip -P "$ZIP_PASSWORD" "$LATEST_BACKUP" -d .
    # 清理临时文件
    rm "$LATEST_BACKUP"
    rm -rf "$TEMP_DIR"
    echo "恢复完成"
else
    echo "错误：未找到备份文件"
    rm -rf "$TEMP_DIR"
    exit 1
fi
