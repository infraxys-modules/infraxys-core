import json

import requests

from infraxys.json.json_utils import JsonUtils
from infraxys.logger import Logger
from .exceptions import BadRequestException, UnauthorizedException, NotFoundException
from .json import json_instance


class InfraxysRestClient(object):
    logger = Logger.get_logger("InfraxysRestClient")
    _instances = {}
    rest_client = None

    @staticmethod
    def get_instance(infraxys_config_variable='INFRAXYS-REST-CLIENT'):
        if not infraxys_config_variable in InfraxysRestClient._instances:
            filename = f"/tmp/infraxys/variables/INFRAXYS-CONFIG/{infraxys_config_variable}"
            InfraxysRestClient.logger.info(f'Retrieving Infraxys (REST) token from {filename}')
            jsonObject = JsonUtils.get_instance().load_from_file(filename=filename)
            endpoint = jsonObject["endpoint"]
            api_token = jsonObject["token"]
            InfraxysRestClient._instances[infraxys_config_variable] = \
                InfraxysRestClient(endpoint=endpoint, api_token=api_token)

        return InfraxysRestClient._instances[infraxys_config_variable]

    def __init__(self, endpoint, api_token):
        self.endpoint = endpoint
        self.api_token = api_token
        self.logger = Logger.get_logger(self.__class__.__name__)
        requests.packages.urllib3.disable_warnings()

    def get_child_instance(self, parent_instance_reference, child_packet_guid=None,
                           child_packet_type=None, attribute_name=None,
                           attribute_value=None, branch='master', json_body={}):

        json_object = self.get_child_instances(parent_instance_guid=parent_instance_guid, container_guid=container_guid,
                                               child_packet_type=child_packet_type,
                                               attribute_name=attribute_name, attribute_value=attribute_value,
                                               branch=branch, json_body=json_body)

        instances = json_object["instances"]
        if len(instances) == 0:
            return None
        elif len(instances) == 1:
            return instances[0]
        else:
            raise Exception("Multiple instances returned while maximum 1 is expected.")

    def get_child_instances(self, parent_instance_guid, container_guid, child_packet_guid=None,
                            child_packet_type=None, attribute_name=None,
                            attribute_value=None, branch='master', json_body={}):
        if container_guid:
            request_path = f'container/{container_guid}/instances/{parent_instance_guid}/children'
        else:
            request_path = f'instance/{branch}/{parent_instance_guid}/children'

        if attribute_name and attribute_value:
            json_body.update({
                "attributeName": attribute_name,
                "attributeValue": attribute_value
            })

        url = "{}/api/v1/{}".format(self.endpoint, request_path)

        if child_packet_type:
            json_body.update({
                "packetType": child_packet_type
            })

        if child_packet_guid:
            json_body.update({
                "packetGuid": child_packet_guid
            })

        response = self.execute_request(request_method='GET', url=url, json_body=json_body)
        json_object = json.loads(response.content.decode('utf-8'))
        return json_object

    def save(self, instance):
        raise Exception("use BaseService.save in the instnace (see Organizations")
        '''
        hier: the instance should contain its parent id (or just container_id for root instances)
            and an instance reference with branch path and such

        when an instance is instantiated in python, retrieve it's packet.json and map field id's with names

        assert isinstance(instance, json_instance.JsonInstance)
        request_path = f'instance/save'

        url = "{}/api/v1/{}".format(self.endpoint, request_path)
        json_body = {
            "id": "8b2293a0-f3ad-418e-a1ce-a24dff044473",
            "packetId": "60e03939-68df-4bfc-935a-67654ae19286",
            "packetName": "Terraform Aliyun runner",
            "packetPath": "github.com\\infraxys-modules\\terraform\\master",
            "attributes": [
                {
                    "id": "e81af9ea-c421-46a9-ac11-338a0e0d049e",
                    "name": "alicloud_provider_version",
                    "value": "1.87.0"
                },
                {
                    "id": "d4693e5b-5bc6-4b0b-82d3-04b8ced82cc7",
                    "name": "aliyun_region",
                    "value": "$container.getAttribute(\"aliyun_core_region\")"
                },
                {
                    "id": "c8a0cf1d-efcc-4894-930a-8bdc98ae09cc",
                    "name": "extra_terraform",
                    "value": ""
                },
                {
                    "id": "82988ae8-7971-4488-a22d-18d15dd569f9",
                    "name": "instance_label",
                    "value": "Aliyun dev ami-builder VPC"
                },
                {
                    "id": "30b59464-45df-45fb-accf-95c9c3d2f8d9",
                    "name": "skip_terraform_action_creation",
                    "value": "1"
                },
                {
                    "id": "0204ebdf-635a-48f9-8bb0-81217ec4824f",
                    "name": "state_velocity_names",
                    "value": ""
                },
                {
                    "id": "98c9d2d5-421f-41b1-a459-7aee9cd5bd8c",
                    "name": "terraform_version",
                    "value": "0.12.26"
                },
                {
                    "id": "ce856561-61bd-478b-916a-bd7e1935bbf9",
                    "name": "aliyun_profile_name",
                    "value": "$container.getAttribute(\"aliyun_profile_name\")"
                },
                {
                    "id": "5805e290-c38c-4653-a7ce-53f98dcbdd77",
                    "name": "TF_LOG",
                    "value": ""
                }
            ],
            "attributes": [
                instance.to_json_fields()
            ]
        }
        response = self.execute_request(request_method='POST', url=url, json_body=json_body)
        json_object = json.loads(response.content.decode('utf-8'))

        print(json_object)
        if "status" in json_object and json_object["status"] == "FAILED":
            message = 'Error creating instance: {}'.format(json_object["message"])
            raise Exception(message)

        return response
        '''

    def ensure_instance(self, instance, parent_instance_guid, parent_container_guid=None, branch='master'):
        assert isinstance(instance, json_instance.JsonInstance)
        if parent_container_guid:
            request_path = f'instance/{branch}/{parent_container_guid}/instances/{parent_instance_guid}/children/ensure'
        else:
            request_path = f'instance/{branch}/{parent_instance_guid}/children/ensure'

        url = "{}/api/v1/{}".format(self.endpoint, request_path)
        json_body = {
            "instances": [
                instance.to_json_fields()
            ]
        }
        response = self.execute_request(request_method='POST', url=url, json_body=json_body)
        json_object = json.loads(response.content.decode('utf-8'))

        if "status" in json_object and json_object["status"] == "FAILED":
            message = 'Error creating instance: {}'.format(json_object["message"])
            raise Exception(message)

        return response

    def execute_get(self, path, json_body=None):
        url = f'{self.endpoint}/api/v1/{path}'
        return self.execute_request(request_method='GET', url=url, json_body=json_body)

    def execute_post(self, path, json_body=None):
        url = f'{self.endpoint}/api/v1/{path}'
        return self.execute_request(request_method='POST', url=url, json_body=json_body)

    def execute_request(self, request_method, url, headers: object = {}, json_body=None):
        headers.update({
            'Content-Type': 'application/json',
            'Authorization': f'token {self.api_token}'
        })

        self.logger.info("Executing {} to REST endpoint: {}".format(request_method, url))
        response = requests.request(request_method, url, headers=headers, verify=False, json=json_body)

        if response.status_code == 200:
            pass
        elif response.status_code == 204:
            self.logger.info("Successful deletion.")
        elif response.status_code == 400:
            raise BadRequestException()
        elif response.status_code == 403:
            raise UnauthorizedException()
        elif response.status_code == 404:
            raise NotFoundException()
        else:
            self.logger.warn("Status code: {}".format(response.status_code))
            try:
                if "token" not in response.content:
                    self.logger.warn(response.content)
            finally:
                pass

        return response
