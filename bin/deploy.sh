#!/bin/bash

# env > ~/.env
set -o xtrace

cd "$(dirname "$0")"
cd ..
export BASE_PATH=$(pwd)
source $BASE_PATH/bin/common.sh

echo -e "\033[0;32mDeploying updates to GitHub...\033[0m"

cd $BASE_PATH

useSSHKey $publicGitUsername

git submodule add $publicGitRepoName
cd $BASE_PATH/$publicFolder
git checkout -b main origin/main

cd $BASE_PATH
useSSHKey $deployGitUsername
git add .
git commit -m "Add submodule $publicFolder"

#echo "[INFO] Reset repo to remote origin to prevent big failure commit"
##git status
##git fetch origin
##git reset --hard origin/main


# Build the project.
echo "[INFO] hugo minify for t5/content to t5/$publicFolder"
/usr/local/bin/hugo --minify # if using a theme, replace with `hugo -t <YOURTHEME>`
cd $BASE_PATH/$publicFolder
rm -rf *

cd $BASE_PATH
mv -v -f ./public/* $publicFolder/

cd $BASE_PATH/$publicFolder
echo "Update domain to https://$publicFolder"
find . -type f -name "*.html" -exec sed -i  "s/shwchurch[[:digit:]]\+/$publicGitUsername/g" {} \;

cd $BASE_PATH
#./bin/deploy-before-2015.sh $publicFolder
#./bin/deploy-before-2020.sh $publicFolder
./bin/deploy-uploads.sh $publicFolder $uploadsGitUsername1 2008 2015 
./bin/deploy-uploads.sh $publicFolder $uploadsGitUsername2 2016 2020

echo "[INFO] Publish content to GithubPage https://$publicFolder"
cd $BASE_PATH/$publicFolder
useSSHKey $publicGitUsername

echo "[INFO] Reduce files that may alter every compilation"
find . -type f -name "*.html" -exec sed -i  "s/id=gallery-[[:digit:]]\+/id=gallery-replaced/g" {} \;
find . -type f -name "*.html" -exec sed -i  "s/galleryid-[[:digit:]]\+/galleryid-replaced/g" {} \;
find . -type f -name "*.html" -exec sed -i  "s#https\?:/wp-content#/wp-content#g" {} \;
find . -type f -name "*.html" -exec sed -i  "s#title=[a-z0-9-]{1,}#title=____#g" {} \;
find . -type f -name "*.html" -exec sed -i  "s#alt=[a-z0-9-]{1,}#alt=____#g" {} \;

git config --global core.quotePath false

gitAddCommitPush(){
	#waitGitComplete
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
	git push --set-upstream origin main  --force

	
}
export -f gitAddCommitPush

# Commit changes.
# Add changes to git.
START=2005
END=$(date +'%Y')
MONTH=$(date +"%m")
cd $BASE_PATH/$publicFolder
gitCommitByBulk "${END}/${MONTH}" $publicGitUsername
gitCommitByBulk "wp-content/uploads/${END}/${MONTH}" $publicGitUsername
gitCommitByBulk "index.html" $publicGitUsername
gitCommitByBulk "404.html" $publicGitUsername
gitCommitByBulk "feed.xml" $publicGitUsername
gitCommitByBulk "js" $publicGitUsername
gitCommitByBulk "images" $publicGitUsername
gitCommitByBulk "scss" $publicGitUsername
#gitAddCommitPush "${END}/${MONTH}"


#waitGitComplete
echo "[INFO] Wait for GH Pages building pipeline"
sleep 120
for i in $(seq $START $END)
do
	#waitGitComplete
	#git reset "$i/"
	gitCommitByBulk "$i/" $publicGitUsername
done
#gitAddCommitPush "." "Commit all the rest"
#waitGitComplete
cd $BASE_PATH/$publicFolder
gitCommitByBulk "categories" $publicGitUsername
gitCommitByBulk "wp-content" $publicGitUsername

rangeGitAddPush page 1 10 $publicGitUsername 
rangeGitAddPush "posts/page" 1 10 $publicGitUsername 

waitGitComplete
cd $BASE_PATH/$publicFolder
git add .
git commit -m "Commit all the rest"
git push --set-upstream origin main  --force

# Remove last commit
#git reset --hard
#git clean -fd


# Come Back up to the Project Root
