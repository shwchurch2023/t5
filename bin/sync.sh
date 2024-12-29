#!/bin/bash

# env > ~/.env (then remove line with % symbol)
export BASE_PATH=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && cd .. && pwd )

echo "[$0] Sync start: $(date)"
start_seconds1=$(date +%s)

source $BASE_PATH/bin/common-utils.sh

cd $BASE_PATH

lock_file main_entry_sync

git config --global core.quotePath false

source_website=https://t5.shwchurch.org/

detectChange_file=${TMP_PATH}/hugo-sync-diff.log
detectChange_file_tmp=${detectChange_file}.tmp

echo "[INFO] You could run deploy.sh if you just want to debug it. Normally, sync.sh doesn't have issue, but only deploy with hugo --minify"
echo -ne "[INFO] You have 15s to cancel me\n\n"

log=/mnt/hugo/github/sync.log
hugo_generate_log=/mnt/hugo/github/hugo_generate.log
logDeployManual=/mnt/hugo/github/deploy-manual.log
logDeployEssentialManual=/mnt/hugo/github/deploy-essential-manual.log
echo  "(cd /mnt/hugo; sudo -u hugo zsh -c '/mnt/hugo/github/t5/bin/deploy.sh > ${log} 2>&1' &); tail -f ${log}"
echo  "(cd /mnt/hugo; /mnt/hugo/github/t5/bin/deploy.sh > ${logDeployManual} 2>&1 &); tail -f ${logDeployManual}"
echo  "(cd /mnt/hugo; (source /mnt/hugo/github/t5/bin/common-utils.sh; commitEssentialAndUpdateManualStart) > ${logDeployEssentialManual} 2>&1 &); tail -f ${logDeployEssentialManual}"

echo -ne "\n\n"
sleep 15

date

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

detectChange(){

	detectChangeMaxRetry=10
	detectChangeSleepGap=300

	echo "[$0] Pull content from ${source_website} to ${detectChange_file_tmp}"

	while [[  "1" = "1" ]];do
		detectChangeMaxRetry=$((detectChangeMaxRetry - 1))

		curl ${source_website} | sed 's/[a-zA-Z0-9<>"\\=\/_&%:\.#,\{\}\(\);\?!\[@|* -]//g' > ${detectChange_file_tmp}
		tmp_content=$(cat $detectChange_file_tmp)
		if [[ ! -f "${detectChange_file_tmp}" || -z "${tmp_content}" ]];then
			
			if [[ "$detectChangeMaxRetry" -lt 0 ]];then
				${BASE_PATH}/bin/mail.sh "shwchurch3@gmail.com" "[ERROR][$0] Failed in getting content from ${source_website}"
				unlock_file main_entry_sync
				exit 1023 
			fi
			echo "[$0] Retry left ${detectChangeMaxRetry}"
			sleep $detectChangeSleepGap
			continue
		fi
		if [[ -f "${detectChange_file}" ]];then
			detectChange_is_changed=$(diff ${detectChange_file} ${detectChange_file_tmp})
			if [[ -z "${detectChange_is_changed}"  ]];then
				if [[ -z "${HUGO_SYNC_FORCE}" ]];then
					echo "[$0] $source_website is not changed. Skip sync. Set env var 'export HUGO_SYNC_FORCE=1' for force syncing "
					unlock_file main_entry_sync
					exit
				else
					echo "[$0] Force synced even no changes"
					break
				fi
			else
				echo "[$0] Change detected"
				echo "[$0] ${detectChange_is_changed}"
				break
			fi	
		else
			break
		fi
	done
}

echo  "(cd /mnt/hugo; sudo -u hugo zsh -c '/mnt/hugo/github/t5/bin/sync.sh > ${log} 2>&1 ' &); tail -f ${log}"

findAndReplace_base_step=40

if [[ "$(shouldExecuteStep ${findAndReplace_base_step} update_repos )" = "true" ]];then
	killLongRunningGit
	updateRepo $githubHugoThemePath
	updateRepo $githubHugoPath
fi

findAndReplace_base_step=$((findAndReplace_base_step + 10))
if [[ "$(shouldExecuteStep ${findAndReplace_base_step} detect_changes )" = "true" ]];then
	detectChange
fi

findAndReplace_base_step=$((findAndReplace_base_step + 10))
if [[ "$(shouldExecuteStep ${findAndReplace_base_step} cleanup_hugo_export_path )" = "true" ]];then

	echo "[INFO] Cleanup ${hugoExportedPath}"
	mkdir -p "${hugoExportedPath}"
	if [[ ! -z "$hugoExportedPath" && -d "${hugoExportedPath}" ]]; then
		rmSafe "${hugoExportedPath}" "wp-hugo-delta-processing"
	else
		echo "[ERROR] Hugo Export Path ${hugoExportedPath} is invalid"
		unlock_file main_entry_sync
		exit 1
	fi

	echo "[INFO] Generating Markdown files from Wordpress "
	cd ${wodrePressHugoExportPath}
	pwd
	
	git config --global --add safe.directory ${wodrePressHugoExportPath}

	echo "git pull"
	git remote -v

	git pull

	date1=$(date +%s)
	echo "php hugo-export-cli.php ${tmpPathPrefix} "

	rm -rf wp-hugo.zip

	ls /mnt/hugo/tmp/

	php hugo-export-cli.php ${tmpPathPrefix} 

	cd ${tmpPathPrefix}
	unzip wp-hugo.zip
	rmSafe "${hugoExportedPath}" "wp-hugo-delta-processing"
	mv hugo-export ${hugoExportedPath}
	rm -rf wp-hugo.zip
	
	date2=$(date +%s)

	echo "Time used $(time_diff_seconds $date1 $date2)"

fi

cd ${hugoExportedPath}

# echo "[INFO] Remove file more than ${fileSizeOfFilesToRemove} that is not required from ${protectedMp3FromDeletedRequiredInMarkdownFileNamePattern}"
postDir=${hugoExportedPath}/posts
uploadsDir=${hugoExportedPath}/wp-content/uploads/
cd ${postDir}
pwd
ls

if [[ ! -d "${postDir}" ]];then
	echo "[$postDir] doesn't exist; exit 1"
	sleep 10
fi
# allMp3RequiredDescriptor=uploaded-files-required.txt 
# allMp3Descriptor=uploaded-files.txt
# allMp3ToDeleteDescriptor=uploaded-files-to-delete.txt 

# grep -iRl "\.mp3" ./ | grep -E "${protectedMp3FromDeletedRequiredInMarkdownFileNamePattern}" | xargs cat | grep "/.*\.mp3>" | perl -pe "s|.*/(.*?\.mp3).*|\1|g"  > ${allMp3RequiredDescriptor}
# echo "" > ${uploadsDir}/${allMp3ToDeleteDescriptor}

# fileSizeOfFilesToRemove=+1M
cd ${uploadsDir}
pwd
ls

findAndReplace_base_step=$((findAndReplace_base_step + 10))
if [[ "$(shouldExecuteStep ${findAndReplace_base_step} copy_content)" = "true" ]];then

	echo "[INFO] Delete other unnecessary files"

	rmSafe "./ftp/choir-mp3/" "choir-mp3" true
	date

	echo "[INFO] Copy all contents into Hugo folder for publishing"


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
		findAndReplace_base_step=$((findAndReplace_base_step + 1))
		if [[ "$(shouldExecuteStep ${findAndReplace_base_step} replace_chars )" = "true" ]];then
			findAndReplace "${pattern}" "." "*.md"
		fi
		# find . "${find_not_hidden_args}" -type f -name "*.md" -exec sed -i "${pattern}" {} \;
done


# echo "[INFO] Download signal"
# cd ${githubHugoPath}/content/wp-content/uploads/
# curl https://apkpure.com/signal-private-messenger/org.thoughtcrime.securesms/download?from=details  | sed -n 's/.*download_link.*href\=\"\(.*\)\".*/\1/p' | xargs curl -o signal.latest.apk -L 

cd ${githubHugoPath}/bin/
echo "[INFO] Deploy and publish to github pages"
./deploy.sh
exit_code_deploy=$?
#./deploy-new.sh
#echo "$(date)" >> ${log}
mv $detectChange_file_tmp $detectChange_file

end_seconds2=$(date +%s)

# standard sh integer arithmetics
time_delta=$((end_seconds2 - start_seconds1 ))

echo "[$0] Sync End: $(date), took $time_delta seconds"

ret=Done
if [[ "$exit_code_deploy" != 0 ]];then
	ret="Failed:"
fi

${BASE_PATH}/bin/mail.sh "shwchurch3@gmail.com" "[INFO][$0] ${ret} Hugo Sync for ${source_website} - Took $time_delta seconds"

unlock_file main_entry_sync