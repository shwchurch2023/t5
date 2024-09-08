#!/bin/bash

# env > ~/.env
export BASE_PATH=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && cd .. && pwd )

source $BASE_PATH/bin/common-utils.sh
git config --global core.quotePath false
initSubmoduleUsage

cd $BASE_PATH

echo -e "\033[0;32mDeploying updates to GitHub...\033[0m"

findAndReplace_base_step=200

#echo "[INFO] Reset repo to remote origin to prevent big failure commit"
##git status
##git fetch origin
##git reset --hard origin/main

findAndReplace_base_step=$((findAndReplace_base_step + 10))
if [[ "$(shouldExecuteStep ${findAndReplace_base_step})" = "true" ]];then
	echo "[INFO] Sync podcast"
	syncPodcast
fi

# Build the project.
echo "[INFO] hugo minify for t5/content to t5/$publicFolder"

findAndReplace_base_step=$((findAndReplace_base_step + 10))
if [[ "$(shouldExecuteStep ${findAndReplace_base_step})" = "true" ]];then
	hugoBuild
fi

ensureRequiredFolder $hugoPublicFolderAbs

publicFolderIndexHtml="$publicFolderAbs/index.html"

cd $BASE_PATH

findAndReplace_base_step=$((findAndReplace_base_step + 10))
if [[ "$(shouldExecuteStep ${findAndReplace_base_step})" = "true" ]];then
	
	addSubmodule $publicGitUsername $publicFolder
	ensureRequiredFolder $publicFolderAbs

	cd $publicFolderAbs
	rmSafe "./*" "github.io"
fi

if [[ -f "${publicFolderIndexHtml}" ]];then
	echo "[ERROR] $publicFolderIndexHtml should be cleared"
	exit 1
fi

cd $BASE_PATH

findAndReplace_base_step=$((findAndReplace_base_step + 10))
if [[ "$(shouldExecuteStep ${findAndReplace_base_step})" = "true" ]];then
	mv -v -f $hugoPublicFolderAbs/* $publicFolderAbs/
	if [[ "$?" != "0" || ! -f "${publicFolderIndexHtml}" ]];then
		echo "[ERROR] Failed on moving files in $hugoPublicFolderAbs to $publicFolderAbs/ "
		ls $publicFolderAbs
		exit 1
	fi

fi

cd $publicFolderAbs
findAndReplace_base_step=$((findAndReplace_base_step + 10))
if [[ "$(shouldExecuteStep ${findAndReplace_base_step})" = "true" ]];then
	echo "Update domain to https://$publicFolder"
	findAndReplace "s/shwchurch[[:digit:]]+/$publicGitUsername/g"
fi

# find "${find_main_public_site_args}" -type f -name "*.html" -exec sed -i  "s/shwchurch[[:digit:]]\+/$publicGitUsername/g" {} \;

cd $BASE_PATH
START=2005
END=$(date +'%Y')
MONTH=$(date +"%m")

findAndReplace_base_step=$((findAndReplace_base_step + 10))
if [[ "$(shouldExecuteStep ${findAndReplace_base_step})" = "true" ]];then

	echo "[INFO] Apply path mapping from"
	applyDistributionMapping
	applyManualDistributionMapping
	commitEssential "$END" "$MONTH" 
fi

findAndReplace_base_step=$((findAndReplace_base_step + 10))
if [[ "$(shouldExecuteStep ${findAndReplace_base_step})" = "true" ]];then
	echo "[INFO] Remove $filePathUrlMappingFilePath"
	rmSafe "$filePathUrlMappingFilePath" "t5" "true"
	touch "$filePathUrlMappingFilePath"
	echo "" > "$filePathUrlMappingFilePath"
fi

cd $BASE_PATH

./bin/deploy-uploads.sh "$publicFolder" "$uploadsGitUsername1" "${githubSplitPart1From}" "$((githubSplitPart2From-1))"
ensureNoErrorOnChildProcess "$?"
cd $BASE_PATH
./bin/deploy-uploads.sh "$publicFolder" "$uploadsGitUsername2" "${githubSplitPart2From}" "$((currYear-1))"
ensureNoErrorOnChildProcess "$?"

findAndReplace_base_step=600

echo "[INFO] Publish content to GithubPage https://$publicFolder"

# Commit changes.
# Add changes to git.
findAndReplace_base_step=$((findAndReplace_base_step + 10))
if [[ "$(shouldExecuteStep ${findAndReplace_base_step})" = "true" ]];then
	reduceCompilationSize
	applyManualDistributionMapping
	commitEssential "$END" "$MONTH" 
fi

findAndReplace_base_step=$((findAndReplace_base_step + 10))
if [[ "$(shouldExecuteStep ${findAndReplace_base_step})" = "true" ]];then
	syncForkInMirrorGithubAccounts
fi

#waitGitComplete
echo "[INFO] Wait for GH Pages building pipeline"
sleep 120
for i in $(seq $START $END)
do
	#waitGitComplete
	#git reset "$i/"

	findAndReplace_base_step=$((findAndReplace_base_step + 2))
	if [[ "$(shouldExecuteStep ${findAndReplace_base_step})" = "true" ]];then
		gitCommitByBulk "$i/" $publicGitUsername
	fi
done

#waitGitComplete
cd $publicFolderAbs
findAndReplace_base_step=$((findAndReplace_base_step + 10))
if [[ "$(shouldExecuteStep ${findAndReplace_base_step})" = "true" ]];then
	gitCommitByBulk "categories" $publicGitUsername
	gitCommitByBulk "wp-content" $publicGitUsername
fi

findAndReplace_base_step=$((findAndReplace_base_step + 10))
if [[ "$(shouldExecuteStep ${findAndReplace_base_step})" = "true" ]];then
	gitCommitByBulk "page" $publicGitUsername
	gitCommitByBulk "posts/page" $publicGitUsername
fi
# rangeGitAddPush page 1 10 $publicGitUsername 
# rangeGitAddPush "posts/page" 1 10 $publicGitUsername 

waitGitComplete
cd $publicFolderAbs
findAndReplace_base_step=$((findAndReplace_base_step + 10))
if [[ "$(shouldExecuteStep ${findAndReplace_base_step})" = "true" ]];then
	git add .
	git commit -m "Commit all the rest"
	git push --set-upstream origin main  --force

	echo "The site is updated"
	echo "Wait for 60 seconds before notifying the forked sites to update"
	sleep 60
fi

findAndReplace_base_step=$((findAndReplace_base_step + 10))
if [[ "$(shouldExecuteStep ${findAndReplace_base_step})" = "true" ]];then
	syncForkInMirrorGithubAccounts
fi

helpCleanSubmodules

executeStepAllDone

# Remove last commit
#git reset --hard
#git clean -fd


# Come Back up to the Project Root
