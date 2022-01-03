#!/bin/bash

set -o xtrace

useSSHKey(){
        username=$1
        key=/mnt/hugo/ssh/id_ed25519_$username
	
        chmod 600 $key
        chmod 644 $key.pub
        eval `ssh-agent -s`
        ssh-add -D $key
        ssh-add $key
        ssh-add -l
        #git config --global core.sshCommand "ssh -i $key -F /dev/null"
        git config core.sshCommand "ssh -i $key -F /dev/null"
        #export GIT_SSH_COMMAND="ssh -i $key -o IdentitiesOnly=yes"

}

export -f useSSHKey

export $(cat /home/ec2-user/.env | sed 's/#.*//g' | xargs)

export SHELL=/bin/bash
export PATH=/home/ec2-user/.nvm/versions/node/v11.13.0/bin:/usr/local/openssl/bin:/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:/opt/aws/bin:/home/ec2-user/bin:$PATH

currentUser=$(whoami)
if [[ "$currentUser" != "hugo" ]]; then
	echo "[ERROR] You mush run this script with \"sudo -u hugo $(realpath $0)\""
	exit 1

fi
