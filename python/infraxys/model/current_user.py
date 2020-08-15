from infraxys.logger import Logger
from infraxys.json.json_utils import JsonUtils

class CurrentUser(object):

    def __init__(self):
        self._grants = []
        self._teams = []
        self._projects = []
        self.username = None
        self.full_name = None
        self.logger = Logger.get_logger(self.__class__.__name__)
        self.load_json_file()

    def load_json_file(self):
        self.json_object = JsonUtils.get_instance().load_from_file("/tmp/infraxys/system/current_user.json")
        self._grants = self.json_object['grants']
        self._teams = self.json_object['teams']
        self._projects = self.json_object['projects']
        self.username = self.json_object['username']
        self.full_name = self.json_object['full_name']

    def has_grant(self, grant):
        return grant in self._grants

    def has_team(self, team):
        return team in self.teams

    def get_projects(self):
        return self._projects
