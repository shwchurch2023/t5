# Shouwang Church website kits

## Development website in macOS with Hugo

- Rename `./content.sample` to `./content`

- Init
```zsh
brew install hugo
```
- Generate and watch file changes with a simple static web server static html

```zsh
hugo server  
open http://localhost:1313
```

- debug 
 - normal change
```sh
 sudo -u hugo zsh -c 'cd /mnt/hugo/github/t5; git pull; git submodule update --recursive'; ps aux | grep -E 'sync|php' | grep -v www | grep -v fpm | grep -v grep | awk '{print $2}' | xargs -I{} sudo kill -9 {};

sudo -u hugo zsh -c 'HUGO_SYNC_FORCE=1 HUGO_SYNC_DEPLOY_END_STEP=290 RUN_ID=$(date +%s)-sync /bin/bash /mnt/hugo/github/t5/bin/sync.sh "$RUN_ID" > /mnt/hugo/github/sync.log 2>&1' > /dev/null 2>&1 &; tail -f /mnt/hugo/github/sync.log

```
 - incremental change
```sh
 sudo -u hugo zsh -c 'cd /mnt/hugo/github/t5; git pull; git submodule update --recursive'; ps aux | grep -E 'sync|php' | grep -v www | grep -v fpm | grep -v grep | awk '{print $2}' | xargs -I{} sudo kill -9 {};

sudo -u hugo zsh -c 'HUGO_SYNC_FORCE=1 HUGO_SYNC_INCREMENTAL=1 HUGO_SYNC_DEPLOY_END_STEP=290 RUN_ID=$(date +%s)-sync /bin/bash /mnt/hugo/github/t5/bin/sync.sh "$RUN_ID" > /mnt/hugo/github/sync.log 2>&1' > /dev/null 2>&1 &; tail -f /mnt/hugo/github/sync.log

```
- crontab change 
```sh
cd /mnt/hugo/github/t5; sudo ./bin/cron-sync.sh
```
- php change
```sh
 sudo -u hugo zsh -c 'cd /mnt/hugo/github/t5; git pull; git submodule update --recursive'; ps aux | grep -E 'sync|php' | grep -v www | grep -v fpm | grep -v grep | awk '{print $2}' | xargs -I{} sudo kill -9 {};

cd /mnt/hugo/github/t5
sudo rsync -a --exclude='.git/' "wordpress-to-hugo-exporter/" "/mnt/data/shwchurch/web/wp-content/plugins/wordpress-to-hugo-exporter/"
sudo chown -R hugo:hugo /mnt/data/shwchurch/web/wp-content/plugins/  

sudo -u hugo zsh -c 'HUGO_SYNC_FORCE=1 HUGO_SYNC_INCREMENTAL=1 HUGO_SYNC_DEPLOY_END_STEP=290 RUN_ID=$(date +%s)-sync /bin/bash /mnt/hugo/github/t5/bin/sync.sh "$RUN_ID" > /mnt/hugo/github/sync.log 2>&1' > /dev/null 2>&1 &; tail -f /mnt/hugo/github/sync.log
```

## Yearly tasks
- Should update the forked https://github.com/shwchurch2023/hugo-theme-stack from source to fix any issues

## Linux: Switch SSH key
```zsh
source ./bin/common-utils.sh
useSSHKey shwchurch2023
```

## Change the main site
* Fork this repo to the new Github account
* SSH to t5 (sw)
* `sudo su hugo`
* `cd /mnt/hugo/github/t5`
* `source ./bin/common.sh`
* `addNewGithubAccountAsMirror NEW_GITHUB_USERNAME NEW_GITHUB_TOKEN`

## For migration AWS EC2 to new version
[./migrate-aws](./migrate-aws/README.md)

## Homebrew

```sh

sudo yum groupinstall "Development Tools" -y
sudo yum install curl file git procps-ng -y

NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

brew install glibc patchelf

```

## Other SOPs

[./README-SOP](./README-SOP.md)