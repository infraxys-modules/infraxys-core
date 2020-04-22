function show_message_dialog() {
    local function_name="show_message_dialog" height=200 width=400 is_html=false message style_name title;
    import_args "$@";
    check_required_arguments $function_name message;
    show_dialog --height "$height" --width "$width" --is_html "$is_html" \
            --message "$message" --style_name "$style_name" --title "$title";

}

function show_dialog() {
    local function_name="show_dialog" default height=300 width=450 is_html=false message input_label style_name
        title="Message" target_variable_name="";
    import_args "$@";
    echo "<FEEDBACK>";
    echo "ui interaction";
    echo "type=BUTTON_DIALOG";
    echo "width=$width";
    echo "height=$height";
    echo "title=$title";
    if [ -n "$input_label" ]; then
        echo "string_input_label=$input_label";
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
                show_error --message "Button caption cannot contain a space and a double quote";
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
    if [ -n "$target_variable_name" ]; then
      eval "$target_variable_name='$LAST_RESULTS'";
    else
      LAST_DIALOG_RESULT="$LAST_RESULTS";
    fi;
}

function get_user_input_v1() {
    BUTTONS=("Ok" "Cancel")
    BUTTON_LOCATIONS=("LEFT" "RIGHT")
    show_dialog "$@";
}

function get_user_input() {
  local target_variable_name;
  import_args "$@";
  check_required_arguments "get_user_input" target_variable_name;
  BUTTONS=("Ok" "Cancel")
  BUTTON_LOCATIONS=("LEFT" "RIGHT")
  show_dialog --target_variable_name "$target_variable_name" "$@";
}

function ask_yes_no() {
    BUTTONS=("Yes" "No")
    BUTTON_LOCATIONS=("LEFT" "RIGHT")
    show_dialog "$@"
}

function ask_yes_no_cancel() {
    BUTTONS=("Yes" "No" "Cancel")
    BUTTON_LOCATIONS=("LEFT" "MIDDLE" "RIGHT")
    show_dialog "$@"
}

function ask_ok_cancel() {
    BUTTONS=("OK" "Cancel")
    BUTTON_LOCATIONS=("LEFT" "RIGHT")
    show_dialog "$@"
}

function show_info() {
    show_dialog --style_name info "$@";
}

function show_warning() {
    show_dialog --style_name warning "$@";
}

function show_warn() {
    show_dialog --style_name warning "$@";
}

function show_error() {
    show_dialog --style_name error "$@";
}
