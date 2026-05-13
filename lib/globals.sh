#!/bin/bash
# Registry of company-wide ("global") portlet-data dependencies that must be
# migrated alongside the site-level export. Custom Fields (Expando) is the
# canonical example: definitions live on the company's Global site and every
# entity that has expando-bridge columns references them.
#
# In INSTANCE_MODE=create the target is a brand-new company, so these
# definitions don't exist yet — step_globals exports them from the source
# company's Global site and imports them into the target's. In reuse mode the
# definitions are already there and the step is a no-op.
#
# Each global declares:
#   id        — short selector key
#   label     — human-readable name (shown in result rows)
#   portlet   — portlet ID whose data is being moved (e.g. Expando)
#   extras    — per-portlet "<field>=<value>" toggles, one per line. These
#               are exactly the checkboxes the export dialog emits when the
#               portlet's data tree is fully ticked.

declare -A GLOBAL_LABEL
declare -A GLOBAL_PORTLET
declare -A GLOBAL_EXTRAS
GLOBAL_ORDER=()

global_register() {
  local id="$1" label="$2" portlet="$3" extras="${4:-}"
  GLOBAL_LABEL[${id}]="${label}"
  GLOBAL_PORTLET[${id}]="${portlet}"
  GLOBAL_EXTRAS[${id}]="${extras}"
  GLOBAL_ORDER+=("${id}")
}

global_ids() { printf '%s\n' "${GLOBAL_ORDER[@]}"; }

# Resolve "all" / "all,-blogs" / "custom_fields,documents_and_media,…" into
# a list of global-asset IDs. "all" expands to every globals_register entry
# plus every asset_register entry that has a portlet (site_settings has none,
# so it's filtered out). Unknown IDs are flagged at use time, not here.
globals_resolve() {
  local input="$1"
  local -a out=()
  local part exclude canonical id

  if [[ "${input}" == all* ]]; then
    for id in "${GLOBAL_ORDER[@]}"; do out+=("${id}"); done
    for id in "${ASSET_ORDER[@]}"; do
      [ -n "${ASSET_PORTLET[${id}]:-}" ] && out+=("${id}")
    done
    input="${input#all}"
  fi

  IFS=',' read -ra parts <<< "${input}"
  for part in "${parts[@]}"; do
    part="${part#[[:space:]]}"; part="${part%[[:space:]]}"
    [ -z "${part}" ] && continue
    if [[ "${part}" == -* ]]; then
      exclude="${part#-}"
      canonical="${exclude//-/_}"
      local -a filtered=()
      local x
      for x in "${out[@]}"; do [ "${x}" = "${canonical}" ] || filtered+=("${x}"); done
      out=("${filtered[@]}")
    else
      canonical="${part//-/_}"
      out+=("${canonical}")
    fi
  done
  printf '%s\n' "${out[@]}"
}

# Look up an id's portlet/label/extras. Tries the globals registry first
# (so Expando wins over an asset of the same name), then falls back to the
# assets registry. Sets _GA_PORTLET, _GA_LABEL, _GA_EXTRAS on success.
# Returns non-zero when the id is unknown or its portlet is empty.
global_asset_resolve() {
  local id="$1"
  _GA_PORTLET=""; _GA_LABEL=""; _GA_EXTRAS=""
  if [ -n "${GLOBAL_LABEL[${id}]+set}" ]; then
    _GA_PORTLET="${GLOBAL_PORTLET[${id}]}"
    _GA_LABEL="${GLOBAL_LABEL[${id}]}"
    _GA_EXTRAS="${GLOBAL_EXTRAS[${id}]}"
  elif [ -n "${ASSET_LABEL[${id}]+set}" ]; then
    _GA_PORTLET="${ASSET_PORTLET[${id}]}"
    _GA_LABEL="${ASSET_LABEL[${id}]}"
    _GA_EXTRAS="${ASSET_EXTRAS[${id}]}"
  else
    return 1
  fi
  [ -n "${_GA_PORTLET}" ] || return 1
  return 0
}
