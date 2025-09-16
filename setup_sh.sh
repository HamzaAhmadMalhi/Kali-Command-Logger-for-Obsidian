#!/bin/bash

# Setup script for Kali Command Logger

echo "=== Kali Command Logger Setup ==="

# Check for required tools and install if needed
echo "Checking for required tools..."

# Check if scrot is installed
if ! command -v scrot >/dev/null 2>&1; then
    echo "Installing scrot..."
    sudo apt install -y scrot
else
    echo "✓ scrot already installed"
fi

# Check if imagemagick is installed
if ! command -v import >/dev/null 2>&1; then
    echo "Installing imagemagick..."
    sudo apt install -y imagemagick
else
    echo "✓ imagemagick already installed"
fi

# Create main script directory
SCRIPT_DIR="/usr/local/bin"
SCRIPT_NAME="klog"

# Get Obsidian vault path from user
echo ""
read -p "Enter your Obsidian vault path (default: /home/$(whoami)/Documents/cmd_notes): " VAULT_PATH
VAULT_PATH=${VAULT_PATH:-"/home/$(whoami)/Documents/cmd_notes"}

# Create vault directory if it doesn't exist
if [[ ! -d "$VAULT_PATH" ]]; then
    echo "Creating Obsidian vault directory: $VAULT_PATH"
    mkdir -p "$VAULT_PATH"
fi

# Create the main script directly
echo "Setting up command logger..."
cat > /tmp/klog << 'EOF'
#!/bin/bash

# Kali Command Logger for Obsidian
OBSIDIAN_VAULT="VAULT_PATH_PLACEHOLDER"
NOTES_DIR="$OBSIDIAN_VAULT/Command_Logs"
SCREENSHOTS_DIR="$OBSIDIAN_VAULT/Screenshots"
DAILY_NOTE="$NOTES_DIR/$(date +%Y-%m-%d)_commands.md"

# Global flags
TAKE_SCREENSHOT=false
SESSION_MODE=false
SESSION_NAME=""

# Function to show help
show_help() {
    cat << EOFHELP
Kali Command Logger for Obsidian

USAGE:
    klog [OPTIONS] <command>
    klog [OPTIONS]

OPTIONS:
    -h, --help            Show this help message
    -cv, --change-vault   Change Obsidian vault path
    -A, --active          Enter active mode (interactive shell)
    -ss, --screenshot     Take a screenshot with the command
    -session <name>       Log entire interactive session (evil-winrm, ssh, etc.)

EXAMPLES:
    klog nmap -sV 192.168.1.1
    klog -ss 'ls -la && whoami'              # With screenshot
    klog gobuster dir -u http://target.com -w /usr/share/wordlists/dirb/common.txt
    
    # Session logging (logs entire interactive session)
    klog -session "evil-winrm-target" evil-winrm -u admin -p 'pass' -i 192.168.1.100
    klog -session "ssh-target" ssh user@192.168.1.50
    klog -session "nc-shell" nc -lvnp 4444
    
    klog -cv                    # Change vault path
    klog -A                     # Enter active mode
    klog -A -ss                 # Active mode with screenshots enabled
    klog --help                 # Show this help

ACTIVE MODE:
    In active mode, you can run commands without typing 'klog' each time.
    Type 'exit' or 'quit' to leave active mode.
    Use -ss flag to enable screenshots for all commands in active mode.

SESSION MODE:
    Session mode logs the entire interactive session using 'script' command.
    Perfect for evil-winrm, SSH, reverse shells, etc.
    All commands typed in the session will be captured and logged.

FILES:
    Logs: $OBSIDIAN_VAULT/Command_Logs/
    Screenshots: $OBSIDIAN_VAULT/Screenshots/
    Sessions: $OBSIDIAN_VAULT/Sessions/
    
NOTES:
    - Only successful commands (exit code 0) are logged
    - Screenshots are taken only when -ss flag is used
    - Session mode captures ALL interactive commands
    - Output is shown in terminal AND saved to Obsidian
EOFHELP
}

# Function to change vault path
change_vault() {
    echo "Current vault path: $OBSIDIAN_VAULT"
    echo ""
    read -p "Enter new Obsidian vault path: " NEW_VAULT
    
    if [[ -n "$NEW_VAULT" ]]; then
        # Update the script file with new path
        sudo sed -i "s|^OBSIDIAN_VAULT=.*|OBSIDIAN_VAULT=\"$NEW_VAULT\"|" /usr/local/bin/klog
        echo "✓ Vault path updated to: $NEW_VAULT"
        echo "✓ Please run klog again to use the new path"
    else
        echo "✗ No path provided, keeping current vault"
    fi
}

# Function for active mode
active_mode() {
    local screenshot_status=""
    if [[ "$TAKE_SCREENSHOT" == "true" ]]; then
        screenshot_status=" (Screenshots: ON)"
    else
        screenshot_status=" (Screenshots: OFF)"
    fi
    
    echo "=== Klog Active Mode$screenshot_status ==="
    echo "Current vault: $OBSIDIAN_VAULT"
    echo "Type commands normally (without 'klog')"
    echo "Type 'exit' or 'quit' to leave active mode"
    echo "=================================="
    
    while true; do
        echo -n "klog> "
        read -r user_input
        
        # Check for exit commands
        if [[ "$user_input" == "exit" || "$user_input" == "quit" || "$user_input" == "q" ]]; then
            echo "Exiting active mode..."
            break
        fi
        
        # Skip empty input
        if [[ -z "$user_input" ]]; then
            continue
        fi
        
        # Run the command through our logging function
        run_and_log "$user_input"
    done
}

# Function for session mode
session_mode() {
    local session_name="$1"
    shift
    local command="$*"
    
    # Create sessions directory
    local sessions_dir="$OBSIDIAN_VAULT/Sessions"
    mkdir -p "$sessions_dir"
    
    # Generate session filename (replace spaces with underscores)
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local safe_session_name=$(echo "$session_name" | tr ' ' '_')
    local session_file="$sessions_dir/${safe_session_name}_${timestamp}.log"
    local clean_session_file="$sessions_dir/${safe_session_name}_${timestamp}_clean.log"
    
    echo "=== Starting Session Logging ==="
    echo "Session: $session_name"
    echo "Command: $command"
    echo "Log file: $session_file"
    echo "Type 'exit' in the session to stop logging"
    echo "==============================="
    
    # Take screenshot at start if requested
    local screenshot_path=""
    if [[ "$TAKE_SCREENSHOT" == "true" ]]; then
        local screenshot_name="session_${safe_session_name}_${timestamp}.png"
        screenshot_path="$SCREENSHOTS_DIR/$screenshot_name"
        
        if command -v scrot >/dev/null 2>&1; then
            scrot "$screenshot_path" 2>/dev/null
        elif command -v gnome-screenshot >/dev/null 2>&1; then
            gnome-screenshot -f "$screenshot_path" 2>/dev/null
        elif command -v import >/dev/null 2>&1; then
            import -window root "$screenshot_path" 2>/dev/null
        fi
    fi
    
    # Create a temporary script file to handle complex commands properly
    local temp_script=$(mktemp)
    cat > "$temp_script" << EOFSCRIPT
#!/bin/bash
exec $command
EOFSCRIPT
    chmod +x "$temp_script"
    
    # Use script command to log the entire session
    script -f "$session_file" -c "$temp_script"
    local exit_code=$?
    
    # Clean up temp script
    rm -f "$temp_script"
    
    # Clean up the session log (remove ANSI escape codes)
    if command -v col >/dev/null 2>&1; then
        col -bp < "$session_file" > "$clean_session_file" 2>/dev/null
    else
        # Fallback: simple sed to remove basic ANSI codes
        sed 's/\x1b\[[0-9;]*m//g' "$session_file" > "$clean_session_file"
    fi
    
    echo ""
    echo "=== Session Ended ==="
    
    # Log the session to Obsidian
    if [[ $exit_code -eq 0 ]] || [[ -s "$clean_session_file" ]]; then
        log_session "$session_name" "$command" "$clean_session_file" "$screenshot_path"
        echo "✓ Session logged successfully to Obsidian"
    else
        echo "✗ Session failed or empty - not logged to Obsidian"
    fi
}

# Create directories if they don't exist
mkdir -p "$NOTES_DIR"
mkdir -p "$SCREENSHOTS_DIR"

log_command() {
    local command="$1"
    local output="$2"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local screenshot_name="cmd_$(date +%Y%m%d_%H%M%S).png"
    local screenshot_path="$SCREENSHOTS_DIR/$screenshot_name"
    local screenshot_taken=false
    
    # Take screenshot only if flag is set
    if [[ "$TAKE_SCREENSHOT" == "true" ]]; then
        if command -v scrot >/dev/null 2>&1; then
            scrot "$screenshot_path" 2>/dev/null && screenshot_taken=true
        elif command -v gnome-screenshot >/dev/null 2>&1; then
            gnome-screenshot -f "$screenshot_path" 2>/dev/null && screenshot_taken=true
        elif command -v import >/dev/null 2>&1; then
            import -window root "$screenshot_path" 2>/dev/null && screenshot_taken=true
        else
            echo "Warning: No screenshot tool found (scrot, gnome-screenshot, or ImageMagick)"
        fi
    fi
    
    # Create daily note if it doesn't exist
    if [[ ! -f "$DAILY_NOTE" ]]; then
        cat > "$DAILY_NOTE" << EOFNOTE
# Command Log - $(date +%Y-%m-%d)

## Commands Executed

EOFNOTE
    fi
    
    # Append command log entry
    cat >> "$DAILY_NOTE" << EOFLOG
### $timestamp

**Command:** \`$command\`

**Output:**
\`\`\`
$output
\`\`\`

EOFLOG
    
    # Add screenshot link if available and taken
    if [[ "$screenshot_taken" == "true" && -f "$screenshot_path" ]]; then
        echo "**Screenshot:** ![[Screenshots/$screenshot_name]]" >> "$DAILY_NOTE"
        echo "" >> "$DAILY_NOTE"
    fi
    
    echo "---" >> "$DAILY_NOTE"
    echo "" >> "$DAILY_NOTE"
}

log_session() {
    local session_name="$1"
    local command="$2"
    local session_file="$3"
    local screenshot_path="$4"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    # Read session content (limit to reasonable size)
    local session_content=""
    if [[ -f "$session_file" ]]; then
        # Limit to last 500 lines to avoid huge logs
        session_content=$(tail -500 "$session_file")
    fi
    
    # Create daily note if it doesn't exist
    if [[ ! -f "$DAILY_NOTE" ]]; then
        cat > "$DAILY_NOTE" << EOFNOTE
# Command Log - $(date +%Y-%m-%d)

## Commands Executed

EOFNOTE
    fi
    
    # Append session log entry
    cat >> "$DAILY_NOTE" << EOFLOG
### $timestamp

**Interactive Session:** \`$session_name\`

**Initial Command:** \`$command\`

**Session Log:**
\`\`\`
$session_content
\`\`\`

**Full Session File:** \`$session_file\`

EOFLOG
    
    # Add screenshot link if available
    if [[ -n "$screenshot_path" && -f "$screenshot_path" ]]; then
        local screenshot_name=$(basename "$screenshot_path")
        echo "**Screenshot:** ![[Screenshots/$screenshot_name]]" >> "$DAILY_NOTE"
        echo "" >> "$DAILY_NOTE"
    fi
    
    echo "---" >> "$DAILY_NOTE"
    echo "" >> "$DAILY_NOTE"
}

run_and_log() {
    local command="$*"
    local temp_output=$(mktemp)
    local temp_error=$(mktemp)
    
    # Run command and capture both stdout and stderr
    eval "$command" > "$temp_output" 2> "$temp_error"
    local exit_code=$?
    
    # Combine output and error
    local full_output=""
    if [[ -s "$temp_output" ]]; then
        full_output+=$(cat "$temp_output")
    fi
    if [[ -s "$temp_error" ]]; then
        if [[ -n "$full_output" ]]; then
            full_output+="\n--- STDERR ---\n"
        fi
        full_output+=$(cat "$temp_error")
    fi
    
    # Clean up temp files
    rm -f "$temp_output" "$temp_error"
    
    # Display the output to the user first
    if [[ -n "$full_output" ]]; then
        echo -e "$full_output"
    fi
    
    # Only log if command was successful (exit code 0)
    if [[ $exit_code -eq 0 ]]; then
        log_command "$command" "$full_output"
        local log_msg="✓ Command logged successfully to Obsidian"
        if [[ "$TAKE_SCREENSHOT" == "true" ]]; then
            log_msg="$log_msg (with screenshot)"
        fi
        echo "$log_msg"
    else
        echo "✗ Command failed (exit code: $exit_code) - not logged to Obsidian"
        return $exit_code
    fi
    
    return $exit_code
}

# Parse command line arguments
ARGS=()
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -cv|--change-vault)
            change_vault
            exit 0
            ;;
        -A|--active)
            shift
            # Check if next argument is -ss
            if [[ "$1" == "-ss" || "$1" == "--screenshot" ]]; then
                TAKE_SCREENSHOT=true
                shift
            fi
            active_mode
            exit 0
            ;;
        -ss|--screenshot)
            TAKE_SCREENSHOT=true
            shift
            ;;
        -session)
            SESSION_MODE=true
            shift
            if [[ -n "$1" && ! "$1" =~ ^- ]]; then
                SESSION_NAME="$1"
                shift
            else
                echo "Error: -session requires a session name"
                echo "Example: klog -session 'evil-winrm-target' evil-winrm -i 192.168.1.100"
                exit 1
            fi
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

# Handle session mode
if [[ "$SESSION_MODE" == "true" ]]; then
    if [[ ${#ARGS[@]} -eq 0 ]]; then
        echo "Error: Session mode requires a command to run"
        echo "Example: klog -session 'evil-winrm-target' evil-winrm -i 192.168.1.100"
        exit 1
    fi
    session_mode "$SESSION_NAME" "${ARGS[@]}"
    exit 0
fi

# Check if we have a command to run
if [[ ${#ARGS[@]} -eq 0 ]]; then
    echo "Usage: klog [OPTIONS] <command>"
    echo "Try 'klog --help' for more information."
    exit 1
fi

# Run the command with logging
run_and_log "${ARGS[@]}"
EOF

# Replace placeholder with actual vault path
sed -i "s|VAULT_PATH_PLACEHOLDER|$VAULT_PATH|g" /tmp/klog

# Install the script
sudo cp /tmp/klog "$SCRIPT_DIR/$SCRIPT_NAME"
sudo chmod +x "$SCRIPT_DIR/$SCRIPT_NAME"
rm /tmp/klog

echo ""
echo "=== Setup Complete! ==="
echo "Usage: klog [OPTIONS] <command>"
echo ""
echo "Examples:"
echo "  klog nmap -sV 192.168.1.1"
echo "  klog -ss 'ls -la && whoami'"
echo "  klog -session 'evil-winrm-target' evil-winrm -u admin -p 'pass' -i 192.168.1.100"
echo "  klog -A                     # Active mode"
echo "  klog --help                 # Show help"
echo ""
echo "Files will be saved to:"
echo "  Logs: $VAULT_PATH/Command_Logs/"
echo "  Screenshots: $VAULT_PATH/Screenshots/"
echo "  Sessions: $VAULT_PATH/Sessions/"
echo ""
echo "Features:"
echo "  ✓ Only successful commands are logged"
echo "  ✓ Screenshots with -ss flag"
echo "  ✓ Session logging for interactive shells"
echo "  ✓ Real-time output + Obsidian logging"
echo ""
echo "Happy hunting! 🎯"