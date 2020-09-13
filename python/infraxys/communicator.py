import sys, json, termios, tty
import fileinput
from json import JSONDecodeError

class Communicator():

    instance = None

    @staticmethod
    def get_instance():
        if not Communicator.instance:
            Communicator.instance = Communicator()

        return Communicator.instance

    def __init__(self):
        self._callback = None
        self._previous_callback = None
        self._keep_listening = False

    def _set_callback(self, callback):
        if self._previous_callback:
            raise Exception("You can only have 2 levels of callback listeners.")
        self._previous_callback = self._callback
        self._callback = callback

    def _set_previous_callback(self):
        self._callback = self._previous_callback
        self._previous_callback = None

    @staticmethod
    def show_info_message(message):
        Communicator.show_message(message=message, type="INFO")

    @staticmethod
    def show_warning_message(message):
        Communicator.show_message(message=message, type="WARNING")

    @staticmethod
    def show_error_message(message):
        Communicator.show_message(message=message, type="ERROR")

    @staticmethod
    def show_tray_message(message):
        Communicator.show_message(message=message, type="TRAY")

    @staticmethod
    def show_message(message, type):
        Communicator.get_instance()._show_message(message=message, type=type)

    def show_exception_dialog(self, exception, title, is_html=False, width='90%', height='90%'):
        self.show_dialog(message=str(exception), title=title, is_html=is_html, width=width, height=height)

    def show_error_dialog(self, message, title, is_html=True, width='90%', height='90%'):
        self.show_dialog(message=message, title=title, is_html=is_html, width=width, height=height)

    def show_yes_no(self, message, title='', is_html=True, width=450, height=450):
        buttons = [
            {'label': 'Yes', 'id': 1},
            {'label': 'No', 'id': 2}
        ]
        result = self.show_dialog(message=message, title=title, is_html=is_html, width=width, height=height, buttons=buttons)
        return (result == "1")

    def show_dialog(self, message, title='', is_html=True, width=450, height=450, buttons=[{'label': 'OK', 'id': 1}]):
        json = {
            "requestType": "UI",
            "subType": "SHOW DIALOG",
            "isHtml": is_html,
            "message": message,
            "title": title,
            "width": width,
            "height": height,
            "buttons": buttons
        }
        return self.send_synchronous(json, return_on_first_answer=True)

    def _show_message(self, message, type):
        json = {
            "requestType": "UI",
            "subType": "SHOW MESSAGE",
            "message": message,
            "type": type
        }
        self.send_synchronous(json, return_on_first_answer=True)

    def set_status(message):
        Communicator.get_instance()._set_status(message=message)

    def _set_status(self, message):
        json = {
            "requestType": "UI",
            "subType": "STATUS",
            "message": message
        }
        self.send_synchronous(json, return_on_first_answer=True)

    # returns immediately
    def _send_asynchronous(self, json):
        print("<FEEDBACK>", flush=True)
        print(json, flush=True)
        print("</FEEDBACK>", flush=True)

    def send_asynchronous(self, json):
        self._send_asynchronous(json=json)

    def send_synchronous(self, json, callback=None, return_on_first_answer=True):
        self._send_asynchronous(json=json)
        return self.wait_for_server(callback=callback, return_on_first_answer=return_on_first_answer)

    def wait_for_server(self, callback, return_on_first_answer=False):
        self._set_callback(callback)
        self._keep_listening = True
        result = None
        processing_answer = False
        stdin = sys.stdin.fileno()
        fileinput.close() # fileinput is open  when a callback executes this function
        try:
            for line in fileinput.input():
                try:
                    line = line.rstrip()
                    # print("Processing ---- %s" % line, flush=True)
                    if processing_answer:
                        if line == "</FROM_SERVER>":
                            processing_answer = False
                            line = result
                        elif result:
                            result = "{}\n{}".format(result, line)
                        else:
                            result = line

                    elif line == "<FROM_SERVER>":
                        processing_answer = True
                        result = None

                    if processing_answer:
                        continue

                except KeyboardInterrupt:
                    sys.exit(1)

                if line == "SUCCESS" or line == "processed":
                    self._set_previous_callback()
                    break
                elif line == "FAILED":
                    sys.exit(1)
                else:
                    if line.startswith("{") and line.endswith("}"):
                        try:
                            tmp_result = json.loads(line)
                        except JSONDecodeError as e:
                            print("Failed to convert line to string so returning the string", flush=True)
                            tmp_result = line
                    else:
                        tmp_result = line
                        if tmp_result.upper().startswith("ERROR"):
                            print("Error. Exiting.", flush=True)
                            sys.exit(1)

                    _callback = self._callback
                    self._set_previous_callback()
                    if _callback:
                        if _callback(tmp_result) != False:
                            break

                        continue
                    else:
                        result = tmp_result
                        break

                    if return_on_first_answer:
                        result = tmp_result
                        break
                    elif not result:
                        result = tmp_result
                    else:
                        result = """{}
    {}""".format(result, tmp_result)

        finally:
            fileinput.close()

        return result

    def stop_listening(self):
        self._keep_listening = False
