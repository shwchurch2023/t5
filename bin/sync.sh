#!/bin/bash

source_website=https://t5.shwchurch.org/

detectChange_file=/tmp/hugo-sync-diff.log
detectChange_file_tmp=${detectChange_file}.tmp

current_process_id=$$

echo "[INFO] Current ID $current_process_id"
ps aux | grep sync | grep -v grep
detect_existing_process=$(ps aux | grep sync | grep -v grep | grep -v "root " | grep -v "ec2-user " | grep -v " ${current_process_id} ")
if [[ ! -z "${detect_existing_process}" ]];then
	echo "[WARN] Existing processes found ${detect_existing_process}"
	echo "[WARN] To kill them, try"
	ps aux | grep sync | grep -v grep | awk '{print $2}' | xargs echo "sudo kill -9 "
	exit 2
fi

exit 2

echo "[INFO] You could run deploy.sh if you just want to debug it. Normally, sync.sh doesn't have issue, but only deploy with hugo --minify"
echo -ne "[INFO] You have 15s to cancel me\n\n"

log=/mnt/hugo/github/sync.log
echo  "(cd /mnt/hugo; sudo -u hugo zsh -c '/mnt/hugo/github/t5/bin/deploy.sh > ${log} 2>&1' &); tail -f ${log}"
echo  "(cd /mnt/hugo; /mnt/hugo/github/t5/bin/deploy.sh > ${log} 2>&1 &); tail -f ${log}"

echo -ne "\n\n"
sleep 15

date

# env > ~/.env
export BASE_PATH=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && cd .. && pwd )

source $BASE_PATH/bin/common-utils.sh

git config --global core.quotePath false

cd $BASE_PATH

ensureRequiredFolders

#protectedMp3FromDeletedRequiredInMarkdownFileNamePattern=2019
protectedMp3FromDeletedRequiredInMarkdownFileNamePattern="\.\/(2019|202|203|204).{0,1}-"

tmpPathPrefix=/mnt/hugo/tmp/
hugoExportedPath=${tmpPathPrefix}/wp-hugo-delta-processing

githubHugoPath=/mnt/hugo/github/t5/
githubHugoThemePath=/mnt/hugo/github/t5/themes/hugo-theme-shwchurch
wodrePressHugoExportPath=/mnt/data/shwchurch/web/wp-content/plugins/wordpress-to-hugo-exporter
ls -la $wodrePressHugoExportPath

echo  "(cd /mnt/hugo; sudo -u hugo zsh -c '/mnt/hugo/github/t5/bin/sync.sh > ${log} 2>&1 ' &); tail -f ${log}"

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

if [[ -z "${HUGO_SKIP_PHP_WP_EXPORT}" ]];then
	echo "[INFO] Cleanup ${hugoExportedPath}"
	mkdir -p "${hugoExportedPath}"
	if [[ ! -z "$hugoExportedPath" && -d "${hugoExportedPath}" ]]; then
		rmSafe "${hugoExportedPath}" "wp-hugo-delta-processing"
	else
		echo "[ERROR] Hugo Export Path ${hugoExportedPath} is invalid"
		exit 1
	fi
fi

echo "[INFO] Generating Markdown files from Wordpress "
cd ${wodrePressHugoExportPath}

detectChange(){
	curl ${source_website} | sed 's/[a-zA-Z0-9<>"\\=\/_&%:\.#,\{\}\(\);\?!\[@|* -]//g' > ${detectChange_file_tmp}
	if [[ ! -f "${detectChange_file_tmp}" ]];then
		${BASE_PATH}/bin/mail.sh "shwchurch3@gmail.com" "[ERROR][$0] Failed in getting content from ${source_website}"
		exit 1023
	fi
	if [[ -f "${detectChange_file}" ]];then
		detectChange_is_changed=$(diff ${detectChange_file} ${detectChange_file_tmp})
		if [[ -z "${detectChange_is_changed}"  ]];then
			if [[ -z "${HUGO_SYNC_FORCE}" ]];then
				echo "[$0] $source_website is not changed. Skip sync. Set env var 'export HUGO_SYNC_FORCE=1' for force syncing "
				exit
			else
				echo "[$0] Force synced even no changes"
			fi
		else
			echo "[$0] Change detected"
			echo "[$0] ${detectChange_is_changed}"
		fi	
	fi
}
detectChange

php hugo-export-cli.php ${tmpPathPrefix} > /dev/null

date

cd ${hugoExportedPath}

# echo "[INFO] Remove file more than ${fileSizeOfFilesToRemove} that is not required from ${protectedMp3FromDeletedRequiredInMarkdownFileNamePattern}"
postDir=${hugoExportedPath}/posts
uploadsDir=${hugoExportedPath}/wp-content/uploads/
cd ${postDir}
pwd
ls

# allMp3RequiredDescriptor=uploaded-files-required.txt 
# allMp3Descriptor=uploaded-files.txt
# allMp3ToDeleteDescriptor=uploaded-files-to-delete.txt 

# grep -iRl "\.mp3" ./ | grep -E "${protectedMp3FromDeletedRequiredInMarkdownFileNamePattern}" | xargs cat | grep "/.*\.mp3>" | perl -pe "s|.*/(.*?\.mp3).*|\1|g"  > ${allMp3RequiredDescriptor}
# echo "" > ${uploadsDir}/${allMp3ToDeleteDescriptor}

# fileSizeOfFilesToRemove=+1M

cd ${uploadsDir}
pwd
ls

echo "[INFO] Delete other unnecessary files"

rmSafe "./ftp/choir-mp3/" "choir-mp3" true
date

echo "[INFO] Copy all contents into Hugo folder for publishing"

if [[ -z "${HUGO_SKIP_PHP_WP_EXPORT}" ]];then
	rmSafe "${githubHugoPath}/content/*" "t5"
	if [[ ! -z "${hugoExportedPath}" && -d "${hugoExportedPath}"  ]];then
		#cp -nr ${hugoExportedPath}/* ${githubHugoPath}/content/
		cd ${hugoExportedPath}
		pwd
		ls
		cp -R ./ ${githubHugoPath}/content/
		cd -
	fi
fi

date

echo "[INFO] Replace all special chars in Markdown Title"

cd ${githubHugoPath}/content/posts
pwd
ls

declare -a SpecialCharsInTitle=(
        '@::＠'
)

for SpecialChar in "${SpecialCharsInTitle[@]}"; do
        KEY="${SpecialChar%%::*}"
        VALUE="${SpecialChar##*::}"
        pattern="s#${KEY}#${VALUE}#g"
		findAndReplace "${pattern}" "." "*.md"
        # find . "${find_not_hidden_args}" -type f -name "*.md" -exec sed -i "${pattern}" {} \;
done


# echo "[INFO] Download signal"
# cd ${githubHugoPath}/content/wp-content/uploads/
# curl https://apkpure.com/signal-private-messenger/org.thoughtcrime.securesms/download?from=details  | sed -n 's/.*download_link.*href\=\"\(.*\)\".*/\1/p' | xargs curl -o signal.latest.apk -L 

cd ${githubHugoPath}/bin/
echo "[INFO] Deploy and publish to github pages"
./deploy.sh
#./deploy-new.sh
#echo "$(date)" >> ${log}
mv $detectChange_file_tmp $detectChange_file

${BASE_PATH}/bin/mail.sh "shwchurch3@gmail.com" "[INFO][$0] Done Hugo Sync for ${source_website}"