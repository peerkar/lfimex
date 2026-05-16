#!/bin/bash
# Registry of toggleable asset types for site export/import.
#
# Each asset declares:
#   * id              — short name used in ASSETS=... selection
#   * label           — human-readable name
#   * portlet         — portlet ID whose PORTLET_DATA_<id>=on enables it
#   * extras          — additional form fields (one "key=value" per line)
#   * test — compare.sh test name to run after import (optional;
#                       empty means no DB-level validation for this asset)
#
# Add a new asset with asset_register; list all with asset_ids.

declare -A ASSET_LABEL
declare -A ASSET_PORTLET
declare -A ASSET_EXTRAS
declare -A ASSET_TEST
declare -A ASSET_COUNT_QUERY
declare -A ASSET_COUNT_DATE_COLUMN
ASSET_ORDER=()

asset_register() {
  local id="$1" label="$2" portlet="$3" extras="${4:-}" test="${5:-}"
  ASSET_LABEL[${id}]="${label}"
  ASSET_PORTLET[${id}]="${portlet}"
  ASSET_EXTRAS[${id}]="${extras}"
  ASSET_TEST[${id}]="${test}"
  ASSET_ORDER+=("${id}")
}

# Register a "headline row count" SQL for an asset. The placeholder __GID__
# is substituted with a groupId before the query runs; __DATE_FILTER__, if
# present in the SQL, is substituted with an "AND <column> BETWEEN <from>
# AND <to>" clause when --filter date-range is active (and with an empty
# string otherwise). See lib/result.sh's _result_print_asset_counts.
#
# Use this for assets that have a primary row-count concept at the site
# level — skip company-scoped ones (asset_libraries) and anything where a
# single number doesn't tell a useful story.
#
# Usage:
#   asset_count_register <id> <sql> [date_column]
#
# date_column is the column (optionally with a table alias, e.g. "ja.modifiedDate")
# the date range applies to. When omitted, the count never narrows for date-range
# runs even if --from-date/--to-date are set.
asset_count_register() {
  local id="$1" sql="$2" date_column="${3:-}"
  ASSET_COUNT_QUERY[${id}]="${sql}"
  ASSET_COUNT_DATE_COLUMN[${id}]="${date_column}"
}

asset_ids() { printf '%s\n' "${ASSET_ORDER[@]}"; }

# List compare.sh tests in TESTS_DIR that aren't mapped to any registered
# asset. These cover site-wide concerns (friendly_url, page, navigation_menu,
# …) and are run once per orchestrator pass against the imported target.
non_asset_tests() {
  local tests_dir="${TESTS_DIR:-${PROJECT_DIR}/lib/tests}"
  [ -d "${tests_dir}" ] || return 0
  local -A used=()
  local k name f
  for k in "${!ASSET_TEST[@]}"; do
    [ -n "${ASSET_TEST[$k]}" ] && used["${ASSET_TEST[$k]}"]=1
  done
  for f in "${tests_dir}"/*.sh; do
    [ -f "$f" ] || continue
    name=$(basename "$f" .sh)
    [ -z "${used[$name]:-}" ] && echo "$name"
  done
}

# True if the given id is registered as an asset.
asset_exists() {
  [ -n "${ASSET_LABEL[${1}]+set}" ]
}

# Resolve "all" / "all,-blogs" / "documents,blogs" into a list of asset IDs.
# Unknown IDs are rejected with a clear error so a typo doesn't blow up later.
assets_resolve() {
  local input="$1"
  local -a out=()
  local part exclude="" canonical
  if [[ "${input}" == all* ]]; then
    out=("${ASSET_ORDER[@]}")
    input="${input#all}"
  fi
  IFS=',' read -ra parts <<< "${input}"
  for part in "${parts[@]}"; do
    part="${part#[[:space:]]}"; part="${part%[[:space:]]}"
    [ -z "${part}" ] && continue
    if [[ "${part}" == -* ]]; then
      exclude="${part#-}"
      canonical="${exclude//-/_}"
      if ! asset_exists "${canonical}"; then
        echo "Unknown asset id to exclude: ${exclude}. Run --list-assets for valid IDs." >&2
        exit 2
      fi
      local -a filtered=()
      local x
      for x in "${out[@]}"; do [ "${x}" = "${canonical}" ] || filtered+=("${x}"); done
      out=("${filtered[@]}")
    else
      canonical="${part//-/_}"
      if ! asset_exists "${canonical}"; then
        echo "Unknown asset id: ${part}. Run --list-assets for valid IDs." >&2
        exit 2
      fi
      out+=("${canonical}")
    fi
  done
  printf '%s\n' "${out[@]}"
}

# Emit the form -F arguments for the selected assets and the shared meta fields
# (PORTLET_DATA=true, checkboxNames=...). Pass the portlet namespace prefix as
# the first arg, then the asset IDs.
#
# Convention: we send only the high-level "include this portlet's data"
# enablers. Per-data-handler toggles (the long _journal_*, _template_*,
# _GroupPagesPortlet_* lists you'd see in the JSP) are intentionally absent
# from BOTH the form params and the checkboxNames list, so Liferay falls back
# to each PortletDataHandlerBoolean's own defaultValue — i.e. exactly what the
# UI's Export dialog ships when the user hits Export with the defaults intact.
# This also handles dynamic per-template-type controls that the Templates and
# Pages portlets register at runtime: we never have to enumerate them.
#
# Overrides go in the asset's `extras` (one "key=value" per line). The only
# one currently in use is `_depot_site-connections=false` (Liferay's default
# is true, but the connection doesn't round-trip across companies — see the
# Asset Libraries note in CLAUDE.md).
#
# DELETIONS is listed in checkboxNames without `=on`, which makes
# _processCheckbox (PortletRequestImpl) force the param to "false". A
# one-shot site → fresh-target import has nothing to delete in the target,
# and the source's DeletionSystemEvent table would otherwise be replayed and
# flood the log with NoSuchLayoutException stacks for legacy rows whose
# externalReferenceCode is blank.
#
# PERMISSIONS / COMMENTS / RATINGS are neither sent nor listed — their
# data-handler defaults apply (PERMISSIONS off, COMMENTS/RATINGS on).
asset_form_fields() {
  local ns="$1"; shift
  local id portlet line key
  local -a checkbox_names=()

  printf -- '-F\n%sPORTLET_DATA=true\n' "${ns}"

  for id in "$@"; do
    portlet="${ASSET_PORTLET[${id}]:-}"
    if [ -n "${portlet}" ]; then
      printf -- '-F\n%sPORTLET_DATA_%s=on\n' "${ns}" "${portlet}"
      printf -- '-F\n%sPORTLET_CONFIGURATION_%s=on\n' "${ns}" "${portlet}"
      printf -- '-F\n%sPORTLET_SETUP_%s=on\n' "${ns}" "${portlet}"
      printf -- '-F\n%sPORTLET_USER_PREFERENCES_%s=on\n' "${ns}" "${portlet}"
      checkbox_names+=("PORTLET_DATA_${portlet}")
      checkbox_names+=("PORTLET_CONFIGURATION_${portlet}")
      checkbox_names+=("PORTLET_SETUP_${portlet}")
      checkbox_names+=("PORTLET_USER_PREFERENCES_${portlet}")
    fi
    while IFS= read -r line; do
      [ -z "${line}" ] && continue
      printf -- '-F\n%s%s\n' "${ns}" "${line}"
      key="${line%%=*}"
      checkbox_names+=("${key}")
    done <<< "${ASSET_EXTRAS[${id}]:-}"
  done

  checkbox_names+=("DELETIONS")

  local joined
  joined=$(IFS=','; echo "${checkbox_names[*]}")
  printf -- '-F\n%scheckboxNames=%s\n' "${ns}" "${joined}"
}
