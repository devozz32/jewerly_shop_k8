@Library('jenkins-share-lib') _
pipeline {
    agent { label 'docker_agent' }

    environment {
        REGISTRY_URL = "localhost:8082"
    }

    stages {
        stage('Debug Branch') {
            steps {
                echo "DEBUG: BRANCH_NAME = '${env.BRANCH_NAME}'"
            }
        }

        stage('Clean Workspace') {
            when { expression { env.BRANCH_NAME.endsWith("dev") } }
            steps {
                script { cleanworkspace() }
            }
        }

        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.PROJECT_NAME = getprojectnamefromgit()
                    echo "Detected PROJECT_NAME = ${env.PROJECT_NAME}"
                    echo "Branch: ${env.BRANCH_NAME}, Commit: ${env.GIT_COMMIT}"
                }
            }
        }

        stage('Verify Snyk CLI') {
            when { expression { env.BRANCH_NAME.endsWith("dev") } }
            steps {
                sh '''
                if command -v snyk >/dev/null 2>&1; then
                  echo "✅ Snyk CLI found: $(snyk --version)"
                else
                  echo "❌ Snyk CLI not found"
                  exit 1
                fi
                '''
            }
        }

        stage('Unit Tests - Frontend Only') {
            when { expression { env.BRANCH_NAME.endsWith("dev") } }
            steps {
                dir('jewelry-store') {
                    sh '''
                    npm ci
                    npm test -- --watchAll=false
                    '''
                }
            }
        }

        stage('Get Versions') {
            when { expression { env.BRANCH_NAME.endsWith("dev") } }
            steps {
                script {
                    env.BACKEND_VERSION  = getversion('backend/VERSION.txt')
                    env.AUTH_VERSION     = getversion('auth-service/VERSION.txt')
                    env.FRONTEND_VERSION = getversion('jewelry-store/VERSION.txt')

                    env.BACKEND_TAG  = "${env.REGISTRY_URL}/${env.PROJECT_NAME}/backend:${env.BACKEND_VERSION}.${env.BUILD_NUMBER}"
                    env.AUTH_TAG     = "${env.REGISTRY_URL}/${env.PROJECT_NAME}/auth-service:${env.AUTH_VERSION}.${env.BUILD_NUMBER}"
                    env.FRONTEND_TAG = "${env.REGISTRY_URL}/${env.PROJECT_NAME}/jewelry-store:${env.FRONTEND_VERSION}.${env.BUILD_NUMBER}"

                    echo "Backend tag : ${env.BACKEND_TAG}"
                    echo "Auth tag    : ${env.AUTH_TAG}"
                    echo "Frontend tag: ${env.FRONTEND_TAG}"
                }
            }
        }

        stage('Docker Login') {
            when { expression { env.BRANCH_NAME.endsWith("dev") } }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'nexus-cred',
                    usernameVariable: 'NEXUS_USER',
                    passwordVariable: 'NEXUS_PASS'
                )]) {
                    sh "docker login ${env.REGISTRY_URL} -u ${NEXUS_USER} -p ${NEXUS_PASS}"
                }
            }
        }

        stage('Build Images') {
            when { expression { env.BRANCH_NAME.endsWith("dev") } }
            steps {
                sh """
                docker build -t ${env.BACKEND_TAG} ./backend
                docker build -t ${env.AUTH_TAG} ./auth-service
                docker build -t ${env.FRONTEND_TAG} ./jewelry-store
                """
            }
        }

        stage('Snyk Container Scan') {
            when { expression { env.BRANCH_NAME.endsWith("dev") } }
            steps {
                script {
                    snykScan(services: [
                        "${env.BACKEND_TAG}",
                        "${env.AUTH_TAG}",
                        "${env.FRONTEND_TAG}"
                    ])
                }
            }
        }

        stage('Push Images') {
            when { expression { env.BRANCH_NAME.endsWith("dev") } }
            steps {
                sh """
                docker push ${env.BACKEND_TAG}
                docker push ${env.AUTH_TAG}
                docker push ${env.FRONTEND_TAG}
                """
            }
        }

        stage('Deploy DEV') {
            when { expression { env.BRANCH_NAME.endsWith("dev") } }
            steps {
                script {
                    def composeCmd = "docker-compose"
                    if (sh(script: "command -v docker compose >/dev/null 2>&1", returnStatus: true) == 0) {
                        composeCmd = "docker compose"
                    }

                    withCredentials([string(credentialsId: 'JWT_SECRET_KEY', variable: 'JWT_SECRET_KEY')]) {
                        sh """
                        export imagenamefrontend=${env.FRONTEND_TAG}
                        export imagenamebackend=${env.BACKEND_TAG}
                        export imagenameauth=${env.AUTH_TAG}
                        export JWT_SECRET_KEY=\$JWT_SECRET_KEY

                        echo "=== DEBUG: Printing image names before compose ==="
                        echo "imagenamefrontend=\$imagenamefrontend"
                        echo "imagenamebackend=\$imagenamebackend"
                        echo "imagenameauth=\$imagenameauth"

                        ${composeCmd} -f docker-compose.yml up -d --force-recreate --remove-orphans
                        """
                    }
                }
            }
        }

        stage('Deploy STAGE') {
            when { expression { env.BRANCH_NAME.endsWith("stage") } }
            steps {
                echo "🟡 Deploy to STAGE (echo only, no real deploy executed)"
            }
        }

        stage('Deploy PROD') {
            when { expression { env.BRANCH_NAME.endsWith("main") } }
            steps {
                echo "🟢 Deploy to PROD (echo only, no real deploy executed)"
            }
        }
    }
}
