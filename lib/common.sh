#!/bin/bash
# Shared helpers: logging, time tracking, mysql access, http session.

# --- logging --------------------------------------------------------------

log_info()  { printf '[%s] [INFO]  %s\n' "$(date +'%H:%M:%S')" "$*" >&2; }
log_warn()  { printf '[%s] [WARN]  %s\n' "$(date +'%H:%M:%S')" "$*" >&2; }
log_error() { printf '[%s] [ERROR] %s\n' "$(date +'%H:%M:%S')" "$*" >&2; }

die() { log_error "$*"; exit 1; }

# Check that the external binaries we shell out to are on PATH. Called early
# so the user sees one clean error instead of a cryptic "command not found"
# halfway through a run. `mysql` and `curl` are always needed; `blade` is
# only needed when we spin up / tear down a target instance via Groovy.
# In create mode we also verify portal-ext.properties allows arbitrary virtual
# hosts — the new company's .localhost vhost is rejected otherwise.
require_tools() {
  local -a required=(mysql curl)
  local check_portal_ext=0
  if [ "${INSTANCE_MODE:-reuse}" = "create" ] && [ "${EXPORT_ONLY:-0}" != "1" ]; then
    required+=(blade)
    check_portal_ext=1
  fi
  if [ "${CLEANUP_INSTANCE:-0}" = "1" ] && [ "${INSTANCE_MODE:-reuse}" = "create" ]; then
    # Already covered by the create branch above, but explicit when create is
    # short-circuited by EXPORT_ONLY but cleanup is somehow still on.
    required+=(blade)
  fi

  local -a missing=()
  local tool seen
  declare -A seen=()
  for tool in "${required[@]}"; do
    [ -n "${seen[${tool}]:-}" ] && continue
    seen[${tool}]=1
    command -v "${tool}" >/dev/null 2>&1 || missing+=("${tool}")
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    die "Missing required tool(s) on PATH: ${missing[*]}. Install them and retry."
  fi

  if [ "${check_portal_ext}" = "1" ]; then
    require_portal_ext_property "virtual.hosts.valid.hosts" "*"
  fi
}

# Assert that ${BUNDLES_DIR}/portal-ext.properties sets the given key to the
# given value (uncommented). Later assignments in a Java properties file
# override earlier ones, so the last matching line wins.
require_portal_ext_property() {
  local key="$1" want="$2"
  local portal_ext="${BUNDLES_DIR}/portal-ext.properties"
  if [ ! -f "${portal_ext}" ]; then
    die "${portal_ext} not found. It must define ${key}=${want}."
  fi
  local escaped_key value
  escaped_key="${key//./\\.}"
  value="$(grep -E "^[[:space:]]*${escaped_key}[[:space:]]*=" "${portal_ext}" \
           | tail -n 1 \
           | sed -E 's/^[^=]*=[[:space:]]*//; s/[[:space:]]+$//')"
  if [ "${value}" != "${want}" ]; then
    die "${portal_ext} must set '${key}=${want}'. Current value: '${value:-<unset>}'."
  fi
}

# Wrap a step invocation with bracketed "starting / completed" log lines.
# Usage: run_step <name> <function> [args...]
# The function's own log_info / result_add output appears between the two
# markers; its exit code is preserved.
run_step() {
  local name="$1"; shift
  log_info "Step ${name} starting"
  "$@"
  local rc=$?
  log_info "Step ${name} completed"
  return $rc
}

# --- time tracking --------------------------------------------------------

# Usage: TIMER=$(timer_start); ...; ELAPSED=$(timer_elapsed "${TIMER}")
timer_start()  { date +%s; }
timer_elapsed() { echo $(( $(date +%s) - $1 )); }
timer_human()  {
  local s="$1"
  if [ "${s}" -lt 60 ]; then printf '%ds' "${s}"
  elif [ "${s}" -lt 3600 ]; then printf '%dm%02ds' $((s/60)) $((s%60))
  else printf '%dh%02dm%02ds' $((s/3600)) $(((s%3600)/60)) $((s%60))
  fi
}

# --- mysql ----------------------------------------------------------------

mysql_q() {
  mysql -u "${SRC_DB_USER}" -p"${SRC_DB_PASS}" -h "${SRC_DB_HOST}" "${SRC_DB_NAME}" -BNe "$1" 2>/dev/null
}

# Look up the groupKey for a groupId. compare.sh resolves --source-site /
# --target-site by Group_.groupKey, not friendlyURL.
group_site_key() {
  mysql_q "SELECT groupKey FROM Group_ WHERE groupId=$1;"
}

# Normalize a date arg to YYYY-MM-DD. Accepts YYYY-MM-DD or YYYYMMDD.
normalize_date() {
  local d="$1"
  if [[ "${d}" =~ ^[0-9]{8}$ ]]; then
    echo "${d:0:4}-${d:4:2}-${d:6:2}"
  else
    echo "${d}"
  fi
}

# Derive Liferay's per-field date values into shell vars named <prefix>_DD,
# <prefix>_MM (0-indexed), <prefix>_YYYY, <prefix>_MMDDYYYY, <prefix>_HOUR (1-12
# encoded as 0 at the 12 boundary to match Liferay's getCalendar PM offset),
# <prefix>_MINUTE, <prefix>_AMPM (0=AM, 1=PM), <prefix>_TIME (HH:MM 24h),
# <prefix>_HUMAN, <prefix>_EPOCH. Uses the logged-in user's timezone.
#
# Usage: derive_date_fields <prefix> <YYYY-MM-DD> <HH:MM:SS> [clamp_to_past=0|1]
derive_date_fields() {
  local prefix="$1" date="$2" time="$3" clamp="${4:-0}"
  local epoch now_epoch hh mm h12 ampm
  epoch="$(TZ="${USER_TIMEZONE}" date -d "${date} ${time}" +%s)"
  if [ "${clamp}" = "1" ]; then
    now_epoch="$(date -u +%s)"
    if [ "${epoch}" -gt "$((now_epoch - 60))" ]; then epoch=$((now_epoch - 60)); fi
  fi
  hh="$(TZ="${USER_TIMEZONE}" date -d "@${epoch}" +%-H)"
  mm="$(TZ="${USER_TIMEZONE}" date -d "@${epoch}" +%-M)"
  if [ "${hh}" -eq 0 ]; then ampm=0; h12=0
  elif [ "${hh}" -eq 12 ]; then ampm=1; h12=0
  elif [ "${hh}" -gt 12 ]; then ampm=1; h12=$((hh - 12))
  else ampm=0; h12="${hh}"
  fi
  eval "${prefix}_DD=\"$(TZ="${USER_TIMEZONE}" date -d "@${epoch}" +%-d)\""
  eval "${prefix}_MM=\"$(( $(TZ="${USER_TIMEZONE}" date -d "@${epoch}" +%-m) - 1 ))\""
  eval "${prefix}_YYYY=\"$(TZ="${USER_TIMEZONE}" date -d "@${epoch}" +%Y)\""
  eval "${prefix}_MMDDYYYY=\"$(TZ="${USER_TIMEZONE}" date -d "@${epoch}" +%m/%d/%Y)\""
  eval "${prefix}_HOUR=\"${h12}\""
  eval "${prefix}_MINUTE=\"${mm}\""
  eval "${prefix}_AMPM=\"${ampm}\""
  eval "${prefix}_TIME=\"$(printf '%02d:%02d' "${hh}" "${mm}")\""
  eval "${prefix}_HUMAN=\"$(TZ="${USER_TIMEZONE}" date -d "@${epoch}" +"%a %b %d %H:%M:%S %Z %Y")\""
  eval "${prefix}_EPOCH=\"${epoch}\""
}

# Resolve the ExportImportConfiguration row that drives a BackgroundTask, then
# dump its ExportImportReportEntry rows into a TSV at $2. The columns are:
# type, status, modelNameLanguageKey, message.
report_collect() {
  local task_id="$1" out="$2"
  local cfg_id
  cfg_id="$(mysql_q "SELECT taskContextMap FROM BackgroundTask WHERE backgroundTaskId=${task_id};" \
    | grep -oE '"exportImportConfigurationId":[0-9]+' \
    | head -n1 \
    | grep -oE '[0-9]+')"
  if [ -z "${cfg_id}" ]; then : > "${out}"; return 0; fi
  mysql_q "
    SELECT
      type_,
      status,
      IFNULL(modelNameLanguageKey, '-'),
      REPLACE(REPLACE(IFNULL(errorMessage, ''), '\n', ' '), '\t', ' ')
    FROM ExportImportReportEntry
    WHERE exportImportConfigurationId = ${cfg_id}
    ORDER BY exportImportReportEntryId;" > "${out}"
}

# Summarize an ExportImportReportEntry TSV: counts + first error/warn message.
# type_=1=ERROR, status=1=RESOLVED, status=2=UNRESOLVED.
report_summary() {
  local file="$1"
  if [ ! -s "${file}" ]; then echo ""; return; fi
  local err warn first
  err=$(awk -F'\t' '$1==1 && $2==2' "${file}" | wc -l)
  warn=$(awk -F'\t' '$1==1 && $2==1' "${file}" | wc -l)
  first=$(awk -F'\t' '$1==1 {print $4; exit}' "${file}" | cut -c1-120)
  if [ "${err}" -eq 0 ] && [ "${warn}" -eq 0 ]; then echo ""; return; fi
  echo "ERR=${err} WARN=${warn} | ${first}"
}

# --- http session ---------------------------------------------------------

# Probe ${BASE_URL}. Returns 0 if the portal answers an HTTP request within
# the timeout, 1 otherwise. Doesn't print anything; the caller decides whether
# to die or continue.
portal_check() {
  curl -sf -o /dev/null --connect-timeout 5 "${BASE_URL}/web/guest"
}

session_init() {
  COOKIE_JAR="$(mktemp)"
  TARGET_COOKIE_JAR="$(mktemp)"
  # shellcheck disable=SC2064
  trap "rm -f '${COOKIE_JAR}' '${TARGET_COOKIE_JAR}'" EXIT
}

# Shared login dance. Sets the named p_auth variable on success.
# Usage: _session_login_into <base-url> <user> <pass> <cookie-jar> <p_auth-var-name>
_session_login_into() {
  local base="$1" user="$2" pass="$3" jar="$4" out_var="$5"
  local guest_page guest_p_auth user_page p_auth

  if ! curl -sf -o /dev/null --connect-timeout 5 "${base}/web/guest"; then
    die "Cannot reach ${base}/web/guest. Is Tomcat running and the virtual host configured?"
  fi

  guest_page="$(curl -s -c "${jar}" -b "${jar}" "${base}/web/guest")"
  guest_p_auth="$(_extract_p_auth "${guest_page}")"
  [ -n "${guest_p_auth}" ] || die "Could not read guest p_auth from ${base}/web/guest."

  curl -s -c "${jar}" -b "${jar}" \
    -d "login=${user}" -d "password=${pass}" -d "p_auth=${guest_p_auth}" \
    -o /dev/null "${base}/c/portal/login"

  user_page="$(curl -s -b "${jar}" "${base}/web/guest")"
  p_auth="$(_extract_p_auth "${user_page}")"
  [ -n "${p_auth}" ] && [ "${p_auth}" != "${guest_p_auth}" ] \
    || die "Login as ${user} at ${base} failed (p_auth did not rotate)."

  printf -v "${out_var}" '%s' "${p_auth}"
}

# Source session: sets P_AUTH and USER_TIMEZONE for export-side calls.
session_login() {
  _session_login_into "${BASE_URL}" "${USERNAME}" "${PASSWORD}" "${COOKIE_JAR}" P_AUTH

  USER_TIMEZONE="$(mysql_q "SELECT timeZoneId FROM User_ WHERE emailAddress='${USERNAME}';")"
  [ -n "${USER_TIMEZONE}" ] || USER_TIMEZONE="UTC"

  log_info "Logged in as ${USERNAME} at ${BASE_URL} (TZ=${USER_TIMEZONE}); p_auth=${P_AUTH}"
}

# Target session: sets TARGET_P_AUTH for site/import/cleanup calls.
# Caller must populate TARGET_BASE_URL / TARGET_USERNAME / TARGET_PASSWORD first
# (step_instance does this once instance routing is known).
session_login_target() {
  [ -n "${TARGET_BASE_URL:-}" ] || die "session_login_target called before TARGET_BASE_URL was set"

  _session_login_into "${TARGET_BASE_URL}" "${TARGET_USERNAME}" "${TARGET_PASSWORD}" \
    "${TARGET_COOKIE_JAR}" TARGET_P_AUTH

  log_info "Logged in as ${TARGET_USERNAME} at ${TARGET_BASE_URL}; p_auth=${TARGET_P_AUTH}"
}

# Re-issue the source / target login. Use before any HTTP-heavy phase that
# follows a long wait (a multi-hour BackgroundTask poll is enough to outlast
# the portal's session timeout — usually 30 min — and the next request would
# otherwise hit Liferay's login redirect, fail silently, and leave us with
# no BackgroundTask or, worse, an HTML login page saved as a "LAR").
session_refresh()        { session_login;        }
session_refresh_target() { session_login_target; }

_extract_p_auth() {
  printf '%s' "$1" \
    | grep -oE 'authToken[^A-Za-z0-9]+[A-Za-z0-9]{6,}' \
    | head -n1 \
    | grep -oE '[A-Za-z0-9]{6,}$'
}

# Issue a curl call against the Liferay portal, attaching the session cookie.
# Usage: portal_curl <output-file> <url> [extra curl args...]
portal_curl() {
  local out="$1" url="$2"; shift 2
  curl -s -L -b "${COOKIE_JAR}" -o "${out}" --url "${url}" "$@"
}

# A LAR is a ZIP archive; the magic bytes start with "PK\x03\x04" (or PK\x05\x06
# for an empty archive). When the session has expired, the portal silently
# returns the login HTML page with a 200 OK, which would otherwise pass any
# size-only check downstream. Use this to fail loud instead.
_is_lar_file() {
  local f="$1"
  [ -s "${f}" ] || return 1
  local magic
  magic=$(head -c 2 "${f}" 2>/dev/null)
  [ "${magic}" = "PK" ]
}
