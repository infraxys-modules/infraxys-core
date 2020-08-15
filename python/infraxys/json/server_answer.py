from marshmallow import Schema, fields, post_load, ValidationError, validates


class ServerAnswersSchema(Schema):
    id = fields.String(required=True)
    selectedItemList = fields.Raw(attribute='selectedItemList')
    value = fields.String()
    tags = fields.Raw(required=False) #fields.Nested fields.String(required=False)

    @post_load
    def make_result(self, data, many, partial):
        return ServerAnswerResult(**data)


class ServerAnswerResult(object):

    def __init__(self, id, selectedItemList=None, value=None, tags=None):
        self.id = id
        self.selectedItemList = selectedItemList
        self.value = value
        self.tags = tags


class ServerAnswerSchema(Schema):
    eventType = fields.String(attribute='event_type',
                              required=True)
    eventDetails = fields.String(attribute='event_details',
                                 required=False,
                                 error_messages={'required': 'eventDetails is required.'})
    eventDetailsJson = fields.List(cls_or_instance=fields.Dict, attribute='event_details_json',
                                   required=False)
    results = fields.Nested(ServerAnswersSchema, many=True)
    objectId = fields.String(attribute='object_id', required=False)
    tags = fields.Raw(required=False)

    #@validates('eventType')
    #def validate_event_type(self, event_type):
    #    if event_type != 'BUTTON_CLICK':
    #        raise ValidationError('Unknown event type: {}.'.format(event_type))

    @post_load
    def make_server_answer(self, data, many, partial):
        return ServerAnswer(**data)


class ServerAnswer(object):

    def __init__(self, event_type, results, event_details=None, event_details_json=None, object_id=None, tags=None):
        self.event_type = event_type
        self.event_details = event_details
        self.event_details_json = event_details_json
        self.results = results
        self.object_id = object_id
        self.tags = tags

    def get_result(self, result_id):
        for result in self.results:
            if result.id == result_id:
                return result

    def get_selected_item(self, result_id):
        return self.get_result(result_id).selectedItemList[0]

    def get_selected_items(self, result_id):
        return self.get_result(result_id).selectedItemList

    def get_form_fields(self):
        json = {}
        for result in self.results:
            if result.selectedItemList:
                json[result.id] = result.selectedItemList
            else:
                json[result.id] = result.value

        return json
