ssh_config_file="/tmp/ssh_config";

function generate_environment_ssh_config() {
    local force="false";
    import_args "$@";

    [[ "$force" == "false" && -f "$ssh_config_file" ]] && return; # file already generated

    local last_dir="$(pwd)";
    cd "$ENVIRONMENT_DIR";

    cat > "$ssh_config_file" << EOF
Host *
    ServerAliveInterval 60
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null
    LogLevel=ERROR
    PreferredAuthentications=publickey

EOF
    for f in $(find . -type f -name generate_ssh_config); do
        log_info "Adding ssh configuration from $f (make sure that you include '-F \$ssh_config_file' when referencing bastion hosts)";
        . $f >> "$ssh_config_file";
    done;

    cd "$last_dir";
    log_info "Ssh configuration file $ssh_config_file contents: ";
    cat "$ssh_config_file";
}
