from infraxys.logger import Logger
from infraxys.communicator import Communicator

class JsonInstances(object):

    def __init__(self, instances, parent_instance_id, packet_guid):
        self.instances = instances
        self.parent_instance_id = parent_instance_id
        self.packet_guid = packet_guid
        self.logger = Logger.get_logger(self.__class__.__name__)


    def import_instances(self, remove_existing_children):
        json_request = {
            "requestType": "IMPORT INSTANCES",
            "parentInstanceId": self.parent_instance_id,
            "packetGuid": self.packet_guid,
            "removeExistingChildren": remove_existing_children,
            "instances": []
        }

        instances_attribute = json_request["instances"]
        for instance in self.instances:
            instances_attribute.append({ "fields": instance.to_json_fields()})

        answer = Communicator.get_instance().send_synchronous(json=json_request)
        print("Json answer: {}.".format(answer), flush=True)
        return answer
