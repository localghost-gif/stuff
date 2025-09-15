#!/bin/bash

# Script to download specific security testing wordlists using GitHub's raw file URLs
# Creates a wordlists directory and downloads only the 3 specific files

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Security Wordlists Downloader (Git Raw URLs)${NC}"
echo "============================================="

# Create wordlists directory if it doesn't exist
WORDLIST_DIR="wordlists"
if [ ! -d "$WORDLIST_DIR" ]; then
    echo -e "${YELLOW}Creating $WORDLIST_DIR directory...${NC}"
    mkdir -p "$WORDLIST_DIR"
fi

cd "$WORDLIST_DIR"

# Function to download file from GitHub raw URL
download_from_github() {
    local github_repo=$1
    local file_path=$2
    local output_filename=$3
    local description=$4
    
    local raw_url="https://raw.githubusercontent.com/${github_repo}/main/${file_path}"
    
    echo -e "\n${YELLOW}Downloading $description...${NC}"
    echo "URL: $raw_url"
    
    # Try main branch first, then master if main fails



