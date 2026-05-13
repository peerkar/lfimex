#!/bin/bash
# Aggregate per-step results and print a summary table.
#
# Each call to result_add appends one row. result_print renders the full table.
# The same rows are also appended to ${RUN_DIR}/summary.tsv for later inspection.

RESULT_ROWS=()

# ANSI color helpers, disabled when NO_COLOR is set or stdout isn't a TTY.
if [ -z "${NO_COLOR:-}" ] && [ -t 1 ]; then
  COLOR_RED=$'\033[31m'
  COLOR_GREEN=$'\033[32m'
  COLOR_YELLOW=$'\033[33m'
  COLOR_GRAY=$'\033[90m'
  COLOR_BOLD=$'\033[1m'
  COLOR_RESET=$'\033[0m'
else
  COLOR_RED=''; COLOR_GREEN=''; COLOR_YELLOW=''; COLOR_GRAY=''; COLOR_BOLD=''; COLOR_RESET=''
fi

result_init() {
  mkdir -p "${RUN_DIR}"
  : > "${RUN_DIR}/summary.tsv"
  printf 'STEP\tSTATUS\tELAPSED\tLOG_ERRORS\tDETAILS\n' >> "${RUN_DIR}/summary.tsv"
}

# Usage: result_add <step> <ok|fail|skip> <elapsed-seconds> <log-summary> <details>
#
# Details are surfaced live via log_info so users see them as each step
# finishes, and they're persisted to summary.tsv for offline inspection.
# They are deliberately NOT rendered in the on-screen summary table.
result_add() {
  local step="$1" status="$2" elapsed="$3" logsum="$4" details="$5"
  RESULT_ROWS+=("${step}|${status}|${elapsed}|${logsum}|${details}")
  printf '%s\t%s\t%s\t%s\t%s\n' "${step}" "${status}" "${elapsed}" "${logsum}" "${details}" \
    >> "${RUN_DIR}/summary.tsv"
  if [ -n "${details}" ] && [ "${step}" != "TOTAL" ]; then
    log_info "${step} [${status}]: ${details}"
  fi
}

result_print() {
  local divider="+------------------------------+--------+----------+---------------------+"
  printf '\n%s\n' "${divider}"
  printf '| %-28s | %-6s | %-8s | %-19s |\n' "STEP" "STATUS" "ELAPSED" "LOG"
  printf '%s\n' "${divider}"
  local row step status elapsed logsum details
  for row in "${RESULT_ROWS[@]}"; do
    IFS='|' read -r step status elapsed logsum details <<< "${row}"
    [ "${step}" = "TOTAL" ] && continue
    printf '| %-28s | %-6s | %-8s | %-19s |\n' \
      "${step:0:28}" "${status:0:6}" "$(timer_human "${elapsed}")" "${logsum:0:19}"
  done
  printf '%s\n' "${divider}"
}

# Scan RESULT_ROWS and print a high-level rollup: per-step status counts,
# total validation checks (passed / failed / ignored), and an overall verdict.
# Total elapsed comes from the TOTAL row appended by lfimex.
result_grand_summary() {
  local ok=0 warn=0 fail=0 skip=0
  local checks_passed=0 checks_failed=0 checks_ignored=0
  local total_elapsed=0
  local row step status elapsed logsum details

  for row in "${RESULT_ROWS[@]}"; do
    IFS='|' read -r step status elapsed logsum details <<< "${row}"
    case "${status}" in
      ok)   ok=$((ok + 1)) ;;
      warn) warn=$((warn + 1)) ;;
      fail) fail=$((fail + 1)) ;;
      skip) skip=$((skip + 1)) ;;
    esac
    if [ "${step}" = "TOTAL" ]; then total_elapsed="${elapsed}"; continue; fi
    # Parse "N/M passed( (K ignored))?" out of validate rows' details.
    if [[ "${step}" == validate:* ]]; then
      if [[ "${details}" =~ ([0-9]+)/([0-9]+)\ passed ]]; then
        local got total
        got="${BASH_REMATCH[1]}"; total="${BASH_REMATCH[2]}"
        checks_passed=$((checks_passed + got))
        checks_failed=$((checks_failed + total - got))
      fi
      if [[ "${details}" =~ \(([0-9]+)\ ignored\) ]]; then
        checks_ignored=$((checks_ignored + BASH_REMATCH[1]))
      fi
    fi
  done

  local verdict verdict_color
  if [ "${fail}" -gt 0 ] || [ "${checks_failed}" -gt 0 ]; then
    verdict="FAIL"; verdict_color="${COLOR_RED}"
  elif [ "${warn}" -gt 0 ]; then
    verdict="WARN"; verdict_color="${COLOR_YELLOW}"
  else
    verdict="PASS"; verdict_color="${COLOR_GREEN}"
  fi

  # Per-count colors: highlight non-zero fails / warns in their respective
  # colors so a quick glance carries the most important signal.
  local c_warn c_fail c_check_fail c_check_ignored
  [ "${warn}" -gt 0 ]            && c_warn="${COLOR_YELLOW}"      || c_warn=""
  [ "${fail}" -gt 0 ]            && c_fail="${COLOR_RED}"         || c_fail=""
  [ "${checks_failed}" -gt 0 ]   && c_check_fail="${COLOR_RED}"   || c_check_fail=""
  [ "${checks_ignored}" -gt 0 ]  && c_check_ignored="${COLOR_GRAY}" || c_check_ignored=""

  local bar="${COLOR_BOLD}================================================================${COLOR_RESET}"
  printf '\n%s\n' "${bar}"
  printf '  STATUS: %s%s%s%s\n' \
    "${COLOR_BOLD}" "${verdict_color}" "${verdict}" "${COLOR_RESET}"
  printf '  ----------------------------------------------------------------\n'
  printf '  Steps     : %d ok, %s%d warn%s, %s%d fail%s, %d skip\n' \
    "${ok}" \
    "${c_warn}" "${warn}" "${COLOR_RESET}" \
    "${c_fail}" "${fail}" "${COLOR_RESET}" \
    "${skip}"
  local checks_total=$((checks_passed + checks_failed + checks_ignored))
  if [ "${checks_total}" -gt 0 ]; then
    printf '  DB checks : %d passed, %s%d failed%s, %s%d ignored%s (%d total)\n' \
      "${checks_passed}" \
      "${c_check_fail}" "${checks_failed}" "${COLOR_RESET}" \
      "${c_check_ignored}" "${checks_ignored}" "${COLOR_RESET}" \
      "${checks_total}"
  else
    printf '  DB checks : (no validation phases ran)\n'
  fi
  printf '  Results   : %s\n' "${RUN_DIR}"
  printf '  Total     : %s\n' "$(timer_human "${total_elapsed}")"
  printf '%s\n' "${bar}"

  printf 'STEPS_OK\t%d\nSTEPS_WARN\t%d\nSTEPS_FAIL\t%d\nSTEPS_SKIP\t%d\nCHECKS_PASSED\t%d\nCHECKS_FAILED\t%d\nCHECKS_IGNORED\t%d\nVERDICT\t%s\n' \
    "${ok}" "${warn}" "${fail}" "${skip}" \
    "${checks_passed}" "${checks_failed}" "${checks_ignored}" \
    "${verdict}" >> "${RUN_DIR}/summary.tsv"

  [ "${verdict}" = "PASS" ]
}
