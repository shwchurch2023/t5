#!/bin/bash

set -o xtrace

export deployGitUsername=shwchurch3
export publicGitUsername=shwchurch7

export uploadsGitUsername1=shwchurch4
export uploadsGitUsername2=shwchurch2020

export publicFolder=${publicGitUsername}.github.io

git config --global core.quotePath false

hugoBuild() {
	cd $BASE_PATH

	/mnt/hugo/hugo --minify # if using a theme, replace with `hugo -t <YOURTHEME>`
	if [[ "$?" != "0" ]]; then
		echo "[ERROR] /usr/local/bin/hugo failed"
		exit 1
	fi
}
export -f hugoBuild

gitSetUser(){
	git config user.email "shwchurch3@gmail.com"
	git config user.name "Shouwang Church"
}

export -f gitSetUser

rmSafe() {
	dir=$1
	expectPathPart=$2
	getRealPath=$(realpath $dir)
	echo "[INFO] rmSafe $getRealPath"
	if [[ ! -z "$dir" && "$getRealPath" =~ "$expectPathPart" ]]; then
		realpath $dir | xargs rm -rf
	else
		echo "[ERROR][rmSafe] $dir is a dangerous path that couldn't be rm -rf "
		exit 1
	fi
}
export -f rmSafe


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
        git config core.sshCommand "ssh -i $key -o StrictHostKeyChecking=no -F /dev/null"
        #export GIT_SSH_COMMAND="ssh -i $key -o IdentitiesOnly=yes"

}

export -f useSSHKey

killLongRunningGit(){
	ps aux | egrep "\sgit\s" | awk '{print $2}' | xargs kill
}
export -f killLongRunningGit 

updateRepo(){
	dir=$1
	echo "Update repo in $dir"
	cd $dir
	gitSetUser
	git add .
	git commit -m "Add current changes"
	git pull --no-edit
	git push
	echo "Try to update parent repo if any"
	cd ..
	gitSetUser
	git add .
	git commit -m "Child repo changed"
	git pull --no-edit
	git push
}
export -f updateRepo

addSubmodule(){
	githubUserName=$1
	repoName=$2
	
	submoduleUrl=git@github.com:${githubUserName}/${repoName}.git

	cd $BASE_PATH
	pwd
	useSSHKey $githubUserName
	git submodule add -f $submoduleUrl
	cd $repoName
	git checkout -b new_tmp
	git checkout new_tmp
	git branch -D main
	git checkout -b main origin/main
	git branch -D new_tmp
	cd $BASE_PATH
	useSSHKey $deployGitUsername
	git add .
	git commit -m "added submodule $submoduleUrl"
	cat .gitmodules
	git pull origin main
	git push origin main 

}
export -f addSubmodule

waitGitComplete(){
	while [[ !  -z "$(ps aux |  grep git | grep -v sync | grep -v grep | grep -v github)"  ]];do
		echo "$(date): Git is running"
		sleep 10	
	done
}
export -f waitGitComplete


gitCommitByBulk(){
	#waitGitComplete
        dir=$1
	gitUsername=$2
	msg=$3
        bulkSize=$4

	if [[ -z "$gitUsername" ]];then
		"[ERROR]{gitCommitByBulk} Must offer gitUsername"
		return
	fi

	if [[ -z "$bulkSize" ]]; then
		bulkSize=200
	fi

	gitSetUser

	echo "[INFO][gitCommitByBulk] Process $dir"
	pwd
	countLines=$(git ls-files -dmo ${dir} | head -n ${bulkSize} | wc -l)
	echo "[INFO] Start git push at dir $dir at bulk $bulkSize"
	git ls-files -dmo ${dir} | head -n ${bulkSize}
	#rm -rf .git/index.lock
	#rm -rf .git/index
	while [[ "${countLines}" != "0"  ]]
	do
		#waitGitComplete
		git ls-files -dmo "${dir}" | head -n ${bulkSize} | xargs -t -I {} echo -e '{}' | xargs -I{} git add "{}"
		finaMsg="[Bulk] ${msg} - Added ${dir}@${countLines} files"
		echo "$finaMsg"
		useSSHKey $gitUsername
		git commit -m "$finaMsg"
		useSSHKey $gitUsername
		git push --set-upstream origin main  --force
		countLines=$(git ls-files -dmo "${dir}" | head -n ${bulkSize} | wc -l)
	done
	git add "${dir}"
	useSSHKey $gitUsername
	git commit -m "[INFO] last capture all of dir $dir, ${msg}"
	useSSHKey $gitUsername
	git push --set-upstream origin main --force
}
export -f gitCommitByBulk

waitGitComplete(){
	while [[ !  -z "$(ps aux |  grep git | grep -v sync | grep -v grep | grep -v github)"  ]];do
		echo "$(date): Git is running"
		sleep 10	
	done
}

export -f waitGitComplete

rangeGitAddPush(){
	pathPrefix=$1
	start=$2
	end=$3
	gitUsername=$4

	for i in $(seq $start $end)
	do
		gitCommitByBulk "$pathPrefix/${i}" $gitUsername
		gitCommitByBulk "$pathPrefix/${i}*" $gitUsername
	done
}
export -f rangeGitAddPush


export $(cat /mnt/hugo/.env | sed 's/#.*//g' | xargs)

export SHELL=/bin/bash
export PATH=/usr/local/openssl/bin:/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:/opt/aws/bin:$PATH

useSSHKey $deployGitUsername

currentUser=$(whoami)
if [[ "$currentUser" != "hugo" ]]; then
	echo "[ERROR] You mush run this script with \"sudo -u hugo $(realpath $0)\""
	exit 1

fi
