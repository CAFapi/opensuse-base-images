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
    echo "$@" |& $(dirname "$0")/../scripts/caf-log-format.sh "write_file_based_secrets_as_properties.sh" 1>&2
}

# A function for writing file-based secrets to a Java arguments file as properties.
#
# For example, for each environment variable ending in the _FILE suffix:
#
#     ABC_PASSWORD_FILE=/var/somefile.txt
#
# read the contents of /var/somefile.txt (for example 'mypassword'), and write the following line to /maven/java-args.txt:
#
#     -DABC_PASSWORD=mypassword
write_file_based_secrets_as_properties() {
    local java_args_file="/maven/java-args.txt"

    # Remove the existing java-args.txt file if it exists
    if [ -f "$java_args_file" ]; then
        rm "$java_args_file"
    fi

    while IFS='=' read -r -d '' env_var_name env_var_value; do
        if [[ ${env_var_name} == *_FILE ]] ; then
            local env_var_name_without_file_suffix=${env_var_name%_FILE}
            if [ "${!env_var_name:-}" ] && [ "${!env_var_name_without_file_suffix:-}" ]; then
                caf_log "ERROR: Both $env_var_name and $env_var_name_without_file_suffix are set (but are exclusive)"
                exit 1
            fi
            caf_log "INFO: Reading ${env_var_name} (${env_var_value})..."
            # TODO dont log env_var_value
            if [ -e "$env_var_value" ]; then
                local file_contents=$(<${env_var_value})
                if echo "-D${env_var_name_without_file_suffix}=${file_contents}" >> "$java_args_file" ; then
                    caf_log "INFO: Successfully added to java-args.txt: -D${env_var_name_without_file_suffix}=${file_contents}"
                    unset "$env_var_name"
                else
                    caf_log "ERROR: Failed to write to java-args.txt: -D${env_var_name_without_file_suffix}=${file_contents}"
                    exit 1
                fi
            else
                caf_log "ERROR: Failed to read file $env_var_value, file does not exist"
                exit 1
            fi
        fi
    done < <(env -0)
}

# Call the function to write secrets to java-args.txt
write_file_based_secrets_as_properties

unset -f caf_log # Don't export the caf_log function when this script is sourced
