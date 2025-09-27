@Library('jenkins-share-lib') _

pipeline {
    agent { label 'docker_agent' }

    environment {
        REGISTRY_URL = "localhost:8082"
       
    }

    stages {
        stage('Clean Workspace') {
            steps {
                script {
                    cleanworkspace()
                }
            }
        }

        stage('Checkout') {
            steps {
                checkout scm
                echo "Branch: ${env.BRANCH_NAME}, Commit: ${env.GIT_COMMIT}"
            }
        }

        stage('Get Versions') {
            steps {
                script {
                    def backendVersion  = getversion('backend/VERSION.txt')
                    def authVersion     = getversion('auth-service/VERSION.txt')
                    def frontendVersion = getversion('jewelry-store/VERSION.txt')

                    env.BACKEND_TAG  = "${REGISTRY_URL}/backend:${backendVersion}.${env.BUILD_NUMBER}"
                    env.AUTH_TAG     = "${REGISTRY_URL}/auth-service:${authVersion}.${env.BUILD_NUMBER}"
                    env.FRONTEND_TAG = "${REGISTRY_URL}/jewelry-store:${frontendVersion}.${env.BUILD_NUMBER}"

                    echo "Backend tag:  ${env.BACKEND_TAG}"
                    echo "Auth tag:     ${env.AUTH_TAG}"
                    echo "Frontend tag: ${env.FRONTEND_TAG}"
                }
            }
        }

        stage('Docker Login') {
            steps {
                script {
                    withCredentials([usernamePassword(
                        credentialsId: 'nexus-cred',
                        usernameVariable: 'NEXUS_USER',
                        passwordVariable: 'NEXUS_PASS'
                    )]) {
                        sh """
                        echo "Logging in to Docker registry: ${REGISTRY_URL}"
                        docker login ${REGISTRY_URL} -u ${NEXUS_USER} -p ${NEXUS_PASS}
                        """
                    }
                }
            }
        }

        stage('Build & Push Images') {
            steps {
                script {
                    sh """
                    docker build -t ${env.BACKEND_TAG} ./backend
                    docker push ${env.BACKEND_TAG}

                    docker build -t ${env.AUTH_TAG} ./auth-service
                    docker push ${env.AUTH_TAG}

                    docker build -t ${env.FRONTEND_TAG} ./jewelry-store
                    docker push ${env.FRONTEND_TAG}
                    """
                }
            }
        }
    }
}
