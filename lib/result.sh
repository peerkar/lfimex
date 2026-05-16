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
  # STATUS column is 8 chars wide to fit "warn(6)" / "fail(2)" etc. Steps that
  # don't go through a BackgroundTask just write "ok" / "fail" / "skip" as
  # before and stay well within the width.
  local divider="+------------------------------+----------+----------+---------------------+"
  printf '\n%s\n' "${divider}"
  printf '| %-28s | %-8s | %-8s | %-19s |\n' "STEP" "STATUS" "ELAPSED" "LOG"
  printf '%s\n' "${divider}"
  local row step status elapsed logsum details
  for row in "${RESULT_ROWS[@]}"; do
    IFS='|' read -r step status elapsed logsum details <<< "${row}"
    [ "${step}" = "TOTAL" ] && continue
    printf '| %-28s | %-8s | %-8s | %-19s |\n' \
      "${step:0:28}" "${status:0:8}" "$(timer_human "${elapsed}")" "${logsum:0:19}"
  done
  printf '%s\n' "${divider}"
}

# Source-vs-target row-count comparison embedded inside the grand summary.
# Walks SELECTED_ASSETS, runs each asset's registered count query (from
# config/asset_catalog.sh's asset_count_register calls) against both
# SOURCE_GROUP_ID and NEW_SITE_GROUP_ID via mysql_q, and prints the result.
# Silently no-ops when there's no target site (e.g. --export-only) or no
# count queries registered, so it doesn't add noise in those runs. Also
# appends machine-readable ASSET_COUNT lines to summary.tsv for later
# scripting.
_result_print_asset_counts() {
  [ -z "${NEW_SITE_GROUP_ID:-}" ] && return 0
  [ -z "${SELECTED_ASSETS+x}" ] && return 0
  [ "${#SELECTED_ASSETS[@]}" -eq 0 ] && return 0

  # Build rows first so the header is suppressed when nothing has a query.
  local -a rows=()
  local asset sql date_col date_clause src_sql tgt_sql src tgt diff
  for asset in "${SELECTED_ASSETS[@]}"; do
    sql="${ASSET_COUNT_QUERY[${asset}]:-}"
    [ -z "${sql}" ] && continue
    date_col="${ASSET_COUNT_DATE_COLUMN[${asset}]:-}"
    # Build the date-range clause when --filter date-range was active AND
    # this asset registered a date column. Either condition missing means
    # we count every row, matching the test files' own date_filter() semantics.
    if [ -n "${FROM_DATE:-}" ] && [ -n "${TO_DATE:-}" ] && [ -n "${date_col}" ]; then
      date_clause="AND ${date_col} BETWEEN '${FROM_DATE} 00:00:00' AND '${TO_DATE} 23:59:59'"
    else
      date_clause=""
    fi
    src_sql="${sql//__GID__/${SOURCE_GROUP_ID}}"
    src_sql="${src_sql//__DATE_FILTER__/${date_clause}}"
    tgt_sql="${sql//__GID__/${NEW_SITE_GROUP_ID}}"
    tgt_sql="${tgt_sql//__DATE_FILTER__/${date_clause}}"
    src="$(mysql_q "${src_sql}" 2>/dev/null)"
    tgt="$(mysql_q "${tgt_sql}" 2>/dev/null)"
    src="${src:-0}"
    tgt="${tgt:-0}"
    diff=$((tgt - src))
    rows+=("${asset}|${src}|${tgt}|${diff}")
  done

  [ "${#rows[@]}" -eq 0 ] && return 0

  # Two blank lines separate the asset-counts block from the preceding run
  # stats block; the caller (result_grand_summary) emits the closing bar.
  printf '\n\n'
  if [ -n "${FROM_DATE:-}" ] && [ -n "${TO_DATE:-}" ]; then
    printf '  %sASSET COUNTS%s (source vs target, %s..%s)\n' \
      "${COLOR_BOLD}" "${COLOR_RESET}" "${FROM_DATE}" "${TO_DATE}"
  else
    printf '  %sASSET COUNTS%s (source vs target)\n' \
      "${COLOR_BOLD}" "${COLOR_RESET}"
  fi
  printf '  ----------------------------------------------------------------\n'
  local row label diff_display c_diff
  for row in "${rows[@]}"; do
    IFS='|' read -r label src tgt diff <<< "${row}"
    if [ "${diff}" -eq 0 ]; then
      diff_display="-"; c_diff=""
    elif [ "${diff}" -gt 0 ]; then
      diff_display="+${diff}"; c_diff="${COLOR_YELLOW}"
    else
      diff_display="${diff}"; c_diff="${COLOR_RED}"
    fi
    printf '  %-22s  %8s  →  %-8s  %s%s%s\n' \
      "${label:0:22}" "${src}" "${tgt}" "${c_diff}" "${diff_display}" "${COLOR_RESET}"
    printf 'ASSET_COUNT\t%s\t%s\t%s\t%s\n' "${label}" "${src}" "${tgt}" "${diff}" \
      >> "${RUN_DIR}/summary.tsv"
  done
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
    # Status can be "<kind>(<bg-task-int>)"; bucket by the kind only.
    local status_kind="${status%%(*}"
    case "${status_kind}" in
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

  # --- Section 1: verdict (boxed) ---
  printf '\n%s\n' "${bar}"
  printf '  STATUS: %s%s%s%s\n' \
    "${COLOR_BOLD}" "${verdict_color}" "${verdict}" "${COLOR_RESET}"
  printf '%s\n' "${bar}"

  # --- Section 2: run stats (indented block, no inner bar) ---
  printf '\n'
  printf '  %sRUN STATS%s\n' "${COLOR_BOLD}" "${COLOR_RESET}"
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
  printf '  Total     : %s\n' "$(timer_human "${total_elapsed}")"
  printf '  Results   : %s\n' "${RUN_DIR}"

  # --- Section 3: asset counts (optional, prepends its own blank lines) ---
  _result_print_asset_counts

  # Closing bar with a blank line in front
  printf '\n%s\n' "${bar}"

  printf 'STEPS_OK\t%d\nSTEPS_WARN\t%d\nSTEPS_FAIL\t%d\nSTEPS_SKIP\t%d\nCHECKS_PASSED\t%d\nCHECKS_FAILED\t%d\nCHECKS_IGNORED\t%d\nVERDICT\t%s\n' \
    "${ok}" "${warn}" "${fail}" "${skip}" \
    "${checks_passed}" "${checks_failed}" "${checks_ignored}" \
    "${verdict}" >> "${RUN_DIR}/summary.tsv"

  [ "${verdict}" = "PASS" ]
}
