#!/bin/zsh
echo "ls /tmp | grep t5_"
ls /tmp | grep t5_ | xargs -I{} echo "sudo rm /tmp/{}"

echo "source /mnt/hugo/github/t5/bin/common-utils.sh; useSSHKey shwchurch3; git pull"

echo 'cd /mnt/data/shwchurch/backup/; ls'
(cd /mnt/data/shwchurch/backup/; ls)

echo "(sudo rm /tmp/t5_shouldExecuteStep_step; sudo chown -R hugo.hugo /mnt/hugo/github/t5; cd /mnt/hugo; sudo -u hugo zsh -c 'export HUGO_SYNC_FORCE=1; /mnt/hugo/github/t5/bin/sync.sh > /mnt/hugo/github/sync.log 2>&1' &); tail -f /mnt/hugo/github/sync.log"
echo "(sudo rm /tmp/t5_shouldExecuteStep_step; sudo chown -R hugo.hugo /mnt/hugo/github/t5; cd /mnt/hugo; sudo -u hugo zsh -c '/mnt/hugo/github/t5/bin/deploy.sh > /mnt/hugo/github/deploy-manual.log 2>&1' &); tail -f /mnt/hugo/github/deploy-manual.log"
echo "(cd /mnt/hugo; sudo -u hugo zsh -c '(source /mnt/hugo/github/t5/bin/common-utils.sh; commitEssentialAndUpdateManualStart) > /mnt/hugo/github/deploy-essential-manual.log 2>&1' &); tail -f /mnt/hugo/github/deploy-essential-manual.log"
. "/home/ec2-user/.acme.sh/acme.sh.env"

export $(cat /mnt/hugo/github/t5/.env | xargs)
export MAIL_SH=/mnt/hugo/github/t5/bin/mail.sh
export PATH=$PATH:/snap/bin