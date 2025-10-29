# How to Apply Security to a New Service

The security middlewares (headers + rate limiting) are already deployed and available.

## Quick Method - Just Add Labels

For any new service, simply add the middleware labels to your docker-compose.yml:

### Example: New API Service

```yaml
version: '3.8'
services:
  api:
    image: your-api:latest
    networks:
      - traefik-public
    deploy:
      labels:
        - traefik.enable=true
        - traefik.http.routers.myapi.rule=Host(`api.afroforgelabs.com`)
        - traefik.http.routers.myapi.entrypoints=websecure
        - traefik.http.routers.myapi.tls.certresolver=letsencrypt
        # ADD THESE TWO LINES for security
        - traefik.http.routers.myapi.middlewares=security-headers@file,rate-limit@file
        - traefik.http.services.myapi.loadbalancer.server.port=8000

networks:
  traefik-public:
    external: true
```

Then deploy:
```bash
docker stack deploy -c docker-compose.yml your-stack-name
```

That's it! No need to run the full `deploy_security.yml` playbook.

## Available Middlewares

- `security-headers@file` - HSTS, X-Frame-Options, X-Content-Type-Options, X-XSS-Protection
- `rate-limit@file` - 100 req/min (burst: 50)

Apply both:
```yaml
- traefik.http.routers.yourservice.middlewares=security-headers@file,rate-limit@file
```

Or just one:
```yaml
# Just headers
- traefik.http.routers.yourservice.middlewares=security-headers@file

# Just rate limiting
- traefik.http.routers.yourservice.middlewares=rate-limit@file
```

## Updating Existing Services

If you already deployed a service and want to add security:

1. **Edit the docker-compose.yml** (add middleware labels)
2. **Redeploy the stack**:
   ```bash
   docker stack deploy -c /path/to/docker-compose.yml stack-name
   ```

Docker will update the service labels without recreating containers.

## Verify Security is Applied

```bash
# Check headers
curl -I https://your-domain.com

# Should see:
# strict-transport-security: max-age=31536000; includeSubDomains; preload
# x-content-type-options: nosniff
# x-frame-options: SAMEORIGIN
# x-xss-protection: 1; mode=block
```

## When to Run Full Playbook

Only run `ansible-playbook playbooks/deploy_security.yml` when:

1. **Fresh deployment** (new cluster)
2. **Changing security configuration** (updating rate limits, adding headers, etc.)
3. **Broken configuration** (need to redeploy everything)
4. **Adding to static config** (changing Traefik base settings)

For normal service deployments, just add the middleware labels!
