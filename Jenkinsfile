        stage('Deploy') {
            steps {
                script {
                    if (env.BRANCH_NAME == 'dev') {
                        echo "Deploying DEV environment with docker compose..."
                        withCredentials([string(credentialsId: 'JWT_SECRET_KEY', variable: 'JWT_SECRET_KEY')]) {
                            sh """
                            echo "Using JWT_SECRET_KEY from Jenkins Credentials"
                            export imagenamefrontend=${env.FRONTEND_TAG}
                            export imagenamebackend=${env.BACKEND_TAG}
                            export imagenameauth=${env.AUTH_TAG}
                            export JWT_SECRET_KEY=${JWT_SECRET_KEY}

                            echo "=== DEBUG: Printing image names before compose ==="
                            echo "imagenamefrontend=$imagenamefrontend"
                            echo "imagenamebackend=$imagenamebackend"
                            echo "imagenameauth=$imagenameauth"
                            

                            docker-compose -f docker-compose.yml up -d --force-recreate
                            """
                        }
                    } else if (env.BRANCH_NAME == 'stage') {
                        echo "Deploy to STAGE (echo only, no real deploy executed)"
                    } else if (env.BRANCH_NAME == 'main') {
                        echo "Deploy to PROD (echo only, no real deploy executed)"
                    }
                }
            }
        }
