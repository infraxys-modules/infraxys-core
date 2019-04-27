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

function execute_infraxys_action() {
	local function_name="execute_infraxys_action" instance_id filename;
	import_args "$@";
	check_required_arguments $function_name instance_id filename;

	echo "<FEEDBACK>";
	echo "ui interaction";
	echo "type=EXECUTE_ACTION";
	echo "instance_id=$instance_id";
	echo "filename=$filename";
	echo "</FEEDBACK>";
	wait_for_feedback;
	LAST_DIALOG_RESULT="$FEEDBACK_RESULTS";
}

function get_user_input() {
    BUTTONS=("Ok" "Cancel")
    BUTTON_LOCATIONS=("LEFT" "RIGHT")
    show_dialog "$@";
}

function show_dialog() {
        local function_name="show_dialog";
        local OPTIND;
        local default="";
        local default_value="";
        local height="300";
        local is_html="false";
        local message="";
        local string_input_label="";
        local style_name="";
        local title="";
        local translate="false";
        local width="450";

    while getopts "b:c:d:h:i:l:m:p:s:t:v:w:" opt; do
                case $opt in
                        c) # "c" from convert since "t" is already used
                                translate="$OPTARG";
                                ;;
                        d)
                                default="$OPTARG";
                                ;;
                        h)
                                height="$OPTARG";
                                ;;
                        i)
                                is_html="$OPTARG";
                                ;;
                        l)
                                string_input_label="$OPTARG";
                                ;;
                        m)
                                message="$OPTARG";
                                ;;
                        s)
                                style_name="$OPTARG";
                                ;;
                        t)
                                title="$OPTARG";
                                ;;
                        v)
                                default_value="$OPTARG";
                                ;;
                        w)
                            width="$OPTARG";
                                ;;
                        ?)
                                echo "Copy installation files to the target server if transfer_files_instead_of_mount = 1 and if we're on the target server
                                Arguments:  ENVIRONMENT VARIABLE 'BUTTONS', default (OK): specify the buttons to show. Examples (OK CANCEL). Surround by double quotes if you want to use spaces
                                                        -c translate (convert), default 'false': specify 'true' to get a translation from the database.
                                                        -d default, default 1: the text that is returned from this function if this is not an interactive sension
                                                        -h height, default 300: the height of the dialog
                                                        -i is_html, default 'false': specify true to avoid an extra paragraph (the message is surrounded by <p> and </p> if is_html is false)
                                                        -l string_input_label, default '': the label to show if this dialog should let the user input a string
                                                        -m message, default '': the message to display
                                                    ENVIRONMENT VARIABLE 'BUTTON_LOCATIONS', default 'MIDDLE': specify an array for locations of the buttons from the -b argument (LEFT, MIDDLE or RIGHT)
                                                        -s style_name, default '': the css style name to add to the dialog
                                                        -t title, default '': the title of the dialog
                                                        -w width, default 450, the width of the dialog.";
                                ;;
                        \?)
                                echo "Invalid option for $function_name: -$OPTARG" >&2
                                exit 1
                                ;;
                esac
    done
        echo "<FEEDBACK>";
        echo "ui interaction";
        echo "type=BUTTON_DIALOG";
        echo "width=$width";
        echo "height=$height";
        echo "translate=$translate";
        echo "title=$title";
        if [ -n "$default_value" ]; then
                echo "default_value=$default_value";
        fi;
        if [ -n "$string_input_label" ]; then
                echo "string_input_label=$string_input_label";
        fi;

        if [ -n "$default" ]; then
                echo "default_button=$default";
        fi;

        if [ -n "$style_name" ]; then
                echo "style_name=$style_name";
        fi;

        if [ -n "$is_html" ]; then
                message="<p>$message</p>"
                is_html="true"
        fi;

        echo "is_html=$is_html";
        button_location_count=0;
        if [ -n "$BUTTON_LOCATIONS" ]; then
                button_location_count=${#BUTTON_LOCATIONS[*]}
        fi;
        for button_number in ${!BUTTONS[*]}; do
            button_caption="${BUTTONS[$button_number]}";
                if [[ "$button_caption" == *\ * ]]; then
                        if [[ "$button_caption" == *\"* ]]; then
                                show_error "Button caption cannot contain a space and a double quote";
                                exit 1;
                        fi;
                fi;
                location="MIDDLE";

                if [ "$button_location_count" -gt "$button_number" ]; then
                        location="${BUTTON_LOCATIONS[$button_number]}";
                fi;
                echo 'button caption="'$button_caption'" location='$location;
        done;

        echo "$message";
        echo "</FEEDBACK>";
	wait_for_feedback;
    	LAST_DIALOG_RESULT="$LAST_RESULTS";
}

function ask_yes_no() {
    BUTTONS=("Yes" "No")
    BUTTON_LOCATIONS=("LEFT" "RIGHT")
    show_dialog "$@"
}

function ask_yes_no_cancel() {
    BUTTONS=("Yes" "No", "Cancel")
    BUTTON_LOCATIONS=("LEFT" "MIDDLE" "RIGHT")
    show_dialog "$@"
}

function ask_ok_cancel() {
    BUTTONS=("OK" "Cancel")
    BUTTON_LOCATIONS=("LEFT" "RIGHT")
    show_dialog "$@"
}

function show_info() {
    show_dialog -s info "$@";
}

function show_warning() {
    show_dialog -s warning "$@";
}

function show_warn() {
    show_dialog -s warning "$@";
}

function show_error() {
    show_dialog -s error "$@";
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
    local function_name="has_grant" grant_name;
    import_args "$@";
    check_required_arguments $function_name grant_name
    local has_rights="$(/tmp/infraxys/system/has_grant "$grant_name")";
    echo "$has_rights";
}
readonly -f has_grant;

function check_grant() {
    local function_name="check_grant" grant_name;
    import_args "$@";
    check_required_arguments $function_name grant_name
    local has_rights="$(/tmp/infraxys/system/has_grant "$grant_name")";
    if [ "$has_rights" != "true" ]; then
        log_error "User lacks required grant '$grant_name'.";
        exit 1;
    fi;
}
readonly -f check_grant;
