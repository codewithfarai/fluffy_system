# Security Configuration Guide

## Overview

This infrastructure implements multiple layers of security to protect your applications and services.

## Deployed Security Features

### 1. Security Headers

Automatically applied to all HTTPS traffic via Traefik middleware.

**Headers Configured:**
- `Strict-Transport-Security: max-age=31536000; includeSubDomains; preload`
  - Forces HTTPS for 1 year
  - Includes all subdomains
  - Eligible for browser preload lists

- `X-Frame-Options: SAMEORIGIN`
  - Prevents clickjacking attacks
  - Only allows framing from same origin

- `X-Content-Type-Options: nosniff`
  - Prevents MIME type sniffing
  - Reduces XSS attack surface

- `X-XSS-Protection: 1; mode=block`
  - Enables browser XSS filters
  - Blocks page rendering if XSS detected

- Headers Removed:
  - `Server` (hides server version)
  - `X-Powered-By` (hides technology stack)

### 2. Rate Limiting

Protects against DDoS and brute force attacks.

**Configuration:**
- **Average**: 100 requests per minute
- **Burst**: 50 requests (allows temporary spikes)
- **Period**: 1 minute

### 3. TLS Configuration

Modern TLS configuration with strong cipher suites.

**Settings:**
- **Minimum Version**: TLS 1.2
- **Maximum Version**: TLS 1.3
- **Cipher Suites**:
  - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
  - TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305
  - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256

## Deployment

### Deploy Security Configuration

```bash
cd /home/dev_two/Desktop/fluffy_system/ansible
ansible-playbook -i inventory/hosts.ini playbooks/deploy_security.yml
```

This playbook will:
1. Update Traefik static configuration on all nodes
2. Create TLS configuration (TLS 1.2/1.3)
3. Create security middlewares (headers + rate limiting)
4. Apply middlewares to website
5. Sync configurations to edge nodes
6. Reload Traefik
7. Redeploy website

### Verify Deployment

Check security headers:
```bash
curl -I https://afroforgelabs.com/
```

Expected output should include:
```
HTTP/2 200
strict-transport-security: max-age=31536000; includeSubDomains; preload
x-content-type-options: nosniff
x-frame-options: SAMEORIGIN
x-xss-protection: 1; mode=block
```

## Configuration Files

### On Manager Node
- `/opt/docker/stacks/traefik/data/traefik.yml` - Static Traefik config
- `/opt/docker/stacks/traefik/data/configurations/dynamic.yml` - TLS options
- `/opt/docker/stacks/traefik/data/configurations/security.yml` - Security middlewares
- `/opt/docker/stacks/website/docker-compose.yml` - Website with middleware labels

### On Edge Nodes
- `/opt/docker/stacks/traefik/data/configurations/dynamic.yml` - Synced TLS config
- `/opt/docker/stacks/traefik/data/configurations/security.yml` - Synced middlewares

## Applying to Additional Services

To protect other services with the same security features:

### Example: API Service

Edit your service's `docker-compose.yml`:

```yaml
services:
  api:
    image: your-api-image
    networks:
      - traefik-public
    deploy:
      labels:
        - traefik.enable=true
        - traefik.http.routers.api.rule=Host(`api.example.com`)
        - traefik.http.routers.api.entrypoints=websecure
        - traefik.http.routers.api.tls.certresolver=letsencrypt
        # Apply security middlewares
        - traefik.http.routers.api.middlewares=security-headers@file,rate-limit@file
        - traefik.http.services.api.loadbalancer.server.port=8000
```

Then redeploy:
```bash
docker stack deploy -c docker-compose.yml your-stack-name
```

## Customizing Security Settings

### Adjust Rate Limiting

Edit `/opt/docker/stacks/traefik/data/configurations/security.yml` on manager:

```yaml
http:
  middlewares:
    rate-limit:
      rateLimit:
        average: 200      # Increase for high-traffic sites
        burst: 100        # Allow larger burst
        period: 1m
```

Then sync to edge nodes and reload:
```bash
ansible-playbook -i inventory/hosts.ini playbooks/deploy_security.yml
```

### Modify Security Headers

Edit the `security-headers` middleware in `security.yml`:

```yaml
http:
  middlewares:
    security-headers:
      headers:
        frameDeny: true
        contentSecurityPolicy: "default-src 'self'"  # Add CSP
        # ... other headers
```

### Update TLS Configuration

Edit `/opt/docker/stacks/traefik/data/configurations/dynamic.yml`:

```yaml
tls:
  options:
    default:
      minVersion: VersionTLS13  # TLS 1.3 only (more strict)
      maxVersion: VersionTLS13
```

## Monitoring

### Check Traefik Logs

View security events:
```bash
# On manager
ansible managers[0] -i inventory/hosts.ini -m shell -a "docker service logs traefik_traefik --tail 100"

# On edge nodes
ansible edge -i inventory/hosts.ini -m shell -a "tail -50 /opt/docker/stacks/traefik/logs/access.log"
```

### Monitor Rate Limiting

Check for rate limit blocks (HTTP 429):
```bash
ansible edge[0] -i inventory/hosts.ini -m shell -a "grep -i '429' /opt/docker/stacks/traefik/logs/access.log | tail -20"
```

## Security Testing

### Test Security Headers

```bash
# Check all headers
curl -I https://afroforgelabs.com/

# Test HSTS
curl -I https://afroforgelabs.com/ | grep -i strict-transport

# Test clickjacking protection
curl -I https://afroforgelabs.com/ | grep -i x-frame-options
```

### Test Rate Limiting

Send multiple requests quickly:
```bash
for i in {1..110}; do
  curl -s -o /dev/null -w "%{http_code}\n" https://afroforgelabs.com/
done | sort | uniq -c
```

If rate limiting is working, you'll see HTTP 429 responses after exceeding the limit.

### Test TLS Configuration

Check TLS version and ciphers:
```bash
nmap --script ssl-enum-ciphers -p 443 afroforgelabs.com
```

Or use SSL Labs:
```
https://www.ssllabs.com/ssltest/analyze.html?d=afroforgelabs.com
```

## Troubleshooting

### Security Headers Not Appearing

1. Check if middleware exists:
```bash
ansible edge[0] -i inventory/hosts.ini -m shell -a "cat /opt/docker/stacks/traefik/data/configurations/security.yml | grep -A10 security-headers"
```

2. Check Traefik logs for errors:
```bash
ansible managers[0] -i inventory/hosts.ini -m shell -a "docker service logs traefik_traefik --tail 50 | grep -i error"
```

3. Verify middleware is applied to route:
```bash
ansible managers[0] -i inventory/hosts.ini -m shell -a "cat /opt/docker/stacks/website/docker-compose.yml | grep middlewares"
```

### Rate Limiting Not Working

1. Check if rate-limit middleware exists:
```bash
ansible edge[0] -i inventory/hosts.ini -m shell -a "grep -A5 'rate-limit:' /opt/docker/stacks/traefik/data/configurations/security.yml"
```

2. Ensure it's in the middleware chain:
```bash
# Should see: security-headers@file,rate-limit@file
curl -I https://afroforgelabs.com/ 2>&1 | head -1
```

## Best Practices

1. **Regular Updates**: Keep Traefik and security configurations updated
2. **Monitor Logs**: Review access logs weekly for anomalies
3. **Test After Changes**: Always test security features after configuration changes
4. **SSL/TLS Audits**: Run SSL Labs tests quarterly
5. **Rate Limit Tuning**: Adjust based on legitimate traffic patterns
6. **Header Testing**: Use securityheaders.com to validate configuration

## Additional Security Layers

This configuration provides strong baseline security. Consider adding:

1. **GeoIP Blocking** (if needed)
2. **IP Whitelisting** for admin interfaces
3. **OAuth/OIDC** for authentication
4. **Fail2Ban** for repeated failed auth attempts
5. **Web Application Firewall** (when requirements are clearer)

## Support

For issues or questions:
- Check logs first
- Review configuration files
- Test with curl/browser dev tools
- Consult Traefik documentation: https://doc.traefik.io/traefik/
