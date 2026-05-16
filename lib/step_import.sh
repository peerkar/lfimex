#!/bin/bash
# Step 4: import the LAR produced by step_export into the destination site.
#
# Two-step against /export_import/import_layouts:
#   1. cmd=add_temp   — multipart upload of the LAR into a temp folder
#   2. cmd=import     — kicks off the import as a BackgroundTask
#
# Polls the LayoutImportBackgroundTaskExecutor row until terminal status.

IMPORT_PORTLET_ID="com_liferay_exportimport_web_portlet_ImportPortlet"

step_import() {
  local -a asset_list=("$@")
  local timer log_offset log_file
  timer=$(timer_start)
  log_offset=$(bundle_log_mark)

  local tag_file label
  tag_file="${ASSET_TAG:+.${ASSET_TAG}}"
  label="import${ASSET_TAG:+:${ASSET_TAG}}"
  log_file="${RUN_DIR}/import${tag_file}.bundle.log"

  if [ -z "${EXPORT_LAR_PATH:-}" ]; then
    bundle_log_collect "${log_offset}" "${log_file}"
    result_add "${label}" "skip" "$(timer_elapsed "${timer}")" \
      "$(bundle_log_summary "${log_file}")" "no LAR produced by export"
    return 0
  fi
  if [ -z "${NEW_SITE_GROUP_ID:-}" ]; then
    bundle_log_collect "${log_offset}" "${log_file}"
    result_add "${label}" "skip" "$(timer_elapsed "${timer}")" \
      "$(bundle_log_summary "${log_file}")" "no destination site"
    return 0
  fi

  # The preceding export can run for hours; the target session sat idle the
  # whole time and is almost certainly expired. Re-login so the upload and
  # import POSTs aren't silently redirected to the login page.
  session_refresh_target

  local ns="_${IMPORT_PORTLET_ID}_"
  local action_url="${TARGET_BASE_URL}/group/guest/~/control_panel/manage"
  action_url+="?p_p_id=${IMPORT_PORTLET_ID}"
  action_url+="&p_p_lifecycle=1"
  action_url+="&p_p_state=maximized"
  action_url+="&p_p_mode=view"
  action_url+="&${ns}jakarta.portlet.action=%2Fexport_import%2Fimport_layouts"
  action_url+="&p_auth=${TARGET_P_AUTH}"

  # --- Step 1: upload LAR via cmd=add_temp ---------------------------------
  log_info "Uploading ${EXPORT_LAR_PATH} to ${NEW_SITE_GROUP_ID}"
  local upload_response="${RUN_DIR}/import${tag_file}.upload.json"
  curl -s -o "${upload_response}" -L -b "${TARGET_COOKIE_JAR}" --url "${action_url}" \
    -F "${ns}cmd=add_temp" \
    -F "${ns}groupId=${NEW_SITE_GROUP_ID}" \
    -F "${ns}privateLayout=false" \
    -F "${ns}plid=${NEW_SITE_PLID}" \
    -F "${ns}file=@${EXPORT_LAR_PATH}" \
    -F "p_auth=${TARGET_P_AUTH}"

  if grep -q '"error"\|larfile' "${upload_response}" 2>/dev/null; then
    bundle_log_collect "${log_offset}" "${log_file}"
    local msg
    msg=$(grep -oE '"error":\s*"[^"]*"|"message":\s*"[^"]*"' "${upload_response}" | head -n1 | cut -c1-60)
    result_add "${label}" "fail" "$(timer_elapsed "${timer}")" \
      "$(bundle_log_summary "${log_file}")" "upload rejected: ${msg}"
    return 1
  fi

  # --- Step 2: trigger the import ------------------------------------------
  local pre_task_id
  pre_task_id="$(mysql_q "SELECT IFNULL(MAX(backgroundTaskId),0) FROM BackgroundTask;")"

  local redirect_url="${TARGET_BASE_URL}/group/guest/~/control_panel/manage"
  redirect_url+="?p_p_id=${IMPORT_PORTLET_ID}"
  redirect_url+="&p_p_lifecycle=0"
  redirect_url+="&p_p_state=maximized"
  redirect_url+="&p_p_mode=view"

  local import_response="${RUN_DIR}/import${tag_file}.response.html"
  local -a import_fields=(
    -F "${ns}cmd=import"
    -F "${ns}groupId=${NEW_SITE_GROUP_ID}"
    -F "${ns}privateLayout=false"
    -F "${ns}plid=${NEW_SITE_PLID}"
    -F "${ns}redirect=${redirect_url}"
    -F "${ns}DATA_STRATEGY=DATA_STRATEGY_MIRROR"
    -F "${ns}LAYOUTS_IMPORT_MODE=CREATED_FROM_PROTOTYPE"
    -F "${ns}USER_ID_STRATEGY=CURRENT_USER_ID"
    -F "${ns}DELETE_PORTLET_DATA=false"
    -F "${ns}UPDATE_LAST_PUBLISH_DATE=false"
    -F "${ns}OVERWRITE_USER_PERMISSIONS=false"
    -F "p_auth=${TARGET_P_AUTH}"
  )

  # Append the same asset-driven toggles used for export so the data handlers
  # actually pick up each entity type. Without these, the import receives only
  # generic flags and silently skips per-asset data.
  local arg val
  while IFS= read -r arg; do
    [ -z "${arg}" ] && continue
    if [ "${arg}" = "-F" ]; then
      IFS= read -r val
      import_fields+=(-F "${val}")
    fi
  done < <(asset_form_fields "${ns}" "${asset_list[@]}")

  curl -s -o "${import_response}" -L -b "${TARGET_COOKIE_JAR}" --url "${action_url}" "${import_fields[@]}"

  # The action's BackgroundTask row appears asynchronously; wait up to 30s.
  local task_id="" i
  for i in $(seq 1 30); do
    task_id="$(mysql_q "SELECT MAX(backgroundTaskId) FROM BackgroundTask WHERE backgroundTaskId > ${pre_task_id} AND taskExecutorClassName LIKE '%LayoutImportBackgroundTaskExecutor';")"
    if [ -n "${task_id}" ] && [ "${task_id}" != "NULL" ]; then break; fi
    sleep 1
  done
  if [ -z "${task_id}" ] || [ "${task_id}" = "NULL" ]; then
    bundle_log_collect "${log_offset}" "${log_file}"
    result_add "${label}" "fail" "$(timer_elapsed "${timer}")" \
      "$(bundle_log_summary "${log_file}")" "import did not create a BackgroundTask"
    return 1
  fi
  log_info "Tracking import BackgroundTask ${task_id}"

  # Poll the import task. BackgroundTaskConstants:
  #   0=NEW, 1=IN_PROGRESS, 2=FAILED, 3=SUCCESSFUL,
  #   4=QUEUED, 5=CANCELLED, 6=COMPLETED_WITH_ERRORS.
  # The integer is appended to `status` as "<ok|warn|fail>(<int>)".
  local elapsed_poll=0 task_status status="ok" details=""
  while :; do
    task_status="$(mysql_q "SELECT status FROM BackgroundTask WHERE backgroundTaskId=${task_id};")"
    case "${task_status}" in
      0|1|4)
        if [ "${elapsed_poll}" -ge "${POLL_TIMEOUT}" ]; then
          status="fail(${task_status})"; details="timeout after ${POLL_TIMEOUT}s, status=${task_status}"
          break
        fi
        sleep "${POLL_SECONDS}"
        elapsed_poll=$((elapsed_poll + POLL_SECONDS))
        ;;
      3) status="ok(${task_status})"; details="task ${task_id} succeeded"; break ;;
      6) status="warn(${task_status})"; details="task ${task_id} completed with errors"; break ;;
      2|5)
        status="fail(${task_status})"
        local msg
        msg=$(mysql_q "SELECT statusMessage FROM BackgroundTask WHERE backgroundTaskId=${task_id};" | head -c 80)
        details="task ${task_id} status=${task_status} ${msg}"
        break
        ;;
      *) status="fail(${task_status})"; details="task ${task_id} unexpected status=${task_status}"; break ;;
    esac
  done

  bundle_log_collect "${log_offset}" "${log_file}"

  # Pull per-entry ExportImportReportEntry rows for this task into a TSV, and
  # tack a one-line summary onto the details column so the user can see what
  # to look at without opening the file.
  local report_file="${RUN_DIR}/import${tag_file}.report.tsv"
  report_collect "${task_id}" "${report_file}"
  local report_sum
  report_sum="$(report_summary "${report_file}")"
  if [ -n "${report_sum}" ]; then
    details="${details} | ${report_sum}"
    log_warn "Import report entries written to ${report_file}"
  fi

  result_add "${label}" "${status}" "$(timer_elapsed "${timer}")" \
    "$(bundle_log_summary "${log_file}")" "${details}"
  [[ "${status}" == ok* || "${status}" == warn* ]]
}
