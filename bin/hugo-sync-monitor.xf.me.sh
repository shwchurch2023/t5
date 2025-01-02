#!/bin/bash

. ./export-env.sh

main=https://t5.shwchurch.org/
mainXpath='//*[@id="main_sermon_hover"]/section/article[1]/h2/a/text()'
target=https://shwchurch2023.github.io/categories/%E8%AE%B2%E9%81%93/
# targetXpath='(//div[contains(@class,"l-title")]/a/text())[1]'
targetXpath='(//main/section/article[1]/a//h2/text())[1]'
#title=$(curl ${main} |  xmllint  --format  --html --xpath '//*[@id="main_sermon_hover"]/section/article[1]/h2/a/text()'   -)

getTitle(){
	domain=$1
	xpath=$2
	cmd="/root/anaconda3/bin/curl ${domain} |  /root/anaconda3/bin/xmllint  --format  --html --xpath '${xpath}'  -"
	eval $cmd

}

titleMain=$(getTitle ${main} ${mainXpath})
titleTarget=$(getTitle ${target} ${targetXpath})

echo "titleMain: ${titleMain}"
echo "titleTarget: ${titleTarget}"
if [[ "$titleMain" != "$titleTarget" ]];then
	echo "It's different"
	/root/mail.sh lanshunfang@gmail.com "[ERROR] Hugo Sync failed. Source: ${titleMain}; Target: ${titleTarget} with xpath [${targetXpath}]. xiaofang.me"
else
#	/root/mail.sh lanshunfang@gmail.com "[INFO] Hugo Sync success. Source: ${titleMain}; Target: ${titleTarget}. xiaofang.me"
	echo "It's the same"
fi
