#!/bin/bash

# env > ~/.env
export $(cat /home/ec2-user/.env | sed 's/#.*//g' | xargs)

set -o xtrace

echo -e "\033[0;32mDeploying updates to GitHub...\033[0m"

cd "$(dirname "$0")"

cd ..

path=$(pwd)

killLongRunningGit(){
        ps aux | egrep "\sgit\s" | awk '{print $2}' | xargs kill
}

cd $pwd/public
echo "[INFO] Reset repo to remote origin to prevent big failure commit"
git status
git fetch origin
git reset --hard origin/master
cd $pwd 


# Build the project.
echo "[INFO] hugo minify for t5/content to t5/public"
/usr/local/bin/hugo --minify # if using a theme, replace with `hugo -t <YOURTHEME>`


# Remove unnecessary html markup to reduce git commit
cd $pwd/
./bin/deploy-before-2015.sh
cd $pwd/public
echo "[INFO] Reduce files that may alter every compilation"
#find . -type f -name "*.html" -exec sed -i  "s/id=gallery-[[:digit:]]\+/id=gallery-replaced/g" {} \;
#find . -type f -name "*.html" -exec sed -i  "s/galleryid-[[:digit:]]\+/galleryid-replaced/g" {} \;
#find . -type f -name "*.html" -exec sed -i  "s#https\?:/wp-content#/wp-content#g" {} \;
#find . -type f -name "*.html" -exec sed -i  "s#title=[a-z0-9-]{1,}#title=____#g" {} \;
#find . -type f -name "*.html" -exec sed -i  "s#alt=[a-z0-9-]{1,}#alt=____#g" {} \;

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


gitAddCommitPush(){
	waitGitComplete
	path=$1
	msg=$2
	git add "${path}"
	git add "${path}*"
	git add "${path}\*"

	if [[ -z ${msg} ]];then
		msg="[Partial] Commit for ${path} `date`"
	fi
	
	git commit -m "$msg"
	
	# Push source and build repos.
	git push --set-upstream origin master  --force

	
}
export -f gitAddCommitPush

rangeGitAddPush(){
	pathPrefix=$1
	start=$2
	end=$3

	for i in $(seq $start $end)
	do
		gitCommitByBulk "$pathPrefix/${i}"
		gitCommitByBulk "$pathPrefix/${i}*"
		#gitAddCommitPush "$pathPrefix/${i}"
	done
}


# Commit changes.
# Add changes to git.
START=2005
END=$(date +'%Y')
MONTH=$(date +"%m")
gitCommitByBulk "${END}/${MONTH}"
gitCommitByBulk "wp-content/uploads/${END}/${MONTH}"
gitCommitByBulk "index.html"
gitCommitByBulk "404.html"
gitCommitByBulk "feed.xml"
gitCommitByBulk "js"
gitCommitByBulk "images"
gitCommitByBulk "scss"
#gitAddCommitPush "${END}/${MONTH}"


waitGitComplete
echo "[INFO] Wait for GH Pages building pipeline"
sleep 600
for i in $(seq $START $END)
do
	waitGitComplete
	#git reset "$i/"
	gitCommitByBulk "$i/"
done
#gitAddCommitPush "." "Commit all the rest"
waitGitComplete
cd $pwd/public
gitCommitByBulk "index.html"
gitCommitByBulk "categories"
gitCommitByBulk "wp-content"

rangeGitAddPush page 1 10
rangeGitAddPush "posts/page" 1 10
waitGitComplete
cd $pwd/public
git add .
git commit -m "Commit all the rest"
git push --set-upstream origin master  --force

# Remove last commit
#git reset --hard
#git clean -fd


# Come Back up to the Project Root
