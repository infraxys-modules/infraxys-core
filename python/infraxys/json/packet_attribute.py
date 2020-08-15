

class PacketAttribute(object):

    def __init__(self, dbId, name, caption, tooltip, typeClassName, uiFieldClassName, required, isKey, defaultValue,
                 newItemsAllowed, maxLength, listOfValues):

        self.dbId = dbId
        self.name = name
        self.caption = caption
        self.tooltip = tooltip
        self.typeClassName = typeClassName
        self.uiFieldClassName = uiFieldClassName
        self.required = required
        self.isKey = isKey
        self.defaultValue = defaultValue
        self.newItemsAllowed = newItemsAllowed
        self.maxLength = maxLength
        self.listOfValues = listOfValues
