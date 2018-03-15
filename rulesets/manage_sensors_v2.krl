ruleset manage_sensors {
  meta {
    name "Manage Sensors"
    author "Kyle Hoover"
    use module manager_profile alias profile
    use module io.picolabs.subscription alias subscriptions
    use module io.picolabs.wrangler alias wrangler
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
      subscriptions:established("Tx_role", "sensor")
        .map(function(subscription) {
          subscription{"Tx"}
        })
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
        {"domain": "sensor", "type": "sensor_unneeded", "attrs": ["sensor_name"]},
        {"domain": "sensor", "type": "subscribe", "attrs": ["name", "eci", "host"]}
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
          "rids": ["twilio_keys", "twilio", "temperature_store", "sensor_profile", "wovyn_base", "io.picolabs.subscription"]
        }
    }
  }

  rule handle_child_initialized {
    select when wrangler child_initialized
    pre {
      sensor_name = event:attr("name")
      sensor_eci = event:attr("eci")
      my_eci = wrangler:myself(){"eci"}
    }
    every {
      event:send({
        "eci": my_eci,
        "domain": "sensor",
        "type": "subscribe",
        "attrs": {
          "name": sensor_name,
          "eci": sensor_eci
        }
      })
      event:send({
        "eci": sensor_eci,
        "domain": "sensor",
        "type": "profile_updated",
        "attrs": {
          "name": sensor_name,
          "threshold": default_threshold,
          "notification_number": default_notification_number
        }
      })
    }
  }

  rule subscribe_new_sensor {
    select when sensor subscribe
    pre {
      sensor_name = event:attr("name")
      sensor_eci = event:attr("eci")
      sensor_host = event:attr("host").defaultsTo(null)
      my_eci = wrangler:myself(){"eci"}
    }
    event:send({
      "eci": my_eci,
      "domain": "wrangler",
      "type": "subscription",
      "attrs": {
        "name": sensor_name,
        "Rx_role": "manager",
        "Tx_role": "sensor",
        "channel_type": "subscription",
        "wellKnown_Tx": sensor_eci,
        "Tx_host": sensor_host
      }
    })
    fired {
      ent:sensors{[sensor_name]} := {
        "eci": sensor_eci,
        "host": sensor_host
      }
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

  rule handle_threshold_violation {
    select when sensor threshold_violation
    pre {
      temp = event:attr("temperature")
      timestamp = event:attr("timestamp")
      notification = <<Temperature threshold violation detected at #{timestamp}. Temp: #{temp} F>>
    }
    profile:send_notification(notification)
  }
}
