#!/bin/bash
# decrypt.sh - Hash identification and decryption script

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

decrypt_base64() {
    local input_string="$1"
    
    if [[ $input_string =~ ^[a-zA-Z0-9+/]+={0,2}$ ]]; then
        print_info "Attempting to decode as Base64..."
        if decoded_string=$(echo "$input_string" | base64 --decode 2>/dev/null); then
            if [[ -n "$decoded_string" && ! "$decoded_string" =~ [^[:print:][:space:]] ]]; then
                print_success "Base64 decoded: $decoded_string"
                return 0
            else
                print_warning "Base64 decoding failed or resulted in unreadable binary data."
                return 1
            fi
        else
            print_warning "Base64 decoding failed."
            return 1
        fi
    fi
    return 1
}

identify_hash() {
    local hash="$1"
    local hash_length=${#hash}
    
    case $hash_length in
        32)
            if [[ $hash =~ ^[a-f0-9]{32}$ ]]; then
                echo "0" # MD5
            fi
            ;;
        40)
            if [[ $hash =~ ^[a-f0-9]{40}$ ]]; then
                echo "100" # SHA1
            fi
            ;;
        56)
            if [[ $hash =~ ^[a-f0-9]{56}$ ]]; then
                echo "1400" # SHA224
            fi
            ;;
        64)
            if [[ $hash =~ ^[a-f0-9]{64}$ ]]; then
                echo "1400" # SHA256
            fi
            ;;
        96)
            if [[ $hash =~ ^[a-f0-9]{96}$ ]]; then
                echo "10800" # SHA384
            fi
            ;;
        128)
            if [[ $hash =~ ^[a-f0-9]{128}$ ]]; then
                echo "1700" # SHA512
            fi
            ;;
        *)
            if [[ $hash =~ ^\$1\$ ]]; then
                echo "500" # MD5crypt
            elif [[ $hash =~ ^\$2a\$|^\$2b\$|^\$2x\$|^\$2y\$ ]]; then
                echo "3200" # bcrypt
            elif [[ $hash =~ ^\$5\$ ]]; then
                echo "7400" # SHA256crypt
            elif [[ $hash =~ ^\$6\$ ]]; then
                echo "1800" # SHA512crypt
            elif [[ $hash =~ ^\$argon2 ]]; then
                echo "m" # Argon2 (requires different handling)
            elif [[ $hash =~ ^{SSHA} ]]; then
                echo "111" # SSHA
            elif [[ $hash =~ ^[a-f0-9]{16}:[a-f0-9]{32}$ ]]; then
                echo "10" # MD5 with salt
            elif [[ $hash =~ ^[a-f0-9]{40}:[a-f0-9]+$ ]]; then
                echo "110" # SHA1 with salt
            else
                echo "unknown"
            fi
            ;;
    esac
}

get_hash_description() {
    case $1 in
        0) echo "MD5" ;;
        100) echo "SHA1" ;;
        1400) echo "SHA256" ;;
        1700) echo "SHA512" ;;
        500) echo "MD5crypt" ;;
        3200) echo "bcrypt" ;;
        7400) echo "SHA256crypt" ;;
        1800) echo "SHA512crypt" ;;
        111) echo "SSHA" ;;
        10) echo "MD5 with salt" ;;
        110) echo "SHA1 with salt" ;;
        *) echo "Unknown" ;;
    esac
}

attempt_decrypt() {
    local hash="$1"
    local mode="$2"
    local wordlist="$3"
    local hash_file="/tmp/hash_to_crack.txt"
    local output_file="/tmp/cracked_output.txt"
    
    echo "$hash" > "$hash_file"
    
    print_info "Attempting to crack hash with mode $mode ($(get_hash_description $mode))"
    
    local hashcat_cmd="hashcat -m $mode -a 0 --potfile-disable --quiet --outfile=$output_file $hash_file $wordlist"
    
    if timeout 300 $hashcat_cmd 2>/dev/null; then
        if [[ -f "$output_file" && -s "$output_file" ]]; then
            local cracked=$(cat "$output_file")
            print_success "Hash cracked: $cracked"
            rm -f "$hash_file" "$output_file"
            return 0
        fi
    fi
    
    rm -f "$hash_file" "$output_file"
    return 1
}

main() {
    local hash_input="$1"
    local wordlist="${2:-/usr/share/wordlists/rockyou.txt}"
    
    if ! command -v hashcat &> /dev/null; then
        print_error "hashcat is not installed. Please install it first."
        exit 1
    fi

    if ! command -v base64 &> /dev/null; then
        print_error "base64 command is not available. Please install it (e.g., coreutils)."
        exit 1
    fi
    
    if [[ -z "$hash_input" ]]; then
        echo "Usage: $0 <hash_or_file> [wordlist]"
        echo "Examples:"
        echo "  $0 'c3VwZXJfc2VjcmV0'"
        echo "  $0 '5d41402abc4b2a76b9719d911017c592'"
        echo "  $0 hashes.txt"
        echo "  $0 hash.txt /path/to/custom_wordlist.txt"
        echo ""
        echo "Note: Script will automatically search for rockyou.txt in common locations:"
        echo "  ./rockyou.txt, ./wordlists/rockyou.txt, ../rockyou.txt, etc."
        exit 1
    fi
    
    if [[ ! -f "$wordlist" ]]; then
        print_warning "Wordlist not found: $wordlist"
        print_info "Falling back to built-in attack modes"
        wordlist=""
    fi
    
    print_info "Starting hash identification and decryption process"
    print_info "Wordlist: ${wordlist:-"Built-in attacks"}"
    
    local hashes=()
    if [[ -f "$hash_input" ]]; then
        print_info "Reading hashes from file: $hash_input"
        while IFS= read -r line; do
            [[ -n "$line" ]] && hashes+=("$line")
        done < "$hash_input"
    else
        hashes=("$hash_input")
    fi
    
    local total_hashes=${#hashes[@]}
    local cracked_count=0
    
    for i in "${!hashes[@]}"; do
        local hash="${hashes[$i]}"
        print_info "Processing hash $((i+1))/$total_hashes: ${hash:0:16}..."
        
        # Check for Base64 first
        if decrypt_base64 "$hash"; then
            ((cracked_count++))
            continue
        fi

        local hash_mode=$(identify_hash "$hash")
        
        if [[ "$hash_mode" == "unknown" ]]; then
            print_warning "Could not identify hash type for: ${hash:0:16}..."
            continue
        fi
        
        print_info "Identified as: $(get_hash_description "$hash_mode") (mode: $hash_mode)"
        
        if [[ -n "$wordlist" ]]; then
            if attempt_decrypt "$hash" "$hash_mode" "$wordlist"; then
                ((cracked_count++))
                continue
            fi
        fi
        
        print_info "Trying common passwords..."
        local common_passwords="/tmp/common_passwords.txt"
        cat > "$common_passwords" << 'EOF'
password
123456
12345678
qwerty
abc123
Password
admin
letmein
welcome
monkey
dragon
EOF
        
        if attempt_decrypt "$hash" "$hash_mode" "$common_passwords"; then
            ((cracked_count++))
        else
            print_warning "Could not crack hash: ${hash:0:16}..."
        fi
        
        rm -f "$common_passwords"
    done
    
    echo
    print_info "=== SUMMARY ==="
    print_info "Total strings processed: $total_hashes"
    print_success "Successfully cracked/decoded: $cracked_count"
    print_warning "Failed to crack/decode: $((total_hashes - cracked_count))"
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
