#!/bin/bash

# env > ~/.env
if [[ -z "$BASE_PATH" ]];then
    cd "$(dirname "$0")"
    cd ..
    export BASE_PATH=$(pwd)
    source $BASE_PATH/bin/common.sh
fi

cd $BASE_PATH

echo -e "\033[0;32mDeploying updates to GitHub...\033[0m"

cd $BASE_PATH

#echo "[INFO] Reset repo to remote origin to prevent big failure commit"
##git status
##git fetch origin
##git reset --hard origin/main

echo "[INFO] Sync podcast"
syncPodcast

# Build the project.
echo "[INFO] hugo minify for t5/content to t5/$publicFolder"

hugoBuild
ensureRequiredFolder $hugoPublicFolderAbs

publicFolderIndexHtml="$publicFolderAbs/index.html"

cd $BASE_PATH
addSubmodule $publicGitUsername $publicFolder
ensureRequiredFolder $publicFolderAbs

cd $publicFolderAbs
rmSafe "./*" "github.io"

if [[ -f "${publicFolderIndexHtml}" ]];then
	echo "[ERROR] $publicFolderIndexHtml should be cleared"
	exit 1
fi

cd $BASE_PATH
mv -v -f $hugoPublicFolderAbs/* $publicFolderAbs/
if [[ "$?" != "0" || ! -f "${publicFolderIndexHtml}" ]];then
	echo "[ERROR] Failed on moving files in $hugoPublicFolderAbs to $publicFolderAbs/ "
	ls $publicFolderAbs
	exit 1
fi

cd $publicFolderAbs
echo "Update domain to https://$publicFolder"
findAndReplace "s/shwchurch[[:digit:]]+/$publicGitUsername/g"
# find "${find_main_public_site_args}" -type f -name "*.html" -exec sed -i  "s/shwchurch[[:digit:]]\+/$publicGitUsername/g" {} \;

cd $BASE_PATH
echo "[INFO] Apply path mapping from"
applyDistributionMapping
applyManualDistributionMapping
START=2005
END=$(date +'%Y')
MONTH=$(date +"%m")
commitEssential "$END" "$MONTH" 

echo "[INFO] Remove $filePathUrlMappingFilePath"
rmSafe "$filePathUrlMappingFilePath" "t5" "true"
touch "$filePathUrlMappingFilePath"
echo "" > "$filePathUrlMappingFilePath"
cd $BASE_PATH
./bin/deploy-uploads.sh "$publicFolder" "$uploadsGitUsername1" 2008 2015 
ensureNoErrorOnChildProcess "$?"
cd $BASE_PATH
./bin/deploy-uploads.sh "$publicFolder" "$uploadsGitUsername2" 2016 2022
ensureNoErrorOnChildProcess "$?"

echo "[INFO] Publish content to GithubPage https://$publicFolder"

# Commit changes.
# Add changes to git.
reduceCompilationSize
commitEssential "$END" "$MONTH" 

#waitGitComplete
echo "[INFO] Wait for GH Pages building pipeline"
sleep 120
for i in $(seq $START $END)
do
	#waitGitComplete
	#git reset "$i/"
	gitCommitByBulk "$i/" $publicGitUsername
done

#waitGitComplete
cd $publicFolderAbs
gitCommitByBulk "categories" $publicGitUsername
gitCommitByBulk "wp-content" $publicGitUsername

gitCommitByBulk "page" $publicGitUsername
gitCommitByBulk "posts/page" $publicGitUsername
# rangeGitAddPush page 1 10 $publicGitUsername 
# rangeGitAddPush "posts/page" 1 10 $publicGitUsername 

waitGitComplete
cd $publicFolderAbs
git add .
git commit -m "Commit all the rest"
git push --set-upstream origin main  --force

echo "The site is updated"
echo "Wait for 60 seconds before notifying the forked sites to update"
sleep 60
syncForkInMirrorGithubAccounts

# Remove last commit
#git reset --hard
#git clean -fd


# Come Back up to the Project Root
