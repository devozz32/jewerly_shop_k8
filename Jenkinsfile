@Library('jenkins-share-lib') _

pipeline {
    agent { label 'jenkins-agent-pod' }

    environment {
        // Registry Configuration
        REGISTRY_URL   = "docker.io"
        DOCKERHUB_USER = "talko32"
        
        // Infrastructure Repository
        INFRA_REPO     = "https://github.com/devozz32/infra-k8s.git"
        INFRA_BRANCH   = "main"
        
        // Project Configuration
        PROJECT_NAME   = ""
        
        // Determine environment and namespace based on branch
        DEPLOY_ENV = "${env.BRANCH_NAME.endsWith('dev') ? 'dev' : env.BRANCH_NAME.endsWith('stage') ? 'stage' : env.BRANCH_NAME.endsWith('main') ? 'prod' : 'none'}"
        K8S_NAMESPACE = "${env.BRANCH_NAME.endsWith('dev') ? 'dev' : env.BRANCH_NAME.endsWith('stage') ? 'stage' : env.BRANCH_NAME.endsWith('main') ? 'prod' : 'default'}"
    }

    stages {

        stage('Debug Environment') {
            steps {
                script {
                    echo """
                    ============================================
                    🔍 Pipeline Configuration
                    ============================================
                    Branch: ${env.BRANCH_NAME}
                    Environment: ${env.DEPLOY_ENV}
                    Namespace: ${env.K8S_NAMESPACE}
                    Commit: ${env.GIT_COMMIT?.take(8)}
                    Build: #${env.BUILD_NUMBER}
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
                    echo "✅ Detected PROJECT_NAME = ${env.PROJECT_NAME}"
                    echo "Branch: ${env.BRANCH_NAME}, Commit: ${env.GIT_COMMIT}"
                }
            }
        }

        stage('Get Versions') {
            when { expression { env.BRANCH_NAME =~ /(dev|stage|main)$/ } }
            steps {
                script {
                    env.BACKEND_VERSION  = getversion('backend/VERSION.txt')
                    env.AUTH_VERSION     = getversion('auth-service/VERSION.txt')
                    env.FRONTEND_VERSION = getversion('jewelry-store/VERSION.txt')

                    env.BACKEND_TAG  = "${env.DOCKERHUB_USER}/store-backend:${env.BACKEND_VERSION}.${env.BUILD_NUMBER}"
                    env.AUTH_TAG     = "${env.DOCKERHUB_USER}/store-auth:${env.AUTH_VERSION}.${env.BUILD_NUMBER}"
                    env.FRONTEND_TAG = "${env.DOCKERHUB_USER}/store-frontend:${env.FRONTEND_VERSION}.${env.BUILD_NUMBER}"

                    echo """
                    ============================================
                    📦 Version Information
                    ============================================
                    Backend  : ${env.BACKEND_TAG}
                    Auth     : ${env.AUTH_TAG}
                    Frontend : ${env.FRONTEND_TAG}
                    ============================================
                    """
                }
            }
        }

        stage('Build & Push Images') {
            when { expression { env.BRANCH_NAME =~ /(dev|stage|main)$/ } }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-creds',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh """
                        echo "🔐 Docker login to Docker Hub..."
                        echo \$DOCKER_PASS | docker login -u \$DOCKER_USER --password-stdin

                        echo ""
                        echo "🔨 Building images..."
                        docker build -t ${env.BACKEND_TAG} ./backend
                        docker build -t ${env.AUTH_TAG} ./auth-service
                        docker build -t ${env.FRONTEND_TAG} ./jewelry-store

                        echo ""
                        echo "📤 Pushing images..."
                        docker push ${env.BACKEND_TAG}
                        docker push ${env.AUTH_TAG}
                        docker push ${env.FRONTEND_TAG}

                        echo ""
                        echo "✅ All images built & pushed successfully!"
                    """
                }
            }
        }

        stage('Checkout Infrastructure Repo') {
            when { expression { env.BRANCH_NAME =~ /(dev|stage|main)$/ } }
            steps {
                script {
                    echo "📥 Cloning infrastructure repository..."
                    dir('infra-k8s') {
                        git branch: "${env.INFRA_BRANCH}", url: "${env.INFRA_REPO}"
                    }
                    echo "✅ Infrastructure repo cloned"
                }
            }
        }

        stage('Install Helm') {
            when { expression { env.BRANCH_NAME =~ /(dev|stage|main)$/ } }
            steps {
                sh '''
                    if ! command -v helm >/dev/null 2>&1; then
                        echo "🪄 Installing Helm..."
                        curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
                    else
                        echo "✅ Helm already installed"
                    fi
                    helm version
                '''
            }
        }

        stage('Update Helm Values') {
            when { expression { env.BRANCH_NAME =~ /(dev|stage|main)$/ } }
            steps {
                script {
                    env.HELM_DIR = "infra-k8s/jewelry-store"
                    env.VALUES_FILE = "${env.HELM_DIR}/values.yaml"

                    sh """
                        echo "📝 Updating values.yaml with image tags..."
                        sed -i 's|image:.*store-backend.*|image: ${env.BACKEND_TAG}|' ${env.VALUES_FILE}
                        sed -i 's|image:.*store-auth.*|image: ${env.AUTH_TAG}|' ${env.VALUES_FILE}
                        sed -i 's|image:.*store-frontend.*|image: ${env.FRONTEND_TAG}|' ${env.VALUES_FILE}

                        echo "✅ values.yaml updated successfully!"
                        grep 'image:' ${env.VALUES_FILE}
                    """
                }
            }
        }

        stage('Manual Approval for Production') {
            when { expression { env.BRANCH_NAME.endsWith("main") } }
            steps {
                script {
                    input message: '🚨 Deploy to PRODUCTION?', ok: 'Deploy!'
                }
            }
        }

        stage('Deploy via Helm') {
            when { expression { env.BRANCH_NAME =~ /(dev|stage|main)$/ } }
            steps {
                withCredentials([string(credentialsId: 'JWT_SECRET_KEY', variable: 'JWT_SECRET_KEY')]) {
                    sh """
                        echo "🚀 Deploying to ${env.DEPLOY_ENV.toUpperCase()} environment..."
                        echo "Namespace: ${env.K8S_NAMESPACE}"
                        echo ""
                        
                        export JWT_SECRET_KEY=\$JWT_SECRET_KEY

                        # ⚙️ Deploy without creating new namespace
                        helm upgrade --install jewelry-store ${env.HELM_DIR} \\
                            -f ${env.VALUES_FILE} \\
                            --namespace ${env.K8S_NAMESPACE} \\
                            --wait \\
                            --timeout 10m \\
                            --atomic

                        echo ""
                        echo "✅ ${env.DEPLOY_ENV.toUpperCase()} deployment completed!"
                    """
                }
            }
        }

        stage('Verify Deployment') {
            when { expression { env.BRANCH_NAME =~ /(dev|stage|main)$/ } }
            steps {
                sh """
                    echo ""
                    echo "📊 Verifying deployment in namespace: ${env.K8S_NAMESPACE}"
                    helm status jewelry-store -n ${env.K8S_NAMESPACE} || true
                    kubectl get pods -n ${env.K8S_NAMESPACE} -o wide || true
                    kubectl get svc -n ${env.K8S_NAMESPACE} || true
                    kubectl get ingress -n ${env.K8S_NAMESPACE} || echo "No Ingress"
                """
            }
        }

        stage('Health Check') {
            when { expression { env.BRANCH_NAME =~ /(dev|stage|main)$/ } }
            steps {
                sh """
                    echo "🔍 Checking pod health..."
                    kubectl wait --for=condition=ready pod --all -n ${env.K8S_NAMESPACE} --timeout=5m || echo "⚠️ Some pods are not ready"
                    kubectl get pods -n ${env.K8S_NAMESPACE}
                """
            }
        }
    }

    post {
        success {
            echo """
            ============================================
            ✅ DEPLOYMENT SUCCESSFUL!
            ============================================
            Environment  : ${env.DEPLOY_ENV.toUpperCase()}
            Namespace    : ${env.K8S_NAMESPACE}
            Build        : #${env.BUILD_NUMBER}
            Branch       : ${env.BRANCH_NAME}
            ============================================
            """
        }

        failure {
            echo """
            ============================================
            ❌ DEPLOYMENT FAILED!
            ============================================
            """
            sh """
                kubectl get pods -n ${env.K8S_NAMESPACE} || true
                helm history jewelry-store -n ${env.K8S_NAMESPACE} || true
            """
        }

        always {
            sh """
                echo "🏁 Pipeline finished for branch: ${env.BRANCH_NAME}"
                docker system prune -f || true
            """
        }
    }
}
