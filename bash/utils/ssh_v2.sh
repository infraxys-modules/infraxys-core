#!/usr/bin/env bash

# Usage:
#   optional: create variable 'CUSTOM_EXPORTED_VARIABLE_NAMES' with a space-delimited list of variable names that should be available on the target
#   optional: create a variable function_<function_name>_function_dependencies with a space-delimited list of function names that should be available on the target
#   optional: create a variable function_<function_name>_variable_dependencies with a space-delimited list of variable names that should be available on the target

function execute_function_over_ssh() {
    local function_name hostname in_background="false" exit_on_error="true" export_standard_functions="true" \
        retrieve_file retrieve_file_local_path transfer_file transfer_file_remote_path create_directory="false" \
        override_ssh_user url_encode_variables="false";

    local function_arguments="$@"; # this will include function_name, hostname, exit_on_error and in_background, but that's ok
    import_args "$@";
    check_required_arguments "execute_function_over_ssh" function_name hostname;

    #generate_environment_ssh_config;
    local _export_function_names="";

    #log_info "Getting function dependencies";
    local function_dependencies="$(get_variable_by_name --variable_name function_${function_name}_function_dependencies)";
    local variable_dependencies="$(get_variable_by_name --variable_name function_${function_name}_variable_dependencies)";
    variable_dependencies="variable_dependencies $CUSTOM_EXPORTED_VARIABLE_NAMES"

    local _export_function_names="";
    [[ "$export_standard_functions" == "true" ]] && _export_function_names="$(get_export_function_names)";

	  [ -n "$function_dependencies" ] && _export_function_names="$_export_function_names $function_dependencies";

    local export_variables=""
    if [ -n "$variable_dependencies" ]; then
      for variable_name in $variable_dependencies; do
        export_variables="${export_variables}export $variable_name='$(get_variable_by_name --variable_name $variable_name)';";
      done;
    fi;
	  export_variables="$(get_export_variables) $export_variables";

    # escape backslashes and colons
    local escaped_function_arguments="$(echo "$function_arguments" | sed 's/\\/\\\\/g' | sed 's/\:/\\\:/g' | sed 's/[(]/\\\(/g' )";
    local typeset_command="$(typeset -f $function_name $_export_function_names); export -f $_export_function_names; $(get_default_ssh_variables); $export_variables $function_name $escaped_function_arguments";
    local user_part="";
    if [ -n "$override_ssh_user" ]; then
      user_part="$override_ssh_user@";
    fi;

    local ssh_command="ssh -k $user_part$hostname";

    if [ -n "$transfer_file" ]; then
      [ -z "$transfer_file_remote_path" ] && transfer_file_remote_path="$transfer_file";

      copy_file_to_host --hostname "$hostname" --source_path "$transfer_file" --target_path "$transfer_file_remote_path" \
          --create_directory "$create_directory";
    fi;
    local - # set option locally
    set +e;
    if [ "$in_background" == "true" ]; then
        $ssh_command "$typeset_command" &
        local last_exit_code="$?";
    else
      $ssh_command "$typeset_command";
      local last_exit_code="$?";
      if [ -n "$retrieve_file" ]; then
        [ -z "$retrieve_file_local_path" ] && retrieve_file_local_path="$retrieve_file";
        copy_file_from_host --hostname "$hostname" --source_path "$retrieve_file" --target_path "$retrieve_file_local_path" \
            --delete_source "true";
      fi;
    fi;

    export LAST_SSH_EXIT_CODE="$last_exit_code";
    if [ "$last_exit_code" != "0" ] && [ "$exit_on_error" == "true" ]; then
    	exit $last_exit_code;
    fi;
}

function execute_command_over_ssh() {
    local function_name="execute_command_over_ssh" hostname command in_background="false" exit_on_error="true"
    import_args "$@";
    check_required_arguments $function_name hostname command;

    #generate_environment_ssh_config;

    local escaped_command="$(echo "$command" | sed 's/\\/\\\\/g')";
    local ssh_command="ssh -k $hostname \"$(get_default_ssh_variables); $escaped_command\"";

    if [ "$in_background" == "true" ]; then
        eval $ssh_command &
    else
        eval $ssh_command;
    fi;

    local last_exit_code="$?";
    if [ "$last_exit_code" != "0" ] && [ "$exit_on_error" == "true" ]; then
    	exit $last_exit_code;
    else
    	return $last_exit_code;
    fi;
}

function rsync_directory() {
    local function_name="rsync_directory" hostname source_directory target_directory;
    import_args "$@";
    check_required_arguments $function_name hostname source_directory target_directory;
    #generate_environment_ssh_config;
    log_info "Synchronizing directory $source_directory to $hostname:$target_directory";
    rsync -ah -e "ssh -k " "$source_directory" "$hostname:$target_directory";
}

function copy_file_from_host() {
    local function_name="copy_file_from_host" hostname source_path target_path delete_source="false";
    import_args "$@";
    check_required_arguments $function_name hostname source_path target_path;
    log_info "Copying file $target_path from $hostname:$source_path";
    scp -q $hostname:"$source_path" "$target_path";

    if [ "$delete_source" == "true" ]; then
      execute_command_over_ssh --hostname "$hostname" --command "rm -Rf '$source_path'";
    fi;
}

function copy_file_to_host() {
    local function_name="copy_file_to_host" hostname source_path target_path create_directory="true";
    import_args "$@";
    check_required_arguments $function_name hostname source_path target_path create_directory;
    if [ "$create_directory" == "true" ]; then
        local directory_name="$(dirname "$target_path")";
        log_info "Creating directory $directory_name on $hostname";
        execute_command_over_ssh --hostname "$hostname" --command "mkdir -p '$directory_name'";
    fi;
    log_info "Copying file $source_path to $hostname:$target_path";
    scp -q "$source_path" $hostname:"$target_path";
}

function get_default_ssh_variables() {
    echo "export INITIAL_PID=$INITIAL_PID;export ON_PROVISIONING_SERVER=false;export APPLICATION_USER=$APPLICATION_USER;export INTERACTIVE=$INTERACTIVE;export INSTANCE_DIR='$TARGET_INSTANCE_DIR';export MODULES_ROOT='$TARGET_MODULES_ROOT'";
}

function should_run_parallel() {
    local function_name="should_run_parallel" ssh_host;
    import_args "$@";
    check_required_argument $function_name ssh_host
    if [[ "$ssh_host" == *\ * ]]; then
        echo "true";
    else
        echo "false";
    fi;
}


