@Library('jenkins-share-lib') _

pipeline {
    agent { label 'jenkins-agent-pod' }

    environment {
        REGISTRY_URL   = "docker.io"
        DOCKERHUB_USER = "talko32"
        INFRA_REPO     = "https://github.com/devozz32/infra-k8s.git"
        INFRA_BRANCH   = "main"
    }

    stages {

        // ───────────────────────────────
        stage('Checkout Source') {
            steps {
                checkout scm
                script {
                    env.PROJECT_NAME = getprojectnamefromgit()
                    echo "✅ Detected PROJECT_NAME = ${env.PROJECT_NAME}"
                    echo "Branch: ${env.BRANCH_NAME}, Commit: ${env.GIT_COMMIT}"

                    // ✅ קביעת סביבה רק אחרי שה־branch נטען
                    env.DEPLOY_ENV = (
                        env.BRANCH_NAME.endsWith('dev')   ? 'dev'   :
                        env.BRANCH_NAME.endsWith('stage') ? 'stage' :
                        env.BRANCH_NAME.endsWith('main')  ? 'prod'  : 'none'
                    )
                    env.K8S_NAMESPACE = env.DEPLOY_ENV

                    echo """
                    ============================================
                    🔍 Environment Info
                    ============================================
                    Branch     : ${env.BRANCH_NAME}
                    Environment: ${env.DEPLOY_ENV}
                    Namespace  : ${env.K8S_NAMESPACE}
                    Build      : #${env.BUILD_NUMBER}
                    ============================================
                    """
                }
            }
        }

        // ───────────────────────────────
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

        // ───────────────────────────────
        stage('Build & Push Images') {
            when { expression { env.DEPLOY_ENV != 'none' } }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-creds',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh """
                        echo "🔐 Docker login..."
                        echo \$DOCKER_PASS | docker login -u \$DOCKER_USER --password-stdin

                        echo "🔨 Building & pushing..."
                        docker build -t ${env.BACKEND_TAG} ./backend
                        docker build -t ${env.AUTH_TAG} ./auth-service
                        docker build -t ${env.FRONTEND_TAG} ./jewelry-store

                        docker push ${env.BACKEND_TAG}
                        docker push ${env.AUTH_TAG}
                        docker push ${env.FRONTEND_TAG}

                        echo "✅ All images pushed!"
                    """
                }
            }
        }

        // ───────────────────────────────
        stage('Checkout Infrastructure Repo') {
            when { expression { env.DEPLOY_ENV != 'none' } }
            steps {
                dir('infra-k8s') {
                    git branch: "${env.INFRA_BRANCH}", url: "${env.INFRA_REPO}"
                }
            }
        }

        // ───────────────────────────────
        stage('Install Helm if Missing') {
            when { expression { env.DEPLOY_ENV != 'none' } }
            steps {
                sh '''
                    if ! command -v helm >/dev/null 2>&1; then
                        echo "🪄 Installing Helm..."
                        curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
                    else
                        echo "✅ Helm already installed."
                    fi
                    helm version
                '''
            }
        }

        // ───────────────────────────────
        stage('Manual Approval for Production') {
            when { expression { env.DEPLOY_ENV == 'prod' } }
            steps {
                input message: '🚨 Deploy to PRODUCTION?', ok: 'Deploy!'
            }
        }

        // ───────────────────────────────
        stage('Deploy via Helm') {
            when { expression { env.DEPLOY_ENV != 'none' } }
            steps {
                withCredentials([string(credentialsId: 'JWT_SECRET_KEY', variable: 'JWT_SECRET_KEY')]) {
                    sh """
                        echo "🚀 Deploying to ${env.DEPLOY_ENV.toUpperCase()} namespace: ${env.K8S_NAMESPACE}"

                        # 🔐 יצירת Secret לפני פריסה
                        kubectl delete secret jwt-secret -n ${env.K8S_NAMESPACE} --ignore-not-found
                        kubectl create secret generic jwt-secret --from-literal=JWT_SECRET_KEY=\$JWT_SECRET_KEY -n ${env.K8S_NAMESPACE}

                        helm upgrade --install jewelry-store infra-k8s/jewelry-store \\
                            -f infra-k8s/jewelry-store/values.yaml \\
                            --set image.registry=${env.REGISTRY_URL}/${env.DOCKERHUB_USER} \\
                            --set image.backendTag=${env.BACKEND_VERSION}.${env.BUILD_NUMBER} \\
                            --set image.authTag=${env.AUTH_VERSION}.${env.BUILD_NUMBER} \\
                            --set image.frontendTag=${env.FRONTEND_VERSION}.${env.BUILD_NUMBER} \\
                            -n ${env.K8S_NAMESPACE} \\
                            --atomic --wait --timeout 10m

                        echo "✅ Helm deploy finished!"
                    """
                }
            }
        }

        // ───────────────────────────────
        stage('Verify & Health Check') {
            when { expression { env.DEPLOY_ENV != 'none' } }
            steps {
                sh """
                    echo "📊 Checking deployment in ${env.K8S_NAMESPACE}"
                    helm status jewelry-store -n ${env.K8S_NAMESPACE} || true
                    kubectl get pods -n ${env.K8S_NAMESPACE} -o wide || true
                    kubectl get svc -n ${env.K8S_NAMESPACE} || true
                    kubectl wait --for=condition=ready pod --all -n ${env.K8S_NAMESPACE} --timeout=5m || true
                """
            }
        }
    }

    post {
        success {
            echo """
            ✅ DEPLOYMENT SUCCESSFUL to ${env.DEPLOY_ENV.toUpperCase()}
            """
        }
        failure {
            echo "❌ DEPLOYMENT FAILED"
        }
        always {
            sh "docker system prune -f || true"
        }
    }
}
