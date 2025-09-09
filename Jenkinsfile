@Library('Shared@main') _

// ===========================================
// Chattingo CI/CD Pipeline
// ===========================================

pipeline {
    agent any
    
    environment {
        // Basic Configuration
        DockerHubUser = 'shaheen8954'
        ProjectName = 'chattingo-web'
        Migration_Image_Name = 'chattingo-app'
        ImageTag = "${BUILD_NUMBER}"
        
        // Git Configuration
        GitUrl = 'https://github.com/Shaheen8954/chattingo.git'
        Branch = 'feature'
        
        // Server Configuration
        ServerUrl = 'chattingo.shaheen.homes'
        
        // Security Tools
        TRIVY_VERSION = '0.50.0'
        GITLEAKS_VERSION = '8.18.1'
        
        // Credentials
        DOCKER_CREDS = credentials('docker-hub-credentials')
        MYSQL_ROOT_PASSWORD = credentials('mysql-root-password')
        JWT_SECRET = credentials('z9iomEpv/QtMfd2HTXnLzGt/7+R7I38m9k0T4L7GJa0=')
    }

    stages {
        // Stage 1: Clean Workspace
        stage('Clean Workspace') {
            steps {
                cleanWs()
            }
        }
        
        // Stage 2: Get Code
        stage('Clone Repository') {
            steps {
                script {
                    clone(env.GitUrl, env.Branch)
                }
            }
        }
        
        // Stage 3: Build Images
        stage('Build Docker Images') {
            parallel {
                stage('Build Backend') {
                    steps {
                        script {
                            dir('backend') {
                                dockerbuild(env.DockerHubUser, env.Migration_Image_Name, env.ImageTag)
                            }
                        }
                    }
                }
                
                stage('Build Frontend') {
                    steps {
                        script {
                            dir('frontend') {
                                dockerbuild(env.DockerHubUser, env.ProjectName, env.ImageTag)
                            }
                        }
                    }
                }
            }
        }
        
        // Stage 4: Security Scans
        stage('Security Scans') {
            parallel {
                stage('Secrets Detection') {
                    steps {
                        script {
                            try {
                                sh """
                                    # Install Gitleaks
                                    wget -q -O gitleaks.tgz https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz
                                    tar xf gitleaks.tgz gitleaks
                                    chmod +x gitleaks
                                    
                                    # Run Gitleaks
                                    if [ -f .gitleaks.toml ]; then
                                        ./gitleaks detect --source . --report-format sarif --report-path gitleaks-report.json --config .gitleaks.toml || true
                                    else
                                        ./gitleaks detect --source . --report-format sarif --report-path gitleaks-report.json || true
                                    fi
                                    rm -f gitleaks.tgz gitleaks
                                """
                                archiveArtifacts artifacts: 'gitleaks-report.json', allowEmptyArchive: true
                                
                                def findings = sh(script: 'if [ -s gitleaks-report.json ]; then echo "true"; else echo "false"; fi', returnStdout: true).trim()
                                if (findings == "true") {
                                    unstable("⚠️ Potential secrets found in code. Check gitleaks-report.json for details.")
                                }
                            } catch (Exception e) {
                                echo "⚠️ Warning: File system security scan failed: ${e.message}"
                                currentBuild.result = 'UNSTABLE'
                            }
                        }
                    }
                }
                
                stage('Container Scan') {
                    steps {
                        script {
                            try {
                                sh """
                                    # Install Trivy
                                    if ! command -v trivy &> /dev/null; then
                                        wget -q https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.deb
                                        sudo dpkg -i trivy_${TRIVY_VERSION}_Linux-64bit.deb || true
                                        rm -f trivy_${TRIVY_VERSION}_Linux-64bit.deb
                                    fi
                                    
                                    # Create reports directory
                                    mkdir -p trivy-reports
                                    
                                    # Scan images
                                    trivy image --format template --template "@/usr/local/share/trivy/templates/html.tpl" -o trivy-reports/backend-report.html ${DockerHubUser}/${Migration_Image_Name}:${ImageTag} || true
                                    trivy image --format template --template "@/usr/local/share/trivy/templates/html.tpl" -o trivy-reports/frontend-report.html ${DockerHubUser}/${ProjectName}:${ImageTag} || true
                                """
                                archiveArtifacts artifacts: 'trivy-reports/*.html', allowEmptyArchive: true
                                
                            } catch (Exception e) {
                                echo "⚠️ Warning: Container scan failed: ${e.message}"
                                currentBuild.result = 'UNSTABLE'
                            }
                        }
                    }
                }
            }
        }
        
        // Stage 5: Push Images
        stage('Push Docker Images') {
            when {
                expression { currentBuild.result != 'FAILURE' }
            }
            parallel {
                stage('Push Backend') {
                    steps {
                        script {
                            dockerpush(env.DockerHubUser, env.Migration_Image_Name, env.ImageTag)
                        }
                    }
                }
                stage('Push Frontend') {
                    steps {
                        script {
                            dockerpush(env.DockerHubUser, env.ProjectName, env.ImageTag)
                        }
                    }
                }
            }
        }
        
        // Stage 6: Deploy
        stage('Deploy Application') {
            when {
                expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' || currentBuild.result == 'UNSTABLE' }
            }
            steps {
                script {
                    // Update docker-compose with the new image tags
                    sh """
                        sed -i 's|image: .*/chattingo-app:.*|image: ${DockerHubUser}/chattingo-app:${ImageTag}|' docker-compose.yml
                        sed -i 's|image: .*/chattingo-web:.*|image: ${DockerHubUser}/chattingo-web:${ImageTag}|' docker-compose.yml
                        sed -i 's|MYSQL_ROOT_PASSWORD:.*|MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}|' docker-compose.yml
                    """
                    
                    // Deploy the application
                    sh 'docker compose up -d'
                }
            }
        }
    }
    
    post { 
        always { 
            node {
                script {
                    // Clean up Docker resources
                    sh 'docker system prune -f || true'
                    // Archive any reports
                    archiveArtifacts artifacts: '**/*.json,**/*.html', allowEmptyArchive: true
                }
            }
        }
        success { 
            echo '✅ Deployment completed successfully!'
        } 
        failure { 
            echo '❌ Deployment failed. Check the logs for details.'
        }
        unstable {
            echo '⚠️ Build completed with warnings. Check security scan reports.'
        }
    }  
}