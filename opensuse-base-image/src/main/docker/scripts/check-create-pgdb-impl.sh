#!/bin/bash
#
# Copyright 2017-2025 Open Text.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

#
# This script is intended to facilitate database creation so that a later
# running process can safely assume the configured database exists.
# This is particularly useful inside containers, where the application embeds
# dropwizard to maintain the target database's schema.
#
# ----------Variable Section-----------#
#Dummy values (come from environment vars)
#DATABASE_NAME=
#DATABASE_HOST=
#DATABASE_PASSWORD=
#DATABASE_PORT=
#DATABASE_USERNAME=
#DATABASE_APPNAME=

tmpDir="/tmp"
scriptName=$(basename "$0")
baseName="${scriptName%.*}"
tmpErr=$tmpDir/$baseName"-stderr"
pgpassFile="$tmpDir/.pgpass"

# Check that the environment variable prefix to use has been passed
if [ $# -ne 1 ]; then
  echo "ERROR: Incorrect number of arguments specified"
  echo "Usage: $scriptName environment_variable_prefix"
  exit 1
fi

ENV_PREFIX=$1

function get_secret {
  local varName="$1"
  local varNameFile="${varName}_FILE"
  local secretValue=""

  # If CAF_ENABLE_ENV_SECRETS=true (default: true), get secret from env var
  if [ "${CAF_ENABLE_ENV_SECRETS:-true}" = "true" ]; then
    # Check if varName is set and not empty
    if [ -n "${!varName}" ]; then
      secretValue="${!varName}"
      printf '%s' "$secretValue"
      return 0
    fi
  fi

  # If CAF_ENABLE_FILE_SECRETS=true (default: false), get secret from file via env var
  if [ "${CAF_ENABLE_FILE_SECRETS:-false}" = "true" ]; then
    # Check if varNameFile is set and not empty
    if [ -n "${!varNameFile}" ]; then

      # Check if file exists and is readable
      if [ ! -r "${!varNameFile}" ]; then
        echo "ERROR: File ${!varNameFile} does not exist or is not readable" >&2
        return 1
      fi

      # Read file
      if ! secretValue="$(< "${!varNameFile}")"; then
        echo "ERROR: Failed to read file ${!varNameFile}" >&2
        return 1
      fi

      # Check if file content is not empty
      if [ -z "$secretValue" ]; then
        echo "ERROR: Secret file ${!varNameFile} is empty" >&2
        return 1
      fi

      printf '%s' "$secretValue"
      return 0
    fi
  fi

  # If no secret is found, return an error
  echo "ERROR: Secret for $varName not found" >&2
  return 1
}

# Need to convert prefixed variables to known values:
varName="$ENV_PREFIX"DATABASE_NAME
database_name=$(echo ${!varName})

varName="$ENV_PREFIX"DATABASE_HOST
database_host=$(echo ${!varName})

varName="$ENV_PREFIX"DATABASE_PORT
database_port=$(echo ${!varName})

varName="$ENV_PREFIX"DATABASE_USERNAME
database_username=$(echo ${!varName})

varName="${ENV_PREFIX}DATABASE_PASSWORD"
if ! database_password="$(get_secret "$varName")"; then
  exit 1
fi

varName="$ENV_PREFIX"DATABASE_APPNAME
database_appname=$(echo ${!varName})

# ----------Function Section-----------#
function check_psql {
  if [ $(type -p psql) ]; then
      _psql=$(type -p psql)
  else
      echo "WARN: Install psql (to the system path) before this script can be used."
      exit 1
  fi

  if [[ "$_psql" ]]; then
    version=$("$_psql" --version 2>&1 | awk '{print $3}')
    echo "INFO: psql $version found, OK to continue"
  fi
}

function check_variables {
  local -i missingVar=0

  if [ -z "$database_name" ] ; then
    echo "ERROR: Mandatory variable "$(echo $ENV_PREFIX"DATABASE_NAME")" not defined"
    missingVar+=1
  fi

  if [ -z "$database_host" ] ; then
    echo "ERROR: Mandatory variable "$(echo $ENV_PREFIX"DATABASE_HOST")" not defined"
    missingVar+=1
  fi

  if [ -z "$database_port" ] ; then
    echo "ERROR: Mandatory variable "$(echo $ENV_PREFIX"DATABASE_PORT")" not defined"
    missingVar+=1
  fi

  if [ -z "$database_username" ] ; then
    echo "ERROR: Mandatory variable "$(echo $ENV_PREFIX"DATABASE_USERNAME")" not defined"
    missingVar+=1
  fi

  # database_password is checked in get_secret function

  if [ -z "$database_appname" ] ; then
    echo "ERROR: Mandatory variable "$(echo $ENV_PREFIX"DATABASE_APPNAME")" not defined"
    missingVar+=1
  fi

  if [ $missingVar -gt 0 ] ; then
    echo "ERROR: Not all required variables for database creation have been defined, exiting."
    cleanup
    exit 1
  fi
}

function create_pgpass_file {
  echo "INFO: Creating .pgpass file at $pgpassFile"

  if echo "*:*:*:*:$database_password" > "$pgpassFile"; then
    echo "INFO: Successfully wrote to $pgpassFile file"
  else
    echo "ERROR: Failed to write to $pgpassFile file"
    exit 1
  fi

  if chmod 0600 "$pgpassFile"; then
    echo "INFO: Successfully set permissions on $pgpassFile file"
  else
    echo "ERROR: Failed to set permissions on $pgpassFile file"
    cleanup
    exit 1
  fi

  export PGPASSFILE="$pgpassFile"
  echo "INFO: PGPASSFILE environment variable set to $PGPASSFILE"
}

function check_db_exist {
  echo "INFO: Checking database existence..."

# Need to set password for run
# Sending psql errors to file, using quiet grep to search for valid result
 if PGAPPNAME="$database_appname" psql --username="$database_username" \
   --host="$database_host" \
   --port="$database_port" \
   --variable database_name="$database_name" \
   --tuples-only \
   2>$tmpErr <<EOF | grep -q 1
SELECT 1 FROM pg_database WHERE datname = :'database_name';
EOF
 then
   echo "INFO: Database [$database_name] already exists."
   cleanup
   exit 0
 else
   if [ -f "$tmpErr" ] && [ -s "$tmpErr" ] ; then
     echo "ERROR: Database connection error, exiting."
     cat "$tmpErr"
     cleanup
     exit 1
   else
     echo "INFO: Database [$database_name] does not exist, creating..."
     create_db
   fi
 fi
}

function create_db {
# Need to set password for run
# Sending psql errors to file, stderr to NULL
# postgres will auto-lowercase database names unless they are quoted
  if PGAPPNAME="$database_appname" psql --username="$database_username" \
   --host="$database_host" \
   --port="$database_port" \
   --variable database_name="$database_name" \
   >/dev/null 2>$tmpErr <<EOF
CREATE DATABASE :"database_name";
EOF
  then
    echo "INFO: Database [$database_name] created."
    cleanup
  else
     echo "ERROR: Database creation error, exiting."
     cat "$tmpErr"
     cleanup
     exit 1
  fi
}

function cleanup {
  if [ -f "$pgpassFile" ]; then
    echo "INFO: Removing $pgpassFile file"
    if rm -f "$pgpassFile"; then
      echo "INFO: $pgpassFile file removed successfully"
    else
      echo "ERROR: Failed to remove $pgpassFile file"
      exit 1
    fi
  else
    echo "INFO: No $pgpassFile file found to remove"
  fi

  unset PGPASSFILE
  echo "INFO: PGPASSFILE environment variable unset"
}

# -------Main Execution Section--------#

check_variables
check_psql
create_pgpass_file
check_db_exist
