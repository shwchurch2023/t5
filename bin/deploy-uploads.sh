#!/bin/bash

# env > ~/.env
#export $(cat /home/ec2-user/.env | sed 's/#.*//g' | xargs)
if [[ -z "$BASE_PATH" ]];then
 export BASE_PATH=$(pwd)
 source $BASE_PATH/bin/common.sh
fi
cd $BASE_PATH

echo -e "\033[0;32mDeploying updates to GitHub...\033[0m"

publicFolder=$1
toGitUsername=$2
startYear=$3
endYear=$4

toGitRepoName=${toGitUsername}.github.io

addSubmodule $toGitUsername $toGitRepoName

splitFiles(){
	dir=$1
	sourcePath=$BASE_PATH/$publicFolder/$dir
	targetFolder=$BASE_PATH/${toGitRepoName}
	targetPath=$targetFolder/$dir
	echo "[INFO] Split file at path $sourcePath  to $targetPath "
	cd $BASE_PATH
	pwd

	rmSafe "$targetPath" "github.io"
	mkdir -p $targetPath
	mv $sourcePath/* $targetPath
	find . -type f -name "*.html" -exec sed -i  "s#/$dir#https://${toGitRepoName}/$dir#g" {} \;
	find . -type f -name "*.html" -exec sed -i  "s#https:https:#https:#g" {} \;
	cd $targetFolder
	pwd
	gitCommitByBulk $dir $toGitUsername
}

# Commit changes.
# Add changes to git.

for i in $(seq $startYear $endYear)
do
	#git reset "$i/"
	splitFiles "wp-content/uploads/$i"
done
#waitGitComplete

# Come Back up to the Project Root
cd $BASE_PATH/
