import requests
import unittest


base_url = 'http://35.185.50.186:8080/sky'
eci = 'DKabtwQwG4ftnJrAsBWDY3'


def create_sensor(name):
    requests.post('{0}/event/{1}/test/sensor/new_sensor'.format(base_url, eci), {'sensor_name': name})


def delete_sensor(name):
    requests.post('{0}/event/{1}/test/sensor/sensor_unneeded'.format(base_url, eci), {'sensor_name': name})


def sensors():
    resp = requests.get('{0}/cloud/{1}/manage_sensors/sensors'.format(base_url, eci))
    return resp.json()


class TestManageSensorsPico(unittest.TestCase):
    def test(self):
        create_sensor('kitchen')
        create_sensor('bathroom')
        create_sensor('cabinet')
        s = sensors()

        self.assertEqual(len(s), 4)
        self.assertTrue('cabinet' in s)

        delete_sensor('cabinet')
        s = sensors()

        self.assertEqual(len(s), 3)
        self.assertTrue('cabinet' not in s)





if __name__ == '__main__':
    unittest.main()
