#!/bin/bash

# Check if required environment variables are set
if [ -z "$GITHUB_USERNAME" ] || [ -z "$REPO_NAME" ] || [ -z "$GITHUB_TOKEN" ]; then
    echo "Error: Please set GITHUB_USERNAME, REPO_NAME, and GITHUB_TOKEN environment variables"
    exit 1
fi

# GitHub repository details
GITHUB_REPO="https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com/${GITHUB_USERNAME}/${REPO_NAME}.git"

# Clone or pull the repo
if [ ! -d "temp_repo" ]; then
    git clone "$GITHUB_REPO" temp_repo
fi

cd temp_repo

# Get the most recent backup file
LATEST_BACKUP=$(ls data-*.tar.gz | sort -r | head -n1)

if [ -n "$LATEST_BACKUP" ]; then
    # Copy backup to current directory
    cp "$LATEST_BACKUP" ../

    # Remove existing data directory and config.yml
    rm -rf ../data
    rm -f ../config.yml

    # Extract new backup
    tar -xzvf "../$LATEST_BACKUP" -C ..

    # Clean up
    rm "../$LATEST_BACKUP"
    rm -rf temp_repo

    echo "Restore completed successfully"
fi
