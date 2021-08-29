def psScriptName = "InstallGoogleChrome.ps1"
def shellScriptName = "InstallGoogleChrome.sh"

def jobConfigurationJson = readJSON text: JobConfiguration;
println "JobConfiguration: '${jobConfigurationJson}'";
String googleChromeChannel = jobConfigurationJson.GoogleChromeChannel?:'stable';
String majorBrowserVersion = '';
String minorBrowserVersion = '';
node ("git") {
	stage ('Stash scripts') {
		checkout scm;
		dir("${pwd()}/SoftwareUpdate/Browsers/Chrome") {
			stash includes: "${psScriptName}", name: "googleChromeInstallPS"
			stash includes: "${shellScriptName}", name: "googleChromeInstallSH"
		}
	}
}

node (NodeName) {
	stage ('Install Chrome') {
		timeout (30) {
			timestamps {
				if (jobConfigurationJson.Version) {
					def matcher = jobConfigurationJson.Version =~ /^(\d+)\.(.+)/;
					if (matcher) {
						majorBrowserVersion = matcher.group(1);
						minorBrowserVersion = matcher.group(2);
					}
				}
				def currentFolder = pwd()
				if (NODE_LABELS.toLowerCase().contains("macos")) {
					echo "Current folder - ${currentFolder}"
					unstash "googleChromeInstallSH"
					sh "chmod +x ./${shellScriptName}"
					sh returnStatus: true, script: "killall -9 \"Google Chrome\" 2>/dev/null"
					sh "./${shellScriptName} ${googleChromeChannel} '${majorBrowserVersion}' '${minorBrowserVersion}' '${env.ARTIFACTORY_ENG_3RDPARTYTOOLS_URL}'"
				} else {
					unstash "googleChromeInstallPS"
					try {
						powershell "${currentFolder}\\${psScriptName} -Edition ${googleChromeChannel} " +
							"-MajorVersion '${majorBrowserVersion}' " +
							"-MinorVersion '${minorBrowserVersion}' " +
							"-LinkTo3rdPartyTools '${env.ARTIFACTORY_ENG_3RDPARTYTOOLS_URL}' "
					} finally {
						def logsFolderPath = "${currentFolder}/Logs"
						if (fileExists(logsFolderPath)) {
							zip (dir: logsFolderPath, glob: '', zipFile: "GoogleChrome${googleChromeChannel}InstallationLog.zip", archive: true)
						}
					}
				}
			}
		}
	}
}
