import json
import os
import sys

from infraxys.model.base_object import BaseObject
from .json_window import JsonWindow


class JsonInstance(BaseObject):

    '''
    def __str__(self):
        if hasattr(self, 'name'):
            return self.name

        for attribute in self.get_attributes():
            if attribute.isKey:
                return self.__getattribute__(attribute.name)

        return super().__str__()
    '''

    def load_instance_form_response(self, server_response):
        form_fields = server_response.get_form_fields()
        self.load_instance_from_name_values(form_fields)

    def load_instance_from_name_values(self, name_values):
        for attribute in self.get_attributes():
            self.__setattr__(attribute.name, name_values[attribute.name])

    def load_instance_from_server(self, server_instance_json):
        self.db_id = server_instance_json["dbId"]
        self.container_db_id = server_instance_json["containerDbId"]
        self.environment_db_id = server_instance_json["environmentDbId"]
        for attribute in self.get_attributes():
            print("Setting {} to {}".format(attribute.name, server_instance_json[attribute.name]), flush=True)
            self.__setattr__(attribute.name, server_instance_json[attribute.name])

    def get_value_from_form_fields(self, attribute_name, form_fields):
        return form_fields[attribute_name]

    def to_json_fields(self):
        json = {}
        for attribute in self.get_attributes():
            value = self.__getattribute__(attribute.name)
            json.update({attribute.name: value})

        return json

    def __init__(self, instance_reference=None, parent_instance_reference=None):
        super().__init__(instance_reference=instance_reference, parent_instance_reference=parent_instance_reference)
        self._json_window = None

    def _get_json_window(self):
        if not self._json_window:
            self._json_window = JsonWindow.get_instance()
            css_file = os.getenv("JSON_WINDOW_CSS_FILE")
            if css_file:
                self._json_window.show(css_file="{}/{}".format(os.environ["MODULES_ROOT"], css_file))
            else:
                self._json_window.show()

        return self._json_window

    def show_instance_form_and_ensure(self, parent_instance_id):
        self.parent_instance_id = parent_instance_id

        form = self.form(self)
        form.add_button_click_listener("OK", self.create_new)
        self._get_json_window().set_form(form, auto_close=True)

    def saveInstance(self):
        if not self.parent_instance_reference:
            raise Exception("parent_instance_reference is required for saveInstance.")

        url = '{}/api/v1/instances/{}/{}/{}/{}/addInstance' \
            .format(self.rest_client.endpoint,
                    self.parent_instance_reference.module_branch_path,
                    self.parent_instance_reference.environment_id,
                    self.parent_instance_reference.container_id,
                    self.parent_instance_reference.instance_id)
        response = self.rest_client.execute_request(request_method='POST', url=url, json_body=self.to_json_fields())
        print("----")
        print("----")
        print("----")
        print(response.content)
        print("----")
        print("----")
        json_object = json.loads(response.content.decode('utf-8'))

        print(json_object)
        if "status" in json_object and json_object["status"] == "FAILED":
            message = 'Error creating instance: {}'.format(json_object["message"])
            raise Exception(message)

        return response

    def save(self, instance, parent_instance_guid, parent_container_guid=None, branch='master'):
        if parent_container_guid:
            request_path = f'instance/{branch}/{parent_container_guid}/instances/{parent_instance_guid}/children/ensure'
        else:
            request_path = f'instance/{branch}/{parent_instance_guid}/children/ensure'

        url = "{}/{}".format(self.endpoint, request_path)
        json_body = {
            "instances": [
                instance.to_json_fields()
            ]
        }
        response = self.execute_request(request_method='POST', url=url, json_body=json_body)
        json_object = json.loads(response.content.decode('utf-8'))

        print(json_object)
        if "status" in json_object and json_object["status"] == "FAILED":
            message = 'Error creating instance: {}'.format(json_object["message"])
            raise Exception(message)

        return response
