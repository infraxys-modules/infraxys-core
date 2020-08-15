from infraxys.json.json_instance import JsonInstance
from infraxys.communicator import Communicator
from .base_object import BaseObject

class Container(BaseObject):

    packet_guid = None

    def __init__(self, environment_id, name=None):
        super().__init__()
        self.environment_id = environment_id
        self.name = name

    def ensure_instance(self):
        json = self.generate_request_json(request_type="ENSURE CONTAINER")
        answer = self.process_ensure_or_clone_request(json=json,
                                        label="Create container '{}' under environment '{}'"
                                        .format(self.name, self.environment_id))
        self.db_id = answer["dbId"]

    def clone_instance(self, source_container_id):
        json = self.generate_request_json(request_type="CLONE CONTAINER")
        json.update({"sourceContainerId": source_container_id})
        answer = self.process_ensure_or_clone_request(json=json,
                                        label="Clone container '{}' under environment '{}'"
                                        .format(source_container_id, self.environment_id))
        self.db_id = answer["dbId"]
        self.name = answer["containerName"]

    def generate_request_json(self, request_type):
        json = {
            "requestType": request_type,
            "targetEnvironmentId": self.environment_id
        }
        return json

    def process_ensure_or_clone_request(self, json, label):
        self.set_status(label)
        self.logger.audit_action_start(label=label)
        answer = Communicator.get_instance().send_synchronous(json=json, return_on_first_answer=True)
        self.logger.info("Answer: {}.".format(answer))
        action_taken = answer["actionTaken"]
        if action_taken == "none":
            self.set_status("Action Environment already exists!")
            self.is_new = False
            self.reason = answer["reason"]
        else:
            self.set_status("Finished: {}".format(label))
            self.logger.audit_action_complete(label=label)
            self.is_new = True

        return answer


