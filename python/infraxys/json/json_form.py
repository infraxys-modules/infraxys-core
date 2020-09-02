import requests
from infraxys.communicator import Communicator
from infraxys.logger import Logger
from infraxys.json.json_window import JsonWindow
from .json_utils import JsonUtils


class JsonForm(object):

    def __init__(self, form_file=None, form_json=None, json_window=None, ok_callback=None):
        self.form_file = form_file
        self.form_json = form_json
        self.json_window = json_window
        self.data_parts = []
        self.button_click_listeners = {}
        self.value_change_listeners = {}
        self.json_window = JsonWindow.get_instance()
        self.logger = Logger.get_logger(self.__class__.__name__)

        if ok_callback:
            self.add_button_click_listener("OK", ok_callback)

        if self.form_file:
            self.form_json = JsonUtils.get_instance().load_from_file(form_file)

    def add_button_click_listener(self, key, callback):
        if not key in self.button_click_listeners:
            self.button_click_listeners[key] = []

        self.button_click_listeners[key].append(callback)

    def add_value_change_listener(self, object_id, callback):
        if not object_id in self.value_change_listeners:
            self.value_change_listeners[object_id] = []

        self.value_change_listeners[object_id].append(callback)

    def add_data_part(self, key, list_items_attribute="items", data_part_json=None, data_part_file=None, data_part_url=None,
                      cached_filename=None):

        full_data_part_json = {
            "id": key,
            "listItemsAttribute": list_items_attribute,
        }

        if data_part_file:
            full_data_part_json.update({"data": self.load_json_file(file=data_part_file)})
        elif data_part_url:
            self.set_status("Retrieving json from {}.".format(data_part_url))
            response = requests.get(url=data_part_url)
            self.set_status("Json retrieved.")
            full_data_part_json.update({"data": response.json()})
        elif cached_filename:
            full_data_part_json.update({"cachedFilename": cached_filename})

        self.logger.info("Adding data part '{}'.".format(key))



        self.data_parts.append(full_data_part_json)

    def load_json_file(self, file):
        return JsonUtils.get_instance().load_from_file(file)

    def generate_json(self):
        json = {
            "requestType": "UI",
            "subType": "FORM",
        }

        json["json"] = self.form_json
        if len(self.data_parts) > 0:
            if "dataParts" not in json["json"]:
                json["json"]["dataParts"] = []

            for data_part in self.data_parts:
                json["json"]["dataParts"].append(data_part)

        return json

    def event(self, event_data):
        if event_data.event_type == "BUTTON_CLICK":
            if event_data.event_details in self.button_click_listeners:
                for listener in self.button_click_listeners[event_data.event_details]:
                    result = listener(event_data)

                    if result == False: # Only explicitly returning False will hold the form
                        return False

                return True
            else:
                self.json_window.close_with_error(
                    "No button_click_listeners defined for eventDetails '{}'".format(event_data.event_details))

        elif event_data.event_type == "VALUE CHANGE":
            if event_data.object_id in self.value_change_listeners:
                for listener in self.value_change_listeners[event_data.object_id]:
                    result = listener(event_data)

            return False # Make sure the form doesn't close

        return True

    def write_attribute_value(self, json, attribute_id, attribute_id_value, write_attribute_name, write_attribute_value):
        if "canvas" in json:
            self.write_attribute_value(json=json["canvas"], attribute_id=attribute_id,
                                       attribute_id_value=attribute_id_value, write_attribute_name=write_attribute_name,
                                       write_attribute_value=write_attribute_value)
        elif "columns" in json:
            for column in json["columns"]:
                self.write_attribute_value(json=column, attribute_id=attribute_id,
                                      attribute_id_value=attribute_id_value, write_attribute_name=write_attribute_name,
                                      write_attribute_value=write_attribute_value)
        elif "components" in json:
            for field in json["components"]:
                self.write_attribute_value(json=field, attribute_id=attribute_id,
                                      attribute_id_value=attribute_id_value, write_attribute_name=write_attribute_name,
                                      write_attribute_value=write_attribute_value)
        else:
            if attribute_id in json and json[attribute_id] == attribute_id_value:
                json[write_attribute_name] = write_attribute_value

    def tag_all_fields(self, json, tags_json):
        if "canvas" in json:
            self.tag_all_fields(json=json["canvas"], tags_json=tags_json)
        elif "columns" in json:
            for column in json["columns"]:
                self.tag_all_fields(json=column, tags_json=tags_json)
        elif "components" in json:
            for field in json["components"]:
                field["tags"] = tags_json

    def rename_id_fields(self, json, suffix):
        if "canvas" in json:
            self.rename_id_fields(json["canvas"], suffix)
        elif "columns" in json:
            for column in json["columns"]:
                self.rename_id_fields(column, suffix)
        elif "components" in json:
            for field in json["components"]:
                self.rename_id_fields(field, suffix)
        else:
            json["id"] = "{}{}".format(json["id"], suffix)

    def copy_fields_from_server_response(self, server_response, into, field_id_suffix=""):
        fields = server_response.get_form_fields()
        for field_name in fields:
            real_id = field_name[0: len(field_name) - len(field_id_suffix)]
            into[real_id] = fields[field_name]

    def set_data_part(self, element_id, json_data_part):
        Communicator.get_instance().set_data_part(element_id=element_id, json_data_part=json_data_part)

    def set_status(self, message):
        Communicator.set_status(message)

    def clear_status(self):
        self.set_status(message="")

    def set_object_value(self, object_id, value=None, base64Value=None):
        assert value or base64Value

        json = {
            "requestType": "UI",
            "subType": "UPDATE VALUE",
            "objectId": object_id
        }
        if value:
            json.update({"value": value})
        else:
            json.update({"valueBase64": base64Value})

        Communicator.get_instance().send_synchronous(json=json)

    def set_object_enabled(self, object_id, value=True):
        json = {
            "requestType": "UI",
            "subType": "SET ENABLED",
            "objectId": object_id
        }
        json.update({"value": value})

        Communicator.get_instance().send_synchronous(json=json)
