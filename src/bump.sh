#!/bin/sh

set -eu

VERSION=$(curl -sf https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r '.current_version')

if [ -z "${VERSION}" ] || [ "${VERSION}" = "null" ]; then
  printf 'Failed to determine the latest Terraform CLI version.\n' >&2
  exit 1
fi

if [ ! -f "${FILE}" ]; then
  printf 'File not found: %s\n' "${FILE}" >&2
  exit 1
fi

if [ -n "${VALUE_PATH}" ] && [ -n "${LINE_MATCH}${LINE_REPLACE}" ]; then
  printf 'Provide either "path" or "match"+"replace", not both.\n' >&2
  exit 1
fi

if [ -n "${VALUE_PATH}" ]; then
  CURRENT=$(yq eval "${VALUE_PATH}" "${FILE}")
  if [ "${CURRENT}" = "null" ]; then
    printf 'Path %s not found in %s.\n' "${VALUE_PATH}" "${FILE}" >&2
    exit 1
  fi
  if [ "${CURRENT}" != "${VERSION}" ]; then
    yq eval "${VALUE_PATH} = \"${VERSION}\"" -i "${FILE}"
  fi
elif [ -n "${LINE_MATCH}" ] && [ -n "${LINE_REPLACE}" ]; then
  MATCHES=$(awk -v pattern="${LINE_MATCH}" '$0 ~ pattern { c++ } END { print c+0 }' "${FILE}")
  if [ "${MATCHES}" -eq 0 ]; then
    printf 'No line in %s matched pattern: %s\n' "${FILE}" "${LINE_MATCH}" >&2
    exit 1
  fi
  REPLACEMENT=$(printf '%s' "${LINE_REPLACE}" | sed "s|{version}|${VERSION}|g")
  awk -v pattern="${LINE_MATCH}" -v replacement="${REPLACEMENT}" '
    $0 ~ pattern { print replacement; next }
    { print }
  ' "${FILE}" >"${FILE}.new"
  mv "${FILE}.new" "${FILE}"
else
  printf 'Provide either "path" (for YAML) or "match"+"replace" (for line-based files).\n' >&2
  exit 1
fi

printf 'version=%s\n' "${VERSION}" >>"${GITHUB_OUTPUT}"
