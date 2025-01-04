#!/bin/bash

#set -o xtrace
export BASE_PATH_COMMON=$(dirname "$0")
cd $BASE_PATH_COMMON
cd ../
export BASE_PATH_COMMON=$(pwd)
export $(cat ${BASE_PATH_COMMON}/.env | xargs)

export $(cat /mnt/hugo/.env | sed 's/#.*//g' | echo)
export $(cat /mnt/hugo/.env | sed 's/#.*//g' | xargs)

cd $BASE_PATH_COMMON


export TMP_PATH=$BASE_PATH_COMMON/tmp

echo "TMP_PATH $TMP_PATH"

# export deployGitUsername=shwchurch3
export deployGitUsername=shwchurch2023
export publicGitUsername=shwchurch7
# export publicGitUsername=shwchurch3

# Those gitUsernames must match pattern `shwchurch.*` defined in bin/deploy-uploads.sh
export uploadsGitUsername1=shwchurch4
export uploadsGitUsername2=shwchurch2023media
export uploadsGitUsername3=shwchurch2024media

export githubSplitPart_uploadsGitUsername1From=2008
export githubSplitPart_uploadsGitUsername2From=2016
export githubSplitPart_uploadsGitUsername3From=2023

export currYear=`date +%Y`

export publicFolder=${publicGitUsername}.github.io
export publicFolderAbs=$BASE_PATH_COMMON/$publicFolder

export hugoPublicFolderAbs=$BASE_PATH_COMMON/public

export uploadsGitUsername1FolderAbs=$BASE_PATH_COMMON/$uploadsGitUsername1.github.io
export uploadsGitUsername2FolderAbs=$BASE_PATH_COMMON/$uploadsGitUsername2.github.io
export uploadsGitUsername3FolderAbs=$BASE_PATH_COMMON/$uploadsGitUsername3.github.io

# export themeFolder=$BASE_PATH_COMMON/themes/hugo-theme-shwchurch
export themeFolder=$BASE_PATH_COMMON/themes/hugo-theme-stack

export filePathUrlMappingFilePath=$BASE_PATH_COMMON/pathDistributionMapping.txt
export filePathUrlMappingFilePathManual=$BASE_PATH_COMMON/pathDistributionMappingManual.txt

export mirrorPublicGithubTokenList=$BASE_PATH_COMMON/mirror-public-github-token__gitignore.txt

separator=________

export submodule_used_path=$BASE_PATH_COMMON/submodule_used.log

# export find_not_hidden_args=" -not -path '*/.*'"
# export find_main_public_site_args="${publicFolderAbs} ${find_not_hidden_args}"

git config --global core.quotePath false

lock_file(){
	lock_name=${1}

	lock_path=/tmp/t5_lock_${lock_name}
	if [[ -f "${lock_path}" ]];then
		lock_process_id=$(cat ${lock_path})
		is_process_exist=$(ps aux | grep -v grep | grep " ${lock_process_id} ")
		if [[ ! -z "${lock_process_id}" && ! -z "${is_process_exist}" ]];then
			echo -ne "\n\n[$0] The lock file with process [${is_process_exist}] is alive for lock [${lock_name}'. Exit\n\n"
			exit 2
		fi
	fi

	lock_file_current_process_id=$$

	echo -ne "\n\n[$0] lock [$lock_name] is successful with process ${lock_file_current_process_id} @ [$lock_path]\n\n"
	echo "${lock_file_current_process_id}" > ${lock_path}
	
}
export lock_file

unlock_file(){
	lock_name=${1}

	lock_path=/tmp/t5_lock_${lock_name}
	
	rm ${lock_path}
	
	
}
export unlock_file

is_lock_file_dead_unexpected(){
	lock_name=${1}

	lock_path=/tmp/t5_lock_${lock_name}
	
	if [[ -f "${lock_path}" ]];then
		lock_process_id=$(cat ${lock_path})
		is_process_exist=$(ps aux | grep -v grep | grep " ${lock_process_id} ")
		>&2 echo "[$0] locker process is dead before completion"
		if [[ ! -z "${lock_process_id}" && -z "${is_process_exist}" ]];then
			echo "Yes"
		fi
	fi
	
	
}
export is_lock_file_dead_unexpected

step_file=/tmp/t5_shouldExecuteStep_step

time_diff_seconds(){
	# date1=$(date +%s)
	local date1=$1
	# date2=$(date +%s)
	local date2=$2
	echo $(( date2 - date1))
}
export time_diff_seconds

shouldExecuteStep(){
	stepid=${1}
	steplabel=${2}

	# >&2 echo "[$0] step_id ${stepid}"

	if [[ -z "${stepid}" ]];then
		exit 1
	fi

	if [[ ! -f "${step_file}" ]];then
		echo "true"
		executeStepStart $stepid $steplabel
		return 0
	fi

	laststepid=$(cat ${step_file} | tr -d '\n')

	if [[ -z "${laststepid}" ]];then
	
		echo "true"
		executeStepStart $stepid $steplabel
		return 0
	fi

	# >&2 echo "[$0] last_step_id ${laststepid}"

	if (( "$((stepid-laststepid))" >= 0 ))
	then
		echo "true"
		executeStepStart $stepid $steplabel
		return 0
	fi

	>&2 echo "[$0] Skip step ${stepid} (label: $steplabel) since last step executed is [${laststepid}] according to [${step_file}]"
	
}
export shouldExecuteStep

executeStepStart(){
	step_id=${1}
	steplabel=${2}
	echo "${step_id}" > $step_file
	>&2 echo "[$0] Executing step ${step_id} with label [$steplabel]"
}
export executeStepStart

executeStepAllDone(){
	rm -f $step_file
	echo "[$0] Executing steps are all done and tracking file is removed at $(date)"
}
export executeStepAllDone


findAndReplace(){
	sed_cmd=${1}

	pathToFind=${2:-"${publicFolderAbs}"}
	filePattern=${3:-"*.html"}

	minArg=1
	if [[ "$#" -lt "${minArg}" ]]; then
		# TODO: print usage
		echo "Need at least $minArg arguments"
		return 2
	fi

	(

		cd $pathToFind
		echo "cd $pathToFind; find . -not -path '*/.*' -type f -name \"${filePattern}\" -exec sed -i \"${sed_cmd}\" {} \;"
		find . -not -path '*/.*' -type f -name "${filePattern}" -exec sed -i "${sed_cmd}" {} \;

	)

	# find "${find_main_public_site_args}"  -type f -name "*.html" -exec sed -i  "s/id=gallery-[[:digit:]]\+/id=gallery-replaced/g" {} \;

}
export findAndReplace

findAndReplaceV2(){
	sed_cmd=${1}
	filePath=${3:-"${publicFolderAbs}/PLACE_HOLDER.html"}

	minArg=1
	if [[ "$#" -lt "${minArg}" ]]; then
		# TODO: print usage
		echo "Need at least $minArg arguments"
		return 2
	fi

	if [[ -z "$filePath" ]];then
		findAndReplace $sed_cmd
	else
		(

			echo "sed -i \"${sed_cmd}\" ${filePath} "
			sed -i "${sed_cmd}" ${filePath} 

		)
	fi



	# find "${find_main_public_site_args}"  -type f -name "*.html" -exec sed -i  "s/id=gallery-[[:digit:]]\+/id=gallery-replaced/g" {} \;

}
export findAndReplaceV2

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
	err_code=$1
	child_label=$2
	if [[ "${err_code}" != "0" ]];then
		echo "[ERROR] Child process [${child_label}] returns error code ${err_code}"
		exit 3
	fi
}
export ensureNoErrorOnChildProcess

export ensureRequiredFolder

ensureRequiredFolders() {
	updateAllSubmodules
	cd $themeFolder
	git checkout -b main origin/main
	ensureRequiredFolder $themeFolder
	cd $BASH_PATH
}
export ensureRequiredFolders

installGo(){
	# cd /tmp
	# local go_tar=go1.23.4.linux-amd64.tar.gz
	# wget https://go.dev/dl/${go_tar}
	# sudo rm -rf /usr/local/go 
	# sudo tar -C /usr/local -xzf ${go_tar}
	# sudo snap install node --channel=16/stable --classic
	curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
}
export installGo

installNodeJs(){
	# cd /tmp
	# local go_tar=go1.23.4.linux-amd64.tar.gz
	# wget https://go.dev/dl/${go_tar}
	# sudo rm -rf /usr/local/go 
	# sudo tar -C /usr/local -xzf ${go_tar}
	# sudo snap install node --classic
	# sudo ln -s /var/lib/snapd/snap/bin/node /usr/bin/node 
	# sudo ln -s /var/lib/snapd/snap/bin/npm /usr/bin/npm 
	sudo yum -y remove libuv -y    
	sudo yum -y install libuv --disableplugin=priorities
	sudo yum -y install nodejs npm --enablerepo=epel
	sudo npm install ts-node -g
	cd $BASE_PATH_COMMON
	npm install
	# sudo npm i commander -g
}
export installNodeJs

installSnap(){
	cd /tmp
	mkdir snap
	cd snap
	# wget https://github.com/albuild/snap/releases/download/v0.1.0/snap-confine-2.36.3-0.amzn2.x86_64.rpm
	# wget https://github.com/albuild/snap/releases/download/v0.1.0/snapd-2.36.3-0.amzn2.x86_64.rpm

	sudo yum -y install squashfs-tools
	# sudo rpm -i *.rpm
	# sudo systemctl enable --now snapd.socket

	sudo wget -O /etc/yum.repos.d/snapd.repo \
		https://bboozzoo.github.io/snapd-amazon-linux/amzn2/snapd.repo
	sudo yum install snapd -y
	sudo systemctl disable --now snapd.socket
	sudo systemctl enable --now snapd.socket

}
export installSnap

installHugoDependencies(){
	installSnap
	installGo
	installNodeJs
	sudo snap install dart-sass
}
export installHugoDependencies

hugoBuild() {
	cd $BASE_PATH_COMMON

	echo "To update hugo, download latest tar.gz from https://github.com/gohugoio/hugo/releases to /mnt/hugo/ and unzip"
	echo "Current $( ls /mnt/hugo/ | grep hugo_ )"
	# echo "New: $(curl https://github.com/gohugoio/hugo/releases 2>/dev/null | grep "_Linux-64bit.tar.gz" | head -1)"
	# echo "New: https://github.com/$(curl https://github.com/gohugoio/hugo/releases 2>/dev/null | grep -oP 'href=".+?_Linux-64bit.tar.gz"' | sed -r 's/.*href="(.+?_Linux-64bit.tar.gz).*/\1/'  | head -1)"
	
	echo "New Hugo Extended version in https://github.com/gohugoio/hugo/releases. Must be extended."
	
	echo "You also need to install snap, golang and dart-scss by [installHugoDependencies] "

	npx ts-node typescript/commander.ts wpHugoExporterAfterAllProcessor --path $BASE_PATH_COMMON/content
	
	/mnt/hugo/hugo --minify # if using a theme, replace with `hugo -t <YOURTHEME>`
	local exit_code_hugo_build=$?
	if [[ "$exit_code_hugo_build" != "0" ]]; then
		echo "[WARN] /mnt/hugo/hugo failed"
		return $exit_code_hugo_build
	fi
}
export hugoBuild

syncPodcast(){
	cd $BASE_PATH_COMMON
	./bin/sync-podcast.sh 
}
export syncPodcast

gitSetUser(){
	git config user.email "shwchurch3@gmail.com"
	git config user.name "Shouwang Church"
}

export gitSetUser

rmSafe() {
	dir=$1
	expectPathPart=$2
	onlyWarning=$3
	getRealPath=$(realpath $dir)
	echo "[INFO] rmSafe $getRealPath (arg: ${1})"
	if [[ ! -z "$dir" && "$getRealPath" =~ "$expectPathPart" ]]; then
		realpath $dir | xargs rm -rf
	else
		echo "[ERROR][rmSafe] $dir is a dangerous path that couldn't be rm -rf "
		if [[ -z "$onlyWarning" ]]; then
			exit 1
		fi
	fi
}
export rmSafe

addNewGithubAccountAsMirror(){
        username=$1
        token=$2

		touch $mirrorPublicGithubTokenList
		echo "${username}:${token}" >> $mirrorPublicGithubTokenList

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
			
			# credentials=(${(s/:/)line})
			IFS=: read -r username token <<< "$line"
			
			# username=${credentials[1]}
			# token=${credentials[2]}

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
				-d '{"branch":"'${branch}'"}'

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

    ssh-keygen -t ed25519 -f "${key}" -C "${username}@outlook.com" -q -N '""'

    pub_key=${key}.pub

	chmod 600 ${key}
	chmod 600 ${pub_key}

    echo "Add the generated SSH pub key to https://github.com/settings/ssh/new"
    pwd
    ls -la
    echo ""
    cat ${pub_key}

	echo ""
	echo "Also, update [[ uploadsGitUsername2 ]] or add new [[ uploadsGitUsernameN ]] and its usage in [[ ./bin/deploy-uploads.sh \"\$publicFolder\" \"\$uploadsGitUsername2\" \"\${githubSplitPart_uploadsGitUsername2From}\" \"\$((currYear-1))\" int_step_id_base ]]"
	help_createGithubIo

	echo "Then start a new ... bin/deploy.sh ... "
}

export addSSHKey

help_createGithubIo(){
	username=${1}
	gitRepoName=${username}.github.io
	echo "----------"
	echo "Also, create repo [[ ${gitRepoName} ]]"
	echo "Generate a personal token from https://github.com/settings/tokens"
	echo "And init it in your local macOS with the hint from github "
	echo "Create index.html in the repo root"
	echo "Make sure [[ git remote set-url origin https://${username}:____TOKEN____@github.com/${username}/${gitRepoName}.git ]]"

	echo "Then protect main branch [[ https://github.com/${username}/${username}/.github.io/settings/branch_protection_rules/new ]]"
	echo "And enable Github Pages [[ https://github.com/${username}//${username}/.github.io/settings/pages ]]"
	echo "--------"
}

useSSHKey(){
		pkill ssh-agent
        username=${1:-"shwchurch2023"}
        key=/mnt/hugo/ssh/id_ed25519_$username
	
        chmod 600 $key
        chmod 644 $key.pub
        eval `ssh-agent -s`
        ssh-add -D $key
        ssh-add $key
        ssh-add -l
        #git config --global core.sshCommand "ssh -i $key -F /dev/null"
        #git config --global --unset core.sshCommand
        #git config --unset core.sshCommand
        git config core.sshCommand "ssh -i $key -o StrictHostKeyChecking=no -F /dev/null"
        #export GIT_SSH_COMMAND="ssh -i $key -o IdentitiesOnly=yes"

}

export useSSHKey

killLongRunningGit(){
	echo "[$0]"
	ps aux | egrep "\sgit\s" | awk '{print $2}' | xargs -I{} kill -9 {}
}
export killLongRunningGit 

updateRepo(){
	dir=$1
	echo "Update repo in $dir"
	cd $dir

	rm -rf .git/index.lock

	git config --global --add safe.directory $dir

	# move all git rebase/merge leftover
	# rm -rf .git_*

	gitSetUser
	git add .
	git commit -m "Add current changes"
	git pull --no-edit
	git push

	# echo "[DEBUG] Skipped [Try to update parent repo if any]"
	echo "Try to update parent repo if any"
	cd ..
	gitSetUser
	git add .
	git commit -m "Child repo changed"
	git pull --no-edit
	git push
}
export updateRepo

initSubmoduleUsage(){
	echo "themes/hugo-theme-yuki"  > $submodule_used_path
	echo "themes/hugo-theme-shwchurch" >> $submodule_used_path
	echo "public" >> $submodule_used_path

	echo "$deployGitUsername" >> $submodule_used_path
	echo "$publicGitUsername" >> $submodule_used_path

}
export initSubmoduleUsage

helpCleanSubmodules(){
	git config --file .gitmodules --get-regexp path | awk '{ print $2 }' | while read line 
	do
	# do something with $line here
	if grep -q "$line" "$submodule_used_path"; then
		echo "Sumodule [[ $line  ]] used"
	else
		echo "Sumodule [[ $line  ]] is NOT used. Consider remove it by:"
		echo "[[ git submodule deinit -f ${line} ]]"
		echo "[[ rm -rf .git/modules/${line} ]]"
		echo "[[ git rm -f ${line} ]]"
	fi
	done
	# cat $submodule_used_path | while read line 
	# do
	# # do something with $line here
	# done
}
export helpCleanSubmodules

addSubmodule(){
	githubUserName=$1
	repoName=$2
	
	submoduleUrl=git@github.com:${githubUserName}/${repoName}.git

	echo "[$0] Usage: addSubmodule shwchurch2024media shwchurch2024media.github.io"

	cd $BASE_PATH_COMMON
	pwd
	useSSHKey $githubUserName
	git submodule add -f $submoduleUrl
	echo "${repoName}" >> $submodule_used_path
	cd $repoName
	# try to init new main

	if [[ ! -f "README.md" ]];then
		echo "Init repo ${githubUserName}.github.io with README.md and main branch"
		git fetch origin
		git checkout -b main origin/main
		echo "# ${githubUserName}.github.io" >> README.md
		git reset .
		git add README.md
		git commit -m "first commit"
		git branch -M main
		git push -u origin main
	fi

	git checkout -b new_tmp
	git checkout new_tmp
	git branch -D main
	# git branch -m master main
	git fetch origin
	git branch -u origin/main main
	git remote set-head origin -a
	git checkout -b main origin/main
	git branch -D new_tmp
	cd $BASE_PATH_COMMON
	useSSHKey $deployGitUsername
	git add .
	git commit -m "added submodule $submoduleUrl"
	cat .gitmodules
	git pull origin main
	git push origin main 

}
export addSubmodule

waitGitComplete(){
	while [[ !  -z "$(ps aux |  grep git | grep -v sync | grep -v grep | grep -v github)"  ]];do
		echo "$(date): Git is running"
		sleep 10	
	done
}
export waitGitComplete


gitCommitByBulk(){
	#waitGitComplete
    dir=$1
	gitUsername=$2
	isExitOnUnpresentPath=$3

	if [[ ! -z "$isExitOnUnpresentPath" && ! -f "$dir" && ! -d  "$dir" ]];then
		echo "[WARN][gitCommitByBulk] dir $dir must be present; skipped"
		return 1
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
	countLines=$(git ls-files -dmo ${dir} | grep -v '/sed' | head -n ${bulkSize} | wc -l)
	echo "[INFO] Start git push at dir $dir at bulk $bulkSize"
	# git ls-files -dmo ${dir} | head -n ${bulkSize}
	#rm -rf .git/index.lock
	#rm -rf .git/index
	while [[ "${countLines}" != "0"  ]]
	do
		#waitGitComplete
		git ls-files -dmo "${dir}" | grep -v '/sed' | head -n ${bulkSize} | xargs -t -I {} echo -e '{}' | xargs -I{} git add "{}"
		finaMsg="[Bulk] ${msg} - Added ${dir}@${countLines} files"
		echo "$finaMsg"
		useSSHKey $gitUsername
		git commit -m "$finaMsg"
		useSSHKey $gitUsername
		git push --set-upstream origin main  --force
		countLines=$(git ls-files -dmo "${dir}" | grep -v '/sed' | head -n ${bulkSize} | wc -l)
	done
	git add "${dir}"
	useSSHKey $gitUsername
	git commit -m "[INFO] last capture all of dir $dir, ${msg}"
	useSSHKey $gitUsername
	git push --set-upstream origin main --force
}
export gitCommitByBulk

waitGitComplete(){
	while [[ !  -z "$(ps aux |  grep git | grep -v sync | grep -v grep | grep -v github)"  ]];do
		echo "$(date): Git is running"
		sleep 10	
	done
}

export waitGitComplete

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
export rangeGitAddPush

applyDistributionMapping(){
	local findAndReplace_base_step_local=${1}
	local dirRelativePath=${2}
	echo "[$0] $filePathUrlMappingFilePath"
	cat $filePathUrlMappingFilePath
	applyPathMapping "$filePathUrlMappingFilePath" "$findAndReplace_base_step_local" "$dirRelativePath"
}
export applyDistributionMapping

applyPathMapping(){
	local file=${1}
	local applyPathMapping_findAndReplace_base_step_local=${2}

	local dirRelativePath=${3}

	echo "[$0] Apply mappings from $file"
	cat $file

	cd $BASH_PATH
	while IFS= read line
	do
		if [[ ! -z "$line" ]];then
			echo "[$0] $line"
			if [[ -z "${applyPathMapping_findAndReplace_base_step_local}" ]];then
				findAndReplace "$line" "${publicFolderAbs}/${dirRelativePath}" 
			else
				applyPathMapping_findAndReplace_base_step_local=$((applyPathMapping_findAndReplace_base_step_local + 1))
				if [[ "$(shouldExecuteStep ${applyPathMapping_findAndReplace_base_step_local} DeploySplitFiles_wp-content_uploads)" = "true" ]];then
					findAndReplace "$line" "${publicFolderAbs}/${dirRelativePath}"
				fi
			fi
			
			# find "${find_main_public_site_args}" -type f -name "*.html" -exec sed -i  "$line" {} \; 
		fi
			# display $line or do something with $line
	done <"$file"
}

export applyPathMapping

applyManualDistributionMapping(){
	findAndReplace_base_step_local=${1}
	dirRelativePath=${2}
	echo "[$0] $filePathUrlMappingFilePathManual"
	applyPathMapping "$filePathUrlMappingFilePathManual" "$findAndReplace_base_step_local" "$dirRelativePath"
}
export applyManualDistributionMapping

commitEssential(){
	local END=${1:-"$(date +'%Y')"}
	local MONTH=${2:-"$(date +"%m")"}

	echo "[$0] Start: ${END}/${MONTH}"
	cd $publicFolderAbs
	gitCommitByBulk "${END}/${MONTH}" $publicGitUsername
	gitCommitByBulk "wp-content/uploads/${END}/${MONTH}" $publicGitUsername
	gitCommitByBulk "index.html" $publicGitUsername "true"
	gitCommitByBulk "404.html" $publicGitUsername "true"
	gitCommitByBulk "feed.xml" $publicGitUsername
	gitCommitByBulk "js" $publicGitUsername
	gitCommitByBulk "ts" $publicGitUsername
	gitCommitByBulk "img" $publicGitUsername
	gitCommitByBulk "images" $publicGitUsername
	gitCommitByBulk "scss" $publicGitUsername

	echo "[$0] Done: ${END}/${MONTH}"
}
export commitEssential

commitEssentialAndUpdateManualStart(){

	local commitEssentialAndUpdateManualStart_findAndReplace_base_step=${1}
	local END=${2:-"$(date +'%Y')"}
	local MONTH=${3:-"$(date +"%m")"}

	echo "[$0] $commitEssentialAndUpdateManualStart_findAndReplace_base_step $END $MONTH"

	applyDistributionMapping "${commitEssentialAndUpdateManualStart_findAndReplace_base_step}" "${END}/${MONTH}"
	applyManualDistributionMapping "${commitEssentialAndUpdateManualStart_findAndReplace_base_step}" "${END}/${MONTH}"
	commitEssential
	syncForkInMirrorGithubAccounts
}
export commitEssentialAndUpdateManualStart

reduceCompilationSize(){
	cd $publicFolderAbs
	useSSHKey $publicGitUsername

	echo "[INFO] Reduce files that may alter every compilation"
	echo "[INFO] Skipped this step since we've updated hugo-theme-stack"

	return 0

	findAndReplace "s/id=gallery-[[:digit:]]\+/id=gallery-replaced/g"
	# find "${find_main_public_site_args}"  -type f -name "*.html" -exec sed -i  "s/id=gallery-[[:digit:]]\+/id=gallery-replaced/g" {} \;
	findAndReplace "s/galleryid-[[:digit:]]\+/galleryid-replaced/g"
	# find "${find_main_public_site_args}"  -type f -name "*.html" -exec sed -i  "s/galleryid-[[:digit:]]\+/galleryid-replaced/g" {} \;
	findAndReplace "s#https\?:/wp-content#/wp-content#g"
	# find "${find_main_public_site_args}"  -type f -name "*.html" -exec sed -i  "s#https\?:/wp-content#/wp-content#g" {} \;
	findAndReplace "s#title=[a-z0-9-]{1,}#title=____#g"
	# find "${find_main_public_site_args}"  -type f -name "*.html" -exec sed -i  "s#title=[a-z0-9-]{1,}#title=____#g" {} \;
	findAndReplace "s#alt=[a-z0-9-]{1,}#alt=____#g"
	# find "${find_main_public_site_args}"  -type f -name "*.html" -exec sed -i  "s#alt=[a-z0-9-]{1,}#alt=____#g" {} \;

}
export reduceCompilationSize


export SHELL=/bin/bash
export PATH=/usr/local/openssl/bin:/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:/opt/aws/bin:$PATH:/snap/bin

useSSHKey $deployGitUsername

currentUser=$(whoami)
if [[ "$currentUser" != "hugo" ]]; then
	echo "[ERROR] You mush run this script with \"sudo -u hugo $(realpath $0)\""
	exit 1

fi
