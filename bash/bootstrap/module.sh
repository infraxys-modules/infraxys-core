#
# Infraxys module related functions
#
# @author jeroen-manders
#

# Keep track of already enabled modules to avoid loops with circular dependencies
declare -A enabled_modules

function enable_module() {
    local function_name="enable_module" git_url git_branch;
    import_args "$@";
    check_required_arguments $function_name git_url git_branch;

    local already_enabled_branch="${enabled_modules["$git_url"]}";
    if [ -n "$already_enabled_branch" ]; then
        if [ "$git_branch" != "$already_enabled_branch" ]; then
            log_warn "#################  ATTENTION !!! ####################";
            log_warn "#################  ATTENTION !!! ####################";
            log_warn "Request to enable branch '$git_branch' for module '$git_url', but another branch '$already_enabled_branch' is already enabled. Not enabling this one.";
            log_warn "#####################################################";
            log_warn "#####################################################";
        fi;
        return;
    fi;

    log_debug "Enabling module $git_url, branch $git_branch";
    local module_dir="$(get_module_directory --git_url "$git_url" --git_branch "$git_branch")";
    if [ "$ON_PROVISIONING_SERVER" == "true" ]; then
        if [ ! -d "$module_dir" ]; then
            log_error "Module directory '$module_dir' doesn't exist. You need to add this module's branch on this provisioning server in Infraxys.";
            exit 1;
        fi;
    fi;

    initialize_module --module-directory "$module_dir";

    enabled_modules["$git_url"]="$git_branch";
    process_module_json --module_path "$module_dir";
}
readonly -f enable_module;

function get_module_directory() {
    local function_name="get_module_directory" git_url git_branch;
    import_args "$@";
    check_required_arguments "$function_name" git_url git_branch;

    echo "$MODULES_ROOT/$(get_module_relative_directory --git_url "$git_url" --git_branch "$git_branch")";
}
readonly -f get_module_directory;

function get_module_relative_directory() {
    local function_name="get_module_directory" git_url git_branch;
    import_args "$@";
    check_required_arguments "$function_name" git_url git_branch;
    local git_hostname="$(get_hostname_from_git_url "$git_url")";
    local user_or_org="$(get_user_or_org_from_git_url "$git_url")";
    local repo_name="$(get_repo_name_from_git_url "$git_url")";
    echo "$git_hostname/$user_or_org/$repo_name/$git_branch";
}
readonly -f get_module_relative_directory;

function get_repo_name_from_git_url() {
    local git_url="$1";
    local basename="$(basename "$git_url")";
    local repo_name="${basename%.*}";
    echo "$repo_name";
}
readonly -f get_repo_name_from_git_url;

function get_hostname_from_git_url() {
    local git_url="$1";
    if [[ "$git_url" == git@* ]]; then
        local git_hostname="$(echo "$(echo ${git_url/git@/})" | cut -d ':' -f 1)";
    elif [[ "$git_url" == https://* ]]; then
        local git_hostname="$(echo "$git_url" | cut -d '/' -f 3)";
    else
        log_fatal "Unsupported git url: $git_url. These should start with git@ or https://";
        exit 1;
    fi;
    echo "$git_hostname";
}
readonly -f get_hostname_from_git_url;

function get_user_or_org_from_git_url() {
    local git_url="$1";
    if [[ "$git_url" == git@* ]]; then
        local user_or_org="$(dirname "$git_url" | cut -d ":" -f 2)";
    elif [[ "$git_url" == https://* ]]; then
        local user_or_org="$(basename "$(dirname "$git_url")")";
    else
        log_fatal "Unsupported git url: $git_url. These should start with git@ or https://";
        exit 1;
    fi;
    echo "$user_or_org";
}
readonly -f get_user_or_org_from_git_url;

function initialize_module() {
    local module_directory;
    import_args "$@";
    check_required_arguments "initialize_module" module_directory;

    local current_working_directory="$(pwd)";
    cd "$module_directory";

    if [ -f "init.sh" ]; then
        log_debug "Running 'init.sh'.";
        source init.sh;
    fi;

    if [ -d "auto-source" ]; then
        log_debug "Sourcing all files directly under 'auto-source'.";
        for f in auto-source/*.sh; do
            source "$f";
        done;
    fi;
    cd "$current_working_directory";
}

readonly -f initialize_module;

function process_module_json() {
    local function_name="process_module_json" module_path;
    import_args "$@";
    check_required_arguments $function_name module_path;
    local full_path="$module_dir/module.json";
    set -o pipefail
    if [ -f "$full_path" ]; then
        result="$(cat "$full_path" | jq -rc '.dependencies[]?' 2>&1)";
        if [ "$?" != "0" -o -z "$result" ]; then
            return; // no dependencies
        fi;
        local IFS=$'\n' && for dependency in $result; do
            [[ -z "$dependency" ]] && continue;
            local git_url="$(echo "$dependency" | jq -rc '.git_url')";
            local git_branch="$(echo "$dependency" | jq -rc '.branch')";
            [[ "$git_url" == "null" ]] && echo "'git_url' attribute is required for dependencies. Processing $full_path." && exit 1;
            [[ "$git_branch" == "null" ]] && git_branch="master";

            enable_module --git_url "$git_url" --git_branch "$git_branch";
        done;
    fi;
}
readonly -f process_module_json;

function execute_module() {
    local function_name="execute_module" git_url hostname;
    import_args "$@";
    check_required_arguments $function_name git_url;

    local git_branch="${enabled_modules["$git_url"]}";
    if [ -z "$git_branch" ]; then
        log_error "Unable to determine branch in execute_module() for $git_url";
        exit 1;
    fi;
    local module_directory="$(get_module_directory --git_url "$git_url" --git_branch "$git_branch")";
    if [ "$(files_exist --directory "$module_directory" --filename_pattern 'execute_on_target*')" == "true" ]; then
        check_required_arguments $function_name hostname;
        local execute_on_target="true";
        local execute_on_target_script='execute_on_target.*';
    fi;

    local current_command_line="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")";

    if [ "$ON_PROVISIONING_SERVER" == "true" ]; then
        run_or_source_files --directory "$module_directory" --filename_pattern 'execute_on_provisioning_server_before*';
        run_or_source_files --directory "$module_directory" --filename_pattern 'execute_on_provisioning_server*';
        if [ "$execute_on_target" == "true" ]; then
            rsync_directory --hostname $hostname --source_directory "$INFRAXYS_ROOT/" --target_directory "$target_provisioning_root";
            local cmd="ssh -t -k -F $ssh_config_file $hostname \"cd $target_provisioning_root/environments; ./execute_remote.sh\"";
            log_info "Executing action on target";
            eval $cmd;
        fi;
    elif [ "$execute_on_target" == "true" ]; then
        run_or_source_files --directory "$module_directory" --filename_pattern "$execute_on_target_script";
    fi;

    if [ "$ON_PROVISIONING_SERVER" == "true" ]; then
        run_or_source_files --directory "$module_directory" --filename_pattern 'execute_on_provisioning_server_after*';
        if [ "$execute_on_target" == "true" ]; then
            if [ "$SKIP_CLEANUP" != "true" ]; then
                log_info "Cleaning up remote server because variable 'SKIP_CLEANUP' <> 'true'.";
                execute_command_over_ssh --hostname $hostname --command "rm -Rf $target_provisioning_root";
            fi;
        fi;
    fi;
}
readonly -f execute_module;

function zzinit_default_module() {
    local run_on_target="false";
    local run_on_provisioning_server="false";
    local full_path="$(get_module_directory --git_url "$default_module_url" --git_branch "$default_module_branch")";

    log_info "Initializing the default module $default_module_url:$default_module_branch.";

    if [ "$(files_exist --directory "$full_path" --filename_pattern 'run_on_target.*')" == "true" ]; then
        run_on_target="true";
    else
        log_debug "No files exist to run on the target";
    fi;
    if [ "$(files_exist --directory "$full_path" --filename_pattern 'run_on_provisioning_server.*')" == "true" ]; then
        run_on_provisioning_server="true";
    fi;
    if [ "$run_on_provisioning_server" == "true" ] && [ "$run_on_target" == "true" ]; then
        log_error "Only one of 'run_on_target.*' and 'run_on_provisioning_server.sh' can exist for a run. Both are defined in $full_path";
        exit 1;
    fi;

    if [ "$ON_PROVISIONING_SERVER" == "true" ]; then
        log_debug "Running files in the default module root starting with 'run_on_provisioning_server.'.";
        run_or_source_files --directory "$full_path" --filename_pattern 'run_on_provisioning_server.*';
        if [ "$run_on_target" == "true" ]; then
            local executed_command_line="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")";
            run_this_on_target --execute_command_line "$command_line";
        fi;
    elif [ "$run_on_target" == "true" ]; then
        log_debug "Running files in the default module root starting with 'run_on_target.'.";
        run_or_source_files --directory "$full_path" --filename_pattern 'run_on_target.*';
    fi;

    if [ "$ON_PROVISIONING_SERVER" == "true" ]; then
        log_debug "Running files in the default module root starting with 'run_on_provisioning_server_after.'.";
        run_or_source_files --directory "$full_path" --filename_pattern 'run_on_provisioning_server_after.*';
        if [ "$run_on_target" == "true" ]; then
            log_info "Cleaning up remote server.";
            execute_command_remote --command "rm -Rf $full_path";
        fi;
    fi;

    cd "$INSTANCE_DIR";
}
readonly -f zzinit_default_module;
