#!/bin/bash
# Step 6: tear down the test target.
#
# Runs only when CLEANUP_INSTANCE=1. The actions vary by INSTANCE_MODE:
#
#   create — delete the new Company via lib/groovy/delete-instance.groovy.
#            Liferay cascades the delete to every group/layout/user/content row
#            inside that company, so we don't need a separate site delete.
#
#   reuse  — delete only NEW_SITE_GROUP_ID via the headless admin REST API.
#            The source company is left untouched (it isn't ours to delete).

DELETE_INSTANCE_SCRIPT="${DELETE_INSTANCE_SCRIPT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/groovy/delete-instance.groovy}"

step_cleanup() {
  if [ "${CLEANUP_INSTANCE:-0}" != "1" ]; then return 0; fi

  local timer log_offset log_file
  timer=$(timer_start)
  log_offset=$(bundle_log_mark)
  log_file="${RUN_DIR}/cleanup.bundle.log"

  case "${INSTANCE_MODE:-reuse}" in
    create) _step_cleanup_company "${timer}" "${log_offset}" "${log_file}" ;;
    reuse)  _step_cleanup_site    "${timer}" "${log_offset}" "${log_file}" ;;
    *)      bundle_log_collect "${log_offset}" "${log_file}"
            result_add "cleanup" "skip" "$(timer_elapsed "${timer}")" \
              "$(bundle_log_summary "${log_file}")" "unknown INSTANCE_MODE"
            return 0 ;;
  esac
}

_step_cleanup_company() {
  local timer="$1" log_offset="$2" log_file="$3"

  if [ -z "${NEW_INSTANCE_COMPANY_ID:-}" ]; then
    bundle_log_collect "${log_offset}" "${log_file}"
    result_add "cleanup" "skip" "$(timer_elapsed "${timer}")" \
      "$(bundle_log_summary "${log_file}")" "no NEW_INSTANCE_COMPANY_ID"
    return 0
  fi

  log_info "Deleting company ${NEW_INSTANCE_COMPANY_ID} via blade sh"

  local rendered="${RUN_DIR}/delete-instance.rendered.groovy"
  sed -e "s|__COMPANY_ID__|${NEW_INSTANCE_COMPANY_ID}|g" "${DELETE_INSTANCE_SCRIPT}" > "${rendered}"

  local blade_out="${RUN_DIR}/cleanup.blade.log"
  set +e
  blade sh "sh ${EXECUTE_SCRIPT_GOSH} ${rendered} groovy" > "${blade_out}" 2>&1
  local rc=$?
  set -e

  bundle_log_collect "${log_offset}" "${log_file}"

  if grep -q "DELETED_COMPANY_ID=${NEW_INSTANCE_COMPANY_ID}" "${blade_out}"; then
    result_add "cleanup" "ok" "$(timer_elapsed "${timer}")" \
      "$(bundle_log_summary "${log_file}")" "deleted company ${NEW_INSTANCE_COMPANY_ID}"
  else
    local err
    err=$(grep -oE 'ERROR=[^$]+' "${blade_out}" | head -n1 | cut -c1-100)
    result_add "cleanup" "fail" "$(timer_elapsed "${timer}")" \
      "$(bundle_log_summary "${log_file}")" \
      "company delete failed (blade rc=${rc}); ${err:-see cleanup.blade.log}"
  fi
}

_step_cleanup_site() {
  local timer="$1" log_offset="$2" log_file="$3"

  if [ -z "${NEW_SITE_GROUP_ID:-}" ]; then
    bundle_log_collect "${log_offset}" "${log_file}"
    result_add "cleanup" "skip" "$(timer_elapsed "${timer}")" \
      "$(bundle_log_summary "${log_file}")" "no NEW_SITE_GROUP_ID"
    return 0
  fi

  # User-supplied site: we didn't create it, so we don't delete it. This is
  # what makes --target-group-id safe to combine with --cleanup.
  if [ -n "${TARGET_GROUP_ID:-}" ]; then
    bundle_log_collect "${log_offset}" "${log_file}"
    result_add "cleanup" "skip" "$(timer_elapsed "${timer}")" \
      "$(bundle_log_summary "${log_file}")" \
      "preserving user-supplied TARGET_GROUP_ID=${TARGET_GROUP_ID}"
    return 0
  fi

  log_info "Deleting site groupId=${NEW_SITE_GROUP_ID} via headless-admin-site"

  local response="${RUN_DIR}/cleanup.response.json"
  local http_code
  http_code=$(curl -s -u "${TARGET_USERNAME}:${TARGET_PASSWORD}" \
    -X DELETE \
    -o "${response}" \
    -w '%{http_code}' \
    "${TARGET_BASE_URL}/o/headless-admin-site/v1.0/sites/${NEW_SITE_GROUP_ID}")

  bundle_log_collect "${log_offset}" "${log_file}"

  if [ "${http_code}" = "204" ] || [ "${http_code}" = "200" ]; then
    result_add "cleanup" "ok" "$(timer_elapsed "${timer}")" \
      "$(bundle_log_summary "${log_file}")" "deleted site ${NEW_SITE_GROUP_ID}"
  else
    local msg
    msg=$(grep -oE '"title":"[^"]*"|"message":"[^"]*"' "${response}" | head -n1 | cut -c1-60)
    result_add "cleanup" "fail" "$(timer_elapsed "${timer}")" \
      "$(bundle_log_summary "${log_file}")" "HTTP ${http_code} ${msg}"
  fi
}
