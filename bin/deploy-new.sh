#!/bin/bash

# env > ~/.env
export $(cat /home/ec2-user/.env | sed 's/#.*//g' | xargs)

set -o xtrace

echo -e "\033[0;32mDeploying updates to GitHub...\033[0m"


cd "$(dirname "$0")"

cd ..

cd public
timestamp=$(date +%s)
tmpGit=".git_${timestamp}"
mv .git $tmpGit
mv $tmpGit ../../
git init
git remote add origin git@github.com:shwchurch3/shwchurch3.github.io.git
cd ../bin
./deploy.sh
#rm -rf .git
#mv ../../$tmpGit ./
#mv $tmpGit .git

