#!/bin/bash

# SSH Monitor - Quick Access Script
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
