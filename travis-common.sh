#!/bin/bash
# -*- sh-basic-offset: 4; sh-indentation: 4 -*-
# Bootstrap Travis environment.

set -e
# Comment out this line for quieter output:
set -x

OS=$(uname -s)
PATH="${PATH}"

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
    Retry sudo apt-get install -y "$@"
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
    Retry sudo apt-get update -qqy

    AptGetInstall git facter

    # Process options
    #BootstrapLinuxOptions
}

InstallAWSCLI() {
  if [[ ! -f /usr/local/bin/aws ]]; then
    echo "Installing AWS CLI tools..."
    curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip"
    unzip -o awscli-bundle.zip
    ./awscli-bundle/install -i $HOME/bin/aws
    rm -rf awscli-bundle awscli-bundle.zip
    aws
  fi
}

InstallLeiningen() {
  if [[ ! -f /usr/local/bin/lein ]]; then
    echo "Installing Leiningen..."
    curl "https://raw.githubusercontent.com/technomancy/leiningen/stable/bin/lein" -o "$HOME/bin/lein"
    chmod a+x $HOME/bin/lein
    lein
  fi
}

BootstrapLinuxOptions() {
    ## Insert Linux installation options if necessary
    echo "Configuring additional Linux Options"
}

InstallDeps() {
    InstallAWSCLI
    InstallLeiningen
}

BootstrapMac() {
    ## Insert Mac dependencies if necessary
    
    BootstrapMacOptions
}

BootstrapMacOptions() {
    ## Insert Mac installation options if necessary
    echo "Configuring additional Mac Options"
}

DumpSysinfo() {
    echo "Dumping system information."
    echo "Path is: $PATH"
    echo "User is: $USER"
    echo "PWD is: `pwd`"
    mkdir -p logs
    facter > logs/facter.out
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

Exists() {
    echo "Testing install of ${1}..."
    command -v $1 >/dev/null 2>&1 && echo "$1 installed correctly!"
}

DumpLogs() {
    echo "Dumping test execution logs."
    DumpSysinfo
    DumpLogsByExtension "out"
    DumpLogsByExtension "log"
    DumpLogsByExtension "fail"
}

RunTests() {
    echo "Running tests"
    Exists aws
    Exists lein
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
    ## Install dependencies
    "install_deps")
        InstallDeps
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
    ## Run the actual tests
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
