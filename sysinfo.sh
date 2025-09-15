#!/bin/bash
# Linux System Information Gathering Script
# For authorized penetration testing purposes only
# Usage: ./sysinfo.sh

# Check if /tmp exists and is a directory
if [ ! -d "/tmp" ]; then
    echo "Error: /tmp directory not found. Exiting."
    exit 1
fi

# Use RANDOM to generate a unique folder name in /tmp
OUTPUT_DIR="/tmp/sysinfo_$(date +%Y%m%d_%H%M%S)_$RANDOM"

# Create the output directory
mkdir -p "$OUTPUT_DIR"

echo "=== Linux System Information Gathering ==="
echo "Output directory: $OUTPUT_DIR"
echo "Started: $(date)"
echo

# Function to run command and save output
run_cmd() {
    local cmd="$1"
    local output_file="$2"
    local description="$3"

    echo "Gathering: $description"
    echo "Command: $cmd" > "$OUTPUT_DIR/$output_file"
    echo "===========================================" >> "$OUTPUT_DIR/$output_file"
    eval "$cmd" >> "$OUTPUT_DIR/$output_file" 2>&1
    echo >> "$OUTPUT_DIR/$output_file"
}

# Basic System Information
run_cmd "uname -a" "01_system_info.txt" "Kernel and system information"
run_cmd "cat /etc/os-release" "01_system_info.txt" "OS release information"
run_cmd "hostnamectl" "01_system_info.txt" "Host information"
run_cmd "uptime" "01_system_info.txt" "System uptime"

# Hardware Information
run_cmd "lscpu" "02_hardware.txt" "CPU information"
run_cmd "free -h" "02_hardware.txt" "Memory information"
run_cmd "df -h" "02_hardware.txt" "Disk usage"
run_cmd "lsblk" "02_hardware.txt" "Block devices"
run_cmd "lspci" "02_hardware.txt" "PCI devices"
run_cmd "lsusb" "02_hardware.txt" "USB devices"

# Network Information
run_cmd "ip addr show" "03_network.txt" "Network interfaces"
run_cmd "ip route show" "03_network.txt" "Routing table"
run_cmd "netstat -tuln" "03_network.txt" "Listening ports"
run_cmd "ss -tuln" "03_network.txt" "Socket statistics"
run_cmd "arp -a" "03_network.txt" "ARP table"

# Users and Groups
run_cmd "cat /etc/passwd" "04_users.txt" "User accounts"
run_cmd "cat /etc/group" "04_users.txt" "Groups"
run_cmd "w" "04_users.txt" "Currently logged in users"
run_cmd "last -10" "04_users.txt" "Recent logins"
run_cmd "id" "04_users.txt" "Current user ID"

# Processes and Services
run_cmd "ps aux" "05_processes.txt" "Running processes"
run_cmd "systemctl list-units --type=service --state=running" "05_processes.txt" "Running services"
run_cmd "systemctl list-units --type=service --state=enabled" "05_processes.txt" "Enabled services"
run_cmd "crontab -l" "05_processes.txt" "User cron jobs"
run_cmd "cat /etc/crontab" "05_processes.txt" "System cron jobs"

# Security Information
run_cmd "cat /etc/sudoers" "06_security.txt" "Sudoers configuration"
run_cmd "find /etc/sudoers.d/ -type f -exec cat {} \;" "06_security.txt" "Sudoers.d files"
run_cmd "cat /etc/shadow" "06_security.txt" "Password hashes (if accessible)"
run_cmd "find / -perm -4000 -type f 2>/dev/null" "06_security.txt" "SUID files"
run_cmd "find / -perm -2000 -type f 2>/dev/null" "06_security.txt" "SGID files"
run_cmd "getcap -r / 2>/dev/null" "06_security.txt" "Files with capabilities"

# Installed Software
run_cmd "dpkg -l" "07_software.txt" "Installed packages (Debian/Ubuntu)"
run_cmd "rpm -qa" "07_software.txt" "Installed packages (RedHat/CentOS)"
run_cmd "which gcc g++ python python3 perl ruby php java javac" "07_software.txt" "Development tools"

# Environment and Configuration
run_cmd "env" "08_environment.txt" "Environment variables"
run_cmd "cat /etc/hosts" "08_environment.txt" "Hosts file"
run_cmd "cat /etc/resolv.conf" "08_environment.txt" "DNS configuration"
run_cmd "mount" "08_environment.txt" "Mounted filesystems"

# Log Files (recent entries)
run_cmd "tail -50 /var/log/auth.log" "09_logs.txt" "Authentication logs"
run_cmd "tail -50 /var/log/syslog" "09_logs.txt" "System logs"
run_cmd "tail -50 /var/log/messages" "09_logs.txt" "System messages"
run_cmd "journalctl --no-pager -n 50" "09_logs.txt" "Recent journal entries"

# Interesting Files and Directories
run_cmd "find /home -name '.*' -type f 2>/dev/null | head -20" "10_interesting.txt" "Hidden files in home directories"
run_cmd "find /tmp -type f 2>/dev/null | head -20" "10_interesting.txt" "Files in /tmp"
run_cmd "find /var/tmp -type f 2>/dev/null | head -20" "10_interesting.txt" "Files in /var/tmp"
run_cmd "find /opt -type f 2>/dev/null | head -20" "10_interesting.txt" "Files in /opt"

# History Files
run_cmd "cat ~/.bash_history" "11_history.txt" "Bash history"
run_cmd "cat ~/.zsh_history" "11_history.txt" "Zsh history"
run_cmd "find /home -name '.*history' -exec cat {} \; 2>/dev/null" "11_history.txt" "All history files"

# Create summary file
{
    echo "=== SYSTEM INFORMATION SUMMARY ==="
    echo "Generated: $(date)"
    echo "Hostname: $(hostname)"
    echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2 2>/dev/null || uname -s)"
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo "Current User: $(whoami)"
    echo "User ID: $(id)"
    echo
    echo "=== FILES GENERATED ==="
    ls -la "$OUTPUT_DIR"
} > "$OUTPUT_DIR/00_SUMMARY.txt"

echo
echo "=== Information Gathering Complete ==="
echo "Results saved to: $OUTPUT_DIR"
echo "Summary available in: $OUTPUT_DIR/00_SUMMARY.txt"
echo
echo "Note: Some commands may fail due to permissions or missing tools."
echo "Review all output files for useful information."