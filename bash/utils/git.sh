
#Variable example: see README.md
function load_git_config_variable() {
    local git_config_variable set_global_config=false;
    import_args "$@";
    check_required_arguments "load_git_config_variable" git_config_variable;
    local var_filename="/tmp/infraxys/variables/GIT-CONFIG/$git_config_variable";
    log_info "Retrieving Git-config from $var_filename (set global config: $set_global_config).";
    github_domain="$(cat "$var_filename" | jq -r '.hostname')";
    github_token="$(cat "$var_filename" | jq -r '.token')";
    if [ "$set_global_config" == "true" ]; then
        local global_config="$(cat "$var_filename" | jq -r '.config')";
        if [ -n "$global_config" ]; then
            for config in $(echo "$global_config" | jq -cr '.[]'); do
                log_info "Processing 'config' element.";
                local name="$(echo "$config" | jq -r '.name')";
                local value="$(echo "$config" | jq -r '.value')";
                if [ -n "$name" ]; then
                    log_info "Setting global git config '$name' to '$value'.";
                    git config --global $name "$value";
                fi;
            done;
        fi;
    fi;
}

function git_clone_repository() {
	local github_domain github_token organization repository branch target_directory \
	    git_config_variable sparse_path;
	import_args "$@";
	check_required_argument "git_clone_repository" github_domain git_config_variable; # at least one of these two is required
	check_required_arguments "git_clone_repository" organization repository branch;

    if [ -n "$git_config_variable" ]; then
      load_git_config_variable --git_config_variable "$git_config_variable";
    fi;
	if [ -z "$target_directory" ]; then
		target_directory="/tmp/$repository_$branch";
	fi;
	if [ -n "$github_token" ]; then
		local github_url="https://$github_token@$github_domain/$organization/$repository";
	else
		local github_url="https://$github_domain/$organization/$repository";
	fi;
	if [ -n "$sparse_path" ]; then
	  log_info "Perform sparse checkout of path $sparse_path from $github_domain/$organization, branch $branch.";
    git init;
    git config core.sparseCheckout true;
    echo "$sparse_path" >> .git/info/sparse-checkout;
    git remote add origin $github_url;
    git pull --depth 1 origin $branch;
	else
    local clone_command="git clone -q -b $branch $github_url $target_directory";
    mkdir -p "$target_directory";
    log_info "Cloning branch $branch from https://$github_domain/$organization/$repository to $target_directory";
    eval "$clone_command";
  fi;
}

function create_github_team() {
    local git_config_variable github_domain github_token organization team_name team_description;
    import_args "$@";
    check_required_arguments "create_github_team" organization team_name team_description;
    check_required_argument "create_github_team" github_domain git_config_variable;
    if [ -n "$git_config_variable" ]; then
      load_git_config_variable --git_config_variable "$git_config_variable";
    fi;
    local github_rest_endpoint="https://$github_domain/api/v3";
    local auth_header="";
    if [ -n "$github_token" ]; then
       auth_header="-H 'Authorization: token $github_token'";
    fi;

    local data="$(cat << EOF
{
  "name": "$team_name",
  "description": "$team_description",
  "privacy": "closed"
}
EOF
)";

    log_info "Creating GitHub team '$team_name' in org '$organization' of '$github_domain'.";
    curl -k -n -s $auth_header -H "Content-Type: application/json" \
        -X POST --data "$data" $github_rest_endpoint/orgs/$organization/teams;

    log_info "Created GitHub team with description '$team_description'."
}
