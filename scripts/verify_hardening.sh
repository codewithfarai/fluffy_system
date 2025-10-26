#!/bin/bash
# Fluffy System Security Hardening Verification Script
# Enhanced version for High Availability deployment
# Usage: ./verify_hardening.sh [hostname]

set -e

TARGET_HOST="${1:-}"
SSH_USER="root"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Check if running locally or remotely
if [[ -z "$TARGET_HOST" ]]; then
    echo -e "${BLUE}Running verification locally...${NC}"
    SSH_CMD=""
else
    echo -e "${BLUE}Running verification on remote host: $TARGET_HOST${NC}"
    SSH_CMD="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 $SSH_USER@$TARGET_HOST"
fi

# Function to run commands (local or remote)
run_cmd() {
    if [[ -z "$SSH_CMD" ]]; then
        eval "$1"
    else
        $SSH_CMD "$1"
    fi
}

# Function to print test results
print_result() {
    local test_name="$1"
    local status="$2"
    local details="$3"
    
    if [[ "$status" == "PASS" ]]; then
        echo -e "${GREEN}✓ PASS${NC} - $test_name"
    elif [[ "$status" == "FAIL" ]]; then
        echo -e "${RED}✗ FAIL${NC} - $test_name"
    else
        echo -e "${YELLOW}⚠ WARN${NC} - $test_name"
    fi
    
    if [[ -n "$details" ]]; then
        echo -e "  ${CYAN}$details${NC}"
    fi
    echo ""
}

echo ""
echo "=========================================="
echo "Security Hardening Verification Report"
echo "Fluffy System - High Availability"
echo "=========================================="
echo ""

# System Information (show first)
echo -e "${BLUE}[0] System Information${NC}"
echo "----------------------------------------"
HOSTNAME=$(run_cmd "hostname" 2>/dev/null || echo "Unknown")
KERNEL=$(run_cmd "uname -r" 2>/dev/null || echo "Unknown")
UPTIME=$(run_cmd "uptime -p" 2>/dev/null || echo "Unknown")
OS_VERSION=$(run_cmd "cat /etc/os-release | grep PRETTY_NAME | cut -d'\"' -f2" 2>/dev/null || echo "Unknown")
echo -e "  ${CYAN}Hostname:${NC} $HOSTNAME"
echo -e "  ${CYAN}OS:${NC} $OS_VERSION"
echo -e "  ${CYAN}Kernel:${NC} $KERNEL"
echo -e "  ${CYAN}Uptime:${NC} $UPTIME"
echo ""

# Check if node initialization completed
echo -e "${BLUE}[1] Node Initialization Status${NC}"
echo "----------------------------------------"

if run_cmd "test -f /tmp/node-init-complete" 2>/dev/null; then
    print_result "Node initialization marker" "PASS" "Initialization completed successfully"
    
    # Read node info
    NODE_INFO=$(run_cmd "cat /tmp/node-info 2>/dev/null" || echo "")
    if [[ -n "$NODE_INFO" ]]; then
        echo -e "${CYAN}Node Configuration:${NC}"
        echo "$NODE_INFO" | while read line; do
            echo "  $line"
        done
        echo ""
    fi
else
    print_result "Node initialization marker" "FAIL" "Node initialization did not complete or marker missing"
fi

# SSH Hardening Checks
echo -e "${BLUE}[2] SSH Configuration Hardening${NC}"
echo "----------------------------------------"

# Check if SSH config exists
if run_cmd "test -f /etc/ssh/sshd_config" 2>/dev/null; then
    print_result "SSH configuration file" "PASS" "/etc/ssh/sshd_config exists"
else
    print_result "SSH configuration file" "FAIL" "/etc/ssh/sshd_config not found"
fi

# Check PermitRootLogin
ROOT_LOGIN=$(run_cmd "grep -E '^PermitRootLogin' /etc/ssh/sshd_config | awk '{print \$2}'" 2>/dev/null || echo "not-set")
if [[ "$ROOT_LOGIN" == "prohibit-password" ]] || [[ "$ROOT_LOGIN" == "without-password" ]]; then
    print_result "PermitRootLogin" "PASS" "Set to: $ROOT_LOGIN (keys only)"
elif [[ "$ROOT_LOGIN" == "no" ]]; then
    print_result "PermitRootLogin" "PASS" "Set to: no (root login disabled)"
else
    print_result "PermitRootLogin" "FAIL" "Current: $ROOT_LOGIN (Expected: prohibit-password)"
fi

# Check PasswordAuthentication
PASS_AUTH=$(run_cmd "grep -E '^PasswordAuthentication' /etc/ssh/sshd_config | awk '{print \$2}'" 2>/dev/null || echo "not-set")
if [[ "$PASS_AUTH" == "no" ]]; then
    print_result "PasswordAuthentication" "PASS" "Password authentication disabled (keys only)"
else
    print_result "PasswordAuthentication" "FAIL" "Current: $PASS_AUTH (SECURITY RISK - should be 'no')"
fi

# Check PubkeyAuthentication
PUBKEY_AUTH=$(run_cmd "grep -E '^PubkeyAuthentication' /etc/ssh/sshd_config | awk '{print \$2}'" 2>/dev/null || echo "yes")
if [[ "$PUBKEY_AUTH" == "yes" ]]; then
    print_result "PubkeyAuthentication" "PASS" "Public key authentication enabled"
else
    print_result "PubkeyAuthentication" "WARN" "Current: $PUBKEY_AUTH (Should be 'yes')"
fi

# Check PermitEmptyPasswords
EMPTY_PASS=$(run_cmd "grep -E '^PermitEmptyPasswords' /etc/ssh/sshd_config | awk '{print \$2}'" 2>/dev/null || echo "not-set")
if [[ "$EMPTY_PASS" == "no" ]]; then
    print_result "PermitEmptyPasswords" "PASS" "Empty passwords forbidden"
else
    print_result "PermitEmptyPasswords" "WARN" "Current: $EMPTY_PASS (Should be 'no')"
fi

# Check MaxAuthTries
MAX_AUTH=$(run_cmd "grep -E '^MaxAuthTries' /etc/ssh/sshd_config | awk '{print \$2}'" 2>/dev/null || echo "6")
if [[ "$MAX_AUTH" =~ ^[1-3]$ ]]; then
    print_result "MaxAuthTries" "PASS" "Set to: $MAX_AUTH (brute force protection)"
elif [[ "$MAX_AUTH" =~ ^[4-6]$ ]]; then
    print_result "MaxAuthTries" "WARN" "Current: $MAX_AUTH (Recommended: ≤3)"
else
    print_result "MaxAuthTries" "FAIL" "Current: $MAX_AUTH (Too high)"
fi

# Check X11Forwarding
X11_FWD=$(run_cmd "grep -E '^X11Forwarding' /etc/ssh/sshd_config | awk '{print \$2}'" 2>/dev/null || echo "yes")
if [[ "$X11_FWD" == "no" ]]; then
    print_result "X11Forwarding" "PASS" "X11 forwarding disabled"
else
    print_result "X11Forwarding" "WARN" "Current: $X11_FWD (Recommended: no)"
fi

# Check ClientAliveInterval
CLIENT_ALIVE=$(run_cmd "grep -E '^ClientAliveInterval' /etc/ssh/sshd_config | awk '{print \$2}'" 2>/dev/null || echo "0")
if [[ "$CLIENT_ALIVE" =~ ^[1-9][0-9]*$ ]] && [[ "$CLIENT_ALIVE" -le 600 ]]; then
    print_result "ClientAliveInterval" "PASS" "Set to: ${CLIENT_ALIVE}s (idle timeout enabled)"
elif [[ "$CLIENT_ALIVE" == "0" ]]; then
    print_result "ClientAliveInterval" "WARN" "Idle timeout disabled (connections never expire)"
else
    print_result "ClientAliveInterval" "WARN" "Set to: ${CLIENT_ALIVE}s"
fi

# Check ClientAliveCountMax
CLIENT_COUNT=$(run_cmd "grep -E '^ClientAliveCountMax' /etc/ssh/sshd_config | awk '{print \$2}'" 2>/dev/null || echo "3")
if [[ -n "$CLIENT_COUNT" ]] && [[ "$CLIENT_COUNT" =~ ^[0-9]+$ ]]; then
    print_result "ClientAliveCountMax" "PASS" "Set to: $CLIENT_COUNT"
fi

# Check if SSH service is running
if run_cmd "systemctl is-active sshd" 2>/dev/null | grep -q "active"; then
    print_result "SSH Service Status" "PASS" "SSH service is running"
elif run_cmd "systemctl is-active ssh" 2>/dev/null | grep -q "active"; then
    print_result "SSH Service Status" "PASS" "SSH service is running"
else
    print_result "SSH Service Status" "FAIL" "SSH service is not active"
fi

# Check SSH port
SSH_PORT=$(run_cmd "grep -E '^Port' /etc/ssh/sshd_config | awk '{print \$2}'" 2>/dev/null || echo "22")
if [[ "$SSH_PORT" == "22" ]]; then
    print_result "SSH Port" "PASS" "Using standard port 22 (protected by bastion)"
else
    print_result "SSH Port" "PASS" "Using port: $SSH_PORT (non-standard)"
fi

# Fail2ban Checks
echo -e "${BLUE}[3] Fail2ban Protection${NC}"
echo "----------------------------------------"

# Check if fail2ban is installed
if run_cmd "which fail2ban-client" >/dev/null 2>&1; then
    print_result "Fail2ban Installation" "PASS" "Fail2ban is installed"
    
    # Check if fail2ban service is running
    if run_cmd "systemctl is-active fail2ban" 2>/dev/null | grep -q "active"; then
        print_result "Fail2ban Service" "PASS" "Fail2ban service is active and running"
        
        # Check SSH jail status
        SSH_JAIL=$(run_cmd "fail2ban-client status sshd 2>/dev/null" || echo "")
        if [[ -n "$SSH_JAIL" ]]; then
            print_result "SSH Jail (sshd)" "PASS" "SSH protection jail is active"
            
            # Extract and display jail details
            TOTAL_BANNED=$(echo "$SSH_JAIL" | grep "Currently banned:" | awk '{print $NF}')
            TOTAL_FAILED=$(echo "$SSH_JAIL" | grep "Total failed:" | awk '{print $NF}')
            TOTAL_BANS=$(echo "$SSH_JAIL" | grep "Total banned:" | awk '{print $NF}')
            
            echo -e "  ${CYAN}SSH Jail Statistics:${NC}"
            echo "    Currently banned IPs: ${TOTAL_BANNED:-0}"
            echo "    Total failed attempts: ${TOTAL_FAILED:-0}"
            echo "    Total bans issued: ${TOTAL_BANS:-0}"
            echo ""
            
            # Show banned IPs if any
            if [[ -n "$TOTAL_BANNED" ]] && [[ "$TOTAL_BANNED" != "0" ]]; then
                echo -e "  ${YELLOW}⚠ Currently Banned IP Addresses:${NC}"
                echo "$SSH_JAIL" | grep -A 100 "Banned IP list:" | tail -n +2 | head -20 | while read ip; do
                    [[ -n "$ip" ]] && echo "    🚫 $ip"
                done
                echo ""
            else
                echo -e "  ${GREEN}✓ No IPs currently banned${NC}"
                echo ""
            fi
        else
            print_result "SSH Jail (sshd)" "FAIL" "SSH jail is not active or not configured"
        fi
        
        # Check for sshd-ddos jail
        SSH_DDOS=$(run_cmd "fail2ban-client status sshd-ddos 2>/dev/null" || echo "")
        if [[ -n "$SSH_DDOS" ]]; then
            print_result "SSH DDoS Protection" "PASS" "SSH DDoS protection jail is active"
        else
            print_result "SSH DDoS Protection" "WARN" "SSH DDoS jail not configured"
        fi
        
        # Check fail2ban configuration
        if run_cmd "test -f /etc/fail2ban/jail.local" 2>/dev/null; then
            print_result "Fail2ban Configuration" "PASS" "Custom jail.local configuration exists"
            
            # Extract configuration values
            BANTIME=$(run_cmd "grep -E '^bantime' /etc/fail2ban/jail.local | head -1 | awk '{print \$3}'" 2>/dev/null || echo "")
            FINDTIME=$(run_cmd "grep -E '^findtime' /etc/fail2ban/jail.local | head -1 | awk '{print \$3}'" 2>/dev/null || echo "")
            MAXRETRY=$(run_cmd "grep -E '^maxretry' /etc/fail2ban/jail.local | head -1 | awk '{print \$3}'" 2>/dev/null || echo "")
            
            if [[ -n "$BANTIME" ]] || [[ -n "$FINDTIME" ]] || [[ -n "$MAXRETRY" ]]; then
                echo -e "  ${CYAN}Fail2ban Protection Settings:${NC}"
                if [[ -n "$BANTIME" ]]; then
                    BAN_HOURS=$(( BANTIME / 3600 ))
                    echo "    Ban duration: ${BANTIME}s (${BAN_HOURS}h)"
                fi
                if [[ -n "$FINDTIME" ]]; then
                    FIND_MINS=$(( FINDTIME / 60 ))
                    echo "    Detection window: ${FINDTIME}s (${FIND_MINS}m)"
                fi
                [[ -n "$MAXRETRY" ]] && echo "    Max retry attempts: $MAXRETRY"
                echo ""
            fi
        else
            print_result "Fail2ban Configuration" "WARN" "Using default configuration (not customized)"
        fi
        
    else
        print_result "Fail2ban Service" "FAIL" "Fail2ban service is not running"
        run_cmd "systemctl status fail2ban --no-pager -l 2>/dev/null | head -10" || true
    fi
else
    print_result "Fail2ban Installation" "FAIL" "Fail2ban is not installed"
fi

# Kernel Security Parameters
echo -e "${BLUE}[4] Kernel Security Parameters${NC}"
echo "----------------------------------------"

# Check IP spoofing protection
RP_FILTER=$(run_cmd "sysctl net.ipv4.conf.all.rp_filter 2>/dev/null | awk '{print \$3}'" || echo "0")
if [[ "$RP_FILTER" == "1" ]]; then
    print_result "IP Spoofing Protection" "PASS" "Reverse path filtering enabled (rp_filter=1)"
else
    print_result "IP Spoofing Protection" "FAIL" "Current: $RP_FILTER (Expected: 1)"
fi

# Check ICMP redirects
ACCEPT_REDIRECTS=$(run_cmd "sysctl net.ipv4.conf.all.accept_redirects 2>/dev/null | awk '{print \$3}'" || echo "1")
if [[ "$ACCEPT_REDIRECTS" == "0" ]]; then
    print_result "ICMP Redirect Protection" "PASS" "ICMP redirects disabled (accept_redirects=0)"
else
    print_result "ICMP Redirect Protection" "FAIL" "Current: $ACCEPT_REDIRECTS (Expected: 0)"
fi

# Check send redirects
SEND_REDIRECTS=$(run_cmd "sysctl net.ipv4.conf.all.send_redirects 2>/dev/null | awk '{print \$3}'" || echo "1")
if [[ "$SEND_REDIRECTS" == "0" ]]; then
    print_result "ICMP Send Redirects" "PASS" "Send redirects disabled (send_redirects=0)"
else
    print_result "ICMP Send Redirects" "WARN" "Current: $SEND_REDIRECTS (Recommended: 0)"
fi

# Check source routing
SOURCE_ROUTE=$(run_cmd "sysctl net.ipv4.conf.all.accept_source_route 2>/dev/null | awk '{print \$3}'" || echo "1")
if [[ "$SOURCE_ROUTE" == "0" ]]; then
    print_result "Source Routing Protection" "PASS" "Source routing disabled (accept_source_route=0)"
else
    print_result "Source Routing Protection" "FAIL" "Current: $SOURCE_ROUTE (Expected: 0)"
fi

# Check log martians
LOG_MARTIANS=$(run_cmd "sysctl net.ipv4.conf.all.log_martians 2>/dev/null | awk '{print \$3}'" || echo "0")
if [[ "$LOG_MARTIANS" == "1" ]]; then
    print_result "Martian Packet Logging" "PASS" "Martian packet logging enabled (log_martians=1)"
else
    print_result "Martian Packet Logging" "WARN" "Current: $LOG_MARTIANS (Recommended: 1 for monitoring)"
fi

# Check SYN cookies
SYN_COOKIES=$(run_cmd "sysctl net.ipv4.tcp_syncookies 2>/dev/null | awk '{print \$3}'" || echo "0")
if [[ "$SYN_COOKIES" == "1" ]]; then
    print_result "SYN Flood Protection" "PASS" "TCP SYN cookies enabled (DDoS protection)"
else
    print_result "SYN Flood Protection" "FAIL" "Current: $SYN_COOKIES (Expected: 1)"
fi

# Check TCP settings
TCP_MAX_SYN=$(run_cmd "sysctl net.ipv4.tcp_max_syn_backlog 2>/dev/null | awk '{print \$3}'" || echo "")
if [[ -n "$TCP_MAX_SYN" ]] && [[ "$TCP_MAX_SYN" -ge 2048 ]]; then
    print_result "TCP SYN Backlog" "PASS" "Set to: $TCP_MAX_SYN (adequate for high load)"
fi

# Check IP forwarding (required for Docker)
IP_FORWARD=$(run_cmd "sysctl net.ipv4.ip_forward 2>/dev/null | awk '{print \$3}'" || echo "0")
if [[ "$IP_FORWARD" == "1" ]]; then
    print_result "IP Forwarding" "PASS" "IP forwarding enabled (required for Docker)"
else
    print_result "IP Forwarding" "WARN" "IP forwarding disabled (Docker networking may not work)"
fi

# Additional Security Checks
echo -e "${BLUE}[5] Additional Security Checks${NC}"
echo "----------------------------------------"

# Check for Docker
if run_cmd "which docker" >/dev/null 2>&1; then
    DOCKER_VERSION=$(run_cmd "docker --version 2>/dev/null" || echo "Unknown")
    print_result "Docker Installation" "PASS" "$DOCKER_VERSION"
    
    # Check if Docker is running
    if run_cmd "systemctl is-active docker" 2>/dev/null | grep -q "active"; then
        print_result "Docker Service" "PASS" "Docker daemon is running"
    else
        print_result "Docker Service" "WARN" "Docker daemon is not running"
    fi
else
    print_result "Docker Installation" "INFO" "Docker not yet installed (normal if initialization is pending)"
fi

# Check for Python (required by init script)
if run_cmd "which python3" >/dev/null 2>&1; then
    PYTHON_VERSION=$(run_cmd "python3 --version 2>&1" || echo "Unknown")
    print_result "Python3" "PASS" "$PYTHON_VERSION installed"
else
    print_result "Python3" "WARN" "Python3 not found"
fi

# Check for jq (required by init script)
if run_cmd "which jq" >/dev/null 2>&1; then
    print_result "jq utility" "PASS" "jq is installed (required for config parsing)"
else
    print_result "jq utility" "WARN" "jq not found (required by init script)"
fi

# Check disk space
DISK_USAGE=$(run_cmd "df -h / | tail -1 | awk '{print \$5}'" 2>/dev/null | tr -d '%' || echo "0")
if [[ "$DISK_USAGE" -lt 70 ]]; then
    print_result "Disk Space" "PASS" "Root filesystem usage: ${DISK_USAGE}%"
elif [[ "$DISK_USAGE" -lt 85 ]]; then
    print_result "Disk Space" "WARN" "Root filesystem usage: ${DISK_USAGE}% (monitor closely)"
else
    print_result "Disk Space" "FAIL" "Root filesystem usage: ${DISK_USAGE}% (critically high)"
fi

# Check memory
MEM_AVAILABLE=$(run_cmd "free -m | grep Mem | awk '{print \$7}'" 2>/dev/null || echo "0")
MEM_TOTAL=$(run_cmd "free -m | grep Mem | awk '{print \$2}'" 2>/dev/null || echo "0")
if [[ "$MEM_TOTAL" -gt 0 ]]; then
    MEM_PERCENT=$(( (MEM_AVAILABLE * 100) / MEM_TOTAL ))
    if [[ "$MEM_PERCENT" -gt 20 ]]; then
        print_result "Memory Availability" "PASS" "${MEM_AVAILABLE}MB available of ${MEM_TOTAL}MB total (${MEM_PERCENT}%)"
    else
        print_result "Memory Availability" "WARN" "${MEM_AVAILABLE}MB available of ${MEM_TOTAL}MB total (${MEM_PERCENT}%)"
    fi
fi

# Check for security updates
UPDATES=$(run_cmd "apt list --upgradable 2>/dev/null | grep -i security | wc -l" || echo "0")
if [[ "$UPDATES" -eq 0 ]]; then
    print_result "Security Updates" "PASS" "No pending security updates"
elif [[ "$UPDATES" -lt 10 ]]; then
    print_result "Security Updates" "WARN" "$UPDATES security update(s) available"
else
    print_result "Security Updates" "FAIL" "$UPDATES security update(s) available (apply soon)"
fi

# Summary
echo "=========================================="
echo -e "${BLUE}Verification Summary${NC}"
echo "=========================================="
echo ""
echo "This verification script checked:"
echo "  ✓ Node initialization status"
echo "  ✓ SSH hardening configuration (8+ checks)"
echo "  ✓ Fail2ban installation and protection"
echo "  ✓ Kernel security parameters (10+ checks)"
echo "  ✓ Additional system security"
echo ""
echo -e "${YELLOW}Review any FAIL or WARN items above.${NC}"
echo ""
echo -e "${CYAN}For detailed information:${NC}"
echo "  • PASS = Security control is properly configured"
echo "  • WARN = Recommended improvement available"
echo "  • FAIL = Security control is missing or misconfigured"
echo ""