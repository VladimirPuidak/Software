#!/bin/sh -euxo pipefail

googleChromeChannel="${1:-stable}"
majorVersion="${2:-}"
minorVersion="${3:-}"
linkTo3rdPartyTools="${4:-https://artifacts.aras.com/artifactory/ENG-3rdPartyTools/}"
googleChromeChannelLowerCase="$(tr '[:upper:]' '[:lower:]' <<<${googleChromeChannel})"
linkAddressToGoogleChrome="https://dl.google.com/chrome/mac/${googleChromeChannelLowerCase}/googlechrome.dmg"
if [[ $googleChromeChannelLowerCase == 'stable' ]]; then
    linkAddressToGoogleChrome='https://dl.google.com/chrome/mac/stable/GGRO/googlechrome.dmg'
fi
if [[ ! -z $majorVersion && ! -z $minorVersion ]]; then
    linkAddressToGoogleChrome="${linkTo3rdPartyTools}Browsers/Chrome/${majorVersion}/${minorVersion}/googlechrome.dmg"
fi
appBundleSuffix="$(sed 's/stable//g' <<<${googleChromeChannelLowerCase})"
appBundleSuffix="$(tr '[:lower:]' '[:upper:]' <<<${appBundleSuffix:0:1})${appBundleSuffix:1}"

pathToGoogleChromeInstaller='/tmp/GoogleChrome.dmg'
pathToGoogleChromeMountPoint='/Volumes/Google Chrome'

cleanup() {
    returnValue=$?
    if [[ -f $pathToGoogleChromeInstaller ]]; then
        rm "${pathToGoogleChromeInstaller}"
    fi
    if [[ -d $pathToGoogleChromeMountPoint ]]; then
        hdiutil detach "${pathToGoogleChromeMountPoint}"
    fi
    exit $returnValue
}

trap "cleanup" EXIT

curl -vLo $pathToGoogleChromeInstaller $linkAddressToGoogleChrome
hdiutil attach "${pathToGoogleChromeInstaller}"
#This installs google chrome as Chrome${appBundleSuffix}.app which is not the default name
#The default is "Google Chrome.app"
googleChromeDeployPath="/Applications/Chrome${appBundleSuffix}.app"
if [[ -d $googleChromeDeployPath ]]; then
    rm -r "${googleChromeDeployPath}"
fi
pathToGoogleChromeWebDataFile="${HOME}/Library/Application Support/Google/Chrome/Default/Web Data"
if [[ $googleChromeChannelLowerCase == 'stable' && -f $pathToGoogleChromeWebDataFile ]]; then
    rm "${pathToGoogleChromeWebDataFile}"
fi
ditto -rsrc "${pathToGoogleChromeMountPoint}/Google Chrome.app" "${googleChromeDeployPath}"
chmod -R +x "${googleChromeDeployPath}"
