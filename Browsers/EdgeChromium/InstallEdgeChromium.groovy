timestamps {
	def edgeChromiumInstallScrtiptsStashName = 'edgeChromiumInstallScrtipts'

	def jobConfigurationJson = readJSON text: JobConfiguration;
	println "JobConfiguration: '${jobConfigurationJson}'";
	String edgeChromiumChannel = jobConfigurationJson.EdgeChromiumChannel?:'stable'
	String majorBrowserVersion = '';
	String minorBrowserVersion = '';
	node ('git') {
		stage ('Take scripts from git') {
			checkout scm;
			dir("${pwd()}/SoftwareUpdate/Browsers/EdgeChromium") {
				stash name: edgeChromiumInstallScrtiptsStashName
			}
		}
		if (jobConfigurationJson.Version) {
			def matcher = jobConfigurationJson.Version =~ /^(\d+)\.(.+)/;
			if (matcher) {
				majorBrowserVersion = matcher.group(1);
				minorBrowserVersion = matcher.group(2);
			}
		}
	}

	node (NodeName) {
		stage ('Install Edge chromium') {
			timeout (30) {
				def currentFolder = pwd()
				unstash edgeChromiumInstallScrtiptsStashName
				if (NODE_LABELS.toLowerCase().contains('macos')) {
					sh 'chmod -R +x ./*.sh'
					sh returnStatus: true, script: "ps -A | grep 'Microsoft Edge.*' | awk '{print \$1}' | xargs kill -9 \$1 2>/dev/null"
					withCredentials([usernamePassword(credentialsId: 'client-node-admin', passwordVariable: 'sudoPassword', usernameVariable: 'clientNodeLogin')]) {
						sh "./InstallEdgeChromium.sh ${edgeChromiumChannel} ${sudoPassword} '${majorBrowserVersion}' '${minorBrowserVersion}' '${env.ARTIFACTORY_ENG_3RDPARTYTOOLS_URL}'"
					}
				} else {
					try {
						powershell "${currentFolder}/InstallEdgeChromium.ps1 -EdgeChromiumChannel ${edgeChromiumChannel} " +
							"-MajorVersion '${majorBrowserVersion}' " +
							"-MinorVersion '${minorBrowserVersion}' " +
							"-LinkTo3rdPartyTools '${env.ARTIFACTORY_ENG_3RDPARTYTOOLS_URL}' "
					} finally {
						def logsFolderPath = "${currentFolder}/Logs"
						if (fileExists(logsFolderPath)) {
							zip (dir: logsFolderPath, glob: '', zipFile: "EdgeChromium${edgeChromiumChannel}InstallationLog.zip", archive: true)
						}
					}
				}
			}
		}
	}
}
