class Attribute(object):

    @staticmethod
    def load(attribute_json):
        attribute = Attribute()
        attribute.id = attribute_json['id']
        attribute.name = attribute_json['name']
        attribute.caption = attribute_json['caption']
        attribute.type = attribute_json['type']
        attribute.form_column = attribute_json['formColumn']
        attribute.form_order = attribute_json['formOrder']
        attribute.visibility = attribute_json['visibility']
        attribute.writability = attribute_json['writability']
        attribute.required = attribute_json['required']
        attribute.list_of_values = attribute_json['listOfValues']
        attribute.part_of_key = attribute_json['isPartOfKey']
        attribute.reference_filter = attribute_json['referenceFilter'] if 'referenceFilter' in attribute_json else None
        attribute.reference_value_attribute = attribute_json['referenceValueAttributeName'] if 'referenceValueAttributeName' in attribute_json else None
        attribute.reference_child_id_filter = attribute_json['referenceChildIdFilter'] if 'referenceChildIdFilter' in attribute_json else None
        attribute.cache_minutes = attribute_json['cacheMinutes'] if 'cacheMinutes' in attribute_json else 0
        attribute.new_items_allowed = attribute_json['newItemsAllowed']
        attribute.parse_with_velocity = attribute_json['parseWithVelocity']
        attribute.input_prompt = attribute_json['inputPrompt'] if 'inputPrompt' in attribute_json else None
        attribute.tooltip = attribute_json['tooltip'] if 'tooltip' in attribute_json else None
        attribute.scope = attribute_json['scope']
        attribute.default_value = attribute_json['defaultValue'] if 'defaultValue' in attribute_json else None
        return attribute

    def __init__(self, id=None, name=None, caption=None, type=None, form_column=1, form_order = 1000, visibility='ALWAYS',
                 writability='ALWAYS', required=False, list_of_values=None, part_of_key=False, reference_filter=None,
                 reference_value_attribute=None, reference_child_id_filter=None, cache_minutes=0, new_items_allowed=False,
                 parse_with_velocity=False, input_prompt=None, tooltip=None, scope=None, default_value=None):
        self.id = id
        self.name = name
        self.caption = caption
        self.type = type
        self.form_column = form_column
        self.form_order = form_order
        self.visibility = visibility
        self.writability = writability
        self.required = False
        self.list_of_values = list_of_values
        self.part_of_key = part_of_key
        self.reference_filter = reference_filter
        self.reference_value_attribute = reference_value_attribute
        self.reference_child_id_filter = reference_child_id_filter
        self.cache_minutes = cache_minutes
        self.new_items_allowed = new_items_allowed
        self.parse_with_velocity = parse_with_velocity
        self.input_prompt = input_prompt
        self.tooltip = tooltip
        self.scope = scope
        self.default_value = default_value
