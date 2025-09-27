@Library('jenkins-share-lib') _

pipeline {
    agent { label 'docker_agent' }

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
                    env.BACKEND_TAG  = "${getversion('backend/VERSION.txt')}.${env.BUILD_NUMBER}"
                    env.AUTH_TAG     = "${getversion('auth-service/VERSION.txt')}.${env.BUILD_NUMBER}"
                    env.FRONTEND_TAG = "${getversion('jewelry-store/VERSION.txt')}.${env.BUILD_NUMBER}"

                    echo "Backend tag:  ${env.BACKEND_TAG}"
                    echo "Auth tag:     ${env.AUTH_TAG}"
                    echo "Frontend tag: ${env.FRONTEND_TAG}"
                }
            }
        }
    }
}
