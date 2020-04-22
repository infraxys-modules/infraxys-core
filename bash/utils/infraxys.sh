#
# @author jmanders
#

function create_infraxys_container() {
    local function_name="create_infraxys_container" environment_id container_type="SERVER" name domain description ssh_host private_ip;
    import_args "$@";
    check_required_argument $function_name environment_id;
    check_required_argument $function_name container_type;
    check_required_argument $function_name name;
    check_required_argument $function_name description;
    log_info "Creating container $name";
    echo "<FEEDBACK>
create container
set container_type=$container_type
set name=$name
set environment_id=$environment_id
set domain=$domain
set description=$description
set connect_name=$ssh_host
set private_ip=$private_ip
</FEEDBACK>";
    wait_for_feedback;
    echo "Container id: $LAST_RESULTS";
}

function create_instance() {
    local function_name="create_instance" parent_instance_id guid;
    import_args "$@";
    check_required_arguments $function_name parent_instance_id guid;
    log_info "Creating instance of $guid";
    echo "<FEEDBACK>
create instance
guid=$guid
parentInstanceId=$parent_instance_id
</FEEDBACK>";
    wait_for_feedback;
    echo "Instance id: $LAST_RESULTS";
}

function show_create_instance() {
    local function_name="show_create_instance" parent_instance_id guid
    import_args "$@";
    check_required_arguments $function_name parent_instance_id guid;

    echo "<FEEDBACK>"
    if [ -n "$parent_instance_id" ]; then
        echo "set instanceid=$parent_instance_id";
    fi;
    echo "ui interaction
type=CREATE INSTANCE
guid=$guid
</FEEDBACK>"
    wait_for_feedback;
    new_instance_id="$LAST_RESULTS";
}

function wait_for_feedback() {
    local function_name="wait_for_feedback" error_text="FAILED" success_text="SUCCESS" exit_on_error="true" any_response="false";
    import_args "$@";
    LAST_RESULTS="";
    LAST_STATUS="";
    while read -r text_from_server; do
        if [ "$text_from_server" == "$success_text" -o "$any_response" == "true" ]; then
            LAST_STATUS="$success_text";
            break;
        elif [ "$text_from_server" == "$error_text" ]; then
            echo "";
            LAST_STATUS="$error_text";
            if [ "$exit_on_error" == "true" ]; then
                exit 1;
            else
                return 1;
            fi;
        else
            if [ -z "$LAST_RESULTS" ]; then
                LAST_RESULTS="$text_from_server";
            else
                LAST_RESULTS="$LAST_RESULTS
$text_from_server";
            fi
        fi;
    done
    echo "";
}

function show_selection_list() {
    local function_name="show_selection_list";
        local OPTIND;
    local string_lines="";
    local list_type="";
    local title="Make your selection"
    local width="700";
    local height="450";
    local is_name_value_list="false";
    local min_selected_items="0";
    local max_selected_items="0";
    local column_1_visible="true";
    local column_1_title="";
    local column_2_title="":
    while getopts "c:d:h:i:l:m:n:s:t:v:w:" opt; do
                case $opt in
                    c)
                                column_1_title="$OPTARG";
                                ;;
                        d)
                                column_2_title="$OPTARG";
                                ;;
                        h)
                                height="$OPTARG";
                                ;;
                        i)
                                is_name_value_list="$OPTARG";
                                ;;
                        l)
                            list_type="$OPTARG";
                                ;;
                        m)
                                min_selected_items="$OPTARG";
                                ;;
                        n)
                                max_selected_items="$OPTARG";
                                ;;
                        s)
                                string_lines="$OPTARG";
                                ;;
                        t)
                                title="$OPTARG";
                                ;;
                        v)
                            column_1_visible="$OPTARG";
                            ;;
                        w)
                                width="$OPTARG";
                                ;;
                ?)
                                echo "Copy installation files to the target server if transfer_files_instead_of_mount = 1 and if we're on the target server
                                Arguments:  -c column_1_title: title of the first column, if visible.
                                                        -d column_1_title: title of the second column
                                                        -h height, default 450: the height of the dialog
                                                        -i is_name_value_list, default 'false': specify true list string_array contains name-value pairs.
                                                        -l list_type: string_array is not used if this argument is passed. valid options are 'ENVIRONMENTS' and 'PROJECTS'.
                                                        -m min_selected_items, default '0': the minimum number of items the user should select.
                                                        -n max_selected_items, default '0': the maximum number of items the user should select.
                                                        -s string_lines, default '': items to display, separated by carriage return
                                                        -t title, default 'Make your selection': the title of the dialog.
                                                        -v column_1_visible, default 'true': specify false if the first column shoudn't be displayed.
                                                        -w width, default 450, the width of the dialog.echo ";
                                ;;
                        \?)
                                echo "Invalid option for $function_name: -$OPTARG" >&2
                                exit 1
                                ;;
                esac
    done
    echo "<FEEDBACK>";
    echo "ui interaction";
    echo "type=selection_list";
    echo "is_name_value_list=$is_name_value_list";
    echo "title=$title";
    echo "width=$width";
    echo "height=$height";
    echo "min_selected_items_count=$min_selected_items";
    echo "max_selected_items_count=$max_selected_items";
    echo "column_1_visible=$column_1_visible";
    echo "column_1_title=$column_1_title";
    echo "column_2_title=$column_2_title";
    echo "";
    if [ -n "$string_lines" ]; then
        echo "$string_lines";
    elif [ -n "$list_type" ]; then
        echo "list_type=$list_type";
    fi;
    echo "</FEEDBACK>";
    wait_for_feedback;
    LAST_DIALOG_RESULT="$LAST_RESULTS";
}

function update_instance_attribute() {
    local function_name="update_instance_attribute" instance_id attribute_name attribute_value compile_container="false" compile_instance="false" compile_environment="false";
    import_args "$@";
    check_required_arguments $function_name instance_id attribute_name attribute_value

    local escaped_attribute_value="$(echo "$attribute_value" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed 's/\n/\\n/g')";
    echo "<FEEDBACK>";
    cat << EOF
{
    "requestType": "UPDATE INSTANCE",
    "dbId": "$instance_id",
    "compileInstance": $compile_instance,
    "compileContainer": $compile_container,
    "compileEnvironment": $compile_environment,
    "fields": {
        "$attribute_name": "$escaped_attribute_value"
    }
}
EOF
    echo "</FEEDBACK>";
    wait_for_feedback --any_response "true";
    LAST_DIALOG_RESULT="$LAST_RESULTS";
}

function has_grant() {
    local function_name="has_grant" grant_name grant_guid;
    import_args "$@";
    check_required_arguments $function_name grant_name grant_guid
    local has_rights="$(/tmp/infraxys/system/has_grant "$grant_guid")";
    echo "$has_rights";
}
readonly -f has_grant;

function check_grant() {
    local function_name="check_grant" grant_name grant_guid;
    import_args "$@";
    check_required_arguments $function_name grant_name grant_guid
    local has_rights="$(/tmp/infraxys/system/has_grant "$grant_guid")";
    if [ "$has_rights" != "true" ]; then
        log_error "User lacks required grant '$grant_name' (guid '$grant_guid').";
        exit 1;
    fi;
}
readonly -f check_grant;
