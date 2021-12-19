#!/bin/bash

# env > ~/.env
#export $(cat /home/ec2-user/.env | sed 's/#.*//g' | xargs)

set -o xtrace

echo -e "\033[0;32mDeploying updates to GitHub...\033[0m"
export PATH=/usr/local/openssl/bin:/sbin:/bin:/usr/sbin:/usr/bin:/opt/aws/bin:$PATH

cd "$(dirname "$0")"

cd ..

BASE_PATH=$(pwd)

githubUserName=shwchurch4
githubKey=id_ed25519_shwchurch4
#githubKey=id_ed25519_shwchurch3+before-2015
githubMainUserName=shwchurch3
githubMainKey=id_ed25519

killLongRunningGit(){
        ps aux | egrep "\sgit\s" | awk '{print $2}' | xargs kill
}

addSshKey(){
	key=$1
	chmod 600 $key
	chmod 644 $key.pub
	eval `ssh-agent -s`
	ssh-add $key
	ssh-add -l 
	git config --global core.sshCommand "ssh -i $key -F /dev/null"
}

switchSshKey(){
	addSshKey /home/ec2-user/.ssh/${githubKey}
}
restoreSshKey(){
	addSshKey /home/ec2-user/.ssh/${githubMainKey}
}

repo=${githubUserName}.github.io
mainRepo=${githubMainUserName}.github.io
sumoduleUrl=git@github.com:${githubUserName}/${repo}.git
switchSshKey

#git submodule add $sumoduleUrl
git submodule add $sumoduleUrl
restoreSshKey
git add .
git commit -m "added submodule $sumoduleUrl"
cat .gitmodules

cd $BASE_PATH/public

splitFiles(){
	path=$1
	rm -rf ../${repo}/$path
	mkdir -p ../${repo}/$path
	mv $path/* ../${repo}/$path
	find . -type f -name "*.html" -exec sed -i  "s#/$path#https://${repo}/$path#g" {} \;
	find . -type f -name "*.html" -exec sed -i  "s#https:https:#https:#g" {} \;
	cd $BASE_PATH/${repo}
	switchSshKey
	gitCommitByBulk $path
	cd $BASE_PATH/public
	restoreSshKey
}

git config --global core.quotePath false

waitGitComplete(){
	while [[ !  -z "$(ps aux |  grep git | grep -v sync | grep -v grep | grep -v github)"  ]];do
		echo "$(date): Git is running"
		sleep 10	
	done
}

gitCommitByBulk(){
	waitGitComplete
        path=$1
	msg=$2
        bulkSize=$3
	if [[ -z "$bulkSize" ]]; then
		bulkSize=200
	fi
	echo "[INFO][gitCommitByBulk] Process $path"
	pwd
	countLines=$(git ls-files -dmo ${path} | head -n ${bulkSize} | wc -l)
	echo "[INFO] Start git push at path $path at bulk $bulkSize"
	git ls-files -dmo ${path} | head -n ${bulkSize}
	#rm -rf .git/index.lock
	#rm -rf .git/index
	while [[ "${countLines}" != "0"  ]]
	do
		waitGitComplete
		git ls-files -dmo "${path}" | head -n ${bulkSize} | xargs -t -I {} echo -e '{}' | xargs -I{} git add "{}"
		finaMsg="[Bulk] ${msg} - Added ${path}@${countLines} files"
		echo "$finaMsg"
		git commit -m "$finaMsg"
		git push --set-upstream origin master  --force
		countLines=$(git ls-files -dmo "${path}" | head -n ${bulkSize} | wc -l)
	done
	git add "${path}"
	git commit -m "[INFO] last capture all of path $path, ${msg}"
	git push --set-upstream origin master --force
}
export -f gitCommitByBulk


rangeGitAddPush(){
	pathPrefix=$1
	start=$2
	end=$3

	for i in $(seq $start $end)
	do
		gitCommitByBulk "$pathPrefix/${i}"
		gitCommitByBulk "$pathPrefix/${i}*"
	done
}


# Commit changes.
# Add changes to git.
START=2008
END=2015

for i in $(seq $START $END)
do
	waitGitComplete
	#git reset "$i/"
	splitFiles wp-content/uploads/$i
done
waitGitComplete

# Come Back up to the Project Root
cd $BASE_PATH/
