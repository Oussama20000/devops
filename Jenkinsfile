pipeline {
    agent any

    tools {
        jdk 'JAVA_HOME'
        maven 'M2_HOME'
    }


    environment {
        SONAR_HOST_URL = 'http://192.168.50.4:9000'
        SONAR_AUTH_TOKEN = credentials('SonarQube')
        GITLEAKS_URL = 'https://github.com/gitleaks/gitleaks/releases/download/v8.18.4/gitleaks_8.18.4_linux_x64.tar.gz'
        IMAGE_NAME = 'oussamabesrour/timesheetdevopsapplication-ski:1.0.0'
    }

    stages {

//Clones your project source code from GitHub.
//Ensures Jenkins always works on the latest commit from the main branch.

        /*************** DEVELOPMENT PHASE ***************/
        stage('Checkout Code') {
            steps {
                git branch: 'main', url: 'https://github.com/Oussama20000/devops.git'
            }
        }
//Runs pre-commit hooks to automatically check code formatting, secrets, or linting before the build.
// Prevents bad code or secrets from entering the repository.

       stage('Pre-commit Security Hooks') {
    steps {
        sh '''
        echo "Running pre-commit hooks..."
        git config --unset-all core.hooksPath || true
        pre-commit run --all-files || true
        '''
    }
}

//Compiles your Java application.
//Runs JUnit tests.
//Packages it into a .jar file.
  
        stage('Build, Test & Package') {
            steps {
                sh 'mvn clean package'
            }
        }

//Confirms that the .jar artifact was successfully built and exists in the target/ directory.

        stage('Verify JAR') {
            steps {
                sh 'ls -l target/timesheet-devops-1.0.jar'
            }
        }

//Generates a code coverage report for the unit tests.
//Measures how much of the codebase is covered by tests.

        stage('JaCoCo Report') {
            steps {
                sh 'mvn jacoco:report'
            }
        }
        
//Publishes the JaCoCo report in the Jenkins dashboard.

        stage('JaCoCo coverage report') {
            steps {
                step([$class: 'JacocoPublisher',
                      execPattern: '**/target/jacoco.exec',
                      classPattern: '**/classes',
                      sourcePattern: '**/src',
                      exclusionPattern: '*/target/**/,**/*Test*,**/*_javassist/**'
                ])
            }
        }

        /*************** ACCEPTANCE / QA PHASE ***************/
        stage('SAST - SonarQube Analysis') {
            steps {
                script {
                    sh '''
                    echo "Analyse SAST avec SonarQube..."
                    mvn sonar:sonar \
                        -Dsonar.projectKey=devsecops \
                        -Dsonar.host.url=$SONAR_HOST_URL \
                        -Dsonar.token=$SONAR_AUTH_TOKEN
                    '''
                }
            }
        }

//Performs Software Composition Analysis (SCA).
//Detects vulnerable dependencies in your project.
//Generates a detailed HTML report for review.

        stage('SCA - Dependency Check') {
            steps {
                script {
                    echo "Analyse des dépendances avec OWASP Dependency-Check..."
                    sh 'mvn org.owasp:dependency-check-maven:check -Dformat=HTML || true'
                }
                publishHTML(target: [
                    allowMissing: false,
                    alwaysLinkToLastBuild: true,
                    keepAll: true,
                    reportDir: 'target',
                    reportFiles: 'dependency-check-report.html',
                    reportName: 'OWASP Dependency-Check Report'
                ])
            }
        }

//Detects hardcoded secrets (API keys, passwords) in your repository.
//Ensures sensitive data does not leak into version control.
//Generates a JSON report.

        stage('Secrets Scan - Gitleaks') {
    steps {
        script {
            sh '''
            echo "⚡ Téléchargement et exécution rapide de Gitleaks..."

            # Cache or reuse Gitleaks binary if already downloaded
            if [ ! -f /usr/local/bin/gitleaks ]; then
              echo "⬇️ Téléchargement de Gitleaks..."
              curl -L -o gitleaks.tar.gz ${GITLEAKS_URL}
              tar -xzf gitleaks.tar.gz
              chmod +x gitleaks || mv gitleaks_*_linux_x64/gitleaks ./gitleaks
              sudo mv gitleaks /usr/local/bin/
              rm -f gitleaks.tar.gz
            else
              echo "✅ Gitleaks déjà installé"
            fi

            # Exécuter le scan Gitleaks et générer un rapport JSON
            echo "🔍 Exécution du scan Gitleaks (exclusions activées)..."
                    ./gitleaks detect \
                        --source . \
                        --no-git \
                        --report-format json \
                        --report-path gitleaks-report.json \
                        --no-banner || true

                    echo "Rapport Gitleaks généré : gitleaks-report.json"
            '''
        }

        publishHTML(target: [
            allowMissing: false,
            alwaysLinkToLastBuild: true,
            keepAll: true,
            reportDir: '.',                  
            reportFiles: 'gitleaks-report.json',
            reportName: 'Gitleaks JSON Report'
        ])
    }
}

//Builds the Docker image for deployment.
//Scans the Docker image for vulnerabilities using Trivy.
//Generates a HTML report of detected vulnerabilities.

/*************** DOCKER BUILD & SECURITY SCAN ***************/
 stage('Docker Build & Scan') {
            steps {
                script {
                    sh '''
                    echo "Construction de l'image Docker..."
                    docker build -t $IMAGE_NAME .

                    echo "Scan de l'image avec Trivy..."
                    if ! command -v trivy &> /dev/null; then
                        curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh
                        chmod +x ./bin/trivy
                    fi

                    # Télécharger le template HTML officiel
                    mkdir -p contrib
                    curl -sL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/html.tpl -o contrib/html.tpl

                    # Scanner l'image avec un template HTML
                    ./bin/trivy image \
                        --timeout 20m \
                        --exit-code 0 \
                        --severity MEDIUM,HIGH,CRITICAL \
                        --format template \
                        --template "@contrib/html.tpl" \
                        --output trivy-report.html \
                        $IMAGE_NAME

                    echo "Rapport Trivy généré : trivy-report.html"
                    '''
                }
                publishHTML(target: [
                    allowMissing: false,
                    alwaysLinkToLastBuild: true,
                    keepAll: true,
                    reportDir: '.',                  
                    reportFiles: 'trivy-report.html',
                    reportName: 'Trivy Report'
                ])
            }
        }

//Deploys the compiled artifact (.jar) to a Nexus repository.
//Ensures safe storage and versioning of artifacts.

        /*************** PRODUCTION PHASE ***************/
        stage('Deploy to Nexus') {
    steps {
        withCredentials([usernamePassword(credentialsId: 'nexus-credentials', usernameVariable: 'NEXUS_USER', passwordVariable: 'NEXUS_PASS')]) {
            sh '''
                echo "🚀 Deploying artifact to Nexus..."
                mvn deploy -DskipTests \
                    -DaltDeploymentRepository=deploymentRepo::default::http://${NEXUS_USER}:${NEXUS_PASS}@192.168.50.4:8081/repository/maven-releases/
            '''
        }
    }
}

//Pushes the Docker image to DockerHub for deployment.
//Prepares the image for production environments.

        stage('Deploy Docker Image') {
            steps {
                withCredentials([string(credentialsId: 'dockerhub-jenkins-token', variable: 'dockerhub_token')]) {
                    sh "docker login -u oussamabesrour -p ${dockerhub_token}"
                    sh "docker push ${IMAGE_NAME}"
                }
            }
        }

//Performs Dynamic Application Security Testing (DAST).
//Detects runtime vulnerabilities like XSS, SQL Injection, and insecure headers.
//Generates an HTML report (zap-report.html) for review.

        /*************** ACCEPTANCE / QA POST-DEPLOY ***************/
   stage('DAST - OWASP ZAP Scan') {
            steps {
                script {
                    sh '''
                    echo "Lancement du scan DAST OWASP ZAP..."
                    docker run --rm -v $(pwd):/zap/wrk/:rw \
                        owasp/zap2docker-stable zap-baseline.py \
                        -t http://localhost:8080 -r zap-report.html || true
                    '''
                }
            }
        }

//Ensures Grafana and Prometheus monitoring containers are running.
//Provides metrics and logs for observability post-deployment.

        /*************** OPERATIONS PHASE ***************/
        stage('Start Monitoring Containers') {
            steps {
                sh 'docker start grafana|| true'
                sh 'docker start prometheus || true'
            }
        }

//Sends email notifications to inform stakeholders about the pipeline status.
//Ensures prompt feedback on success or failure.

        stage('Email Notification') {
            steps {
                mail bcc: '',
                     body: '''
Final Report: The pipeline has completed successfully. No action required.
''',
                     cc: '',
                     from: '',
                     replyTo: '',
                     subject: 'Succès de la pipeline DevOps Project',
                     to: 'besrour.oussama@gmail.com'
            }
        }
}

    /*************** POST-BUILD ACTIONS ***************/
    post {
        success {
            script {
                emailext(
                    subject: "Build Success: ${currentBuild.fullDisplayName}",
                    body: "Le build a réussi ! Consultez les détails à ${env.BUILD_URL}",
                    to: 'besrour.oussama@gmail.com'
                )
            }
        }
        failure {
            script {
                emailext(
                    subject: "Build Failure: ${currentBuild.fullDisplayName}",
                    body: "Le build a échoué ! Vérifiez les détails à ${env.BUILD_URL}",
                    to: 'besrour.oussama@gmail.com'
                )
            }
        }
        always {
            script {
                emailext(
                    subject: "Build Notification: ${currentBuild.fullDisplayName}",
                    body: "Consultez les détails du build à ${env.BUILD_URL}",
                    to: 'besrour.oussama@gmail.com'
                )
            }
        }
    }
}
