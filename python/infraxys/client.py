import json


class Client(object):

    @staticmethod
    def statusMessage(message):
        jsonObject = {
            "type": "STATUS-MESSAGE",
            "message": message
        }

        print('<CLIENT-FEEDBACK>' + json.dumps(jsonObject) +
              '</CLIENT-FEEDBACK>', flush=True)
