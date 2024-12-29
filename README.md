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