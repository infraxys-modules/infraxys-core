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
        if [ "$git_branch" == "$already_enabled_branch" ]; then
          # ignore this module branch since it was already processed
          return;
        fi;
    fi;

    log_debug "Enabling module $git_url, branch $git_branch";
    local module_dir="$(get_module_directory --git_url "$git_url" --git_branch "$git_branch")";
    if [ "$ON_PROVISIONING_SERVER" == "true" ]; then
        if [ ! -d "$module_dir" ]; then
            log_error "Module directory '$module_dir' doesn't exist. Make sure it's available in Infraxys and that a depen.";
            exit 1;
        fi;
    fi;

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

function modules_enabled() {
    local current_working_directory="$(pwd)";

    cd "$MODULES_ROOT";
    log_info "Sourcing all module root files starting with 'init.' ordered by name.";

    for f in $(find . -maxdepth 5 -type f -name init.\* -printf '%f%%%p\n' | sort | awk -F '%' '{print $2}'); do
        dir="$(dirname "$f")";
        f="$(basename "$f")" # remove dirname
        log_info "Sourcing '$f' in '$dir'";
        cd "$dir";
        source "$f";
        cd "$MODULES_ROOT";
    done;

    log_info "Sourcing all module files directly under 'auto-source' directories, ordered by name.";

    local files="$(find */*/*/*/auto-source/ -type f -printf '%f%%%p\n' 2>&1)";
    if [ "$?" == "0" ]; then
      for f in $(echo "$files" | sort | awk -F '%' '{print $2}'); do
          dir="$(dirname "$f")";
          f="$(basename "$f")" # remove dirname
          log_info "Sourcing '$f' in '$dir'";
          cd "$dir/.."; # always run from the module root
          source "auto-source/$f";
          cd "$MODULES_ROOT";
      done;
    fi;

    log_info "Sourcing all module root files that have a name starting with 'after_modules_enabled.'.";
    for f in $(find . -maxdepth 5 -type f -name after_modules_enabled.\* -printf '%f%%%p\n' | sort | awk -F '%' '{print $2}'); do
        dir="$(dirname "$f")";
        f="$(basename "$f")" # remove dirname
        log_info "Sourcing '$f' in '$dir'";
        cd "$dir";
        source "$f";
        cd "$MODULES_ROOT";
    done;

    cd "$current_working_directory";
}
readonly -f modules_enabled;

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
