#!/bin/bash

set -o xtrace

export BASE_PATH=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && cd .. && pwd )

source $BASE_PATH/bin/common-utils.sh

useSSHKey $deployGitUsername

currentUser=$(whoami)
if [[ "$currentUser" != "hugo" ]]; then
	echo "[ERROR] You mush run this script with \"sudo -u hugo $(realpath $0)\""
	exit 1

fi
