#
# Core functions
#
# @author jmanders
#

function is_url() {
    local function_name="is_url" uri;
    import_args "$@";
    check_required_argument $function_name uri;
    if [[ "$uri" == http* ]]; then
        echo "true";
    else
        echo "false";
    fi;
}

