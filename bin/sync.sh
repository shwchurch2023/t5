#!/bin/bash

# env > ~/.env (then remove line with % symbol)
export BASE_PATH=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && cd .. && pwd )

echo "[$0] Sync start: $(date)"
start_seconds1=$(date +%s)

source $BASE_PATH/bin/common-utils.sh

cd $BASE_PATH

SYNC_INSTANCE_ID="${1:-${HUGO_SYNC_RUN_ID:-manual-${start_seconds1}-${RANDOM}}}"
export SYNC_INSTANCE_ID
SYNC_INSTANCE_STATE_FILE=/tmp/t5_sync_instance_state
echo "[$0] Run ID: ${SYNC_INSTANCE_ID}"

register_sync_instance(){
	local existing_id=""
	local existing_pid=""
	if [[ -f "${SYNC_INSTANCE_STATE_FILE}" ]]; then
		local IFS=":"
		read -r existing_id existing_pid < "${SYNC_INSTANCE_STATE_FILE}"
		if [[ -n "${existing_pid}" ]] && kill -0 "${existing_pid}" 2>/dev/null; then
			if [[ "${existing_id}" != "${SYNC_INSTANCE_ID}" ]]; then
				echo "[$0] Another sync instance (ID ${existing_id}, PID ${existing_pid}) is running. Exit current invocation."
				exit 0
			fi
		fi
	fi

	printf "%s:%s\n" "${SYNC_INSTANCE_ID}" "$$" > "${SYNC_INSTANCE_STATE_FILE}"
}

cleanup_sync_instance(){
	if [[ -f "${SYNC_INSTANCE_STATE_FILE}" ]]; then
		local recorded_id=""
		local recorded_pid=""
		local IFS=":"
		read -r recorded_id recorded_pid < "${SYNC_INSTANCE_STATE_FILE}"
		if [[ "${recorded_id}" = "${SYNC_INSTANCE_ID}" && "${recorded_pid}" = "$$" ]]; then
			rm -f "${SYNC_INSTANCE_STATE_FILE}"
		fi
	fi
}

trap cleanup_sync_instance EXIT
register_sync_instance

lock_file main_entry_sync

git config --global core.quotePath false

source_website=https://t5.shwchurch.org/

detectChange_file=${TMP_PATH}/hugo-sync-diff.log
detectChange_file_tmp=${detectChange_file}.tmp
syncStartEmailSent=0

sendSyncNotification(){
	local subject="$1"
	local body="${2:-$1}"
	${BASE_PATH}/bin/mail.sh "shwchurch3@gmail.com" "${subject}" "${body}"
}

sendSyncStartEmail(){
	if [[ "${syncStartEmailSent}" = "1" ]]; then
		return
	fi
	local timestamp
	timestamp=$(date '+%Y-%m-%d %H:%M:%S %Z')
	local subject="Start to sync at ${timestamp}"
	sendSyncNotification "${subject}" "${subject}"
	syncStartEmailSent=1
}

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
# githubHugoThemePath=/mnt/hugo/github/t5/themes/hugo-theme-shwchurch
githubHugoThemePath=${themeFolder}

wodrePressHugoExportPath=/mnt/data/shwchurch/web/wp-content/plugins/wordpress-to-hugo-exporter
ls -la $wodrePressHugoExportPath

incrementalSyncEnabled=0
case "${HUGO_SYNC_INCREMENTAL}" in
	1|true|TRUE|yes|YES)
		incrementalSyncEnabled=1
		;;
esac

if [[ "${incrementalSyncEnabled}" -eq 1 ]]; then
	echo "[INFO] HUGO_SYNC_INCREMENTAL enabled - incremental Wordpress export requested"
else
	echo "[INFO] Full Wordpress export (HUGO_SYNC_INCREMENTAL not set)"
fi

if [[ "${incrementalSyncEnabled}" -eq 1 && ! -d "${tmpPathPrefix}/hugo-export-files" ]]; then
	echo "[WARN] Incremental sync requested but ${tmpPathPrefix}/hugo-export-files is missing. Fallback to full export."
	incrementalSyncEnabled=0
fi
detectChange(){

	detectChangeMaxRetry=5
	detectChangeSleepGap=300

	echo "[$0] Pull content from ${source_website} to ${detectChange_file_tmp}"

	while [[  "1" = "1" ]];do
		detectChangeMaxRetry=$((detectChangeMaxRetry - 1))

		curl ${source_website} | sed 's/[a-zA-Z0-9<>"\\=\/_&%:\.#,\{\}\(\);\?!\[@|* -]//g' > ${detectChange_file_tmp}
		tmp_content=$(cat $detectChange_file_tmp)
		if [[ ! -f "${detectChange_file_tmp}" || -z "${tmp_content}" ]];then
			
				if [[ "$detectChangeMaxRetry" -lt 0 ]];then
					sendSyncNotification "[ERROR][$0] Failed in getting content from ${source_website}"
				unlock_file main_entry_sync
				executeStepAllDone
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
					executeStepAllDone

					exit
					else
						echo "[$0] Force synced even no changes"
						sendSyncStartEmail
						cleanupDeployEndStateIfNeeded
						break
					fi
				else
					echo "[$0] Change detected"
					echo "[$0] ${detectChange_is_changed}"
					sendSyncStartEmail
					cleanupDeployEndStateIfNeeded
					break
				fi	
			else
				cleanupDeployEndStateIfNeeded
				break
			fi
		done
	}

stopSyncIfRequested(){
	local step_label=$1
	if shouldStopAfterStep "${findAndReplace_base_step}" "${step_label}"; then
		echo "[$0] Stop requested after step ${findAndReplace_base_step}. Exit sync.sh"
		unlock_file main_entry_sync
		executeStepAllDone
		exit 0
	fi
}

echo  "(cd /mnt/hugo; sudo -u hugo zsh -c '/mnt/hugo/github/t5/bin/sync.sh > ${log} 2>&1 ' &); tail -f ${log}"

findAndReplace_base_step=40
stopSyncIfRequested "update_repos"

if [[ "$(shouldExecuteStep ${findAndReplace_base_step} update_repos )" = "true" ]];then
	killLongRunningGit
	# echo "[DEBUG] Skipped updateRepo $githubHugoThemePath"
	updateRepo $githubHugoThemePath

	# echo "[DEBUG] Skipped updateRepo $githubHugoPath"
	updateRepo $githubHugoPath
fi

findAndReplace_base_step=$((findAndReplace_base_step + 10))
stopSyncIfRequested "detect_changes"
if [[ "$(shouldExecuteStep ${findAndReplace_base_step} detect_changes )" = "true" ]];then
	detectChange
fi

findAndReplace_base_step=$((findAndReplace_base_step + 10))
stopSyncIfRequested "cleanup_hugo_export_path"
if [[ "$(shouldExecuteStep ${findAndReplace_base_step} cleanup_hugo_export_path )" = "true" ]];then

	echo "[INFO] Cleanup ${hugoExportedPath}"
	mkdir -p "${hugoExportedPath}"
	if [[ ! -z "$hugoExportedPath" && -d "${hugoExportedPath}" ]]; then
		rmSafe "${hugoExportedPath}" "wp-hugo-delta-processing"
	else
		echo "[ERROR] Hugo Export Path ${hugoExportedPath} is invalid"
		unlock_file main_entry_sync
		executeStepAllDone
		exit 1
	fi

	exporterSource="${BASE_PATH}/wordpress-to-hugo-exporter"
	if [[ ! -d "${exporterSource}" ]]; then
		echo "[ERROR] Exporter submodule is missing at ${exporterSource}"
		unlock_file main_entry_sync
		executeStepAllDone
		exit 1
	fi

	# echo "[INFO] Updating exporter submodule at ${exporterSource}"
	# (
	# 	cd "${exporterSource}" && \
	# 	git pull --ff-only
	# )
	# if [[ "$?" -ne 0 ]]; then
	# 	echo "[WARN] Unable to update exporter submodule; continuing with current version"
	# fi

	echo "[INFO] Refresh ${wodrePressHugoExportPath} with exporter submodule"
	if [[ -d "${wodrePressHugoExportPath}" ]]; then
		rmSafe "${wodrePressHugoExportPath}" "wordpress-to-hugo-exporter"
	fi
	mkdir -p "${wodrePressHugoExportPath}"
	rsync -a --exclude='.git/' "${exporterSource}/" "${wodrePressHugoExportPath}/"

	echo "[INFO] Generating Markdown files from Wordpress "
	cd ${wodrePressHugoExportPath}
	pwd
	
	git config --global --add safe.directory ${wodrePressHugoExportPath}
	

	echo "git pull"
	git remote -v

	git pull

	date1=$(date +%s)

	ls ${tmpPathPrefix}

	if [[ "${incrementalSyncEnabled}" -eq 1 ]]; then
		echo "[INFO] Preserving ${tmpPathPrefix}/hugo-export-files for incremental export"
	else
		rm -f "${tmpPathPrefix}/wp-hugo.zip"
		rm -rf ${tmpPathPrefix}/wp-hugo*
		if [[ -d "${tmpPathPrefix}/hugo-export-files" ]]; then
			rmSafe "${tmpPathPrefix}/hugo-export-files" "hugo-export-files"
		fi
	fi

	ls ${tmpPathPrefix}

	echo "php hugo-export-cli.php ${tmpPathPrefix} --no-zip"


	watch_pid=""
	if [[ -d "${tmpPathPrefix}" ]]; then
		echo "[INFO] Starting periodic ls logging for ${tmpPathPrefix} after 120 seconds (append-only)"
		(
			sleep 120
			while [[ -d "${tmpPathPrefix}" ]]; do
				echo "[INFO][watch] $(date '+%Y-%m-%d %H:%M:%S') contents of ${tmpPathPrefix}:"
				ls -la "${tmpPathPrefix}"
				sleep 300
			done
			echo "[INFO][watch] ${tmpPathPrefix} no longer available; stopping periodic ls logging"
		) &
		watch_pid=$!
	else
		echo "[WARN] Skip watch logging because ${tmpPathPrefix} is not available"
	fi

	php_cmd=(php hugo-export-cli.php "${tmpPathPrefix}" --no-zip)
	if [[ "${incrementalSyncEnabled}" -eq 1 ]]; then
		php_cmd+=(--incremental)
	fi
	"${php_cmd[@]}" &
	php_pid=$!
	echo "[INFO] hugo-export-cli.php started with PID ${php_pid}"
	if command -v ps >/dev/null 2>&1; then
		if ! ps -p "${php_pid}" -o pid,ppid,%cpu,%mem,etime,command; then
			echo "[WARN] Unable to show process info for PID ${php_pid}"
		fi
	else
		echo "[WARN] 'ps' command not available; cannot display process info"
	fi
	wait "${php_pid}"
	php_status=$?

	if [[ -n "${watch_pid}" ]]; then
		echo "[INFO] Stopping background watch process ${watch_pid}"
		kill "${watch_pid}" >/dev/null 2>&1 || true
		wait "${watch_pid}" 2>/dev/null || true
		watch_pid=""
	fi

	if [[ ${php_status} -ne 0 ]]; then
		echo "[ERROR] hugo-export-cli.php exited with status ${php_status}"
	fi

	cd ${tmpPathPrefix}
	echo "[INFO] Using folder-only export output"
	exportedFolder="hugo-export-files"
	if [[ ! -d "${exportedFolder}" ]]; then
		echo "[ERROR] Unable to locate exported directory (${exportedFolder}) in ${tmpPathPrefix}"
		unlock_file main_entry_sync
		executeStepAllDone
		exit 1
	fi
	rmSafe "${hugoExportedPath}" "wp-hugo-delta-processing"
	mkdir -p "${hugoExportedPath}"
	if ! rsync -a --exclude='.git/' "${exportedFolder}/" "${hugoExportedPath}/"; then
		echo "[ERROR] Failed to copy exported files from ${exportedFolder} to ${hugoExportedPath}"
		unlock_file main_entry_sync
		executeStepAllDone
		exit 1
	fi
	
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
stopSyncIfRequested "copy_content"
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
		rsync -a --exclude='.git/' ./ "${githubHugoPath}/content/"
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
		stopSyncIfRequested "replace_chars"
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

findAndReplace_base_step=290
stopSyncIfRequested "deploy"

./deploy.sh
exit_code_deploy=$?
#./deploy-new.sh
#echo "$(date)" >> ${log}
if [[ -f "${detectChange_file_tmp}" ]]; then
	mv $detectChange_file_tmp $detectChange_file
else
	if [[ -n "${HUGO_SYNC_FORCE}" ]]; then
		echo "[INFO] detectChange output not updated since HUGO_SYNC_FORCE skipped detection"
	else
		echo "[INFO] detectChange output not updated (step skipped)"
	fi
fi

end_seconds2=$(date +%s)

# standard sh integer arithmetics
time_delta=$((end_seconds2 - start_seconds1 ))

echo "[$0] Sync End: $(date), took $time_delta seconds"

ret=Done
if [[ "$exit_code_deploy" != 0 ]];then
	ret="Failed:"
fi

sendSyncNotification "[INFO][$0] ${ret} Hugo Sync for ${source_website} - Took $time_delta seconds"

unlock_file main_entry_sync
executeStepAllDone
