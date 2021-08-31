
pipeline {
    agent { 
        label 'WindowsClient'                                                                    
        }
    options {
        buildDiscarder(logRotator(numToKeepStr: '10', artifactNumToKeepStr: '10'))
	disableConcurrentBuilds()
        timestamps()
    }
    stages {
        stage("Download Git") {
            steps {
                checkout scm
            }
        }
        stage("Get hostname") {
            steps {
                powershell 'hostname'
            }
        }
    }
}
