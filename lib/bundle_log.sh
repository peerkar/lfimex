#!/bin/bash
# Capture ERROR/WARN lines written to the Liferay log during a phase.
#
# Usage:
#   OFFSET=$(bundle_log_mark)
#   ... do work ...
#   bundle_log_collect "${OFFSET}" "${PHASE}.log"   # writes any new ERR/WARN
#
# The offset is the byte size of the log file when the phase started; we tail
# from there to the current end to capture only lines emitted by this phase.

# Resolve today's Liferay log file inside LIFERAY_LOG_DIR. Done at call time
# (not when config is sourced) so a run that crosses midnight reads the
# next day's file instead of staying pinned to the start-of-run date.
_liferay_log_file() {
  echo "${LIFERAY_LOG_DIR}/liferay.$(date -u +%Y-%m-%d).log"
}

bundle_log_mark() {
  local log_file
  log_file="$(_liferay_log_file)"
  if [ -f "${log_file}" ]; then stat -c %s "${log_file}"; else echo 0; fi
}

bundle_log_collect() {
  local offset="$1" out="$2"
  local log_file
  log_file="$(_liferay_log_file)"
  if [ ! -f "${log_file}" ]; then echo "(no liferay log at ${log_file})" > "${out}"; return 0; fi
  local current
  current="$(stat -c %s "${log_file}")"
  if [ "${current}" -le "${offset}" ]; then : > "${out}"; return 0; fi
  # Liferay log header format: "YYYY-MM-DD HH:MM:SS.fff LEVEL [thread][logger] msg".
  # We match the LEVEL slot directly so stack-trace lines that mention the word
  # "ERROR" or "warn" inside a message don't falsely trip the capture. Blocks
  # whose header matches LIFERAY_LOG_IGNORE_REGEX are skipped entirely (they
  # cover known Liferay false positives like the popup-view.jsp error every
  # ExportImportPortlet action triggers).
  tail -c "+$((offset + 1))" "${log_file}" \
    | awk -v ignore="${LIFERAY_LOG_IGNORE_REGEX}" '
        /^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9:.]+ (ERROR|WARN) +\[/ {
          capture=1; printed=0
          if (ignore != "" && $0 ~ ignore) capture=0
        }
        capture {
          if (printed >= 50) next
          print
          printed++
          if ($0 ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}/ && printed>1) capture=0
        }
      ' > "${out}"
}

# One-line LOG-column summary for a captured bundle log.
#
# Output rules (signal-first):
#   - Empty string when the captured log has no ERROR/WARN blocks. That
#     covers both an empty file (nothing landed in the window) AND a
#     non-empty file where every ERROR/WARN matched LIFERAY_LOG_IGNORE_REGEX
#     and got filtered out. The TSV and on-screen table both render as a
#     blank cell.
#   - "ERR=n" / "WARN=n" / "ERR=n WARN=n" otherwise. The zero half is
#     omitted so "WARN=3" reads cleanly instead of "ERR=0 WARN=3".
#   - When at least one ERROR is present, append " | <first error message>"
#     with the Liferay header prefix stripped, so the table can show the
#     class/message directly. Trimmed to ~120 chars; result_print further
#     clips to the column width.
bundle_log_summary() {
  local file="$1"
  [ ! -s "${file}" ] && { echo ""; return; }
  local err warn
  err=$(grep -cE '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9:.]+ ERROR +\[' "${file}" || true)
  warn=$(grep -cE '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9:.]+ WARN +\[' "${file}" || true)
  [ "${err}" -eq 0 ] && [ "${warn}" -eq 0 ] && { echo ""; return; }

  local parts=""
  [ "${err}" -gt 0 ] && parts="ERR=${err}"
  if [ "${warn}" -gt 0 ]; then
    [ -n "${parts}" ] && parts="${parts} WARN=${warn}" || parts="WARN=${warn}"
  fi

  local first
  first=$(grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9:.]+ ERROR +\[' "${file}" \
          | head -n1 \
          | sed -E 's/^[0-9-]+ [0-9:.]+ +(ERROR|WARN) +\[[^]]*\]\[[^]]*\] +//' \
          | cut -c1-120)
  if [ -n "${first}" ]; then
    echo "${parts} | ${first}"
  else
    echo "${parts}"
  fi
}
