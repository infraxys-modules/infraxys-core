function update_status() {
    local function_name="update_status" message;
    import_args "$@";
    check_required_arguments $function_name message;
    local request="$(cat << EOF
    <FEEDBACK>
{
    "requestType": "SYSTEM",
    "subType": "STATUS",
    "message": "$message"
}
</FEEDBACK>
EOF
)";
    echo "$request";
    wait_for_feedback;
}

function audit_start_action() {
    local escaped_label="$(echo "$instance_label" | sed 's/"/\\"/g')";
    local json="$(cat << EOF
        "project_name": "$project_name",
        "environment_name": "$environment_name",
        "container_name": "$container_name",
        "instance_label": "$escaped_label"
EOF
)";
    audit_action --action "START ACTION" --json "$json";
}

function audit_action() {
    local function_name=audit_action action details json
    import_args "$@";
    check_required_arguments $function_name action;
    local detail_part="";
    if [ -n "$details" ]; then
        detail_part="$(cat << EOF
,
        "details": "$details"
EOF
)";
    fi;
    local detail_json_part="";
    if [ -n "$json" ]; then
        detail_json_part="$(cat << EOF
,
$json
EOF
)";
    fi;
    json="$(cat << EOF
    {
        "audit_type": "action",
        "ticket": "$GLOBAL_TICKET",
        "action": "$action"$detail_part$detail_json_part

    }
EOF
)";
    log_audit --json "$json";
}

function log_audit() {
    local function_name="log_audit" json;
    import_args "$@";
    check_required_arguments $function_name json;
    local request="$(cat << EOF
    <FEEDBACK>
{
    "requestType": "SYSTEM",
    "subType": "AUDIT",
    "json": $json
}
</FEEDBACK>
EOF
)";
    echo "$request";
    wait_for_feedback;
}

function show_json_form() {
    local function_name="show_json_form" json json_file exit_code_on_cancel="" callback_function;
    import_args "$@";
    check_required_argument $function_name json json_file;
    if [ -z "$json" ]; then
        json="$(cat "$json_file")";
    fi;
    local request="$(cat << EOF
    <FEEDBACK>
{
    "requestType": "UI",
    "subType": "FORM",
    "json": $json
}
</FEEDBACK>
EOF
)";
    echo "$request";

    while read text_from_server; do
        local add_to_last_results="false";
        if [ "$text_from_server" == "SUCCESS" ]; then
            break;
        elif [ "$text_from_server" == "FAILED" ]; then
            echo "";
            LAST_STATUS="$error_text";
            break;
        elif  [[ "$text_from_server" == {* && "$text_from_server" == *} ]]; then
            export last_json_event_type="$(echo "$text_from_server" | jq -r '.eventType')";
            export last_json_event_details="$(echo "$text_from_server" | jq -r '.eventDetails')";
            export last_json_object_id="$(echo "$text_from_server" | jq -r '.objectId')";

            IFS=$'\n' && for result in $(echo "$text_from_server" | jq -cr 'select(.results != null) | .results[]'); do
                local result_id="$(echo "$result" | jq -r '.id')";
                local result_variable="jsonResult_$result_id";
                log_info "Setting environment variable $result_variable";
                export "$result_variable"=$result;
            done;
            if [ -n "$callback_function" ]; then
                $callback_function --json_from_server "$text_from_server";
                if [ "$STOP_WAITING" == "true" ]; then
                    break;
                fi;
                LAST_RESULTS="";
            else
                add_to_last_results="true";
            fi;
        else
            add_to_last_results="true";
        fi;
        if [ "$add_to_last_results" == "true" ]; then
            if [ -z "$LAST_RESULTS" ]; then
                LAST_RESULTS="$text_from_server";
            else
                LAST_RESULTS="$LAST_RESULTS
$text_from_server";
            fi
        fi;
    done
}

function get_json_result() {
    local function_name=get_json_result json object_id property;
    import_args "$@";
    check_required_arguments $function_name object_id;

    [[ -z "$json" ]] && json="$LAST_RESULTS";
    if [ -z "$json" ]; then
        log_error "Variable LAST_RESULTS or json should be set when calling $function_name.";
        exit 1;
    fi;

    local result="$(echo "$json" | jq -r '.results[] | select(.id == "'$object_id'")')";
    if [ -n "$property" ]; then
        result="$(echo "$result" | jq -r '.selectedItemList[] | .'$property)";
    fi;
    echo "$result";
}

function get_first_json_result() {
    local function_name=get_first_json_result json object_id property;
    import_args "$@";
    check_required_arguments $function_name object_id;

    [[ -z "$json" ]] && json="$LAST_RESULTS";
    if [ -z "$json" ]; then
        log_error "Variable LAST_RESULTS or json should be set when calling $function_name.";
        exit 1;
    fi;
    local result="$(get_json_result --json "$json" --object_id "$object_id")";

    if [ -n "$property" ]; then
        result="$(echo "$result" | jq -r '.selectedItemList[0] .'$property)";
    else
        result="$(echo "$result" | jq -r '.selectedItemList[0]')";
    fi;
    echo "$result";
}

function answer_form_interaction() {
    local json;
    import_args "$@";
    echo "<FEEDBACK>";
    echo "$json";
    echo "</FEEDBACK>";
}

function create_json_instance() {
    local function_name="create_json_instance" fields_json packet_guid parent_instance_id compile_container="false" execute_filename;
    import_args "$@";
    check_required_arguments $function_name fields_json packet_guid parent_instance_id compile_container;
    local request="$(cat << EOF
<FEEDBACK>
{
"requestType": "CREATE INSTANCE",
"packetGuid": "$packet_guid",
"parentInstanceId": "$parent_instance_id",
"compileContainer": $compile_container,
"fields": $fields_json
}
</FEEDBACK>
EOF
)";
    echo "$request";
    wait_for_feedback;
    if [ "$LAST_STATUS" == "SUCCESS" -a -n "$execute_filename" ]; then
        local instance_id="$(echo "$LAST_RESULTS" | jq -r '.dbId')";
        execute_json_action --instance_id "$instance_id" --filename "$execute_filename";
    fi;
}

function execute_json_action() {
    local function_name="execute_json_action" instance_id filename;
    import_args "$@";
    check_required_arguments $function_name instance_id filename;
    local request="$(cat << EOF
<FEEDBACK>
{
"requestType": "EXECUTE ACTION",
"instanceId": "$instance_id",
"filename": "$filename"
}
</FEEDBACK>
EOF
)";
    echo "$request";
    wait_for_feedback;
}

function add_and_wrap_data_part() {
    local function_name=add_and_wrap_data_part full_json data_part_id data_json;
    import_args "$@";
    check_required_arguments $function_name full_json data_part_id data_json;

    local wrapped_data_json="$(cat <<EOF
{
    "items":
$data_json
}
EOF
)";

    add_data_part --full_json "$full_json" --data_part_id "$data_part_id" --data_json "$wrapped_data_json";
}

# insert this data part to an existing json-array
# format should be (use add_and_wrap_data_part for this):
#   {
#       "items": [
#       {
#           "property1": "val1",
#           "property2": "val2"
#       }
#     ]
#   }
function add_data_part() {
    local function_name=add_data_part full_json data_part_id data_json;
    import_args "$@";
    check_required_arguments $function_name full_json data_part_id data_json;
    local data_part="$(cat <<EOF
            {
                "id": "$data_part_id",
                "data":
                    $data_json
            }
EOF
    )";
    echo "$full_json" | jq '.dataParts += ['"$data_part"']';
}

function add_canvas_columns() {
    local function_name=add_canvas_columns json columns_json;
    import_args "$@";
    check_required_arguments $function_name json columns_json;
    echo "$json" | jq '.form.canvas.columns += ['"$columns_json"']';
}

function export_json_attributes() {
    local function_name=export_json_attributes json;
    import_args "$@";
    check_required_arguments $function_name json;

    for key in $(echo "$json" | jq -r 'to_entries[] | .key'); do
        local value="$(echo "$json" | jq -r '.'$key'')";
        #log_debug "Exporting property '$key' $value.";
        export $key="$value";
    done;
}