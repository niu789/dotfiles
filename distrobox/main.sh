#!/bin/bash

# ====================================================================
# Distrobox Main Container Setup Script
# ====================================================================

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script configuration
CONTAINER_NAME="main"
CONFIG_FILE="main.ini"
VSCODE_URL="https://code.visualstudio.com/sha/download?build=insider&os=linux-deb-x64"
VSCODE_DEB="$HOME/Downloads/code-insiders.deb"
TOTAL_STEPS=9
CURRENT_STEP=0

# Default flags
VERBOSE=false
STEP_BY_STEP=false
DRY_RUN=false
REMOVE=false

# Progress bar function
show_progress() {
    local step=$1
    local total=$2
    local percent=$((step * 100 / total))
    local filled=$((percent / 2))
    
    printf "\r${CYAN}Progress: ["
    printf "%${filled}s" | tr ' ' '='
    printf "%$((50 - filled))s" | tr ' ' ' '
    printf "] %3d%%${NC}" $percent
    
    if [ $step -eq $total ]; then
        echo
    fi
}

# Message functions
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Execute command with proper output handling
execute_command() {
    local cmd="$1"
    local description="$2"
    
    if $DRY_RUN; then
        echo -e "${CYAN}[DRY-RUN]${NC} Would execute: $cmd"
        return 0
    fi
    
    if $VERBOSE; then
        echo -e "${CYAN}[EXECUTING]${NC} $cmd"
        eval "$cmd"
    else
        eval "$cmd" > /dev/null 2>&1
    fi
    
    return $?
}

# Step execution with confirmation
execute_step() {
    local step_num=$1
    local step_desc=$2
    local step_cmd=$3
    
    CURRENT_STEP=$step_num
    show_progress $CURRENT_STEP $TOTAL_STEPS
    
    echo
    info "Step $step_num/$TOTAL_STEPS: $step_desc"
    
    if $STEP_BY_STEP; then
        echo -e "${YELLOW}Command to execute:${NC} $step_cmd"
        read -p "Do you want to proceed with this step? (y/n/q): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Qq]$ ]]; then
            warning "Execution stopped by user at step $step_num"
            exit 0
        elif [[ ! $REPLY =~ ^[Yy]$ ]]; then
            warning "Skipping step $step_num"
            return 1
        fi
    fi
    
    execute_command "$step_cmd" "$step_desc"
    local result=$?
    
    if [ $result -eq 0 ]; then
        success "$step_desc completed"
    else
        error "$step_desc failed with exit code $result"
        if ! $STEP_BY_STEP; then
            read -p "Do you want to continue despite the error? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                error "Execution stopped due to error"
                exit 1
            fi
        fi
    fi
    
    return $result
}

# Help message
show_help() {
    cat << EOF
Distrobox Main Container Setup Script

Usage: $(basename "$0") [OPTIONS]

OPTIONS:
    -h, --help          Show this help message
    -v, --verbose       Show detailed output from all commands
    -s, --step-by-step  Confirm each step before execution
    -d, --dry-run       Show what would be done without executing
    -r, --remove        Remove the existing container before setup
    
EXAMPLES:
    $(basename "$0")                    # Normal execution
    $(basename "$0") --verbose          # Show all command outputs
    $(basename "$0") --step-by-step     # Interactive mode
    $(basename "$0") --dry-run          # Test run without changes
    $(basename "$0") --remove           # Remove container and recreate

EOF
    exit 0
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -s|--step-by-step)
                STEP_BY_STEP=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -r|--remove)
                REMOVE=true
                shift
                ;;
            *)
                error "Unknown option: $1"
                show_help
                ;;
        esac
    done
}

# Check prerequisites
check_prerequisites() {
    info "Checking prerequisites..."
    
    if ! command -v distrobox &> /dev/null; then
        error "distrobox is not installed"
        exit 1
    fi
    
    if [ ! -f "$CONFIG_FILE" ]; then
        error "Configuration file $CONFIG_FILE not found"
        exit 1
    fi
    
    success "Prerequisites check passed"
}

# Main execution
main() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Distrobox Main Container Setup${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    
    if $DRY_RUN; then
        warning "Running in DRY-RUN mode - no changes will be made"
        echo
    fi
    
    if $VERBOSE; then
        info "Verbose mode enabled"
    fi
    
    if $STEP_BY_STEP; then
        info "Step-by-step mode enabled"
    fi
    
    check_prerequisites
    echo
    
    # Step 0: Remove existing container if requested
    if $REMOVE; then
        execute_step 0 "Removing existing container" \
            "distrobox rm -f $CONTAINER_NAME"
        TOTAL_STEPS=$((TOTAL_STEPS + 1))
    fi
    
    # Step 1: Create container from configuration
    execute_step 1 "Creating container from $CONFIG_FILE" \
        "distrobox assemble create --file $CONFIG_FILE"
    
    # Step 2: Download VS Code Insiders
    execute_step 2 "Downloading VS Code Insiders" \
        "curl -L '$VSCODE_URL' -o '$VSCODE_DEB'"
    
    # Step 3: Update package lists
    execute_step 3 "Updating package lists in container" \
        "distrobox enter $CONTAINER_NAME -- sudo apt-get update"
    
    # Step 4: Upgrade packages
    execute_step 4 "Upgrading packages in container" \
        "distrobox enter $CONTAINER_NAME -- sudo apt-get dist-upgrade -y"
    
    # Step 5: Install VS Code dependencies
    execute_step 5 "Installing VS Code dependencies" \
        "distrobox enter $CONTAINER_NAME -- sudo apt-get -y install libasound2t64 libxkbfile1 xdg-utils"
    
    # Step 6: Install VS Code Insiders (first attempt)
    execute_step 6 "Installing VS Code Insiders (first attempt)" \
        "distrobox enter $CONTAINER_NAME -- sudo dpkg --install '$VSCODE_DEB'"
    
    # Step 7: Fix any dependency issues
    execute_step 7 "Fixing any dependency issues" \
        "distrobox enter $CONTAINER_NAME -- sudo apt-get -y -f install"
    
    # Step 8: Install VS Code Insiders (final)
    execute_step 8 "Installing VS Code Insiders (final)" \
        "distrobox enter $CONTAINER_NAME -- sudo dpkg --install '$VSCODE_DEB'"
    
    # Step 9: Export applications
    execute_step 9 "Exporting applications to host" \
    	"distrobox enter $CONTAINER_NAME -- bash -c 'distrobox-export --app keybase && distrobox-export --app code-insiders && distrobox-export --bin /usr/bin/code-insiders --export-path ~/.local/bin'"

    execute_step 10 "Setting up GNOME Keyring for VS Code" \
    "distrobox enter $CONTAINER_NAME -- bash -c '\
        sudo apt install -y gnome-keyring libsecret-1-0 libsecret-tools && \
        echo \"eval \\$(gnome-keyring-daemon --start --daemonize 2>/dev/null)\" >> ~/.zshrc && \
        echo \"export GNOME_KEYRING_CONTROL\" >> ~/.zshrc && \
        echo \"export SSH_AUTH_SOCK\" >> ~/.zshrc \
    '"

    # Final progress
    show_progress $TOTAL_STEPS $TOTAL_STEPS
    
    echo
    echo -e "${GREEN}========================================${NC}"
    if $DRY_RUN; then
        success "Dry run completed successfully!"
    else
        success "Container setup completed successfully!"
        info "You can enter the container with: distrobox enter $CONTAINER_NAME"
        info "Or launch zsh directly with: $HOME/.local/bin/zsh"
    fi
    echo -e "${GREEN}========================================${NC}"
}

# Script entry point
parse_arguments "$@"
main

exit 0
