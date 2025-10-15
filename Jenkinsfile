@Library('jenkins-share-lib') _

pipeline {
    agent { label 'jenkins-agent-pod' }

    environment {
        // 🐳 Docker Hub
        REGISTRY_URL   = "docker.io"
        DOCKERHUB_USER = "talko32"

        // 🌐 Infra repo
        INFRA_REPO     = "https://github.com/devozz32/infra-k8s.git"
        INFRA_BRANCH   = "main"
    }

    stages {

        // ───────────────────────────────
        stage('Determine Environment') {
            steps {
                script {
                    def branch = env.BRANCH_NAME ?: "main"

                    if (branch == "main" || branch.contains("main")) {
                        env.DEPLOY_ENV = "prod"
                    } else if (branch == "stage" || branch.contains("stage")) {
                        env.DEPLOY_ENV = "stage"
                    } else if (branch == "dev" || branch.contains("dev")) {
                        env.DEPLOY_ENV = "dev"
                    } else {
                        env.DEPLOY_ENV = "dev"
                    }

                    env.K8S_NAMESPACE = env.DEPLOY_ENV

                    echo """
                    ============================================
                    🔍 Pipeline Configuration
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

        // ───────────────────────────────
        stage('Checkout Source') {
            steps {
                checkout scm
                script {
                    env.PROJECT_NAME = getprojectnamefromgit()
                    echo "✅ PROJECT_NAME = ${env.PROJECT_NAME}"
                }
            }
        }

        // ───────────────────────────────
        stage('Get Versions') {
            steps {
                script {
                    env.BACKEND_VERSION  = getversion('backend/VERSION.txt')
                    env.AUTH_VERSION     = getversion('auth-service/VERSION.txt')
                    env.FRONTEND_VERSION = getversion('jewelry-store/VERSION.txt')

                    echo """
                    ============================================
                    📦 Version Information
                    ============================================
                    Backend  : ${env.BACKEND_VERSION}
                    Auth     : ${env.AUTH_VERSION}
                    Frontend : ${env.FRONTEND_VERSION}
                    ============================================
                    """
                }
            }
        }

        // ───────────────────────────────
        stage('Build & Push Docker Images') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-creds',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh '''
                        echo "🔐 Logging in to Docker Hub..."
                        echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin

                        echo "🔨 Building Docker images..."
                        docker build -t ${DOCKERHUB_USER}/store-backend:${BACKEND_VERSION}.${BUILD_NUMBER} ./backend
                        docker build -t ${DOCKERHUB_USER}/store-auth:${AUTH_VERSION}.${BUILD_NUMBER} ./auth-service
                        docker build -t ${DOCKERHUB_USER}/store-frontend:${FRONTEND_VERSION}.${BUILD_NUMBER} ./jewelry-store

                        echo "📤 Pushing images to Docker Hub..."
                        docker push ${DOCKERHUB_USER}/store-backend:${BACKEND_VERSION}.${BUILD_NUMBER}
                        docker push ${DOCKERHUB_USER}/store-auth:${AUTH_VERSION}.${BUILD_NUMBER}
                        docker push ${DOCKERHUB_USER}/store-frontend:${FRONTEND_VERSION}.${BUILD_NUMBER}

                        echo "✅ Images pushed successfully!"
                    '''
                }
            }
        }

        // ───────────────────────────────
        stage('Checkout Infrastructure Repo') {
            steps {
                dir('infra-k8s') {
                    git branch: "${env.INFRA_BRANCH}", url: "${env.INFRA_REPO}"
                }
            }
        }

        // ───────────────────────────────
        stage('Install Helm & kubectl') {
            steps {
                sh '''
                    if ! command -v helm >/dev/null 2>&1; then
                        echo "🪄 Installing Helm..."
                        curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
                    fi
                    helm version

                    if ! command -v kubectl >/dev/null 2>&1; then
                        echo "⚙️ Installing kubectl..."
                        KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
                        curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
                        install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
                    fi
                    kubectl version --client
                '''
            }
        }

        // ───────────────────────────────
        stage('Manual Approval for Production') {
            when { expression { env.DEPLOY_ENV == "prod" } }
            steps {
                input message: "🚨 Deploy to PRODUCTION?", ok: "Deploy!"
            }
        }

        // ───────────────────────────────
        stage('Deploy via Helm (Helm creates Secret)') {
            steps {
                withCredentials([string(credentialsId: 'JWT_SECRET_KEY', variable: 'JWT_SECRET_KEY')]) {
                    script {
                        sh """
                            echo "🚀 Deploying to ${DEPLOY_ENV.toUpperCase()} namespace: ${K8S_NAMESPACE}"

                            # 🧩 Create namespace if missing
                            kubectl get ns ${K8S_NAMESPACE} || kubectl create ns ${K8S_NAMESPACE}

                            # ⚓ Helm upgrade/install — Helm עצמו ייצור את ה־Secret מתוך values
                            helm upgrade --install jewelry-store infra-k8s/jewelry-store \
                                -f infra-k8s/jewelry-store/values.yaml \
                                --set image.registry=${REGISTRY_URL}/${DOCKERHUB_USER} \
                                --set image.backendTag=${BACKEND_VERSION}.${BUILD_NUMBER} \
                                --set image.authTag=${AUTH_VERSION}.${BUILD_NUMBER} \
                                --set image.frontendTag=${FRONTEND_VERSION}.${BUILD_NUMBER} \
                                --set jwtSecret.key=$JWT_SECRET_KEY \
                                -n ${K8S_NAMESPACE} \
                                --atomic --wait --timeout 10m

                            echo "✅ Deployment completed successfully (Secret created by Helm)!"
                        """
                    }
                }
            }
        }

        // ───────────────────────────────
        stage('Verify Deployment') {
            steps {
                sh """
                    echo "📊 Verifying deployment..."
                    kubectl get pods -n ${K8S_NAMESPACE} -o wide
                    kubectl get svc -n ${K8S_NAMESPACE}
                    kubectl get ingress -n ${K8S_NAMESPACE} || echo "No Ingress found"
                """
            }
        }

        // ───────────────────────────────
        stage('Health Check') {
            steps {
                sh """
                    echo "🩺 Checking pod readiness..."
                    kubectl wait --for=condition=ready pod --all -n ${K8S_NAMESPACE} --timeout=5m || echo "⚠️ Some pods not ready"
                    kubectl get pods -n ${K8S_NAMESPACE}
                """
            }
        }
    }

    // ───────────────────────────────
    post {
        success {
            echo """
            ✅ DEPLOYMENT SUCCESSFUL!
            Environment: ${env.DEPLOY_ENV}
            Namespace: ${env.K8S_NAMESPACE}
            Build: #${env.BUILD_NUMBER}
            """
        }
        failure {
            echo "❌ DEPLOYMENT FAILED!"
            sh "kubectl get pods -n ${env.K8S_NAMESPACE} || true"
            sh "helm history jewelry-store -n ${env.K8S_NAMESPACE} || true"
        }
        always {
            sh "docker system prune -f || true"
            echo "🏁 Pipeline finished for ${env.BRANCH_NAME}"
        }
    }
}
