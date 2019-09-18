#!/usr/bin/env/bash

set -eo pipefail;

function process_ssh_private_key_variables() {
    local directory="$INFRAXYS_ROOT/variables/SSH-PRIVATE-KEY";
    log_info "Processing variables of type 'SSH-PRIVATE-KEY' under $directory.";

    mkdir -p ~/.ssh/keys;
    mkdir -p ~/.ssh/generated.d;

    echo 'Include ~/.ssh/generated.d/*' >> ~/.ssh/config;

    chmod -R 700 ~/.ssh;

    if [ -d "$directory" ]; then

        cd "$directory" > /dev/null;
        for f in *; do
            log_info "Copying key file $f to ~/.ssh/keys";
            cp "$f" ~/.ssh/keys;
        done;
        cd - > /dev/null;
    fi;
}

function generate_environment_ssh_config() {
    local force="false";
    import_args "$@";

    local last_dir="$(pwd)";
    cd "$ENVIRONMENT_DIR";

    cat > ~/.ssh/config << EOF
Host *
    ServerAliveInterval 60
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null
    LogLevel=ERROR
    PreferredAuthentications=publickey

EOF
    echo ----
    pwd
    echo ----
    for f in $(find . -type f -name generate_ssh_config); do
        log_info "Adding ssh configuration from $f.";
        . $f >> ~/.ssh/config;
    done;

    cd "$last_dir";
    log_info "Ssh configuration file contents: ";
    cat ~/.ssh/config;
}

echo ----
pwd
echo ----
process_ssh_private_key_variables;
generate_environment_ssh_config;
