#!/usr/bin/env python

#
# @author jmanders
#
import copy
import datetime
import getpass
import socket
import sys
from pprint import pprint

from .communicator import Communicator

current_hostname = socket.gethostname()
current_os_user = getpass.getuser()


class Logger:

    @staticmethod
    def get_logger(tag, ticket=""):
        return Logger(tag, ticket)

    def __init__(self, tag, ticket):
        self.tag = tag
        self.ticket = ticket

    def trace(self, text, new_line=True):
        self._do_log("TRACE", text, new_line)

    def debug(self, text, new_line=True):
        self._do_log("DEBUG", text, new_line)

    def info(self, text, new_line=True):
        self._do_log("INFO ", text, new_line)

    def warn(self, text, new_line=True):
        self._do_log("WARN ", text, new_line)

    def error(self, text, new_line=True):
        self._do_log("ERROR", text, new_line)

    def fatal(self, text, new_line=True, exit_on_error=True, exit_code=1):
        self._do_log("FATAL", text, new_line)
        if exit_on_error:
            sys.exit(exit_code)

    def audit_json(self, json):
        self._audit(json=json)

    def audit(self, text, ticket="", audit_json={}):
        self._do_log("AUDIT", text, True)
        json = {
            "ticket": ticket,
            "message": text
        }
        self._audit(json=json)

    def audit_action_start(self, label, audit_json={}):
        self.audit_action(label=label, status="start")

    def audit_action_complete(self, label, audit_json={}):
        self.audit_action(label=label, status="complete")

    def audit_action(self, label, status=None, audit_json={}):
        json = copy.deepcopy(audit_json)
        json.update({ "label": label })
        if status:
            json.update({"status": status})

        self._audit(json)

    def _audit(self, json):
        audit_json = {
            "requestType": "SYSTEM",
            "subType": "AUDIT",
            "json": json
        }
        Communicator.get_instance().send_synchronous(json=audit_json)

    def _do_log(self, level, text, new_line=True):
        time_string = datetime.datetime.utcnow().strftime('%d-%m-%Y %H:%M:%S,%f')[:-2]
        line = "[{}] [{}] [{}] [{}] [{}] {}".format(time_string, current_hostname, level, current_os_user, self.tag,
                                                    text)
        if new_line:
            print(line, flush=True)
        else:
            sys.stdout.write(line)
            sys.stdout.flush()

    # noinspection PyMethodMayBeStatic
    def print_dot(self):
        sys.stdout.write('.')
        sys.stdout.flush()

    # noinspection PyMethodMayBeStatic
    def print_object(object_to_print):
        pprint(vars(object_to_print))
