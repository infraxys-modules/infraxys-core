class BaseException(Exception):

    def __init__(self, label=None):
        self.label = label

    def __str__(self):
        if self.label:
            return "BaseException: {}".format(self.label)
        else:
            return "BaseException"

class HandledException(Exception):

    def __init__(self, exception_number, label):
        self.exception_number = exception_number
        self.label = label

    def __str__(self):
        return f'HandledException: {self.exception_number} - {self.label}'

class UnauthorizedException(BaseException):

    def __str__(self):
        if self.label:
            return "UnauthorizedException: {}".format(self.label)
        else:
            return "UnauthorizedException"


class BadRequestException(BaseException):

    def __str__(self):
        if self.label:
            return "BadRequestException: {}".format(self.label)
        else:
            return "BadRequestException"


class NotFoundException(BaseException):

    def __str__(self):
        if self.label:
            return "NotFoundException: {}".format(self.label)
        else:
            return "NotFoundException"
