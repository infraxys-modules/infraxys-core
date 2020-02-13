#!/usr/bin/env/bash

set -eo pipefail;

# This code must run only after all modules are enabled because "generate_ssh_config"-scripts may depend on other modules like aws_core to retrieve dns names or IPs

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
    log_info "Adding all files in the environment with name starting with 'generate_ssh_config'.";
    for f in $(find "$ENVIRONMENT_DIR" -type f -name generate_ssh_config*); do
        log_info "Adding ssh configuration from $f.";
        . $f --target_variable_name "temp_ssh_config";
        echo "$temp_ssh_config" >> ~/.ssh/config;
        temp_ssh_config="";
        echo "" >> ~/.ssh/config;
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


process_ssh_private_key_variables;
generate_environment_ssh_config;
process_ssh_config_variables;

