@Library('jenkins-share-lib') _
pipeline {
    agent { label 'docker_agent' }

    environment {
        REGISTRY_URL = "localhost:8082"
    }

    stages {
        stage('Clean Workspace') {
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
            when { branch 'dev' }
            steps {
                script {
                    echo "Checking if snyk CLI is installed..."
                    sh '''
                    if command -v snyk >/dev/null 2>&1; then
                      echo "Snyk CLI found: $(snyk --version)"
                    else
                      echo "Snyk CLI not found in PATH"
                      echo "Make sure it is installed in the Docker image or install it with: npm install -g snyk"
                      exit 1
                    fi
                    '''
                }
            }
        }

        stage('Unit Tests - Frontend Only') {
            when { branch 'dev' }
            steps {
                script {
                    def failed = false
                    def results = []
                    try {
                        dir('jewelry-store') {
                            sh '''
                            npm ci
                            npm test -- --watchAll=false
                            '''
                        }
                        results << "Frontend tests passed"
                    } catch (err) {
                        results << "Frontend tests FAILED: ${err.getMessage()}"
                        failed = true
                    }
                    echo "=== Unit Test Summary ==="
                    results.each { echo it }
                    if (failed) {
                        error("Frontend tests failed. See summary above.")
                    } else {
                        echo "All frontend tests passed"
                    }
                }
            }
        }

        stage('Get Versions') {
            when { branch 'dev' }
            steps {
                script {
                    env.BACKEND_VERSION = getversion('backend/VERSION.txt')
                    env.AUTH_VERSION    = getversion('auth-service/VERSION.txt')
                    env.FRONTEND_VERSION = getversion('jewelry-store/VERSION.txt')

                    env.BACKEND_TAG  = "${env.REGISTRY_URL}/${env.PROJECT_NAME}/backend:${env.BACKEND_VERSION}.${env.BUILD_NUMBER}"
                    env.AUTH_TAG     = "${env.REGISTRY_URL}/${env.PROJECT_NAME}/auth-service:${env.AUTH_VERSION}.${env.BUILD_NUMBER}"
                    env.FRONTEND_TAG = "${env.REGISTRY_URL}/${env.PROJECT_NAME}/jewelry-store:${env.FRONTEND_VERSION}.${env.BUILD_NUMBER}"

                    echo "Backend tag: ${env.BACKEND_TAG}"
                    echo "Auth tag: ${env.AUTH_TAG}"
                    echo "Frontend tag: ${env.FRONTEND_TAG}"
                }
            }
        }

        stage('Docker Login') {
            when { branch 'dev' }
            steps {
                script {
                    withCredentials([usernamePassword(
                        credentialsId: 'nexus-cred',
                        usernameVariable: 'NEXUS_USER',
                        passwordVariable: 'NEXUS_PASS'
                    )]) {
                        sh """
                        echo "Logging in to Docker registry: ${env.REGISTRY_URL}"
                        docker login ${env.REGISTRY_URL} -u ${NEXUS_USER} -p ${NEXUS_PASS}
                        """
                    }
                }
            }
        }

        stage('Build Images') {
            when { branch 'dev' }
            steps {
                sh """
                docker build -t ${env.BACKEND_TAG} ./backend
                docker build -t ${env.AUTH_TAG} ./auth-service
                docker build -t ${env.FRONTEND_TAG} ./jewelry-store
                """
            }
        }

        stage('Snyk Container Scan') {
            when { branch 'dev' }
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
            when { branch 'dev' }
            steps {
                sh """
                docker push ${env.BACKEND_TAG}
                docker push ${env.AUTH_TAG}
                docker push ${env.FRONTEND_TAG}
                """
            }
        }

        stage('Deploy') {
            steps {
                script {
                    if (env.BRANCH_NAME == 'dev') {
                        echo "Recreating DEV environment with docker-compose..."
                        withCredentials([string(credentialsId: 'jwt-secret', variable: 'JWT_SECRET_KEY')]) {
                            sh """
                            echo "Using JWT_SECRET_KEY from Jenkins Credentials"
                            imagenamefrontend=${env.FRONTEND_TAG} \
                            imagenamebackend=${env.BACKEND_TAG} \
                            imagenameauth=${env.AUTH_TAG} \
                            JWT_SECRET_KEY=${JWT_SECRET_KEY} \
                            docker compose -f docker-compose.yml down || true

                            imagenamefrontend=${env.FRONTEND_TAG} \
                            imagenamebackend=${env.BACKEND_TAG} \
                            imagenameauth=${env.AUTH_TAG} \
                            JWT_SECRET_KEY=${JWT_SECRET_KEY} \
                            docker compose -f docker-compose.yml up -d --force-recreate --remove-orphans
                            """
                        }
                    }
                    else if (env.BRANCH_NAME == 'stage') {
                        echo "Deploy to STAGE (echo only, no real deploy executed)"
                    }
                    else if (env.BRANCH_NAME == 'main') {
                        echo "Deploy to PROD (echo only, no real deploy executed)"
                    }
                }
            }
        }
    }
}
