# Dokploy Configuration for Redash

# This file contains instructions for deploying Redash on Dokploy

## Project Configuration

- **Name**: redash
- **Repository**: Your GitHub repository URL
- **Branch**: main (or your preferred branch)
- **Build Method**: Docker Compose
- **Compose File**: docker-compose.prod.yml

## Port Configuration Issue Fix

If you encounter the error "port is already allocated" for port 80, use the alternative compose file:

- **Compose File**: docker-compose.dokploy.yml (uses port 3000 instead)

Or manually change the server port in docker-compose.prod.yml:

```yaml
server:
  ports:
    - "3000:5000" # Change from 80:5000 to 3000:5000
```

## Environment Variables

Copy the contents of `.env.example` to your Dokploy environment variables and modify:

### Required Variables:

```
REDASH_HOST=https://your-domain.com
REDASH_SECRET_KEY=your-generated-secret-key
REDASH_COOKIE_SECRET=your-generated-cookie-secret
REDASH_WTF_CSRF_SECRET_KEY=your-generated-csrf-secret
```

### Optional but Recommended:

```
REDASH_MAIL_SERVER=smtp.your-provider.com
REDASH_MAIL_PORT=587
REDASH_MAIL_USE_TLS=true
REDASH_MAIL_USERNAME=your-email@domain.com
REDASH_MAIL_PASSWORD=your-email-password
REDASH_MAIL_DEFAULT_SENDER=redash@your-domain.com
```

## Port Configuration

- **Main Port**: 3000 (for docker-compose.dokploy.yml)
- **Alternative Port**: 80 (for docker-compose.prod.yml, may conflict)
- **Container Port**: 5000 (internal Redash application port)

**Note**: Dokploy automatically handles SSL/TLS and domain routing, so you don't need to expose port 80 or 443 directly.

## Domain Configuration

Set your domain in Dokploy and ensure it matches the REDASH_HOST environment variable.

## SSL/TLS

Enable SSL in Dokploy for security. Redash should always run over HTTPS in production.

## Health Check

- **Endpoint**: /ping
- **Expected Response**: 200 OK

## Persistent Volumes

Dokploy will automatically handle the Docker volumes defined in docker-compose.prod.yml:

- postgres_data: Database storage
- redis_data: Redis cache storage

## Post-Deployment Steps

1. Wait for all services to start (may take 2-3 minutes)
2. Access your domain to complete initial setup
3. Create admin user through the web interface
4. Configure data sources as needed

## Monitoring

Monitor the following services:

- nginx: Web server and reverse proxy
- server: Main Redash application
- scheduler: Query scheduler
- scheduled_worker: Scheduled query worker
- adhoc_worker: Ad-hoc query worker
- postgres: Database
- redis: Cache and message broker

## Backup Recommendations

- Regular database backups using pg_dump
- Environment variables backup
- Configuration files backup

## Troubleshooting

Common issues and solutions:

1. **Services not starting**: Check logs in Dokploy dashboard
2. **Database connection issues**: Verify PostgreSQL is healthy
3. **Email not working**: Check SMTP configuration
4. **Performance issues**: Adjust worker counts in docker-compose.prod.yml

## Security Considerations

- Always use HTTPS
- Regular security updates
- Strong passwords and secrets
- Network access restrictions
- Regular security audits
