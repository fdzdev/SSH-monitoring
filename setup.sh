#!/bin/bash

# 🔐 SSH Monitor - Complete Setup Script
# This script sets up the entire SSH monitoring system seamlessly after cloning

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
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

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        print_error "Run: sudo bash setup.sh"
        exit 1
    fi
}

# Function to detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
    print_status "Detected OS: $OS $VER"
}

# Function to install dependencies
install_dependencies() {
    print_status "Installing system dependencies..."
    
    if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
        apt update
        apt install -y python3 python3-pip sqlite3 curl wget git
    elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]] || [[ "$OS" == *"Rocky"* ]]; then
        yum update -y
        yum install -y python3 python3-pip sqlite curl wget git
    elif [[ "$OS" == *"Amazon Linux"* ]]; then
        yum update -y
        yum install -y python3 python3-pip sqlite curl wget git
    else
        print_warning "Unsupported OS. Please install manually: python3, sqlite3, curl"
    fi
    
    print_success "Dependencies installed"
}

# Function to setup Python environment
setup_python() {
    print_status "Setting up Python environment..."
    
    # Check Python version
    python3 --version
    
    # Install Python dependencies if needed
    if command -v pip3 &> /dev/null; then
        pip3 install --upgrade pip
    fi
    
    print_success "Python environment ready"
}

# Function to setup SSH monitoring
setup_ssh_monitoring() {
    print_status "Setting up SSH monitoring system..."
    
    # Make script executable
    chmod +x ssh_tracker.py
    
    # Create log directory if it doesn't exist
    mkdir -p /var/log
    
    # Create database and log files with proper permissions
    touch /var/log/ssh_attempts.db
    touch /var/log/ssh_attempts.log
    
    # Set proper permissions
    chmod 644 /var/log/ssh_attempts.db
    chmod 644 /var/log/ssh_attempts.log
    
    print_success "SSH monitoring files created"
}

# Function to create systemd service
create_systemd_service() {
    print_status "Creating systemd service..."
    
    # Get current directory
    CURRENT_DIR=$(pwd)
    
    # Create service file
    cat > /etc/systemd/system/ssh-monitor.service << EOF
[Unit]
Description=SSH Monitor Service
After=network.target ssh.service
Wants=ssh.service

[Service]
Type=simple
ExecStart=/usr/bin/python3 ${CURRENT_DIR}/ssh_tracker.py
WorkingDirectory=${CURRENT_DIR}
Restart=always
RestartSec=10
User=root
StandardOutput=journal
StandardError=journal
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd and enable service
    systemctl daemon-reload
    systemctl enable ssh-monitor.service
    
    print_success "Systemd service created and enabled"
}

# Function to create run.sh script
create_run_script() {
    print_status "Creating run.sh script..."
    
    cat > run.sh << 'EOF'
#!/bin/bash

# SSH Monitor - Quick Run Script
# This script provides easy access to SSH monitoring functions

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to print colored output
print_status() {
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

# Function to show help
show_help() {
    echo "🔐 SSH Monitor - Quick Access Script"
    echo "====================================="
    echo ""
    echo "Usage: ./run.sh [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start     - Start SSH monitoring service"
    echo "  stop      - Stop SSH monitoring service"
    echo "  restart   - Restart SSH monitoring service"
    echo "  status    - Show service status"
    echo "  logs      - Show real-time logs"
    echo "  stats     - Show database statistics"
    echo "  recent    - Show recent SSH attempts"
    echo "  failed    - Show failed SSH attempts"
    echo "  monitor   - Start real-time monitoring"
    echo "  install   - Install as system service"
    echo "  uninstall - Remove system service"
    echo "  help      - Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./run.sh start      # Start the service"
    echo "  ./run.sh monitor    # Monitor in real-time"
    echo "  ./run.sh stats      # View statistics"
    echo ""
}

# Function to check if service is running
check_service() {
    if systemctl is-active --quiet ssh-monitor; then
        return 0
    else
        return 1
    fi
}

# Function to start service
start_service() {
    print_status "Starting SSH monitoring service..."
    systemctl start ssh-monitor
    if check_service; then
        print_success "Service started successfully"
    else
        print_error "Failed to start service"
        exit 1
    fi
}

# Function to stop service
stop_service() {
    print_status "Stopping SSH monitoring service..."
    systemctl stop ssh-monitor
    print_success "Service stopped"
}

# Function to restart service
restart_service() {
    print_status "Restarting SSH monitoring service..."
    systemctl restart ssh-monitor
    if check_service; then
        print_success "Service restarted successfully"
    else
        print_error "Failed to restart service"
        exit 1
    fi
}

# Function to show service status
show_status() {
    print_status "Service status:"
    systemctl status ssh-monitor --no-pager -l
}

# Function to show logs
show_logs() {
    print_status "Showing SSH monitoring logs..."
    journalctl -u ssh-monitor -f
}

# Function to show statistics
show_stats() {
    print_status "Database statistics:"
    if [[ -f /var/log/ssh_attempts.db ]]; then
        sqlite3 /var/log/ssh_attempts.db "
        SELECT 
            COUNT(*) as total_attempts,
            SUM(success) as successful,
            COUNT(*) - SUM(success) as failed,
            COUNT(DISTINCT ip_address) as unique_ips
        FROM ssh_attempts;
        "
    else
        print_error "Database not found. Start the service first."
        exit 1
    fi
}

# Function to show recent attempts
show_recent() {
    print_status "Recent SSH attempts:"
    if [[ -f /var/log/ssh_attempts.db ]]; then
        sqlite3 /var/log/ssh_attempts.db "
        SELECT 
            timestamp,
            ip_address,
            username,
            CASE success 
                WHEN 1 THEN 'SUCCESS' 
                ELSE 'FAILED' 
            END as status,
            country,
            city
        FROM ssh_attempts 
        ORDER BY timestamp DESC 
        LIMIT 20;
        "
    else
        print_error "Database not found. Start the service first."
        exit 1
    fi
}

# Function to show failed attempts
show_failed() {
    print_status "Failed SSH attempts:"
    if [[ -f /var/log/ssh_attempts.db ]]; then
        sqlite3 /var/log/ssh_attempts.db "
        SELECT 
            timestamp,
            ip_address,
            username,
            failure_reason,
            country,
            city
        FROM ssh_attempts 
        WHERE success = 0 
        ORDER BY timestamp DESC 
        LIMIT 20;
        "
    else
        print_error "Database not found. Start the service first."
        exit 1
    fi
}

# Function to start real-time monitoring
start_monitoring() {
    print_status "Starting real-time SSH monitoring..."
    print_warning "Press Ctrl+C to stop monitoring"
    echo ""
    
    if [[ -f /var/log/ssh_attempts.db ]]; then
        # Show initial stats
        show_stats
        echo ""
        print_status "Monitoring auth.log for new SSH attempts..."
        echo ""
        
        # Start the Python tracker
        python3 ssh_tracker.py
    else
        print_error "Database not found. Start the service first."
        exit 1
    fi
}

# Function to install service
install_service() {
    print_status "Installing SSH monitoring as system service..."
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        print_error "This command must be run as root (use sudo)"
        print_error "Run: sudo ./run.sh install"
        exit 1
    fi
    
    # Create service file
    CURRENT_DIR=$(pwd)
    cat > /etc/systemd/system/ssh-monitor.service << EOF
[Unit]
Description=SSH Monitor Service
After=network.target ssh.service
Wants=ssh.service

[Service]
Type=simple
ExecStart=/usr/bin/python3 ${CURRENT_DIR}/ssh_tracker.py
WorkingDirectory=${CURRENT_DIR}
Restart=always
RestartSec=10
User=root
StandardOutput=journal
StandardError=journal
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd and enable service
    systemctl daemon-reload
    systemctl enable ssh-monitor.service
    
    print_success "Service installed and enabled"
    print_status "Use 'sudo ./run.sh start' to start the service"
}

# Function to uninstall service
uninstall_service() {
    print_status "Uninstalling SSH monitoring service..."
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        print_error "This command must be run as root (use sudo)"
        print_error "Run: sudo ./run.sh uninstall"
        exit 1
    fi
    
    # Stop and disable service
    systemctl stop ssh-monitor 2>/dev/null || true
    systemctl disable ssh-monitor 2>/dev/null || true
    
    # Remove service file
    rm -f /etc/systemd/system/ssh-monitor.service
    
    # Reload systemd
    systemctl daemon-reload
    
    print_success "Service uninstalled"
}

# Main script logic
case "${1:-help}" in
    start)
        start_service
        ;;
    stop)
        stop_service
        ;;
    restart)
        restart_service
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    stats)
        show_stats
        ;;
    recent)
        show_recent
        ;;
    failed)
        show_failed
        ;;
    monitor)
        start_monitoring
        ;;
    install)
        install_service
        ;;
    uninstall)
        uninstall_service
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
EOF
    
    # Make run.sh executable
    chmod +x run.sh
    
    print_success "run.sh script created"
}

# Function to setup bashrc integration
setup_bashrc() {
    print_status "Setting up bashrc integration for key 9..."
    
    # Function to add to bashrc
    add_to_bashrc() {
        local bashrc_file="$1"
        local integration_code="
# SSH Monitor Integration - Press 9 to show last SSH attempts
ssh_monitor_show_last() {
    if [[ -f /var/log/ssh_attempts.db ]]; then
        echo \"🔐 Last 10 SSH attempts:\"
        sqlite3 /var/log/ssh_attempts.db \"
        SELECT 
            timestamp,
            ip_address,
            username,
            CASE success 
                WHEN 1 THEN '✅ SUCCESS' 
                ELSE '❌ FAILED' 
            END as status,
            country,
            city
        FROM ssh_attempts 
        ORDER BY timestamp DESC 
        LIMIT 10;
        \"
    else
        echo \"❌ SSH monitoring database not found. Start the service first.\"
        echo \"💡 Run: sudo ./run.sh start\"
    fi
}

# Bind key 9 to show SSH attempts
bind '\\\"9\\\": ssh_monitor_show_last\\n' 2>/dev/null || true
"
        
        # Check if integration already exists
        if ! grep -q "SSH Monitor Integration" "$bashrc_file"; then
            echo "$integration_code" >> "$bashrc_file"
            print_success "Added to $bashrc_file"
        else
            print_warning "Integration already exists in $bashrc_file"
        fi
    }
    
    # Add to user's bashrc
    if [[ -n "$SUDO_USER" ]]; then
        USER_BASHRC="/home/$SUDO_USER/.bashrc"
        if [[ -f "$USER_BASHRC" ]]; then
            add_to_bashrc "$USER_BASHRC"
        fi
    fi
    
    # Add to root's bashrc
    if [[ -f /root/.bashrc ]]; then
        add_to_bashrc "/root/.bashrc"
    fi
    
    print_success "Bashrc integration complete"
    print_warning "Note: You may need to restart your terminal or run 'source ~/.bashrc'"
}

# Function to test the system
test_system() {
    print_status "Testing SSH monitoring system..."
    
    # Check if database exists
    if [[ -f /var/log/ssh_attempts.db ]]; then
        print_success "Database file exists"
    else
        print_error "Database file not found"
        return 1
    fi
    
    # Check if log file exists
    if [[ -f /var/log/ssh_attempts.log ]]; then
        print_success "Log file exists"
    else
        print_error "Log file not found"
        return 1
    fi
    
    # Check if service file exists
    if [[ -f /etc/systemd/system/ssh-monitor.service ]]; then
        print_success "Systemd service file exists"
    else
        print_error "Systemd service file not found"
        return 1
    fi
    
    # Check if run.sh exists and is executable
    if [[ -f run.sh ]] && [[ -x run.sh ]]; then
        print_success "run.sh script exists and is executable"
    else
        print_error "run.sh script not found or not executable"
        return 1
    fi
    
    print_success "All system components verified"
}

# Function to show final instructions
show_final_instructions() {
    echo ""
    echo "🎉 SSH Monitor Setup Complete!"
    echo "=============================="
    echo ""
    echo "🚀 Quick Start:"
    echo "  sudo ./run.sh start      # Start the monitoring service"
    echo "  ./run.sh monitor         # Monitor in real-time"
    echo "  ./run.sh stats           # View statistics"
    echo ""
    echo "🔧 Service Management:"
    echo "  sudo ./run.sh start      # Start service"
    echo "  sudo ./run.sh stop       # Stop service"
    echo "  sudo ./run.sh restart    # Restart service"
    echo "  sudo ./run.sh status     # Check status"
    echo ""
    echo "📊 Viewing Data:"
    echo "  ./run.sh recent         # Recent attempts"
    echo "  ./run.sh failed         # Failed attempts"
    echo "  ./run.sh logs           # Service logs"
    echo ""
    echo "⌨️  Bashrc Integration:"
    echo "  Press '9' in terminal   # Show last 10 SSH attempts"
    echo "  (May need to restart terminal or run 'source ~/.bashrc')"
    echo ""
    echo "📁 Files Created:"
    echo "  /etc/systemd/system/ssh-monitor.service"
    echo "  /var/log/ssh_attempts.db"
    echo "  /var/log/ssh_attempts.log"
    echo "  run.sh"
    echo ""
    echo "🔐 The system is now ready to monitor SSH attempts!"
    echo "   All SSH activity will be logged to the database."
    echo ""
}

# Main setup function
main() {
    echo "🔐 SSH Monitor - Complete Setup Script"
    echo "======================================"
    echo ""
    
    # Check if running as root
    check_root
    
    # Detect OS
    detect_os
    
    # Install dependencies
    install_dependencies
    
    # Setup Python environment
    setup_python
    
    # Setup SSH monitoring
    setup_ssh_monitoring
    
    # Create systemd service
    create_systemd_service
    
    # Create run.sh script
    create_run_script
    
    # Setup bashrc integration
    setup_bashrc
    
    # Test the system
    test_system
    
    # Show final instructions
    show_final_instructions
}

# Run main function
main "$@"
