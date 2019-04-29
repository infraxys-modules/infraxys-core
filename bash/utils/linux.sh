#
# linux.sh
#
# Linux related functions
# @author jmanders



function prepare_os() {
    local function_name="prepare_os" initial_ssh_user remove_initial_user="true";
    import_args "$@";
    if [ -n "$initial_ssh_user" ]; then
        enable_root_login --ssh_user $initial_ssh_user --remove_other_user "$remove_initial_user";
    fi;

    if [ "$os_flavor" == "red hat" ]; then
        execute_function_remote --function_name clean_yum;
    fi;
    execute_function_remote --function_name configure_ssh;
    if [ "$use_nat_server" == "true" ]; then
        execute_function_remote --function_name configure_route_via_nat --nat_server_private_ip "$nat_server_private_ip";
    fi;
}



function get_ip_address() {
    if [ "$(uname)" == "Darwin" ]; then # OSX
        #ip_address="$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -1)";
        ip_address="$(ipconfig getifaddr en0)";
    else
        ip_address="$(ip addr show | grep -w inet | grep -v 127.0.0.1|awk '{ print $2}'| cut -d "/" -f 1 | head -1)";
    fi;
    echo "$ip_address";
}

function configure_auto_start() {
    local function_name="configure_auto_start" filename target_filename=""
	import_args "$@";
	check_required_argument $function_name filename;

    if [ -z "$target_filename" ]; then
        target_filename="$filename";
    fi;
    log_info "Configuring /etc/init.d/$filename.";
    copy_file --source_filename "$filename" --target_directory "/etc/init.d" --target_filename "$target_filename" --mode 755;
    chkconfig --add $target_filename;
}

function run_as() {
    local username="$1";
    local command_line="$2";
    if [ "$(id -un)" == "$username" ]; then
        $command_line;
    else
        su $username -p -c "$command_line";
    fi;
}

function set_hostname_and_configure_etc_hosts() {
    local function_name=set_hostname new_hostname;
    import_args "$@";
    check_required_arguments $function_name new_hostname;
    log_info "Setting active hostname to '$new_hostname'.";
    hostname "$new_hostname";
    if [ "$os_flavor" == "red hat" ]; then
        log_info "Updating /etc/sysconfig/network and restarting the network service.";
        update_line_in_file --filename "/etc/sysconfig/network" --text "HOSTNAME=" --new_text "HOSTNAME=$new_hostname";
        service network restart;
    fi;
    if [ -f "/etc/hostname" ]; then
        log_info "Setting /etc/hostname to $new_hostname and restarting the hostname service.";
        echo "$new_hostname" > /etc/hostname;
        service hostname restart;
    fi;
    local ip_address="$(get_ip_address)";
    local actual_hostname="$(hostname)";
    local short_hostname="$(hostname -s)";
    #local actual_aliases="$(hostname -a)"; # fails if executed before reboot
    block_in_file --marker_text="Infraxys local IP start ###" --filename "/etc/hosts" --block_text "$ip_address $container_name $actual_hostname $new_hostname $short_hostname";
    if [ -f "/etc/cloud/cloud.cfg" ]; then
        log_info "Disabling automatic hostname changes from Cloud init.";
        update_line_in_file --filename "/etc/cloud/cloud.cfg" --text "preserve_hostname" --new_text "preserve_hostname: true";
    fi;
}

function get_major_os_version() {
    if [ "$os_flavor" == "red hat" ]; then
        local version="$(rpm -q --qf "%{VERSION}" $(rpm -q --whatprovides redhat-release) | grep -Eo '^[0-9]*')";
        echo "$version";
    else
        exit 1;
    fi;
}

