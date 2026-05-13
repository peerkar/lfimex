#!/bin/bash
# Step 2: target portal instance.
#
# INSTANCE_MODE controls behavior:
#
#   reuse  (default) — use the source company; the rest of the pipeline runs
#                      against the same Liferay instance.
#
#   create           — substitute placeholders in lib/groovy/create-instance.groovy
#                      and run it via `blade sh < <rendered>`. blade interprets
#                      stdin as a Groovy script executed in the Liferay JVM;
#                      script println output comes back on stdout, where we
#                      grep for INSTANCE_COMPANY_ID=.

CREATE_INSTANCE_SCRIPT="${CREATE_INSTANCE_SCRIPT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/groovy/create-instance.groovy}"
EXECUTE_SCRIPT_GOSH="${EXECUTE_SCRIPT_GOSH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/groovy/executeScript.gosh}"

step_instance() {
  local timer log_offset log_file rc=0
  timer=$(timer_start)
  log_offset=$(bundle_log_mark)
  log_file="${RUN_DIR}/instance.bundle.log"

  case "${INSTANCE_MODE:-reuse}" in
    reuse)   _step_instance_reuse  "${timer}" "${log_offset}" "${log_file}" || rc=$? ;;
    create)  _step_instance_create "${timer}" "${log_offset}" "${log_file}" || rc=$? ;;
    *)       log_error "Unknown INSTANCE_MODE='${INSTANCE_MODE}'. Use 'reuse' or 'create'."
             bundle_log_collect "${log_offset}" "${log_file}"
             result_add "create_instance" "fail" "$(timer_elapsed "${timer}")" \
               "$(bundle_log_summary "${log_file}")" "unknown INSTANCE_MODE=${INSTANCE_MODE}"
             return 1 ;;
  esac

  # Publish target-instance routing for the steps that follow (site, import,
  # cleanup). In create mode this points at the new company's virtual host;
  # in reuse mode it equals the source so the same code paths Just Work.
  [ "${rc}" -eq 0 ] && _step_instance_publish_target_routing
  return "${rc}"
}

# Set TARGET_BASE_URL / TARGET_USERNAME / TARGET_PASSWORD so subsequent steps
# can hit the right Liferay company. .localhost virtual hosts resolve to
# 127.0.0.1 via RFC 6761 so no /etc/hosts surgery is needed.
_step_instance_publish_target_routing() {
  if [ "${INSTANCE_MODE:-reuse}" = "create" ]; then
    # Pull the port off BASE_URL (default 80 when none is present).
    local proto_host port
    proto_host="${BASE_URL#*://}"
    port="${proto_host##*:}"
    [ "${port}" = "${proto_host}" ] && port="80"

    TARGET_BASE_URL="http://${NEW_INSTANCE_VIRTUAL_HOST}:${port}"
    TARGET_USERNAME="${NEW_INSTANCE_ADMIN_EMAIL}"
    TARGET_PASSWORD="${NEW_INSTANCE_ADMIN_PASSWORD}"
  else
    TARGET_BASE_URL="${BASE_URL}"
    TARGET_USERNAME="${USERNAME}"
    TARGET_PASSWORD="${PASSWORD}"
  fi
  log_info "Target routing: ${TARGET_BASE_URL} as ${TARGET_USERNAME}"
}

_step_instance_reuse() {
  local timer="$1" log_offset="$2" log_file="$3"

  NEW_INSTANCE_COMPANY_ID="$(mysql_q "SELECT companyId FROM Group_ WHERE groupId=${SOURCE_GROUP_ID};")"
  if [ -z "${NEW_INSTANCE_COMPANY_ID}" ]; then
    bundle_log_collect "${log_offset}" "${log_file}"
    result_add "create_instance" "fail" "$(timer_elapsed "${timer}")" \
      "$(bundle_log_summary "${log_file}")" "could not resolve source companyId"
    return 1
  fi
  NEW_INSTANCE_WEB_ID="$(mysql_q "SELECT webId FROM Company WHERE companyId=${NEW_INSTANCE_COMPANY_ID};")"

  bundle_log_collect "${log_offset}" "${log_file}"
  result_add "create_instance" "skip" "$(timer_elapsed "${timer}")" \
    "$(bundle_log_summary "${log_file}")" \
    "reusing source company ${NEW_INSTANCE_COMPANY_ID} (${NEW_INSTANCE_WEB_ID})"
}

_step_instance_create() {
  local timer="$1" log_offset="$2" log_file="$3"

  # *.localhost is RFC 6761 — resolves to 127.0.0.1 everywhere without
  # /etc/hosts surgery. Append it if a user override dropped it.
  [[ "${NEW_INSTANCE_WEB_ID}"       == *.localhost ]] || NEW_INSTANCE_WEB_ID="${NEW_INSTANCE_WEB_ID}.localhost"
  [[ "${NEW_INSTANCE_VIRTUAL_HOST}" == *.localhost ]] || NEW_INSTANCE_VIRTUAL_HOST="${NEW_INSTANCE_VIRTUAL_HOST}.localhost"
  [[ "${NEW_INSTANCE_MAIL_DOMAIN}"  == *.localhost ]] || NEW_INSTANCE_MAIL_DOMAIN="${NEW_INSTANCE_MAIL_DOMAIN}.localhost"

  if ! command -v blade >/dev/null 2>&1; then
    bundle_log_collect "${log_offset}" "${log_file}"
    result_add "create_instance" "fail" "$(timer_elapsed "${timer}")" \
      "$(bundle_log_summary "${log_file}")" "blade CLI not on PATH"
    return 1
  fi
  if [ ! -f "${CREATE_INSTANCE_SCRIPT}" ]; then
    bundle_log_collect "${log_offset}" "${log_file}"
    result_add "create_instance" "fail" "$(timer_elapsed "${timer}")" \
      "$(bundle_log_summary "${log_file}")" "groovy template missing: ${CREATE_INSTANCE_SCRIPT}"
    return 1
  fi

  # Render the Groovy template into the run dir so the original stays clean
  # for git. Each substitution targets a unique __TOKEN__ name.
  local rendered="${RUN_DIR}/create-instance.rendered.groovy"
  sed \
    -e "s|__WEB_ID__|${NEW_INSTANCE_WEB_ID}|g" \
    -e "s|__VIRTUAL_HOSTNAME__|${NEW_INSTANCE_VIRTUAL_HOST}|g" \
    -e "s|__MAIL_DOMAIN__|${NEW_INSTANCE_MAIL_DOMAIN}|g" \
    -e "s|__ADMIN_PASSWORD__|${NEW_INSTANCE_ADMIN_PASSWORD}|g" \
    -e "s|__ADMIN_SCREEN_NAME__|${NEW_INSTANCE_ADMIN_SCREEN_NAME}|g" \
    -e "s|__ADMIN_EMAIL__|${NEW_INSTANCE_ADMIN_EMAIL}|g" \
    -e "s|__ADMIN_FIRST_NAME__|${NEW_INSTANCE_ADMIN_FIRST_NAME}|g" \
    -e "s|__ADMIN_LAST_NAME__|${NEW_INSTANCE_ADMIN_LAST_NAME}|g" \
    -e "s|__SOURCE_WEB_ID__|${SOURCE_COMPANY_WEB_ID}|g" \
    "${CREATE_INSTANCE_SCRIPT}" > "${rendered}"

  if [ ! -f "${EXECUTE_SCRIPT_GOSH}" ]; then
    bundle_log_collect "${log_offset}" "${log_file}"
    result_add "create_instance" "fail" "$(timer_elapsed "${timer}")" \
      "$(bundle_log_summary "${log_file}")" "gosh wrapper missing: ${EXECUTE_SCRIPT_GOSH}"
    return 1
  fi

  log_info "Creating instance webId=${NEW_INSTANCE_WEB_ID} via blade sh"

  # blade sh forwards arguments verbatim to the Gogo shell. The `sh` Gogo
  # command runs a .gosh file (the wrapper), passing $1=groovy path and
  # $2=language. The wrapper looks up the Scripting service and evaluates
  # the script. See lib/groovy/executeScript.gosh.
  local blade_out="${RUN_DIR}/create-instance.blade.log"
  set +e
  blade sh "sh ${EXECUTE_SCRIPT_GOSH} ${rendered} groovy" > "${blade_out}" 2>&1
  local rc=$?
  set -e

  NEW_INSTANCE_COMPANY_ID="$(grep -oE 'INSTANCE_COMPANY_ID=[0-9]+' "${blade_out}" | head -n1 | cut -d= -f2)"
  if [ -z "${NEW_INSTANCE_COMPANY_ID}" ]; then
    bundle_log_collect "${log_offset}" "${log_file}"
    local err
    err=$(grep -oE 'ERROR=[^$]+' "${blade_out}" | head -n1 | cut -c1-100)
    result_add "create_instance" "fail" "$(timer_elapsed "${timer}")" \
      "$(bundle_log_summary "${log_file}")" \
      "no INSTANCE_COMPANY_ID (blade rc=${rc}); ${err:-see create-instance.blade.log}"
    return 1
  fi

  bundle_log_collect "${log_offset}" "${log_file}"
  result_add "create_instance" "ok" "$(timer_elapsed "${timer}")" \
    "$(bundle_log_summary "${log_file}")" \
    "created company ${NEW_INSTANCE_COMPANY_ID} (${NEW_INSTANCE_WEB_ID})"
}
