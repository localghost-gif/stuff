#!/bin/bash

# Script to download common security testing wordlists
# Creates a wordlists directory and downloads files there

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Security Wordlists Downloader${NC}"
echo "================================="

# Create wordlists directory if it doesn't exist
WORDLIST_DIR="wordlists"
if [ ! -d "$WORDLIST_DIR" ]; then
    echo -e "${YELLOW}Creating $WORDLIST_DIR directory...${NC}"
    mkdir -p "$WORDLIST_DIR"
fi

cd "$WORDLIST_DIR"

# Function to download and handle errors
download_file() {
    local url=$1
    local filename=$2
    local description=$3
    
    echo -e "\n${YELLOW}Downloading $description...${NC}"
    echo "URL: $url"
    
    if wget -O "$filename" "$url"; then
        echo -e "${GREEN}✓ Successfully downloaded $filename${NC}"
        
        # Show file size
        size=$(du -h "$filename" | cut -f1)
        echo "  File size: $size"
    else
        echo -e "${RED}✗ Failed to download $filename${NC}"
        return 1
    fi
}

# 1. Download n0kovo's huge subdomain list
download_file \
    "https://raw.githubusercontent.com/n0kovo/n0kovo_subdomains/main/n0kovo_subdomains.txt" \
    "n0kovo_subdomains.txt" \
    "n0kovo's huge subdomain list"

# 2. Download Directory 2.3 Medium list (from SecLists)
download_file \
    "https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/directory-list-2.3-medium.txt" \
    "directory-list-2.3-medium.txt" \
    "Directory 2.3 Medium wordlist"

# 3. Download RockYou wordlist
download_file \
    "https://raw.githubusercontent.com/brannondorsey/naive-hashcat/master/wordlists/rockyou.txt" \
    "rockyou.txt" \
    "RockYou password list"

echo -e "\n${GREEN}All downloads completed!${NC}"
echo -e "${YELLOW}Files saved in: $(pwd)${NC}"
echo ""
echo "Downloaded files:"
ls -lah *.txt 2>/dev/null || echo "No .txt files found"

echo -e "\n${YELLOW}Note: These wordlists are for legitimate security testing purposes only.${NC}"
echo -e "${YELLOW}Always ensure you have proper authorization before using them.${NC}"