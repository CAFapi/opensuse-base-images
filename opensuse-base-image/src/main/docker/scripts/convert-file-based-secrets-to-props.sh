#!/bin/bash
#
# Copyright 2017-2024 Open Text.
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

# A function for logging in the caf logging format.
caf_log() {
    echo "$@" |& $(dirname "$0")/../scripts/caf-log-format.sh "convert_file_based_secrets_to_props.sh" 1>&2
}

# A function for converting file-based secrets to properties.
#
# For example, for each environment variable ending in the _FILE suffix:
#
#     ABC_PASSWORD_FILE=/var/somefile.txt
#
# read the contents of /var/somefile.txt (for example 'mypassword'), and write the following line to /maven/secret-props.txt:
#
#     -DABC_PASSWORD=mypassword
convert_file_based_secrets_to_props() {
    local props_file="/maven/secret-props.txt"

    if [ -f "$props_file" ]; then
        rm "$props_file"
    fi

    while IFS='=' read -r -d '' env_var_name env_var_value; do
        if [[ ${env_var_name} == *_FILE ]] ; then
            local prop_name=${env_var_name%_FILE}
            caf_log "INFO: Reading ${env_var_name} (${env_var_value})..."
            if [ -e "$env_var_value" ]; then
                local file_contents=$(<${env_var_value})
                if echo "-D${prop_name}=${file_contents}" >> "$props_file" ; then
                    caf_log "INFO: Successfully added to ${props_file}: -D${prop_name}=<CONTENT HIDDEN>"
                    unset "$env_var_name"
                else
                    caf_log "ERROR: Failed to write to ${props_file}: -D${prop_name}=<CONTENT HIDDEN>"
                    exit 1
                fi
            else
                caf_log "ERROR: Failed to read file $env_var_value, file does not exist"
                exit 1
            fi
        fi
    done < <(env -0)
}

convert_file_based_secrets_to_props

unset -f caf_log # Don't export the caf_log function when this script is sourced