#!/usr/bin/env/bash

set -eo pipefail;

export PYTHONPATH="$(pwd)/python:$PYTHONPATH";

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
            if grep -qi "OPENSSH" "$f"; then
              log_fatal "This is an OPENSSH private key, which is not supported. You can convert it to RSA-format using 'ssh-keygen -p -N "" -m pem -f /path/to/key'.
              Be careful, this command will overwrite the origin file.";
            fi;
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
            echo "" >> ~/.ssh/config; # ensure new line
            log_info "Adding contents of file $f to ~/.ssh/config";
            cat "$f" >> ~/.ssh/config;
        done;
        cd - > /dev/null;
    fi;
}

# call this function only when explicitly needed
# Terraform, for example, needs this to retrieve modules over https that are in GitHub Enterprise
#    and/or private GitHub repositories
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

function init_git() {
  [ -n "$github_user_name" ] && log_info "Setting github_user_name to $github_user_name" && git config --global user.name "$github_user_name";
  [ -n "$github_user_email" ] && log_info "Setting github_user_email to $github_user_email" && git config --global user.email "$github_user_email";
  git config --global push.default simple

  if [ -n "$git_token_variable" ]; then
    log_info "Setting GitHub token to the value of variable '$git_token_variable'.";
    export github_token="$(cat /tmp/infraxys/variables/GITHUB-TOKEN/$git_token_variable)";
  fi;
}

init_ssh;
process_ssh_private_key_variables;
generate_environment_ssh_config;
process_ssh_config_variables;
init_git;

