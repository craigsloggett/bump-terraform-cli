#!/bin/sh

set -euf

# Required user inputs.
: "${FILE:?FILE is required}"

# GitHub Actions runtime environment.
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT is unset, most likely during testing}"
: "${GITHUB_STEP_SUMMARY:?GITHUB_STEP_SUMMARY is unset, most likely during testing}"

# Optional user inputs.
: "${YAML_PATH:=}"
: "${LINE_MATCH:=}"
: "${LINE_REPLACE:=}"

die() {
  printf '%s\n' "$1" >&2
  exit 1
}

validate_utilities() (
  for utility in "$@"; do
    command -v "${utility}" >/dev/null 2>&1 ||
      die "Required utility not installed: ${utility}"
  done
)

validate_inputs() (
  [ -f "${FILE}" ] || die "File not found: ${FILE}"

  if [ -n "${LINE_MATCH}" ] && [ -z "${LINE_REPLACE}" ]; then
    die "'match' was provided without 'replace'."
  fi

  if [ -z "${LINE_MATCH}" ] && [ -n "${LINE_REPLACE}" ]; then
    die "'replace' was provided without 'match'."
  fi

  if [ -n "${YAML_PATH}" ] && [ -n "${LINE_MATCH}" ]; then
    die "Provide either 'path' or 'match'+'replace', not both."
  fi

  if [ -z "${YAML_PATH}" ] && [ -z "${LINE_MATCH}" ]; then
    die "Provide either 'path' or 'match'+'replace'."
  fi

  if [ -n "${YAML_PATH}" ] && [ "${YAML_PATH#.}" = "${YAML_PATH}" ]; then
    die "Missing leading '.' in path: ${YAML_PATH}"
  fi
)

discover_latest_version() (
  latest_version=$(
    curl -sf https://checkpoint-api.hashicorp.com/v1/check/terraform |
      jq -r '.current_version // empty'
  )
  [ -n "${latest_version}" ] ||
    die 'Failed to determine the latest version.'

  printf '%s\n' "${latest_version}"
)

bump_yaml() {
  current_version=$(yq "${YAML_PATH}" "${FILE}") ||
    exit 1

  [ "${current_version}" != "null" ] ||
    die "Path ${YAML_PATH} not found in ${FILE}."

  [ "${current_version}" != "${LATEST_VERSION}" ] ||
    return 1 # No change, signal VERSION_CHANGED="false"

  yq "${YAML_PATH} = \"${LATEST_VERSION}\"" -i "${FILE}" ||
    exit 1
}

bump_line() {
  match_count=$(grep -cE "${LINE_MATCH}" "${FILE}") || true

  [ "${match_count}" -ge 1 ] ||
    die "No line in ${FILE} matched pattern: ${LINE_MATCH}"

  [ "${match_count}" -le 1 ] ||
    die "Pattern matched ${match_count} lines in ${FILE}; refine the pattern to match exactly one line."

  awk -v pattern="${LINE_MATCH}" -v replacement="${LINE_REPLACE}" -v version="${LATEST_VERSION}" '
    $0 ~ pattern {
      output = replacement                 # Working copy of the replacement template.
      gsub(/\{version\}/, version, output) # Substitute {version} with the latest version.
      print output
      next                                 # Skip the passthrough block for this line.
    }
    { print }                              # Passthrough for non-matching lines.
  ' "${FILE}" >"${STAGING}" ||
    exit 1

  cmp -s "${FILE}" "${STAGING}" &&
    return 1 # No change, signal VERSION_CHANGED="false"

  mv "${STAGING}" "${FILE}" ||
    exit 1
}

emit_outputs() {
  {
    printf 'version=%s\n' "${LATEST_VERSION}"
    printf 'changed=%s\n' "${VERSION_CHANGED}"
  } >>"${GITHUB_OUTPUT}"
}

emit_state_log() (
  printf '::group::Status\n'
  printf 'version=%s\n' "${LATEST_VERSION}"
  printf 'changed=%s\n' "${VERSION_CHANGED}"
  printf 'file=%s\n' "${FILE}"
  printf '::endgroup::\n'
)

emit_diff_log() (
  [ "${VERSION_CHANGED}" = "true" ] || return 0

  printf '::group::Changes\n'
  git -c color.ui=always --no-pager diff -- "${FILE}" || true
  printf '\n::endgroup::\n'
)

# shellcheck disable=SC2016 # Backticks are literal Markdown code-spans, not command substitution.
emit_summary() {
  [ "${VERSION_CHANGED}" = "true" ] ||
    return 0

  {
    printf 'Terraform can be updated in `%s` to `v%s`\n\n' "${FILE}" "${LATEST_VERSION}"
  } >>"${GITHUB_STEP_SUMMARY}"
}

main() {
  validate_utilities curl jq yq
  validate_inputs

  STAGING=$(mktemp "${FILE}.XXXXXX")
  readonly STAGING
  trap 'rm -f "${STAGING}"' EXIT

  LATEST_VERSION=$(discover_latest_version)
  readonly LATEST_VERSION

  VERSION_CHANGED="false"
  if [ -n "${YAML_PATH}" ]; then
    bump_yaml && VERSION_CHANGED="true"
  else
    bump_line && VERSION_CHANGED="true"
  fi
  readonly VERSION_CHANGED

  emit_outputs
  emit_state_log
  emit_diff_log
  emit_summary
}

main "$@"
