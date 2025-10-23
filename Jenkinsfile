@Library('jenkins-share-lib') _

pipeline {
    agent { label 'jenkins-agent-pod' }

    options {
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '20'))
        disableConcurrentBuilds()
    }

    environment {
        REGISTRY_URL   = "docker.io"
        DOCKERHUB_USER = "talko32"

        BACKEND_IMAGE  = "store-backend"
        AUTH_IMAGE     = "store-auth"
        FRONTEND_IMAGE = "store-frontend"
    }

    stages {

        stage('Determine Environment') {
            steps {
                script {
                    def branch = env.BRANCH_NAME ?: "main"
                    if (branch == "main" || branch.contains("main")) {
                        env.DEPLOY_ENV = "prod"
                    } else if (branch == "stage" || branch.contains("stage")) {
                        env.DEPLOY_ENV = "stage"
                    } else {
                        env.DEPLOY_ENV = "dev"
                    }
                    env.K8S_NAMESPACE = env.DEPLOY_ENV

                    echo """
                    ============================================
                    Pipeline Configuration
                    ============================================
                    Branch     : ${branch}
                    Environment: ${env.DEPLOY_ENV}
                    Namespace  : ${env.K8S_NAMESPACE}
                    Build      : #${env.BUILD_NUMBER}
                    ============================================
                    """
                }
            }
        }

        stage('Checkout Source') {
            steps {
                checkout scm
                script {
                    env.PROJECT_NAME = getprojectnamefromgit()
                    echo "PROJECT_NAME = ${env.PROJECT_NAME}"
                }
            }
        }

        stage('Get Versions') {
            steps {
                script {
                    env.BACKEND_VERSION  = getversion('backend/VERSION.txt')
                    env.AUTH_VERSION     = getversion('auth-service/VERSION.txt')
                    env.FRONTEND_VERSION = getversion('jewelry-store/VERSION.txt')

                    echo """
                    ============================================
                    Version Information
                    ============================================
                    Backend  : ${env.BACKEND_VERSION}
                    Auth     : ${env.AUTH_VERSION}
                    Frontend : ${env.FRONTEND_VERSION}
                    ============================================
                    """
                }
            }
        }

        stage('Build & Push Docker Images') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-creds',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh '''#!/bin/bash
                    set -euxo pipefail

                    echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin

                    docker build -t ${DOCKERHUB_USER}/${BACKEND_IMAGE}:${BACKEND_VERSION}.${BUILD_NUMBER} ./backend
                    docker build -t ${DOCKERHUB_USER}/${AUTH_IMAGE}:${AUTH_VERSION}.${BUILD_NUMBER} ./auth-service
                    docker build -t ${DOCKERHUB_USER}/${FRONTEND_IMAGE}:${FRONTEND_VERSION}.${BUILD_NUMBER} ./jewelry-store

                    docker push ${DOCKERHUB_USER}/${BACKEND_IMAGE}:${BACKEND_VERSION}.${BUILD_NUMBER}
                    docker push ${DOCKERHUB_USER}/${AUTH_IMAGE}:${AUTH_VERSION}.${BUILD_NUMBER}
                    docker push ${DOCKERHUB_USER}/${FRONTEND_IMAGE}:${FRONTEND_VERSION}.${BUILD_NUMBER}
                    '''
                }
            }
        }

        stage('Snyk Container Scan (non-blocking)') {
            
            steps {
                script {
                    catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') {
                        snykScan(services: [
                            "${env.BACKEND_VERSION}.${env.BUILD_NUMBER}",
                            "${env.AUTH_VERSION}.${env.BUILD_NUMBER}",
                            "${env.FRONTEND_VERSION}.${env.BUILD_NUMBER}"
                        ])
                    }
                    echo "Snyk scan completed (pipeline continues even if vulnerabilities found)."
                }
            }
        }

        stage('Install Helm & kubectl (if missing)') {
            steps {
                sh '''#!/bin/bash
                set -e
                if ! command -v helm >/dev/null 2>&1; then
                    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
                fi

                if ! command -v kubectl >/dev/null 2>&1; then
                    KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
                    curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
                    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
                fi

                helm version
                kubectl version --client
                '''
            }
        }

        stage('Verify Namespace Exists') {
            steps {
                sh '''#!/bin/bash
                set -e
                if ! kubectl get namespace ${K8S_NAMESPACE} >/dev/null 2>&1; then
                    echo "Namespace '${K8S_NAMESPACE}' does not exist. Aborting by policy (no auto-creation)."
                    exit 1
                fi
                '''
            }
        }

        stage('Manual Approval for Production') {
            when { expression { env.DEPLOY_ENV == "prod" } }
            steps {
                input message: "Approve deployment to PRODUCTION?", ok: "Deploy"
            }
        }

        stage('Deploy via Helm') {
            steps {
                withCredentials([string(credentialsId: 'JWT_SECRET_KEY', variable: 'JWT_SECRET_KEY')]) {
                    sh '''#!/bin/bash
                    set -euxo pipefail

                    VALUES_FILE="./helm/values-${DEPLOY_ENV}.yaml"
                    if [ ! -f "$VALUES_FILE" ]; then
                      VALUES_FILE="./helm/values.yaml"
                    fi

                    helm upgrade --install jewelry-store ./helm \
                        -f "$VALUES_FILE" \
                        --set namespace=${K8S_NAMESPACE} \
                        --set image.registry=${DOCKERHUB_USER} \
                        --set image.backendName=${BACKEND_IMAGE} \
                        --set image.authName=${AUTH_IMAGE} \
                        --set image.frontendName=${FRONTEND_IMAGE} \
                        --set image.backendTag=${BACKEND_VERSION}.${BUILD_NUMBER} \
                        --set image.authTag=${AUTH_VERSION}.${BUILD_NUMBER} \
                        --set image.frontendTag=${FRONTEND_VERSION}.${BUILD_NUMBER} \
                        --set-string jwtSecret="${JWT_SECRET_KEY}" \
                        -n ${K8S_NAMESPACE} \
                        --atomic --wait --timeout 10m
                    '''
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                sh '''#!/bin/bash
                set -e
                kubectl get deploy,po,svc,ing -n ${K8S_NAMESPACE} -o wide || true
                kubectl get configmap,secret -n ${K8S_NAMESPACE} || true
                '''
            }
        }

        stage('Health Check') {
            steps {
                sh '''#!/bin/bash
                set -e
                kubectl wait --for=condition=available deploy --all -n ${K8S_NAMESPACE} --timeout=5m || true
                kubectl get pods -n ${K8S_NAMESPACE}
                '''
            }
        }
    }

    post {
        success {
            echo """
            ============================================
            DEPLOYMENT SUCCESSFUL
            ============================================
            Environment: ${env.DEPLOY_ENV}
            Namespace: ${env.K8S_NAMESPACE}
            Build: #${env.BUILD_NUMBER}

            Images Deployed:
            - Backend: ${env.BACKEND_IMAGE}:${env.BACKEND_VERSION}.${env.BUILD_NUMBER}
            - Auth: ${env.AUTH_IMAGE}:${env.AUTH_VERSION}.${env.BUILD_NUMBER}
            - Frontend: ${env.FRONTEND_IMAGE}:${env.FRONTEND_VERSION}.${env.BUILD_NUMBER}
            ============================================
            """
        }
        failure {
            sh '''#!/bin/bash
            kubectl get all -n ${K8S_NAMESPACE} || true
            helm history jewelry-store -n ${K8S_NAMESPACE} || true
            '''
        }
        always {
            sh '''#!/bin/bash
            docker system prune -f || true
            '''
            echo "Pipeline finished for ${env.BRANCH_NAME}"
        }
    }
}
