import os

from infraxys.communicator import Communicator
from infraxys.logger import Logger


class BaseObject(object):

    def __init__(self, instance_reference=None, parent_instance_reference=None, parent_instance=None):
        self.instance_reference = instance_reference
        self.parent_instance_reference = parent_instance_reference
        self.parent_instance = parent_instance
        self._packet = None
        self.logger = Logger.get_logger(self.__class__.__name__)

    def get_packet(self):
        return self._packet

    def get_parent_instance_guid(self):
        return self.parent_instance_guid

    def set_parent_instance_guid(self, parent_instance_guid):
        self.parent_instance_guid = parent_instance_guid

    def set_status(self, message):
        Communicator.set_status(message)

    def from_environment(self):
        for attribute in self.get_attributes():
            self.__setattr__(attribute.name, os.getenv(attribute.name, ""))

        self._loaded()
        return self

    def _loaded(self):
        pass  # override this method if you need to calculate variables after all values are set

    def get_attributes(self):
        return self.get_packet().get_attributes()

    def audit_action_start(self, label):
        self.logger.audit_action_start(label=label, audit_json=self.audit_json)

    def audit_action_complete(self, label):
        self.logger.audit_action_complete(label=label, audit_json=self.audit_json)

    def audit_action(self, label, status=None):
        self.logger.audit_action(label=label, status=status, audit_json=self.audit_json)

    def get_from_db_by_velocity_name(self, velocity_name, container_id=None, environment_id=None):
        assert container_id or environment_id
        json = {
            "requestType": "GET INSTANCE",
            "velocityName": velocity_name
        }

        if container_id:
            json.update({"containerId": container_id})
        else:
            json.update({"environmentId": environment_id})

        answer = Communicator.get_instance().send_synchronous(json=json)
        print(answer, flush=True)
        self.load_instance_from_server(answer)

    def ensure_instance(self, compile_container=False, compile_instance=False, compile_environment=False):
        json = {
            "requestType": "ENSURE INSTANCE",
            "packetGuid": self.packet_guid,
            "parentInstanceId": self.parent_instance_id,
            "compileInstance": compile_instance,
            "compileContainer": compile_container,
            "compileEnvironment": compile_environment,
            "fields": self.to_json_fields()
        }
        answer = Communicator.get_instance().send_synchronous(json=json)
        self.instance_id = answer["dbId"]
        return answer

    def update_instance(self, compile_container=False, compile_instance=False, compile_environment=False):
        assert self.db_id
        json = {
            "requestType": "UPDATE INSTANCE",
            "dbId": self.db_id,
            "compileInstance": compile_instance,
            "compileContainer": compile_container,
            "compileEnvironment": compile_environment,
            "fields": self.to_json_fields()
        }
        answer = Communicator.get_instance().send_synchronous(json=json)
        return answer

    def execute_pipeline(self, pipeline_type="INSTALL", scope="ENVIRONMENT"):
        assert self.db_id
        assert scope == "ENVIRONMENT" or scope == "CONTAINER"
        json = {
            "requestType": "EXECUTE PIPELINE",
            "pipelineType": "INSTALL"
        }

        if scope == "CONTAINER":
            json.update({"containerId": self.container_db_id})
        else:
            json.update({"environmentId": self.environment_db_id})

        answer = self._execute_action(
            label="Executing {} {} pipeline for {}".format(scope, pipeline_type, self.__str__()),
            json=json)
        return answer

    def execute_action(self, filename, instance_id=None, label=None):
        raise Exception("Use REST-API to execute actions.")
        if instance_id == None:
            if self.instance_id == None:
                raise BaseException(
                    "instance_id should be passed to execute_action if it wasn't set during instance creation.")
        else:
            self.instance_id = instance_id

        json = {
            "requestType": "EXECUTE ACTION",
            "instanceId": self.instance_id,
            "filename": filename
        }

        if not label:
            label = "Executing action '{}' on '{}'".format(filename, self.__str__())

        answer = self._execute_action(label=label,
                                      json=json)
        return answer

    def _execute_action(self, label, json):
        self.set_status(label)
        self.logger.audit(label)
        answer = Communicator.get_instance().send_synchronous(json=json, return_on_first_answer=False)
        if answer:
            print("Answer: {}.".format(answer), flush=True)

        self.set_status("Finished: {}".format(label))
        return answer

    def create_new(self, server_response):
        self.logger.debug("Creating new.")
        self.load_instance_form_response(server_response)
        self.ensure_instance(compile_instance=True)
