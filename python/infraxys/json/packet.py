import sys

from .packet_attribute import PacketAttribute
from pprint import pprint

class Packet(object):

    def __init__(self, dbId, guid, name, packetType, attributes_json):
        self.dbId = dbId
        self.guid = guid
        self.name = name
        self.packetType = packetType
        self._attributes = []

        for attribute_json in attributes_json:
            self._attributes.append(PacketAttribute(dbId=attribute_json["dbId"],
                                                   name=attribute_json["name"],
                                                   caption=attribute_json["caption"],
                                                   tooltip=attribute_json["tooltip"],
                                                   typeClassName=attribute_json["typeClassName"],
                                                   uiFieldClassName=attribute_json["uiFieldClassName"],
                                                   required=attribute_json["required"],
                                                   isKey=attribute_json["isKey"],
                                                   defaultValue=attribute_json["defaultValue"],
                                                   newItemsAllowed=attribute_json["newItemsAllowed"],
                                                   maxLength=attribute_json["maxLength"],
                                                   listOfValues=attribute_json["listOfValues"]))

    def get_attributes(self):
        return self._attributes
