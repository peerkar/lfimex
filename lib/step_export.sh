#!/bin/bash
# Step 1: site-level export via the ExportPortlet "/export_import/export_layouts"
# action. Exports the source site's pages plus the selected asset types,
# polls the resulting BackgroundTask, downloads the produced LAR.

EXPORT_PORTLET_ID="com_liferay_exportimport_web_portlet_ExportPortlet"

step_export() {
  local -a asset_list=("$@")
  local ns="_${EXPORT_PORTLET_ID}_"
  local timer status="ok" details=""
  local task_id="" lar_path=""
  local log_offset log_file
  timer=$(timer_start)
  log_offset=$(bundle_log_mark)

  # ASSET_TAG is set by per-asset orchestration to keep each cycle's artifacts
  # separate. When empty, filenames stay at their original "export.*" form.
  local tag_file tag_id
  tag_file="${ASSET_TAG:+.${ASSET_TAG}}"
  tag_id="${ASSET_TAG:+-${ASSET_TAG}}"
  log_file="${RUN_DIR}/export${tag_file}.bundle.log"

  log_info "Exporting site ${SOURCE_GROUP_ID} (assets: ${asset_list[*]})"

  local export_filename="SiteExport-${RUN_ID}${tag_id}.lar"
  local action_url="${BASE_URL}/group/guest/~/control_panel/manage"
  action_url+="?p_p_id=${EXPORT_PORTLET_ID}"
  action_url+="&p_p_lifecycle=1"
  action_url+="&p_p_state=maximized"
  action_url+="&p_p_mode=view"
  action_url+="&${ns}jakarta.portlet.action=%2Fexport_import%2Fexport_layouts"
  action_url+="&p_auth=${P_AUTH}"

  local redirect_url="${BASE_URL}/group/guest/~/control_panel/manage"
  redirect_url+="?p_p_id=${EXPORT_PORTLET_ID}"
  redirect_url+="&p_p_lifecycle=0"
  redirect_url+="&p_p_state=maximized"
  redirect_url+="&p_p_mode=view"

  # The layout-tree fields (rootLayoutId / rootLayoutIncluded / layoutIdMap /
  # pagesToExport) used to be unconditional here. They moved into the
  # `site_pages` asset's extras so site pages are selectable like any other
  # asset — when site_pages isn't in --assets, the export still runs but
  # carries no Layout rows.
  local -a fields=(
    -F "${ns}redirect=${redirect_url}"
    -F "${ns}groupId=${SOURCE_GROUP_ID}"
    -F "${ns}liveGroupId=${SOURCE_GROUP_ID}"
    -F "${ns}privateLayout=${SOURCE_PRIVATE_LAYOUT}"
    -F "${ns}cmd=export"
    -F "${ns}exportFileName=${export_filename}"
    -F "${ns}name=${export_filename}"
    -F "p_auth=${P_AUTH}"
  )

  # Date filter. When FILTER=date-range, emit the per-field values Liferay's
  # ExportImportDateUtil reads back. When FILTER=all (default), just set range.
  if [ "${FILTER:-all}" = "date-range" ]; then
    derive_date_fields START "${FROM_DATE}" "00:00:00" 0
    derive_date_fields END   "${TO_DATE}"   "23:59:00" 1
    log_info "Date filter: ${START_HUMAN} → ${END_HUMAN}"
    fields+=(
      -F "${ns}range=dateRange"
      -F "${ns}startDate=${START_MMDDYYYY}"
      -F "${ns}startDateDay=${START_DD}"
      -F "${ns}startDateMonth=${START_MM}"
      -F "${ns}startDateYear=${START_YYYY}"
      -F "${ns}startTime=${START_TIME}"
      -F "${ns}startDateHour=${START_HOUR}"
      -F "${ns}startDateMinute=${START_MINUTE}"
      -F "${ns}startDateAmPm=${START_AMPM}"
      -F "${ns}startDateTime=${START_HUMAN}"
      -F "${ns}endDate=${END_MMDDYYYY}"
      -F "${ns}endDateDay=${END_DD}"
      -F "${ns}endDateMonth=${END_MM}"
      -F "${ns}endDateYear=${END_YYYY}"
      -F "${ns}endTime=${END_TIME}"
      -F "${ns}endDateHour=${END_HOUR}"
      -F "${ns}endDateMinute=${END_MINUTE}"
      -F "${ns}endDateAmPm=${END_AMPM}"
      -F "${ns}endDateTime=${END_HUMAN}"
    )
  else
    fields+=(-F "${ns}range=all")
  fi

  # Asset registry emits "-F\n<field>\n" pairs; absorb them into the curl arg array.
  local arg key val
  while IFS= read -r arg; do
    [ -z "${arg}" ] && continue
    if [ "${arg}" = "-F" ]; then
      IFS= read -r val
      fields+=(-F "${val}")
    fi
  done < <(asset_form_fields "${ns}" "${asset_list[@]}")

  local pre_task_id
  pre_task_id="$(mysql_q "SELECT IFNULL(MAX(backgroundTaskId),0) FROM BackgroundTask;")"
  log_info "BackgroundTask max id before POST: ${pre_task_id}"

  local response_file="${RUN_DIR}/export${tag_file}.response.html"
  curl -s -o "${response_file}" -L -b "${COOKIE_JAR}" --url "${action_url}" "${fields[@]}"

  # The action's BackgroundTask row appears asynchronously; wait up to 30s.
  local i
  for i in $(seq 1 30); do
    task_id="$(mysql_q "SELECT MAX(backgroundTaskId) FROM BackgroundTask WHERE backgroundTaskId > ${pre_task_id} AND taskExecutorClassName LIKE '%LayoutExportBackgroundTaskExecutor';")"
    if [ -n "${task_id}" ] && [ "${task_id}" != "NULL" ]; then break; fi
    sleep 1
  done
  if [ -z "${task_id}" ] || [ "${task_id}" = "NULL" ]; then
    status="fail"; details="action did not create a BackgroundTask"
    _step_export_finish "${timer}" "${log_offset}" "${log_file}" "${status}" "${details}" ""
    return 1
  fi
  log_info "Tracking export BackgroundTask ${task_id}"

  # Poll until terminal status. BackgroundTaskConstants:
  #   0=NEW, 1=IN_PROGRESS, 2=FAILED, 3=SUCCESSFUL,
  #   4=QUEUED, 5=CANCELLED, 6=COMPLETED_WITH_ERRORS.
  local elapsed_poll=0 task_status
  while :; do
    task_status="$(mysql_q "SELECT status FROM BackgroundTask WHERE backgroundTaskId=${task_id};")"
    case "${task_status}" in
      0|1|4)
        if [ "${elapsed_poll}" -ge "${POLL_TIMEOUT}" ]; then
          status="fail"; details="timeout after ${POLL_TIMEOUT}s, status=${task_status}"
          break
        fi
        sleep "${POLL_SECONDS}"
        elapsed_poll=$((elapsed_poll + POLL_SECONDS))
        ;;
      3) details="task ${task_id} succeeded"; break ;;
      6) status="warn"; details="task ${task_id} completed with errors"; break ;;
      2|5) status="fail"; details="task ${task_id} status=${task_status} (failed/cancelled)"; break ;;
      *) status="fail"; details="task ${task_id} unexpected status=${task_status}"; break ;;
    esac
  done

  if [ "${status}" = "ok" ]; then
    local row
    row="$(mysql_q "SELECT uuid_, fileName, groupId FROM DLFileEntry WHERE fileName LIKE 'SiteExport-${RUN_ID}${tag_id}%' ORDER BY fileEntryId DESC LIMIT 1;")"
    if [ -n "${row}" ]; then
      local uuid name group
      read -r uuid name group <<< "${row}"
      lar_path="${RUN_DIR}/${name}"
      portal_curl "${lar_path}" "${BASE_URL}/documents/portlet_file_entry/${group}/${name}/${uuid}?download=true"
      if [ ! -s "${lar_path}" ]; then
        status="fail"; details="LAR download empty"
      else
        EXPORT_LAR_PATH="${lar_path}"
        details="${name} ($(du -h "${lar_path}" | awk '{print $1}'))"
      fi
    else
      status="fail"; details="LAR DLFileEntry not found"
    fi
  fi

  _step_export_finish "${timer}" "${log_offset}" "${log_file}" "${status}" "${details}" "${task_id}" "${tag_file}"
  [ "${status}" = "ok" ]
}

_step_export_finish() {
  local timer="$1" log_offset="$2" log_file="$3" status="$4" details="$5" task_id="$6" tag_file="$7"
  local elapsed logsum
  elapsed=$(timer_elapsed "${timer}")
  bundle_log_collect "${log_offset}" "${log_file}"
  logsum=$(bundle_log_summary "${log_file}")
  [ -n "${task_id}" ] && details="${details} (task=${task_id})"
  if [ -n "${task_id}" ]; then
    local report_file="${RUN_DIR}/export${tag_file}.report.tsv"
    report_collect "${task_id}" "${report_file}"
    local report_sum
    report_sum="$(report_summary "${report_file}")"
    if [ -n "${report_sum}" ]; then
      details="${details} | ${report_sum}"
      log_warn "Export report entries written to ${report_file}"
    fi
  fi
  local label="export${ASSET_TAG:+:${ASSET_TAG}}"
  result_add "${label}" "${status}" "${elapsed}" "${logsum}" "${details}"
}
