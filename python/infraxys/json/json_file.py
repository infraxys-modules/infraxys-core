import os
from infraxys.logger import Logger
from infraxys.json.json_utils import JsonUtils


class JsonFile(object):

    def __init__(self, json_file, items_attribute='items'):
        self.json_file = json_file
        self.items_attribute = items_attribute
        self.logger = Logger.get_logger(self.__class__.__name__)
        self.json_object = JsonUtils.get_instance().load_from_file(self.json_file)

    def get_attribute(self, attribute_name):
        return self.json_object[attribute_name]

    def get_item(self, attribute_name, attribute_value, from_json_object = None, case_sensitive=True):
        json_object = from_json_object if from_json_object else self.json_object
        search_value = attribute_value
        if not case_sensitive:
            search_value = search_value.upper()

        for item in json_object[self.items_attribute]:
            if case_sensitive:
                if item[attribute_name] == search_value:
                    return item
            else:
                if item[attribute_name].upper() == search_value:
                    return item

        return None

    def get_all_items(self):
        return self.json_object[self.items_attribute]

    def get_items(self, attribute_name, attribute_value, from_json_object=None, items_attribute=None):
        results = []
        json_object = from_json_object if from_json_object else self.json_object
        items_attribute_name = items_attribute if items_attribute else self.items_attribute
        for item in json_object[items_attribute_name]:
            if item[attribute_name] == attribute_value:
                results.append(item)

        return results