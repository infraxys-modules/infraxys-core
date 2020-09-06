import base64, sys, traceback
from infraxys.communicator import Communicator
from infraxys.logger import Logger
from .server_answer import *


class JsonWindow(object):

    _instance = None

    @staticmethod
    def get_instance():
        if not JsonWindow._instance:
            JsonWindow._instance = JsonWindow()

        return JsonWindow._instance

    @staticmethod
    def is_open():
        return self._instance and self._instance.window_is_open

    def __init__(self):
        self.css_file = None
        self.canceled = False
        self.auto_close = False
        self.window_is_open = False
        self.logger = Logger.get_logger(self.__class__.__name__)

    def show(self, css_file=None):
        self.css_file = css_file
        json = {
            "requestType": "UI",
            "subType": "WINDOW",
        }

        if css_file:
            file = open(css_file, 'r')
            css = file.read()
            base64_css = base64.b64encode(css.encode("utf-8"))
            json["css"] = base64_css.decode("utf-8")

        Communicator.get_instance().send_synchronous(json=json, callback=self.answer_received,
                                                     return_on_first_answer=False)
        self.window_is_open = True

    def set_form(self, form, form_loaded_listener=None, auto_close=False, status=""):
        self.active_form = form
        self.auto_close = auto_close
        self.form_loaded_listener = form_loaded_listener
        json = form.generate_json()
        if status == "":
            self.set_status(status)
        Communicator.get_instance().send_synchronous(json=json, callback=self.answer_received)
        # return from this method is only when the form is closed or replaced

    def answer_received(self, json_object):
        try:
            if json_object == "":
                self.logger.info("Empty answer received from server.")
                Communicator.get_instance().wait_for_server(callback=self.answer_received)
                return

            #print("===", flush=True)
            #print(json_object, flush=True)
            #print("===", flush=True)
            schema = ServerAnswerSchema()
            event_data = schema.load(json_object)
            if event_data.event_type == "FORM_LOADED":
                if self.form_loaded_listener:
                    self.form_loaded_listener(event_data)

                Communicator.get_instance().wait_for_server(callback=self.answer_received)
                return

            elif event_data.event_type == "BUTTON_CLICK":
                if event_data.event_details == "CANCEL":
                    self.canceled = True
                    self.close()
                    return

            if self.active_form.event(event_data):
                if self.auto_close and event_data.event_details == "OK":
                    self.close()
            else:
                Communicator.get_instance().wait_for_server(callback=self.answer_received)

        except Exception as e:
            print("Exception handling event", flush=True)
            traceback.print_exc()
            print(e, flush=True)
            raise e


    def close(self):
        if not self.window_is_open:
            return
        json = {
            "requestType": "UI",
            "subType": "ACTION",
            "action": "close"
        }

        Communicator.get_instance().send_synchronous(json=json)
        Communicator.get_instance().stop_listening()
        self.window_is_open = False

    def close_with_error(self, message):
        self.logger.error(message)
        self.close()
        sys.exit(1)

    def set_status(self, message):
        Communicator.set_status(message)
