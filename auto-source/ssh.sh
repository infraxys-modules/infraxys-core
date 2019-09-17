#!/usr/bin/env/bash

set -eo pipefail;

function process_ssh_private_key_variables() {
    local directory="$INFRAXYS_ROOT/variables/SSH-PRIVATE-KEY";
    log_info "Processing variables of type 'SSH-PRIVATE-KEY' under $directory.";

    if [ -d "$directory" ]; then
        mkdir -p ~/.ssh;
        chmod 700 ~/.ssh;
        cd "$directory" > /dev/null;
        for f in *; do
            log_info "Adding $f to ~/.ssh";
            cp "$f" ~/.ssh/;
        done;
        cd - > /dev/null;
    fi;
}

process_ssh_private_key_variables;

