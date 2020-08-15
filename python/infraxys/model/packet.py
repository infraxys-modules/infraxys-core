import json
from .attribute import Attribute


class Packet(object):

    def __init__(self, packet_json_path):
        self.packet_json_path = packet_json_path
        self.id = None
        self.label = None
        self.type = None
        self.key = None
        self.auto_expand = True
        self.skip_every_instance_files = False
        self.limit_to_allowed_children = False
        self.auto_generate = False
        self.info_html = None
        self.attributes = []
        self.attributes_by_lower_name = {}

        # generate unique module branch path to the repo of this packet
        parts = packet_json_path.split("/")
        self.module_branch_path = f'{parts[4]}\\{parts[5]}\\{parts[6]}\\{parts[7]}'
        self._load_from_json()

    def _load_from_json(self):
        with open(self.packet_json_path, 'r') as file:
            json_string = file.read()

        packet_json = json.loads(json_string)
        self.id = packet_json['id']
        self.label = packet_json['label']
        self.type = packet_json['type'] if type in packet_json else ''
        self.key = packet_json['key'] if type in packet_json else ''
        self.auto_expand = packet_json['autoExpand']
        self.skip_every_instance_files = packet_json['skipEveryInstanceFiles']
        self.limit_to_allowed_children = packet_json['limitToAllowedChildren']
        self.auto_generate = packet_json['autoGenerate']
        self.info_html = packet_json['infoHtml'] if type in packet_json else ''

        for attribute_json in packet_json['attributes']:
            attribute = Attribute.load(attribute_json)
            self.attributes.append(attribute)
            self.attributes_by_lower_name[attribute.name.lower()] = attribute

    def get_default_value(self, attribute_name):
        if attribute_name.lower() in self.attributes_by_lower_name:
            return self.attributes_by_lower_name[attribute_name.lower()]