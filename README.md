# 🖥️ Server Health Report Automation Script

A Bash-based automation script that monitors Linux server health, generates an HTML and PDF report, evaluates filesystem health, and automatically emails the report to administrators. The script can also be scheduled using **Cron** for periodic execution.

---

# 📌 Project Overview

Monitoring server health is an important task for every Linux Administrator and DevOps Engineer. Instead of manually checking CPU, Memory, Disk usage, and filesystem utilization every week, this project automates the complete process.

The script performs the following tasks:

* Collects CPU Usage
* Collects Memory Usage
* Collects Root Disk Usage
* Checks all mounted filesystems
* Determines overall server health
* Generates an HTML Report
* Converts HTML into PDF
* Emails the PDF report automatically
* Stores execution logs
* Can run automatically using Cron

---

# 🏗 Project Architecture

```
                    +--------------------+
                    |  Cron Scheduler    |
                    +---------+----------+
                              |
                              |
                              v
                  +-------------------------+
                  | server_health_report.sh |
                  +-----------+-------------+
                              |
          -----------------------------------------------
          |             |              |                |
          v             v              v                v
      CPU Usage     Memory Usage   Disk Usage   Filesystem Usage
          |             |              |                |
          -----------------------------------------------
                              |
                              v
                 Determine Overall Health
                              |
                              v
                  Generate HTML Report
                              |
                              v
                  Convert HTML → PDF
                              |
                              v
                 Send Email using SSMTP
                              |
                              v
                   Store Execution Logs
```

---

# ✨ Features

* Linux Server Health Monitoring
* HTML Report Generation
* PDF Report Generation
* Automatic Email Notification
* Filesystem Health Validation
* Detailed Logging
* Cron Job Scheduling
* Easy Customization
* Lightweight Bash Script

---

# 📁 Project Structure

```
ServerReportAutomationScript/

│
├── copilot/server_health_report.sh
├── copilot/screenshots/
|       ├── report.png
|       └── email.png
├── README.md
```

---

# ⚙ Prerequisites

Operating System

* Ubuntu
* Debian
* Linux VM
* WSL (for testing)

Required Packages

```
wkhtmltopdf
ssmtp
mailutils
base64
cron
```

Install them

```bash
sudo apt update

sudo apt install wkhtmltopdf

sudo apt install ssmtp

sudo apt install mailutils

sudo apt install cron
```

---

# 📧 Gmail Configuration

Configure Gmail SMTP inside

```
/etc/ssmtp/ssmtp.conf
```

Example

```ini
root=yourmail@gmail.com

mailhub=smtp.gmail.com:465

AuthUser=yourmail@gmail.com

AuthPass=YOUR_APP_PASSWORD

UseTLS=YES

UseSTARTTLS=NO

FromLineOverride=YES
```

> Never commit your Gmail App Password to GitHub.

---

# 🚀 Script Execution Flow

The script follows the below sequence.

---

## Step 1 – Initialize Variables

The script initializes

* Email Details
* Report Directory
* Timestamp
* Log File
* HTML Report Name
* PDF Report Name

---

## Step 2 – Check Dependencies

The script verifies that

* wkhtmltopdf is installed
* ssmtp is installed

If any dependency is missing, execution stops.

---

## Step 3 – Collect System Metrics

The script collects

### CPU Usage

```
top
```

Example

```
CPU = 5%
```

---

### Memory Usage

```
free
```

Example

```
Memory = 42%
```

---

### Root Disk Usage

```
df /
```

Example

```
Disk = 18%
```

---

## Step 4 – Check Filesystem Usage

The script checks every mounted filesystem using

```
df -P
```

Example

```
Filesystem      Use%

/

6%

/mnt/c

93%

/mnt/d

49%
```

---

### Health Rule

If **any filesystem has Use% greater than 70%**

```
Overall Status = UNHEALTHY
```

Otherwise

```
Overall Status = HEALTHY
```

Example

| Filesystem | Use% | Status    |
| ---------- | ---- | --------- |
| /          | 6    | Healthy   |
| /mnt/c     | 93   | Unhealthy |
| /mnt/d     | 49   | Healthy   |

Overall Status

```
UNHEALTHY
```

Reason

```
Filesystem usage exceeded 70%
```

---

## Step 5 – Generate HTML Report

The script creates an HTML report containing

* Server Name
* Report Date
* CPU Usage
* Memory Usage
* Disk Usage
* Filesystem Table
* Overall Health
* Health Reason

---

## Step 6 – Convert HTML into PDF

The script uses

```
wkhtmltopdf
```

to generate

```
vm_health_report.pdf
```

---

## Step 7 – Send Email

The PDF report is converted to Base64 and attached to an email.

The email contains

* Subject
* Summary
* PDF Attachment

The email is sent using Gmail SMTP.

---

## Step 8 – Logging

Every execution is recorded in

```
/var/log/vm-health-report.log
```

Example

```
[INFO] Starting Script

[INFO] CPU : 3%

[INFO] Memory : 32%

[SUCCESS] PDF Created

[SUCCESS] Email Sent

[INFO] Completed
```

---

# 📄 Generated Report

The generated report contains

✔ CPU Usage

✔ Memory Usage

✔ Disk Usage

✔ Filesystem Usage

✔ Overall Status

✔ Health Reason

✔ Report Timestamp

---

# 🟢 Health Evaluation Logic

| Condition                | Status    |
| ------------------------ | --------- |
| All filesystem Use% ≤ 70 | HEALTHY   |
| Any filesystem Use% > 70 | UNHEALTHY |

---

# 📅 Automating with Cron

Make the script executable

```bash
chmod +x server_health_report.sh
```

Open Cron

```bash
sudo crontab -e
```

Run every Saturday at 7:40 AM

```cron
40 7 * * 6 /root/copilot/server_health_report.sh >> /var/log/vm-health-cron.log 2>&1
```

Cron Format

```
* * * * *

| | | | |

| | | | +----- Day of Week

| | | +------- Month

| | +--------- Day

| +----------- Hour

+------------- Minute
```

Example

```
40 7 * * 6
```

means

```
Every Saturday

07:40 AM
```

Check cron

```bash
sudo crontab -l
```

Verify cron service

```bash
sudo systemctl status cron
```

Start Cron

```bash
sudo systemctl enable cron

sudo systemctl start cron
```

---

# ▶ Run Manually

```bash
chmod +x server_health_report.sh

./server_health_report.sh
```

---

# 📂 Output Files

```
/tmp/vm-health-reports/

├── vm_health_report.html

└── vm_health_report.pdf
```

---

# 📝 Log File

```
/var/log/vm-health-report.log
```

---

# 🔧 Technologies Used

* Bash Shell Scripting
* Linux
* Cron
* HTML
* CSS
* wkhtmltopdf
* SSMTP
* Gmail SMTP
* Base64 Encoding

---

# 🚀 Future Enhancements

* AWS SES Email Integration
* Slack Notifications
* Microsoft Teams Alerts
* CloudWatch Integration
* Prometheus Metrics
* Grafana Dashboard
* Multi-server Monitoring
* CSV Report Export
* Database Storage
* Docker Support

---

# 👨‍💻 Author

**Saurabh Thakre**

---

# ⭐ Summary

This project automates Linux server health monitoring by collecting CPU, Memory, Disk, and Filesystem metrics. It evaluates server health based on filesystem utilization, generates an HTML and PDF report, emails the report automatically using Gmail SMTP, logs every execution, and supports scheduled execution through Cron. The solution reduces manual monitoring effort and provides administrators with regular health reports in an easy-to-read format.
