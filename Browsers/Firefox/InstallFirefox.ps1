<# Script purpose: Install Firefox
Prohibits automatic Firefox updates
Self-elevates 'Run as local Admin'
Written in PowerGUI Script Editor 3.8.0.129 x86_64 #>

[CmdletBinding()]
Param(
	[Parameter(Mandatory = $True)]
	[ValidateNotNullOrEmpty()]
	[System.String]$Version,
	[Parameter(Mandatory = $True)]
	[ValidateNotNullOrEmpty()]
	[System.String]$Bitness,
	[Parameter(Mandatory = $True)]
	[ValidateNotNullOrEmpty()]
	[System.String]$language,
	[Parameter(Mandatory = $True)]
	[ValidateNotNullOrEmpty()]
	[uri]$LinkTo3rdPartyTools
)

$ErrorActionPreference = 'Stop'

function DisableAutoUpdate() {
	#Since FF60 there is registry flag which can be used to disable autoupdate
	$registryPathFirefoxPolicies = "HKLM:\Software\Policies\Mozilla\Firefox"
	if (!(Test-Path $registryPathFirefoxPolicies)) {
		New-Item -Path $registryPathFirefoxPolicies -Force
	}
	New-ItemProperty -Path $registryPathFirefoxPolicies -Name 'DisableAppUpdate' -Value 1 -PropertyType DWORD -Force
}

function GatherEventLogs {
	Param(
		[Parameter(Mandatory=$True)]
		[string]$logsFolderPath
	)
	$LastBootUpTime = (Get-CimInstance -ClassName win32_operatingsystem | Select-Object lastbootuptime).lastbootuptime
	$ts = New-TimeSpan -Start $LastBootUpTime -End (Get-Date)
	$LastBootUpMilliseconds = [math]::Round($ts.TotalMilliseconds)
	[string]$applicationLogAllEventsFilePath = (Join-Path -Path $logsFolderPath -ChildPath 'applicationLogAllEvents.evtx')
	[string]$systemLogAllEventsFilePath = (Join-Path -Path $logsFolderPath -ChildPath 'systemLogAllEvents.evtx')
	wevtutil epl Application $applicationLogAllEventsFilePath /ow:"true" /q:"*[System[TimeCreated[timediff(@SystemTime) <= $LastBootUpMilliseconds]]]"
	wevtutil epl System $systemLogAllEventsFilePath /ow:"true" /q:"*[System[TimeCreated[timediff(@SystemTime) <= $LastBootUpMilliseconds]]]"
}

$pathToInstaller = "$($LinkTo3rdPartyTools.AbsoluteUri)Browsers/Firefox/releases/${Version}/${Bitness}/${Language}/Firefox Setup ${Version}.exe"
$firefoxInstaller = "Firefox Setup ${Version}.exe"
$pathToPreferences = "$($LinkTo3rdPartyTools.AbsoluteUri)Browsers/Firefox"

try {
	$tempfolder = $PSScriptRoot
	$configFile = "$tempfolder\ffsetup.ini"
	$browserMainPath = "c:\browsers\firefox\esr"

	# This section elevates privileges, required to successfully execute rest of script
	$myWindowsID = [System.Security.Principal.WindowsIdentity]::GetCurrent()
	$myWindowsPrincipal = new-object System.Security.Principal.WindowsPrincipal($myWindowsID)
	$adminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator

	if ($myWindowsPrincipal.IsInRole($adminRole)) {
		$Host.UI.RawUI.WindowTitle = $myInvocation.MyCommand.Definition + "(Elevated)"
		$Host.UI.RawUI.BackgroundColor = "DarkBlue"
		clear-host
	}
	else {
		$newProcess = new-object System.Diagnostics.ProcessStartInfo "PowerShell"
		$newProcess.Arguments = $myInvocation.MyCommand.Definition
		$newProcess.Verb = "runas"
		[System.Diagnostics.Process]::Start($newProcess)
		exit
	}

	Write-Output 'Downloading browser...'
	$ProgressPreference = 'SilentlyContinue'
	Invoke-WebRequest -Uri $pathToInstaller -OutFile "${tempfolder}/${firefoxInstaller}" -Verbose
	$ver = $Version.Split('.')[0]
	Write-Output "Installing Firefox..."
	$configFile = "$tempfolder\ffsetup.ini"
		@"
[Install]
StartMenuShortcuts=false
MaintenanceService=true
DesktopShortcut=false
CloseAppNoPrompt=false
QuickLaunchShortcut=false
InstallDirectoryPath=$browserMainPath`\ff$ver
"@ > $configFile

	cmd /C "${tempfolder}\${firefoxInstaller}" @("/INI=${configFile}", '/S')
	$exitCode = $LASTEXITCODE
	if ($exitCode -ne 0) {
		Write-Output "Firefox installer finished with exit code: '${exitCode}'"
		exit $exitCode
	}

	$jsPrefsFolder = "$browserMainPath`\ff$ver\defaults\pref"
	Write-Output 'Copy settings...'
	Invoke-WebRequest -Uri "${pathToPreferences}/prefs.js" -OutFile "${jsPrefsFolder}/autoprefs.js" -Verbose
	Invoke-WebRequest -Uri "${pathToPreferences}/mozilla.cfg" -OutFile "${browserMainPath}/ff${ver}/mozilla.cfg" -Verbose
	Invoke-WebRequest -Uri "${pathToPreferences}/override.ini" -OutFile "${browserMainPath}/ff${ver}/override.ini" -Verbose
	DisableAutoUpdate
	Write-Output 'Installation complete.'

	exit 0
}
catch {
	Write-Output ($PSItem | Out-String)
	exit -1
}
finally {
	[string]$logsFolderPath = Join-Path -Path $PSScriptRoot -ChildPath 'Logs';
	New-Item -Path $logsFolderPath -ItemType Directory -Force;
	GatherEventLogs -logsFolderPath $logsFolderPath
}