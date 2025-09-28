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
stage('Unit Tests - Frontend Only') {
    steps {
        script {
            def failed = false
            def results = []

            // Frontend tests only
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
            steps {
                script {
                    def backendVersion  = getversion('backend/VERSION.txt')
                    def authVersion     = getversion('auth-service/VERSION.txt')
                    def frontendVersion = getversion('jewelry-store/VERSION.txt')

                    env.BACKEND_TAG  = "${env.REGISTRY_URL}/${env.PROJECT_NAME}/backend:${backendVersion}.${env.BUILD_NUMBER}"
                    env.AUTH_TAG     = "${env.REGISTRY_URL}/${env.PROJECT_NAME}/auth-service:${authVersion}.${env.BUILD_NUMBER}"
                    env.FRONTEND_TAG = "${env.REGISTRY_URL}/${env.PROJECT_NAME}/jewelry-store:${frontendVersion}.${env.BUILD_NUMBER}"

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
                        echo "Logging in to Docker registry: ${env.REGISTRY_URL}"
                        docker login ${env.REGISTRY_URL} -u ${NEXUS_USER} -p ${NEXUS_PASS}
                        """
                    }
                }
            }
        }

        stage('Build & Push Images') {
            steps {
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
