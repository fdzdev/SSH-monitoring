#!/usr/bin/env python3
"""
SSH Monitor - Complete SSH Attempt Tracking System
Clone this folder, run the script, and you're done!
"""

import re
import sqlite3
import time
import subprocess
import json
from datetime import datetime
import os
import sys
import signal


class SSHTracker:
    def __init__(self):
        self.db_path = "/var/log/ssh_attempts.db"
        self.log_path = "/var/log/ssh_attempts.log"
        self.running = True

        # Handle graceful shutdown
        signal.signal(signal.SIGINT, self.signal_handler)
        signal.signal(signal.SIGTERM, self.signal_handler)

        print("🚀 SSH Monitor Starting...")
        self.init_database()
        self.setup_logging()

    def signal_handler(self, signum, frame):
        print("\n🛑 Shutting down SSH Monitor gracefully...")
        self.running = False
        sys.exit(0)

    def setup_logging(self):
        try:
            if not os.path.exists(self.log_path):
                with open(self.log_path, "w") as f:
                    f.write(f"SSH Monitor started at {datetime.now()}\n")
            print(f"✅ Log file ready: {self.log_path}")
        except Exception as e:
            print(f"❌ Error setting up log file: {e}")

    def init_database(self):
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()

            # Create table with comprehensive fields
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS ssh_attempts (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp TEXT NOT NULL,
                    ip_address TEXT NOT NULL,
                    username TEXT,
                    success INTEGER NOT NULL,
                    failure_reason TEXT,
                    port INTEGER,
                    ssh_version TEXT,
                    country TEXT,
                    city TEXT,
                    isp TEXT,
                    raw_log_line TEXT,
                    created_at TEXT DEFAULT CURRENT_TIMESTAMP
                )
            """)

            # Create indexes for better performance
            cursor.execute(
                "CREATE INDEX IF NOT EXISTS idx_ip ON ssh_attempts(ip_address)"
            )
            cursor.execute(
                "CREATE INDEX IF NOT EXISTS idx_timestamp ON ssh_attempts(timestamp)"
            )
            cursor.execute(
                "CREATE INDEX IF NOT EXISTS idx_success ON ssh_attempts(success)"
            )

            conn.commit()
            conn.close()
            print(f"✅ Database ready: {self.db_path}")
        except Exception as e:
            print(f"❌ Database error: {e}")
            sys.exit(1)

    def log_message(self, message):
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_entry = f"[{timestamp}] {message}"

        try:
            with open(self.log_path, "a") as f:
                f.write(log_entry + "\n")
        except Exception as e:
            print(f"❌ Log write error: {e}")

        print(log_entry)

    def get_geolocation(self, ip):
        """Get geolocation info for IP address"""
        try:
            # Try ipinfo.io first (free tier)
            result = subprocess.run(
                ["curl", "-s", "--max-time", "5", f"https://ipinfo.io/{ip}/json"],
                capture_output=True,
                text=True,
            )
            if result.returncode == 0 and result.stdout.strip():
                data = json.loads(result.stdout)
                return {
                    "country": data.get("country", "Unknown"),
                    "city": data.get("city", "Unknown"),
                    "isp": data.get("org", "Unknown"),
                }
        except:
            pass

        # Fallback to ip-api.com
        try:
            result = subprocess.run(
                ["curl", "-s", "--max-time", "5", f"http://ip-api.com/json/{ip}"],
                capture_output=True,
                text=True,
            )
            if result.returncode == 0 and result.stdout.strip():
                data = json.loads(result.stdout)
                if data.get("status") == "success":
                    return {
                        "country": data.get("country", "Unknown"),
                        "city": data.get("city", "Unknown"),
                        "isp": data.get("isp", "Unknown"),
                    }
        except:
            pass

        return {"country": "Unknown", "city": "Unknown", "isp": "Unknown"}

    def parse_auth_log(self):
        try:
            # Read the last 200 lines of auth.log
            result = subprocess.run(
                ["sudo", "tail", "-n", "200", "/var/log/auth.log"],
                capture_output=True,
                text=True,
            )

            if result.returncode != 0:
                self.log_message(f"⚠️ Error reading auth.log: {result.stderr}")
                return

            lines = result.stdout.split("\n")
            processed_count = 0

            for line in lines:
                if "sshd" in line and any(
                    keyword in line
                    for keyword in [
                        "Accepted",
                        "Failed",
                        "Invalid user",
                        "Connection from",
                    ]
                ):
                    if self.process_ssh_line(line):
                        processed_count += 1

            if processed_count > 0:
                self.log_message(f"📊 Processed {processed_count} SSH lines")

        except Exception as e:
            self.log_message(f"❌ Error parsing log: {e}")

    def process_ssh_line(self, line):
        try:
            # Extract ISO timestamp from log line
            timestamp_match = re.search(
                r"(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+\+\d{2}:\d{2})", line
            )
            if not timestamp_match:
                return False

            timestamp = timestamp_match.group(1)

            # Extract IP address
            ip_match = re.search(r"from ([\d.]+)", line)
            if not ip_match:
                return False

            ip_address = ip_match.group(1)

            # Extract port
            port = None
            port_match = re.search(r"port (\d+)", line)
            if port_match:
                port = int(port_match.group(1))

            # Extract SSH version
            ssh_version = None
            version_match = re.search(r"ssh(\d+)", line)
            if version_match:
                ssh_version = f"SSH{version_match.group(1)}"

            # Extract username
            username = None
            if "Accepted" in line:
                user_match = re.search(r"Accepted \w+ for (\w+) from", line)
                if user_match:
                    username = user_match.group(1)
            elif "Failed" in line:
                user_match = re.search(r"Failed \w+ for (\w+) from", line)
                if user_match:
                    username = user_match.group(1)
            elif "Invalid user" in line:
                user_match = re.search(r"Invalid user (\w+) from", line)
                if user_match:
                    username = user_match.group(1)

            # Determine success/failure
            success = 1 if "Accepted" in line else 0

            # Extract failure reason
            failure_reason = None
            if not success:
                if "Failed password" in line:
                    failure_reason = "Failed password"
                elif "Invalid user" in line:
                    failure_reason = "Invalid user"
                elif "Connection closed" in line:
                    failure_reason = "Connection closed"
                else:
                    failure_reason = "Other failure"

            # Get geolocation info (only for new IPs to avoid rate limiting)
            geo_info = self.get_geolocation(ip_address)

            # Save to database
            self.save_attempt(
                timestamp,
                ip_address,
                username,
                success,
                failure_reason,
                port,
                ssh_version,
                geo_info,
                line,
            )

            # Log the attempt
            status = "✅ SUCCESS" if success else "❌ FAILED"
            port_info = f" (port {port})" if port else ""
            geo_info_str = (
                f" [{geo_info['city']}, {geo_info['country']}]"
                if geo_info["country"] != "Unknown"
                else ""
            )

            self.log_message(
                f"SSH {status}: {ip_address}{port_info} -> {username or 'unknown'}{geo_info_str}"
            )

            return True

        except Exception as e:
            self.log_message(f"❌ Error processing line: {e}")
            return False

    def save_attempt(
        self,
        timestamp,
        ip_address,
        username,
        success,
        failure_reason,
        port,
        ssh_version,
        geo_info,
        raw_line,
    ):
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        cursor.execute(
            """
            INSERT INTO ssh_attempts 
            (timestamp, ip_address, username, success, failure_reason, port, ssh_version, 
             country, city, isp, raw_log_line)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
            (
                timestamp,
                ip_address,
                username,
                success,
                failure_reason,
                port,
                ssh_version,
                geo_info["country"],
                geo_info["city"],
                geo_info["isp"],
                raw_line,
            ),
        )

        conn.commit()
        conn.close()

    def show_stats(self):
        """Show current statistics"""
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()

            # Total attempts
            cursor.execute("SELECT COUNT(*) FROM ssh_attempts")
            total = cursor.fetchone()[0]

            # Successful attempts
            cursor.execute("SELECT COUNT(*) FROM ssh_attempts WHERE success = 1")
            successful = cursor.fetchone()[0]

            # Failed attempts
            cursor.execute("SELECT COUNT(*) FROM ssh_attempts WHERE success = 0")
            failed = cursor.fetchone()[0]

            # Unique IPs
            cursor.execute("SELECT COUNT(DISTINCT ip_address) FROM ssh_attempts")
            unique_ips = cursor.fetchone()[0]

            # Recent activity (last hour)
            cursor.execute("""
                SELECT COUNT(*) FROM ssh_attempts 
                WHERE timestamp > datetime('now', '-1 hour')
            """)
            recent = cursor.fetchone()[0]

            conn.close()

            print("\n" + "=" * 50)
            print("📊 SSH MONITOR STATISTICS")
            print("=" * 50)
            print(f"Total Attempts: {total}")
            print(f"Successful: {successful}")
            print(f"Failed: {failed}")
            print(f"Unique IPs: {unique_ips}")
            print(f"Last Hour: {recent}")
            print("=" * 50)

        except Exception as e:
            print(f"❌ Error getting stats: {e}")

    def run(self):
        self.log_message("�� SSH Monitor is now running and monitoring auth.log...")

        # Process existing logs first
        self.log_message("📖 Processing existing log entries...")
        self.parse_auth_log()

        # Show initial stats
        self.show_stats()

        # Then monitor in real-time
        self.log_message("�� Starting real-time monitoring...")
        self.log_message("💡 Press Ctrl+C to stop and view statistics")

        cycle_count = 0
        while self.running:
            time.sleep(30)  # Check every 30 seconds
            cycle_count += 1

            # Parse logs
            self.parse_auth_log()

            # Show stats every 10 cycles (5 minutes)
            if cycle_count % 10 == 0:
                self.show_stats()

        # Final stats before exit
        self.show_stats()


def main():
    print("🔐 SSH Monitor - Complete SSH Attempt Tracking System")
    print("=" * 60)

    # Check if running as root
    if os.geteuid() != 0:
        print("❌ This script must be run as root (use sudo)")
        print("💡 Run: sudo python3 ssh_monitor.py")
        sys.exit(1)

    # Check if required tools exist
    required_tools = ["tail", "curl"]
    for tool in required_tools:
        if subprocess.run(["which", tool], capture_output=True).returncode != 0:
            print(f"❌ Required tool not found: {tool}")
            print(f"�� Install with: sudo apt install {tool}")
            sys.exit(1)

    try:
        tracker = SSHTracker()
        tracker.run()
    except KeyboardInterrupt:
        print("\n🛑 SSH Monitor stopped by user")
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
