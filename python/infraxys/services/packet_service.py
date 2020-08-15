import os
import sys

from infraxys.model.packet import Packet
from infraxys.services.base_service import BaseService


class PacketService(BaseService):

    _instance = None

    @staticmethod
    def get_instance():
        if not PacketService._instance:
            PacketService._instance = PacketService()

        return PacketService._instance

    def __init__(self):
        super().__init__()
        self.packets_by_directory = {}

    def zzget_packet(self, for_instance=None, packet_directory=None):
        assert for_instance or packet_directory
        if not packet_directory:
            class_file = sys.modules[for_instance.__class__.__module__].__file__
            class_directory = os.path.dirname(os.path.abspath(class_file))
            packet_name = for_instance.__class__.packet_name
            parts = class_directory.split('/')
            packet_directory = f'{parts[0]}/{parts[1]}/{parts[2]}/{parts[3]}/{parts[4]}/{parts[5]}/{parts[6]}' \
                               f'/{parts[7]}/packets/{packet_name}'

        if not packet_directory in self.packets_by_directory:
            json_file = f'{packet_directory}/packet.json'
            self.logger.info("Retrieving packet object from " + json_file)
            self.packets_by_directory[packet_directory] = Packet(json_file)

        return self.packets_by_directory[packet_directory]
