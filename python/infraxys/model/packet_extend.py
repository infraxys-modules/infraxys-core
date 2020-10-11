class PacketExtend(object):

    @staticmethod
    def load(extend_json):
        packetExtend = PacketExtend()
        packetExtend.name = extend_json['name']
        packetExtend.id = extend_json['id']
        packetExtend.module_branch_path = extend_json['moduleBranchPath']
        return packetExtend

    def __init__(self):
        self.name = None
        self.id = None
        self.module_branch_path = None


