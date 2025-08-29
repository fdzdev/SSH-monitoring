# 🔐 SSH Monitor - Complete SSH Attempt Tracking System

A comprehensive, self-contained SSH monitoring system that tracks all SSH attempts to your server with geolocation, detailed logging, and real-time monitoring.

## 🚀 Quick Start (3 Steps)

### 1. Clone and Setup
```bash
# Clone this folder to your server
git clone <your-repo-url> ssh-monitor
cd ssh-monitor

# Make the script executable
chmod +x ssh_monitor.py
```

### 2. Run the Monitor
```bash
# Start monitoring (must run as root)
sudo python3 ssh_monitor.py
```

### 3. You're Done! ��

The system is now monitoring all SSH attempts in real-time.

## 📋 What It Tracks

- ✅ **IP Addresses** of all SSH attempts
- ✅ **Timestamps** with millisecond precision
- ✅ **Usernames** attempted
- ✅ **Success/Failure** status
- ✅ **Port numbers** used
- ✅ **SSH versions** (SSH1, SSH2)
- ✅ **Geolocation** (Country, City, ISP)
- ✅ **Raw log lines** for debugging
- ✅ **Real-time monitoring** with live updates

## ��️ Database Schema

```sql
CREATE TABLE ssh_attempts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL,           -- ISO timestamp from logs
    ip_address TEXT NOT NULL,          -- IP address of attempt
    username TEXT,                     -- Username attempted
    success INTEGER NOT NULL,          -- 1=success, 0=failure
    failure_reason TEXT,               -- Why it failed
    port INTEGER,                      -- Port number used
    ssh_version TEXT,                  -- SSH version (SSH1/SSH2)
    country TEXT,                      -- Country from geolocation
    city TEXT,                         -- City from geolocation
    isp TEXT,                          -- ISP from geolocation
    raw_log_line TEXT,                 -- Original log line
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);
```

## 🔍 Viewing Results

### Real-time Monitoring
```bash
# Watch live SSH attempts
sudo python3 ssh_monitor.py
```

### Database Queries
```bash
# View all attempts
sqlite3 /var/log/ssh_attempts.db "SELECT * FROM ssh_attempts ORDER BY timestamp DESC LIMIT 20;"

# View failed attempts only
sqlite3 /var/log/ssh_attempts.db "SELECT timestamp, ip_address, username, failure_reason FROM ssh_attempts WHERE success = 0 ORDER BY timestamp DESC;"

# View attempts from specific IP
sqlite3 /var/log/ssh_attempts.db "SELECT * FROM ssh_attempts WHERE ip_address = '192.168.1.1';"

# View attempts in last hour
sqlite3 /var/log/ssh_attempts.db "SELECT * FROM ssh_attempts WHERE timestamp > datetime('now', '-1 hour');"
```

### Log File
```bash
# View monitoring log
tail -f /var/log/ssh_attempts.log

# View last 100 entries
tail -n 100 /var/log/ssh_attempts.log
```

## 🛠️ System Requirements

- **OS**: Ubuntu/Debian (tested on Ubuntu 20.04+)
- **Python**: Python 3.6+
- **Tools**: `tail`, `curl`
- **Permissions**: Must run as root (for reading auth.log)

## 📦 Installation

### Automatic (Ubuntu/Debian)
```bash
# Install required packages
sudo apt update
sudo apt install python3 python3-pip sqlite3 curl

# Clone and run
git clone <your-repo-url> ssh-monitor
cd ssh-monitor
chmod +x ssh_monitor.py
sudo python3 ssh_monitor.py
```

### Manual
```bash
# Install Python dependencies
pip3 install sqlite3

# Install system tools
sudo apt install curl sqlite3
```

## �� Configuration

### Custom Log Path
Edit the script to change log locations:
```python
self.db_path = '/var/log/ssh_attempts.db'    # Database location
self.log_path = '/var/log/ssh_attempts.log'  # Monitor log location
```

### Monitoring Frequency
Change how often it checks logs:
```python
time.sleep(30)  # Check every 30 seconds
```

### Geolocation Services
The script uses multiple geolocation services:
- **Primary**: ipinfo.io (free tier)
- **Fallback**: ip-api.com (free)

## 📊 Statistics

The monitor shows real-time statistics:
- Total SSH attempts
- Successful vs failed attempts
- Unique IP addresses
- Recent activity (last hour)

## 🚨 Security Features

- **Comprehensive logging** of all SSH activity
- **IP geolocation** for threat assessment
- **Failure reason tracking** for security analysis
- **Real-time monitoring** for immediate response
- **Database indexing** for fast queries

## 🔄 Running as a Service

### Create Systemd Service
```bash
sudo nano /etc/systemd/system/ssh-monitor.service
```

**Service content:**
```ini
[Unit]
Description=SSH Monitor Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /path/to/ssh_monitor.py
Restart=always
RestartSec=10
User=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

### Enable Service
```bash
sudo systemctl daemon-reload
sudo systemctl enable ssh-monitor
sudo systemctl start ssh-monitor

# Check status
sudo systemctl status ssh-monitor

# View logs
sudo journalctl -u ssh-monitor -f
```

## 🧪 Testing

### Test SSH Connection
From another machine:
```bash
ssh username@your_server_ip
```

### Check Database
```bash
sqlite3 /var/log/ssh_attempts.db "SELECT * FROM ssh_attempts ORDER BY timestamp DESC LIMIT 1;"
```

### Check Logs
```bash
tail -f /var/log/ssh_attempts.log
```

## 📁 File Locations

- **Script**: `/path/to/ssh_monitor.py`
- **Database**: `/var/log/ssh_attempts.db`
- **Monitor Log**: `/var/log/ssh_attempts.log`
- **System Log**: `/var/log/auth.log` (existing)

## 🚀 Advanced Usage

### Custom Queries
```bash
# Find suspicious patterns
sqlite3 /var/log/ssh_attempts.db "
SELECT ip_address, COUNT(*) as attempts, 
       SUM(success) as successful,
       GROUP_CONCAT(DISTINCT username) as usernames
FROM ssh_attempts 
WHERE timestamp > datetime('now', '-24 hours')
GROUP BY ip_address 
HAVING attempts > 5
ORDER BY attempts DESC;
"

# Geographic analysis
sqlite3 /var/log/ssh_attempts.db "
SELECT country, city, COUNT(*) as attempts,
       SUM(success) as successful
FROM ssh_attempts 
WHERE country != 'Unknown'
GROUP BY country, city
ORDER BY attempts DESC;
"
```

### Export Data
```bash
# Export to CSV
sqlite3 /var/log/ssh_attempts.db "
.mode csv
.headers on
.output ssh_attempts.csv
SELECT * FROM ssh_attempts;
"

# Export to JSON
sqlite3 /var/log/ssh_attempts.db "
.mode json
.output ssh_attempts.json
SELECT * FROM ssh_attempts;
"
```

## 🔍 Troubleshooting

### Common Issues

**Permission Denied**
```bash
# Run as root
sudo python3 ssh_monitor.py
```

**Database Locked**
```bash
# Check if another instance is running
ps aux | grep ssh_monitor

# Kill existing process
sudo pkill -f ssh_monitor
```

**Log File Not Found**
```bash
# Check if auth.log exists
ls -la /var/log/auth.log

# Check permissions
sudo ls -la /var/log/auth.log
```

### Debug Mode
```bash
# Run with verbose output
sudo python3 -u ssh_monitor.py
```

## 📈 Performance

- **Memory**: ~10-20MB RAM usage
- **CPU**: Minimal impact (<1% on typical servers)
- **Storage**: Database grows ~1KB per SSH attempt
- **Network**: Geolocation API calls (minimal)

## 🔒 Privacy & Compliance

- **Local storage**: All data stays on your server
- **No external logging**: Only geolocation lookups
- **Data retention**: Keep as long as you want
- **GDPR compliant**: No personal data sent externally

## �� Contributing

Feel free to submit issues, feature requests, or pull requests!

## 📄 License

This project is open source and available under the MIT License.

---

## 🎯 Quick Commands Reference

```bash
# Start monitoring
sudo python3 ssh_monitor.py

# View recent attempts
sqlite3 /var/log/ssh_attempts.db "SELECT * FROM ssh_attempts ORDER BY timestamp DESC LIMIT 10;"

# View failed attempts
sqlite3 /var/log/ssh_attempts.db "SELECT * FROM ssh_attempts WHERE success = 0;"

# View log file
tail -f /var/log/ssh_attempts.log

# Stop monitoring
Ctrl+C
```

**That's it! Clone, run, and you're done! 🚀**