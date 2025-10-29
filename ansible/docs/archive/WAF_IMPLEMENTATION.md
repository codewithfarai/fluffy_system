# Coraza WAF Implementation Guide

## Overview

This infrastructure uses **Coraza WAF** with the OWASP Core Rule Set (CRS) to protect the website against common web attacks. Coraza is a modern, high-performance WAF that is 100% compatible with ModSecurity rules.

## Architecture

```
Internet → Traefik (Port 443) → Coraza WAF Plugin → Website Service
```

### Components

1. **Traefik v3.5**: Reverse proxy and load balancer
2. **Coraza WASM Plugin**: Web Application Firewall engine
3. **OWASP CRS**: Core Rule Set for comprehensive attack protection
4. **Security Middlewares**: Additional security headers and rate limiting

## Protected Website

- **Domain**: `afroforgelabs.com`
- **Service**: `website_web`
- **Replicas**: 2

## WAF Configuration

### Protection Levels

We've implemented two WAF middleware configurations:

#### 1. Standard Protection (`waf-website`)
- **Paranoia Level**: 1 (Recommended for production)
- **Anomaly Threshold**: 5 (Inbound), 4 (Outbound)
- **Allowed Methods**: GET, HEAD, POST, OPTIONS
- **Mode**: Anomaly scoring (logs and blocks)

#### 2. Strict Protection (`waf-strict`)
- **Paranoia Level**: 2 (Higher sensitivity)
- **Anomaly Threshold**: 3 (Stricter)
- **Allowed Methods**: GET, POST only
- **Use Case**: Admin panels, API endpoints (future implementation)

### OWASP CRS Rules Enabled

The following OWASP CRS rule categories are active:

| Category | Rule ID | Protection Against |
|----------|---------|-------------------|
| METHOD-ENFORCEMENT | 911 | HTTP method violations |
| SCANNER-DETECTION | 913 | Security scanners and bots |
| PROTOCOL-ENFORCEMENT | 920 | HTTP protocol violations |
| PROTOCOL-ATTACK | 921 | HTTP request smuggling, header injection |
| APPLICATION-ATTACK-LFI | 930 | Local File Inclusion |
| APPLICATION-ATTACK-RFI | 931 | Remote File Inclusion |
| APPLICATION-ATTACK-RCE | 932 | Remote Code Execution |
| APPLICATION-ATTACK-PHP | 933 | PHP injection attacks |
| APPLICATION-ATTACK-NODEJS | 934 | Node.js specific attacks |
| APPLICATION-ATTACK-XSS | 941 | Cross-Site Scripting |
| APPLICATION-ATTACK-SQLI | 942 | SQL Injection |
| SESSION-FIXATION | 943 | Session fixation attacks |
| APPLICATION-ATTACK-JAVA | 944 | Java-specific attacks |
| BLOCKING-EVALUATION | 949 | Anomaly scoring evaluation |
| DATA-LEAKAGES | 950-954 | Information disclosure |
| RESPONSE-BLOCKING | 959 | Response anomaly detection |
| CORRELATION | 980 | Attack correlation |

### Custom Rules

Additional custom rules implemented:

```yaml
# Block known malicious bots
SecRule REQUEST_HEADERS:User-Agent "@pm bad-bot malicious-scanner" \
  "id:100001,phase:1,t:lowercase,log,deny,status:403,msg:'Malicious bot detected'"

# Block path traversal attempts
SecRule REQUEST_URI "@rx \.\./" \
  "id:100002,phase:1,t:lowercase,log,deny,status:403,msg:'Path traversal attempt detected'"
```

### Security Headers

The following security headers are automatically added to all responses:

- `X-Frame-Options: SAMEORIGIN`
- `X-Content-Type-Options: nosniff`
- `X-XSS-Protection: 1; mode=block`
- `Strict-Transport-Security: max-age=31536000; includeSubDomains; preload`
- Removed `X-Powered-By` and `Server` headers

### Rate Limiting

- **Average**: 100 requests per minute
- **Burst**: 50 requests
- **Period**: 1 minute

## Deployment

### Deploy WAF Configuration

```bash
ansible-playbook -i inventory/hosts.ini playbooks/deploy_waf.yml
```

### What This Playbook Does

1. Updates Traefik static configuration with Coraza plugin
2. Creates WAF middleware with OWASP CRS rules
3. Applies security headers and rate limiting
4. Updates website deployment to use WAF protection
5. Reloads Traefik service
6. Redeploys website stack
7. Runs security tests to validate WAF functionality

### Deployment Steps

1. **Static Configuration Update**
   - Adds experimental Coraza plugin to Traefik
   - Synced across all nodes

2. **Dynamic Configuration Creation**
   - Creates `/opt/docker/stacks/traefik/data/configurations/waf.yml`
   - Defines WAF middlewares and rules

3. **Website Update**
   - Updates Docker Compose with middleware chain
   - Applies: `waf-website → security-headers → rate-limit`

4. **Service Reload**
   - Force updates Traefik to load plugin
   - Redeploys website with new configuration

## Testing and Validation

### Automated Tests

The playbook includes automated security tests:

1. **Legitimate Request Test**: Verifies normal traffic passes
2. **SQL Injection Test**: Tests SQLi blocking
3. **XSS Test**: Tests XSS script blocking
4. **Path Traversal Test**: Tests directory traversal blocking

### Manual Testing

#### Test Legitimate Access
```bash
curl -I https://afroforgelabs.com
# Expected: 200 OK
```

#### Test SQL Injection Protection
```bash
curl -I "https://afroforgelabs.com/?id=1' OR '1'='1"
# Expected: 403 Forbidden
```

#### Test XSS Protection
```bash
curl -I "https://afroforgelabs.com/?search=<script>alert('xss')</script>"
# Expected: 403 Forbidden
```

#### Test Path Traversal Protection
```bash
curl -I "https://afroforgelabs.com/../../../etc/passwd"
# Expected: 403 Forbidden
```

#### Test RCE Protection
```bash
curl -I "https://afroforgelabs.com/?cmd=cat%20/etc/passwd"
# Expected: 403 Forbidden
```

## Monitoring and Logging

### View WAF Logs

#### Traefik Service Logs (Real-time)
```bash
docker service logs -f traefik_traefik
```

#### Access Logs
```bash
tail -f /opt/docker/stacks/traefik/logs/access.log
```

#### Traefik Logs
```bash
tail -f /opt/docker/stacks/traefik/logs/traefik.log
```

### Log Analysis

Look for these indicators in logs:

- **Blocked Requests**: Status code `403`
- **Anomaly Scores**: Check for `tx.anomaly_score` values
- **Rule IDs**: Identify which CRS rules triggered

Example blocked request log:
```json
{
  "level": "info",
  "msg": "Request blocked by Coraza",
  "rule_id": "942100",
  "anomaly_score": 5,
  "uri": "/admin?id=1' OR '1'='1"
}
```

## Fine-Tuning

### Adjusting Paranoia Level

Edit `/opt/docker/stacks/traefik/data/configurations/waf.yml`:

```yaml
# Paranoia levels: 1 (default), 2 (moderate), 3 (strict), 4 (extreme)
- SecAction "id:900000,phase:1,pass,t:none,nolog,setvar:tx.paranoia_level=2"
```

**Recommendation**: Start with level 1, monitor for false positives, then increase if needed.

### Adjusting Anomaly Threshold

Lower threshold = stricter blocking:

```yaml
# Default: 5 (balanced)
# Strict: 3
# Relaxed: 10
- SecAction "id:900110,phase:1,pass,t:none,nolog,setvar:tx.inbound_anomaly_score_threshold=5"
```

### Adding Exclusion Rules

If legitimate traffic is blocked, add exclusions:

```yaml
# Exclude specific URI from SQLi checks
- SecRuleRemoveById 942100
- SecRule REQUEST_URI "@beginsWith /api/upload" "id:100100,phase:1,pass,nolog,ctl:ruleRemoveById=942100"
```

### Adjusting Rate Limits

Edit rate limit middleware:

```yaml
rate-limit:
  rateLimit:
    average: 200      # Increase for high-traffic sites
    burst: 100        # Allow burst traffic
    period: 1m
```

## Extending WAF Protection

### Protect Additional Services

To extend WAF protection to other services (e.g., API, web apps):

1. **Update the service Docker Compose file**:
```yaml
deploy:
  labels:
    - traefik.http.routers.myapp.middlewares=waf-website@file,security-headers@file
```

2. **For stricter protection** (admin panels):
```yaml
deploy:
  labels:
    - traefik.http.routers.admin.middlewares=waf-strict@file,security-headers@file
```

3. **Redeploy the service**:
```bash
docker stack deploy -c /path/to/docker-compose.yml stackname
```

### Create Service-Specific WAF Rules

Add to `waf.yml`:

```yaml
waf-api:
  plugin:
    coraza:
      crsEnabled: true
      directives:
        - SecRuleEngine On
        - SecAction "id:900200,phase:1,pass,t:none,nolog,setvar:'tx.allowed_methods=GET POST PUT DELETE'"
        - SecAction "id:900220,phase:1,pass,t:none,nolog,setvar:'tx.allowed_request_content_type=application/json'"
        # Include relevant CRS rules...
```

## Troubleshooting

### WAF Not Blocking Attacks

1. **Check Traefik logs**:
   ```bash
   docker service logs traefik_traefik | grep -i coraza
   ```

2. **Verify plugin loaded**:
   ```bash
   docker service inspect traefik_traefik --format '{{ "{{" }}json .Spec.TaskTemplate.ContainerSpec.Labels{{ "}}" }}' | jq
   ```

3. **Check middleware chain**:
   ```bash
   curl http://edge-node:8080/api/http/middlewares
   ```

4. **Verify WAF configuration**:
   ```bash
   cat /opt/docker/stacks/traefik/data/configurations/waf.yml
   ```

### False Positives (Legitimate Traffic Blocked)

1. **Identify the rule** causing false positive from logs
2. **Test without WAF** temporarily:
   ```yaml
   # Remove waf middleware from router
   - traefik.http.routers.website.middlewares=security-headers@file
   ```

3. **Add exclusion rule** (see Fine-Tuning section)
4. **Lower paranoia level** if too many false positives

### High Latency

1. **Check Coraza performance**:
   ```bash
   docker service logs traefik_traefik | grep -i "request duration"
   ```

2. **Optimize rules** by disabling unused rule sets
3. **Increase Traefik resources**:
   ```yaml
   resources:
     limits:
       memory: 1G
       cpus: '2.0'
   ```

### Plugin Not Loading

1. **Verify experimental plugins section** in static config
2. **Check Traefik version** (requires v3.0+)
3. **Verify network connectivity** to download plugin
4. **Force service update**:
   ```bash
   docker service update --force traefik_traefik
   ```

## Security Best Practices

1. **Regular Updates**: Keep Traefik and Coraza plugin updated
2. **Monitor Logs**: Regularly review WAF logs for attack patterns
3. **Tune Gradually**: Start with lower paranoia, increase based on needs
4. **Test Changes**: Always test in staging before production
5. **Document Exclusions**: Keep track of custom rules and exclusions
6. **Review Metrics**: Monitor false positive rates
7. **Incident Response**: Have a plan for handling detected attacks
8. **Backup Configs**: Version control all WAF configurations

## Performance Considerations

- **Rule Evaluation**: Coraza evaluates rules efficiently with caching
- **Transformation Caching**: Reduces repeated transformations
- **Immutable Rules**: Rules don't get copied per transaction
- **Expected Latency**: ~2-5ms per request with CRS enabled
- **Resource Usage**: ~100-200MB RAM per Traefik instance

## References

- [Coraza WAF Documentation](https://coraza.io/)
- [OWASP Core Rule Set](https://coreruleset.org/)
- [Traefik Plugin Documentation](https://plugins.traefik.io/)
- [Coraza Traefik Plugin](https://github.com/jcchavezs/coraza-http-wasm-traefik)

## Support and Maintenance

### Configuration Files Location

- Static Config: `/opt/docker/stacks/traefik/data/traefik.yml`
- WAF Rules: `/opt/docker/stacks/traefik/data/configurations/waf.yml`
- TLS Config: `/opt/docker/stacks/traefik/data/configurations/dynamic.yml`
- Website Config: `/opt/docker/stacks/website/docker-compose.yml`

### Regular Maintenance Tasks

- **Weekly**: Review WAF logs for attack patterns
- **Monthly**: Update Traefik and plugins if security patches available
- **Quarterly**: Review and optimize WAF rules based on traffic patterns
- **Yearly**: Comprehensive security audit and penetration testing

## Future Enhancements

- [ ] Extend WAF protection to API endpoints
- [ ] Extend WAF protection to web applications
- [ ] Implement WAF dashboard for visual monitoring
- [ ] Add GeoIP blocking capabilities
- [ ] Integrate with SIEM for centralized logging
- [ ] Implement automated alerting for attack patterns
- [ ] Add machine learning-based threat detection
- [ ] Create custom rule sets for application-specific threats
