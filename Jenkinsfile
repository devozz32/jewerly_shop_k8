@Library('jenkins-share-lib') _
pipeline {
    agent { label 'docker_agent' }

    environment {
        REGISTRY_URL = "localhost:8082"
        INFRA_REPO   = "https://github.com/devozz32/infra-k8s.git"
        PROJECT_NAME = ""
    }

    stages {

        stage('Checkout Source') {
            steps {
                checkout scm
                script {
                    env.PROJECT_NAME = getprojectnamefromgit()
                    echo "Detected PROJECT_NAME = ${env.PROJECT_NAME}"
                    echo "Branch: ${env.BRANCH_NAME}, Commit: ${env.GIT_COMMIT}"
                }
            }
        }

        stage('Get Versions') {
            steps {
                script {
                    env.BACKEND_VERSION  = getversion('backend/VERSION.txt')
                    env.AUTH_VERSION     = getversion('auth-service/VERSION.txt')
                    env.FRONTEND_VERSION = getversion('jewelry-store/VERSION.txt')

                    env.BACKEND_TAG  = "${env.REGISTRY_URL}/${env.PROJECT_NAME}/backend:${env.BACKEND_VERSION}.${env.BUILD_NUMBER}"
                    env.AUTH_TAG     = "${env.REGISTRY_URL}/${env.PROJECT_NAME}/auth-service:${env.AUTH_VERSION}.${env.BUILD_NUMBER}"
                    env.FRONTEND_TAG = "${env.REGISTRY_URL}/${env.PROJECT_NAME}/jewelry-store:${env.FRONTEND_VERSION}.${env.BUILD_NUMBER}"
                }
                echo """
                Backend tag : ${env.BACKEND_TAG}
                Auth tag    : ${env.AUTH_TAG}
                Frontend tag: ${env.FRONTEND_TAG}
                """
            }
        }

        stage('Build & Push Images') {
            when { expression { env.BRANCH_NAME.endsWith("dev") || env.BRANCH_NAME.endsWith("stage") || env.BRANCH_NAME.endsWith("main") } }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'nexus-cred',
                    usernameVariable: 'NEXUS_USER',
                    passwordVariable: 'NEXUS_PASS'
                )]) {
                    sh """
                    docker login ${env.REGISTRY_URL} -u ${NEXUS_USER} -p ${NEXUS_PASS}
                    docker build -t ${env.BACKEND_TAG} ./backend
                    docker build -t ${env.AUTH_TAG} ./auth-service
                    docker build -t ${env.FRONTEND_TAG} ./jewelry-store
                    docker push ${env.BACKEND_TAG}
                    docker push ${env.AUTH_TAG}
                    docker push ${env.FRONTEND_TAG}
                    """
                }
            }
        }

        stage('Deploy via Helm') {
            when { expression { env.BRANCH_NAME.endsWith("dev") || env.BRANCH_NAME.endsWith("stage") || env.BRANCH_NAME.endsWith("main") } }
            steps {
                script {
                    def namespace = ""
                    if (env.BRANCH_NAME.endsWith("dev")) {
                        namespace = "dev"
                    } else if (env.BRANCH_NAME.endsWith("stage")) {
                        namespace = "stage"
                    } else if (env.BRANCH_NAME.endsWith("main")) {
                        namespace = "prod"
                    }

                    echo "Deploying to namespace: ${namespace}"

                    // משוך את ריפו התשתית
                    dir('infra-k8s') {
                        git branch: 'main', url: "${env.INFRA_REPO}"
                    }

                    withCredentials([string(credentialsId: 'JWT_SECRET_KEY', variable: 'JWT_SECRET_KEY')]) {
                        env.HELM_DIR = "infra-k8s/jewelry-store"
                        env.VALUES_FILE = "${env.HELM_DIR}/values.yaml"

                        // עדכון של תגי התמונות בקובץ values.yaml
                        sh """
                        yq e -i '.backend.image="${env.BACKEND_TAG}"' ${env.VALUES_FILE}
                        yq e -i '.auth.image="${env.AUTH_TAG}"' ${env.VALUES_FILE}
                        yq e -i '.frontend.image="${env.FRONTEND_TAG}"' ${env.VALUES_FILE}
                        """

                        // פריסה עם Helm
                        sh """
                        export JWT_SECRET_KEY=\$JWT_SECRET_KEY
                        helm upgrade --install jewelry-store ${env.HELM_DIR} -f ${env.VALUES_FILE} -n ${namespace} --create-namespace
                        """
                    }
                }
            }
        }
    }

    post {
        always {
            echo "Pipeline finished for branch: ${env.BRANCH_NAME}"
        }
    }
}
