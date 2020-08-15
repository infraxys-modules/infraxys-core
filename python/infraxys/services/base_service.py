from infraxys.logger import Logger


class BaseService(object):

    def __init__(self):
        self.logger = Logger.get_logger(self.__class__.__name__)
