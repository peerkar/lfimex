#!/bin/bash
# Step 3.5: migrate global (company-wide) dependencies from source to target
# before the site-level export/import cycle runs.
#
# Custom Fields (Expando), and anything else registered via global_register,
# are exported from the source company's Global site through ExportImportPortlet
# and imported into the new company's Global site. This is a no-op in
# INSTANCE_MODE=reuse (target = source).
#
# Both phases drive the same MVC action — /export_import/export_import — with
# cmd=export, cmd=add_temp, cmd=import in turn. The action enqueues a
# BackgroundTask backed by PortletExportBackgroundTaskExecutor /
# PortletImportBackgroundTaskExecutor, which we poll the same way step_export
# and step_import poll the layout-level executors.

EXPORT_IMPORT_PORTLET_ID="com_liferay_exportimport_web_portlet_ExportImportPortlet"

step_globals() {
  if [ "${INSTANCE_MODE:-reuse}" != "create" ]; then
    return 0
  fi
  if [ -z "${GLOBAL_ASSETS:-}" ]; then
    return 0
  fi
  if [ -z "${NEW_INSTANCE_COMPANY_ID:-}" ]; then
    log_warn "Skipping globals: no NEW_INSTANCE_COMPANY_ID"
    return 0
  fi

  local -a global_list
  mapfile -t global_list < <(globals_resolve "${GLOBAL_ASSETS}")
  if [ "${#global_list[@]}" -eq 0 ]; then
    return 0
  fi

  local src_global_gid tgt_global_gid
  src_global_gid="$(_global_site_id "${SOURCE_COMPANY_WEB_ID}")"
  tgt_global_gid="$(mysql_q "SELECT groupId FROM Group_ WHERE companyId=${NEW_INSTANCE_COMPANY_ID} AND friendlyURL='/global' AND site=1 LIMIT 1;")"

  if [ -z "${src_global_gid}" ] || [ -z "${tgt_global_gid}" ]; then
    log_warn "Could not resolve Global sites (source=${src_global_gid}, target=${tgt_global_gid})"
    return 0
  fi
  log_info "Global sites: source=${src_global_gid}, target=${tgt_global_gid}"
  log_info "Global assets to migrate: ${global_list[*]}"

  local id
  for id in "${global_list[@]}"; do
    if ! global_asset_resolve "${id}"; then
      log_warn "Skipping global '${id}': not registered or has no portlet"
      continue
    fi
    _step_globals_one "${id}" "${_GA_PORTLET}" "${_GA_LABEL}" "${_GA_EXTRAS}" \
      "${src_global_gid}" "${tgt_global_gid}"
  done
}

_global_site_id() {
  mysql_q "SELECT g.groupId FROM Group_ g JOIN Company c ON c.companyId=g.companyId WHERE c.webId='$1' AND g.friendlyURL='/global' AND g.site=1 LIMIT 1;"
}

# Any existing Layout plid for the given companyId. ExportImportPortlet
# requires a real plid in its form; SOURCE_PLID lives in the source company
# and isn't valid for target POSTs.
_company_any_plid() {
  mysql_q "SELECT MIN(plid) FROM Layout WHERE companyId=$1;"
}

# Drive one global through export → upload → import, recording one result
# row per phase. Phases are isolated so a failed export doesn't try to
# upload, and a failed upload doesn't try to import.
_step_globals_one() {
  local id="$1" portlet_id="$2" label="$3" extras="$4" src_gid="$5" tgt_gid="$6"

  log_info "Global ${id} (${label}): portlet=${portlet_id}"

  local lar_path=""
  _step_globals_export "${id}" "${portlet_id}" "${src_gid}" "${extras}" || return 0
  lar_path="${_LAST_GLOBAL_LAR_PATH}"
  [ -n "${lar_path}" ] || return 0

  _step_globals_import "${id}" "${portlet_id}" "${tgt_gid}" "${extras}" "${lar_path}"
}

# Build the -F arguments shared by both export and import POSTs. Field set
# mirrors what Liferay's "Export/Import" dialog actually submits — additional
# toggles like DELETIONS / PERMISSIONS aren't part of the company-wide
# Custom Fields flow.
_global_form_fields() {
  local ns="$1" portlet="$2" group_id="$3" cmd="$4" plid="$5" extras="$6" file_name="${7:-}" base_url="${8:-${BASE_URL}}"

  printf -- '-F\n%scmd=%s\n' "${ns}" "${cmd}"
  printf -- '-F\n%stabs1=export_import\n' "${ns}"
  printf -- '-F\n%stabs2=%s\n' "${ns}" "${cmd}"
  printf -- '-F\n%sgroupId=%s\n' "${ns}" "${group_id}"
  printf -- '-F\n%splid=%s\n' "${ns}" "${plid}"
  printf -- '-F\n%sportletResource=%s\n' "${ns}" "${portlet}"
  # ExportImportPortlet's action calls sendRedirect with whatever redirect=
  # we pass; without it, the default target is the same portlet's render URL,
  # which has no view.jsp and floods the log with "Path /view.jsp is not
  # accessible" stack traces. Send the user back to a benign page instead.
  printf -- '-F\n%sredirect=%s\n' "${ns}" "${base_url}/web/guest"
  printf -- '-F\n%sPORTLET_CONFIGURATION=true\n' "${ns}"
  printf -- '-F\n%sPORTLET_CONFIGURATION_%s=on\n' "${ns}" "${portlet}"
  printf -- '-F\n%sPORTLET_SETUP_%s=on\n' "${ns}" "${portlet}"
  printf -- '-F\n%sPORTLET_DATA_CONTROL_DEFAULT=false\n' "${ns}"
  printf -- '-F\n%sPORTLET_DATA=true\n' "${ns}"
  printf -- '-F\n%sPORTLET_DATA_%s=on\n' "${ns}" "${portlet}"
  printf -- '-F\n%sCOMMENTS=on\n' "${ns}"
  printf -- '-F\n%sRATINGS=on\n' "${ns}"

  if [ "${cmd}" = "export" ]; then
    printf -- '-F\n%srange=all\n' "${ns}"
    [ -n "${file_name}" ] && printf -- '-F\n%sexportFileName=%s\n' "${ns}" "${file_name}"
  elif [ "${cmd}" = "import" ]; then
    printf -- '-F\n%sDATA_STRATEGY=DATA_STRATEGY_MIRROR\n' "${ns}"
    printf -- '-F\n%sUSER_ID_STRATEGY=CURRENT_USER_ID\n' "${ns}"
  fi

  local -a checkbox_names=(
    "PORTLET_CONFIGURATION_${portlet}"
    "PORTLET_SETUP_${portlet}"
    "PORTLET_DATA_${portlet}"
    "COMMENTS" "RATINGS" "DELETIONS" "PERMISSIONS"
  )
  local line key
  while IFS= read -r line; do
    [ -z "${line}" ] && continue
    printf -- '-F\n%s%s\n' "${ns}" "${line}"
    key="${line%%=*}"
    checkbox_names+=("${key}")
  done <<< "${extras}"

  local joined
  joined=$(IFS=','; echo "${checkbox_names[*]}")
  printf -- '-F\n%scheckboxNames=%s\n' "${ns}" "${joined}"
}

# Build the ExportImportPortlet popup URL the export-import dialog posts to.
# Liferay opens this as a popup (lifecycle=0, state=pop_up); the form's cmd
# parameter ("export" / "add_temp" / "import") tells the render command to
# dispatch to the matching action internally. session is "source" (uses
# BASE_URL / P_AUTH) or "target" (uses TARGET_BASE_URL / TARGET_P_AUTH).
_global_action_url() {
  local session="$1"
  local ns="_${EXPORT_IMPORT_PORTLET_ID}_"
  local base auth
  if [ "${session}" = "target" ]; then
    base="${TARGET_BASE_URL}"; auth="${TARGET_P_AUTH}"
  else
    base="${BASE_URL}"; auth="${P_AUTH}"
  fi
  # Both jakarta.portlet.action and mvcRenderCommandName are needed:
  # the first dispatches the ACTION phase to ExportImportMVCActionCommand;
  # the second tells the container to render ExportImportMVCRenderCommand
  # (a real popup view) after the action returns. Without the render-command
  # parameter, the container falls back to doView → /view.jsp, which the
  # portlet doesn't ship — and Liferay logs an error for every action.
  local url="${base}/group/control_panel/manage"
  url+="?p_p_id=${EXPORT_IMPORT_PORTLET_ID}"
  url+="&p_p_lifecycle=1"
  url+="&p_p_state=pop_up"
  url+="&p_p_mode=view"
  url+="&${ns}jakarta.portlet.action=%2Fexport_import%2Fexport_import"
  url+="&${ns}mvcRenderCommandName=%2Fexport_import%2Fexport_import"
  url+="&p_auth=${auth}"
  echo "${url}"
}

_step_globals_export() {
  local id="$1" portlet="$2" src_gid="$3" extras="$4"
  local label="globals_export:${id}"
  local timer log_offset log_file
  timer=$(timer_start)
  log_offset=$(bundle_log_mark)
  log_file="${RUN_DIR}/${label//:/_}.bundle.log"

  # Sessions may be stale by the time this runs (esp. between consecutive
  # globals or after long site tasks); refresh source before the action POST.
  session_refresh

  local ns="_${EXPORT_IMPORT_PORTLET_ID}_"
  local action_url file_name
  action_url="$(_global_action_url source)"
  # "Global-" prefix marks the LAR as company-wide (vs site-scoped); no ".lar"
  # suffix because Liferay appends "-<timestamp>.lar" to whatever we submit.
  file_name="Global-${id}-${RUN_ID}.portlet"

  local pre_task_id
  pre_task_id="$(mysql_q "SELECT IFNULL(MAX(backgroundTaskId),0) FROM BackgroundTask;")"

  local response_file="${RUN_DIR}/${label//:/_}.response.html"
  local -a fields=(
    -F "p_auth=${P_AUTH}"
  )
  local arg val
  while IFS= read -r arg; do
    [ -z "${arg}" ] && continue
    if [ "${arg}" = "-F" ]; then
      IFS= read -r val
      fields+=(-F "${val}")
    fi
  done < <(_global_form_fields "${ns}" "${portlet}" "${src_gid}" "export" "${SOURCE_PLID}" "${extras}" "${file_name}" "${BASE_URL}")

  # No -L: ExportImportPortlet's action redirects to its own render URL, but
  # the portlet has no default view.jsp (render is dispatched via specific
  # mvcRenderCommandName values). Following the redirect floods the log with
  # "Path /view.jsp is not accessible" errors per call. The action itself
  # completes before the 302, so we don't need the redirect target.
  curl -s -o "${response_file}" -b "${COOKIE_JAR}" --url "${action_url}" "${fields[@]}"

  local task_id status="ok" details=""
  task_id="$(_wait_for_task "${pre_task_id}" "%PortletExportBackgroundTaskExecutor")"
  if [ -z "${task_id}" ]; then
    bundle_log_collect "${log_offset}" "${log_file}"
    result_add "${label}" "fail" "$(timer_elapsed "${timer}")" \
      "$(bundle_log_summary "${log_file}")" "no BackgroundTask"
    return 1
  fi
  log_info "Tracking globals export task ${task_id}"

  _poll_task "${task_id}" status details

  local lar_path=""
  if [ "${status}" = "ok" ]; then
    # Poll above can outlast the session; refresh before downloading the LAR.
    session_refresh
    local row uuid name group
    row="$(mysql_q "SELECT uuid_, fileName, groupId FROM DLFileEntry WHERE fileName LIKE '${file_name}%' ORDER BY fileEntryId DESC LIMIT 1;")"
    if [ -n "${row}" ]; then
      read -r uuid name group <<< "${row}"
      # Save under our submitted name so artifacts on disk match what we asked
      # for, dropping Liferay's appended "-<timestamp>.lar".
      lar_path="${RUN_DIR}/${file_name}.lar"
      portal_curl "${lar_path}" "${BASE_URL}/documents/portlet_file_entry/${group}/${name}/${uuid}?download=true"
      if [ ! -s "${lar_path}" ]; then
        status="fail"; details="LAR download empty"
      elif ! _is_lar_file "${lar_path}"; then
        status="fail"; details="LAR download is not a ZIP (likely login redirect; session expired?)"
      else
        details="${file_name}.lar ($(du -h "${lar_path}" | awk '{print $1}')) (task=${task_id})"
        _LAST_GLOBAL_LAR_PATH="${lar_path}"
      fi
    else
      status="fail"; details="LAR DLFileEntry not found"
    fi
  fi

  bundle_log_collect "${log_offset}" "${log_file}"
  result_add "${label}" "${status}" "$(timer_elapsed "${timer}")" \
    "$(bundle_log_summary "${log_file}")" "${details}"
  [ "${status}" = "ok" ]
}

_step_globals_import() {
  local id="$1" portlet="$2" tgt_gid="$3" extras="$4" lar_path="$5"
  local label="globals_import:${id}"
  local timer log_offset log_file
  timer=$(timer_start)
  log_offset=$(bundle_log_mark)
  log_file="${RUN_DIR}/${label//:/_}.bundle.log"

  # Refresh target session — the matching export just polled the DB (no HTTP),
  # so the cookie set up by step_instance / session_login_target may be stale.
  session_refresh_target

  local ns="_${EXPORT_IMPORT_PORTLET_ID}_"
  local action_url tgt_plid upload_response
  action_url="$(_global_action_url target)"

  # The form requires plid, but SOURCE_PLID is a source-company layout that
  # doesn't exist in the new company. Grab any layout in the target — the
  # plid is used only for ThemeDisplay context, not for the actual import.
  tgt_plid="$(_company_any_plid "${NEW_INSTANCE_COMPANY_ID}")"
  if [ -z "${tgt_plid}" ] || [ "${tgt_plid}" = "NULL" ]; then
    bundle_log_collect "${log_offset}" "${log_file}"
    result_add "${label}" "fail" "$(timer_elapsed "${timer}")" \
      "$(bundle_log_summary "${log_file}")" "no plid in target company"
    return 1
  fi

  # cmd=add_temp uploads the LAR into the portlet's import temp folder.
  upload_response="${RUN_DIR}/${label//:/_}.upload.json"
  curl -s -o "${upload_response}" -b "${TARGET_COOKIE_JAR}" --url "${action_url}" \
    -F "${ns}cmd=add_temp" \
    -F "${ns}groupId=${tgt_gid}" \
    -F "${ns}plid=${tgt_plid}" \
    -F "${ns}portletResource=${portlet}" \
    -F "${ns}redirect=${TARGET_BASE_URL}/web/guest" \
    -F "${ns}file=@${lar_path}" \
    -F "p_auth=${TARGET_P_AUTH}"

  local pre_task_id
  pre_task_id="$(mysql_q "SELECT IFNULL(MAX(backgroundTaskId),0) FROM BackgroundTask;")"

  # cmd=import kicks off the actual portlet-data import as a BackgroundTask.
  local import_response="${RUN_DIR}/${label//:/_}.response.html"
  local -a fields=(
    -F "p_auth=${TARGET_P_AUTH}"
  )
  local arg val
  while IFS= read -r arg; do
    [ -z "${arg}" ] && continue
    if [ "${arg}" = "-F" ]; then
      IFS= read -r val
      fields+=(-F "${val}")
    fi
  done < <(_global_form_fields "${ns}" "${portlet}" "${tgt_gid}" "import" "${tgt_plid}" "${extras}" "" "${TARGET_BASE_URL}")

  curl -s -o "${import_response}" -b "${TARGET_COOKIE_JAR}" --url "${action_url}" "${fields[@]}"

  local task_id status="ok" details=""
  task_id="$(_wait_for_task "${pre_task_id}" "%PortletImportBackgroundTaskExecutor")"
  if [ -z "${task_id}" ]; then
    bundle_log_collect "${log_offset}" "${log_file}"
    result_add "${label}" "fail" "$(timer_elapsed "${timer}")" \
      "$(bundle_log_summary "${log_file}")" "no BackgroundTask"
    return 1
  fi
  log_info "Tracking globals import task ${task_id}"

  _poll_task "${task_id}" status details

  bundle_log_collect "${log_offset}" "${log_file}"
  result_add "${label}" "${status}" "$(timer_elapsed "${timer}")" \
    "$(bundle_log_summary "${log_file}")" "task=${task_id} ${details}"
  [ "${status}" = "ok" ] || [ "${status}" = "warn" ]
}

# Spin for up to 30s waiting for a new BackgroundTask row to appear with the
# matching executor class. Returns the task id or empty string.
_wait_for_task() {
  local pre_task_id="$1" executor_like="$2"
  local task_id="" i
  for i in $(seq 1 30); do
    task_id="$(mysql_q "SELECT MAX(backgroundTaskId) FROM BackgroundTask WHERE backgroundTaskId > ${pre_task_id} AND taskExecutorClassName LIKE '${executor_like}';")"
    if [ -n "${task_id}" ] && [ "${task_id}" != "NULL" ]; then
      echo "${task_id}"
      return
    fi
    sleep 1
  done
  echo ""
}

# Poll a BackgroundTask until it reaches a terminal status. Sets the named
# status and details variables in the caller's scope (nameref).
_poll_task() {
  local task_id="$1"
  local -n _st="$2" _det="$3"
  local elapsed_poll=0 task_status
  while :; do
    task_status="$(mysql_q "SELECT status FROM BackgroundTask WHERE backgroundTaskId=${task_id};")"
    case "${task_status}" in
      0|1|4)
        if [ "${elapsed_poll}" -ge "${POLL_TIMEOUT}" ]; then
          _st="fail"; _det="timeout after ${POLL_TIMEOUT}s, status=${task_status}"
          return
        fi
        sleep "${POLL_SECONDS}"
        elapsed_poll=$((elapsed_poll + POLL_SECONDS))
        ;;
      3) _det="succeeded"; return ;;
      6) _st="warn"; _det="completed with errors"; return ;;
      2|5)
        _st="fail"
        local msg
        msg=$(mysql_q "SELECT statusMessage FROM BackgroundTask WHERE backgroundTaskId=${task_id};" | head -c 80)
        _det="status=${task_status} ${msg}"
        return
        ;;
      *) _st="fail"; _det="unexpected status=${task_status}"; return ;;
    esac
  done
}
