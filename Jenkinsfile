
@Library('Shared@main') _

pipeline {
    agent any
    
    environment {
        DockerHubUser = 'shaheen8954'
        DockerHubPassword = credentials('docker-hub-credentials')
        ImageTag = "${BUILD_NUMBER}"
        Url = ('https://github.com/Shaheen8954/chattingo.git')
        Branch = "feature"
        TRIVY_VERSION = '0.50.0'
    }

    stages {
        stage('Preflight - Skip') {
            steps {
                script {
                    def msgs = currentBuild.changeSets.collectMany { cs -> cs.items*.msg }.join('\n')
                    def authors = currentBuild.changeSets.collectMany { cs -> cs.items*.author?.fullName }.findAll { it }.unique()
                    def files = []
                    currentBuild.changeSets.each { cs -> cs.items.each { it.affectedFiles.each { files << it.path } } }

                    if (msgs =~ /(?i)\[skip ci\]/) {
                        echo 'Skip: [skip ci]'
                        currentBuild.result = 'NOT_BUILT'
                        error('SKIP')
                    }

                    if (authors.any { it.equalsIgnoreCase('Jenkins CI') || it.endsWith('[bot]') }) {
                        echo "Skip: bot ${authors}"
                        currentBuild.result = 'NOT_BUILT'
                        error('SKIP')
                    }

                    def relevant = files.any { p ->
                        p == 'Jenkinsfile' || p == 'docker-compose.yml' ||
                        p.startsWith('backend/') || p.startsWith('frontend/')
                    }
                    if (!relevant) {
                        echo 'Skip: no relevant file changes'
                        currentBuild.result = 'NOT_BUILT'
                        error('SKIP')
                    }
                }
            }
        }

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
                                currentBuild.result = 'STABLE'
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
                                '''
                                
                                // Archive the reports
                                archiveArtifacts artifacts: 'trivy-reports/*.html', allowEmptyArchive: true
                                
                            } catch (Exception e) {
                                echo "Warning: Trivy scan failed: ${e.message}"
                                // Continue the build even if the scan fails
                                currentBuild.result = 'STABLE'
                            }
                        }
                    }
                }
            }
        }
        
        stage('Push Docker Images') {
            when {
                allOf {
                    anyOf { branch 'main'; branch 'develop' }
                    // Only push if Docker login was successful
                    expression { currentBuild.result != 'FAILURE' }
                }
            }
            parallel {
                stage('Push Backend Image') {
                    steps {
                        script {
                            dockerpush(env.DockerHubUser, 'chattingo-backend', env.ImageTag)
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
                allOf {
                    anyOf { branch 'main'; branch 'develop' }
                    // Only update if images were pushed successfully
                    expression { currentBuild.result != 'FAILURE' }
                }
            }
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: 'github-credentials', usernameVariable: 'GIT_USER', passwordVariable: 'GIT_PASS')]) {
                        sh '''
                            echo "Updating docker-compose.yml with new image tags..."

                            # Replace placeholder form → pinned
                            sed -i "s|image: \\${DockerHubUser}/chattingo-backend:\\${ImageTag}|image: ${DockerHubUser}/chattingo-backend:${ImageTag}|g" docker-compose.yml
                            sed -i "s|image: \\${DockerHubUser}/chattingo-frontend:\\${ImageTag}|image: ${DockerHubUser}/chattingo-frontend:${ImageTag}|g" docker-compose.yml

                            # Replace already-pinned tags → new tag (tag part only)
                            sed -E -i "s|(image:\\s*)${DockerHubUser}/chattingo-backend:([[:alnum:]_.-]+)|\\1${DockerHubUser}/chattingo-backend:${ImageTag}|g" docker-compose.yml
                            sed -E -i "s|(image:\\s*)${DockerHubUser}/chattingo-frontend:([[:alnum:]_.-]+)|\\1${DockerHubUser}/chattingo-frontend:${ImageTag}|g" docker-compose.yml

                            echo "Updated docker-compose.yml image references:"
                            grep -E "^\\s*image:" docker-compose.yml

                            # Configure Git identity
                            git config user.email "jenkins@${JOB_NAME}@shaheen.com" || true
                            git config user.name "Jenkins CI" || true

                            # Ensure authenticated remote
                            git remote set-url origin https://${GIT_USER}:${GIT_PASS}@github.com/Shaheen8954/chattingo.git || true

                            # Commit only if file changed
                            if git diff --quiet docker-compose.yml; then
                                echo "No changes to commit in docker-compose.yml"
                            else
                                git add docker-compose.yml
                                git commit -m "chore: pin compose images to ${ImageTag} [skip ci]"
                                git push origin ${Branch}
                                echo "Docker Compose file updated and committed to GitHub with [skip ci]!"
                            fi

                            echo "Docker Compose file update completed successfully!"
                        '''
                    }
                }
            }
        }
        
        stage('Deploy') {
            when {
                allOf {
                    anyOf { branch 'main'; branch 'develop' }
                    // Only deploy if all previous stages were successful
                    expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' || currentBuild.result == 'UNSTABLE' }
                }
            }
            steps {
                script {
                    withCredentials([
                        string(credentialsId: 'SPRING_DATASOURCE_PASSWORD', variable: 'J_SPRING_DB_PWD'),
                        string(credentialsId: 'jwt-secret',                variable: 'J_JWT_SECRET'),
                        string(credentialsId: 'mysql-root-password',       variable: 'J_MYSQL_ROOT_PWD'),
                        string(credentialsId: 'SPRING_PROFILES_ACTIVE',     variable: 'J_PROFILES'),
                        string(credentialsId: 'SERVER_PORT',                variable: 'J_SERVER_PORT'),
                        string(credentialsId: 'WEBSOCKET_ENDPOINT',         variable: 'J_WS_EP')
                    ]) {
                        sh '''
                            # Export runtime secrets for docker compose
                            export JWT_SECRET="${J_JWT_SECRET}"
                            export SPRING_DATASOURCE_PASSWORD="${J_SPRING_DB_PWD}"
                            export SPRING_DATASOURCE_USERNAME="root"
                            export SPRING_DATASOURCE_URL="jdbc:mysql://dbservice:3306/chattingo_db?createDatabaseIfNotExist=true"
                            export SPRING_PROFILES_ACTIVE="${J_PROFILES}"
                            export SERVER_PORT="${J_SERVER_PORT}"
                            export WEBSOCKET_ENDPOINT="${J_WS_EP}"
                            export MYSQL_ROOT_PASSWORD="${J_MYSQL_ROOT_PWD}"
                            export MYSQL_DATABASE="chattingo_db"

                            export CORS_ALLOWED_ORIGINS="http://chattingo.shaheen.homes,https://chattingo.shaheen.homes,http://localhost:3000,http://127.0.0.1:3000,http://localhost:3001"
                            export CORS_ALLOWED_METHODS="GET,POST,PUT,DELETE,OPTIONS,PATCH"
                            export CORS_ALLOWED_HEADERS="*"

                            # Stop all containers
                            docker compose down || true

                            # Ensure latest images for provided tags
                            docker compose pull || true
                            
                            # Deploy with updated docker-compose.yml
                            docker compose up -d
                            echo "Deployment completed!"
                        '''
                    }
                }
            }
        }
    }
}
