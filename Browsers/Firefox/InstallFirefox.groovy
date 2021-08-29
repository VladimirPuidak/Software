def scriptToInstallFirefox = "InstallFirefox.ps1"

def configuration;
def version = ''
def bitness = ''
def language = ''

stage ("Stash script") {
	node ("git") {
		configuration = readJSON text: JobConfiguration
		echo configuration.toString()
		try {
			version = configuration.Version
			bitness = configuration.Bitness
			language = configuration.Language
		} catch (org.jenkinsci.plugins.workflow.steps.FlowInterruptedException flowInterruptedException) {
			echo "Flow interrupted"
			throw flowInterruptedException;
		} catch (all) {
			error 'Version/Bitness/Language are mandatory params for this job! Check your JSON'
		}
		checkout scm;
		dir("${pwd()}/SoftwareUpdate/Browsers/Firefox") {
			stash includes: scriptToInstallFirefox, name: 'script'
		}
	}
}

stage ("Install Firefox") {
	node (NodeName) {
		if (NODE_LABELS.toLowerCase().contains("macos")) {
			echo "macOS has preinstalled Firefox"
		} else {
			if (bitness == "x32") {
				bitness = "win32"
			} else {
				bitness = "win64"
			}
			timestamps {
				def currentFolder = pwd()
				unstash 'script'
				try {
					powershell "${currentFolder}/${scriptToInstallFirefox} -Version '${version}' " +
						"-Bitness '${bitness}' " +
						"-Language '${language}' " +
						"-LinkTo3rdPartyTools '${env.ARTIFACTORY_ENG_3RDPARTYTOOLS_URL}' "
				} finally {
					def logsFolderPath = "${currentFolder}/Logs"
					if (fileExists(logsFolderPath)) {
						zip (dir: logsFolderPath, glob: '', zipFile: "Firefox${version}${bitness}${language}Log.zip", archive: true)
					}
				}
			}
		}
	}
}
