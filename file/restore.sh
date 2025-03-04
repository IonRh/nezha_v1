#!/bin/bash
# 使用 GitHub API 获取 README.md 文件内容
readme_content=$(curl -s -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3.raw" \
    "https://api.github.com/repos/$GITHUB_USERNAME/$REPO_NAME/contents/README.md")
# Check if required environment variables are set
if [ -z "$GITHUB_USERNAME" ] || [ -z "$REPO_NAME" ] || [ -z "$GITHUB_TOKEN" ]; then
    echo "Error: Please set GITHUB_USERNAME, REPO_NAME, 和 GITHUB_TOKEN environment variables"
    exit 1
fi

# GitHub repository details
GITHUB_REPO="https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com/${GITHUB_USERNAME}/${REPO_NAME}.git"

# Clone or pull the repo
if [ ! -d "temp_repo" ]; then
    git clone "$GITHUB_REPO" temp_repo
fi

cd temp_repo

LATEST_BACKUP=$readme_content
if [ -z "$readme_content" ]; then
    # Get the most recent backup file
    LATEST_BACKUP=$(ls data-*.zip | sort -r | head -n1)
fi
if [ -n "$LATEST_BACKUP" ]; then
    # Copy backup to current directory
    cp "$LATEST_BACKUP" ../

    # Remove existing data directory and config.yml
    rm -rf ../data
    rm -f ../config.yml

    # Extract new backup
    unzip -P "$ZIP_PASSWORD" "../$LATEST_BACKUP" -d ..

    # Clean up
    rm "../$LATEST_BACKUP"
    rm -rf /app/temp_repo
    echo "Restore completed successfully"
fi
