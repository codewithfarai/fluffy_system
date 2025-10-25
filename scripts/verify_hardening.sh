#!/bin/bash
# Fluffy System Security Hardening Verification Script
# Usage: ./verify_hardening.sh [hostname]

set -e

TARGET_HOST="${1:-}"
SSH_USER="root"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
        echo -e "  ${details}"
    fi
    echo ""
}

echo ""
echo "=========================================="
echo "Security Hardening Verification Report"
echo "=========================================="
echo ""

# Check if node initialization completed
echo -e "${BLUE}[1] Checking Node Initialization Status${NC}"
echo "----------------------------------------"

if run_cmd "test -f /tmp/node-init-complete" 2>/dev/null; then
    print_result "Node initialization marker" "PASS" "Initialization completed successfully"
    
    # Read node info
    NODE_INFO=$(run_cmd "cat /tmp/node-info 2>/dev/null" || echo "")
    if [[ -n "$NODE_INFO" ]]; then
        echo -e "${BLUE}Node Information:${NC}"
        echo "$NODE_INFO" | while read line; do
            echo "  $line"
        done
        echo ""
    fi
else
    print_result "Node initialization marker" "FAIL" "Node initialization did not complete"
fi

# SSH Hardening Checks
echo -e "${BLUE}[2] SSH Configuration Hardening${NC}"
echo "----------------------------------------"

# Check PermitRootLogin
ROOT_LOGIN=$(run_cmd "grep -E '^PermitRootLogin' /etc/ssh/sshd_config | awk '{print \$2}'" 2>/dev/null || echo "")
if [[ "$ROOT_LOGIN" == "prohibit-password" ]] || [[ "$ROOT_LOGIN" == "without-password" ]]; then
    print_result "PermitRootLogin" "PASS" "Set to: $ROOT_LOGIN"
else
    print_result "PermitRootLogin" "FAIL" "Current value: $ROOT_LOGIN (Expected: prohibit-password)"
fi

# Check PasswordAuthentication
PASS_AUTH=$(run_cmd "grep -E '^PasswordAuthentication' /etc/ssh/sshd_config | awk '{print \$2}'" 2>/dev/null || echo "")
if [[ "$PASS_AUTH" == "no" ]]; then
    print_result "PasswordAuthentication" "PASS" "Password authentication disabled"
else
    print_result "PasswordAuthentication" "FAIL" "Current value: $PASS_AUTH (Expected: no)"
fi

# Check PubkeyAuthentication
PUBKEY_AUTH=$(run_cmd "grep -E '^PubkeyAuthentication' /etc/ssh/sshd_config | awk '{print \$2}'" 2>/dev/null || echo "")
if [[ "$PUBKEY_AUTH" == "yes" ]]; then
    print_result "PubkeyAuthentication" "PASS" "Public key authentication enabled"
else
    print_result "PubkeyAuthentication" "WARN" "Current value: $PUBKEY_AUTH (Expected: yes)"
fi

# Check MaxAuthTries
MAX_AUTH=$(run_cmd "grep -E '^MaxAuthTries' /etc/ssh/sshd_config | awk '{print \$2}'" 2>/dev/null || echo "")
if [[ "$MAX_AUTH" =~ ^[1-3]$ ]]; then
    print_result "MaxAuthTries" "PASS" "Set to: $MAX_AUTH (secure)"
else
    print_result "MaxAuthTries" "WARN" "Current value: $MAX_AUTH (Recommended: ≤3)"
fi

# Check X11Forwarding
X11_FWD=$(run_cmd "grep -E '^X11Forwarding' /etc/ssh/sshd_config | awk '{print \$2}'" 2>/dev/null || echo "")
if [[ "$X11_FWD" == "no" ]]; then
    print_result "X11Forwarding" "PASS" "X11 forwarding disabled"
else
    print_result "X11Forwarding" "WARN" "Current value: $X11_FWD (Recommended: no)"
fi

# Check ClientAliveInterval
CLIENT_ALIVE=$(run_cmd "grep -E '^ClientAliveInterval' /etc/ssh/sshd_config | awk '{print \$2}'" 2>/dev/null || echo "")
if [[ -n "$CLIENT_ALIVE" ]] && [[ "$CLIENT_ALIVE" =~ ^[0-9]+$ ]]; then
    print_result "ClientAliveInterval" "PASS" "Set to: ${CLIENT_ALIVE}s"
else
    print_result "ClientAliveInterval" "WARN" "Not configured or invalid"
fi

# Check if SSH service is running
if run_cmd "systemctl is-active sshd" 2>/dev/null | grep -q "active"; then
    print_result "SSH Service Status" "PASS" "SSH service is running"
else
    print_result "SSH Service Status" "FAIL" "SSH service is not active"
fi

# Fail2ban Checks
echo -e "${BLUE}[3] Fail2ban Configuration${NC}"
echo "----------------------------------------"

# Check if fail2ban is installed
if run_cmd "which fail2ban-client" >/dev/null 2>&1; then
    print_result "Fail2ban Installation" "PASS" "Fail2ban is installed"
    
    # Check if fail2ban service is running
    if run_cmd "systemctl is-active fail2ban" 2>/dev/null | grep -q "active"; then
        print_result "Fail2ban Service" "PASS" "Fail2ban service is running"
        
        # Check SSH jail status
        SSH_JAIL=$(run_cmd "fail2ban-client status sshd 2>/dev/null" || echo "")
        if [[ -n "$SSH_JAIL" ]]; then
            print_result "SSH Jail (sshd)" "PASS" "SSH jail is active"
            
            # Extract and display jail details
            TOTAL_BANNED=$(echo "$SSH_JAIL" | grep "Currently banned:" | awk '{print $NF}')
            TOTAL_FAILED=$(echo "$SSH_JAIL" | grep "Total failed:" | awk '{print $NF}')
            
            echo -e "  ${BLUE}SSH Jail Statistics:${NC}"
            echo "    Currently banned IPs: ${TOTAL_BANNED:-0}"
            echo "    Total failed attempts: ${TOTAL_FAILED:-0}"
            echo ""
            
            # Show banned IPs if any
            if [[ "$TOTAL_BANNED" != "0" ]] && [[ -n "$TOTAL_BANNED" ]]; then
                echo -e "  ${YELLOW}Banned IP addresses:${NC}"
                echo "$SSH_JAIL" | grep -A 100 "Banned IP list:" | tail -n +2 | while read ip; do
                    [[ -n "$ip" ]] && echo "    - $ip"
                done
                echo ""
            fi
        else
            print_result "SSH Jail (sshd)" "FAIL" "SSH jail is not active"
        fi
        
        # Check fail2ban configuration
        if run_cmd "test -f /etc/fail2ban/jail.local"; then
            print_result "Fail2ban Configuration" "PASS" "Custom jail.local exists"
            
            # Extract configuration values
            BANTIME=$(run_cmd "grep -E '^bantime' /etc/fail2ban/jail.local | head -1 | awk '{print \$3}'" 2>/dev/null || echo "")
            FINDTIME=$(run_cmd "grep -E '^findtime' /etc/fail2ban/jail.local | head -1 | awk '{print \$3}'" 2>/dev/null || echo "")
            MAXRETRY=$(run_cmd "grep -E '^maxretry' /etc/fail2ban/jail.local | head -1 | awk '{print \$3}'" 2>/dev/null || echo "")
            
            if [[ -n "$BANTIME" ]] || [[ -n "$FINDTIME" ]] || [[ -n "$MAXRETRY" ]]; then
                echo -e "  ${BLUE}Fail2ban Settings:${NC}"
                [[ -n "$BANTIME" ]] && echo "    Ban time: ${BANTIME}s"
                [[ -n "$FINDTIME" ]] && echo "    Find time: ${FINDTIME}s"
                [[ -n "$MAXRETRY" ]] && echo "    Max retry: $MAXRETRY"
                echo ""
            fi
        else
            print_result "Fail2ban Configuration" "WARN" "Using default configuration"
        fi
        
    else
        print_result "Fail2ban Service" "FAIL" "Fail2ban service is not running"
    fi
else
    print_result "Fail2ban Installation" "FAIL" "Fail2ban is not installed"
fi

# Kernel Security Parameters
echo -e "${BLUE}[4] Kernel Security Parameters${NC}"
echo "----------------------------------------"

# Check IP spoofing protection
RP_FILTER=$(run_cmd "sysctl net.ipv4.conf.all.rp_filter 2>/dev/null | awk '{print \$3}'" || echo "")
if [[ "$RP_FILTER" == "1" ]]; then
    print_result "IP Spoofing Protection" "PASS" "Reverse path filtering enabled"
else
    print_result "IP Spoofing Protection" "FAIL" "Current value: $RP_FILTER (Expected: 1)"
fi

# Check ICMP redirects
ACCEPT_REDIRECTS=$(run_cmd "sysctl net.ipv4.conf.all.accept_redirects 2>/dev/null | awk '{print \$3}'" || echo "")
if [[ "$ACCEPT_REDIRECTS" == "0" ]]; then
    print_result "ICMP Redirects" "PASS" "ICMP redirects disabled"
else
    print_result "ICMP Redirects" "FAIL" "Current value: $ACCEPT_REDIRECTS (Expected: 0)"
fi

# Check source routing
SOURCE_ROUTE=$(run_cmd "sysctl net.ipv4.conf.all.accept_source_route 2>/dev/null | awk '{print \$3}'" || echo "")
if [[ "$SOURCE_ROUTE" == "0" ]]; then
    print_result "Source Routing" "PASS" "Source routing disabled"
else
    print_result "Source Routing" "FAIL" "Current value: $SOURCE_ROUTE (Expected: 0)"
fi

# Check SYN cookies
SYN_COOKIES=$(run_cmd "sysctl net.ipv4.tcp_syncookies 2>/dev/null | awk '{print \$3}'" || echo "")
if [[ "$SYN_COOKIES" == "1" ]]; then
    print_result "SYN Flood Protection" "PASS" "TCP SYN cookies enabled"
else
    print_result "SYN Flood Protection" "FAIL" "Current value: $SYN_COOKIES (Expected: 1)"
fi

# Check IP forwarding (required for Docker)
IP_FORWARD=$(run_cmd "sysctl net.ipv4.ip_forward 2>/dev/null | awk '{print \$3}'" || echo "")
if [[ "$IP_FORWARD" == "1" ]]; then
    print_result "IP Forwarding" "PASS" "IP forwarding enabled (required for Docker)"
else
    print_result "IP Forwarding" "WARN" "IP forwarding disabled (may affect Docker networking)"
fi

# System Information
echo -e "${BLUE}[5] System Information${NC}"
echo "----------------------------------------"

HOSTNAME=$(run_cmd "hostname" 2>/dev/null || echo "Unknown")
KERNEL=$(run_cmd "uname -r" 2>/dev/null || echo "Unknown")
UPTIME=$(run_cmd "uptime -p" 2>/dev/null || echo "Unknown")
echo -e "  Hostname: $HOSTNAME"
echo -e "  Kernel: $KERNEL"
echo -e "  Uptime: $UPTIME"
echo ""

# Summary
echo "=========================================="
echo -e "${BLUE}Verification Summary${NC}"
echo "=========================================="
echo ""
echo "This script has verified:"
echo "  ✓ SSH hardening configuration"
echo "  ✓ Fail2ban installation and status"
echo "  ✓ Kernel security parameters"
echo "  ✓ System initialization markers"
echo ""
echo "Review any FAIL or WARN items above."
echo ""