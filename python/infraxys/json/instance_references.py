from infraxys.json.instance_reference import InstanceReference
from infraxys.json.json_utils import JsonUtils


class InstanceReferences(object):
    _references_by_name = {}

    def load(instance_references_file):
        json_object = JsonUtils.get_instance().load_from_file(instance_references_file)
        for (key, ref) in json_object.items():
            InstanceReferences._references_by_name[key] = InstanceReference(name=key,
                                                                            module_branch_path=ref['moduleBranchPath'],
                                                                            environment_id=ref['environmentId'],
                                                                            container_id=ref['containerId'],
                                                                            instance_id=ref['instanceId'])

    def get_instance_reference(reference_name):
        if reference_name in InstanceReferences._references_by_name:
            return InstanceReferences._references_by_name[reference_name]

        return None
