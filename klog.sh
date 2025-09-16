#!/bin/bash

# Kali Command Logger for Obsidian
OBSIDIAN_VAULT="/home/$(whoami)/Documents/cmd_notes"  # Default vault path
NOTES_DIR="$OBSIDIAN_VAULT/Command_Logs"
SCREENSHOTS_DIR="$OBSIDIAN_VAULT/Screenshots"
DAILY_NOTE="$NOTES_DIR/$(date +%Y-%m-%d)_commands.md"

# Global flags
TAKE_SCREENSHOT=false
SESSION_MODE=false
SESSION_NAME=""

# Function to show help
show_help() {
    cat << EOF
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
EOF
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
    cat > "$temp_script" << EOF
#!/bin/bash
exec $command
EOF
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

# Parse comman