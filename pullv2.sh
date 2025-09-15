#!/bin/bash

# Script to clone common security testing repositories
# Creates a wordlists directory and clones repositories there

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Security Repositories Cloner${NC}"
echo "================================="

# Create wordlists directory if it doesn't exist
WORDLIST_DIR="wordlists"
if [ ! -d "$WORDLIST_DIR" ]; then
    echo -e "${YELLOW}Creating $WORDLIST_DIR directory...${NC}"
    mkdir -p "$WORDLIST_DIR"
fi

cd "$WORDLIST_DIR"

# Function to clone repository and handle errors
clone_repo() {
    local repo_url=$1
    local repo_name=$2
    local description=$3
    
    echo -e "\n${YELLOW}Cloning $description...${NC}"
    echo "Repository: $repo_url"
    
    # Remove existing directory if it exists
    if [ -d "$repo_name" ]; then
        echo -e "${BLUE}Removing existing $repo_name directory...${NC}"
        rm -rf "$repo_name"
    fi
    
    if git clone --depth 1 "$repo_url" "$repo_name"; then
        echo -e "${GREEN}✓ Successfully cloned $repo_name${NC}"
        
        # Show directory size
        size=$(du -sh "$repo_name" | cut -f1)
        echo "  Directory size: $size"
        
        # Show file count
        file_count=$(find "$repo_name" -type f | wc -l)
        echo "  Files: $file_count"
    else
        echo -e "${RED}✗ Failed to clone $repo_name${NC}"
        return 1
    fi
}

# Function to create symbolic links for easy access
create_symlinks() {
    echo -e "\n${YELLOW}Creating symbolic links for commonly used files...${NC}"
    
    # Link rockyou.txt if it exists
    if [ -f "SecLists/Passwords/Leaked-Databases/rockyou.txt" ]; then
        ln -sf "SecLists/Passwords/Leaked-Databases/rockyou.txt" "rockyou.txt"
        echo -e "${GREEN}✓ Linked rockyou.txt${NC}"
    elif [ -f "SecLists/Passwords/Leaked-Databases/rockyou-75.txt" ]; then
        ln -sf "SecLists/Passwords/Leaked-Databases/rockyou-75.txt" "rockyou.txt"
        echo -e "${GREEN}✓ Linked rockyou-75.txt as rockyou.txt${NC}"
    fi
    
    # Link directory wordlist
    if [ -f "SecLists/Discovery/Web-Content/directory-list-2.3-medium.txt" ]; then
        ln -sf "SecLists/Discovery/Web-Content/directory-list-2.3-medium.txt" "directory-list-medium.txt"
        echo -e "${GREEN}✓ Linked directory-list-medium.txt${NC}"
    fi
    
    # Link subdomain wordlist
    if [ -f "n0kovo_subdomains/n0kovo_subdomains.txt" ]; then
        ln -sf "n0kovo_subdomains/n0kovo_subdomains.txt" "subdomains.txt"
        echo -e "${GREEN}✓ Linked subdomains.txt${NC}"
    fi
    
    # Link common passwords
    if [ -f "SecLists/Passwords/Common-Credentials/10-million-password-list-top-1000000.txt" ]; then
        ln -sf "SecLists/Passwords/Common-Credentials/10-million-password-list-top-1000000.txt" "common-passwords.txt"
        echo -e "${GREEN}✓ Linked common-passwords.txt${NC}"
    fi
}

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo -e "${RED}Error: git is not installed. Please install git first.${NC}"
    exit 1
fi

# 1. Clone SecLists - Comprehensive collection of security testing wordlists
clone_repo \
    "https://github.com/danielmiessler/SecLists.git" \
    "SecLists" \
    "SecLists - Security testing wordlists collection"

# 2. Clone n0kovo's subdomain list
clone_repo \
    "https://github.com/n0kovo/n0kovo_subdomains.git" \
    "n0kovo_subdomains" \
    "n0kovo's huge subdomain list"

# 3. Clone PayloadsAllTheThings - Web application security payloads
clone_repo \
    "https://github.com/swisskyrepo/PayloadsAllTheThings.git" \
    "PayloadsAllTheThings" \
    "PayloadsAllTheThings - Web security payloads"

# 4. Clone FuzzDB - Attack patterns and primitives
clone_repo \
    "https://github.com/fuzzdb-project/fuzzdb.git" \
    "fuzzdb" \
    "FuzzDB - Attack patterns and primitives"

# Create symbolic links for easy access
create_symlinks

echo -e "\n${GREEN}All repositories cloned successfully!${NC}"
echo -e "${YELLOW}Files saved in: $(pwd)${NC}"
echo ""

# Show repository structure
echo -e "${BLUE}Repository structure:${NC}"
ls -la

# Show linked files for quick access
echo -e "\n${BLUE}Quick access files (symlinks):${NC}"
ls -la *.txt 2>/dev/null || echo "No symlinked .txt files found"

echo -e "\n${YELLOW}Repository contents:${NC}"
echo -e "${GREEN}SecLists${NC} - Passwords, usernames, URLs, sensitive data patterns, fuzzing payloads"
echo -e "${GREEN}n0kovo_subdomains${NC} - Huge subdomain enumeration wordlist"
echo -e "${GREEN}PayloadsAllTheThings${NC} - Web application security testing payloads"
echo -e "${GREEN}fuzzdb${NC} - Attack patterns, fuzzing payloads, and web fault injection"

echo -e "\n${YELLOW}Update repositories with:${NC}"
echo "cd wordlists && find . -name '.git' -type d -execdir git pull \\;"

echo -e "\n${YELLOW}Note: These wordlists are for legitimate security testing purposes only.${NC}"
echo -e "${YELLOW}Always ensure you have proper authorization before using them.${NC}"