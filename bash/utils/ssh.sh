#
# ssh.sh
#
# Ssh related functions and variables
# @author jmanders

_default_ssh_options="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=60 -o LogLevel=ERROR -o PreferredAuthentications=publickey";
default_ssh_options="$_default_ssh_options";
# export_function_names="create_or_replace_block_in_file replace_line_starting_with remove_lines_starting_with file_contains_pattern get_process_line get_substring get_rest_of_line_in_file exit_if_option_is_empty exit_if_empty get_property_from_file install_packages apt_install_packages yum_install_packages yum_install wait_for_last_line_in_file copy_file create_directory parse_long_arguments validate_exit_code wait_until_feedback_processed";

function set_default_ssh_options() {
    if [ "$(function_exists get_bastion_ssh_proxy_command)" ]; then
        if [ -n "$instance_name" ]; then # only set this if the current action is under an instance-container
            default_ssh_options="-o ProxyCommand=\"$(get_bastion_ssh_proxy_command --private_ip $(get_instance_private_ip)) \" $_default_ssh_options -i $ssh_instance_private_key_file";
        fi;
    elif [ -n "$hop_server_ssh_host" ] && [ "$hop_server_ssh_host" != "$container_ssh_host" ]; then
        default_ssh_options="-o ProxyCommand=\"ssh $_default_ssh_options root@$hop_server_ssh_host -W $container_ssh_host:22\" $_default_ssh_options";
    else
        default_ssh_options="$_default_ssh_options";
    fi;
}

function add_ssh_keys_from_file() {
	local function_name="add_ssh_keys_from_file" filename;
	import_args "$@";
	check_required_argument $function_name filename;
	if [ -z "$SSH_AUTH_SOCK" ]; then # ssh agent not yet running
        eval `ssh-agent -s`
    fi;
	while read _line; do
		local parsed_line=$(echo "$_line" | tr -d ' ' | tr -d '\t')
		if [ -n "$parsed_line" ]; then
			log_debug "Adding ssh key '$parsed_line'.";
			local file_mode="$(get_file_mode --filename $parsed_line)";
			if [ "$file_mode" != "600" ]; then
				log_info "Setting file mode to 600 for $parsed_line";
				chmod 600 "$parsed_line";
			fi;
			ssh-add "$parsed_line";
		fi;
	done <$filename;
}

function get_remote_ssh_args() {
    echo "export INITIAL_PID=$INITIAL_PID;export ON_PROVISIONING_SERVER=false; export APPLICATION_USER=$APPLICATION_USER; export INTERACTIVE=$INTERACTIVE; export EXECUTING_PIPELINE=$EXECUTING_PIPELINE;export THREAD_NUMBER=$THREAD_NUMBER;export INSTANCE_DIR='$TARGET_INSTANCE_DIR';export MODULES_ROOT='$TARGET_MODULES_ROOT'";
}

function get_ssh_part_for_connect() {
	local function_name="get_ssh_part_for_file" ssh_host="";
	import_args "$@";

	if [ -z "$ssh_host" ]; then
		echo "";
	else
		if [ -z "$ssh_user" ]; then
			echo "$ssh_host";
		else
			echo "$ssh_user@$ssh_host";
		fi;
	fi;
}

function is_localhost() {
	local ssh_host="$1";
	if [ "$ssh_host" == "localhost" -o "$ssh_host" == "127.0.0.1" ]; then
		echo true;
	else
		echo false;
	fi;
}

function wait_for_ssh_connection() {
	local function_name="wait_for_ssh_connection" ssh_host max_wait=6000 exit_on_failure=true;
	import_args "$@";

	check_required_argument $function_name ssh_host;
    local time_remaining=max_wait;
    let timeout=10;
    if [ -n "$hop_server_ssh_host" ] && [ "$hop_server_ssh_host" != "$ssh_host" ]; then
    	log_info_no_cr "Waiting for ssh at $ssh_host through $hop_server_ssh_host .";
	else
		log_info_no_cr "Waiting for ssh at $ssh_host .";
	fi;
	set +e;
	waited="false";
	while true; do
		if [ -n "$hop_server_ssh_host" ] && [ "$hop_server_ssh_host" != "$ssh_host" ]; then
        	ssh $_default_ssh_options -o ConnectTimeout=$timeout root@$hop_server_ssh_host "nmap -Pn -p 22 $ssh_host| grep 22/tcp | grep open >/dev/null 2>&1";
		else
		    if [ "$waited" == "true" ]; then
		        sleep 5; # nc often comes back immediately ...
		    fi;
		    if [ "$(uname -s)" == "Darwin" ]; then
			    nc -G $timeout -w 1 $ssh_host 22 >/dev/null 2>&1;
			else
			    nmap -Pn -p 22 $ssh_host| grep 22/tcp | grep open >/dev/null 2>&1;
			fi;
		fi;
        if [ $? -eq 0 ]; then
            break;
        fi;
        waited="true";
        let time_remaining-=$timeout;

        if [ $time_remaining -le 1 ]; then
            echo "";
            log_error "Ssh still not available.";
            if [ -n "$hop_server_ssh_host" ] && [ "$hop_server_ssh_host" != "$ssh_host" ]; then
                echo "Ssh result:"
                ssh $_default_ssh_options -o ConnectTimeout=$timeout root@$hop_server_ssh_host "nmap -Pn -p 22 $ssh_host| grep 22/tcp | grep open"
            else
                echo "nc result: (nc -G $timeout -w 1 $ssh_host 22)"
                if [ "$(uname -s)" == "Darwin" ]; then
                    nc -G $timeout -w 1 $ssh_host 22;
                else
                    nmap -Pn -p 22 $ssh_host| grep 22/tcp | grep open >/dev/null 2>&1;
                fi;
            fi;
            if [ "$exit_on_failure" == "true" ]; then
                exit 1;
            else
                return 1;
            fi;
        fi;
        echo -n ".";
    done;
    echo " ";
    set -e;
    if [ "$waited" == "true" ]; then
        sleep 4; # ssh daemon might not yet be fully operational.
    fi;
}

function execute_command_remote() {
	local function_name="execute_command_remote" ssh_host="$container_ssh_host" ssh_user=root command message exit_on_error="true";
	import_args "$@";
	check_required_arguments $function_name ssh_host ssh_user command;
	[ -n "$message" ] && log_info "$message";

	#if [ -n "$hop_server_ssh_host" ] && [ "$hop_server_ssh_host" != "$ssh_host" ]; then
        if [ "$(should_run_parallel --ssh_host $ssh_host)" == "true" ]; then
            log_debug "Executing remote in parallel."
            for h in $ssh_host; do
                local cmd="ssh -t $ssh_user@$h -k $ssh_key_options $default_ssh_options \"$(get_remote_ssh_args); $command\""
                eval $cmd &
            done;
            log_debug "Remote processes started.";
            wait_for_background_jobs;
        else
            log_debug "Executing command remote on $ssh_user@$ssh_host.";
            local cmd="ssh -t $ssh_user@$ssh_host -k $ssh_key_options $default_ssh_options \"$(get_remote_ssh_args); $command\"";
            eval $cmd;
		fi;
    #else
    #	ssh -t $ssh_user@$ssh_host -k $_default_ssh_options "$(get_remote_ssh_args); $command";
    #fi;
    last_result="$?";
    if [ "$last_result" != "0" ] && [ "$exit_on_error" == "true" ]; then
    	exit $last_result;
    else
    	return $last_result;
    fi;
}

function get_export_function_names() {
    echo "$LOGGING_EXPORTED_FUNCTION_NAMES $LINUX_EXPORTED_FUNCTION_NAMES $FILE_EXPORTED_FUNCTION_NAMES $VALIDATE_EXPORTED_FUNCTION_NAMES $BASH_EXPORTED_FUNCTION_NAMES $CUSTOM_EXPORTED_FUNCTION_NAMES $dependencies";
}

function get_export_variables() {
    echo "export os_flavor=\"$os_flavor\";";
}

function export_shared_functions() {
    local function_names="$(get_export_function_names)";
    for function_name in $function_names; do
        export -f $function_name;
    done;
}

function confirm_or_abort() {
    local function_name="ask_confirmation" message expected_answer="y";
    import_args "$@";
    check_required_argument $function_name message;
    if [ "$INTERACTIVE" == "true" ]; then
        echo "--------------------";


        local datepart=$(date +"%d-%m-%Y %H:%M:%S,%3N");
        read -p "[$datepart] [`hostname`] [QUESTION] [`whoami`] $message" answer;
        if [ "$answer" != "$expected_answer" ]; then
            log_warn "You didn't an'wer '$expected_answer'. Aborting.";
            exit 1;
        fi;

    fi;
}

function execute_function_remote() {
	local _function_name="execute_function_remote" function_name ssh_host= ssh_user \
			message in_background=false exit_on_error="true" extra_functions_to_export extra_arguments;
	import_args "$@";
	[ -z "$ssh_host" ] && ssh_host="$connect_host";
	[ -z "$ssh_host" ] && ssh_host="$container_ssh_host";
	[ -z "$ssh_user" ] && ssh_user="$connect_username";
	[ -z "$ssh_user" ] && ssh_user="root";
	check_required_argument $_function_name ssh_host;
	check_required_argument $_function_name ssh_user;
	check_required_argument $_function_name function_name;
	shift 2; # remove --function_name name from argument list. If ssh_host and/or ssh_user are passed here, then they will be passed to the function with the other arguments

	local function_arguments="$@";
	local function_dependencies="$(get_variable_by_name --variable_name function_${function_name}_function_dependencies)";
	local variable_dependencies="$(get_variable_by_name --variable_name function_${function_name}_variable_dependencies)";
	variable_dependencies="variable_dependencies $CUSTOM_EXPORTED_VARIABLE_NAMES"
	local _export_function_names="$(get_export_function_names)";
	[ -n "$extra_functions_to_export" ] && _export_function_names="$_export_function_names $extra_functions_to_export";
	[ -n "$function_dependencies" ] && _export_function_names="$_export_function_names $function_dependencies";

	local export_variables=""
	if [ -n "$variable_dependencies" ]; then
		for variable_name in $variable_dependencies; do
			export_variables="${export_variables}export $variable_name='$(get_variable_by_name --variable_name $variable_name)';";
		done;
	fi;
	export_variables="$(get_export_variables) $export_variables";
	[ -n "$message" ] && log_info "$message";

    if [ "$(function_exists get_bastion_ssh_proxy_command)" ]; then
        local ssh_command="$(get_instance_ssh_command --private_ip $ssh_host --ssh_connect_username $ssh_user)";
        local proxy_command="$(get_bastion_ssh_proxy_command --private_ip $ssh_host)";
        local typeset_command="$(typeset -f $function_name $_export_function_names); export -f $_export_function_names; $(get_remote_ssh_args); $export_variables $function_name $function_arguments";

        if [ "$in_background" == "true" ]; then
            $ssh_command  -o ProxyCommand="$proxy_command" "$typeset_command" &
        else
            $ssh_command  -o ProxyCommand="$proxy_command" "$typeset_command";
		fi;
    elif [ -n "$hop_server_ssh_host" ] && [ "$hop_server_ssh_host" != "$ssh_host" ]; then
		if [ "$in_background" == "true" ]; then
            ssh -t  $ssh_user@$ssh_host -k -o ProxyCommand="ssh -k $_default_ssh_options root@$hop_server_ssh_host -W $ssh_host:22" $_default_ssh_options \
                "$(typeset -f $function_name $_export_function_names); export -f $_export_function_names; $(get_remote_ssh_args); $export_variables $function_name $function_arguments" &
		else
            ssh -t  $ssh_user@$ssh_host -k -o ProxyCommand="ssh -k $_default_ssh_options root@$hop_server_ssh_host -W $ssh_host:22" $_default_ssh_options \
                "$(typeset -f $function_name $_export_function_names); export -f $_export_function_names; $(get_remote_ssh_args); $export_variables $function_name $function_arguments";
		fi;
    else
    	if [ "$in_background" == "true" ]; then
    		ssh -t  $ssh_user@$ssh_host -k $_default_ssh_options \
                "$(typeset -f $function_name $_export_function_names); export -f $_export_function_names; $(get_remote_ssh_args); $export_variables $function_name $function_arguments" &
		else
            ssh -t $ssh_user@$ssh_host -k $_default_ssh_options \
                "$(typeset -f $function_name $_export_function_names); export -f $_export_function_names; $(get_remote_ssh_args); $export_variables $function_name $function_arguments";
		fi;
    fi;
    last_result="$?";
    if [ "$last_result" != "0" ] && [ "$exit_on_error" == "true" ]; then
    	exit $last_result;
    else
    	return $last_result;
    fi;
}

function enable_root_login() {
	local function_name="enable_root_login" ssh_host="$container_ssh_host" ssh_user remove_other_user="false";
	import_args "$@";
	check_required_argument $function_name ssh_host;
	check_required_argument $function_name ssh_user;

	set +e;
	log_info "Sudo might complain that the hostname is unknown. This is because the hostname isn't in /etc/hosts. The command succeeds though.";
	execute_command_remote --message "Copying authorized keys file from $ssh_user to root on $ssh_host." --exit_on_error "false" --ssh_user $ssh_user \
			--command "if [ -f ~/.ssh/authorized_keys ]; then sudo cp ~/.ssh/authorized_keys /root/.ssh/; fi;";
	set -e;
    if [ "$remove_other_user" == "true" ]; then
     	if [ "$ssh_user" == "root" ]; then
     	    log_error "Request is to remove the other user, but this user is root. Cannot remove root.";
     	    exit 1;
     	fi;
     	set +e;
    	execute_command_remote --message "Removing user $ssh_user." --exit_on_error "false" --ssh_user root --command "userdel $ssh_user";
    	set -e;
    fi;
}

function_configure_ssh_function_dependencies="restart_ssh_service";
function_configure_ssh_variable_dependencies="os_flavor";
function configure_ssh() {
    log_info "Configuring ssh authentication";
    local dateString="`date +'%d-%m-%Y %H:%M:%S'`"
    update_line_in_file --filename "/etc/ssh/sshd_config" --starts_only false --text "GSSAPIAuthentication" --new_text "GSSAPIAuthentication no # set by Infraxys on $dateString";
    update_line_in_file --filename "/etc/ssh/sshd_config" --starts_only false --text "GSSAPICleanupCredentials" --new_text "GSSAPICleanupCredentials no # set by Infraxys on $dateString";
    restart_ssh_service;
}

function restart_ssh_service() {
	if [ "$os_flavor" == "ubuntu" -o "$os_flavor" == "debian" ]; then
        service ssh restart
    else
        service sshd restart
    fi;

    sleep 3; #wait for the restart process to exit
}

function execute_on_target() {
    local executed_command_line="$command_line";
    if [ "$ON_PROVISIONING_SERVER" == "true" ]; then
        run_this_on_target --execute_command_line  "$executed_command_line";
    else
        $@;
    fi;
}

function run_this_on_target() {
    local function_name="run_this_on_target" execute_command_line;
    import_args "$@";
    local TARGET_MODULES_ROOT="/tmp/infraxys-provisioning-server/modules";
    if [ "$ON_PROVISIONING_SERVER" == "true" ]; then
        transfer_directory --source_directory "$INFRAXYS_ROOT/" --target_directory "$target_provisioning_root";
        if [ -n "$container_ssh_key_file" -a "$target_is_localhost" == "false" ]; then
            local ssh_key_options="-i $container_ssh_key_file";
        else
            local ssh_key_options="";
        fi;
    fi;
    if [ "$ON_PROVISIONING_SERVER" == "false" ] || [ "$target_is_localhost" == "true" ]; then
        log_debug "Executing $execute_command_line on localhost";
        local orig_instance_dir="$INSTANCE_DIR";
        local orig_modules_root="$MODULES_ROOT";
        export ON_PROVISIONING_SERVER=false;
        export INSTANCE_DIR="$TARGET_INSTANCE_DIR";
        export MODULES_ROOT="$TARGET_MODULES_ROOT";
        cd $TARGET_INSTANCE_DIR;
        ./$execute_command_line $ORIG_ARGUMENTS;
        export ON_PROVISIONING_SERVER=true;
        export INSTANCE_DIR="$orig_instance_dir";
        export MODULES_ROOT="$orig_modules_root";
    else
        if [ "$(should_run_parallel --ssh_host $container_ssh_host)" == "true" ]; then
            for h in $container_ssh_host; do
                log_debug "Executing remote on $h (background)."
                #local cmd="ssh -t $container_ssh_user@$h -k $ssh_key_options $default_ssh_options \"$(get_remote_ssh_args); cd $TARGET_INSTANCE_DIR; ./$executed_filename $ORIG_ARGUMENTS\""
                local cmd="ssh -t $container_ssh_user@$h -k $ssh_key_options $default_ssh_options \"$(get_remote_ssh_args); cd $TARGET_INSTANCE_DIR; $execute_command_line\""
                eval $cmd &
            done;
            log_debug "Remote processes started.";
            wait_for_background_jobs;
        else
            log_debug "Executing execute_remote.sh on $container_ssh_user@$container_ssh_host in $target_provisioning_root/environments."
            local cmd="ssh -t $container_ssh_user@$container_ssh_host -k $ssh_key_options $default_ssh_options \"$(get_remote_ssh_args); cd $target_provisioning_root/environments; ./execute_remote.sh\"";
            eval $cmd;
        fi;
    fi;
}

function create_key_file() {
    local function_name=create_key_file key_filename key_username append_to_authorized_keys_of_user
    import_args "$@";
    check_required_arguments $function_name key_filename key_username;

    local ssh_directory="$(eval echo ~$key_username)/.ssh";
    local full_path="$ssh_directory/$key_filename";

	create_directory --name "$ssh_directory" --owner $key_username --mode 700;

	if [ -f "$full_path" ]; then
		log_warn "File $full_path already exists.";
	else
		if [ "$key_username" == "`id -un`" ]; then
		    log_info "Generating key in $full_path.";
			ssh-keygen -N "" -f $full_path;
		else
			log_info "Generating key in $full_path for user $key_username.";
			su $key_username -c "ssh-keygen -N \"\" -f $full_path";
		fi;
	fi;
	if [ -n "$append_to_authorized_keys_of_user" ]; then
	    local target_user_ssh_directory="$(eval echo ~$append_to_authorized_keys_of_user)/.ssh";
	    create_directory --name "$target_user_ssh_directory" --owner $append_to_authorized_keys_of_user --mode 700;
	    log_info "Appending ${full_path}.pub to $target_user_ssh_directory/authorized_keys";
	    cat "${full_path}.pub" >> "$target_user_ssh_directory/authorized_keys";
	fi;
}



