#!/bin/bash
# Step 0: copy OSGi config files from OSGI_CONFIGS_DIR into the live
# Liferay's osgi/configs/ directory. ConfigAdmin watches that folder and
# applies the new values automatically; we give it a couple of seconds
# before the rest of the pipeline runs.
#
# Controlled by COPY_OSGI_CONFIGS (default 1). The CLI flag --skip-osgi
# flips it to 0 so the source files are left untouched.

step_osgi() {
  local timer log_offset log_file
  timer=$(timer_start)
  log_offset=$(bundle_log_mark)
  log_file="${RUN_DIR}/osgi.bundle.log"

  if [ "${COPY_OSGI_CONFIGS:-1}" != "1" ]; then
    bundle_log_collect "${log_offset}" "${log_file}"
    result_add "osgi_configs" "skip" "$(timer_elapsed "${timer}")" \
      "$(bundle_log_summary "${log_file}")" "COPY_OSGI_CONFIGS=0"
    return 0
  fi

  local src="${OSGI_CONFIGS_DIR}"
  local dst="${BUNDLES_DIR}/osgi/configs"

  if [ ! -d "${src}" ]; then
    bundle_log_collect "${log_offset}" "${log_file}"
    result_add "osgi_configs" "skip" "$(timer_elapsed "${timer}")" \
      "$(bundle_log_summary "${log_file}")" "source directory missing: ${src}"
    return 0
  fi
  if [ ! -d "${dst}" ]; then
    bundle_log_collect "${log_offset}" "${log_file}"
    result_add "osgi_configs" "fail" "$(timer_elapsed "${timer}")" \
      "$(bundle_log_summary "${log_file}")" "destination missing: ${dst}"
    return 1
  fi

  local count
  count=$(find "${src}" -maxdepth 1 -type f | wc -l)
  if [ "${count}" -eq 0 ]; then
    bundle_log_collect "${log_offset}" "${log_file}"
    result_add "osgi_configs" "skip" "$(timer_elapsed "${timer}")" \
      "$(bundle_log_summary "${log_file}")" "no files in ${src}"
    return 0
  fi

  log_info "Copying ${count} OSGi config file(s) from ${src} to ${dst}"
  cp -f "${src}"/* "${dst}/"

  # Give ConfigAdmin a beat to register the new values before phases that
  # depend on them (e.g. export limits, search reindex behavior) kick off.
  sleep 2

  bundle_log_collect "${log_offset}" "${log_file}"
  result_add "osgi_configs" "ok" "$(timer_elapsed "${timer}")" \
    "$(bundle_log_summary "${log_file}")" "copied ${count} file(s) to ${dst}"
}
