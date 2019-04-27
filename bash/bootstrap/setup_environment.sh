#
# Source this script from any instance script to have all necessary files and variables configured
#
# @author jeroen-manders
#
# This script assumes that the following variables are set. Infraxys does this for you.
#
# INSTANCE_DIR: the directory to the instance scripts. This is underneath the container directory when on
#       the provisioning server. Provided by this script itself when on the target server.
# ON_PROVISIONING_SERVER: true or false
# THREAD_NUMBER: unique at a certain moment in time.
# MODULES_ROOT: directory containing Infraxys modules
#

log_info "Executing $0";

: ${LOG_TRACE:=false}; export LOG_TRACE;

if [ "$ON_PROVISIONING_SERVER" == "true" ]; then
: ${INFRAXYS_ROOT:=/tmp/infraxys}; export INFRAXYS_ROOT;
else
: ${INFRAXYS_ROOT:=/tmp/infraxys/run_$$}; export INFRAXYS_ROOT;
fi;

cd "$MODULES_ROOT/github.com/jeroenmanders/core/master/bash";

for f in utils/*.sh; do
    source $f;
done;

import_args "$@"; # it is possible to override variables or pass arguments when executing from the command line or through the REST API

cd "$MODULES_ROOT/github.com/jeroenmanders/core/master/bash/bootstrap"
source ./module.sh;
source ./ssh.sh;

function prepare_environment() {
    if [ "$ON_PROVISIONING_SERVER" == "true" ]; then
        log_trace "Preparing files";
        mkdir /infraxys/run_overrides
        if [ -z "$INITIAL_PID" ]; then
            export INITIAL_PID="$$";
        fi;
    fi;
    source_initial_files;
    log_trace "Setting variables necessary for the legacy scripts. Remove when migration is fully done"
    local date_string="$(date +"%Y%m%d-%H%M%S")";
    export target_provisioning_root="/tmp/infraxys_${date_string}_$INITIAL_PID";
    export TARGET_INSTANCE_DIR="$target_provisioning_root/environments/$environment_directory/$container_directory/$instance_directory";
    export local_file_directory="$target_provisioning_root/files"; # TODO: remove variable local_file_directory and use target_files_root instead
    export target_files_root="$target_provisioning_root/files";
    export target_directory="$target_provisioning_root";
    #initialize_module --module-directory "$MODULES_ROOT/github.com/jeroenmanders/core/master/system"
    #initialize_module --module-directory "$MODULES_ROOT/github.com/jeroenmanders/core/master/packaging"
    #initialize_module --module-directory "$MODULES_ROOT/github.com/jeroenmanders/core/master/python"

    cd "$INSTANCE_DIR";
    log_debug "Environment preparation complete";
}
readonly -f prepare_environment;

function source_initial_files() {
    log_trace 'Exporting all entries called *.auto_properties for the environment, container and instance';
    for f in $INSTANCE_DIR/../../environment.auto/*.auto_properties $INSTANCE_DIR/../container.auto/*.auto_properties $INSTANCE_DIR/*.auto_properties $INSTANCE_DIR/run_overrides/*.auto_properties; do
        if [ -f "$f" ]; then # the path with *.auto_properties is returned if no files matched
            log_trace "Exporting file $f";
            export_file "$f";
        fi;
    done;

    if [ "$ON_PROVISIONING_SERVER" == "true" ]; then
        if [ -n "$ORIG_ARGUMENTS" ]; then
            log_trace "Getting overrrides: $ORIG_ARGUMENTS -- $@"
            import_args_into_file "$INFRAXYS_ROOT/run_overrides/override.auto_properties" $ORIG_ARGUMENTS;
            if [ -f "$INFRAXYS_ROOT/run_overrides/override.auto_properties" ]; then
                log_trace "Using overrides:"
                cat /infraxys/run_overrides/override.auto_properties
            else
                log_warn "Commandline overrides are not handled properly.";
            fi;
        fi;
    fi;
    if [ -n "$container_ssh_key_file" ]; then
        log_trace "Changing path $container_ssh_key_file to $INSTANCE_DIR/$container_ssh_key_file";
        container_ssh_key_file="$INSTANCE_DIR/$container_ssh_key_file";
    fi;
    set_default_ssh_options;
    if [ "$ON_PROVISIONING_SERVER" == "true" ]; then
        if [ -f "$ENVIRONMENT_DIR/environment.auto/ssh_key_files.txt" ]; then
            cd "$INFRAXYS_ROOT/environments";
            add_ssh_keys_from_file --filename "$ENVIRONMENT_DIR/environment.auto/ssh_key_files.txt";
        fi;
    fi;
}
readonly -f source_initial_files;

function execute_gather_scripts() {
    local start_dir="$(pwd)";
    if [ "$ON_PROVISIONING_SERVER" == "false" ]; then
        return;
    fi;

    log_debug "Executing scripts with names starting with 'prepare_execution' in all enabled modules.";
    for git_url in "${!enabled_modules[@]}"; do
        local git_branch="${enabled_modules["$git_url"]}";
        run_or_source_files --directory "$(get_module_directory --git_url "$git_url" --git_branch "$git_branch")" --filename_pattern 'prepare_execution.*';
    done;

    if [ "$run_or_source_files_found" == "true" ]; then
        log_debug "Container or environment .auto files might have changed. Retrieving and loading them again.";
        set_all_host_ips;
        source_initial_files;
    fi;
    cd "$start_dir";
}
readonly -f execute_gather_scripts;

function set_all_host_ips() {
    cd $INSTANCE_DIR;
    all_target_ips="";
    extra_sid_part="";
    if [ ! -s "/tmp/_host_names_with_ips.tmp" ]; then
        log_debug "No ips retrieved, so not reloading them";
        return;
    else
        log_debug "Host names with ips;";
        cat "/tmp/_host_names_with_ips.tmp";
    fi;
    while IFS='' read -r line || [[ -n "$line" ]]; do
        ORG_IFS="${IFS}";
        IFS=",";
        words=($line)
        IFS="$ORG_IFS";
        local hostname="${words[0]}";
        local private_ip_addresses="${words[1]}";
        local ssh_hosts="${words[2]}";
        if [ -z "$ssh_hosts" ]; then
            ssh_hosts="$private_ip_addresses";
        elif [ -z "$private_ip_addresses" ]; then
            private_ip_addresses="$ssh_hosts";
        fi;
        if [ -n "$hop_server_container_name" ] && [ "$hostname" != "$hop_server_container_name" ]; then
            ssh_hosts="$private_ip_addresses"; # ssh connections are done to the private ip through the hop server
        fi;
        if [ "$ansible_enabled" == "true" -o "$ansible_enabled" == "1" ]; then
            #if [ -f "$ansible_execution_directory/$ansible_environment_directory/$ansible_hosts_filename" ]; then
            if [ -f "$INFRAXYS_ROOT/ansible/ansible_host_inventory" ]; then
                if [ "$(uname -s)" == "Darwin" ]; then
                    sed -i '' "s/^$hostname ansible_ssh_host=\"[A-Za-z0-9.]*\" ansible_private_ip=\"[A-Za-z0-9.]*\"/$hostname ansible_ssh_host=\"$ssh_hosts\" ansible_private_ip=\"$private_ip_addresses\"/" $INFRAXYS_ROOT/ansible/ansible_host_inventory
                else
                    sed -i "s/^$hostname ansible_ssh_host=\"[A-Za-z0-9.]*\" ansible_private_ip=\"[A-Za-z0-9.]*\"/$hostname ansible_ssh_host=\"$ssh_hosts\" ansible_private_ip=\"$private_ip_addresses\"/" $INFRAXYS_ROOT/ansible/ansible_host_inventory
                fi;
            else
                for f in "$ansible_execution_directory/$ansible_environment_directory/$ansible_hosts_filename/*"; do
                    if [ "$(uname -s)" == "Darwin" ]; then
                        sed -i '' "s/^$hostname ansible_ssh_host=\"[A-Za-z0-9.]*\" ansible_private_ip=\"[A-Za-z0-9.]*\"/$hostname ansible_ssh_host=\"$ssh_hosts\" ansible_private_ip=\"$private_ip_addresses\"/" $f
                    else
                        sed -i "s/^$hostname ansible_ssh_host=\"[A-Za-z0-9.]*\" ansible_private_ip=\"[A-Za-z0-9.]*\"/$hostname ansible_ssh_host=\"$ssh_hosts\" ansible_private_ip=\"$private_ip_addresses\"/" $f
                    fi;
                done;
            fi;
        fi;
	if [ -d "../../$hostname" ]; then
	        for f in $(find ../../$hostname -type f -name container.auto_properties); do
        	    if [ "$(uname -s)" == "Darwin" ]; then
                	sed -i '' "s/^container_ssh_host=.*/container_ssh_host=$ssh_hosts/" $f;
	            else
        	        sed -i "s/^container_ssh_host=.*/container_ssh_host=$ssh_hosts/" $f;
	            fi;
	        done;
	fi;	
        if [ "$hop_server_container_name" == "$hostname" ] && [ "$hop_server_container_name" != "$container_name" ]; then
            for f in $(find ../.. -type f -name container.auto_properties); do
                if [ "$(uname -s)" == "Darwin" ]; then
                    sed -i '' "s/^hop_server=.*/hop_server=$ssh_hosts/" $f;
                    sed -i '' "s/^hop_server_ssh_host=.*/hop_server_ssh_host=$ssh_hosts/" $f;
                else
                    sed -i "s/^hop_server=.*/hop_server=$ssh_hosts/" $f;
                    sed -i "s/^hop_server_ssh_host=.*/hop_server_ssh_host=$ssh_hosts/" $f;
                fi;
            done;
            for f in $(find ../.. -type f -name core.py); do
                if [ "$(uname -s)" == "Darwin" ]; then
                    sed -i '' "s/^Infraxys.hop_server=.*/Infraxys.hop_server=\"$ssh_hosts\"/" $f;
                else
                    sed -i "s/^Infraxys.hop_server=.*/Infraxys.hop_server=\"$ssh_hosts\"/" $f;
                fi;
            done;
        fi;
        for f in $(find ../../$hostname -maxdepth 2 -type f -name core); do
            if [ "$(uname -s)" == "Darwin" ]; then
                sed -i '' "s/^export primary_ip_address=.*/export primary_ip_address='$ssh_hosts';/" $f;
                sed -i '' "s/^export target_server=.*/export target_server='$ssh_hosts';/" $f;
            else
                sed -i "s/^export primary_ip_address=.*/export primary_ip_address='$ssh_hosts';/" $f;
                sed -i "s/^export target_server=.*/export target_server='$ssh_hosts';/" $f;
            fi;
        done;
    done < "/tmp/_host_names_with_ips.tmp"
}
readonly -f set_all_host_ips;