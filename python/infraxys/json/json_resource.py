import os

from infraxys.logger import Logger
from .json_window import JsonWindow


class JsonResource(object):

    def __init__(self):
        self.json_window = json_window
        self.logger = Logger.get_logger(self.__class__.__name__)

    def _get_json_window(self):
        if not self.json_window:
            self.json_window = JsonWindow.get_instance()
            css_file = os.getenv("JSON_WINDOW_CSS_FILE")
            if css_file:
                self.json_window.show(css_file="{}/{}".format(os.environ["MODULES_ROOT"], css_file))
            else:
                self.json_window.show()

        return self.json_window
