from infraxys.json.json_instance import JsonInstance
from infraxys.communicator import Communicator
from .base_object import BaseObject


class Environment(BaseObject):

    packet_guid = None

    def __init__(self, project_id, name):
        super().__init__()
        self.project_id = project_id
        self.name = name

    def ensure_instance(self):
        json = self.generate_request_json(request_type="ENSURE ENVIRONMENT")
        self.process_ensure_or_clone_request(json=json,
                                        label="Create environment '{}' under project '{}'"
                                        .format(self.name, self.project_id))

    def clone_instance(self, source_environment_id):
        json = self.generate_request_json(request_type="CLONE ENVIRONMENT")
        json.update({"sourceEnvironmentId": source_environment_id})
        self.process_ensure_or_clone_request(json=json,
                                        label="Create environment '{}' under project '{}' by cloning {}"
                                        .format(self.name, self.project_id, source_environment_id))

    def generate_request_json(self, request_type):
        json = {
            "requestType": request_type,
            "projectId": self.project_id,
            "environmentName": self.name
        }
        return json

    def process_ensure_or_clone_request(self, json, label):
        self.logger.audit_action_start(label=label)
        answer = Communicator.get_instance().send_synchronous(json=json, return_on_first_answer=True)
        self.logger.info("Answer: {}.".format(answer))
        action_taken = answer["actionTaken"]
        if action_taken == "none":
            self.set_status("Environment '{}' already exists!".format(self.name))
            self.is_new = False
            self.reason = answer["reason"]
        else:
            self.set_status("Finished: {}".format(label))
            self.logger.audit_action_complete(label=label)
            self.is_new = True

        self.db_id = answer["dbId"]

