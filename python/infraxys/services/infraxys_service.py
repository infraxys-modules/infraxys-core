import json

from infraxys.communicator import Communicator
from infraxys.exceptions import NotFoundException
from infraxys.infraxys_rest_client import InfraxysRestClient
from infraxys.model.base_object import BaseObject
from infraxys.model.packet import Packet
from infraxys.services.base_service import BaseService
from ..json.instance_reference import InstanceReference


class InfraxysService(BaseService):
    _instance = None

    def get_instance():
        if not InfraxysService._instance:
            InfraxysService._instance = InfraxysService()

        return InfraxysService._instance

    def get_by_reference(self, instance_reference, target_class=None, target_instance=None):
        assert target_class or target_instance
        json_body = instance_reference.to_rest_get_json()
        try:
            response = InfraxysRestClient.get_instance().execute_get(path='instances', json_body=json_body)
        except NotFoundException as e:
            self.logger.info(f'No instance was found with {json_body}')
            raise e

        json_response = json.loads(response.content.decode('utf-8'))
        instance_json = json_response['instance']
        return self._get_instance_from_instance_json(instance_json, target_class, target_instance)

    def get_child_by_attribute(self, parent_instance, attribute_name, attribute_value, target_class=None,
                               target_instance=None):
        assert target_class or target_instance
        json_body = parent_instance.instance_reference.to_rest_get_json()
        json_body.update({
            'attributeName': attribute_name,
            'attributeValue': attribute_value
        })
        response = InfraxysRestClient.get_instance().execute_get(path='instances/byAttributeNameAndValue',
                                                                 json_body=json_body)
        json_response = json.loads(response.content.decode('utf-8'))
        # print(json_response)
        if 'instance' in json_response:
            instance_json = json_response['instance']
            result = self._get_instance_from_instance_json(instance_json, target_class, target_instance)
            return result

        return None

    def get_instances_by_packet_type(self, parent_instance, packet_type, target_class, recursive=False):
        json_body = parent_instance.instance_reference.to_rest_get_json()
        json_body.update({
            'packetType': packet_type,
            'recursive': recursive
        })
        response = InfraxysRestClient.get_instance().execute_get(path='instances/byPacketType', json_body=json_body)
        json_response = json.loads(response.content.decode('utf-8'))
        results = []
        if 'instances' in json_response:
            for instance_json in json_response['instances']:
                instance = self._get_instance_from_instance_json(instance_json, target_class)
                results.append(instance)

        return results

    def _get_instance_from_instance_json(self, instance_json, target_class=None, target_instance=None):
        assert target_class or target_instance
        instance_reference = InstanceReference(instance_json['moduleBranchPath'],
                                               instance_json['containerId'],
                                               instance_json['id'],
                                               instance_json['environmentId'])
        if target_instance:
            instance = target_instance
        else:
            instance = target_class(instance_reference=instance_reference)

        attributes = []
        self._load_attribute_values(add_to_attributes=attributes, instance=instance, packet=instance.get_packet())

        if 'attributes' in instance_json:
            attributes_json = instance_json['attributes']
            #self.logger.info(f'Creating instance of class {target_class}')

            for attribute_json in attributes_json:
                attribute_name = attribute_json['name']
                if hasattr(instance, attribute_name):
                    instance.__setattr__(attribute_name, attribute_json['value'])
                else:
                    self.logger.debug(f'Python class doesn\'t have attribute {attribute_name}')

        return instance

    def save(self, instance):
        assert isinstance(instance, BaseObject)
        assert instance.instance_reference or instance.parent_instance_reference \
               or (instance.parent_instance and instance.parent_instance.instance_reference)

        packet = instance.get_packet()  # PacketService.get_instance().get_packet(for_instance=instance)
        assert packet
        instance_body = {
            "packetId": packet.id,
            "packetPath": packet.module_branch_path
        }

        attributes = []
        self._load_attribute_values(add_to_attributes=attributes, instance=instance, packet=packet)

        if instance.instance_reference:  # existing instance
            instance_body.update({
                "id": instance.instance_reference.instance_id,
                "moduleBranchPath": instance.instance_reference.module_branch_path,
                "environmentId": instance.instance_reference.environment_id,
                "containerId": instance.instance_reference.container_id
            })
        else:  # add to parent
            ref_to_use = instance.parent_instance_reference if instance.parent_instance_reference else instance.parent_instance.instance_reference

            instance_body.update({
                "parentId": ref_to_use.instance_id,
                "moduleBranchPath": ref_to_use.module_branch_path,
                "environmentId": ref_to_use.environment_id,
                "containerId": ref_to_use.container_id
            })

        instance_body.update({
            "attributes": attributes
        })

        json_body = {
            "instance": instance_body
        }

        # print(json_body)
        # print('---------------')
        response = InfraxysRestClient.get_instance().execute_post(path='instances', json_body=json_body)
        json_object = json.loads(response.content.decode('utf-8'))

        # print(json_object)
        if "status" in json_object and json_object["status"] == "FAILED":
            message = 'Error creating instance: {}'.format(json_object["message"])
            raise Exception(message)

        return response

    def _load_attribute_values(self, add_to_attributes, instance, packet):
        for attribute in packet.attributes:
            value = None
            if hasattr(instance, attribute.name):
                value = instance.__getattribute__(attribute.name)

            add_to_attributes.append({
                "id": attribute.id,
                "name": attribute.name,
                "value": value
            })

        for packet_extend in packet.packet_extends:
            self._load_attribute_values(add_to_attributes, instance, self.get_packet(packet_extend))

    def get_packet(self, packet_extend):
        path = packet_extend.module_branch_path.replace('\\', '/')
        if not path in Packet.instances_by_path:
            packet_directory=f'/tmp/infraxys/modules/{path}/packets/{packet_extend.name}'
            self.logger.info('Retrieving extended packet from: ' + packet_directory)
            json_file = f'{packet_directory}/packet.json'
            packet = Packet(json_file)
            Packet.instances_by_path[path] = packet

        return Packet.instances_by_path[path]

    @staticmethod
    def add_action_error(code, message):
        json = {
            "requestType": "ADD_ACTION_ERROR",
            "code": code,
            "message": message
        }
        Communicator.get_instance().send_asynchronous(json=json)

    @staticmethod
    def add_action_log_entry(message, level='INFO'):
        json = {
            "requestType": "ADD_ACTION_LOG",
            "level": level,
            "message": message
        }
        Communicator.get_instance().send_asynchronous(json=json)

    @staticmethod
    def set_rest_response(message):
        json = {
            "requestType": "SET_REST_RESPONSE",
            "actionResponse": {
                "message": message
            }
        }
        Communicator.get_instance().send_asynchronous(json=json)
