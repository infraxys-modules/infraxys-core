class InstanceReference(object):

    # environment_id is not there for roles
    def __init__(self, module_branch_path, container_id, instance_id, environment_id=None, name=None):
        self.module_branch_path = module_branch_path
        self.container_id = container_id
        self.instance_id = instance_id
        self.environment_id = environment_id
        self.name = name

    def to_rest_get_json(self):
        return {
            'moduleBranchPath': self.module_branch_path,
            'environmentId': self.environment_id,
            'containerId': self.container_id,
            'instanceId': self.instance_id
        }
