#!/bin/bash

. ~/.bashrc

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"


cronScriptPath=/etc/cron.d/hugo-sync

hugoGithubRoot=/home/ec2-user/hugo/github
syncFile=${hugoGithubRoot}/t5/bin/sync.sh 
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
