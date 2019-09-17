#!/usr/bin/env/bash

set -eo pipefail;

function process_ssh_private_key_variables() {
    local directory="$INFRAXYS_ROOT/variables/SSH-PRIVATE-KEY";
    log_info "Processing variables of type 'SSH-PRIVATE-KEY' under $directory.";
    echo "-- $INFRAXYS_ROOT:"
    ls -ltr "$INFRAXYS_ROOT";

    echo "-- $INFRAXYS_ROOT/variables:"
    ls -ltr "$INFRAXYS_ROOT/variables";

    echo "-- $INFRAXYS_ROOT/variables/SSH-PRIVATE-KEY:"
    ls -ltr "$INFRAXYS_ROOT/variables/SSH-PRIVATE-KEY";

    if [ -d "$directory" ]; then
        cd "$directory" > /dev/null;
        echo "In directory"
        ls -ltr;
        echo
        for f in *; do
            log_info "Adding $f to ~/.ssh";
            cp "$f" ~/.ssh/;
        done;
        cd - > /dev/null;
    fi;
}

process_ssh_private_key_variables;

