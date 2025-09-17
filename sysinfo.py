#!/usr/bin/env python3
"""
Python port of:
Linux System Information Gathering Script by l0calgh0st

Saves outputs to /tmp/sysinfo_<YYYYMMDD_HHMMSS>_<RAND>/
"""

from __future__ import annotations
import os
import sys
import subprocess
import shlex
import time
import random
from datetime import datetime
from typing import List, Tuple

# Config
TMP_BASE = "/tmp"
TIMEOUT = 60  # seconds per command (adjust if you expect long-running commands)
OUTPUT_DIR = os.path.join(
    TMP_BASE,
    f"sysinfo_{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}_{random.randint(1000,9999)}",
)


def ensure_tmp_exists() -> None:
    if not os.path.isdir(TMP_BASE):
        print(f"Error: {TMP_BASE} directory not found. Exiting.")
        sys.exit(1)


def make_output_dir(path: str) -> None:
    os.makedirs(path, exist_ok=True)


def write_header(filename: str, title: str, cmd: str) -> None:
    header = []
    header.append(f"Gathering: {title}")
    header.append(f"Command: {cmd}")
    header.append("=" * 43)
    with open(filename, "a", encoding="utf-8", errors="ignore") as fh:
        fh.write("\n".join(header) + "\n")


def run_cmd_save(cmd: str, outpath: str, description: str, timeout: int = TIMEOUT) -> None:
    """
    Run command string through shell, append output (stdout+stderr) to outpath file.
    Non-fatal on failure; writes error info to file.
    """
    # Ensure out directory exists
    os.makedirs(os.path.dirname(outpath), exist_ok=True)
    write_header(outpath, description, cmd)

    try:
        # Use shell to preserve compound commands like `cat /etc/shadow` or `find ... -exec cat {} \;`
        completed = subprocess.run(
            cmd,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout,
            check=False,
            text=True,
            errors="ignore",
        )
        with open(outpath, "a", encoding="utf-8", errors="ignore") as fh:
            fh.write(completed.stdout or "")
            fh.write("\n\n")
    except subprocess.TimeoutExpired as e:
        with open(outpath, "a", encoding="utf-8", errors="ignore") as fh:
            fh.write(f"\n[ERROR] Command timed out after {timeout} seconds.\n")
            if e.stdout:
                fh.write(e.stdout)
            fh.write("\n\n")
    except Exception as e:
        with open(outpath, "a", encoding="utf-8", errors="ignore") as fh:
            fh.write(f"\n[ERROR] Unexpected error running command: {e}\n\n")


def generate_summary(output_dir: str) -> None:
    summary_path = os.path.join(output_dir, "00_SUMMARY.txt")
    try:
        pretty_os = ""
        try:
            # Try reading PRETTY_NAME from /etc/os-release
            with open("/etc/os-release", "r", encoding="utf-8", errors="ignore") as f:
                for line in f:
                    if line.startswith("PRETTY_NAME="):
                        pretty_os = line.split("=", 1)[1].strip().strip('"')
                        break
        except Exception:
            pretty_os = ""

        lines = []
        lines.append("=== SYSTEM INFORMATION SUMMARY ===")
        lines.append(f"Generated: {datetime.utcnow().isoformat()} UTC")
        lines.append(f"Hostname: {subprocess.getoutput('hostname')}")
        lines.append(f"OS: {pretty_os or subprocess.getoutput('uname -s')}")
        lines.append(f"Kernel: {subprocess.getoutput('uname -r')}")
        lines.append(f"Architecture: {subprocess.getoutput('uname -m')}")
        lines.append(f"Current User: {subprocess.getoutput('whoami')}")
        lines.append(f"User ID: {subprocess.getoutput('id')}")
        lines.append("")
        lines.append("=== FILES GENERATED ===")
        try:
            for ent in sorted(os.listdir(output_dir)):
                full = os.path.join(output_dir, ent)
                try:
                    size = os.path.getsize(full)
                    lines.append(f"{ent} - {size} bytes")
                except Exception:
                    lines.append(ent)
        except Exception as e:
            lines.append(f"[ERROR enumerating files: {e}]")

        with open(summary_path, "w", encoding="utf-8", errors="ignore") as fh:
            fh.write("\n".join(lines))
    except Exception as e:
        print(f"Failed to write summary: {e}")


def main() -> None:
    ensure_tmp_exists()
    make_output_dir(OUTPUT_DIR)

    print("=== Linux System Information Gathering ===")
    print(f"Output directory: {OUTPUT_DIR}")
    print(f"Started: {datetime.now().isoformat()}")
    print()

    # commands grouped by target file (mimicking your original script)
    # Each entry: (command_string, out_filename, description)
    cmds: List[Tuple[str, str, str]] = [
        ("uname -a", "01_system_info.txt", "Kernel and system information"),
        ("cat /etc/os-release", "01_system_info.txt", "OS release information"),
        ("hostnamectl", "01_system_info.txt", "Host information"),
        ("uptime", "01_system_info.txt", "System uptime"),

        ("lscpu", "02_hardware.txt", "CPU information"),
        ("free -h", "02_hardware.txt", "Memory information"),
        ("df -h", "02_hardware.txt", "Disk usage"),
        ("lsblk", "02_hardware.txt", "Block devices"),
        ("lspci", "02_hardware.txt", "PCI devices"),
        ("lsusb", "02_hardware.txt", "USB devices"),

        ("ip addr show", "03_network.txt", "Network interfaces"),
        ("ip route show", "03_network.txt", "Routing table"),
        ("netstat -tuln", "03_network.txt", "Listening ports"),
        ("ss -tuln", "03_network.txt", "Socket statistics"),
        ("arp -a", "03_network.txt", "ARP table"),

        ("cat /etc/passwd", "04_users.txt", "User accounts"),
        ("cat /etc/group", "04_users.txt", "Groups"),
        ("w", "04_users.txt", "Currently logged in users"),
        ("last -10", "04_users.txt", "Recent logins"),
        ("id", "04_users.txt", "Current user ID"),

        ("ps aux", "05_processes.txt", "Running processes"),
        ("systemctl list-units --type=service --state=running", "05_processes.txt", "Running services"),
        ("systemctl list-units --type=service --state=enabled", "05_processes.txt", "Enabled services"),
        ("crontab -l", "05_processes.txt", "User cron jobs"),
        ("cat /etc/crontab", "05_processes.txt", "System cron jobs"),

        ("cat /etc/sudoers", "06_security.txt", "Sudoers configuration"),
        ("find /etc/sudoers.d/ -type f -exec cat {} \\;", "06_security.txt", "Sudoers.d files"),
        ("cat /etc/shadow", "06_security.txt", "Password hashes (if accessible)"),
        ("find / -perm -4000 -type f 2>/dev/null", "06_security.txt", "SUID files"),
        ("find / -perm -2000 -type f 2>/dev/null", "06_security.txt", "SGID files"),
        ("getcap -r / 2>/dev/null", "06_security.txt", "Files with capabilities"),

        ("dpkg -l", "07_software.txt", "Installed packages (Debian/Ubuntu)"),
        ("rpm -qa", "07_software.txt", "Installed packages (RedHat/CentOS)"),
        ("which gcc g++ python python3 perl ruby php java javac", "07_software.txt", "Development tools"),

        ("env", "08_environment.txt", "Environment variables"),
        ("cat /etc/hosts", "08_environment.txt", "Hosts file"),
        ("cat /etc/resolv.conf", "08_environment.txt", "DNS configuration"),
        ("mount", "08_environment.txt", "Mounted filesystems"),

        ("tail -50 /var/log/auth.log", "09_logs.txt", "Authentication logs"),
        ("tail -50 /var/log/syslog", "09_logs.txt", "System logs"),
        ("tail -50 /var/log/messages", "09_logs.txt", "System messages"),
        ("journalctl --no-pager -n 50", "09_logs.txt", "Recent journal entries"),

        ("find /home -name '.*' -type f 2>/dev/null | head -20", "10_interesting.txt", "Hidden files in home directories"),
        ("find /tmp -type f 2>/dev/null | head -20", "10_interesting.txt", "Files in /tmp"),
        ("find /var/tmp -type f 2>/dev/null | head -20", "10_interesting.txt", "Files in /var/tmp"),
        ("find /opt -type f 2>/dev/null | head -20", "10_interesting.txt", "Files in /opt"),

        ("cat ~/.bash_history", "11_history.txt", "Bash history"),
        ("cat ~/.zsh_history", "11_history.txt", "Zsh history"),
        ("find /home -name '.*history' -exec cat {} \\; 2>/dev/null", "11_history.txt", "All history files"),
    ]

    # Run everything sequentially
    for cmd, fname, desc in cmds:
        outpath = os.path.join(OUTPUT_DIR, fname)
        print(f"Gathering: {desc}")
        run_cmd_save(cmd, outpath, desc)

    # Write summary file
    generate_summary(OUTPUT_DIR)

    print()
    print("=== Information Gathering Complete ===")
    print(f"Results saved to: {OUTPUT_DIR}")
    print(f"Summary available in: {os.path.join(OUTPUT_DIR, '00_SUMMARY.txt')}")
    print()
    print("Note: Some commands may fail due to permissions or missing tools.")
    print("Review all output files for useful information.")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nInterrupted by user.")
        sys.exit(1)
