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

        stage('Setup Python Virtualenv') {
            steps {
                sh """
                apt-get update && apt-get install -y python3 python3-venv python3-pip
                python3 -m venv .venv
                . .venv/bin/activate
                pip install flake8 pytest
                """
            }
        }

        stage('Lint All Services') {
            steps {
                script {
                    def failed = false
                    try {
                        dir('backend') {
                            sh '. ../.venv/bin/activate && flake8 .'
                        }
                        echo "Backend lint passed"
                    } catch (err) {
                        echo "Backend lint FAILED: ${err.getMessage()}"
                        failed = true
                    }

                    try {
                        dir('auth-service') {
                            sh '. ../.venv/bin/activate && flake8 .'
                        }
                        echo "Auth Service lint passed"
                    } catch (err) {
                        echo "Auth Service lint FAILED: ${err.getMessage()}"
                        failed = true
                    }

                    try {
                        dir('jewelry-store') {
                            sh 'npm ci && npm run lint'
                        }
                        echo "Frontend lint passed"
                    } catch (err) {
                        echo "Frontend lint FAILED: ${err.getMessage()}"
                        failed = true
                    }

                    if (failed) {
                        error("One or more lint checks failed. See above for details.")
                    } else {
                        echo "All lint checks passed for all services"
                    }
                }
            }
        }

        stage('Unit Tests for All Services') {
            steps {
                script {
                    def failed = false
                    def results = []

                    try {
