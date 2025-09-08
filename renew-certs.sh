#!/bin/bash
cd /root/chattingo
docker compose run --rm certbot renew
docker compose exec nginx nginx -s reload
