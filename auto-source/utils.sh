
function process_netrc_variables() {
    local directory="$INFRAXYS_ROOT/variables/NETRC";

    if [ -d "$directory" ]; then
        cd "$directory" > /dev/null;
        for f in *; do
            log_info "Copying contents of $f to ~/.netrc";
            cat "$f" > ~/.netrc;
        done;
        chmod 400 ~/.netrc
        cd - > /dev/null;
    fi;
}

process_netrc_variables;