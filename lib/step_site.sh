#!/bin/bash
# Step 3: create the destination site via Liferay's headless admin API.
#
# POST /o/headless-admin-site/v1.0/sites with a Site JSON body.
# Authenticates with Basic Auth (the credentials from config.sh).

step_site() {
  local timer log_offset log_file response slug
  timer=$(timer_start)
  log_offset=$(bundle_log_mark)
  log_file="${RUN_DIR}/site.bundle.log"

  if [ -z "${NEW_INSTANCE_COMPANY_ID:-}" ]; then
    bundle_log_collect "${log_offset}" "${log_file}"
    result_add "create_site" "fail" "$(timer_elapsed "${timer}")" \
      "$(bundle_log_summary "${log_file}")" "no target company (step_instance failed)"
    return 1
  fi

  # Site slug derived from RUN_ID so multiple runs don't collide.
  slug="$(echo "${NEW_SITE_NAME}" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9-')"
  [ -z "${slug}" ] && slug="imported-${RUN_ID}"

  # Mirror the source site's locale config onto the new site so LAR imports
  # don't fail locale validation. mysql_q's -N -s output escapes typeSettings
  # newlines as the literal two characters "\n", which is what we split on.
  local src_ts src_locales src_inherit avail_langs_json="" inherit_locales_json=""
  src_ts="$(mysql_q "SELECT typeSettings FROM Group_ WHERE groupId=${SOURCE_GROUP_ID};")"
  src_locales="$(printf '%s' "${src_ts}" | grep -oE 'locales=[^\\]+' | head -1 | cut -d= -f2-)"
  src_inherit="$(printf '%s' "${src_ts}" | grep -oE 'inheritLocales=[^\\]+' | head -1 | cut -d= -f2)"
  if [ -n "${src_locales}" ]; then
    # en_US,fr_FR → "en-US","fr-FR"
    local langs
    langs="$(printf '%s' "${src_locales}" | tr '_' '-' | awk -F, '{
      for (i=1;i<=NF;i++) { printf "%s\"%s\"", (i>1?",":""), $i }
    }')"
    avail_langs_json=",\"locales\":[${langs}]"
  fi
  if [ "${src_inherit}" = "false" ] || [ "${src_inherit}" = "true" ]; then
    inherit_locales_json=",\"inheritLocales\":${src_inherit}"
  fi

  response="${RUN_DIR}/site.response.json"
  local body="{\"name\":\"${NEW_SITE_NAME}\",\"friendlyUrlPath\":\"/${slug}\",\"membershipType\":\"open\",\"active\":true${inherit_locales_json}${avail_langs_json}}"

  local http_code
  http_code=$(curl -s -u "${TARGET_USERNAME}:${TARGET_PASSWORD}" \
    -H 'Content-Type: application/json' \
    -X POST -d "${body}" \
    -o "${response}" \
    -w '%{http_code}' \
    "${TARGET_BASE_URL}/o/headless-admin-site/v1.0/sites")

  if [ "${http_code}" != "200" ] && [ "${http_code}" != "201" ]; then
    bundle_log_collect "${log_offset}" "${log_file}"
    local msg
    msg=$(grep -oE '"title":"[^"]*"|"message":"[^"]*"' "${response}" | head -n1 | cut -c1-60)
    result_add "create_site" "fail" "$(timer_elapsed "${timer}")" \
      "$(bundle_log_summary "${log_file}")" "HTTP ${http_code} ${msg}"
    return 1
  fi

  NEW_SITE_GROUP_ID="$(grep -oE '"id"\s*:\s*[0-9]+' "${response}" | head -n1 | grep -oE '[0-9]+')"
  if [ -z "${NEW_SITE_GROUP_ID}" ]; then
    bundle_log_collect "${log_offset}" "${log_file}"
    result_add "create_site" "fail" "$(timer_elapsed "${timer}")" \
      "$(bundle_log_summary "${log_file}")" "could not parse site id from response"
    return 1
  fi

  # step_import needs a plid for context; reusing the control panel plid
  # works because all imports run through the Control Panel.
  NEW_SITE_PLID="${SOURCE_PLID}"

  bundle_log_collect "${log_offset}" "${log_file}"
  result_add "create_site" "ok" "$(timer_elapsed "${timer}")" \
    "$(bundle_log_summary "${log_file}")" "groupId=${NEW_SITE_GROUP_ID} slug=/${slug}"
}
