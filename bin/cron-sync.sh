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
cronScriptPath1=/etc/cron.d/hugo-sync-monitor

hugoGithubRoot=/mnt/hugo/github
syncFile=${BASE_PATH}/bin/sync.sh 
syncMonitorFile=${BASE_PATH}/bin/sync-monitor.sh 
logPath=${hugoGithubRoot}/sync.log
logPath1=${hugoGithubRoot}/sync-monitor.log

scriptToRun="/bin/bash ${syncFile} > ${logPath} 2>&1"
scriptToRun1="/bin/bash ${syncMonitorFile} > ${logPath1} 2>&1"



# sudo useradd -U $hugoUserGroup
sudo chown -R hugo.hugo .
# sudo usermod -a -G $hugoUserGroup $currentUser
sudo chmod -R g+rw $hugoGithubRoot
ls -la $hugoGithubRoot
#echo "1 14 * * * $hugoUserGroup ${scriptToRun}" > ${cronScriptPath}
sudo bash -c "cat <<EOF > \"${cronScriptPath}_1\"
1 0,6,12,18 * * 1,2,4 hugo ${scriptToRun}
1 0,6,12,18 * * 3 hugo HUGO_SYNC_FORCE=1 ${scriptToRun}
1 * * * 5,6,0 hugo flock -n /tmp/hugo-sync-weekend.lock -c \"HUGO_SYNC_DEPLOY_END_STEP=290 ${scriptToRun}\"
EOF"
sudo bash -c "echo \"*/5 * * * * hugo ${scriptToRun1}\" > \"${cronScriptPath1}_1\""

#cat ${cronScriptPath}
sudo cat ${cronScriptPath}_1
sudo cat ${cronScriptPath1}_1

sudo service crond restart
echo "Crontab restart, new PID: $(pgrep cron)"
echo "sudo tail -f  /var/log/cron*"
