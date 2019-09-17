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

cd "$MODULES_ROOT/github.com/infraxys-modules/infraxys-core/master/bash";

for f in utils/*.sh; do
    source $f;
done;

import_args "$@"; # it is possible to override variables or pass arguments when executing from the command line or through the REST API

cd "$MODULES_ROOT/github.com/infraxys-modules/infraxys-core/master/bash/bootstrap"
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

    cd "$INSTANCE_DIR";
    log_debug "Environment preparation complete";
}
readonly -f prepare_environment;

function source_initial_files() {
    log_trace 'Exporting all entries from files called *.auto_properties for the environment, container and instance';
    for f in $INSTANCE_DIR/../../environment.auto/*.auto_properties $INSTANCE_DIR/../container.auto/*.auto_properties $INSTANCE_DIR/*.auto_properties $INSTANCE_DIR/run_overrides/*.auto_properties; do
        if [ -f "$f" ]; then # the path with *.auto_properties is returned if no files matched
            log_trace "Sourcing file $f";
            #export_file "$f";
            source "$f";
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
