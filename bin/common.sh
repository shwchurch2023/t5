#!/bin/bash

set -o xtrace

export deployGitUsername=shwchurch3
export publicGitUsername=shwchurch7
# export publicGitUsername=shwchurch3

export uploadsGitUsername1=shwchurch4
export uploadsGitUsername2=shwchurch2020

export publicFolder=${publicGitUsername}.github.io
export publicFolderAbs=$BASE_PATH/$publicFolder

export hugoPublicFolderAbs=$BASE_PATH/public

export uploadsGitUsername1FolderAbs=$BASE_PATH/$uploadsGitUsername1.github.io
export uploadsGitUsername2FolderAbs=$BASE_PATH/$uploadsGitUsername2.github.io

export themeFolder=$BASE_PATH/themes/hugo-theme-shwchurch

export filePathUrlMappingFilePath=$BASE_PATH/pathDistributionMapping.txt
export filePathUrlMappingFilePathManual=$BASE_PATH/pathDistributionMappingManual.txt

export mirrorPublicGithubTokenList=$BASE_PATH/mirror-public-github-token__gitignore.txt

separator=________

git config --global core.quotePath false

updateAllSubmodules(){
	git submodule update --init --recursive
}

ensureRequiredFolder() {
	if [[ ! -d "$1" ]];then
		echo "[ERROR] path $1 must be present"
		exit 2
	fi
}

ensureNoErrorOnChildProcess() {
	if [[ "$1" != "0" ]];then
		echo "[ERROR] Child process returns error code $1"
		exit 3
	fi
}
export -f ensureNoErrorOnChildProcess

export -f ensureRequiredFolder

ensureRequiredFolders() {
	updateAllSubmodules
	cd $themeFolder
	git checkout -b main origin/main
	ensureRequiredFolder $themeFolder
	cd $BASH_PATH
}
export -f ensureRequiredFolders

hugoBuild() {
	cd $BASE_PATH

	/mnt/hugo/hugo --minify # if using a theme, replace with `hugo -t <YOURTHEME>`
	if [[ "$?" != "0" ]]; then
		echo "[WARN] /mnt/hugo/hugo failed"
	fi
}
export -f hugoBuild

syncPodcast(){
	cd $BASE_PATH
	./bin/sync-podcast.sh 
}
export -f syncPodcast

gitSetUser(){
	git config user.email "shwchurch3@gmail.com"
	git config user.name "Shouwang Church"
}

export -f gitSetUser

rmSafe() {
	dir=$1
	expectPathPart=$2
	onlyWarning=$3
	getRealPath=$(realpath $dir)
	echo "[INFO] rmSafe $getRealPath"
	if [[ ! -z "$dir" && "$getRealPath" =~ "$expectPathPart" ]]; then
		realpath $dir | xargs rm -rf
	else
		echo "[ERROR][rmSafe] $dir is a dangerous path that couldn't be rm -rf "
		if [[ -z "$onlyWarning" ]]; then
			exit 1
		fi
	fi
}
export -f rmSafe

addNewGithubAccountAsMirror(){
        username=$1
        token=$2

		touch $mirrorPublicGithubTokenList
		echo "${username} ${token}" >> $mirrorPublicGithubTokenList

		echo "Call [[ syncForkInMirrorGithubAccounts ]] since you may have forked this repo"

		syncForkInMirrorGithubAccounts
}

export addNewGithubAccountAsMirror

syncForkInMirrorGithubAccounts(){
	echo "[$0] Syncking all forked github actions added via [[ addNewGithubAccountAsMirror GITHUB_USERNAME GITHUB_TOKEN ]]"

	file=$mirrorPublicGithubTokenList

	cd $BASH_PATH
	while IFS= read line
	do
		if [[ ! -z "$line" ]];then
			echo "$line"
			credentials=($line)
			username=${credentials[1]}
			token=${credentials[2]}

			if [[ -z "${username}" ||  -z "${token}" ]];then
				echo "[Error] Either username ${username} or token ${token} is empty. Skipped"
				continue
			fi
			repo=${username}.github.io
			branch=main

			echo "Synking forked repo [[$repo]]"

			curl \
				-X POST \
				-H "Accept: application/vnd.github.v3+json" \
				-H "Authorization: token ${token}" \
				https://api.github.com/repos/${username}/${repo}/merge-upstream \
				-d '{"branch":"${branch}"}'

		fi
			# display $line or do something with $line
	done <"$file"
}

export syncForkInMirrorGithubAccounts


addSSHKey(){

    username=$1

    key=id_ed25519_$username

    cd /mnt/hugo/ssh/

    if [[ -f "${key}" ]];then
        echo "${key} already exists"
        return 1
    fi

    ssh-keygen -t ed25519 -f "${key}" -C "shwchurch3@gmail.com"

    pub_key=${key}.pub

    echo "Add the generated SSH pub key to https://github.com/settings/ssh/new"
    pwd
    ls -la
    echo ""
    cat ${pub_key}
}

export addSSHKey

useSSHKey(){
		pkill ssh-agent
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
	# git branch -m master main
	git fetch origin
	git branch -u origin/main main
	git remote set-head origin -a
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
	isExitOnUnpresentPath=$3

	if [[ ! -z "$isExitOnUnpresentPath" && ! -f "$dir" && ! -d  "$dir" ]];then
		echo "[ERROR][gitCommitByBulk] dir $dir must be present"
		exit 1
	fi


	if [[ -z "$gitUsername" ]];then
		"[ERROR]{gitCommitByBulk} Must offer gitUsername"
		return
	fi

	if [[ -z "$bulkSize" ]]; then
		bulkSize=400
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

applyDistributionMapping(){
	applyPathMapping "$filePathUrlMappingFilePath"
}
export -f applyDistributionMapping

applyPathMapping(){
	file=${0}

	cd $BASH_PATH
	while IFS= read line
	do
		if [[ ! -z "$line" ]];then
			echo "$line"
			find . -type f -name "*.html" -exec sed -i  "$line" {} \; 
		fi
			# display $line or do something with $line
	done <"$file"
}


applyManualDistributionMapping(){
	applyPathMapping "$filePathUrlMappingFilePathManual"
}
export -f applyManualDistributionMapping

commitEssential(){
	END=$1
	MONTH=$2
	cd $publicFolderAbs
	gitCommitByBulk "${END}/${MONTH}" $publicGitUsername
	gitCommitByBulk "wp-content/uploads/${END}/${MONTH}" $publicGitUsername
	gitCommitByBulk "index.html" $publicGitUsername "true"
	gitCommitByBulk "404.html" $publicGitUsername "true"
	gitCommitByBulk "feed.xml" $publicGitUsername
	gitCommitByBulk "js" $publicGitUsername
	gitCommitByBulk "images" $publicGitUsername
	gitCommitByBulk "scss" $publicGitUsername
}
export -f commitEssential

reduceCompilationSize(){
	cd $publicFolderAbs
	useSSHKey $publicGitUsername

	echo "[INFO] Reduce files that may alter every compilation"
	find . -type f -name "*.html" -exec sed -i  "s/id=gallery-[[:digit:]]\+/id=gallery-replaced/g" {} \;
	find . -type f -name "*.html" -exec sed -i  "s/galleryid-[[:digit:]]\+/galleryid-replaced/g" {} \;
	find . -type f -name "*.html" -exec sed -i  "s#https\?:/wp-content#/wp-content#g" {} \;
	find . -type f -name "*.html" -exec sed -i  "s#title=[a-z0-9-]{1,}#title=____#g" {} \;
	find . -type f -name "*.html" -exec sed -i  "s#alt=[a-z0-9-]{1,}#alt=____#g" {} \;

}
export -f reduceCompilationSize

export $(cat /mnt/hugo/.env | sed 's/#.*//g' | xargs)

export SHELL=/bin/bash
export PATH=/usr/local/openssl/bin:/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:/opt/aws/bin:$PATH

useSSHKey $deployGitUsername

currentUser=$(whoami)
if [[ "$currentUser" != "hugo" ]]; then
	echo "[ERROR] You mush run this script with \"sudo -u hugo $(realpath $0)\""
	exit 1

fi
