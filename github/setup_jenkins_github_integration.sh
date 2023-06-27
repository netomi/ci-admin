#!/usr/bin/env bash
#*******************************************************************************
# Copyright (c) 2021 Eclipse Foundation and others.
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License 2.0
# which is available at http://www.eclipse.org/legal/epl-v20.html,
# or the MIT License which is available at https://opensource.org/licenses/MIT.
# SPDX-License-Identifier: EPL-2.0 OR MIT
#*******************************************************************************

# Bash strict-mode
set -o errexit
set -o nounset
set -o pipefail

IFS=$'\n\t'
SCRIPT_FOLDER="$(dirname "$(readlink -f "${0}")")"
CI_ADMIN_ROOT="${SCRIPT_FOLDER}/.."

JIRO_ROOT_FOLDER="$("${CI_ADMIN_ROOT}/utils/local_config.sh" "get_var" "jiro-root-dir")"
PROJECTS_BOTS_API_ROOT_FOLDER="$("${CI_ADMIN_ROOT}/utils/local_config.sh" "get_var" "projects-bots-api-root-dir")"

PROJECT_NAME="${1:-}"
SHORT_NAME="${PROJECT_NAME##*.}"

# check that project name is not empty
if [[ -z "${PROJECT_NAME}" ]]; then
  printf "ERROR: a project name must be given.\n"
  exit 1
fi


# TODO:
# * deal with multiple executions due to errors
#     * do not create github credentials if they already exist
# * add confirmations/questions
# * open websites
# * create webhooks
# * improve instructions

create_github_credentials() {
  echo "# Creating GitHub bot user credentials..."
  "${CI_ADMIN_ROOT}/pass/add_creds.sh" "github" "${PROJECT_NAME}" || true
  "${CI_ADMIN_ROOT}/pass/add_creds.sh" "github_ssh" "${PROJECT_NAME}" || true
}

set_up_github_account() {
  # automate?
  cat <<EOF

# Setting up GitHub bot account...
==================================
* Set up GitHub bot account (https://github.com/signup)
  * Take credentials from pass
* Verify email
* Add SSH public key to GitHub bot account (Settings -> SSh and GPG keys -> New SSH key)
* Create API token (Settings -> Developer Settings -> Personal access tokens)
  * API token
    * Name:       Jenkins GitHub Plugin token https://ci.eclipse.org/${SHORT_NAME}
    * Expiration: No expiration
    * Scopes:     repo:status, public_repo, admin:repo_hook
  * Add token to pass (api-token)
* Add GitHub bot to project’s GitHub org (invite via webmaster account)
EOF
  read -rsp $'Once you are done, press any key to continue...\n' -n1

#TODO: read tokens from stdin and add them to pass

}

add_jenkins_credentials() {
#TODO: check that token credentials have been created
  printf "\n# Adding GitHub bot credentials to Jenkins instance...\n"
  "${JIRO_ROOT_FOLDER}/jenkins-create-credentials.sh" "${PROJECT_NAME}"
  "${JIRO_ROOT_FOLDER}/jenkins-create-credentials-token.sh" "auto" "${PROJECT_NAME}"
}

update_projects_bot_api() {
  printf "\n# Update projects-bots-api...\n"

  echo "Connected to cluster?"
  read -rp "Press enter to continue or CTRL-C to stop the script"

  echo "Pulled latest version of projects-bots-api?"
  read -rp "Press enter to continue or CTRL-C to stop the script"

  "${PROJECTS_BOTS_API_ROOT_FOLDER}/regen_db.sh"

  printf "\n\n"
#TODO: Show error if files are equal
  read -rsp $'Once you are done with comparing the diff, press any key to continue...\n' -n1
  "${PROJECTS_BOTS_API_ROOT_FOLDER}/deploy_db.sh"

  printf "\n# TODO: Double check that bot account has been added to API (https://api.eclipse.org/bots)...\n"
  read -rsp $'Once you are done, press any key to continue...\n' -n1
}

create_org_webhook() {
  echo "# Creating organization webhook..."
  "${SCRIPT_FOLDER}/create_webhook.sh" "org" "${PROJECT_NAME}" "eclipse-${SHORT_NAME}"
}

instructions_template() {
  cat <<EOF

Post the following on the corresponding HelpDesk issue:
-------------------------------------------------------
A GitHub bot (ID: eclipse-${SHORT_NAME}-bot) has been created. Credentials have been added to the ${SHORT_NAME} JIPP.

To set up a job that builds pull requests, you can use a Freestyle job and the GitHub Pull Request Builder (GHPRB) Plugin.

The recommended way is to use a Multibranch Pipeline job instead (a Jenkinsfile in your repo is required):
1. New item > Multibranch Pipeline
2. Branch Sources > Add source > GitHub
3. Select credentials "GitHub bot (username/token)"
4. Add the repository URL
5. Configure behaviors 
6. Save

By default, all branches and PRs will be scanned and dedicated build jobs will be created automatically (if a Jenkinsfile is found).

EOF
}

question() {
  local message="${1:-}"
  local action="${2:-}"
  read -rp "Do you want to ${message}? (Y)es, (N)o, E(x)it: " yn
  case $yn in
    [Yy]* ) ${action};;
    [Nn]* ) return ;;
    [Xx]* ) exit 0;;
        * ) echo "Please answer (Y)es, (N)o, E(x)it"; question "${message}" "${action}";
  esac
}

#### MAIN

create_github_credentials

set_up_github_account

update_projects_bot_api

question "add Jenkins credentials" add_jenkins_credentials

question "create an org webhook" create_org_webhook

printf "\n# TODO: Set up GitHub config in Jenkins (if applicable)...\n"
printf "\n# TODO: Commit changes to pass...\n"

read -rsp $'Once you are done, press any key to continue...\n' -n1

instructions_template

