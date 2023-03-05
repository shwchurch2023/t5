#!/bin/bash

# env > ~/.env

if [[ -z "$BASE_PATH" ]];then
    cd "$(dirname "$0")"
    cd ..
    export BASE_PATH=$(pwd)
    source $BASE_PATH/bin/common.sh
fi
# source $BASE_PATH/bin/common.sh
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

	rmSafe "$targetPath" "github.io"
	mkdir -p $targetPath
	
	cd $sourcePath/
	mv * $targetPath
	cd -

	dir=$(echo "$dir" | sed  "s#/mnt/hugo/github/t5/shwchurch[0-9]*.github.io/##g")
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
		find . -type f -name "*.html" -exec sed -i  "$i" {} \; 
	done
	# find . -type f -name "*.html" -exec sed -i  "" {} \;
	# # find . -type f -name "*.html" -exec sed -i  "s#/$dir#https://${toGitRepoName}/$dir#g" {} \;
	# find . -type f -name "*.html" -exec sed -i   {} \;
	# find . -type f -name "*.html" -exec sed -i   {} \;
	# find . -type f -name "*.html" -exec sed -i   {} \;
	
	cd $targetFolder
	gitCommitByBulk $dir $toGitUsername
	isSplitExecute='1'
}

# Commit changes.
# Add changes to git.

for i in $(seq "$startYear" "$endYear")
do
	#git reset "$i/"
	splitFiles "wp-content/uploads/$i"
done
#waitGitComplete

if [[ -z "$isSplitExecute" ]];then 
	exit 3
fi

# Come Back up to the Project Root
cd $BASE_PATH/
