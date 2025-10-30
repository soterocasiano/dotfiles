#!/bin/bash

# VS Code MCP Settings Deployment Script
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"
MCP_SETTINGS_FILE="${SCRIPT_DIR}/vscode-mcp-settings.json"

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v code &> /dev/null; then
        log_warn "VS Code CLI is not installed or not in PATH"
        log_info "You can still manually copy the configuration files"
    fi
    
    if ! command -v node &> /dev/null; then
        log_error "Node.js is not installed or not in PATH"
        log_error "Node.js is required for MCP servers"
        exit 1
    fi
    
    if ! command -v npx &> /dev/null; then
        log_error "npx is not installed or not in PATH"
        log_error "npx is required for MCP servers"
        exit 1
    fi
}

setup_environment() {
    log_info "Setting up environment..."
    
    if [[ ! -f "$ENV_FILE" ]]; then
        log_warn "Environment file not found. Creating from template..."
        cp "${SCRIPT_DIR}/.env.template" "$ENV_FILE"
        log_warn "Please edit $ENV_FILE with your configuration before running again."
        exit 1
    fi
    
    # Source environment variables
    source "$ENV_FILE"
    
    # Validate required variables for enabled servers
    if [[ -z "$ATLASSIAN_CLOUD_ID" ]] || [[ -z "$ATLASSIAN_API_TOKEN" ]] || [[ -z "$ATLASSIAN_EMAIL" ]]; then
        log_warn "Atlassian environment variables not set. Atlassian MCP server will not work."
    fi
    
    if [[ -z "$GITHUB_TOKEN" ]]; then
        log_warn "GitHub token not set. GitHub MCP server will not work."
    fi
}

install_mcp_extension() {
    log_info "Installing VS Code MCP extension..."
    
    if command -v code &> /dev/null; then
        code --install-extension modelcontextprotocol.mcp
        log_info "MCP extension installed successfully"
    else
        log_warn "Please manually install the MCP extension in VS Code:"
        log_warn "1. Open VS Code"
        log_warn "2. Go to Extensions (Ctrl+Shift+X)"
        log_warn "3. Search for 'Model Context Protocol'"
        log_warn "4. Install the official MCP extension"
    fi
}

deploy_workspace_config() {
    local workspace_dir="${1:-.}"
    local vscode_dir="${workspace_dir}/.vscode"
    local settings_file="${vscode_dir}/settings.json"
    
    log_info "Deploying MCP configuration to workspace: $workspace_dir"
    
    # Create .vscode directory if it doesn't exist
    mkdir -p "$vscode_dir"
    
    # Check if settings.json exists
    if [[ -f "$settings_file" ]]; then
        log_warn "Existing settings.json found. Creating backup..."
        cp "$settings_file" "${settings_file}.backup.$(date +%s)"
    fi
    
    # Create or update settings.json with MCP configuration
    if [[ -f "$settings_file" ]]; then
        # Merge with existing settings (simple approach)
        log_info "Merging with existing VS Code settings..."
        
        # Create temporary merged file
        local temp_file="/tmp/vscode-settings-merged.json"
        
        # Use jq to merge if available, otherwise manual merge
        if command -v jq &> /dev/null; then
            jq -s '.[0] * .[1]' "$settings_file" "$MCP_SETTINGS_FILE" > "$temp_file"
            cp "$temp_file" "$settings_file"
            rm "$temp_file"
        else
            log_warn "jq not found. Please manually merge the MCP settings:"
            log_warn "1. Copy contents of $MCP_SETTINGS_FILE"
            log_warn "2. Add to your existing $settings_file"
        fi
    else
        # Copy MCP settings as new settings.json
        cp "$MCP_SETTINGS_FILE" "$settings_file"
    fi
    
    log_info "MCP configuration deployed to: $settings_file"
}

deploy_global_config() {
    log_info "Deploying MCP configuration globally..."
    
    local vscode_config_dir
    if [[ "$OSTYPE" == "darwin"* ]]; then
        vscode_config_dir="$HOME/Library/Application Support/Code/User"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        vscode_config_dir="$HOME/.config/Code/User"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        vscode_config_dir="$APPDATA/Code/User"
    else
        log_error "Unsupported operating system: $OSTYPE"
        exit 1
    fi
    
    local settings_file="${vscode_config_dir}/settings.json"
    
    if [[ ! -d "$vscode_config_dir" ]]; then
        log_error "VS Code user configuration directory not found: $vscode_config_dir"
        exit 1
    fi
    
    # Backup existing settings
    if [[ -f "$settings_file" ]]; then
        log_warn "Backing up existing global settings..."
        cp "$settings_file" "${settings_file}.backup.$(date +%s)"
    fi
    
    # Deploy configuration
    if [[ -f "$settings_file" ]] && command -v jq &> /dev/null; then
        # Merge with existing settings
        local temp_file="/tmp/vscode-global-settings-merged.json"
        jq -s '.[0] * .[1]' "$settings_file" "$MCP_SETTINGS_FILE" > "$temp_file"
        cp "$temp_file" "$settings_file"
        rm "$temp_file"
        log_info "MCP configuration merged with existing global settings"
    else
        cp "$MCP_SETTINGS_FILE" "$settings_file"
        log_info "MCP configuration deployed as new global settings"
    fi
    
    log_info "Global MCP configuration deployed to: $settings_file"
}

test_mcp_servers() {
    log_info "Testing MCP server installations..."
    
    # Test GitHub server
    if command -v npx &> /dev/null; then
        log_info "Testing GitHub MCP server..."
        if npx -y @modelcontextprotocol/server-github@latest --version &> /dev/null; then
            log_info "✓ GitHub MCP server is available"
        else
            log_warn "✗ GitHub MCP server test failed"
        fi
        
        log_info "Testing Atlassian MCP server..."
        if npx -y @modelcontextprotocol/server-atlassian@latest --version &> /dev/null; then
            log_info "✓ Atlassian MCP server is available"
        else
            log_warn "✗ Atlassian MCP server test failed"
        fi
    fi
}

show_usage() {
    echo "Usage: $0 [workspace|global] [workspace-path]"
    echo ""
    echo "Commands:"
    echo "  workspace [path]  Deploy MCP config to workspace (default: current directory)"
    echo "  global           Deploy MCP config globally to VS Code user settings"
    echo ""
    echo "Examples:"
    echo "  $0 workspace                    # Deploy to current workspace"
    echo "  $0 workspace /path/to/project   # Deploy to specific workspace"
    echo "  $0 global                       # Deploy globally"
}

main() {
    local deployment_type="${1:-workspace}"
    local workspace_path="${2:-.}"
    
    log_info "Starting VS Code MCP configuration deployment..."
    
    check_prerequisites
    setup_environment
    
    case "$deployment_type" in
        "workspace")
            install_mcp_extension
            deploy_workspace_config "$workspace_path"
            ;;
        "global")
            install_mcp_extension
            deploy_global_config
            ;;
        "help"|"-h"|"--help")
            show_usage
            exit 0
            ;;
        *)
            log_error "Invalid deployment type: $deployment_type"
            show_usage
            exit 1
            ;;
    esac
    
    test_mcp_servers
    
    log_info "Deployment completed successfully!"
    log_info ""
    log_info "Next steps:"
    log_info "1. Restart VS Code to load the new MCP configuration"
    log_info "2. Verify your environment variables are set correctly"
    log_info "3. Test MCP functionality in VS Code"
}

# Run main function
main "$@"