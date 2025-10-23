@Library('jenkins-share-lib') _

pipeline {
    agent { label 'jenkins-agent-pod' }

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
                    sh '''
                        echo "Logging in to Docker Hub..."
                        echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin

                        echo "Building Docker images..."
                        docker build -t ${DOCKERHUB_USER}/${BACKEND_IMAGE}:${BACKEND_VERSION}.${BUILD_NUMBER} ./backend
                        docker build -t ${DOCKERHUB_USER}/${AUTH_IMAGE}:${AUTH_VERSION}.${BUILD_NUMBER} ./auth-service
                        docker build -t ${DOCKERHUB_USER}/${FRONTEND_IMAGE}:${FRONTEND_VERSION}.${BUILD_NUMBER} ./jewelry-store

                        echo "Pushing images to Docker Hub..."
                        docker push ${DOCKERHUB_USER}/${BACKEND_IMAGE}:${BACKEND_VERSION}.${BUILD_NUMBER}
                        docker push ${DOCKERHUB_USER}/${AUTH_IMAGE}:${AUTH_VERSION}.${BUILD_NUMBER}
                        docker push ${DOCKERHUB_USER}/${FRONTEND_IMAGE}:${FRONTEND_VERSION}.${BUILD_NUMBER}

                        echo "Images pushed successfully."
                    '''
                }
            }
        }

        stage('Install Helm & kubectl') {
            steps {
                sh '''
                    if ! command -v helm >/dev/null 2>&1; then
                        echo "Installing Helm..."
                        curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
                    fi

                    if ! command -v kubectl >/dev/null 2>&1; then
                        echo "Installing kubectl..."
                        KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
                        curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
                        install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
                    fi

                    helm version
                    kubectl version --client
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
                    script {
                        sh """
                            echo "Deploying to ${DEPLOY_ENV} (namespace: ${K8S_NAMESPACE})"
                            
                            helm upgrade --install jewelry-store ./helm \
                                -f ./helm/values.yaml \
                                --set namespace=${K8S_NAMESPACE} \
                                --set image.registry=${DOCKERHUB_USER} \
                                --set image.backendName=${BACKEND_IMAGE} \
                                --set image.authName=${AUTH_IMAGE} \
                                --set image.frontendName=${FRONTEND_IMAGE} \
                                --set image.backendTag=${BACKEND_VERSION}.${BUILD_NUMBER} \
                                --set image.authTag=${AUTH_VERSION}.${BUILD_NUMBER} \
                                --set image.frontendTag=${FRONTEND_VERSION}.${BUILD_NUMBER} \
                                --set jwtSecret="\${JWT_SECRET_KEY}" \
                                -n ${K8S_NAMESPACE} \
                                --create-namespace \
                                --atomic --wait --timeout 10m

                            echo "Deployment completed successfully."
                        """
                    }
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                sh """
                    echo "Verifying deployment in namespace: ${K8S_NAMESPACE}"
                    kubectl get pods -n ${K8S_NAMESPACE} -o wide
                    kubectl get svc -n ${K8S_NAMESPACE}
                    kubectl get ingress -n ${K8S_NAMESPACE} || echo "No Ingress found"
                    kubectl get configmap -n ${K8S_NAMESPACE}
                    kubectl get secret -n ${K8S_NAMESPACE}
                """
            }
        }

        stage('Health Check') {
            steps {
                sh """
                    echo "Waiting for pods to be ready..."
                    kubectl wait --for=condition=ready pod --all -n ${K8S_NAMESPACE} --timeout=5m || echo "Some pods not ready"
                    
                    echo "Final pod status:"
                    kubectl get pods -n ${K8S_NAMESPACE}
                """
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
            echo """
            ============================================
            DEPLOYMENT FAILED
            ============================================
            Environment: ${env.DEPLOY_ENV}
            Namespace: ${env.K8S_NAMESPACE}
            Build: #${env.BUILD_NUMBER}
            ============================================
            """
            sh "kubectl get pods -n ${env.K8S_NAMESPACE} || true"
            sh "kubectl describe pods -n ${env.K8S_NAMESPACE} || true"
            sh "helm history jewelry-store -n ${env.K8S_NAMESPACE} || true"
        }
        always {
            sh "docker system prune -f || true"
            echo "Pipeline finished for ${env.BRANCH_NAME}"
        }
    }
}
