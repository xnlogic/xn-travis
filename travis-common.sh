#!/bin/bash
# -*- sh-basic-offset: 4; sh-indentation: 4 -*-
# Bootstrap an Travis environment.

set -e
# Comment out this line for quieter output:
set -x

OS=$(uname -s)
PATH="${PATH}"

Bootstrap() {
    if [[ "Darwin" == "${OS}" ]]; then
        BootstrapMac
    elif [[ "Linux" == "${OS}" ]]; then
        BootstrapLinux
    else
        echo "Unknown OS: ${OS}"
        exit 1
    fi
}

BootstrapLinux() {
    ## Insert Linux dependencies if necessary
    Retry sudo apt-get update -qq

    Retry sudo apt-get install --no-install-recommends git facter

    InstallAWSCLI
    InstallLeiningen

    # Process options
    BootstrapLinuxOptions
}

InstallAWSCLI() {
  if [[ ! -f /usr/local/bin/aws ]]; then
    echo "Installing AWS CLI tools..."
    curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip"
    unzip -o awscli-bundle.zip
    sudo ./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws
    rm -rf awscli-bundle awscli-bundle.zip
  fi
}

InstallLeiningen() {
  if [[ ! -f /usr/local/bin/lein ]]; then
  echo "Installing Leiningen..."
  sudo wget -O /usr/local/bin/lein https://raw.githubusercontent.com/technomancy/leiningen/stable/bin/lein
  sudo chmod a+x /usr/local/bin/lein
  fi
}

BootstrapLinuxOptions() {
    ## Insert Linux installation options if necessary
}

BootstrapMac() {
    ## Insert Mac dependencies if necessary
    
    BootstrapMacOptions
}

BootstrapMacOptions() {
    ## Insert Mac installation options if necessary
}

AptGetInstall() {
    if [[ "Linux" != "${OS}" ]]; then
        echo "Wrong OS: ${OS}"
        exit 1
    fi

    if [[ "" == "$*" ]]; then
        echo "No arguments to aptget_install"
        exit 1
    fi

    echo "Installing apt package(s) $@"
    Retry sudo apt-get install "$@"
}

DpkgCurlInstall() {
    if [[ "Linux" != "${OS}" ]]; then
        echo "Wrong OS: ${OS}"
        exit 1
    fi

    if [[ "" == "$*" ]]; then
        echo "No arguments to dpkgcurl_install"
        exit 1
    fi

    echo "Installing remote package(s) $@"
    for rf in "$@"; do
        curl -OL ${rf}
        f=$(basename ${rf})
        sudo dpkg -i ${f}
        rm -v ${f}
    done
}

DumpSysinfo() {
    echo "Dumping system information."
    facter
}

DumpLogsByExtension() {
    if [[ -z "$1" ]]; then
        echo "dump_logs_by_extension requires exactly one argument, got: $@"
        exit 1
    fi
    extension=$1
    shift
    package=$(find . -maxdepth 1 -name "logs" -type d)
    if [[ ${#package[@]} -ne 1 ]]; then
        echo "Could not find logs directory, skipping log dump."
        exit 0
    fi
    for name in $(find "${package}" -type f -name "*${extension}"); do
        echo ">>> Filename: ${name} <<<"
        cat ${name}
    done
}

DumpLogs() {
    echo "Dumping test execution logs."
    DumpLogsByExtension "out"
    DumpLogsByExtension "log"
    DumpLogsByExtension "fail"
}

RunTests() {
    echo "Running tests"
}

Retry() {
    if "$@"; then
        return 0
    fi
    for wait_time in 5 20 30 60; do
        echo "Command failed, retrying in ${wait_time} ..."
        sleep ${wait_time}
        if "$@"; then
            return 0
        fi
    done
    echo "Failed all retries!"
    exit 1
}

COMMAND=$1
echo "Running command: ${COMMAND}"
shift
case $COMMAND in
    ##
    ## Bootstrap a new core system
    "bootstrap")
        Bootstrap
        ;;
    ##
    ## Install a binary deb package via apt-get
    "install_aptget"|"aptget_install")
        AptGetInstall "$@"
        ;;
    ##
    ## Install a binary deb package via a curl call and local dpkg -i
    "install_dpkgcurl"|"dpkgcurl_install")
        DpkgCurlInstall "$@"
        ;;
    ##
    ## Run the actual tests, ie R CMD check
    "run_tests")
        RunTests
        ;;
    ##
    ## Dump information about installed packages
    "dump_sysinfo")
        DumpSysinfo
        ;;
    ##
    ## Dump build or check logs
    "dump_logs")
        DumpLogs
        ;;
    ##
    ## Dump selected build or check logs
    "dump_logs_by_extension")
        DumpLogsByExtension "$@"
        ;;
esac
