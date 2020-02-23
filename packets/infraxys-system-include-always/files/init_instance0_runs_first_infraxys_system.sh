export INSTANCE_GUID="$instance.getGuid()";
export PACKET_GUID="$instance.getPacketGuid()";
export instance_db_id=$instance.id;
#if ($instance.attributes)
#foreach ($attribute in $instance.attributes)
#if ($attribute.autoExportToScript == true)
export $attribute.name="$(cat << EOF
$attribute.value
EOF
)";
#end  
#end
#end 


#[[
export GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"

infraxys_system_init_instance_start_dir="$(pwd)"
for f in $(find ../../environment.auto -maxdepth 1 -type f -name \*.sh | sort); do
    log_info "Automatically sourcing environment scoped bash script $f";
    source "$f";
done;

for f in $(find ../container.auto -maxdepth 1 -type f -name \*.sh | sort); do
    log_info "Automatically sourcing container scoped bash script $f";
    source "$f";
done;
]]#

cd "${D}infraxys_system_init_instance_start_dir";
