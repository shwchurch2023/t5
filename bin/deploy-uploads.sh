#!/bin/bash

# env > ~/.env

export BASE_PATH=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && cd .. && pwd )

source $BASE_PATH/bin/common-utils.sh

cd $BASE_PATH

echo -e "\033[0;32mDeploying updates to GitHub...\033[0m"

publicFolder=$1
toGitUsername=$2
startYear=$3
endYear=$4

if [[ -z "$endYear" || "$endYear" =~ "^2" ]]; then
	echo "[ERROR] Parameters are invalide. publicFolder:${publicFolder} toGitUsername=${toGitUsername} startYear=${startYear} endYear=${endYear}"
	exit 1
fi

toGitRepoName=${toGitUsername}.github.io

echo "[INFO] Start moving uploads from $startYear to $endYear from $publicFolder to $toGitRepoName"

addSubmodule $toGitUsername $toGitRepoName

isSplitExecute=''

targetFolder=$BASE_PATH/${toGitRepoName}

splitFiles(){
	dir=$1

	sourcePath=$publicFolderAbs/$dir
	if [[ ! -d "$sourcePath" ]]; then

		echo "[INFO] $sourcePath is not found, skip. "
		continue
	fi

	targetFolder=$BASE_PATH/${toGitRepoName}
	targetPath=$targetFolder/$dir
	echo "[INFO] Split file at path $sourcePath  to $targetPath "
	cd $BASE_PATH

	rmSafe "$targetPath" "github.io" "1"
	mkdir -p $targetPath
	
	cd $sourcePath/
	mv * $targetPath
	cd -

	dir=$(echo "$dir" | sed  "s#/mnt/hugo/github/t5/shwchurch.*.github.io/##g")
	mapping=(
		"s#https://$publicFolder/$dir#https://${toGitRepoName}/$dir#g"
		"s#https://${toGitRepoName}/$dir#/$dir#g"
		"s#/$dir#https://${toGitRepoName}/$dir#g"
		"s#https:https:#https:#g"
	)
	
	for i in "${mapping[@]}"
	do
		echo "[INFO] Replace mapping: $i"
		echo "$i" >> $filePathUrlMappingFilePath
		findAndReplace "$i"
		# find "${find_main_public_site_args}" -type f -name "*.html" -exec sed -i  "$i" {} \; 
	done
	# find . -type f -name "*.html" -exec sed -i  "" {} \;
	# # find . -type f -name "*.html" -exec sed -i  "s#/$dir#https://${toGitRepoName}/$dir#g" {} \;
	# find . -type f -name "*.html" -exec sed -i   {} \;
	# find . -type f -name "*.html" -exec sed -i   {} \;
	# find . -type f -name "*.html" -exec sed -i   {} \;
	
	cd $targetFolder
	CURR_YEAR=$(date +'%Y')
	MONTH=$(date +"%m")

	cp -r ${publicFolderAbs}/index.html ${publicFolderAbs}/404.html ${publicFolderAbs}/config.yaml ${publicFolderAbs}/images ${publicFolderAbs}/js  ${publicFolderAbs}/scss ./ 
	# cp -r ${publicFolderAbs}/${CURR_YEAR}/${MONTH}  ${publicFolderAbs}/wp-content/uploads/${CURR_YEAR}/${MONTH} ./
	gitCommitByBulk $dir $toGitUsername
	isSplitExecute='1'
}

# Commit changes.
# Add changes to git.

findAndReplace_base_step=400
for i in $(seq "$startYear" "$endYear")
do
	#git reset "$i/"
	findAndReplace_base_step=$((findAndReplace_base_step + 2))
	if [[ "$(shouldExecuteStep ${findAndReplace_base_step})" = "true" ]];then
		splitFiles "wp-content/uploads/$i"
	fi
done
#waitGitComplete

if [[ -z "$isSplitExecute" ]];then 
	exit 3
fi

# Come Back up to the Project Root
cd $BASE_PATH/
