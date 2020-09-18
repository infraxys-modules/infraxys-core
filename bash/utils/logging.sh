#
# Bash logging functions
#
# @author jmanders
#

LOGGING_EXPORTED_FUNCTION_NAMES="confirm_or_abort log_trace log_debug log_info log_info_no_cr log_warn log_error log_fatal log_text show_error";

function confirm_or_abort() {
    local function_name="ask_confirmation" message expected_answer="y";
    import_args "$@";
    check_required_argument $function_name message;
    if [ "$INTERACTIVE" == "true" ]; then
        echo "--------------------";
        local datepart=$(date +"%d-%m-%Y %H:%M:%S,%3N");
        read -p "[$datepart] [`hostname`] [QUESTION] [`whoami`] $message" answer;
        if [ "$answer" != "$expected_answer" ]; then
            log_warn "You didn't answer '$expected_answer'. Aborting.";
            exit 1;
        fi;
    else
        log_info "Auto confirming because we're in non-interactive mode. Message: $message";
    fi;
}

function log_text() {
    local log_level="$1";
    local log_message="$2";
    local echo_argument="";
    [[ $# -gt 2 ]] && echo_argument="$3";
    local datepart=$(date +"%d-%m-%Y %H:%M:%S,%4N");
    echo $echo_argument "[$datepart] [`hostname`] [$log_level] [`whoami`] $log_message";
}

function log_trace() {
    if [ "$LOG_TRACE_MESSAGES" == "true" -o "$LOG_TRACE" == "true" ]; then
	    log_text "TRACE" "$1";
    fi
}

function log_debug() {
	log_text "DEBUG" "$1";
}

function log_info() {
	log_text "INFO " "$1";
}

function log_warn() {
	log_text "WARN " "$1";
}

function log_error() {
	local message="$(log_text "ERROR" "$1")";
    echo "$message" >&2;
}

function log_fatal() {
    local message="$(log_text "FATAL" "$1")";
    echo "$message" >&2;
    exit 1;
}

log_info_to_std_err() {
    local message="$(log_info "$@")";
    echo "$message" >&2;
}

function log_trace_no_cr() {
	log_text "TRACE" "$1" "-n";
}

function log_debug_no_cr() {
	log_text "DEBUG" "$1" "-n";
}

function log_info_no_cr() {
	log_text "INFO " "$1" "-n";
}

function log_warn_no_cr() {
	log_text "WARN" "$1" "-n";
}

function log_error_no_cr() {
	log_text "ERROR" "$1" "-n";
}
