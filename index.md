# Test

Set HUGO_SYNC_FORCE to non-empty value to force sync
`sudo -u hugo zsh`
```zsh
# zsh with hugo
(HUGO_SYNC_FORCE=1 ./bin/sync.sh > ../sync.log 2>&1 &); tail -f ../sync.log
```