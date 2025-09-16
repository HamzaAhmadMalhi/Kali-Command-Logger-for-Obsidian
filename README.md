# Kali Command Logger for Obsidian

A sophisticated Bash script that automatically logs penetration testing commands to an Obsidian vault with screenshots, timestamps, and full session recording capabilities.

## Requirments
Need Obsidian installed on Kali Linux: https://obsidian.md/download

## Features

### Core Functionality
- **Success-only logging**: Only saves commands that execute successfully (exit code 0)
- **Real-time output**: Shows command output in terminal AND saves to Obsidian
- **Daily organization**: Creates daily markdown files with timestamps
- **Error handling**: Displays errors but doesn't log failed commands
- **Obsidian integration**: Properly formatted markdown with embedded images

### Advanced Features
- **Optional screenshots**: Use `-ss` flag to capture screen with commands
- **Interactive session logging**: Records entire sessions (evil-winrm, SSH, reverse shells)
- **Active mode**: Run multiple commands without typing 'klog' each time
- **Vault management**: Change Obsidian vault path on the fly
- **ANSI cleanup**: Removes terminal escape codes for clean logs

## Installation

### Quick Install (Recommended)
```bash
git clone https://github.com/HamzaAhmadMalhi/Kali-Command-Logger-for-Obsidian.git
cd kali-obsidian-logger
chmod +x setup.sh
./setup.sh
```

### Manual Install
```bash
# Install dependencies
sudo apt install -y scrot imagemagick

# Download and install klog
sudo wget -O /usr/local/bin/klog https://github.com/HamzaAhmadMalhi/Kali-Command-Logger-for-Obsidian.git/main/klog
sudo chmod +x /usr/local/bin/klog

# Configure vault path
sudo nano /usr/local/bin/klog
# Edit line 4: OBSIDIAN_VAULT="/path/to/your/vault"
```

## Usage

### Basic Commands
```bash
# Simple command logging
klog whoami
klog nmap -sV 192.168.1.1

# With screenshot
klog -ss gobuster dir -u http://target.com -w /usr/share/wordlists/dirb/common.txt

# Complex commands (use quotes)
klog 'ls -la && whoami && id'
```

### Session Logging (Perfect for OSCP!)
```bash
# Log entire interactive sessions
klog -session "evil-winrm-target" evil-winrm -u admin -p 'password' -i 192.168.1.100
klog -session "ssh-server" ssh user@192.168.1.50
klog -session "reverse-shell" nc -lvnp 4444

# With screenshots
klog -ss -session "domain-controller" evil-winrm -u administrator -p 'P@ssw0rd' -i 192.168.1.10
```

### Active Mode
```bash
# Enter interactive mode
klog -A
# Then type commands without 'klog' prefix:
# klog> nmap -sV 192.168.1.1
# klog> whoami
# klog> exit

# Active mode with screenshots
klog -A -ss
```

### Configuration
```bash
# Change vault path
klog -cv

# Get help
klog --help
```

## Output Structure

```
ObsidianVault/
├── Command_Logs/
│   ├── 2025-09-15_commands.md
│   └── 2025-09-16_commands.md
├── Screenshots/
│   ├── cmd_20250915_143022.png
│   └── session_evil-winrm_20250915_143145.png
└── Sessions/
    ├── evil-winrm-target_20250915_143022.log
    └── evil-winrm-target_20250915_143022_clean.log
```

## Example Output

### Command Log in Obsidian
```markdown
# Command Log - 2025-09-15

## Commands Executed

### 2025-09-15 14:30:22

**Command:** `nmap -sV 192.168.1.100`

**Output:**
```
Starting Nmap 7.94 ( https://nmap.org ) at 2025-09-15 14:30 EDT
Nmap scan report for 192.168.1.100
Host is up (0.0012s latency).
PORT     STATE SERVICE VERSION
22/tcp   open  ssh     OpenSSH 8.9p1
80/tcp   open  http    Apache httpd 2.4.52
```

**Screenshot:** ![[Screenshots/cmd_20250915_143022.png]]

---

### 2025-09-15 14:35:45

**Interactive Session:** `evil-winrm-target`

**Initial Command:** `evil-winrm -u administrator -p P@ssw0rd -i 192.168.1.100`

**Session Log:**
```
Evil-WinRM shell v3.7
*Evil-WinRM* PS C:\Users\Administrator> whoami /all
USER INFORMATION
----------------
User Name                     SID
============================= =============================
target\administrator         S-1-5-21-123456789-1234567890

*Evil-WinRM* PS C:\Users\Administrator> dir C:\Users\Administrator\Desktop
proof.txt

*Evil-WinRM* PS C:\Users\Administrator> type proof.txt
OSCP{your_flag_here}
```

**Full Session File:** `/Sessions/evil-winrm-target_20250915_143545.log`

**Screenshot:** ![[Screenshots/session_evil-winrm-target_20250915_143545.png]]

---
```

## OSCP Use Cases

### Perfect for Penetration Testing Documentation

1. **Initial Reconnaissance**
   ```bash
   klog -ss nmap -sV -sC 192.168.1.0/24
   klog gobuster dir -u http://192.168.1.100 -w /usr/share/wordlists/dirb/common.txt
   ```

2. **Exploitation**
   ```bash
   klog -ss searchsploit apache 2.4.52
   klog python3 exploit.py 192.168.1.100
   ```

3. **Post-Exploitation**
   ```bash
   klog -session "target-shell" evil-winrm -u administrator -p 'password' -i 192.168.1.100
   ```
   Then inside the session:
   ```
   whoami /all
   systeminfo
   dir C:\Users\Administrator\Desktop
   type proof.txt
   ```

4. **Privilege Escalation**
   ```bash
   klog -session "privesc" ssh user@192.168.1.100
   ```
   Then inside:
   ```
   sudo -l
   find / -perm -4000 2>/dev/null
   cat /root/proof.txt
   ```

## Configuration Options

### Command Line Options
```
-h, --help            Show help message
-cv, --change-vault   Change Obsidian vault path
-A, --active          Enter active mode (interactive shell)
-ss, --screenshot     Take a screenshot with the command
-session <n>       Log entire interactive session
```

### Default Settings
- **Vault Path**: `/home/$(whoami)/Documents/cmd_notes`
- **Screenshots**: Disabled by default (use `-ss` to enable)
- **Screenshot Tools**: `scrot` > `gnome-screenshot` > `imagemagick`
- **Session Logging**: Full terminal capture with ANSI cleanup

## Requirements

- **Operating System**: Kali Linux (or any Debian-based system)
- **Screenshot Tools**: `scrot`, `gnome-screenshot`, or `imagemagick`
- **Session Logging**: `script` command (pre-installed on most Linux systems)
- **Obsidian**: Local vault directory (Obsidian app not required for logging)

## Troubleshooting

### Common Issues

**Command not found:**
```bash
which klog
# If missing:
sudo chmod +x /usr/local/bin/klog
```

**No screenshots:**
```bash
sudo apt install -y scrot imagemagick
```

**Session logging fails:**
```bash
# For commands with special characters, use quotes:
klog -session "target" "evil-winrm -u admin -p 'P@ssw0rd!' -i 192.168.1.100"
```

**Permission errors:**
```bash
# Check vault permissions
ls -la /path/to/your/vault
mkdir -p /path/to/your/vault
```

**Special characters in passwords:**
```bash
# Method 1: Use environment variable
export PASS='P@ssw0rd!'
klog -session "target" evil-winrm -u admin -p "$PASS" -i 192.168.1.100

# Method 2: Double quotes around entire command
klog -session "target" "evil-winrm -u admin -p 'P@ssw0rd!' -i 192.168.1.100"
```

## Changelog

### v1.0.0 (Current)
- ✅ Basic command logging with success-only filtering
- ✅ Optional screenshot capture with `-ss` flag
- ✅ Interactive session logging with `-session`
- ✅ Active mode for continuous logging
- ✅ Vault path management
- ✅ ANSI escape code cleanup
- ✅ Obsidian-formatted markdown output
- ✅ Daily log organization
- ✅ Error handling and validation

## Acknowledgments

- **Obsidian**: For the amazing note-taking platform
- **Evil-WinRM**: For Windows remote management
- **OSCP Community**: For inspiration and testing scenarios
