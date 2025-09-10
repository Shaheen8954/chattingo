# 🚀 Chattingo - Mini Hackathon Challenge

A full-stack real-time chat application built with React, Spring Boot, and WebSocket technology. **Your mission**: Containerize this application using Docker and deploy it to Hostinger VPS using Jenkins CI/CD pipeline.


## 🎯 **Hackathon Challenge**
Transform this vanilla application into a production-ready, containerized system with automated deployment!

## 📋 Table of Contents

- [Architecture Overview](#️-architecture-overview)
- [Technology Stack](#️-technology-stack)
- [Application Features](#-application-features)
- [Project Structure](#-project-structure)


## 🎯 Project Goals
- **Build & Deploy**: Create Dockerfiles and containerize the application
- **CI/CD Pipeline**: Implement Jenkins automated deployment
- **VPS Deployment**: Deploy on Hostinger VPS using modern DevOps practices


## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │   Backend       │    │   Database      │
│   (React)       │◄──►│   (Spring Boot) │◄──►│   (MySQL)       │
│   Port: 80      │    │   Port: 8080    │    │   Port: 3306    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │
         └────── WebSocket ──────┘
```

## 🛠️ Technology Stack

### Frontend
- **React 18** - Modern UI framework
- **Redux Toolkit** - State management
- **Material-UI** - Component library
- **Tailwind CSS** - Utility-first CSS
- **WebSocket (SockJS + STOMP)** - Real-time messaging
- **React Router** - Client-side routing

### Backend
- **Spring Boot 3.3.1** - Java framework
- **Spring Security** - Authentication & authorization
- **Spring Data JPA** - Database operations
- **Spring WebSocket** - Real-time communication
- **JWT** - Token-based authentication
- **MySQL** - Database


## 🚀 Quick Start

### **Just Registered? Start Here!**

#### **Step 1: Fork & Clone**
```bash
# Fork this repository on GitHub: https://github.com/iemafzalhassan/chattingo
# Then clone your fork
git clone https://github.com/YOUR_USERNAME/chattingo.git
cd chattingo
```






## 📱 Application Features

### Core Functionality
- ✅ User authentication (JWT)
- ✅ Real-time messaging (WebSocket)
- ✅ Group chat creation
- ✅ User profile management
- ✅ Message timestamps
- ✅ Responsive design

### API Endpoints
```
POST   /api/auth/register    - User registration
POST   /api/auth/login       - User login
GET    /api/users            - Get users
POST   /api/chats/create     - Create chat
GET    /api/chats            - Get user chats
POST   /api/messages/create  - Send message
GET    /api/messages/{chatId} - Get chat messages
WS     /ws                   - WebSocket endpoint
```

## 📊 Project Structure

```
chattingo/
├── backend/                 # Spring Boot application
│   ├── src/main/java/
│   │   └── com/chattingo/
│   │       ├── Controller/  # REST APIs
│   │       ├── Service/     # Business logic
│   │       ├── Model/       # JPA entities
│   │       └── config/      # Configuration
│   ├── src/main/resources/
│   │   └── application.properties
│   ├── .env                 # Environment variables
│   └── pom.xml
├── frontend/               # React application
│   ├── src/
│   │   ├── Components/     # React components
│   │   ├── Redux/          # State management
│   │   └── config/         # API configuration
│   ├── .env                # Environment variables
│   └── package.json
├── CONTRIBUTING.md         # Detailed setup & deployment guide
└── README.md              # This file
```




