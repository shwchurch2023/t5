#!/bin/zsh

export BASE_PATH=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && cd .. && pwd )

# if [[ -z "$BASE_PATH" ]];then
#     cd "$(dirname "$0")"
#     cd ..
#     export BASE_PATH=$(pwd)
#     source $BASE_PATH/bin/common.sh
# fi
currentUser=$(whoami)

if [[ "${currentUser}" != 'root' ]]; then
    echo "[ERROR] The cron generator should be executed with root/sudo"
    exit 2
fi

cd "$(dirname "$0")"
cd ..

cd $BASE_PATH

cronScriptPath=/etc/cron.d/hugo-sync

hugoGithubRoot=/mnt/hugo/github
syncFile=${BASE_PATH}/bin/sync.sh 
logPath=${hugoGithubRoot}/sync.log

scriptToRun="/bin/bash ${syncFile} > ${logPath} 2>&1"



# sudo useradd -U $hugoUserGroup
sudo chown -R hugo.hugo .
# sudo usermod -a -G $hugoUserGroup $currentUser
sudo chmod -R g+rw $hugoGithubRoot
ls -la $hugoGithubRoot
#echo "1 14 * * * $hugoUserGroup ${scriptToRun}" > ${cronScriptPath}
sudo bash -c "echo \"1 9,19 * * * hugo ${scriptToRun}\" > \"${cronScriptPath}_1\""

#cat ${cronScriptPath}
sudo cat ${cronScriptPath}_1

sudo service crond restart
echo "Crontab restart, new PID: $(pgrep cron)"
echo "sudo tail -f  /var/log/cron*"
