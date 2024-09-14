#!/bin/bash

# env > ~/.env (then remove line with % symbol)
export BASE_PATH=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && cd .. && pwd )

source $BASE_PATH/bin/common-utils.sh

cd $BASE_PATH

is_sync_dead_unexpected=$(is_lock_file_dead_unexpected main_entry_sync)

if [[ ! -z "${is_sync_dead_unexpected}" ]];then
	echo "[$0] sync process dead unexpected. Restart it."
	cd /mnt/hugo; sudo -u hugo zsh -c '/mnt/hugo/github/t5/bin/sync.sh > /mnt/hugo/github/sync.log 2>&1' &
fi
