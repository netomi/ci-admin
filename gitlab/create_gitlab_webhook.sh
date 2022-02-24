#!/usr/bin/env bash
#*******************************************************************************
# Copyright (c) 2022 Eclipse Foundation and others.
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License 2.0
# which is available at http://www.eclipse.org/legal/epl-v20.html
# SPDX-License-Identifier: EPL-2.0
#*******************************************************************************

# Create webhook in GitLab

# Bash strict-mode
set -o errexit
set -o nounset
set -o pipefail

IFS=$'\n\t'
SCRIPT_FOLDER="$(dirname "$(readlink -f "${0}")")"

if [[ ! -f "${SCRIPT_FOLDER}/../.localconfig" ]]; then
  echo "ERROR: File '$(readlink -f "${SCRIPT_FOLDER}/../.localconfig")' does not exists"
  echo "Create one to configure the location of the password store. Example:"
  echo '{"password-store": {"cbi-dir": "~/.password-store/cbi"}}'
fi

PASSWORD_STORE_DIR="$(jq -r '.["password-store"]["cbi-dir"]' "${SCRIPT_FOLDER}/../.localconfig")"
PASSWORD_STORE_DIR="$(readlink -f "${PASSWORD_STORE_DIR/#~\//${HOME}/}")"
export PASSWORD_STORE_DIR

GITLAB_PASS_DOMAIN="gitlab.eclipse.org"

PROJECT_NAME="${1:-}"
REPO_NAME="${2:-}"
SHORT_NAME=${PROJECT_NAME##*.}

# verify input
if [ -z "${PROJECT_NAME}" ]; then
  printf "ERROR: a project name (e.g. 'technology.cbi' for CBI project) must be given.\n"
  exit 1
fi
if [ -z "${REPO_NAME}" ]; then
  printf "ERROR: a repo name (e.g. 'cbi') must be given.\n"
  exit 1
fi

PW_STORE_PATH="bots/${PROJECT_NAME}/${GITLAB_PASS_DOMAIN}"


create_gitlab_webhook() {
  local project_name="${1:-}"
  local repo_name="${2:-}"
  local webhook_url="${3:-}"

  if [[ ! -f "${PASSWORD_STORE_DIR}/bots/${project_name}/${GITLAB_PASS_DOMAIN}/webhook-secret.gpg" ]]; then
    echo "Creating webhook secret credentials in password store..."
    pwgen -1 -s -r '&' -y 24 | pass insert --echo "${PW_STORE_PATH}/webhook-secret"
  else
    echo "Found ${GITLAB_PASS_DOMAIN} webhook-secret credentials in password store. Skipping creation..."
  fi
  webhook_secret="$(pass "${PW_STORE_PATH}/webhook-secret")"

 "${SCRIPT_FOLDER}/gitlab_admin.sh" "create_webhook" "${repo_name}" "${webhook_url}" "${webhook_secret}"
}

webhook_url="https://ci.eclipse.org/${SHORT_NAME}/gitlab-webhook/post"

create_gitlab_webhook "${PROJECT_NAME}" "${REPO_NAME}" "${webhook_url}"
