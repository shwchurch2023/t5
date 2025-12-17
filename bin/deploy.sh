#!/bin/bash

# env > ~/.env
export BASE_PATH=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && cd .. && pwd )

source $BASE_PATH/bin/common-utils.sh
git config --global core.quotePath false
initSubmoduleUsage

cd $BASE_PATH

echo -e "\033[0;32mDeploying updates to GitHub...\033[0m"

stopDeployIfRequested(){
	local step_label=$1
	if shouldStopAfterStep "${findAndReplace_base_step}" "${step_label}"; then
		echo "[$0] Stop requested after step ${findAndReplace_base_step}. Exit deploy.sh"
		executeStepAllDone
		exit 0
	fi
}

findAndReplace_base_step=200
stopDeployIfRequested "start"

#echo "[INFO] Reset repo to remote origin to prevent big failure commit"
##git status
##git fetch origin
##git reset --hard origin/main

findAndReplace_base_step=$((findAndReplace_base_step + 10))
stopDeployIfRequested "sync_podcast"
if [[ "$(shouldExecuteStep ${findAndReplace_base_step} sync_podcast)" = "true" ]];then
	echo "[INFO] Sync podcast"
	syncPodcast
fi

# Build the project.
echo "[INFO] hugo minify for t5/content to t5/$publicFolder"

findAndReplace_base_step=$((findAndReplace_base_step + 10))
stopDeployIfRequested "hugoBuild"
if [[ "$(shouldExecuteStep ${findAndReplace_base_step} hugoBuild)" = "true" ]];then
	hugoBuild
	if [[ "$?" != "0" ]];then
		echo "[WARN] Hugo Build failed; Continue since the failure may be just for some posts"
	fi
fi

ensureRequiredFolder $hugoPublicFolderAbs

publicFolderIndexHtml="$publicFolderAbs/index.html"

cd $BASE_PATH

findAndReplace_base_step=$((findAndReplace_base_step + 10))
stopDeployIfRequested "clean_public_folder"
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
stopDeployIfRequested "moving_hugo_to_public_folder"
if [[ "$(shouldExecuteStep ${findAndReplace_base_step} moving_hugo_to_public_folder)" = "true" ]];then
	mv -v -f $hugoPublicFolderAbs/* $publicFolderAbs/
	if [[ "$?" != "0" || ! -f "${publicFolderIndexHtml}" ]];then
		echo "[ERROR] Failed on moving files in $hugoPublicFolderAbs to $publicFolderAbs/; Exit 1"
		ls $publicFolderAbs
		exit 1
	fi

fi

cd $publicFolderAbs
echo "Content of [$publicFolderAbs]"
ls

findAndReplace_base_step=$((findAndReplace_base_step + 10))
stopDeployIfRequested "update_domain"
if [[ "$(shouldExecuteStep ${findAndReplace_base_step} update_shwchurch_N_with_$publicGitUsername )" = "true" ]];then
	echo "Update domain to https://$publicFolder"
	findAndReplace "s/shwchurch[[:digit:]]+/$publicGitUsername/g"
fi

# find "${find_main_public_site_args}" -type f -name "*.html" -exec sed -i  "s/shwchurch[[:digit:]]\+/$publicGitUsername/g" {} \;

cd $BASE_PATH
export START=2005
export END=$(date +'%Y')
export MONTH=$(date +"%m")

findAndReplace_base_step=290
stopDeployIfRequested "commitEssentialAndUpdateManualStart"

# commitEssentialAndUpdateManualStart $findAndReplace_base_step
commitEssentialAndUpdateManualStart

findAndReplace_base_step=300
stopDeployIfRequested "post_commitEssential"

findAndReplace_base_step=$((findAndReplace_base_step + 100))
stopDeployIfRequested "apply_distributions"

# if [[ "$(shouldExecuteStep ${findAndReplace_base_step} first_commit_essential)" = "true" ]];then

# 	echo "[INFO] Apply path mapping from"
# 	applyDistributionMapping $findAndReplace_base_step
	
# 	findAndReplace_base_step=$((findAndReplace_base_step + 100))
# 	applyManualDistributionMapping $findAndReplace_base_step
# 	commitEssential "$END" "$MONTH" 
	
# fi


findAndReplace_base_step=500
stopDeployIfRequested "clean_up_url_mapping_file"
if [[ "$(shouldExecuteStep ${findAndReplace_base_step} clean_up_url_mapping_file)" = "true" ]];then
	echo "[INFO] Remove $filePathUrlMappingFilePath"
	rmSafe "$filePathUrlMappingFilePath" "t5" "true"
	touch "$filePathUrlMappingFilePath"
	echo "" > "$filePathUrlMappingFilePath"
fi

cd $BASE_PATH
findAndReplace_base_step=800
stopDeployIfRequested "deploy_uploads_part1"

error_on_deploy_uploads=""

./bin/deploy-uploads.sh "$publicFolder" "$uploadsGitUsername1" "${githubSplitPart_uploadsGitUsername1From}" "$((githubSplitPart_uploadsGitUsername2From-1))" $findAndReplace_base_step

if [[ "$?" != "0" ]];then
	error_on_deploy_uploads="[ Error $uploadsGitUsername1  ${githubSplitPart_uploadsGitUsername1From} $((githubSplitPart_uploadsGitUsername2From-1)) ] "
fi

# ensureNoErrorOnChildProcess "$?" "Deploy for $uploadsGitUsername1 from year ${githubSplitPart_uploadsGitUsername1From}"

cd $BASE_PATH
findAndReplace_base_step=1200
stopDeployIfRequested "deploy_uploads_part2"
./bin/deploy-uploads.sh "$publicFolder" "$uploadsGitUsername2" "${githubSplitPart_uploadsGitUsername2From}" "$((githubSplitPart_uploadsGitUsername3From-1))" $findAndReplace_base_step
# ensureNoErrorOnChildProcess "$?" "Deploy for $uploadsGitUsername2 from year ${githubSplitPart_uploadsGitUsername2From}"
if [[ "$?" != "0" ]];then
	error_on_deploy_uploads="${error_on_deploy_uploads} | [ Error $uploadsGitUsername2  ${githubSplitPart_uploadsGitUsername2From} $((githubSplitPart_uploadsGitUsername3From-1)) ] "
fi


cd $BASE_PATH
findAndReplace_base_step=1600
stopDeployIfRequested "deploy_uploads_part3"
./bin/deploy-uploads.sh "$publicFolder" "$uploadsGitUsername3" "${githubSplitPart_uploadsGitUsername3From}" "$((currYear-1))" $findAndReplace_base_step
# ensureNoErrorOnChildProcess "$?" "Deploy for $uploadsGitUsername3 from year ${githubSplitPart_uploadsGitUsername3From}"
if [[ "$?" != "0" ]];then
	error_on_deploy_uploads="${error_on_deploy_uploads} | [ Error $uploadsGitUsername3  ${githubSplitPart_uploadsGitUsername3From} $((currYear-1)) ] "
fi


findAndReplace_base_step=8000
stopDeployIfRequested "publish_to_github"

echo "[INFO] Publish content to GithubPage https://$publicFolder"

# Commit changes.
# Add changes to git.
findAndReplace_base_step=$((findAndReplace_base_step + 10))
stopDeployIfRequested "reduceCompilationSize"

if [[ "$(shouldExecuteStep ${findAndReplace_base_step} reduceCompilationSize )" = "true" ]];then
	reduceCompilationSize
fi

findAndReplace_base_step=$((findAndReplace_base_step + 2))
stopDeployIfRequested "commitEssentialAndUpdateManualStart_2"
# commitEssentialAndUpdateManualStart $findAndReplace_base_step
commitEssentialAndUpdateManualStart 

findAndReplace_base_step=$((findAndReplace_base_step + 10))
stopDeployIfRequested "sync_fork_mirrors_wait"
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
	stopDeployIfRequested "commit_folder_$i"
	if [[ "$(shouldExecuteStep ${findAndReplace_base_step} commit_folder_$i )" = "true" ]];then
		gitCommitByBulk "$i/" $publicGitUsername
	fi
done

#waitGitComplete
cd $publicFolderAbs
findAndReplace_base_step=$((findAndReplace_base_step + 10))
stopDeployIfRequested "commit_categories_wp_content"
if [[ "$(shouldExecuteStep ${findAndReplace_base_step} commit_categories_wp_content )" = "true" ]];then
	gitCommitByBulk "categories" $publicGitUsername
	if [[ -z "${error_on_deploy_uploads}" ]];then
		gitCommitByBulk "wp-content" $publicGitUsername
	else
		echo "Skipped on committing [wp-content] to $publicGitUsername as previous error found [${error_on_deploy_uploads}]"
		
	fi
fi

findAndReplace_base_step=$((findAndReplace_base_step + 10))
stopDeployIfRequested "commit_pages_posts"
if [[ "$(shouldExecuteStep ${findAndReplace_base_step} commit_pages_posts)" = "true" ]];then
	gitCommitByBulk "page" $publicGitUsername
	gitCommitByBulk "posts/page" $publicGitUsername
fi
# rangeGitAddPush page 1 10 $publicGitUsername 
# rangeGitAddPush "posts/page" 1 10 $publicGitUsername 

waitGitComplete
cd $publicFolderAbs
findAndReplace_base_step=$((findAndReplace_base_step + 10))
stopDeployIfRequested "commit_all_rest"
if [[ -z "${error_on_deploy_uploads}" ]];then
	if [[ "$(shouldExecuteStep ${findAndReplace_base_step} commit_all_rest)" = "true" ]];then
		git add .
		git commit -m "Commit all the rest"
		git push --set-upstream origin main  --force

		echo "The site is updated"
		echo "Wait for 60 seconds before notifying the forked sites to update"
		sleep 60
	fi
else

	echo "Skipped on committing [all the rest] to $publicGitUsername as previous error found [${error_on_deploy_uploads}]"
		
fi

findAndReplace_base_step=$((findAndReplace_base_step + 10))
stopDeployIfRequested "sync_fork_mirrors_2"
if [[ "$(shouldExecuteStep ${findAndReplace_base_step} sync_fork_mirrors_2)" = "true" ]];then
	syncForkInMirrorGithubAccounts
fi

helpCleanSubmodules

executeStepAllDone

if [[ ! -z "${error_on_deploy_uploads}" ]]; then
	echo "[$0] Deploy Error: ${error_on_deploy_uploads}"
	exit 1
fi

# Remove last commit
#git reset --hard
#git clean -fd


# Come Back up to the Project Root
