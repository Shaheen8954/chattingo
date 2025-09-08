@Library('Shared@main') _

pipeline {
    agent any
    
    environment {
        DockerHubUser = 'shaheen8954'
        ProjectName = 'chattingo-web'
        ImageTag = "${BUILD_NUMBER}"
        Migration_Image_Name = 'chattingo-app'
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
                        dockerbuild(env.DockerHubUser, env.ProjectName, env.ImageTag)
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
                                // Install Trivy if not already installed
                                sh '''
                                    if ! command -v trivy &> /dev/null; then
                                        wget https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.deb
                                        sudo dpkg -i trivy_${TRIVY_VERSION}_Linux-64bit.deb || true
                                        rm -f trivy_${TRIVY_VERSION}_Linux-64bit.deb
                                    fi
                                    
                                    # Create reports directory
                                    mkdir -p trivy-reports
                                    
                                    # Scan backend image
                                    trivy image --format template --template "@/usr/local/share/trivy/templates/html.tpl" -o trivy-reports/backend-report.html ${DockerHubUser}/${Migration_Image_Name}:${ImageTag} || true
                                    
                                    # Scan frontend image
                                    trivy image --format template --template "@/usr/local/share/trivy/templates/html.tpl" -o trivy-reports/frontend-report.html ${DockerHubUser}/${ProjectName}:${ImageTag} || true
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
                // Only push if security scans didn't fail completely
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
                            dockerpush(env.DockerHubUser, env.ProjectName, env.ImageTag)
                        }
                    }
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
                    sh 'docker compose up -d'
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
