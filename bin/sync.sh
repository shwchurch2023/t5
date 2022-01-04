#!/bin/bash


echo "[INFO] You could run deploy.sh if you just want to debug it. Normally, sync.sh doesn't have issue, but only deploy with hugo --minify"
echo -ne "[INFO] You have 15s to cancel me\n\n"
ps aux | grep sync | grep -v grep | awk '{print $2}' | xargs echo "sudo kill -9 "
echo -ne "\n\n"
sleep 15

# env > ~/.env
if [[ -z "$BASE_PATH" ]];then
    cd "$(dirname "$0")"
    cd ..
    export BASE_PATH=$(pwd)
    source $BASE_PATH/bin/common.sh
fi

cd $BASE_PATH

#protectedMp3FromDeletedRequiredInMarkdownFileNamePattern=2019
protectedMp3FromDeletedRequiredInMarkdownFileNamePattern="\.\/(2019|202|203|204).{0,1}-"

tmpPathPrefix=/mnt/hugo/tmp/
hugoExportedPath=${tmpPathPrefix}/wp-hugo-delta-processing

githubHugoPath=/mnt/hugo/github/t5/
githubHugoThemePath=/mnt/hugo/github/t5/themes/hugo-theme-shwchurch
wodrePressHugoExportPath=/mnt/data/shwchurch/web/wp-content/plugins/wordpress-to-hugo-exporter
ls -la $wodrePressHugoExportPath

log=/mnt/hugo/github/sync.log
echo  "(cd /mnt/hugo; sudo -u hugo /mnt/hugo/github/t5/bin/sync.sh > ${log} 2>&1 &); tail -f ${log}"

detechIfSyncIsRunning(){
	if pidof -x "`basename $0`" -o $$ >/dev/null; then
		echo "Process already running"
		exit
	fi
}

detechIfSyncIsRunning

killLongRunningGit

updateRepo $githubHugoThemePath
updateRepo $githubHugoPath

echo "[INFO] Cleanup ${hugoExportedPath}"
mkdir -p "${hugoExportedPath}"
if [[ ! -z "$hugoExportedPath" && -d "${hugoExportedPath}" ]]; then
	rmSafe "${hugoExportedPath}" "wp-hugo-delta-processing"
else
	echo "[ERROR] Hugo Export Path ${hugoExportedPath} is invalid"
	exit 1
fi

echo "[INFO] Generating Markdown files from Wordpress "
cd ${wodrePressHugoExportPath}

php hugo-export-cli.php ${tmpPathPrefix} > /dev/null

cd ${hugoExportedPath}

# echo "[INFO] Remove file more than ${fileSizeOfFilesToRemove} that is not required from ${protectedMp3FromDeletedRequiredInMarkdownFileNamePattern}"
postDir=${hugoExportedPath}/posts
uploadsDir=${hugoExportedPath}/wp-content/uploads/
cd ${postDir}
# allMp3RequiredDescriptor=uploaded-files-required.txt 
# allMp3Descriptor=uploaded-files.txt
# allMp3ToDeleteDescriptor=uploaded-files-to-delete.txt 

# grep -iRl "\.mp3" ./ | grep -E "${protectedMp3FromDeletedRequiredInMarkdownFileNamePattern}" | xargs cat | grep "/.*\.mp3>" | perl -pe "s|.*/(.*?\.mp3).*|\1|g"  > ${allMp3RequiredDescriptor}
# echo "" > ${uploadsDir}/${allMp3ToDeleteDescriptor}

# fileSizeOfFilesToRemove=+1M

cd ${uploadsDir}

echo "[INFO] Delete other unnecessary files"

rmSafe "./ftp/choir-mp3/" "choir-mp3"

echo "[INFO] Copy all contents into Hugo folder for publishing"

rmSafe "${githubHugoPath}/content/*" "t5"
if [[ ! -z "${hugoExportedPath}" && -d "${hugoExportedPath}"  ]];then
	#cp -nr ${hugoExportedPath}/* ${githubHugoPath}/content/
	cd ${hugoExportedPath}
	cp -R ./ ${githubHugoPath}/content/
	cd -
fi


echo "[INFO] Replace all special chars in Markdown Title"

cd ${githubHugoPath}/content/posts

declare -a SpecialCharsInTitle=(
        '@::＠'
)

for SpecialChar in "${SpecialCharsInTitle[@]}"; do
        KEY="${SpecialChar%%::*}"
        VALUE="${SpecialChar##*::}"
        pattern="s#${KEY}#${VALUE}#g"
        find . -type f -name "*.md" -exec sed -i "${pattern}" {} \;
done


cd ${githubHugoPath}/bin/
./sync-podcast.sh 

echo "[INFO] Download signal"
cd ${githubHugoPath}/content/wp-content/uploads/
curl https://apkpure.com/signal-private-messenger/org.thoughtcrime.securesms/download?from=details  | sed -n 's/.*download_link.*href\=\"\(.*\)\".*/\1/p' | xargs curl -o signal.latest.apk -L 

cd ${githubHugoPath}/bin/
echo "[INFO] Deploy and publish to github pages"
./deploy.sh
#./deploy-new.sh
#echo "$(date)" >> ${log}

