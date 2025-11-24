# Dae Subscription Auto-Update Script

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![GitHub Issues](https://img.shields.io/github/issues/tuoro/dae-update-subscription)](https://github.com/tuoro/dae-update-subscription/issues)

## 📋 Project Overview

This script automates the configuration of **Dae** proxy tool's subscription update mechanism. Dae does not store subscription information natively and requires re-reading subscriptions on each startup. When subscription links are blocked or inaccessible, it fails to retrieve subscription and group configurations, affecting normal operation.

This script solves this problem by:
- ✅ Storing subscription files locally (`.sub` format)
- ✅ Periodically auto-updating subscription content
- ✅ Automatic retry mechanism on failure
- ✅ Systemd scheduled task management

---

## 🔧 System Requirements

### Operating System
- Linux system (Ubuntu, Debian, CentOS, Rocky Linux, etc.)
- Must support systemd (Debian 8+, Ubuntu 15.04+, CentOS 7+, etc.)

### Required Software
| Component | Description | Check Method |
|-----------|-------------|--------------|
| **curl** | Used to download subscription files | `which curl` |
| **systemd** | System daemon manager | `systemctl --version` |
| **bash** | Shell script interpreter | `bash --version` |
| **dae** | Proxy tool (must be pre-installed) | `dae --version` |

### Permission Requirements
- Requires **root** privileges (use `sudo`)
- Need read/write permissions for `/usr/local/etc/dae/` and `/usr/local/bin/` directories

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

### Verify Dependencies are Complete
```bash
# Check curl
which curl && curl --version

# Check systemd
systemctl --version

# Check dae
dae --version

# Check bash
bash --version
```

---

## 🚀 Quick Start

### Method 1: Direct Download and Run (Recommended)
```bash
# Download the script
curl -fsSL https://raw.githubusercontent.com/tuoro/dae-update-subscription/main/setup-dae-auto-update.sh -o setup-dae-auto-update.sh

# Grant execute permission
chmod +x setup-dae-auto-update.sh

# Run with root privileges
sudo ./setup-dae-auto-update.sh
```

### Method 2: Clone Repository
```bash
# Clone the repository
git clone https://github.com/tuoro/dae-update-subscription.git

# Enter directory
cd dae-update-subscription

# Grant execute permission
chmod +x setup-dae-auto-update.sh

# Run script
sudo ./setup-dae-auto-update.sh
```

### Method 3: Manual Creation
```bash
# Create and edit file directly
sudo nano setup-dae-auto-update.sh

# Paste script content from GitHub, then save (Ctrl+X → Y → Enter)

# Grant execute permission
chmod +x setup-dae-auto-update.sh

# Run script
sudo ./setup-dae-auto-update.sh
```

---

## ⚙️ Post-Installation Configuration

After running the script, follow these steps:

### Step 1: Edit Subscription List File
```bash
sudo nano /usr/local/etc/dae/sublist
```

**File Format** (one subscription per line, format: `name:URL`):
```
sub1:https://example.com/subscribe?token=abc123
sub2:https://another-service.com/api/sub?key=xyz789
sub3:https://third-provider.com/subscription?id=def456
```

**Notes**:
- Supports multiple subscription sources (sub1, sub2, sub3, etc.)
- The name part will be used to generate corresponding `.sub` files
- URL must be the complete subscription link
- Remove lines starting with `#` (comments)

### Step 2: Modify Dae Configuration File
```bash
sudo nano /usr/local/etc/dae/config.dae
```

**Find the `subscription` configuration block and modify it**:
```yaml
subscription {
    # Modify according to subscription names in sublist
    sub1:'file://sub1.sub'
    sub2:'file://sub2.sub'
    sub3:'file://sub3.sub'
}
```

**Important**: 
- The names in file paths must exactly match those in `sublist`
- Use single quotes around `file://` paths
- Remove any existing HTTP/HTTPS subscription URLs

### Step 3: Verify Configuration
```bash
# Check if sublist permissions are correct
ls -l /usr/local/etc/dae/sublist
# Output should display: -rw------- (600 permissions)

# Verify sublist content
cat /usr/local/etc/dae/sublist
```

---

## 🧪 Testing and Verification

### Manually Run Subscription Update Once
```bash
sudo systemctl start update-subs.service
```

### View Subscription Update Logs
```bash
# View logs in real-time
sudo journalctl -u update-subs.service -f

# View last 50 lines of logs
sudo journalctl -u update-subs.service -n 50

# View logs for specific time range
sudo journalctl -u update-subs.service --since "2 hours ago"
```

### Verify Subscription Files Were Generated
```bash
# Check if .sub files were generated
ls -lh /usr/local/etc/dae/*.sub

# View subscription file content (first 20 lines)
cat /usr/local/etc/dae/sub1.sub | head -20
```

### Check if Dae Correctly Loaded Subscriptions
```bash
# View dae logs
sudo journalctl -u dae -f

# Or restart dae
sudo systemctl restart dae

# Check dae status
sudo systemctl status dae
```

---

## 🕐 Timer Configuration

The script automatically creates the following scheduling rules:

| Trigger Condition | Description |
|------------------|------------|
| **15 minutes after system boot** | Initial auto-update of subscriptions |
| **Every 12 hours thereafter** | Regular periodic auto-update |

### Check Timer Status
```bash
# Check if timer is enabled and running
sudo systemctl status update-subs.timer

# View all scheduled tasks and next execution time
sudo systemctl list-timers update-subs.timer

# View detailed timer information
sudo systemctl show update-subs.timer
```

### Manually Modify Timer Rules

To change update frequency (e.g., update every 6 hours instead):

```bash
# Edit timer configuration
sudo nano /etc/systemd/system/update-subs.timer
```

Modify the following section:
```ini
[Timer]
OnBootSec=15min
OnUnitActiveSec=6h        # Change to 6h (6 hours), 3h, 24h, etc.
```

Reload and restart:
```bash
sudo systemctl daemon-reload
sudo systemctl restart update-subs.timer
```

---

## 🔍 Troubleshooting

### Issue 1: Script Execution Says "root privileges required"
```bash
# Make sure to run script with sudo
sudo ./setup-dae-auto-update.sh
```

### Issue 2: dae Not Detected
```bash
# Verify dae is properly installed
dae --version

# If not installed, please install dae first
# Installation guide: https://github.com/daeuniverse/dae
```

### Issue 3: Subscription Update Failed
```bash
# View detailed error logs
sudo journalctl -u update-subs.service -xe

# Possible causes:
# 1. Subscription link has expired or is invalid
# 2. Network connectivity issues
# 3. Firewall blocking outbound connections
# 4. Subscription server temporarily unavailable

# Manually test if subscription link is accessible
curl -v "https://your-subscription-url"
```

### Issue 4: systemd timer Not Auto-starting
```bash
# Check if timer is enabled
sudo systemctl list-unit-files | grep update-subs

# Output should show "enabled"

# If not enabled, manually enable it
sudo systemctl enable update-subs.timer
sudo systemctl start update-subs.timer
```

### Issue 5: Dae Cannot Read Local Subscription Files
```bash
# Check file permissions
ls -l /usr/local/etc/dae/*.sub

# Check file format
file /usr/local/etc/dae/sub1.sub

# Verify dae configuration syntax
sudo dae validate
```

### Issue 6: Subscription File Permissions Incorrect
```bash
# Fix permissions (should be 0600)
sudo chmod 0600 /usr/local/etc/dae/*.sub
sudo chmod 0600 /usr/local/etc/dae/sublist

# Verify ownership (should be root)
sudo chown root:root /usr/local/etc/dae/*.sub
sudo chown root:root /usr/local/etc/dae/sublist
```

### Issue 7: "curl: command not found"
```bash
# Install curl
sudo apt install curl      # Debian/Ubuntu
sudo yum install curl      # CentOS/RHEL
```

---

## 📊 How It Works

### Installation Script Workflow
```
Script Execution
  ├── Permission Check (root required)
  ├── Software Check (dae, systemd, curl)
  ├── Config Directory Creation (/usr/local/etc/dae)
  ├── Config File Backup (with timestamp)
  ├── Create Subscription Update Script (/usr/local/bin/update-dae-subs.sh)
  ├── Create systemd Service (/etc/systemd/system/update-subs.service)
  ├── Create systemd Timer (/etc/systemd/system/update-subs.timer)
  ├── Create Subscription List Template (/usr/local/etc/dae/sublist)
  ├── Reload systemd daemon
  └── Enable and Start Timer
       └── First run: 15 minutes after system boot
       └── Recurring: Every 12 hours
```

### Subscription Update Script Workflow
```
update-dae-subs.sh Execution
  ├── Enter Config Directory (/usr/local/etc/dae)
  ├── Get dae Version Info
  ├── Construct User-Agent Header
  ├── Read sublist File
  ├── For Each Subscription:
  │   ├── Download via curl (3 retries, 5s delay)
  │   ├── Save as .sub.new temporarily
  │   ├── Verify Download Success
  │   ├── Replace old .sub file
  │   └── Set Permissions to 0600
  ├── Execute 'dae reload' to Apply Changes
  └── Exit with Success/Failure Status
```

---

## 📝 Created Files

List of files created by the script:

| File Path | Permissions | Description |
|-----------|------------|-------------|
| `/usr/local/bin/update-dae-subs.sh` | 755 | Subscription update execution script |
| `/etc/systemd/system/update-subs.service` | 644 | systemd service file |
| `/etc/systemd/system/update-subs.timer` | 644 | systemd timer file |
| `/usr/local/etc/dae/sublist` | 600 | Subscription link list (created as template) |
| `/usr/local/etc/dae/*.sub` | 600 | Downloaded subscription files (auto-generated) |
| `/usr/local/etc/dae/config.dae.backup.*` | 644 | Backup of original config file (if exists) |

---

## 🔐 Security Recommendations

1. **Permission Management**
   - `sublist` file is set to `600` permissions (owner read/write only)
   - `.sub` files are set to `600` permissions
   - Subscription URLs typically contain tokens—do not share publicly
   - Never commit `sublist` to public repositories

2. **Backup Strategy**
   - Script automatically backs up config files with timestamps
   - Backup file location: `/usr/local/etc/dae/`
   - Periodically verify backup files are complete
   - Keep at least 3 recent backups

3. **Log Auditing**
   - Regularly check systemd logs for errors
   - Monitor failed subscription updates
   - Set up alerts for repeated failures
   - Review logs: `journalctl -u update-subs.service --since "7 days ago"`

4. **Network Security**
   - Ensure subscription URLs use HTTPS protocol
   - Avoid using this script on unsecured networks
   - Regularly rotate subscription tokens
   - Use firewall rules to restrict outbound connections if needed

---

## 🔄 Uninstall or Reset

### Completely Remove Auto-update Feature
```bash
# Stop and disable timer
sudo systemctl stop update-subs.timer
sudo systemctl disable update-subs.timer

# Delete systemd files
sudo rm /etc/systemd/system/update-subs.service
sudo rm /etc/systemd/system/update-subs.timer

# Delete update script
sudo rm /usr/local/bin/update-dae-subs.sh

# Reload systemd
sudo systemctl daemon-reload

# Optional: Remove subscription files
sudo rm /usr/local/etc/dae/*.sub
sudo rm /usr/local/etc/dae/sublist
```

### Restore Configuration to Original State
```bash
# View available backup files
ls -la /usr/local/etc/dae/*.backup*

# Restore from most recent backup
LATEST_BACKUP=$(ls -t /usr/local/etc/dae/config.dae.backup.* | head -1)
sudo cp "$LATEST_BACKUP" /usr/local/etc/dae/config.dae

# Restart dae
sudo systemctl restart dae
```

---

## 📚 Related Resources

- [Dae Official Repository](https://github.com/daeuniverse/dae)
- [Dae Documentation](https://github.com/daeuniverse/dae/wiki)
- [systemd Timer Documentation](https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html)
- [curl Manual](https://curl.se/docs/)

---

## 🤝 Frequently Asked Questions

**Q: Can the script run on macOS?**  
A: No. macOS uses launchd instead of systemd. The script would need to be adapted to use launchd for scheduled tasks.

**Q: Can I run multiple Dae instances simultaneously?**  
A: Yes, but you need to configure separate configuration directories for each instance and modify the script paths accordingly.

**Q: What subscription file size should I be concerned about performance?**  
A: Most subscription files are 1-10 MB. Performance is typically not an issue unless files exceed 50 MB.

**Q: How can I verify subscription content completeness?**  
A: Check the `.sub` file's modification time and size with `ls -lh`, or review update logs with `journalctl`.

**Q: Does it support authenticated subscription links (username/password)?**  
A: Yes. You can include authentication info in the URL format: `https://user:pass@example.com/sub`

**Q: Can I use different update intervals for different subscriptions?**  
A: The current implementation updates all subscriptions together. To achieve different intervals, you would need to create separate services and timers.

**Q: What happens if a subscription download fails?**  
A: The script continues updating other subscriptions and marks the overall operation as failed. The old `.sub` file remains unchanged for failed downloads.

**Q: Can I run this on a system without systemd?**  
A: No, this script specifically requires systemd. For systems using other init systems (like OpenRC or runit), you would need to adapt the scheduling mechanism.

---

## 🐛 Reporting Issues

If you encounter problems:

1. **Gather Information**
   ```bash
   # System information
   uname -a
   
   # Service logs
   sudo journalctl -u update-subs.service -n 100 --no-pager
   
   # Timer status
   sudo systemctl status update-subs.timer
   ```

2. **Create an Issue**
   - Visit: https://github.com/tuoro/dae-update-subscription/issues
   - Provide the information gathered above
   - Include your configuration (with sensitive tokens removed)
   - Describe the expected vs actual behavior

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes:

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
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

**Last Updated**: 2025-11-24  
**Version**: 1.0.0  
**Maintainer**: [@tuoro](https://github.com/tuoro)
