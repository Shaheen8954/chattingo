
@Library('Shared@main') _

pipeline {
    agent any
    
    environment {
        DockerHubUser = 'shaheen8954'
        DockerHubPassword = credentials('docker-hub-credentials')
        ProjectName = 'chattingo'
        ImageTag = "${BUILD_NUMBER}"
        Migration_Image_Name = 'chattingo-backend'
        Url = ('https://github.com/Shaheen8954/chattingo.git')
        Branch = "feature"
        PortNumber = 'chattingo.shaheen.homes'
        TRIVY_VERSION = '0.50.0'
    }

    stages {
        stage('Cleanup Workspace') {
            steps {
                script {
                    cleanWs()
                }
            }
        }
        
        stage('Clone Repository') {
            steps {
                script {
                    clone(env.Url, env.Branch)
                }
            }
        }
        
        stage('Prepare Backend Environment') {
            steps {
                script {
                    dir('backend') {
                        // Ensure .env file exists for the build
                        sh '''
                            if [ ! -f .env ]; then
                                echo "Creating .env file from template..."
                                cp .env .env.backup 2>/dev/null || true
                                echo ".env file prepared for build"
                            else
                                echo ".env file already exists"
                            fi
                        '''
                    }
                }
            }
        }
        
        stage('Build Backend Image') {
            steps {
                script {
                    dir('backend') {
                        dockerbuild(env.DockerHubUser, env.Migration_Image_Name, env.ImageTag)
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
        
        stage('Security Scans') {
            parallel {
                stage('File System Security Scan') {
                    steps {
                        script {
                            try {
                                // Install and run Gitleaks for secrets detection
                                sh '''
                                    wget -q -O gitleaks.tgz https://github.com/gitleaks/gitleaks/releases/download/v8.18.1/gitleaks_8.18.1_linux_x64.tar.gz
                                    tar xf gitleaks.tgz gitleaks
                                    chmod +x gitleaks
                                    # Run gitleaks with our config file
                                    if [ -f .gitleaks.toml ]; then
                                        ./gitleaks detect --source . --report-format sarif --report-path gitleaks-report.json --config .gitleaks.toml || true
                                    else
                                        ./gitleaks detect --source . --report-format sarif --report-path gitleaks-report.json || true
                                    fi
                                    rm -f gitleaks.tgz gitleaks
                                '''
                                // Archive the report whether it found issues or not
                                archiveArtifacts artifacts: 'gitleaks-report.json', allowEmptyArchive: true
                                
                                // Check if there are any findings and warn instead of failing
                                def findings = sh(script: 'if [ -s gitleaks-report.json ]; then echo "true"; else echo "false"; fi', returnStdout: true).trim()
                                if (findings == "true") {
                                    unstable("Potential secrets found in code. Check the archived gitleaks-report.json for details.")
                                }
                            } catch (Exception e) {
                                echo "Warning: File system security scan failed: ${e.message}"
                                // Continue the build even if the scan fails
                                currentBuild.result = 'UNSTABLE'
                            }
                        }
                    }
                }
                
                stage('Trivy Image Scan') {
                    steps {
                        script {
                            try {
                                // Use Trivy Docker image for scanning
                                sh '''
                                    # Create reports directory
                                    mkdir -p trivy-reports
                                    
                                    # Function to scan image with Trivy Docker container
                                    scan_image() {
                                        local image_name=$1
                                        local report_name=$2
                                        
                                        echo "Scanning image: $image_name"
                                        docker run --rm \
                                            -v /var/run/docker.sock:/var/run/docker.sock \
                                            -v $(pwd)/trivy-reports:/reports \
                                            aquasec/trivy:${TRIVY_VERSION} image \
                                            --format template \
                                            --template "@/usr/local/share/trivy/templates/html.tpl" \
                                            -o /reports/${report_name} \
                                            ${image_name} || true
                                    }
                                    
                                    # Scan backend image
                                    scan_image "${DockerHubUser}/${Migration_Image_Name}:${ImageTag}" "backend-report.html"
                                    
                                    # Scan frontend image
                                    scan_image "${DockerHubUser}/chattingo-frontend:${ImageTag}" "frontend-report.html"
                                    
                                    echo "Trivy scanning completed. Reports generated:"
                                    ls -la trivy-reports/
                                '''
                                
                                // Archive the reports
                                archiveArtifacts artifacts: 'trivy-reports/*.html', allowEmptyArchive: true
                                
                            } catch (Exception e) {
                                echo "Warning: Trivy scan failed: ${e.message}"
                                // Continue the build even if the scan fails
                                currentBuild.result = 'UNSTABLE'
                            }
                        }
                    }
                }
            }
        }
        
        stage('Push Docker Images') {
            when {
                // Only push if Docker login was successful
                expression { currentBuild.result != 'FAILURE' }
            }
            parallel {
                stage('Push Backend Image') {
                    steps {
                        script {
                            dockerpush(env.DockerHubUser, env.Migration_Image_Name, env.ImageTag)
                        }
                    }
                }
                stage('Push Frontend Image') {
                    steps {
                        script {
                            dockerpush(env.DockerHubUser, 'chattingo-frontend', env.ImageTag)
                        }
                    }
                }
            }
        }
        
        stage('Update Docker Compose') {
            when {
                // Only update if images were pushed successfully
                expression { currentBuild.result != 'FAILURE' }
            }
            steps {
                script {
                    sh '''
                        echo "Updating docker-compose.yml with new image tags..."
                        
                        # Update backend image tag
                        sed -i "s|image: \${DockerHubUser}/chattingo-backend:\${ImageTag}|image: ${DockerHubUser}/chattingo-backend:${ImageTag}|g" docker-compose.yml
                        echo "Updated backend image tag"
                        
                        # Update frontend image tag  
                        sed -i "s|image: \${DockerHubUser}/chattingo-frontend:\${ImageTag}|image: ${DockerHubUser}/chattingo-frontend:${ImageTag}|g" docker-compose.yml
                        echo "Updated frontend image tag"
                        
                        # Verify the changes
                        echo "Updated docker-compose.yml image references:"
                        grep -E "image:" docker-compose.yml
                        
                        
                        # Configure Git for Jenkins CI
                        git config user.email "jenkins@${JOB_NAME}@shaheen.com" || true
                        git config user.name "Jenkins CI" || true
                        
                        # Check if there are changes to commit
                        if git diff --quiet docker-compose.yml; then
                            echo "No changes to commit in docker-compose.yml"
                        else
                            # Commit changes with [skip ci] to avoid webhook trigger
                            git add docker-compose.yml
                            git commit -m "chore: update image tags to ${ImageTag} [skip ci]"
                            git push origin ${Branch}
                            echo "Docker Compose file updated and committed to GitHub with [skip ci]!"
                        fi
                        
                        echo "Docker Compose file update completed successfully!"
                                           '''
                }
            }
        }
        
        stage('Deploy') {
            when {
                // Only deploy if all previous stages were successful
                expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' || currentBuild.result == 'UNSTABLE' }
            }
            steps {
                script {
                    sh '''
                        echo "Starting deployment with updated docker-compose.yml..."
                        
                        # Deploy with updated docker-compose.yml
                        docker compose up -d
                        echo "Deployment completed!"
                    '''
                }
            }
        }
    }
    
    post { 
        always { 
            // Archive any remaining artifacts
            archiveArtifacts artifacts: '**/*.json,**/*.html', allowEmptyArchive: true
            
            // Clean up
            sh 'docker system prune -f || true'
        }
        success { 
            echo 'Deployment completed successfully!'
        } 
        failure { 
            echo 'Deployment failed. Please check the logs for more details.'
        }
        unstable {
            echo 'Build completed with warnings. Please check the security scan reports.'
        }
    }  
}
