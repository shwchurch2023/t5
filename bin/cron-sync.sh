#!/bin/bash


if [[ -z "$BASE_PATH" ]];then
    cd "$(dirname "$0")"
    cd ..
    export BASE_PATH=$(pwd)
    source $BASE_PATH/bin/common.sh
fi

cd $BASE_PATH

cronScriptPath=/etc/cron.d/hugo-sync

hugoGithubRoot=/mnt/hugo/github
syncFile=${BASE_PATH}/bin/sync.sh 
logPath=${hugoGithubRoot}/sync.log

scriptToRun="/bin/bash ${syncFile} > ${logPath} 2>&1"

currentUser=$(whoami)
hugoUserGroup=hugo
sudo useradd -U $hugoUserGroup
sudo chown -R $hugoUserGroup.$hugoUserGroup .
sudo usermod -a -G $hugoUserGroup $currentUser
sudo chmod -R g+rw $hugoGithubRoot
ls -la $hugoGithubRoot
#echo "1 14 * * * $hugoUserGroup ${scriptToRun}" > ${cronScriptPath}
sudo bash -c "echo \"1 19 * * 5,6 $hugoUserGroup ${scriptToRun}\" > \"${cronScriptPath}_1\""

#cat ${cronScriptPath}
sudo cat ${cronScriptPath}_1

sudo service crond restart
echo "Crontab restart, new PID: $(pgrep cron)"
echo "sudo tail -f  /var/log/cron*"
