#!/usr/bin/env python3
"""
Pull v2.5 by l0calgh0st - Python port
Downloads a set of security wordlists (raw GitHub URLs).
"""

from __future__ import annotations
import os
import sys
import urllib.request
import urllib.error
import shutil
from typing import Optional, Tuple
from time import time

RED = '\033[0;31m'
GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
NC = '\033[0m'

WORDLIST_DIR = "wordlists"
CHUNK_SIZE = 32 * 1024


def human_readable_size(bytesize: int) -> str:
    if bytesize < 1024:
        return f"{bytesize} B"
    for unit in ("KB", "MB", "GB", "TB"):
        bytesize /= 1024.0
        if bytesize < 1024.0:
            return f"{bytesize:0.2f} {unit}"
    return f"{bytesize:.2f} PB"


def safe_mkdir(path: str) -> None:
    if not os.path.isdir(path):
        print(f"{YELLOW}Creating {path} directory...{NC}")
        os.makedirs(path, exist_ok=True)


def download_url(url: str, output_path: str, show_progress: bool = True, timeout: int = 30) -> bool:
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "python-wordlist-downloader/1.0"})
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            total = resp.getheader("Content-Length")
            total = int(total) if total and total.isdigit() else None

            start = time()
            downloaded = 0
            tmp_path = output_path + ".part"

            with open(tmp_path, "wb") as out_file:
                while True:
                    chunk = resp.read(CHUNK_SIZE)
                    if not chunk:
                        break
                    out_file.write(chunk)
                    downloaded += len(chunk)
                    if show_progress:
                        if total:
                            percent = downloaded / total * 100
                            print(f"\rDownloading {os.path.basename(output_path)} — {human_readable_size(downloaded)} / {human_readable_size(total)} ({percent:5.1f}%)", end="")
                        else:
                            print(f"\rDownloading {os.path.basename(output_path)} — {human_readable_size(downloaded)}", end="")
                            
                if show_progress:
                    print()
            shutil.move(tmp_path, output_path)
            elapsed = time() - start
            if total:
                rate = downloaded / elapsed if elapsed > 0 else downloaded
                print(f"  Saved {human_readable_size(downloaded)} ({downloaded} bytes) in {elapsed:.1f}s — {human_readable_size(int(rate))}/s")
            else:
                print(f"  Saved {human_readable_size(downloaded)} ({downloaded} bytes)")
        return True
    except urllib.error.HTTPError as e:
        print(f"\n{RED}HTTP Error {e.code} for {url}{NC}")
    except urllib.error.URLError as e:
        print(f"\n{RED}URL Error for {url}: {e.reason}{NC}")
    except Exception as e:
        print(f"\n{RED}Unexpected error while downloading {url}: {e}{NC}")

    try:
        part = output_path + ".part"
        if os.path.exists(part):
            os.remove(part)
    except Exception:
        pass
    return False


def download_from_github(github_repo: str, file_path: str, output_filename: str, description: str) -> bool:
    branches = ("main", "master")
    for branch in branches:
        raw_url = f"https://raw.githubusercontent.com/{github_repo}/{branch}/{file_path}"
        print(f"\n{YELLOW}Downloading {description}...{NC}")
        print(f"URL: {raw_url}")

        outpath = os.path.join(WORDLIST_DIR, output_filename)
        if download_url(raw_url, outpath):
            print(f"{GREEN}✓ Successfully downloaded {output_filename}{NC}")
            try:
                size = os.path.getsize(outpath)
                print(f"  File size: {human_readable_size(size)}")
            except Exception:
                pass
            return True
        else:
            print(f"{YELLOW}Trying branch '{branch}' failed, trying next branch if available...{NC}")
    print(f"{RED}✗ Failed to download {output_filename}{NC}")
    return False


def main() -> None:
    print(f"{YELLOW}Security Wordlists Downloader (Git Raw URLs){NC}")
    print("=============================================")

    safe_mkdir(WORDLIST_DIR)
    
    tasks = [
        ("n0kovo/n0kovo_subdomains", "n0kovo_subdomains_huge.txt", "n0kovo_subdomains_huge.txt", "n0kovo's huge subdomain list"),
        ("danielmiessler/SecLists", "Discovery/Web-Content/combined_directories.txt", "combined_directories.txt", "Combined Directories list"),
    ]

    for repo, path, outname, desc in tasks:

        download_from_github(repo, path, outname, desc)

    print(f"\n{YELLOW}Downloading RockYou password list...{NC}")
    rockyou_downloaded = False

    rockyou_sources = [
        ("brannondorsey/naive-hashcat", "master", "wordlists/rockyou.txt"),
        ("danielmiessler/SecLists", "master", "Passwords/Leaked-Databases/rockyou.txt"),
        ("danielmiessler/SecLists", "master", "Passwords/Leaked-Databases/rockyou-75.txt"),
    ]

    out_rock_path = os.path.join(WORDLIST_DIR, "rockyou.txt")
    for repo, branch, path in rockyou_sources:
        raw_url = f"https://raw.githubusercontent.com/{repo}/{branch}/{path}"
        print(f"Trying: {raw_url}")
        if download_url(raw_url, out_rock_path):
            print(f"{GREEN}✓ Successfully downloaded rockyou.txt{NC}")
            try:
                size = os.path.getsize(out_rock_path)
                print(f"  File size: {human_readable_size(size)}")
            except Exception:
                pass
            rockyou_downloaded = True
            break
        else:
            print(f"{RED}✗ Failed from this source{NC}")

    if not rockyou_downloaded:
        print(f"{RED}✗ Could not download rockyou.txt from any source{NC}")

    print(f"\n{GREEN}Download process completed!{NC}")
    print(f"{YELLOW}Files saved in: {os.path.abspath(WORDLIST_DIR)}{NC}\n")

    print("Downloaded files:")
    try:
        txts = [f for f in os.listdir(WORDLIST_DIR) if f.lower().endswith(".txt")]
        if txts:
            for f in sorted(txts):
                full = os.path.join(WORDLIST_DIR, f)
                try:
                    print(f" - {f} ({human_readable_size(os.path.getsize(full))})")
                except Exception:
                    print(f" - {f}")
        else:
            print(" No .txt files found")
    except FileNotFoundError:
        print(" No .txt files found")

    print(f"\n{YELLOW}Note: These wordlists are for legitimate security testing purposes only.{NC}")
    print(f"{YELLOW}Always ensure you have proper authorization before using them.{NC}")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print(f"\n{RED}Interrupted by user{NC}")
        sys.exit(1)
