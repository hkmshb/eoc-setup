#!/usr/bin/env bash
set -Eeuo pipefail

function check_openssl {
  which openssl > /dev/null
}

function gen_random_string {
  openssl rand -hex 16 | tr -d "\n"
}

function final_warning {
  lin_path="/etc/hosts"
  win_path="C:\Windows\System32\Drivers\etc\hosts"

  echo ""
  echo "Add to your [$lin_path] or [$win_path] file the following line:"
  echo ""
  echo -e "\033[93m127.0.0.1  \033[1m${HOSTNAME}\033[0m"
  echo ""
}

function gen_env_file {
  local HOSTNAME=eoc
  local SOLR_CORE=ckan
  local CKAN_VERSION=ckan-2.7.2

  cat << EOF
#
# USE THIS ONLY LOCALLY
#
# This file was generated by "./src/bin/gen_env_file.sh" script.
#
# Variables in this file will be substituted into "docker-compose.yml" and are
# intended to be used exclusively for local deployment. Never deploy these to
# publicly accessible servers.
#
# Verify correct substitution with:
#
#   docker-compose config
#
# If variables are newly added or enabled, please restart the containrs to pull
# in changes:
#
#   docker-compose restart {container-name}
#

# ------------------------------------------------------------------
## CKAN
# ==================================================================
export DEBUG=true
export HOSTNAME=${HOSTNAME}
export GITHUB_TOKEN=<required>

export CKAN_VERSION=${CKAN_VERSION}
export CKAN_SITE_URL=http://${HOSTNAME}:5000/

export CKAN_HOME=/usr/lib/ckan/default
export CKAN_CONFIG=/etc/ckan/default
export CKAN_STORAGE_PATH=/var/lib/ckan

## Databases
export POSTGRES_USER=postgres
export POSTGRES_PASSWORD=$(gen_random_string)

export CKAN_DB_HOST=db
export CKAN_DB_USER=ckan
export CKAN_DB_NAME=ckan
export CKAN_DB_PASSWORD=$(gen_random_string)

export DATASTORE_NAME=datastore
export DATASTORE_USERNAME=datastore
export DATA_STORE_PASSWORD=$(gen_random_string)

## Solr
export SOLR_CORE=${SOLR_CORE}
export SOLR_HOME=/opt/solr/server/solr/${SOLR_CORE}

## SMTP
export SMTP_SERVER=
export SMTP_USER=
export SMTP_PASSWORD=

# ------------------------------------------------------------------
## CKAN + EOC Extensions
# ==================================================================

## Google Analytics
export GOOGLE_PASSWORD=
export GOOGLE_EMAIL=
export GOOGLE_CLIENT_ID=
export GOOGLE_CIENT_SECRET=
export GOOGLE_ANALYTICS_KEY=

## AWS
export AWS_ACCESS_KEY=
export AWS_SECRET_KEY=

## Gather
export GATHER_API_KEY=
export GATHER_RESPONSES_URL=

EOF
}

if [ -e ".env.local" ]; then
  echo -e "\033[93;1m[.env.local]\033[0m file already exists!"
  echo "Remove it if you want to generate a new one."
  final_warning
  exit 0
fi

check_openssl
RET=$?
if [ $RET -eq 1 ]; then
    echo -e "\033[91mPlease install 'openssl'  https://www.openssl.org/\033[0m"
    exit 1
fi

set -Eeo pipefail
gen_env_file > .env.local
echo -e "\033[92;1m[.env.local]\033[0m file generated!"
final_warning