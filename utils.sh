#!/#!/bin/bash

function onlyAllowRoot() {
    if [[ "$EUID" = 0 ]]; then
        echo "[INFO] Access by Root"
    else
        sudo -k # make sure to ask for password on next sudo
        if sudo true; then
            echo "[INFO] Access Granted"
        else
            echo "[ERROR] Access Denied.!"
            exit 0
        fi
    fi
}

function directoryCheck {
    if [ -d "$1" ]; then
        echo "[ERROR] Directory $1 exists"
    else
        echo "[INFO] Directory $1 does not exist"
        echo "[INFO] Creating Directory $1"
        mkdir -p $1
    fi
}

function groupSystemExist {
    if [ grep -q "^$1:" /etc/group ]; then
        echo "[ERROR] Group $1 exists"
    else
        echo "[INFO] Group $1 does not exist"
        echo "[INFO] Creating Group $1"
        sudo groupadd --system $1
    fi
}

function userSystemExists {
    if [ grep -q "^$1:" /etc/passwd ]; then
        echo "[INFO] User $1 exists"
    else
        echo "[INFO] User $1 does not exist"
        echo "[INFO] Creating User $1"

        ## Check if Using Group
        if [ -z "$2" ]; then
            echo "[INFO] Group is not specified. Using default group 'users'"
            sudo useradd -s /sbin/nologin --system $1
        else
            echo "[INFO] Group is specified. Using group $2"
            sudo useradd -s /sbin/nologin --system -g $2 $1
        fi
    fi
}

function githubDownload {
    ## Check if Variable isnot empty
    if [[ -z "$1" || -z "$2" || -z "$3" ]] then
        echo "[ERROR] Variable is empty. Example: githubDownload prometheus/prometheus latest linux-amd64"
        exit 0
    fi

    echo "[INFO] Check Repo $1 [$2] version $3"

    ## Curl Check if Repo Valid
    REPO_CHECK=$( curl -s https://api.github.com/repos/$1/releases/$2 )
    if [ -z "$REPO_CHECK" ]; then
        echo "[ERROR] Repo $1 [$2] version $3 is not valid"
        exit 0
    fi

    ## Check if browser_download_url is valid
    if [ -z "$(echo $REPO_CHECK | grep browser_download_url)" ]; then
        echo "[ERROR] Repo $1 [$2] version $3 is not valid"
        exit 0
    fi

    ## Check if version is valid
    if [ -z "$(echo $REPO_CHECK | grep browser_download_url | grep $3)" ]; then
        echo "[ERROR] Repo $1 [$2] version $3 is not valid"
        exit 0
    fi

    ## Download File
    echo "[INFO] Downloading $1 [$2] version $3"
    curl -s $(echo $REPO_CHECK | grep browser_download_url | grep $3 | cut -d '"' -f 4) | wget -qi -
}