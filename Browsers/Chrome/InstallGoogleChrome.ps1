param(
	[Parameter(Mandatory = $False)]
	[ValidateNotNull()]
	[string]$Edition = 'stable',
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

$ChromeInstaller = "${PSScriptRoot}\ChromeInstaller.exe"
[int]$OSBitness = (Get-WMIObject Win32_Processor).AddressWidth[0];
if ($OSBitness -eq 32) {
	$linkToGoogleChrome = 'https://dl.google.com/tag/s/appguid%3D%7B8A69D345-D564-463C-AFF1-A69D9E530F96%7D%26iid%3D%7BEE50A47A-4D91-EBC1-A2B8-CCB727FD6702%7D%26lang%3Den%26browser%3D3%26usagestats%3D0%26appname%3DGoogle%2520Chrome%26needsadmin%3Dprefers%26ap%3Dstable-arch_x86-statsdef_1%26installdataindex%3Dempty/chrome/install/ChromeStandaloneSetup.exe'
}
else {
	$linkToGoogleChrome = 'https://dl.google.com/tag/s/appguid%3D%7B8A69D345-D564-463C-AFF1-A69D9E530F96%7D%26iid%3D%7BF9A07A37-07AE-3B11-0FCC-FC4CCB455B7A%7D%26lang%3Den%26browser%3D4%26usagestats%3D0%26appname%3DGoogle%2520Chrome%26needsadmin%3Dprefers%26ap%3Dx64-stable-statsdef_1%26installdataindex%3Ddefaultbrowser/chrome/install/ChromeStandaloneSetup64.exe'
}
if ($Edition -eq 'beta') {
	if ($OSBitness -eq 32) {
		$linkToGoogleChrome = 'https://dl.google.com/tag/s/appguid%3D%7B8237E44A-0054-442C-B6B6-EA0509993955%7D%26iid%3D%7B8F94C426-F48E-944F-58B4-56AC548C0A6F%7D%26lang%3Den%26browser%3D4%26usagestats%3D0%26appname%3DChrome%2520Beta%26needsadmin%3Dtrue%26ap%3D-arch_x86-statsdef_1%26installdataindex%3Dempty/chrome/install/beta/ChromeBetaStandaloneSetup.exe'
	}
	else {
		$linkToGoogleChrome = 'https://dl.google.com/tag/s/appguid%3D%7B8237E44A-0054-442C-B6B6-EA0509993955%7D%26iid%3D%7B389821F6-53D2-EE13-5871-793EFDEC6CC5%7D%26lang%3Den%26browser%3D4%26usagestats%3D0%26appname%3DGoogle%2520Chrome%2520Beta%26needsadmin%3Dprefers%26ap%3D-arch_x64-statsdef_1%26installdataindex%3Dempty/chrome/install/beta/ChromeBetaStandaloneSetup64.exe'
	}
}
if ($Edition -eq 'dev') {
	if ($OSBitness -eq 32) {
		$linkToGoogleChrome = 'https://dl.google.com/tag/s/appguid%3D%7B401C381F-E0DE-4B85-8BD8-3F3F14FBDA57%7D%26iid%3D%7B3C078BAD-5ACB-D945-6C84-7F778A6383F1%7D%26lang%3Den%26browser%3D4%26usagestats%3D0%26appname%3DGoogle%2520Chrome%2520Dev%26needsadmin%3Dtrue%26ap%3D-arch_x86-statsdef_1%26installdataindex%3Dempty/chrome/install/dev/ChromeDevStandaloneSetup.exe'
	}
	else {
		$linkToGoogleChrome = 'https://dl.google.com/tag/s/appguid%3D%7B401C381F-E0DE-4B85-8BD8-3F3F14FBDA57%7D%26iid%3D%7B3C078BAD-5ACB-D945-6C84-7F778A6383F1%7D%26lang%3Den%26browser%3D4%26usagestats%3D0%26appname%3DGoogle%2520Chrome%2520Dev%26needsadmin%3Dtrue%26ap%3D-arch_x64-statsdef_1%26installdataindex%3Dempty/chrome/install/dev/ChromeDevStandaloneSetup64.exe'
	}
}
if ($Edition -eq 'canary') {
	if ($OSBitness -eq 32) {
		$linkToGoogleChrome = 'https://dl.google.com/tag/s/appguid%3D%7B4ea16ac7-fd5a-47c3-875b-dbf4a2008c20%7D%26iid%3D%7B0281A7E2-6043-D983-8BBA-7FD622493C9D%7D%26lang%3Den%26browser%3D4%26usagestats%3D1%26appname%3DGoogle%2520Chrome%2520Canary%26needsadmin%3Dfalse/update2/installers/ChromeStandaloneSetup.exe'
	}
	else {
		$linkToGoogleChrome = 'https://dl.google.com/tag/s/appguid%3D%7B4EA16AC7-FD5A-47C3-875B-DBF4A2008C20%7D%26iid%3D%7B930C9E9E-6131-19D5-6D03-EEE4BD9BF2EC%7D%26lang%3Den%26browser%3D4%26usagestats%3D1%26appname%3DGoogle%2520Chrome%2520Canary%26needsadmin%3Dfalse%26ap%3Dx64-canary-statsdef_1%26installdataindex%3Dempty/update2/installers/ChromeStandaloneSetup64.exe'
	}
}
if ($MajorVersion.Length -ne 0 -and $MinorVersion.Length -ne 0) {
	$linkToGoogleChrome = "$($LinkTo3rdPartyTools.AbsoluteUri)Browsers/Chrome/${MajorVersion}/${MinorVersion}/ChromeStandaloneSetup.exe"
}

function StopAndKillGoogleUpdaterProcesses {
	schtasks /query /v /fo CSV | 
	ForEach-Object { $PSItem.split(",") | Where-Object { $PSItem -like "*GoogleUpdateTaskMachine*" } } | 
	ForEach-Object { schtasks /change /disable /tn $PSItem };
	Get-Service -Name 'gupdate*' | Set-Service -StartupType Disabled;
	Get-Service -Name 'gupdate*' | Stop-Service;
	Get-Service -Name 'GoogleChrome*' | Set-Service -StartupType Disabled;
	Get-Service -Name 'GoogleChrome*' | Stop-Service;
	Get-Process -Name 'elevation_service*' | Stop-Process -Force;
	Get-Process -Name 'chrome*' | Stop-Process -Force;
	Get-Process -Name 'google*' | Stop-Process -Force;
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

$logsFolderPath = Join-Path -Path $PSScriptRoot -ChildPath 'Logs'
$pathToGoogleUpdateConfig = Join-Path -Path 'c:\' -ChildPath 'GoogleUpdate.ini'
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
LogFilePath="${logsFolderPath}\GoogleUpdate_${Edition}.log"
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
"@ | Out-File -FilePath $pathToGoogleUpdateConfig -Encoding utf8
	Write-Output "Install Google chrome '${Edition}' edition...";
	$ProgressPreference = 'SilentlyContinue';
	Invoke-WebRequest -Uri $linkToGoogleChrome -OutFile $ChromeInstaller -Verbose;
	StopAndKillGoogleUpdaterProcesses;
	cmd /C $ChromeInstaller /enterprise /silent /install;
	$exitCode = $LASTEXITCODE;
	Write-Output "Chrome installer finished with exit code: '${exitCode}'";
	if ($exitCode -eq 0) {
		StopAndKillGoogleUpdaterProcesses;
	}
	exit $exitCode;
}
catch {
	$_;
	exit 1;
}
finally {
	[string]$pathToLogFile = Join-Path -Path $env:temp -ChildPath 'chrome_installer.log';
	if ((Test-Path -Path $pathToLogFile) -eq $true) {
		Copy-Item -Path $pathToLogFile -Destination $logsFolderPath;
	}
	GatherEventLogs -logsFolderPath $logsFolderPath
	Remove-Item $pathToGoogleUpdateConfig
}