ruleset manage_sensors {
  meta {
    name "Manage Sensors"
    author "Kyle Hoover"
    shares __testing, sensors, get_temps
  }

  global {
    default_threshold = 75
    default_notification_number = ""
    base_url = "http://35.185.50.186:8080/sky/cloud"

    sensors = function () {
      ent:sensors
    }

    get_temps = function () {
      ent:sensors.values()
        .map(function (eci) {
          http:get(<<#{base_url}/#{eci}/temperature_store/temperatures>>){"content"}.decode()
        })
        .reduce(function (acc, array) {
          acc.append(array)
        }, [])
        .sort(function (a, b) {
          a{"timestamp"} < b{"timestamp"} =>  1 |
          a{"timestamp"} > b{"timestamp"} => -1 |
          0
        })
    }

    __testing = {
      "queries": [
        {"name": "sensors"},
        {"name": "get_temps"}
      ],
      "events": [
        {"domain": "sensor", "type": "new_sensor", "attrs": ["sensor_name"]},
        {"domain": "sensor", "type": "sensor_unneeded", "attrs": ["sensor_name"]}
      ]
    }
  }

  rule init {
    select when wrangler ruleset_added where rids >< meta:rid
    fired {
      ent:sensors := {}
    }
  }

  rule add_sensor {
    select when sensor new_sensor
    pre {
      sensor_name = event:attr("sensor_name")
      exists = ent:sensors >< sensor_name
    }
    if not exists then noop()
    fired {
      raise wrangler event "child_creation"
        attributes {
          "name": sensor_name,
          "color": "#d190a7",
          "rids": ["twilio_keys", "twilio", "temperature_store", "sensor_profile", "wovyn_base"]
        }
    }
  }

  rule store_new_sensor {
    select when wrangler child_initialized
    pre {
      sensor_name = event:attr("name")
      eci = event:attr("eci")
    }
    event:send({
      "eci": eci,
      "domain": "sensor",
      "type": "profile_updated",
      "attrs": {
        "name": sensor_name,
        "threshold": default_threshold,
        "notification_number": default_notification_number
      }
    })
    fired {
      ent:sensors{[sensor_name]} := eci
    }
  }

  rule delete_sensor {
    select when sensor sensor_unneeded
    pre {
      sensor_name = event:attr("sensor_name")
      exists = ent:sensors >< sensor_name
    }
    if exists then noop()
    fired {
      raise wrangler event "child_deletion"
        attributes {
          "name": sensor_name
        };
      clear ent:sensors{[sensor_name]}
    }
  }
}
