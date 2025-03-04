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
    # cp "$LATEST_BACKUP" ../
    # Remove existing data directory and config.yml
    rm -f ../config.yml
    # Extract new backup
    unzip -P "$ZIP_PASSWORD" "$LATEST_BACKUP" -d .
    cp config.yml ../
    cd data
    database="sqlite.db"
    tables=(
    "alert_rules"
    "crons"
    "ddns"
    "nats"
    "notification_group_notifications"
    "notification groups"
    "notifications"
    "nz_waf"
    "oauth2_binds"
    "server_group_servers"
    "server_groups"
    "servers"
    "services"
    "transfers"
    "users"
    )
    output_file="all_tables_data.sql"
    for table in "${tables[@]}"; do
    echo "--- Table: $table ---" >> "$output_file"
    sqlite3 "$database" ".dump \"$table\"" >> "$output_file"
    echo "" >> "$output_file"
    if [ $? -ne 0 ]; then
    echo "Error dumping table $table"
    exit 1
    fi
    echo "" >> "$output_file"
    done
    echo "Exported all specified tables data to $output_file"
    input_file="all_tables_data.sql"
    output_file="all_inserts.sql"
    grep "INSERT INTO" "$input_file" > "$output_file"
    if [ $? -eq 0 ]; then
    echo "Successfully extracted all INSERT statements to $output_file"
    else
    echo "Error extracting INSERT statements."
    fi
    cp all_inserts.sql /app/data
    cd /app/data
    sqlite3 sqlite.db "DELETE FROM users;"
    sqlite3 sqlite.db < all_inserts.sql
    # Clean up
    rm /app/data/all_inserts.sql "/app/data/$LATEST_BACKUP"
    rm -rf /app/temp_repo
    echo "Restore completed successfully"
fi
