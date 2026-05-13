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
ASSET_ORDER=()

asset_register() {
  local id="$1" label="$2" portlet="$3" extras="${4:-}" test="${5:-}"
  ASSET_LABEL[${id}]="${label}"
  ASSET_PORTLET[${id}]="${portlet}"
  ASSET_EXTRAS[${id}]="${extras}"
  ASSET_TEST[${id}]="${test}"
  ASSET_ORDER+=("${id}")
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

  # Shared toggles
  printf -- '-F\n%sPERMISSIONS=on\n' "${ns}"
  printf -- '-F\n%sCOMMENTS=on\n' "${ns}"
  printf -- '-F\n%sRATINGS=on\n' "${ns}"
  printf -- '-F\n%sDELETIONS=on\n' "${ns}"
  checkbox_names+=("PERMISSIONS" "COMMENTS" "RATINGS" "DELETIONS")

  local joined
  joined=$(IFS=','; echo "${checkbox_names[*]}")
  printf -- '-F\n%scheckboxNames=%s\n' "${ns}" "${joined}"
}
