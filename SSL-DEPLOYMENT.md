# SSL Deployment with Nginx + Certbot

## Initial Setup (Run Once)

1. **Update email in init script:**
   ```bash
   # Edit init-letsencrypt.sh and change email
   email="your-email@domain.com"
   ```

2. **Run SSL initialization:**
   ```bash
   ./init-letsencrypt.sh
   ```

## Regular Deployment (Jenkins/CI)

```bash
# Standard deployment
docker compose down
docker compose up -d dbservice appservice web nginx

# Certificates will persist in ./certbot/ directory
```

## Certificate Renewal

**Automatic (recommended):**
```bash
# Add to crontab for automatic renewal
0 12 * * * /root/chattingo/renew-certs.sh
```

**Manual:**
```bash
./renew-certs.sh
```

## Troubleshooting

- Certificates stored in `./certbot/conf/`
- ACME challenges in `./certbot/www/`
- Check nginx logs: `docker compose logs nginx`
- Check certbot logs: `docker compose logs certbot`
