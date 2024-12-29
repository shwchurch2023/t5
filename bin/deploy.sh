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
if [[ "$(shouldExecuteStep ${findAndReplace_base_step} sync_podcast)" = "true" ]];then
	echo "[INFO] Sync podcast"
	syncPodcast
fi

# Build the project.
echo "[INFO] hugo minify for t5/content to t5/$publicFolder"

findAndReplace_base_step=$((findAndReplace_base_step + 10))
if [[ "$(shouldExecuteStep ${findAndReplace_base_step} hugoBuild)" = "true" ]];then
	hugoBuild
fi

ensureRequiredFolder $hugoPublicFolderAbs

publicFolderIndexHtml="$publicFolderAbs/index.html"

cd $BASE_PATH

findAndReplace_base_step=$((findAndReplace_base_step + 10))
if [[ "$(shouldExecuteStep ${findAndReplace_base_step} clean_public_folder)" = "true" ]];then
	
	addSubmodule $publicGitUsername $publicFolder
	ensureRequiredFolder $publicFolderAbs

	cd $publicFolderAbs
	rmSafe "./*" "github.io"
	if [[ -f "${publicFolderIndexHtml}" ]];then
		echo "[ERROR] $publicFolderIndexHtml should be cleared"
		exit 1
	fi
fi


cd $BASE_PATH

findAndReplace_base_step=$((findAndReplace_base_step + 10))
if [[ "$(shouldExecuteStep ${findAndReplace_base_step} moving_hugo_to_public_folder)" = "true" ]];then
	mv -v -f $hugoPublicFolderAbs/* $publicFolderAbs/
	if [[ "$?" != "0" || ! -f "${publicFolderIndexHtml}" ]];then
		echo "[ERROR] Failed on moving files in $hugoPublicFolderAbs to $publicFolderAbs/; Exit 1"
		ls $publicFolderAbs
		exit 1
	fi

fi

cd $publicFolderAbs
findAndReplace_base_step=$((findAndReplace_base_step + 10))
if [[ "$(shouldExecuteStep ${findAndReplace_base_step} update_shwchurch_N_with_$publicGitUsername )" = "true" ]];then
	echo "Update domain to https://$publicFolder"
	findAndReplace "s/shwchurch[[:digit:]]+/$publicGitUsername/g"
fi

# find "${find_main_public_site_args}" -type f -name "*.html" -exec sed -i  "s/shwchurch[[:digit:]]\+/$publicGitUsername/g" {} \;

cd $BASE_PATH
START=2005
END=$(date +'%Y')
MONTH=$(date +"%m")

findAndReplace_base_step=300

# commitEssentialAndUpdateManualStart $findAndReplace_base_step
commitEssentialAndUpdateManualStart

findAndReplace_base_step=$((findAndReplace_base_step + 100))

# if [[ "$(shouldExecuteStep ${findAndReplace_base_step} first_commit_essential)" = "true" ]];then

# 	echo "[INFO] Apply path mapping from"
# 	applyDistributionMapping $findAndReplace_base_step
	
# 	findAndReplace_base_step=$((findAndReplace_base_step + 100))
# 	applyManualDistributionMapping $findAndReplace_base_step
# 	commitEssential "$END" "$MONTH" 
	
# fi


findAndReplace_base_step=500
if [[ "$(shouldExecuteStep ${findAndReplace_base_step} clean_up_url_mapping_file)" = "true" ]];then
	echo "[INFO] Remove $filePathUrlMappingFilePath"
	rmSafe "$filePathUrlMappingFilePath" "t5" "true"
	touch "$filePathUrlMappingFilePath"
	echo "" > "$filePathUrlMappingFilePath"
fi

cd $BASE_PATH
findAndReplace_base_step=800
./bin/deploy-uploads.sh "$publicFolder" "$uploadsGitUsername1" "${githubSplitPart1From}" "$((githubSplitPart2From-1))" $findAndReplace_base_step
ensureNoErrorOnChildProcess "$?" "Deploy for $uploadsGitUsername1 from year ${githubSplitPart1From}"

cd $BASE_PATH
findAndReplace_base_step=1200
./bin/deploy-uploads.sh "$publicFolder" "$uploadsGitUsername2" "${githubSplitPart2From}" "$((currYear-1))" $findAndReplace_base_step
ensureNoErrorOnChildProcess "$?" "Deploy for $uploadsGitUsername1 from year ${githubSplitPart2From}"

findAndReplace_base_step=1600

echo "[INFO] Publish content to GithubPage https://$publicFolder"

# Commit changes.
# Add changes to git.
findAndReplace_base_step=$((findAndReplace_base_step + 10))

if [[ "$(shouldExecuteStep ${findAndReplace_base_step} reduceCompilationSize )" = "true" ]];then
	reduceCompilationSize
fi

findAndReplace_base_step=$((findAndReplace_base_step + 2))
# commitEssentialAndUpdateManualStart $findAndReplace_base_step
commitEssentialAndUpdateManualStart 

findAndReplace_base_step=$((findAndReplace_base_step + 10))
# if [[ "$(shouldExecuteStep ${findAndReplace_base_step} sync_fork_mirrors_1 )" = "true" ]];then
# 	syncForkInMirrorGithubAccounts
# fi

#waitGitComplete
echo "[INFO] Wait for GH Pages building pipeline"
sleep 120
echo "[INFO] Done waiting for GH Pages building pipeline"
for i in $(seq $START $END)
do
	#waitGitComplete
	#git reset "$i/"

	findAndReplace_base_step=$((findAndReplace_base_step + 2))
	if [[ "$(shouldExecuteStep ${findAndReplace_base_step} commit_folder_$i )" = "true" ]];then
		gitCommitByBulk "$i/" $publicGitUsername
	fi
done

#waitGitComplete
cd $publicFolderAbs
findAndReplace_base_step=$((findAndReplace_base_step + 10))
if [[ "$(shouldExecuteStep ${findAndReplace_base_step} commit_categories_wp_content )" = "true" ]];then
	gitCommitByBulk "categories" $publicGitUsername
	gitCommitByBulk "wp-content" $publicGitUsername
fi

findAndReplace_base_step=$((findAndReplace_base_step + 10))
if [[ "$(shouldExecuteStep ${findAndReplace_base_step} commit_pages_posts)" = "true" ]];then
	gitCommitByBulk "page" $publicGitUsername
	gitCommitByBulk "posts/page" $publicGitUsername
fi
# rangeGitAddPush page 1 10 $publicGitUsername 
# rangeGitAddPush "posts/page" 1 10 $publicGitUsername 

waitGitComplete
cd $publicFolderAbs
findAndReplace_base_step=$((findAndReplace_base_step + 10))
if [[ "$(shouldExecuteStep ${findAndReplace_base_step} commit_all_rest)" = "true" ]];then
	git add .
	git commit -m "Commit all the rest"
	git push --set-upstream origin main  --force

	echo "The site is updated"
	echo "Wait for 60 seconds before notifying the forked sites to update"
	sleep 60
fi

findAndReplace_base_step=$((findAndReplace_base_step + 10))
if [[ "$(shouldExecuteStep ${findAndReplace_base_step} sync_fork_mirrors_2)" = "true" ]];then
	syncForkInMirrorGithubAccounts
fi

helpCleanSubmodules

executeStepAllDone

# Remove last commit
#git reset --hard
#git clean -fd


# Come Back up to the Project Root
