#!/bin/bash

export BASE_PATH=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && cd .. && pwd )

source $BASE_PATH/bin/common-utils.sh

echo "[INFO] Stripping all links including special chars"

cd $BASE_PATH/content/posts

echo "" > special-chars.txt 
echo "" > special-chars-shorted.txt 

grep -iRl "^url: /20" ./ | xargs cat | grep "^url: " | sed 's/url: //' >> special-chars.txt 2>/dev/null

declare -a SpecialChars=(
	"　" 
	"。" 
	"，" 
	"-" 
	"—" 
	"——" 
	"－－" 
	" " 
	"”" 
	"“" 
	"”" 
	"？" 
	"：" 
	"！" 
	"_" 
	"（" 
	"）" 
	"《" 
	"》" 
	"•" 
	"、" 
	"：" 
	"、" 
	"："
)

while IFS='' read -r line || [[ -n "$line" ]]; do

	escapedLine=${line}

	for SpecialChar in "${SpecialChars[@]}"; do
		#escapedLine=$(printf '%s\n' "${escapedLine//${SpecialChar}/}")
		escapedLine=$(echo ${escapedLine} | sed "s/${SpecialChar}//g")
	done

	echo ${escapedLine}

	if [[ ! -z "${escapedLine}" && "${escapedLine}" != "${line}" ]]; then

		pattern="s#${line}#${escapedLine}#g"
		echo "${pattern}" >> ./special-chars-shorted.txt
		echo "[INFO] ${pattern}"

		findAndReplace "${pattern}" "." "*.md" >/dev/null 2>&1
		# find . "${find_not_hidden_args}" -type f -name "*.md" -exec sed -i "${pattern}" {} \; >/dev/null 2>&1
	fi
	
    
done < "./special-chars.txt"

