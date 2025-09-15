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

# Function to download a file from GitHub raw content using main/master fallback
download_from_github() {
    local github_repo="$1"
    local file_path="$2"
    local output_filename="$3"
    local description="$4"

    echo -e "\n${YELLOW}Downloading $description...${NC}"

    for branch in main master; do
        raw_url="https://raw.githubusercontent.com/${github_repo}/${branch}/${file_path}"
        echo "Trying: $raw_url"

        if wget -q --show-progress -O "$output_filename" "$raw_url"; then
            echo -e "${GREEN}✓ Successfully downloaded $output_filename${NC}"
            size=$(du -h "$output_filename" | cut -f1)
            echo "  File size: $size"
            return 0
        else
            echo -e "${RED}✗ Failed to download from branch '$branch'${NC}"
        fi
    done

    echo -e "${RED}✗ All attempts failed for $description${NC}"
    return 1
}

# Check if wget is installed
if ! command -v wget &> /dev/null; then
    echo -e "${RED}Error: wget is not installed. Please install wget first.${NC}"
    exit 1
fi

# 1. Download n0kovo's huge subdomain list
download_from_github \
    "n0kovo/n0kovo_subdomains" \
    "n0kovo_subdomains.txt" \
    "n0kovo_subdomains.txt" \
    "n0kovo's huge subdomain list"

# 2. Download Directory 2.3 Medium list (from SecLists)
download_from_github \
    "danielmiessler/SecLists" \
    "Discovery/Web-Content/directory-list-2.3-medium.txt" \
    "directory-list-2.3-medium.txt" \
    "Directory 2.3 Medium wordlist"

# 3. Download RockYou wordlist from multiple sources
echo -e "\n${YELLOW}Downloading RockYou password list...${NC}"
rockyou_downloaded=false

declare -a rockyou_sources=(
    "brannondorsey/naive-hashcat|master|wordlists/rockyou.txt"
    "danielmiessler/SecLists|master|Passwords/Leaked-Databases/rockyou.txt"
    "danielmiessler/SecLists|master|Passwords/Leaked-Databases/rockyou-75.txt"
)

for source in "${rockyou_sources[@]}"; do
    IFS='|' read -r repo branch path <<< "$source"
    raw_url="https://raw.githubusercontent.com/${repo}/${branch}/${path}"

    echo "Trying: $raw_url"

    if wget -q --show-progress -O "rockyou.txt" "$raw_url"; then
        echo -e "${GREEN}✓ Successfully downloaded rockyou.txt${NC}"
        size=$(du -h "rockyou.txt" | cut -f1)
        echo "  File size: $size"
        rockyou_downloaded=true
        break
    else
        echo -e "${RED}✗ Failed from this source${NC}"
    fi
done

if [ "$rockyou_downloaded" = false ]; then
    echo -e "${RED}✗ Could not download rockyou.txt from any source${NC}"
fi

# Summary
echo -e "\n${GREEN}Download process completed!${NC}"
echo -e "${YELLOW}Files saved in: $(pwd)${NC}"
echo ""
echo "Downloaded files:"
ls -lah *.txt 2>/dev/null || echo "No .txt files found"

# Final note
echo -e "\n${YELLOW}Note: These wordlists are for legitimate security testing purposes only.${NC}"
echo -e "${YELLOW}Always ensure you have proper authorization before using them.${NC}"

