#
# Functions for setting and passing environment variables and dependencies
#
# @author jeroen-manders
#

BASH_EXPORTED_FUNCTION_NAMES="import_args replace_spaces function_exists update_line_in_file remove_lines_in_file_that_start_with block_in_file file_contains_pattern";

function import_args() {
	local varvalue="";
	local varname="";
	local import_to_file="";
	if [ $# -ge 2 ]; then
	  if [ "$1" == "import_to_file" ]; then
	      import_to_file="$2";
	      shift 2;
	  fi;
	fi;
    while [[ $# > 1 ]]; do
        varname="$1";
        varname=${varname//[-]/_};
        varname=$(echo "$varname" | tr "[:upper:]" "[:lower:]");
        shift;
        if [[ $# == 0 ]]; then #  || "$1" == --* ]]; then # variable has no value --> disabled because an argument might be: --arguments "--arg1 blabla"
        	varvalue="";
       	else
        	varvalue="$1";
       		if [[ "$varvalue" == --* ]]; then
       			# next argument, this one has an empty value
       			continue;
			fi;
        	shift;

        	while true; do # handle spaces in variable values. Necessary for remote execution with arguments
        	    [[ $# -gt 0 ]] || break;
        	    local nextvar="$1";
        	    if [[ -z "$nextvar" ]] || [[ "$nextvar" == --* ]]; then
        	        break;
        	    fi;
        	    varvalue="$varvalue $nextvar";
        	    shift;
        	done;

        fi;
        varname=${varname:2}; # remove the starting --
        if [ -n "$import_to_file" ]; then
            echo "$varname=$varvalue" >> "$import_to_file";
        else
            export $varname="$varvalue";
        fi;
    done;
}

function nvl2() {
    local function_name="nvl" variable_name value_if_not_empty value_if_empty;
    import_args "$@";
    check_required_argument $function_name variable_name;
    if [ -z "${!variable_name}" ]; then
        echo "$value_if_empty";
    else
        echo "$value_if_not_empty";
    fi;
}

function get_variable_by_name() {
    local function_name="get_variable_by_name" variable_name default_value="";
    import_args "$@";
    check_required_argument $function_name variable_name;
    if [ -z "${!variable_name}" ]; then
  	    echo "$default_value";
   	else
   		echo "${!variable_name}";
   	fi;
}

function import_args_into_file() {
    import_args import_to_file $@;
}

# Return value "target_value" if variable "source_variable_name" has the value "source_value", otherwise return default_value.
function get_value_for_var() {
	local source_variable_name source_value target_value default_value;
	import_args "$@";
	if [ "${!source_variable_name}" == "$source_value" ]; then
		echo "$target_value";
	else
	    echo "$default_value"
	fi;
}

# Set the variable "target_variable_name" to value "target_value" if variable "source_variable_name" has the value "source_value", otherwise leave it like it is.
function set_value_for_var() {
	local source_variable target_variable source_value target_value;
	import_args "$@";
	if [ "${!source_variable}" == "$source_value" ]; then
		eval $target_variable="$target_value";
	fi;
}

# export names from a name-value pair file
function export_file() {
    local l_tmp_filename="$1";
    OLDIFS=$IFS;
    log_debug "Exporting file $l_tmp_filename";
    while read _variable; do
        local parsed_variable=$(echo "$_variable" | tr -d ' ' | tr -d '\t')
        if [ -n "$parsed_variable" ]; then
            IFS='=' read -r varname varvalue <<< "$_variable"
            varname="$(cut -d "=" -f 1 <<< "$_variable")";
            varvalue="$(cut -d "=" -f 2- <<< "$_variable")";
            varvalue=$(echo "$varvalue" | sed -e 's/{CARRIAGE_RETURN}/\
/g')
            export $varname="$varvalue";
            IFS=$OLDIFS;
        fi;
    done <$l_tmp_filename
}

function wait_for_background_jobs() {
    local job_count=0;
    for job in $(jobs -p); do
        job_count=$((job_count + 1));
        #log_info "Waiting for background job $job";
    done;
    log_info "Waiting for $job_count background jobs.";
    local failed_jobs=0;
    for job in $(jobs -p); do
        wait $job || let "failed_jobs+=1"
    done;

    if [ $failed_jobs -gt 0 ]; then
        echo "Failed background jobs: $failed_jobs";
        exit 1;
    fi;
    log_info "All background jobs have finished.";
}

function files_exist() {
    local function_name="files_exist" directory filename_pattern;
    import_args "$@";
    check_required_argument $function_name directory filename_pattern;
    cd "$directory";
    for f in $(find . -maxdepth 1 -type f -name $filename_pattern); do
        echo "true";
        exit;
    done;
    echo "false";
}

function run_or_source_files() {
    local function_name="run_or_source_files" directory filename_pattern filename_extension run_function_name;
    import_args "$@";
    check_required_arguments $function_name directory
    check_required_argument $function_name filename_pattern filename_extension;
    cd "$directory";
    run_or_source_files_found="false"
    if [ -n "$filename_extension" ]; then
        log_debug "Running files with extension '$filename_extension' in '$directory'.";
        for f in $(find . -maxdepth 1 -type f -name *.$filename_extension); do
            run_or_source_files_found="true";
            run_or_source_file --filename "$f";
        done;
    else
        log_debug "Running files with name pattern '$filename_pattern' in '$directory'.";
        for f in $(find . -maxdepth 1 -type f -name $filename_pattern); do
            run_or_source_files_found="true";
            run_or_source_file --filename "$f";
        done;
    fi;
    if [ -n "$run_function_name" ]; then
        log_info "Executing function $run_function_name";
        $run_function_name "$@";
    fi;
}

function run_or_source_file() {
    local function_name="run_or_source_files" filename;
    import_args "$@";
    check_required_argument $function_name filename;
    if [ -e "$filename" ]; then
        if [[ "$filename" == *sh ]]; then
            log_debug "Sourcing $filename.";
            . $filename;
        elif [[ "$filename" == *py ]]; then
            log_debug "Executing $filename";
            ./$filename;
        else
            log_debug "Executing $filename.";
            ./$filename;
        fi;
    fi;
}

function get_file_mode() {
    local function_name="get_file_mode" filename
	import_args "$@";
	check_required_argument $function_name filename;
    if [ "$(uname)" == "Darwin" ]; then
        local file_mode="$(stat -f "%A" $filename)";
    else
        local file_mode="$(stat -c "%a" $filename)";
    fi;
    echo "$file_mode";
}

function replace_spaces() {
    local function_name=make_space_delimited_comma_delimited text replace_with;
    import_args "$@";
    check_required_arguments $function_name text replace_with;
    local result="$(echo "$text" | sed "s/[[:space:]][[:space:]]*/$replace_with/g")";
    echo "$result";
}

function files_exist_with_pattern() {
    local function_name="files_with_pattern_exist" directory filename_pattern;
    import_args "$@";
    check_required_argument $function_name directory;
    check_required_argument $function_name filename_pattern;
    local file_count="$(find $directory -maxdepth 1 -type f -name $filename_pattern 2>/dev/null | wc -l)";
    if [ $file_count -eq 0 ]; then
        echo "false";
    else
        echo "true"
    fi;
}

function unset_pipefail() {
    local result="$(set -o | grep pipefail)"
    [[ "$result" == *off ]] && last_pipefail="off" || last_pipefail="on";
    set +o pipefail;
}

function restore_pipefail() {
    if [ "$last_pipefail" == "on" ]; then
        set -o pipefail;
    elif  [ "$last_pipefail" == "off" ]; then
        set +o pipefail;
    else
        log_error "Unable to restore pipefile setting because variable 'last_pipefail' is not 'on' or 'off'.";
        exit 1;
    fi;
}

function function_exists() {
    declare -f "$1" > /dev/null && echo true;
}

function file_contains_pattern() {
    local function_name="file_contains_pattern" filename pattern;
    import_args "$@";
    check_required_argument $function_name filename;
    check_required_argument $function_name pattern;
    set +e;
    grep "$pattern" "$filename" >/dev/null 2>&1;
    if [ "$?" == "0" ]; then
        echo "true";
    else
        echo "false";
    fi;
    set -e;
}

function update_line_in_file() {
    local function_name="update_line_in_file" filename text new_text add_line_if_not_found="true" replace_line="true" starts_only="true";
    import_args "$@";
    check_required_argument $function_name filename;
    check_required_argument $function_name text;
    check_required_argument $function_name new_text;

    if [ "$starts_only" == "false" -a "$replace_line" == "false" ]; then
        log_error "Only replacing lines is supported when using --starts_only false, not updating lines";
        exit 1;
    fi;
    local escaped_new_text=$(sed 's/[\/\.]/\\&/g' <<<"$new_text");
    local escaped_text=$(sed 's/[\/\.]/\\&/g' <<<"$text");
    local line_found="false";

    if [ "$starts_only" == "true" ]; then
        pattern="^$text";
    else
        pattern="$text";
    fi;

    if [ "$(file_contains_pattern --filename "$filename" --pattern "$pattern")" == "true" ]; then
        if [ "$replace_line" == "true" ]; then
            if [ "$starts_only" == "true" ]; then
                log_debug "Replacing existing line in $filename that starts with $text.";
                sed -i "s/^$escaped_text.*/$escaped_new_text/" $filename;
            else
                log_debug "Replacing existing line in $filename that contains $text.";
                sed -i "s/.*$escaped_text.*/$escaped_new_text/" $filename;
            fi;
        else
            log_debug "Adding $new_text to the line that starts with $text in $filename.";
            sed -i "s/^$escaped_text.*/&$escaped_new_text/" $filename;
        fi;

    elif [ "$add_line_if_not_found" == "true" ]; then
        log_debug "Line starting with $text not found; adding it";
        echo "$new_text" >> $filename;
    else
        log_debug "Line starting with $text not found and argument 'add_line_if_not_found' is not 'true'. Changing nothing.";
    fi;
}

function remove_lines_in_file_that_start_with() {
    local function_name="remove_lines_in_file_that_start_with" filename start_text;
    import_args "$@";
    check_required_argument $function_name filename;
    check_required_argument $function_name start_text;

    if [ -f "$filename" ]; then
        log_debug "Removing lines from $filename that start with $start_text.";
        sed -i "/^$start_text/d" $filename 2>/dev/null;
    fi;
}

function block_in_file() {
    local function_name="block_in_file" filename block_text line_comment="#" marker_text="Infraxys block";
    import_args "$@";
    check_required_argument $function_name filename;

    local comment_line="$line_comment $marker_text";
    local comment_start_line="$comment_line - start";
    local comment_end_line="$comment_line - end";

    if [ -f "$filename" ]; then
        log_info "Removing block '$comment_start_line' from $filename.";
        # replace slashes
        local espaced_comment_start_line="${comment_start_line/\//\/}"
        local espaced_comment_end_line="${comment_end_line/\//\/}"
        sed -i "/$espaced_comment_start_line/,/$espaced_comment_end_line/d" $filename 2>/dev/null;
    fi;
    if [ -z "$block_text" ]; then
        log_debug "Block text is empty so not creating it.";
    else
        log_debug "Adding block '$comment_start_line' to $filename.";
        echo "$comment_start_line" >> $filename;
        echo "$block_text" >> $filename;
        echo "$comment_end_line" >> $filename;
    fi;
}

function trim() {
    local result=$(echo "$1" | sed -e 's/^ *//' -e 's/ *$//')
    echo "$result";
}

