#!/bin/bash

################################################################################
# VM Health Report Script with Sendmail Email Support
# Modified: Add filesystem-availability based health check and per-filesystem HTML table
################################################################################

EMAIL_FROM="saurabhthakare0205@gmail.com"
EMAIL_RECIPIENT="saurabhthakare0205@gmail.com"
EMAIL_SUBJECT="VM Health Report - $(date '+%A, %B %d, %Y')"
REPORT_DIR="/tmp/vm-health-reports"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
REPORT_DATE=$(date '+%Y-%m-%d %H:%M:%S')
HTML_REPORT="$REPORT_DIR/vm_health_report_${TIMESTAMP}.html"
PDF_REPORT="$REPORT_DIR/vm_health_report_${TIMESTAMP}.pdf"
LOG_FILE="/var/log/vm-health-report.log"

# Filesystem availability threshold: minimum percent AVAILABLE required for healthy.
# Default: 70 (i.e., each filesystem must have >=70% of its capacity available)
FILESYSTEM_THRESHOLD_USE=70

THRESHOLD=60

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

CPU_USAGE=0
MEMORY_USAGE=0
DISK_USAGE=0
OVERALL_HEALTH="HEALTHY"
REASON=""
HOSTNAME_VM=$(hostname)

log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" >> "$LOG_FILE"
    if [ "$level" = "ERROR" ]; then
        echo -e "${RED}[${timestamp}] [${level}] ${message}${NC}"
    elif [ "$level" = "SUCCESS" ]; then
        echo -e "${GREEN}[${timestamp}] [${level}] ${message}${NC}"
    else
        echo "[${timestamp}] [${level}] ${message}"
    fi
}

check_dependencies() {
    if ! command -v sendmail &> /dev/null; then
    log_message "ERROR" "sendmail not found"
    return 1
fi

if ! command -v wkhtmltopdf &> /dev/null; then
    log_message "INFO" "wkhtmltopdf not available, skipping PDF conversion"
fi
    return 0
}

get_cpu_usage() {
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}' | cut -d'.' -f1)
    if [ -z "$CPU_USAGE" ] || [ "$CPU_USAGE" == "" ]; then
        CPU_USAGE=0
    fi
    [[ ! "$CPU_USAGE" =~ ^[0-9]+$ ]] && CPU_USAGE=0
    echo "$CPU_USAGE"
}

get_memory_usage() {
    MEMORY_USAGE=$(free | grep Mem | awk '{printf("%.0f", ($3 / $2) * 100)}')
    [[ ! "$MEMORY_USAGE" =~ ^[0-9]+$ ]] && MEMORY_USAGE=0
    echo "$MEMORY_USAGE"
}

get_disk_usage() {
    DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    [[ ! "$DISK_USAGE" =~ ^[0-9]+$ ]] && DISK_USAGE=0
    echo "$DISK_USAGE"
}

get_status_color() {
    local usage=$1
    if [ "$usage" -gt "$THRESHOLD" ]; then
        echo "#d32f2f"
    elif [ "$usage" -gt 40 ]; then
        echo "#f57c00"
    else
        echo "#388e3c"
    fi
}

get_status_text() {
    local usage=$1
    if [ "$usage" -gt "$THRESHOLD" ]; then
        echo "CRITICAL"
    elif [ "$usage" -gt 40 ]; then
        echo "WARNING"
    else
        echo "NORMAL"
    fi
}

# New: check filesystems' AVAILABLE percentage and build an HTML table.
# Excludes tmpfs and devtmpfs to avoid ephemeral mounts.
# Produces:
#  - OVERALL_HEALTH and REASON (UNHEALTHY if any filesystem avail% < FILESYSTEM_THRESHOLD_AVAIL)
#  - temporary file with table rows at /tmp/fs_rows_${TIMESTAMP}.html (inserted into HTML report)
check_filesystems() {
    local fs_temp="/tmp/fs_rows_${TIMESTAMP}.html"
    : > "$fs_temp"

    local -a unhealthy_list=()

    while read -r filesystem size used avail usep mountpoint
    do
        # Skip WSL virtual mounts
        case "$mountpoint" in
            /usr/lib/wsl/*|/mnt/wsl*|/run*|/dev*|/proc*|/sys*)
                continue
                ;;
        esac

        use_pct=$(echo "$usep" | tr -d '%')

        human_line=$(df -h -P | awk -v m="$mountpoint" '$6==m {print; exit}')

        human_size=$(echo "$human_line" | awk '{print $2}')
        human_used=$(echo "$human_line" | awk '{print $3}')
        human_avail=$(echo "$human_line" | awk '{print $4}')

        row_class="fs-normal"

        if [ "$use_pct" -gt "$FILESYSTEM_THRESHOLD_USE" ]; then
            row_class="fs-critical"
            unhealthy_list+=("${mountpoint} (${use_pct}%)")
        fi

        printf '<tr class="%s"><td>%s</td><td>%s</td><td style="text-align:right">%s</td><td style="text-align:right">%s</td><td style="text-align:right">%s%%</td></tr>\n' \
        "$row_class" \
        "$filesystem" \
        "$mountpoint" \
        "$human_size" \
        "$human_used" \
        "$use_pct" >> "$fs_temp"

    done < <(df -P | tail -n +2)

    if [ ${#unhealthy_list[@]} -gt 0 ]; then
        OVERALL_HEALTH="UNHEALTHY"
        REASON="Filesystem usage exceeded 70%: ${unhealthy_list[*]}"
    else
        OVERALL_HEALTH="HEALTHY"
        REASON="All filesystems are below or equal to 70% usage."
    fi

    FILESYSTEM_TABLE_FILE="$fs_temp"
}

determine_health_status() {
    # First and primary check: filesystem-availability based health (per your requirement).
    check_filesystems

    # If you want to combine with CPU/MEM/DISK checks, remove the 'return' below and
    # add merging logic (e.g., mark UNHEALTHY if either filesystems fail or metrics exceed thresholds).
    return
}

create_html_report() {
    local cpu_color=$(get_status_color "$CPU_USAGE")
    local memory_color=$(get_status_color "$MEMORY_USAGE")
    local disk_color=$(get_status_color "$DISK_USAGE")

    local cpu_status=$(get_status_text "$CPU_USAGE")
    local memory_status=$(get_status_text "$MEMORY_USAGE")
    local disk_status=$(get_status_text "$DISK_USAGE")

    cat > "$HTML_REPORT" << 'HTML_END'
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>VM Health Report</title>
<style>
body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
.container { max-width: 1000px; margin: 0 auto; background: white; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
.header { 
    background: #667eea;
    color: white;
    padding: 25px;
    text-align: center;
    border-radius: 8px 8px 0 0;
}
.header h1 { margin: 0; font-size: 24px; }
.header p { margin: 5px 0 0 0; font-size: 12px; opacity: 0.9; }
.content { padding: 25px; }
.info-box { background: #f9f9f9; padding: 15px; border-left: 4px solid #667eea; margin-bottom: 20px; border-radius: 4px; }
.info-row { display: flex; justify-content: space-between; margin: 8px 0; }
.info-label { font-weight: 600; color: #666; }
.info-value { color: #333; }
table { width: 100%; border-collapse: collapse; margin: 20px 0; }
th { background: #667eea; color: white; padding: 12px; text-align: left; font-size: 13px; }
td { padding: 12px; border-bottom: 1px solid #eee; }
tr:last-child td { border-bottom: none; }
.metric-name { font-weight: 500; }
.metric-value { font-size: 18px; font-weight: 600; }
.badge { display: inline-block; padding: 5px 10px; border-radius: 4px; font-weight: 600; font-size: 11px; color: white; }
.normal { background: #388e3c; }
.warning { background: #f57c00; }
.critical { background: #d32f2f; }
.status-box { margin-top: 25px; padding: 20px; border-radius: 6px; text-align: center; color: white; font-weight: 600; font-size: 16px; }
.healthy { background: #388e3c; }
.unhealthy { background: #d32f2f; }
.reason-box { margin-top: 15px; padding: 15px; background: #f0f0f0; border-left: 4px solid #667eea; border-radius: 4px; }
.reason-label { font-weight: 600; color: #333; margin-bottom: 8px; }
.reason-text { color: #555; line-height: 1.5; }

/* Filesystem table styling */
#fs-table { margin-top: 10px; }
#fs-table th, #fs-table td { padding: 10px; font-size: 13px; }
.fs-normal { background: #e8f5e9; } /* light green */
.fs-critical { background: #ffebee; } /* light red */
.fs-critical td { font-weight: 700; color: #b71c1c; }

/* Responsive */
@media (max-width: 700px) {
  .info-row { flex-direction: column; align-items: flex-start; }
}
.footer { background: #f5f5f5; padding: 15px; text-align: center; font-size: 11px; color: #666; border-top: 1px solid #ddd; border-radius: 0 0 8px 8px; }
</style>
</head>
<body>
<div class="container">
<div class="header">
<h1>Server Health Report</h1>
<p>Automated System Resource Analysis</p>
</div>
<div class="content">
<div class="info-box">
<div class="info-row">
<span class="info-label">Server Name:</span>
<span class="info-value">HOSTNAME_PLACEHOLDER</span>
</div>
<div class="info-row">
<span class="info-label">Report Date:</span>
<span class="info-value">DATE_PLACEHOLDER</span>
</div>
</div>

<table>
<thead>
<tr>
<th>Resource</th>
<th style="text-align: right;">Usage</th>
<th style="text-align: center;">Status</th>
</tr>
</thead>
<tbody>
<tr>
<td class="metric-name">CPU Usage</td>
<td style="text-align: right;"><span class="metric-value" style="color: CPU_COLOR_PLACEHOLDER;">CPU_VALUE_PLACEHOLDER%</span></td>
<td style="text-align: center;"><span class="badge CPU_STATUS_CLASS_PLACEHOLDER">CPU_STATUS_PLACEHOLDER</span></td>
</tr>
<tr>
<td class="metric-name">Memory Usage</td>
<td style="text-align: right;"><span class="metric-value" style="color: MEMORY_COLOR_PLACEHOLDER;">MEMORY_VALUE_PLACEHOLDER%</span></td>
<td style="text-align: center;"><span class="badge MEMORY_STATUS_CLASS_PLACEHOLDER">MEMORY_STATUS_PLACEHOLDER</span></td>
</tr>
<tr>
<td class="metric-name">Disk Usage (root)</td>
<td style="text-align: right;"><span class="metric-value" style="color: DISK_COLOR_PLACEHOLDER;">DISK_VALUE_PLACEHOLDER%</span></td>
<td style="text-align: center;"><span class="badge DISK_STATUS_CLASS_PLACEHOLDER">DISK_STATUS_PLACEHOLDER</span></td>
</tr>
</tbody>
</table>

<!-- Filesystem table -->
<h3>Filesystems Usages</h3>
<table id="fs-table" border="0" cellpadding="0" cellspacing="0">
<thead>
<tr>
<th>Filesystem</th>
<th>Mount</th>
<th style="text-align:right">Size</th>
<th style="text-align:right">Used</th>
<th style="text-align:right">Use %</th>
</tr>
</thead>
<tbody>
FILESYSTEM_TABLE_PLACEHOLDER
</tbody>
</table>

<div class="status-box OVERALL_CLASS_PLACEHOLDER">
Overall Status: OVERALL_HEALTH_PLACEHOLDER
</div>
<div class="reason-box">
<div class="reason-label">Health Assessment:</div>
<div class="reason-text">REASON_PLACEHOLDER</div>
</div>
</div>
<div class="footer">
<p>This report was automatically generated by VM Health Monitoring System</p>
</div>
</div>
</body>
</html>
HTML_END

    sed -i "s|HOSTNAME_PLACEHOLDER|$HOSTNAME_VM|g" "$HTML_REPORT"
    sed -i "s|DATE_PLACEHOLDER|$REPORT_DATE|g" "$HTML_REPORT"
    sed -i "s|CPU_VALUE_PLACEHOLDER|$CPU_USAGE|g" "$HTML_REPORT"
    sed -i "s|MEMORY_VALUE_PLACEHOLDER|$MEMORY_USAGE|g" "$HTML_REPORT"
    sed -i "s|DISK_VALUE_PLACEHOLDER|$DISK_USAGE|g" "$HTML_REPORT"
    sed -i "s|CPU_COLOR_PLACEHOLDER|$cpu_color|g" "$HTML_REPORT"
    sed -i "s|MEMORY_COLOR_PLACEHOLDER|$memory_color|g" "$HTML_REPORT"
    sed -i "s|DISK_COLOR_PLACEHOLDER|$disk_color|g" "$HTML_REPORT"
    sed -i "s|CPU_STATUS_PLACEHOLDER|$cpu_status|g" "$HTML_REPORT"
    sed -i "s|MEMORY_STATUS_PLACEHOLDER|$memory_status|g" "$HTML_REPORT"
    sed -i "s|DISK_STATUS_PLACEHOLDER|$disk_status|g" "$HTML_REPORT"
    sed -i "s|OVERALL_HEALTH_PLACEHOLDER|$OVERALL_HEALTH|g" "$HTML_REPORT"
    # Reason may contain characters; use | delimiter
    sed -i "s|REASON_PLACEHOLDER|$REASON|g" "$HTML_REPORT"

    local cpu_class="normal"
    [ "$CPU_USAGE" -gt 40 ] && [ "$CPU_USAGE" -le "$THRESHOLD" ] && cpu_class="warning"
    [ "$CPU_USAGE" -gt "$THRESHOLD" ] && cpu_class="critical"
    sed -i "s|CPU_STATUS_CLASS_PLACEHOLDER|$cpu_class|g" "$HTML_REPORT"

    local memory_class="normal"
    [ "$MEMORY_USAGE" -gt 40 ] && [ "$MEMORY_USAGE" -le "$THRESHOLD" ] && memory_class="warning"
    [ "$MEMORY_USAGE" -gt "$THRESHOLD" ] && memory_class="critical"
    sed -i "s|MEMORY_STATUS_CLASS_PLACEHOLDER|$memory_class|g" "$HTML_REPORT"

    local disk_class="normal"
    [ "$DISK_USAGE" -gt 40 ] && [ "$DISK_USAGE" -le "$THRESHOLD" ] && disk_class="warning"
    [ "$DISK_USAGE" -gt "$THRESHOLD" ] && disk_class="critical"
    sed -i "s|DISK_STATUS_CLASS_PLACEHOLDER|$disk_class|g" "$HTML_REPORT"

    local overall_class="healthy"
    [ "$OVERALL_HEALTH" = "UNHEALTHY" ] && overall_class="unhealthy"
    sed -i "s|OVERALL_CLASS_PLACEHOLDER|$overall_class|g" "$HTML_REPORT"

    # Insert the filesystem rows from temporary file into the placeholder position
    if [ -n "$FILESYSTEM_TABLE_FILE" ] && [ -f "$FILESYSTEM_TABLE_FILE" ]; then
        # Replace the placeholder line by reading the temp file into the HTML
        sed -i "/FILESYSTEM_TABLE_PLACEHOLDER/{
            r $FILESYSTEM_TABLE_FILE
            d
        }" "$HTML_REPORT"
        # Clean up temp file
        rm -f "$FILESYSTEM_TABLE_FILE"
    else
        # If no table rows, remove placeholder
        sed -i "s|FILESYSTEM_TABLE_PLACEHOLDER||g" "$HTML_REPORT"
    fi
}

convert_html_to_pdf() {

    if command -v wkhtmltopdf &> /dev/null; then

        wkhtmltopdf \
        --quiet \
        --margin-top 10mm \
        --margin-bottom 10mm \
        --margin-left 10mm \
        --margin-right 10mm \
        --page-size A4 \
        "$HTML_REPORT" \
        "$PDF_REPORT"

        if [ $? -eq 0 ]; then
            log_message "SUCCESS" "PDF report created"
            return 0
        fi
    fi


    # fallback: keep HTML report
    cp "$HTML_REPORT" "$PDF_REPORT"

    log_message "INFO" "PDF conversion skipped. HTML report used"

    return 0
}

send_email_with_sendmail() {

    if [ ! -f "$PDF_REPORT" ]; then
        log_message "ERROR" "PDF report missing"
        return 1
    fi

    local pdf_filename=$(basename "$PDF_REPORT")
    local email_file="/tmp/email_${TIMESTAMP}.txt"

    (
    echo "From: $EMAIL_FROM"
    echo "To: $EMAIL_RECIPIENT"
    echo "Subject: $EMAIL_SUBJECT"
    echo "MIME-Version: 1.0"
    echo 'Content-Type: multipart/mixed; boundary="BOUNDARY"'
    echo

    echo "--BOUNDARY"
    echo "Content-Type: text/plain; charset=UTF-8"
    echo
    echo "Dear Administrator,"
    echo
    echo "Please find attached VM Health Report."
    echo
    echo "Server Name : $HOSTNAME_VM"
    echo "CPU Usage   : $CPU_USAGE%"
    echo "Memory Usage: $MEMORY_USAGE%"
    echo "Disk Usage  : $DISK_USAGE%"
    echo "Status      : $OVERALL_HEALTH"
    echo
    echo "Regards,"
    echo "VM Health Monitoring System"
    echo

    echo "--BOUNDARY"
    echo "Content-Type: application/pdf; name=\"$pdf_filename\""
    echo "Content-Disposition: attachment; filename=\"$pdf_filename\""
    echo "Content-Transfer-Encoding: base64"
    echo

    base64 "$PDF_REPORT"

    echo
    echo "--BOUNDARY--"

    ) > "$email_file"


    /usr/sbin/sendmail -t < "$email_file"


    if [ $? -eq 0 ]; then
        log_message "SUCCESS" "Email sent successfully with PDF attachment"
        rm -f "$email_file"
        return 0
    else
        log_message "ERROR" "Failed to send email using sendmail"
        rm -f "$email_file"
        return 1
    fi
}

cleanup_old_reports() {
    find "$REPORT_DIR" -name "vm_health_report_*.html" -type f -mtime +30 -delete 2>/dev/null
    find "$REPORT_DIR" -name "vm_health_report_*.pdf" -type f -mtime +30 -delete 2>/dev/null
    log_message "INFO" "Cleaned up old reports"
}

mkdir -p "$REPORT_DIR"
mkdir -p "$(dirname "$LOG_FILE")"

log_message "INFO" "Starting VM Health Report Generation"
log_message "INFO" "Target Email: $EMAIL_RECIPIENT"

if ! check_dependencies; then
    log_message "ERROR" "Dependency check failed"
    exit 1
fi

CPU_USAGE=$(get_cpu_usage)
MEMORY_USAGE=$(get_memory_usage)
DISK_USAGE=$(get_disk_usage)

log_message "INFO" "Metrics - CPU: $CPU_USAGE%, Memory: $MEMORY_USAGE%, Disk: $DISK_USAGE%"

determine_health_status
log_message "INFO" "Health Status: $OVERALL_HEALTH - Reason: $REASON"

create_html_report
log_message "INFO" "HTML report created: $HTML_REPORT"

if convert_html_to_pdf; then
    log_message "INFO" "PDF created: $PDF_REPORT"
    if send_email_with_sendmail; then
        log_message "SUCCESS" "Report sent successfully"
    else
        log_message "ERROR" "Failed to send email"
    fi
else
    log_message "ERROR" "Failed to create PDF"
fi

cleanup_old_reports
log_message "INFO" "Completed"

exit 0
