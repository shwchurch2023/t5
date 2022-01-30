if [[ -z "$BASE_PATH" ]];then
    cd "$(dirname "$0")"
    cd ..
    export BASE_PATH=$(pwd)
    source $BASE_PATH/bin/common.sh
fi

cd $BASE_PATH

main=https://t5.shwchurch.org/
mainXpath='//*[@id="main_sermon_hover"]/section/article[1]/h2/a/text()'
target=https://${publicGitUsername}.github.io/categories/%E8%AE%B2%E9%81%93/
targetXpath='(//div[contains(@class,"l-title")]/a/text())[1]'
#title=$(curl ${main} |  xmllint  --format  --html --xpath '//*[@id="main_sermon_hover"]/section/article[1]/h2/a/text()'   -)

getTitle(){
	domain=$1
	xpath=$2
	curl ${domain} |  xmllint  --format  --html --xpath ${xpath}  -

}

titleMain=$(getTitle ${main} ${mainXpath})
titleTarget=$(getTitle ${target} ${targetXpath})

echo "titleMain: ${titleMain}"
echo "titleTarget: ${titleTarget}"
if [[ "$titleMain" != "$titleTarget" ]];then
	echo "It's different"
else
	echo "It's the same"
fi
