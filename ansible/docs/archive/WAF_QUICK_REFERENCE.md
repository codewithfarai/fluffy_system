# Coraza WAF Quick Reference

## Deployment Commands

### Deploy WAF Configuration
```bash
cd /home/dev_two/Desktop/fluffy_system/ansible
ansible-playbook -i inventory/hosts.ini playbooks/deploy_waf.yml
```

### Test WAF Protection
```bash
./scripts/test_waf.sh afroforgelabs.com https
```

## Common Operations

### Check Traefik Service Status
```bash
docker service ls | grep traefik
docker service ps traefik_traefik
```

### View WAF Logs (Real-time)
```bash
# Service logs
docker service logs -f traefik_traefik

# Access logs
tail -f /opt/docker/stacks/traefik/logs/access.log

# Traefik logs
tail -f /opt/docker/stacks/traefik/logs/traefik.log
```

### Reload Traefik Configuration
```bash
docker service update --force traefik_traefik
```

### Verify Middleware Configuration
```bash
# On edge node
curl http://localhost:8080/api/http/middlewares
```

## Configuration Files

| File | Purpose | Location |
|------|---------|----------|
| Static Config | Traefik base config + plugin | `/opt/docker/stacks/traefik/data/traefik.yml` |
| WAF Rules | Coraza middleware & OWASP CRS | `/opt/docker/stacks/traefik/data/configurations/waf.yml` |
| TLS Config | SSL/TLS settings | `/opt/docker/stacks/traefik/data/configurations/dynamic.yml` |
| Website Config | Website service definition | `/opt/docker/stacks/website/docker-compose.yml` |

## WAF Settings

### Current Configuration

| Setting | Value | Description |
|---------|-------|-------------|
| WAF Engine | Coraza v0.2.2 | WASM-based WAF |
| Rule Set | OWASP CRS | Core Rule Set |
| Paranoia Level | 1 | Standard protection |
| Anomaly Threshold | 5 (in) / 4 (out) | Trigger point for blocking |
| Allowed Methods | GET, HEAD, POST, OPTIONS | HTTP methods |
| Rate Limit | 100 req/min (burst: 50) | DDoS protection |

### Protected Against

- SQL Injection (SQLi)
- Cross-Site Scripting (XSS)
- Remote Code Execution (RCE)
- Local/Remote File Inclusion (LFI/RFI)
- Path Traversal
- Session Fixation
- Protocol Violations
- Scanner Detection
- NoSQL/LDAP/XML Injection

## Quick Tests

### Test Normal Access
```bash
curl -I https://afroforgelabs.com
# Expected: 200 OK
```

### Test SQL Injection Block
```bash
curl -I "https://afroforgelabs.com/?id=1' OR '1'='1"
# Expected: 403 Forbidden
```

### Test XSS Block
```bash
curl -I "https://afroforgelabs.com/?search=<script>alert(1)</script>"
# Expected: 403 Forbidden
```

## Troubleshooting

### WAF Not Blocking

1. Check plugin loaded:
   ```bash
   docker service inspect traefik_traefik | grep coraza
   ```

2. Verify configuration:
   ```bash
   cat /opt/docker/stacks/traefik/data/traefik.yml | grep -A5 experimental
   ```

3. Check logs for errors:
   ```bash
   docker service logs traefik_traefik | grep -i error
   ```

### False Positives

1. Identify blocking rule:
   ```bash
   docker service logs traefik_traefik | grep "403"
   ```

2. Temporarily bypass WAF (testing only):
   ```bash
   # Edit website docker-compose.yml
   # Remove waf-website@file from middlewares
   docker stack deploy -c /opt/docker/stacks/website/docker-compose.yml website
   ```

3. Add exclusion rule to `/opt/docker/stacks/traefik/data/configurations/waf.yml`

### Performance Issues

1. Check resource usage:
   ```bash
   docker stats $(docker ps -q -f name=traefik)
   ```

2. Reduce paranoia level in waf.yml:
   ```yaml
   - SecAction "id:900000,phase:1,pass,t:none,nolog,setvar:tx.paranoia_level=1"
   ```

3. Increase Traefik resources in docker-compose.yml

## Tuning Recommendations

### Production Settings (Current)
- Paranoia Level: 1
- Anomaly Threshold: 5
- Mode: Anomaly Scoring with Blocking

### Monitoring Mode (Learning)
```yaml
- SecRuleEngine DetectionOnly  # Log only, don't block
```

### Strict Mode (High Security)
```yaml
- SecAction "id:900000,phase:1,pass,t:none,nolog,setvar:tx.paranoia_level=2"
- SecAction "id:900110,phase:1,pass,t:none,nolog,setvar:tx.inbound_anomaly_score_threshold=3"
```

## Extending Protection

### Protect API Endpoint
```yaml
# In service docker-compose.yml
deploy:
  labels:
    - traefik.http.routers.api.middlewares=waf-website@file,security-headers@file
```

### Protect Admin Panel (Stricter)
```yaml
# In service docker-compose.yml
deploy:
  labels:
    - traefik.http.routers.admin.middlewares=waf-strict@file,security-headers@file
```

## Monitoring Metrics

### Key Metrics to Track

1. **Request Rate**: Normal vs blocked requests
2. **False Positive Rate**: Legitimate requests blocked
3. **Top Blocked Rules**: Most triggered CRS rules
4. **Attack Patterns**: Types of attacks detected
5. **Response Latency**: Impact on performance

### Prometheus Metrics

Access metrics endpoint:
```bash
curl http://edge-node:8082/metrics | grep traefik
```

## Security Headers Applied

```
X-Frame-Options: SAMEORIGIN
X-Content-Type-Options: nosniff
X-XSS-Protection: 1; mode=block
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
```

## Rate Limiting

- **Average**: 100 requests/minute
- **Burst**: 50 requests
- **Period**: 1 minute

Adjust in `/opt/docker/stacks/traefik/data/configurations/waf.yml`:
```yaml
rate-limit:
  rateLimit:
    average: 200      # Adjust based on traffic
    burst: 100
    period: 1m
```

## Support

- Full Documentation: `/home/dev_two/Desktop/fluffy_system/ansible/docs/WAF_IMPLEMENTATION.md`
- Coraza WAF: https://coraza.io/
- OWASP CRS: https://coreruleset.org/
- Traefik Plugins: https://plugins.traefik.io/

## Maintenance Schedule

- **Daily**: Monitor logs for attack patterns
- **Weekly**: Review blocked requests for false positives
- **Monthly**: Update plugins and review rules
- **Quarterly**: Tune configuration based on traffic patterns
- **Yearly**: Conduct security audit and penetration testing
