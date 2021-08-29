param(
	[Parameter(Mandatory = $True)]
	[ValidateNotNullOrEmpty()]
	[string]$EdgeChromiumChannel,
	[Parameter(Mandatory = $False)]
	[ValidateNotNull()]
	[string]$MajorVersion = '',
	[Parameter(Mandatory = $False)]
	[ValidateNotNull()]
	[string]$MinorVersion = '',
	[Parameter(Mandatory = $False)]
	[ValidateNotNullOrEmpty()]
	[uri]$LinkTo3rdPartyTools = 'https://artifacts.aras.com/artifactory/ENG-3rdPartyTools/'
)

$ErrorActionPreference = 'Stop';
Set-StrictMode -Version Latest;
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

[bool]$MsiInstaller = $false;
[string]$pathToLogFile = Join-Path -Path $env:temp -ChildPath 'msedge_installer.log';
[string]$microsoftEdgeChromiumInstaller = Join-Path -Path $PSScriptRoot -ChildPath 'MicrosoftEdgeChromium.exe';
[string]$linkToMicrosoftEdgeChromium = 'https://go.microsoft.com/fwlink/?linkid=2108834&Channel=Stable&language=en';
if ($EdgeChromiumChannel -eq 'beta') {
	$linkToMicrosoftEdgeChromium = 'https://go.microsoft.com/fwlink/?linkid=2100017&Channel=Beta&language=en';
}
elseif ($EdgeChromiumChannel -eq 'dev') {
	$linkToMicrosoftEdgeChromium = 'https://go.microsoft.com/fwlink/?linkid=2069324&Channel=Dev&language=en';
}
if ($MajorVersion.Length -ne 0 -and $MinorVersion.Length -ne 0) {
	$MsiInstaller = $True;
	$microsoftEdgeChromiumInstaller = Join-Path -Path $PSScriptRoot -ChildPath 'MicrosoftEdgeChromium.msi';
	$linkToMicrosoftEdgeChromium = "$($LinkTo3rdPartyTools.AbsoluteUri)Browsers/MicrosoftEdgeChromium/${MajorVersion}/${MinorVersion}/MicrosoftEdgeChromium.msi"
}

function StopAndKillMicrosoftChromiumUpdaterProcesses {
	schtasks /query /v /fo CSV | 
	ForEach-Object { $PSItem.split(",") | Where-Object { $PSItem -like "*MicrosoftEdgeUpdateTaskMachine*" } } | 
	ForEach-Object { schtasks /change /disable /tn $PSItem };
	Get-Service -Name 'edgeupdate*' | Set-Service -StartupType Disabled;
	Get-Service -Name 'edgeupdate*' | Stop-Service;
	Get-Service -Name 'MicrosoftEdge*' | Set-Service -StartupType Disabled;
	Get-Service -Name 'MicrosoftEdge*' | Stop-Service;
	Get-Process -Name 'elevation_service*' | Stop-Process -Force;
	Get-Process -Name 'msedge*' | Stop-Process -Force;
	Get-Process -Name 'microsoftedgeupdate*' | Stop-Process -Force;
}

function GatherEventLogs {
	Param(
		[Parameter(Mandatory = $True)]
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

function InstallMicrosoftEdge {
	Param(
		[Parameter(Mandatory = $True)]
		[bool]$MsiInstaller,
		[Parameter(Mandatory = $True)]
		[string]$MicrosoftEdgeChromiumInstaller,
		[Parameter(Mandatory = $True)]
		[string]$PathToLogFile,
		[Parameter(Mandatory = $True)]
		[ref]$ExitCode
	)
	if ($MsiInstaller) {
		cmd /C msiexec.exe /i $MicrosoftEdgeChromiumInstaller /qn /log $pathToLogFile
	}
	else {
		cmd /C $MicrosoftEdgeChromiumInstaller /enterprise /silent /install
	}
	$ExitCode.Value = $LASTEXITCODE
}

$logsFolderPath = Join-Path -Path $PSScriptRoot -ChildPath 'Logs'
$pathToMicrosoftEdgeUpdateConfigFile = Join-Path -Path 'c:\' -ChildPath 'MicrosoftEdgeUpdate.ini'
try {
	Write-Output "Create logs folder '${logsFolderPath}'"
	New-Item -Path $logsFolderPath -ItemType Directory -Force
	@"
	[LoggingLevel]
	LC_CORE=5
	LC_NET=4
	LC_SERVICE=3
	LC_SETUP=3
	LC_SHELL=3
	LC_UTIL=3
	LC_OPT=3
	LC_REPORT=3
	
	[LoggingSettings]
	EnableLogging=1
	LogFilePath="${logsFolderPath}\MicrosoftEdgeUpdate_${EdgeChromiumChannel}.log"
	MaxLogFileSize=10000000
	ShowTime=1
	LogToFile=1
	AppendToFile=1
	LogToStdOut=0
	LogToOutputDebug=1
	
	[DebugSettings]
	SkipServerReport=1
	NoSendDumpToServer=1
	NoSendStackToServer=1
"@ | Out-File -FilePath $pathToMicrosoftEdgeUpdateConfigFile -Encoding utf8
	Write-Output "Install Microsoft edge chromium from '${EdgeChromiumChannel}' channel...";
	$ProgressPreference = 'SilentlyContinue';
	Invoke-WebRequest -Uri $linkToMicrosoftEdgeChromium -OutFile $microsoftEdgeChromiumInstaller -Verbose;
	StopAndKillMicrosoftChromiumUpdaterProcesses;
	[int]$exitCode = 0
	InstallMicrosoftEdge -MsiInstaller $MsiInstaller `
		-MicrosoftEdgeChromiumInstaller $microsoftEdgeChromiumInstaller `
		-PathToLogFile $pathToLogFile `
		-ExitCode ([ref]$exitCode)
	if ($exitCode -eq 0x80040902) {
		cmd /C tasklist /SVC /FO TABLE
		Write-Output "Repeat attempt to install MS edge because of error code '-2147219198'"
		Start-Sleep -Seconds 60
		InstallMicrosoftEdge -MsiInstaller $MsiInstaller `
			-MicrosoftEdgeChromiumInstaller $microsoftEdgeChromiumInstaller `
			-PathToLogFile $pathToLogFile `
			-ExitCode ([ref]$exitCode)
		cmd /C tasklist /SVC /FO TABLE
	}
	Write-Output "Microsoft edge chromium installer finished with exit code: '${exitCode}'";
	if ($exitCode -eq 0) {
		StopAndKillMicrosoftChromiumUpdaterProcesses;
	}
	exit $exitCode;
}
catch {
	Write-Output ($PSItem | Out-String);
	exit 1;
}
finally {
	if ((Test-Path -Path $pathToLogFile) -eq $true) {
		Copy-Item -Path $pathToLogFile -Destination $logsFolderPath;
	}
	GatherEventLogs -logsFolderPath $logsFolderPath
	Remove-Item $pathToMicrosoftEdgeUpdateConfigFile
}