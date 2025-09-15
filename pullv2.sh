#!/bin/bash

# Script to clone and extract specific security testing wordlists
# Creates a wordlists directory and downloads the same 3 files as before

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Security Wordlists Downloader (Git Version)${NC}"
echo "============================================="

# Create wordlists directory if it doesn't exist
WORDLIST_DIR="wordlists"
if [ ! -d "$WORDLIST_DIR" ]; then
    echo -e "${YELLOW}Creating $WORDLIST_DIR directory...${NC}"
    mkdir -p "$WORDLIST_DIR"
fi

cd "$WORDLIST_DIR"

# Function to clone repo, extract file, and cleanup
extract_file_from_repo() {
    local repo_url=$1
    local file_path=$2
    local output_filename=$3
    local description=$4
    local temp_dir="temp_repo_$$"
    
    echo -e "\n${YELLOW}Extracting $description...${NC}"
    echo "Repository: $repo_url"
    echo "File: $file_path"
    
    if git clone --depth 1 --filter=blob:none --sparse "$repo_url" "$temp_dir"; then
        cd "$temp_dir"
        git sparse-checkout set "$file_path"
        
        if [ -f "$file_path" ]; then
            cp "$file_path" "../$output_filename"
            cd ..
            rm -rf "$temp_dir"
            
            echo -e "${GREEN}✓ Successfully extracted $output_filename${NC}"
            
            # Show file size
            size=$(du -h "$output_filename" | cut -f1)
            echo "  File size: $size"
        else
            cd ..
            rm -rf "$temp_dir"
            echo -e "${RED}✗ File not found in repository: $file_path${NC}"
            return 1
        fi
    else
        rm -rf "$temp_dir" 2>/dev/null || true
        echo -e "${RED}✗ Failed to clone repository${NC}"
        return 1
    fi
}

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo -e "${RED}Error: git is not installed. Please install git first.${NC}"
    exit 1
fi

# 1. Extract n0kovo's huge subdomain list
extract_file_from_repo \
    "https://github.com/n0kovo/n0kovo_subdomains.git" \
    "n0kovo_subdomains.txt" \
    "n0kovo_subdomains.txt" \
    "n0kovo's huge subdomain list"

# 2. Extract Directory 2.3 Medium list (from SecLists)
extract_file_from_repo \
    "https://github.com/danielmiessler/SecLists.git" \
    "Discovery/Web-Content/directory-list-2.3-medium.txt" \
    "directory-list-2.3-medium.txt" \
    "Directory 2.3 Medium wordlist"

# 3. Extract RockYou wordlist (try multiple possible locations)
echo -e "\n${YELLOW}Extracting RockYou password list...${NC}"
rockyou_extracted=false

# Try different possible locations for rockyou.txt in SecLists
rockyou_paths=(
    "Passwords/Leaked-Databases/rockyou.txt"
    "Passwords/Leaked-Databases/rockyou-75.txt"
    "Passwords/rockyou.txt"
)

for rockyou_path in "${rockyou_paths[@]}"; do
    echo "Trying path: $rockyou_path"
    if extract_file_from_repo \
        "https://github.com/danielmiessler/SecLists.git" \
        "$rockyou_path" \
        "rockyou.txt" \
        "RockYou password list"; then
        rockyou_extracted=true
        break
    fi
done

# If rockyou not found in SecLists, try alternative repository
if [ "$rockyou_extracted" = false ]; then
    echo -e "${YELLOW}Trying alternative repository for rockyou.txt...${NC}"
    extract_file_from_repo \
        "https://github.com/brannondorsey/naive-hashcat.git" \
        "wordlists/rockyou.txt" \
        "rockyou.txt" \
        "RockYou password list (alternative source)"
fi

echo -e "\n${GREEN}All downloads completed!${NC}"
echo -e "${YELLOW}Files saved in: $(pwd)${NC}"
echo ""
echo "Downloaded files:"
ls -lah *.txt 2>/dev/null || echo "No .txt files found"

echo -e "\n${YELLOW}Note: These wordlists are for legitimate security testing purposes only.${NC}"
echo -e "${YELLOW}Always ensure you have proper authorization before using them.${NC}"
