#!/bin/bash

# Set environment variables for docker-compose
export DockerHubUser=shaheen8954
export ImageTag=42
export MYSQL_ROOT_PASSWORD=chattingo123

echo "Stopping existing containers..."
docker compose down

echo "Starting services with updated configuration..."
docker compose up -d

echo "Waiting for services to start..."
sleep 10

echo "Checking container status..."
docker ps

echo "Checking nginx logs..."
docker logs chattingo-nginx --tail 10

echo "Checking backend logs..."
docker logs chattingo-app --tail 10
