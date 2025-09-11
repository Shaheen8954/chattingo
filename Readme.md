# Chattingo - Production-Ready Real-Time Chat Application

## **Client Handover Documentation**

A fully containerized, production-deployed real-time chat application with automated CI/CD pipeline. This document contains all necessary information for client takeover, maintenance, and future development.

---

## **Production Deployment Information**

### **Live Application**
- **[URL](https://chattingo.shaheen.homes)**: https://chattingo.shaheen.homes
- **Status**: ✅ Production Ready
- **SSL Certificate**: Let's Encrypt (Auto-renewal configured)
- **Deployment Date**: September 2024

### **Infrastructure Details**
- **Hosting**: Hostinger VPS
- **Domain**: chattingo.shaheen.homes
- **CI/CD**: Jenkins Pipeline (Automated)
- **Container Registry**: Docker Hub

---

## **System Architecture**

```
Internet (HTTPS) → Nginx Proxy → [Frontend + Backend + Database]
                                      ↓
                              Docker Compose Stack
```

### **Service Architecture**
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │   Backend       │    │   Database      │
│   (React/Nginx) │◄──►│   (Spring Boot) │◄──►│   (MySQL 8.0)   │
│   Port: 80      │    │   Port: 8080    │    │   Port: 3306    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │
         └────── WebSocket ──────┘
```

---

## **Technology Stack**

### **Frontend**
- **React 18** - Modern UI framework
- **Redux Toolkit** - State management  
- **Material-UI + Tailwind CSS** - Styling
- **WebSocket (SockJS + STOMP)** - Real-time messaging
- **Nginx** - Production web server

### **Backend**
- **Spring Boot 3.3.1** - Java 17 framework
- **Spring Security + JWT** - Authentication
- **Spring Data JPA** - Database operations
- **Spring WebSocket** - Real-time communication
- **MySQL 8.0** - Primary database

### **DevOps & Infrastructure**
- **Docker + Docker Compose** - Containerization
- **Jenkins** - CI/CD automation
- **Nginx** - Reverse proxy & SSL termination
- **Let's Encrypt** - SSL certificates
- **Docker Hub** - Container registry

---

## **Application Features**

### **Core Functionality**
- ✅ User registration & authentication (JWT)
- ✅ Real-time messaging (WebSocket)
- ✅ Group chat creation & management
- ✅ User profile management
- ✅ Message history & timestamps
- ✅ Responsive design (Mobile/Desktop)
- ✅ SSL/HTTPS security

### **API Endpoints**
```
Authentication:
POST   /api/auth/register    - User registration
POST   /api/auth/login       - User login

User Management:
GET    /api/users            - Get users list
GET    /api/users/profile    - Get user profile

Chat Management:
POST   /api/chats/create     - Create new chat
GET    /api/chats            - Get user chats

Messaging:
POST   /api/messages/create  - Send message
GET    /api/messages/{chatId} - Get chat messages

Real-time:
WS     /ws                   - WebSocket endpoint
```

---

## **Deployment & Operations**

### **Current Deployment**
```bash
# Production containers (running)
chattingo-nginx     # Reverse proxy + SSL
chattingo-web       # React frontend  
chattingo-app       # Spring Boot backend
chattingo-db        # MySQL database
chattingo-certbot   # SSL certificate management
```

### **Docker Images**
```bash
# Current production images
shaheen8954/chattingo-frontend:69
shaheen8954/chattingo-backend:69
mysql:8.0
nginx:alpine
certbot/certbot:latest
```

### **Environment Configuration**
```bash
# Production environment variables (configured)
JWT_SECRET=<secure-token>
MYSQL_ROOT_PASSWORD=<secure-password>
SPRING_DATASOURCE_URL=jdbc:mysql://dbservice:3306/chattingo_db
CORS_ALLOWED_ORIGINS=https://chattingo.shaheen.homes
```

---

## **Configuration Files Explained**

### **Frontend Dockerfile**
```dockerfile
# Multi-stage build for React application
FROM node:18-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm install --no-audit --no-fund

FROM node:18-alpine AS build
WORKDIR /app
COPY --from=deps /app/node_modules /app/node_modules
COPY . .
ARG REACT_APP_API_URL
ENV REACT_APP_API_URL=${REACT_APP_API_URL}
RUN npm run build

FROM nginx:alpine AS runtime
COPY --from=build /app/build /usr/share/nginx/html
COPY public/nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx","-g","daemon off;"]
```

**Explanation:**
- **Stage 1 (deps)**: Installs Node.js dependencies
- **Stage 2 (build)**: Builds React application for production
- **Stage 3 (runtime)**: Serves built files using Nginx
- **Benefits**: Smaller final image, faster deployments

### **Backend Dockerfile**
```dockerfile
# Multi-stage build for Spring Boot application
FROM maven:3.8.5-openjdk-17-slim AS deps
WORKDIR /backend
COPY pom.xml ./
RUN mvn -q -DskipTests dependency:go-offline

FROM maven:3.8.5-openjdk-17-slim AS build
WORKDIR /backend
COPY --from=deps /root/.m2 /root/.m2
COPY . .
RUN mvn -q -DskipTests package

FROM gcr.io/distroless/java17-debian12 AS runtime
WORKDIR /app
COPY --from=build /backend/target/*jar /app/app.jar
USER nonroot
EXPOSE 8080
ENTRYPOINT ["java","-jar","/app/app.jar"]
```

**Explanation:**
- **Stage 1 (deps)**: Downloads Maven dependencies
- **Stage 2 (build)**: Compiles Java application
- **Stage 3 (runtime)**: Uses distroless image for security
- **Benefits**: Secure, minimal runtime environment

### **Nginx Configuration (nginx.conf)**
```nginx
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    upstream backend {
        server appservice:8080;  # Backend service
    }

    upstream frontend {
        server web:80;           # Frontend service
    }

    # HTTP server - redirects to HTTPS
    server {
        listen 80;
        server_name chattingo.shaheen.homes;
        
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;  # SSL certificate validation
        }
        
        location / {
            return 301 https://$server_name$request_uri;
        }
    }

    # HTTPS server - main application
    server {
        listen 443 ssl;
        http2 on;
        server_name chattingo.shaheen.homes;

        # SSL certificates
        ssl_certificate /etc/letsencrypt/live/chattingo.shaheen.homes/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/chattingo.shaheen.homes/privkey.pem;

        # API requests to backend
        location /api/ {
            proxy_pass http://backend/api/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # WebSocket connections
        location /ws/ {
            proxy_pass http://backend/ws/;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
        }

        # Frontend static files
        location / {
            proxy_pass http://frontend;
        }
    }
}
```

**Key Functions:**
- **Reverse Proxy**: Routes requests to appropriate services
- **SSL Termination**: Handles HTTPS certificates
- **Load Balancing**: Distributes traffic between services
- **WebSocket Support**: Enables real-time messaging

### **Docker Compose (docker-compose.yml)**
```yaml
services:
  # MySQL Database
  dbservice:
    image: mysql:8.0
    container_name: chattingo-db
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${MYSQL_DATABASE:-chattingo_db}
    ports:
      - "3308:3306"
    volumes:
      - mysql-data:/var/lib/mysql
    healthcheck:
      test: ["CMD-SHELL", "mysqladmin ping -h 127.0.0.1 -uroot -p$${MYSQL_ROOT_PASSWORD}"]
      interval: 5s
      timeout: 5s
      retries: 20

  # Spring Boot Backend
  appservice:
    image: shaheen8954/chattingo-backend:69
    container_name: chattingo-app
    depends_on:
      dbservice:
        condition: service_healthy
    environment:
      SPRING_DATASOURCE_URL: ${SPRING_DATASOURCE_URL}
      SPRING_DATASOURCE_USERNAME: ${SPRING_DATASOURCE_USERNAME:-root}
      SPRING_DATASOURCE_PASSWORD: ${SPRING_DATASOURCE_PASSWORD}
      JWT_SECRET: ${JWT_SECRET}
      CORS_ALLOWED_ORIGINS: ${CORS_ALLOWED_ORIGINS}

  # React Frontend
  web:
    image: shaheen8954/chattingo-frontend:69
    container_name: chattingo-web
    depends_on:
      - appservice

  # Nginx Reverse Proxy
  nginx:
    image: nginx:alpine
    container_name: chattingo-nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./certbot/conf:/etc/letsencrypt:ro
    depends_on:
      - web
      - appservice

  # SSL Certificate Management
  certbot:
    image: certbot/certbot:latest
    container_name: chattingo-certbot
    volumes:
      - ./certbot/conf:/etc/letsencrypt
      - ./certbot/www:/var/www/certbot

volumes:
  mysql-data:

networks:
  appnet:
```

**Service Breakdown:**
- **dbservice**: MySQL database with health checks
- **appservice**: Spring Boot backend application
- **web**: React frontend served by Nginx
- **nginx**: Reverse proxy with SSL termination
- **certbot**: Automatic SSL certificate management

### **Jenkins Pipeline (Jenkinsfile)**
```groovy
@Library('Shared@main') _

pipeline {
    agent any
    
    environment {
        DockerHubUser = 'shaheen8954'
        DockerHubPassword = credentials('docker-hub-credentials')
        ProjectName = 'chattingo'
        ImageTag = "${BUILD_NUMBER}"
        Url = 'https://github.com/Shaheen8954/chattingo.git'
        Branch = "feature"
    }

    stages {
        stage('Cleanup Workspace') {
            steps {
                script {
                    cleanWs()  // Clean previous builds
                }
            }
        }
        
        stage('Clone Repository') {
            steps {
                script {
                    clone(env.Url, env.Branch)  // Get latest code
                }
            }
        }
        
        stage('Build Backend Image') {
            steps {
                script {
                    dir('backend') {
                        dockerbuild(env.DockerHubUser, 'chattingo-backend', env.ImageTag)
                    }
                }
            }
        }

        stage('Build Frontend Image') {
            steps {
                script {
                    dir('frontend') {
                        dockerbuild(env.DockerHubUser, 'chattingo-frontend', env.ImageTag)
                    }
                }
            }
        }

        stage('Security Scan') {
            steps {
                script {
                    // Trivy security scanning
                    trivyscan(env.DockerHubUser, 'chattingo-backend', env.ImageTag)
                    trivyscan(env.DockerHubUser, 'chattingo-frontend', env.ImageTag)
                }
            }
        }

        stage('Push to Registry') {
            steps {
                script {
                    dockerpush(env.DockerHubUser, 'chattingo-backend', env.ImageTag)
                    dockerpush(env.DockerHubUser, 'chattingo-frontend', env.ImageTag)
                }
            }
        }

        stage('Deploy to Production') {
            steps {
                script {
                    // Update docker-compose and restart services
                    deploy(env.ProjectName, env.ImageTag)
                }
            }
        }
    }

    post {
        always {
            cleanWs()  // Cleanup after build
        }
        success {
            echo 'Deployment successful!'
        }
        failure {
            echo 'Deployment failed!'
        }
    }
}
```

**Pipeline Stages:**
1. **Cleanup**: Removes previous build artifacts
2. **Clone**: Gets latest code from repository
3. **Build**: Creates Docker images for frontend/backend
4. **Security Scan**: Scans images for vulnerabilities
5. **Push**: Uploads images to Docker Hub
6. **Deploy**: Updates production environment

**Key Benefits:**
- **Automated**: No manual deployment steps
- **Consistent**: Same process every time
- **Secure**: Security scanning included
- **Rollback**: Easy to revert if issues occur

---

##  **Maintenance & Operations**

### **Server Access**
```bash
# SSH to production server
ssh root@<server-ip>
git clone https://github.com/Shaheen8954/chattingo.git
cd chattingo

# Check application status
docker-compose ps


### **Common Operations**
```bash
# Restart application
docker-compose restart

# Update application (via Jenkins)
# Trigger Jenkins pipeline or manual deployment

# SSL certificate renewal (automatic)
docker-compose exec certbot certbot renew
```

### **Monitoring Commands**
```bash
# Check service health
docker stats

# View application logs
docker-compose logs -f appservice
docker-compose logs -f web
docker-compose logs -f nginx

---

##  **CI/CD Pipeline**

### **Jenkins Pipeline**
- **Repository**: https://github.com/Shaheen8954/chattingo.git
- **Branch**: feature
- **Trigger**: Manual/Webhook
- **Build Process**: 
  1. Cleanup workspace
  2. Clone repository
  3. Build Docker images
  4. Security scan (Trivy)
  5. Push to Docker Hub
  6. Deploy to production

### **Deployment Process**
```bash
# Automated via Jenkins
1. Code push to repository
2. Jenkins builds new images
3. Images pushed to Docker Hub
4. Docker compose file updated
5. Production containers starts
6. Health checks performed
```

---

## **Project Structure**

```
chattingo/
├── backend/                    # Spring Boot application
│   ├── src/main/java/com/chattingo/
│   │   ├── Controller/         # REST API controllers
│   │   ├── Service/           # Business logic
│   │   ├── Model/             # JPA entities
│   │   ├── Repository/        # Data access
│   │   └── config/            # Security & WebSocket config
│   ├── Dockerfile             # Backend container config
│   ├── pom.xml               # Maven dependencies
│   └── .env                  # Environment variables
├── frontend/                  # React application
│   ├── src/
│   │   ├── Components/       # React components
│   │   ├── Redux/            # State management
│   │   └── config/           # API configuration
│   ├── Dockerfile            # Frontend container config
│   ├── package.json          # NPM dependencies
│   └── .env                  # Environment variables
├── nginx/
│   └── nginx.conf            # Reverse proxy configuration
├── certbot/                  # SSL certificate storage
├── docker-compose.yml        # Multi-container orchestration
├── Jenkinsfile              # CI/CD pipeline definition
└── README.md                # This documentation
```

---


### **Key Files for Maintenance**
- `docker-compose.yml` - Service orchestration
- `nginx/nginx.conf` - Proxy configuration  
- `Jenkinsfile` - CI/CD pipeline
- `backend/.env` - Backend configuration
- `frontend/.env` - Frontend configuration

### **Troubleshooting**
```bash
# Application not responding
docker-compose restart

# Database connection issues
docker-compose logs dbservice
docker exec -it chattingo-db mysql -u root -p

# SSL certificate issues
docker-compose logs certbot
docker-compose exec certbot certbot certificates

# Build failures
# Check Jenkins console output
# Verify Docker Hub credentials
```

---

** Application is production-ready and fully operational at https://chattingo.shaheen.homes**

*For technical support or questions, refer to the deployment logs and monitoring dashboards.*




