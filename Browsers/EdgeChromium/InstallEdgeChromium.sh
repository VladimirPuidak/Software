#!/bin/sh -euxo pipefail

edgeChromiumChannel=$1
sudoPassword=$2
majorVersion="${3:-}"
minorVersion="${4:-}"
linkTo3rdPartyTools="${5:-https://artifacts.aras.com/artifactory/ENG-3rdPartyTools/}"

pathToMicrosoftEdgeChromiumInstaller='/tmp/MicrosoftEdgeChromium.pkg'
linkAddressToMicrosoftEdgeChromium='https://go.microsoft.com/fwlink/?linkid=2069148&platform=Mac&Consent=1&channel=Stable'
if [ $edgeChromiumChannel == "dev" ]; then
    linkAddressToMicrosoftEdgeChromium='https://go.microsoft.com/fwlink/?linkid=2069340&platform=Mac&Consent=1&channel=Dev'
elif [[ $edgeChromiumChannel == "beta" ]]; then
    linkAddressToMicrosoftEdgeChromium='https://go.microsoft.com/fwlink/?linkid=2069439&platform=Mac&Consent=1&channel=Beta'
fi
if [[ ! -z $majorVersion && ! -z $minorVersion ]]; then
    linkAddressToMicrosoftEdgeChromium="${linkTo3rdPartyTools}Browsers/MicrosoftEdgeChromium/${majorVersion}/${minorVersion}/MicrosoftEdgeChromium.pkg"
fi

cleanup() {
    returnValue=$?
    if [[ -f $pathToMicrosoftEdgeChromiumInstaller ]]; then
        rm "${pathToMicrosoftEdgeChromiumInstaller}"
    fi
    exit $returnValue
}

trap "cleanup" EXIT

curl -vLo "${pathToMicrosoftEdgeChromiumInstaller}" $linkAddressToMicrosoftEdgeChromium
echo $sudoPassword | sudo -S installer -pkg  "${pathToMicrosoftEdgeChromiumInstaller}" -dumplog -target /
