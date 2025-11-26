# Dae Auto-Update Scripts

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![GitHub Issues](https://img.shields.io/github/issues/tuoro/dae-update-subscription)](https://github.com/tuoro/dae-update-subscription/issues)

## 📋 Project Overview

This repository contains automated update scripts for **Dae** proxy tool:

1. **Subscription Auto-Update** - Automatically updates and stores subscription configurations
2. **GeoIP/GeoSite Auto-Update** - Automatically updates GeoIP and GeoSite database files

### Why These Scripts?

**Subscription Updates:**
- Dae doesn't store subscription information natively
- Requires re-reading subscriptions on each startup
- When subscription links are blocked, configurations become inaccessible
- Solution: Store subscriptions locally and update periodically

**GeoIP/GeoSite Updates:**
- Routing rules rely on up-to-date geographic data
- Manual updates are tedious and error-prone
- Solution: Automated daily updates with SHA256 verification and intelligent retry mechanism

---

## 🔧 System Requirements

### Operating System
- Linux system (Ubuntu, Debian, CentOS, Rocky Linux, etc.)
- Must support systemd (Debian 8+, Ubuntu 15.04+, CentOS 7+, etc.)

### Required Software
| Component | Description | Check Method |
|-----------|-------------|--------------|
| **curl** | Download files | `which curl` |
| **systemd** | System daemon manager | `systemctl --version` |
| **bash** | Shell interpreter | `bash --version` |
| **dae** | Proxy tool (must be pre-installed) | `dae --version` |

### Permission Requirements
- Requires **root** privileges (use `sudo`)
- Need read/write permissions for `/usr/local/etc/dae/` and `/usr/local/bin/`

---

## 📦 Dependency Installation

### Debian / Ubuntu
```bash
sudo apt update
sudo apt install -y curl systemd
```

### CentOS / Rocky Linux
```bash
sudo yum install -y curl systemd
```

---

## 🚀 Feature 1: Subscription Auto-Update

### Overview
Automatically downloads and stores Dae subscription configurations locally, with periodic updates.

### Quick Start

#### Method 1: Direct Download (Recommended)
```bash
# Download and run
curl -L https://raw.githubusercontent.com/tuoro/dae-update-subscription/main/setup-dae-auto-update.sh -o setup-dae-auto-update.sh
chmod +x setup-dae-auto-update.sh
sudo ./setup-dae-auto-update.sh
```

#### Method 2: Clone Repository
```bash
git clone https://github.com/tuoro/dae-update-subscription.git
cd dae-update-subscription
chmod +x setup-dae-auto-update.sh
sudo ./setup-dae-auto-update.sh
```

### Post-Installation Configuration

#### Step 1: Edit Subscription List
```bash
sudo nano /usr/local/etc/dae/sublist
```

Format (one per line: `name:URL`):
```
sub1:https://example.com/subscribe?token=abc123
sub2:https://another-service.com/api/sub?key=xyz789
```

#### Step 2: Update Dae Config
```bash
sudo nano /usr/local/etc/dae/config.dae
```

Modify the `subscription` block:
```yaml
subscription {
    sub1:'file://sub1.sub'
    sub2:'file://sub2.sub'
}
```

### Schedule
- **First run**: 15 minutes after system boot
- **Regular updates**: Every 12 hours

### Common Commands
```bash
# Manual update
sudo systemctl start update-subs.service

# View logs
sudo journalctl -u update-subs.service -f

# Check timer status
sudo systemctl status update-subs.timer

# View next execution time
sudo systemctl list-timers update-subs.timer
```

---

## 🌍 Feature 2: GeoIP/GeoSite Auto-Update

### Overview
Automatically downloads and updates GeoIP and GeoSite database files from official sources with SHA256 verification and intelligent retry mechanism.

### Features
- ✅ **SHA256 Verification**: Ensures file integrity before and after download
- ✅ **Smart Updates**: Only downloads when new version available (compares SHA256)
- ✅ **Intelligent Retry**: 5 retries with 10-second intervals for reliable downloads
- ✅ **Auto Reload**: Automatically reloads Dae service after updates
- ✅ **GitHub Official Source**: Uses Loyalsoldier/v2ray-rules-dat repository
- ✅ **No Backup Clutter**: Lightweight with no backup file storage

### Quick Start

```bash
# Download and run
curl -L https://raw.githubusercontent.com/tuoro/dae-update-subscription/main/setup-geodata-update.sh -o setup-geodata-update.sh
chmod +x setup-geodata-update.sh
sudo ./setup-geodata-update.sh
```

### Schedule
- **Daily execution**: Every day at 8:00 AM
- **Persistent**: If system was off at scheduled time, runs immediately on boot

### Data Sources (GitHub Official)
- **GeoIP**: `https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat`
- **GeoSite**: `https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat`
- **SHA256 Checksums**: Automatically downloaded and verified

### File Locations
- **Data files**: `/usr/local/share/dae/`
  - `geoip.dat` - IP geolocation database
  - `geosite.dat` - Domain classification database

### Retry Configuration
```
重试次数: 5 次
重试间隔: 10 秒
连接超时: 30 秒
总超时时间: 120 秒
```

### Common Commands
```bash
# Manual update
sudo systemctl start update-geodata.service

# View logs in real-time
sudo journalctl -u update-geodata.service -f

# Check timer status
sudo systemctl status update-geodata.timer

# View next execution time
sudo systemctl list-timers update-geodata.timer

# View last 50 log lines
sudo journalctl -u update-geodata.service -n 50
```

### Modify Update Time

To change execution time (e.g., to 3:00 AM):

```bash
# Edit timer
sudo nano /etc/systemd/system/update-geodata.timer
```

Change to:
```ini
[Timer]
OnCalendar=*-*-* 03:00:00
Persistent=true
```

Reload:
```bash
sudo systemctl daemon-reload
sudo systemctl restart update-geodata.timer
```

### Update Workflow

```
Update Process
  ├── Check local file exists
  ├── Download remote SHA256 checksum (with retry)
  ├── Compare with local file SHA256
  │   ├── Match → Skip update (already latest)
  │   └── Different → Proceed with download
  ├── Download new file with enhanced retry mechanism
  │   ├── Retry up to 5 times on failure
  │   ├── 10 second delay between retries
  │   └── 120 second total timeout per attempt
  ├── Verify downloaded file SHA256
  │   ├── Pass → Continue
  │   └── Fail → Delete and exit with error
  ├── Replace with new file
  ├── Set correct permissions (644)
  └── Reload Dae service
```

---

## 📊 Script Comparison

| Feature | Subscription Update | GeoData Update |
|---------|-------------------|----------------|
| **Purpose** | Update proxy subscriptions | Update routing databases |
| **Update Frequency** | Every 12 hours | Daily at 8:00 AM |
| **Data Source** | User-provided URLs | GitHub official releases |
| **Verification** | File size check | SHA256 checksum |
| **Smart Update** | No (always downloads) | Yes (only when changed) |
| **Retry Mechanism** | Basic | Enhanced (5 retries, 10s interval) |
| **Connection Timeout** | 30s | 30s |
| **Total Timeout** | 60s | 120s |
| **Backup** | Yes (timestamped) | No (lightweight) |
| **File Location** | `/usr/local/etc/dae/` | `/usr/local/share/dae/` |

---

## 🔍 Troubleshooting

### Common Issues for Both Scripts

#### Issue 1: "root privileges required"
```bash
# Always use sudo
sudo ./setup-xxx.sh
```

#### Issue 2: "curl: command not found"
```bash
# Install curl
sudo apt install curl      # Debian/Ubuntu
sudo yum install curl      # CentOS/RHEL
```

#### Issue 3: Timer not auto-starting
```bash
# Check if enabled
sudo systemctl list-unit-files | grep update

# Enable manually if needed
sudo systemctl enable update-subs.timer
sudo systemctl enable update-geodata.timer
```

### Subscription-Specific Issues

#### Invalid subscription URL
```bash
# Test URL manually
curl -v "https://your-subscription-url"

# Check sublist format
cat /usr/local/etc/dae/sublist
```

#### Dae not loading subscriptions
```bash
# Verify file permissions
ls -l /usr/local/etc/dae/*.sub

# Check Dae config syntax
sudo dae validate
```

### GeoData-Specific Issues

#### Download keeps failing despite retries
```bash
# Check detailed logs
sudo journalctl -u update-geodata.service -n 100

# Test network connectivity
curl --connect-timeout 30 --max-time 120 -I https://github.com

# Try manual download with same retry settings
curl -L --connect-timeout 30 --max-time 120 --retry 5 --retry-delay 10 \
  https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat \
  -o /tmp/test-geoip.dat

# Check if GitHub is accessible
ping github.com
```

#### SHA256 verification failed
```bash
# Check logs for details
sudo journalctl -u update-geodata.service | grep "SHA256"

# This usually indicates:
# - Corrupted download (retry will handle)
# - Incomplete transfer (extended timeout helps)
# - Network issue during download (5 retries should resolve)

# Manual verification
curl -L https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat.sha256sum
sha256sum /usr/local/share/dae/geoip.dat
```

#### Files not updating
```bash
# Check if already latest version
sudo journalctl -u update-geodata.service | grep "已是最新版本"

# Force update by removing local files
sudo rm /usr/local/share/dae/geoip.dat
sudo rm /usr/local/share/dae/geosite.dat
sudo systemctl start update-geodata.service
```

#### Service fails immediately
```bash
# Check for syntax errors
bash -n /usr/local/bin/update-dae-geodata.sh

# Run manually to see detailed errors
sudo /usr/local/bin/update-dae-geodata.sh

# Check systemd service status
sudo systemctl status update-geodata.service -l
```

---

## 📝 Created Files

### Subscription Update Files
| File Path | Permissions | Description |
|-----------|------------|-------------|
| `/usr/local/bin/update-dae-subs.sh` | 755 | Subscription update script |
| `/etc/systemd/system/update-subs.service` | 644 | systemd service |
| `/etc/systemd/system/update-subs.timer` | 644 | systemd timer |
| `/usr/local/etc/dae/sublist` | 600 | Subscription URL list |
| `/usr/local/etc/dae/*.sub` | 600 | Downloaded subscriptions |
| `/usr/local/etc/dae/backup/*.sub.*` | 600 | Subscription backups (timestamped) |

### GeoData Update Files
| File Path | Permissions | Description |
|-----------|------------|-------------|
| `/usr/local/bin/update-dae-geodata.sh` | 755 | GeoData update script |
| `/etc/systemd/system/update-geodata.service` | 644 | systemd service |
| `/etc/systemd/system/update-geodata.timer` | 644 | systemd timer |
| `/usr/local/share/dae/geoip.dat` | 644 | GeoIP database |
| `/usr/local/share/dae/geosite.dat` | 644 | GeoSite database |

---

## 🔐 Security Recommendations

1. **File Permissions**
   - Subscription files: `600` (owner only)
   - GeoData files: `644` (world-readable)
   - Never commit `sublist` to public repositories

2. **URL Security**
   - Use HTTPS for all subscription URLs
   - Regularly rotate subscription tokens
   - Verify GeoData SHA256 checksums (automatic)

3. **Network Security**
   - Ensure subscription URLs use HTTPS protocol
   - Avoid using this script on unsecured networks
   - Regularly rotate subscription tokens

4. **Log Monitoring**
   ```bash
   # Check for errors in last 7 days
   sudo journalctl -u update-subs.service --since "7 days ago" | grep ERROR
   sudo journalctl -u update-geodata.service --since "7 days ago" | grep ERROR
   
   # Check retry patterns
   sudo journalctl -u update-geodata.service | grep "已重试"
   ```

---

## 🔄 Uninstall

### Remove Subscription Auto-Update
```bash
sudo systemctl stop update-subs.timer
sudo systemctl disable update-subs.timer
sudo rm /etc/systemd/system/update-subs.{service,timer}
sudo rm /usr/local/bin/update-dae-subs.sh
sudo systemctl daemon-reload
```

### Remove GeoData Auto-Update
```bash
sudo systemctl stop update-geodata.timer
sudo systemctl disable update-geodata.timer
sudo rm /etc/systemd/system/update-geodata.{service,timer}
sudo rm /usr/local/bin/update-dae-geodata.sh
sudo systemctl daemon-reload
```

---

## 🤝 Frequently Asked Questions

**Q: Can I run both scripts together?**  
A: Yes! They are independent and designed to work alongside each other.

**Q: Why use local subscription files?**  
A: Prevents service disruption when subscription URLs are blocked or unavailable.

**Q: How often should GeoIP/GeoSite be updated?**  
A: Daily is sufficient. These databases update infrequently (weekly to monthly).

**Q: What happens if SHA256 verification fails?**  
A: The corrupted file is automatically deleted and old version remains. Script will retry up to 5 times with 10-second intervals.

**Q: Why does download sometimes fail?**  
A: GitHub may occasionally be slow or rate-limited. The enhanced retry mechanism handles this:
- 5 retry attempts
- 10 second delay between retries
- 120 second timeout per attempt
- This provides up to 10+ minutes of retry time

**Q: Can I use different data sources for GeoIP/GeoSite?**  
A: Yes, but you'll need to modify the URLs in `/usr/local/bin/update-dae-geodata.sh`.

**Q: Will updates interrupt active connections?**  
A: No. Dae reload is graceful and doesn't drop existing connections.

**Q: Can I run on systems without systemd?**  
A: No. These scripts specifically require systemd. For other init systems, you'd need to adapt the scheduling mechanism.

**Q: How much disk space do files use?**  
A: 
- GeoData files: ~10-20 MB each (no backups)
- Subscription files: Varies by subscription size
- Subscription backups: Kept for last 5 updates

**Q: Why remove backup for GeoData but keep for subscriptions?**  
A: GeoData files are versioned on GitHub and easily re-downloadable. Subscriptions may change or become unavailable, so backups are valuable.

**Q: Can I adjust the retry settings?**  
A: Yes, edit `/usr/local/bin/update-dae-geodata.sh` and modify:
```bash
CURL_RETRY_TIMES=5      # Number of retries
CURL_RETRY_DELAY=10     # Seconds between retries
CURL_TIMEOUT=120        # Total timeout per attempt
```

---

## 📚 Related Resources

- [Dae Official Repository](https://github.com/daeuniverse/dae)
- [Dae Documentation](https://github.com/daeuniverse/dae/wiki)
- [Dae Installer](https://github.com/daeuniverse/dae-installer)
- [Loyalsoldier GeoData](https://github.com/Loyalsoldier/v2ray-rules-dat)
- [systemd Timer Documentation](https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html)

---

## 🐛 Reporting Issues

If you encounter problems:

1. **Gather Information**
   ```bash
   # System info
   uname -a
   
   # Service logs (choose relevant service)
   sudo journalctl -u update-subs.service -n 100 --no-pager
   sudo journalctl -u update-geodata.service -n 100 --no-pager
   
   # Timer status
   sudo systemctl status update-subs.timer
   sudo systemctl status update-geodata.timer
   
   # Check retry patterns
   sudo journalctl -u update-geodata.service | grep -E "(重试|retry)"
   ```

2. **Create an Issue**
   - Visit: https://github.com/tuoro/dae-update-subscription/issues
   - Provide logs and system information
   - Include configuration (remove sensitive tokens)
   - Describe expected vs actual behavior
   - Mention if retries are happening

---

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

This project is open source and available under the MIT License.

---

## 💬 Support

- **GitHub Issues**: [Report bugs or request features](https://github.com/tuoro/dae-update-subscription/issues)
- **Discussions**: [Ask questions and share ideas](https://github.com/tuoro/dae-update-subscription/discussions)

---

## ⭐ Star History

If this project helped you, please consider giving it a star! ⭐

---

## 📋 Changelog

### Version 2.1.0 (2025-11-26)
- **Enhanced Retry Mechanism**: Increased to 5 retries with 10-second intervals
- **Extended Timeout**: Total timeout increased to 120 seconds per attempt
- **Removed Backup**: Simplified GeoData updates (no local backups)
- **Better Logging**: Added retry configuration output in logs
- **Fixed Timer**: Corrected OnCalendar to single entry (8:00 AM only)

### Version 2.0.0
- Initial release with subscription and GeoData auto-update

---

**Last Updated**: 2025-11-26  
**Version**: 2.1.0  
**Maintainer**: [@tuoro](https://github.com/tuoro)
