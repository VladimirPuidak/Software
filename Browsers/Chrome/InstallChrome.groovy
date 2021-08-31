#!groovy
properties([
	buildDiscarder(
		logRotator(
			artifactDaysToKeepStr: '',
			artifactNumToKeepStr: '',
			daysToKeepStr: '',
			numToKeepStr: '100')
	),
	disableConcurrentBuilds()
  timestamps()
])

pipeline {
    agent { 
        label 'WindowsClient'                                                                    
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
