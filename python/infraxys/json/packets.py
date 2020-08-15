import json, os, sys
from .json_utils import JsonUtils
from .packet import Packet
from infraxys.logger import Logger
from pprint import pprint


class Packets(object):

    _instance = None

    @staticmethod
    def get_instance():
        if not Packets._instance:
            Packets._instance = Packets()
            Packets._instance._load()

        return Packets._instance

    def __init__(self):
        self.logger = Logger.get_logger(self.__class__.__name__)
        self.packets = {}
        self.packets_by_type = {}

    def _load(self):
        json_file="{}/environment.auto/packets.json".format(os.environ["ENVIRONMENT_DIR"])
        self.logger.debug("Loading packets from {}".format(json_file))
        with open(json_file, "r") as file:
            json_string = file.read()
        json.loads(json_string, object_hook=Packets.decode_packets)

    def get_packet(self, guid=None, packet_type=None):
        if guid:
            return self.packets[guid]
        elif packet_type:
            return self.packets_by_type[packet_type]
        else:
            self.logger.error("guid or packet_type should be past to packets.get_packet().")
            sys.exit(1)

    def decode_packets(dct):
        if "guid" in dct:
            packet = Packet(dbId=dct["dbId"], guid=dct["guid"], name=dct["name"],
                            packetType=dct["packetType"], attributes_json=dct["attributes"])

            Packets.get_instance().packets[packet.guid] = packet
            if "packetType" in dct:
                Packets.get_instance().packets_by_type[packet.packetType] = packet

        return dct
