@Library('jenkins-share-lib') _

pipeline {
    agent { label 'docker_agent' }

    stages {
        stage('Clean Workspace') {
            steps {
                script {
                    // Clean everything before doing checkout
                    cleanworkspace()
                }
            }
        }

        stage('Checkout') {
            steps {
                // Explicit checkout so it shows in the logs
                checkout scm
                echo "Branch: ${env.BRANCH_NAME}, Commit: ${env.GIT_COMMIT}"
            }
        }
