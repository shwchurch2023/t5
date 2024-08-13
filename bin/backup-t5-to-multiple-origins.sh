#!/bin/bash

# env > ~/.env

export BASE_PATH=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

echo $BASE_PATH
source $BASE_PATH/bin/common-utils.sh
cd $BASE_PATH

echo -e "\033[0;32mDeploying updates to GitHub...\033[0m"

githubAccounts=("shwchurch3" "shwchurch3hugo")

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
export useSSHKey

pushRemote(){
	dir=$1
	repo=$2
	account=$3
	cd $dir
	useSSHKey $account
	git remote add $account git@github.com:$account/$repo.git
	git remote set-url $account git@github.com:$account/$repo.git
	git add .
	git commit -m "Backup"
	git pull $account main
	git push $account main --force
	cd -

}
export pushRemote

testMigratedPush(){
	testMigratedPush_path=${1:-""}
	testMigratedPush_repo=${1:-"t5"}

	cd $BASE_PATH

	if [[ ! -z "${testMigratedPush_path}" ]];then
		cd $testMigratedPush_path
	fi

	date >> aws-upgraded.log
	git add aws-upgraded.log
	git commit -m "AWS upgraded" 
	pushRemote $BASE_PATH/${testMigratedPush_path} ${testMigratedPush_repo} $account

}
export testMigratedPush

for account in ${githubAccounts[@]}; do
	pushRemote $BASE_PATH t5 $account
	pushRemote $BASE_PATH/themes/hugo-theme-shwchurch hugo-theme-shwchurch $account
done

useSSHKey shwchurch3

