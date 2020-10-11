import json
from .attribute import Attribute
from .packet_extend import PacketExtend


class Packet(object):

    instances_by_path = {}

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
        self.packet_extends = []
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
        self.auto_generate = packet_json['autoGenerate'] if 'autoGenerate' in packet_json else False
        self.info_html = packet_json['infoHtml'] if type in packet_json else ''

        for attribute_json in packet_json['attributes']:
            attribute = Attribute.load(attribute_json)
            self.attributes.append(attribute)
            self.attributes_by_lower_name[attribute.name.lower()] = attribute

        if 'extends' in packet_json:
            for extends_packet_json in packet_json['extends']:
                packet_extend = PacketExtend.load(extends_packet_json)
                self.packet_extends.append(packet_extend)

    def get_default_value(self, attribute_name):
        if attribute_name.lower() in self.attributes_by_lower_name:
            return self.attributes_by_lower_name[attribute_name.lower()]