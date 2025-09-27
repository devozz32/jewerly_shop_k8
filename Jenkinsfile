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
    }
}
