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
	pushRemote_return_code=0
	(
	dir=$1
	repo=$2
	account=$3
	cd $dir
	useSSHKey $account
	git remote add $account git@github.com:$account/$repo.git
	git remote set-url $account git@github.com:$account/$repo.git
	git add .
	git commit -m "Backup"
	git config pull.rebase false
	git pull $account main --no-edit
	git push $account main --force
	pushRemote_return_code=$?
	)
	return $pushRemote_return_code

}
export pushRemote

testMigratedPush(){
	testMigratedPush_path=${1:-"$BASE_PATH"}
	testMigratedPush_repo=${2:-"t5"}


	if [[ ! -z "${testMigratedPush_path}" ]];then
		cd $testMigratedPush_path
	fi

	date >> aws-upgraded.log
	git add aws-upgraded.log
	git commit -m "AWS upgraded" 

	for account in ${githubAccounts[@]}; do
		pushRemote $BASE_PATH/${testMigratedPush_path} ${testMigratedPush_repo} $account
		if [[ "$?" = 0 ]];then
			break;
		fi
	done

}
export testMigratedPush

pushRemote $BASE_PATH t5 shwchurch3
pushRemote $BASE_PATH/themes/hugo-theme-shwchurch hugo-theme-shwchurch shwchurch3hugo


useSSHKey shwchurch3

