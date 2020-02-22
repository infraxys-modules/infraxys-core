#!/usr/bin/env/bash

set -eo pipefail;

# This code must run after cloud provider configuration, like connecting to AWS (which is in init.005.sh)

function init_ssh() {
    mkdir -p ~/.ssh/keys;
    mkdir -p ~/.ssh/generated.d;

    echo 'Include ~/.ssh/generated.d/*' >> ~/.ssh/config;
}
readonly init_ssh;

function process_ssh_private_key_variables() {
    local directory="$INFRAXYS_ROOT/variables/SSH-PRIVATE-KEY";
    log_info "Processing variables of type 'SSH-PRIVATE-KEY' under $directory.";

    chmod -R 700 ~/.ssh;

    if [ -d "$directory" ]; then
        cd "$directory" > /dev/null;
        for f in *; do
            log_info "Copying key file $f to ~/.ssh/keys";
            cp "$f" ~/.ssh/keys;
        done;
        chmod 400 ~/.ssh/keys/*;
        cd - > /dev/null;
    fi;
}

function generate_environment_ssh_config() {
    local force="false";
    import_args "$@";

    local last_dir="$(pwd)";
    cd "$ENVIRONMENT_DIR";

    cat >> ~/.ssh/config << EOF
Host *
    ServerAliveInterval 60
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null
    LogLevel=ERROR
    PreferredAuthentications=publickey

EOF
    local temp_ssh_config="";
    log_info "Running all packet files in this environment with name starting with 'configure_ssh'. These files should write ssh-config to '~/.ssh/generated.d/<vpc name>', for example.";
    for f in $(find "$ENVIRONMENT_DIR" -type f -name configure_ssh*); do
        log_info "Executing $f.";
        $f;
        echo "" >> ~/.ssh/config; # ensure the next output starts on a new line
    done;
    cd "$last_dir";
}

function process_ssh_config_variables() {
    local directory="$INFRAXYS_ROOT/variables/SSH-CONFIG";
    log_info "Processing variables of type 'SSH-CONFIG' under $directory.";

    echo '' >> ~/.ssh/config;

    if [ -d "$directory" ]; then

        cd "$directory" > /dev/null;
        for f in *; do
            log_info "Adding contents of file $f to ~/.ssh/config";
            cat "$f" >> ~/.ssh/config;
        done;
        cd - > /dev/null;
    fi;
}

init_ssh;
process_ssh_private_key_variables;
generate_environment_ssh_config;
process_ssh_config_variables;

