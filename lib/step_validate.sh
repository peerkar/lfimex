#!/bin/bash
# Step 5: DB-level validation.
#
#   step_validate <asset_id...>      runs the compare.sh test mapped to each
#                                    selected asset (ASSET_TEST[<id>]).
#                                    Skips assets with no mapping.
#
#   step_validate_extras <test...>   runs compare.sh tests by name. Used for
#                                    site-wide checks (friendly_url, page,
#                                    navigation_menu, …) that aren't tied to
#                                    any asset id.
#
# Source/target sites are resolved from their groupIds via Group_.groupKey,
# which is what compare.sh expects for --source-site / --target-site.

step_validate() {
  local -a asset_list=("$@")
  local id test_name

  _resolve_validate_keys || return 0

  for id in "${asset_list[@]}"; do
    test_name="${ASSET_TEST[${id}]:-}"
    if [ -z "${test_name}" ]; then
      _validate_skip_no_test "validate:${id}"
      continue
    fi
    _run_compare_test "validate:${id}" "${test_name}" \
      "${_VALIDATE_SOURCE_KEY}" "${_VALIDATE_TARGET_KEY}"
  done
}

step_validate_extras() {
  local -a test_names=("$@")
  local test_name

  _resolve_validate_keys || return 0

  for test_name in "${test_names[@]}"; do
    _run_compare_test "validate:${test_name}" "${test_name}" \
      "${_VALIDATE_SOURCE_KEY}" "${_VALIDATE_TARGET_KEY}"
  done
}

# Resolve source/target site keys once per step. Sets the globals
# _VALIDATE_SOURCE_KEY and _VALIDATE_TARGET_KEY (globals — must not be
# called inside a $() subshell, since those wouldn't propagate back).
# Returns non-zero (after recording a "skip" row) when there's no target.
_resolve_validate_keys() {
  if [ -z "${NEW_SITE_GROUP_ID:-}" ]; then
    local timer log_offset log_file
    timer=$(timer_start)
    log_offset=$(bundle_log_mark)
    log_file="${RUN_DIR}/validate.bundle.log"
    bundle_log_collect "${log_offset}" "${log_file}"
    result_add "validate" "skip" "$(timer_elapsed "${timer}")" \
      "$(bundle_log_summary "${log_file}")" "no destination site"
    return 1
  fi

  _VALIDATE_SOURCE_KEY="$(group_site_key "${SOURCE_GROUP_ID}")"
  _VALIDATE_TARGET_KEY="$(group_site_key "${NEW_SITE_GROUP_ID}")"
  if [ -z "${_VALIDATE_SOURCE_KEY}" ] || [ -z "${_VALIDATE_TARGET_KEY}" ]; then
    log_warn "Could not resolve site keys (source=${_VALIDATE_SOURCE_KEY}, target=${_VALIDATE_TARGET_KEY})"
    return 1
  fi
  log_info "Validating source=${SOURCE_COMPANY_WEB_ID}/${_VALIDATE_SOURCE_KEY}, target=${NEW_INSTANCE_WEB_ID:-${TARGET_COMPANY_WEB_ID}}/${_VALIDATE_TARGET_KEY}"
}

_validate_skip_no_test() {
  local label="$1"
  local timer log_offset log_file
  timer=$(timer_start)
  log_offset=$(bundle_log_mark)
  log_file="${RUN_DIR}/${label//:/_}.bundle.log"
  bundle_log_collect "${log_offset}" "${log_file}"
  result_add "${label}" "skip" "$(timer_elapsed "${timer}")" \
    "$(bundle_log_summary "${log_file}")" "no validation test mapped"
}

# Run one compare.sh test, record one result row.
_run_compare_test() {
  local label="$1" test_name="$2" source_key="$3" target_key="$4"
  local timer log_offset log_file out_file rc

  timer=$(timer_start)
  log_offset=$(bundle_log_mark)
  log_file="${RUN_DIR}/${label//:/_}.bundle.log"
  out_file="${RUN_DIR}/${label//:/_}.log"

  local -a compare_args=(
    --source-company-web-id "${SOURCE_COMPANY_WEB_ID}"
    --source-site "${source_key}"
    --target-company-web-id "${NEW_INSTANCE_WEB_ID:-${TARGET_COMPANY_WEB_ID}}"
    --target-site "${target_key}"
    --tests "${test_name}"
  )
  if [ "${FILTER:-all}" = "date-range" ]; then
    compare_args+=(--from-date "${FROM_DATE}" --to-date "${TO_DATE}")
  fi
  if [ -n "${IGNORE_PATTERNS:-}" ]; then
    compare_args+=(--ignore-tests "${IGNORE_PATTERNS}")
  fi

  set +e
  LOG_FILE="${RUN_DIR}/${label//:/_}.compare.log" \
    "${COMPARE_SH}" "${compare_args[@]}" > "${out_file}" 2>&1
  rc=$?
  set -e

  bundle_log_collect "${log_offset}" "${log_file}"

  # Pass/fail/ignored counts come from compare.sh's footer line; strip ANSI first.
  local summary_line failed total ignored=0
  summary_line="$(sed 's/\x1b\[[0-9;]*m//g' "${out_file}" | grep -E 'checks passed|checks failed' | tail -n1)"
  if [[ "${summary_line}" =~ ([0-9]+)\ of\ ([0-9]+)\ checks\ failed ]]; then
    failed="${BASH_REMATCH[1]}"; total="${BASH_REMATCH[2]}"
  elif [[ "${summary_line}" =~ All\ ([0-9]+)\ checks\ passed ]]; then
    failed=0; total="${BASH_REMATCH[1]}"
  else
    failed="?"; total="?"
  fi
  if [[ "${summary_line}" =~ \(([0-9]+)\ ignored\) ]]; then
    ignored="${BASH_REMATCH[1]}"
  fi

  local ign_suffix="" status details
  [ "${ignored}" -gt 0 ] && ign_suffix=" (${ignored} ignored)"

  if [ "${rc}" -eq 0 ]; then
    status="ok"; details="test=${test_name} | ${total}/${total} passed${ign_suffix}"
  else
    status="fail"
    local first_fail
    first_fail=$(sed 's/\x1b\[[0-9;]*m//g' "${out_file}" | grep -m1 -E '^\s+✗ ' | sed -E 's/^\s+✗\s+//' | head -c 80)
    details="test=${test_name} | $((total - failed))/${total} passed${ign_suffix} | first fail: ${first_fail}"
  fi

  result_add "${label}" "${status}" "$(timer_elapsed "${timer}")" \
    "$(bundle_log_summary "${log_file}")" "${details}"
}
