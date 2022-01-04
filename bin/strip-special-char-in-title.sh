#!/bin/bash

echo "[INFO] Replace all special chars in Title"

cd /mnt/hugo/github/t5/content/posts

declare -a SpecialCharsInTitle=(
	'@::＠'
)

for SpecialChar in "${SpecialCharsInTitle[@]}"; do 
	KEY="${SpecialChar%%::*}"
    	VALUE="${SpecialChar##*::}"
	pattern="s#${KEY}#${VALUE}#g"
	find . -type f -name "*.md" -exec sed -i "${pattern}" {} \;
done
