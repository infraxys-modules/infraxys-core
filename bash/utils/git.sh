
function git_clone_repository() {
	local function_name="git_clone_repository" github_domain github_token organization repository branch target_directory;
	import_args "$@";
	check_required_arguments "$function_name" github_domain organization repository branch;

	if [ -z "$target_directory" ]; then
		target_directory="/tmp/$repository_$branch";
	fi;
	if [ -n "$github_token" ]; then
		local github_url="https://$github_token@$github_domain/$organization/$repository";
	else
		local github_url="https://$github_domain/$organization/$repository";
	fi;
	local clone_command="git clone -q -b $branch $github_url $target_directory";
	mkdir -p "$target_directory";
	log_info "Cloning branch $branch from https://$github_domain/$organization/$repository to $target_directory";
	eval "$clone_command";
}

function create_github_team() {
    local function_name="create_github_team" github_domain github_token organization team_name team_description;
    import_args "$@";
    check_required_arguments "$function_name" github_domain organization team_name team_description;
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

