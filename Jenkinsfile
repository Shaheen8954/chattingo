pipeline {
    agent any
    
    environment {
        // Docker Hub Configuration
        BACKEND_IMAGE = 'chattingo-backend'
        FRONTEND_IMAGE = 'chattingo'
        IMAGE_TAG = "${BUILD_NUMBER}"
        
        // Repository Configuration
        GIT_URL = 'https://github.com/Shaheen8954/chattingo.git'
        GIT_BRANCH = 'feature'
        
        // Application Configuration
        DOMAIN = 'chattingo.shaheen.homes'
    }

    stages {
        // Stage 1: Clean workspace
        stage('Clean Workspace') {
            steps {
                echo "🧹 Cleaning workspace..."
                cleanWs()
            }
        }
        
        // Stage 2: Clone repository
        stage('Clone Repository') {
            steps {
                echo "📥 Cloning repository from ${GIT_BRANCH} branch..."
                git branch: "${GIT_BRANCH}", url: "${GIT_URL}"
            }
        }
        
        // Stage 3: Setup environment files
        stage('Setup Environment Files') {
            steps {
                echo "⚙️ Creating environment files..."
                script {
                    // Get secrets from Jenkins credentials
                    withCredentials([
                        string(credentialsId: 'jwt-secret', variable: 'JWT_SECRET'),
                        string(credentialsId: 'db-password', variable: 'DB_PASSWORD'),
                        string(credentialsId: 'mysql-root-password', variable: 'MYSQL_ROOT_PASSWORD')
                    ]) {
                        // Create backend .env file
                        sh '''
                            echo "Creating backend .env file..."
                            cat > backend/.env << EOF
JWT_SECRET=${JWT_SECRET}
SPRING_DATASOURCE_URL=jdbc:mysql://mysql:3306/chattingo_db?createDatabaseIfNotExist=true
SPRING_DATASOURCE_USERNAME=root
SPRING_DATASOURCE_PASSWORD=${DB_PASSWORD}
CORS_ALLOWED_ORIGINS=https://${DOMAIN},http://${DOMAIN}
CORS_ALLOWED_METHODS=GET,POST,PUT,DELETE,OPTIONS,PATCH
CORS_ALLOWED_HEADERS=*
SPRING_PROFILES_ACTIVE=production
SERVER_PORT=8080
WEBSOCKET_ENDPOINT=/ws
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
MYSQL_DATABASE=chattingo_db
EOF
                        '''
                        
                        // Create frontend .env file
                        sh '''
                            echo "Creating frontend .env file..."
                            cat > frontend/.env << EOF
REACT_APP_API_URL=https://${DOMAIN}/api
REACT_APP_WS_URL=wss://${DOMAIN}/ws
REACT_APP_ENV=production
REACT_APP_DEBUG=false
EOF
                        '''
                    }
                }
            }
        }
        
        // Stage 4: Build backend Docker image
        stage('Build Backend Image') {
            steps {
                echo "🐳 Building backend Docker image..."
                script {
                    withCredentials([usernamePassword(credentialsId: 'docker-hub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                        dir('backend') {
                            sh "docker build -t ${DOCKER_USER}/${BACKEND_IMAGE}:${IMAGE_TAG} ."
                        }
                    }
                }
            }
        }
        
        // Stage 5: Build frontend Docker image
        stage('Build Frontend Image') {
            steps {
                echo "🐳 Building frontend Docker image..."
                script {
                    withCredentials([usernamePassword(credentialsId: 'docker-hub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                        dir('frontend') {
                            sh "docker build -t ${DOCKER_USER}/${FRONTEND_IMAGE}:${IMAGE_TAG} ."
                        }
                    }
                }
            }
        }
        
        // Stage 6: File system security scan
        stage('File System Security Scan') {
            steps {
                echo "🔍 Scanning files for security issues..."
                script {
                    sh '''
                        # Download and install Trivy
                        wget -q https://github.com/aquasecurity/trivy/releases/download/v0.50.0/trivy_0.50.0_Linux-64bit.tar.gz
                        tar xzf trivy_0.50.0_Linux-64bit.tar.gz
                        chmod +x trivy
                        
                        # Scan file system and save report to root directory
                        echo "Scanning file system..."
                        ./trivy fs --format json --output filesystem-security-report.json . || true
                        
                        # Create readable HTML report
                        ./trivy fs --format template --template "@contrib/html.tpl" --output filesystem-security-report.html . || true
                        
                        # Cleanup
                        rm -f trivy_0.50.0_Linux-64bit.tar.gz trivy
                        
                        echo "File system scan completed. Reports saved in root directory."
                    '''
                }
            }
        }
        
        // Stage 7: Docker image security scan
        stage('Image Security Scan') {
            steps {
                echo "🔍 Scanning Docker images for vulnerabilities..."
                script {
                    withCredentials([usernamePassword(credentialsId: 'docker-hub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                        sh '''
                            # Download Trivy again (cleaned up in previous stage)
                            wget -q https://github.com/aquasecurity/trivy/releases/download/v0.50.0/trivy_0.50.0_Linux-64bit.tar.gz
                            tar xzf trivy_0.50.0_Linux-64bit.tar.gz
                            chmod +x trivy
                            
                            # Scan backend image
                            echo "Scanning backend image..."
                            ./trivy image --format json --output backend-image-security-report.json ${DOCKER_USER}/${BACKEND_IMAGE}:${IMAGE_TAG} || true
                            ./trivy image --format template --template "@contrib/html.tpl" --output backend-image-security-report.html ${DOCKER_USER}/${BACKEND_IMAGE}:${IMAGE_TAG} || true
                            
                            # Scan frontend image
                            echo "Scanning frontend image..."
                            ./trivy image --format json --output frontend-image-security-report.json ${DOCKER_USER}/${FRONTEND_IMAGE}:${IMAGE_TAG} || true
                            ./trivy image --format template --template "@contrib/html.tpl" --output frontend-image-security-report.html ${DOCKER_USER}/${FRONTEND_IMAGE}:${IMAGE_TAG} || true
                            
                            # Cleanup
                            rm -f trivy_0.50.0_Linux-64bit.tar.gz trivy
                            
                            echo "Image security scans completed. Reports saved in root directory."
                        '''
                    }
                }
            }
        }
        
        // Stage 8: Push images to Docker Hub
        stage('Push Images to Docker Hub') {
            steps {
                echo "📤 Pushing images to Docker Hub..."
                script {
                    withCredentials([usernamePassword(credentialsId: 'docker-hub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                        sh '''
                            echo "Logging into Docker Hub..."
                            echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin
                            
                            echo "Pushing backend image..."
                            docker push ${DOCKER_USER}/${BACKEND_IMAGE}:${IMAGE_TAG}
                            
                            echo "Pushing frontend image..."
                            docker push ${DOCKER_USER}/${FRONTEND_IMAGE}:${IMAGE_TAG}
                            
                            echo "Images pushed successfully!"
                        '''
                    }
                }
            }
        }
        
        // Stage 9: Update docker-compose with new tags
        stage('Update Docker Compose') {
            steps {
                echo "📝 Updating docker-compose.yml with new image tags..."
                script {
                    withCredentials([usernamePassword(credentialsId: 'docker-hub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                        sh '''
                            # Update image tags in docker-compose.yml
                            sed -i "s|image: ${DOCKER_USER}/${BACKEND_IMAGE}:.*|image: ${DOCKER_USER}/${BACKEND_IMAGE}:${IMAGE_TAG}|g" docker-compose.yml
                            sed -i "s|image: ${DOCKER_USER}/${FRONTEND_IMAGE}:.*|image: ${DOCKER_USER}/${FRONTEND_IMAGE}:${IMAGE_TAG}|g" docker-compose.yml
                            
                            # Show the changes
                            echo "Updated docker-compose.yml:"
                            cat docker-compose.yml
                            
                            # Commit changes
                            git config user.email "jenkins@${DOMAIN}"
                            git config user.name "Jenkins CI"
                            git add docker-compose.yml
                            git commit -m "Update image tags to build ${IMAGE_TAG}" || echo "No changes to commit"
                        '''
                    }
                }
            }
        }
        
        // Stage 10: Deploy application
        stage('Deploy Application') {
            steps {
                echo "🚀 Deploying application..."
                script {
                    sh '''
                        echo "Starting deployment with docker-compose..."
                        docker-compose down || true
                        docker-compose up -d
                        
                        echo "Waiting for services to start..."
                        sleep 30
                        
                        echo "Checking service status..."
                        docker-compose ps
                        
                        echo "Deployment completed!"
                    '''
                }
            }
        }
    }
    
    // Post-build actions
    post {
        always {
            echo "📋 Archiving security reports..."
            // Archive all security reports
            archiveArtifacts artifacts: '*-security-report.*', allowEmptyArchive: true
            
            echo "🧹 Cleaning up Docker resources..."
            sh 'docker system prune -f || true'
        }
        success {
            echo "✅ Pipeline completed successfully!"
            echo "🌐 Application is available at: https://${DOMAIN}"
        }
        failure {
            echo "❌ Pipeline failed! Check the logs above for details."
        }
        unstable {
            echo "⚠️ Pipeline completed with warnings. Check security reports."
        }
    }
}