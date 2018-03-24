ruleset manage_sensors {
  meta {
    name "Manage Sensors"
    author "Kyle Hoover"
    use module manager_profile alias profile
    use module io.picolabs.subscription alias subscriptions
    use module io.picolabs.wrangler alias wrangler
    shares __testing, sensors, get_temps, reports
  }

  global {
    max_reports = 5
    default_threshold = 75
    default_notification_number = ""
    base_url = "http://35.185.50.186:8080/sky/cloud"

    sensors = function () {
      ent:sensors
    }

    reports = function () {
      ent:reports.defaultsTo({})
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
        {"name": "get_temps"},
        {"name": "reports"}
      ],
      "events": [
        {"domain": "sensor", "type": "new_sensor", "attrs": ["sensor_name"]},
        {"domain": "sensor", "type": "sensor_unneeded", "attrs": ["sensor_name"]},
        {"domain": "sensor", "type": "subscribe", "attrs": ["name", "eci", "host"]},
        {"domain": "collection", "type": "temp_report"}
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

  rule start_collection_temp_report {
    select when collection temp_report
    pre {
      report_id = ent:report_id.defaultsTo(1)
      new_report = {"temp_sensors": 0, "responding": 0, "temps": []}
    }
    fired {
      ent:reports := ent:reports.defaultsTo({});
      ent:reports{[report_id]} := new_report;
      ent:gathered := ent:gathered.defaultsTo({});
      ent:gathered{[report_id]} := [];
      ent:report_id := ent:report_id.defaultsTo(1) + 1;
      raise explicit event "temp_report_started"
        attributes {"report_id": report_id}
    }
  }

  rule scatter_temp_reports {
    select when explicit temp_report_started
    foreach subscriptions:established("Tx_role", "sensor") setting (sensor)
      pre {
        report_id = event:attr("report_id")
      }
      event:send({
        "eci": sensor{"Tx"},
        "domain": "sensor",
        "type": "temp_report",
        "attrs": {
          "report_id": report_id
        }
      })
      fired {
        ent:reports{[report_id, "temp_sensors"]} := ent:reports{[report_id, "temp_sensors"]} + 1
      }
  }

  rule gather_temp_reports {
    select when sensor temp_report_created
    pre {
      report_id = event:attr("report_id")
      rx = event:attr("rx")
      temps = event:attr("temps")
      gathered = ent:gathered{[report_id]}
      already_gathered = (gathered >< rx)
    }
    if not already_gathered then noop()
    fired {
      ent:gathered{[report_id]} := gathered.append(rx);
      ent:reports{[report_id, "responding"]} := gathered.length() + 1;
      ent:reports{[report_id, "temps"]} := ent:reports{[report_id, "temps"]}.append(temps)
    }
  }

  rule check_reports_size {
    select when explicit temp_report_started
    pre {
      num_reports = ent:reports.keys().length()
      delete_old_reports = num_reports > max_reports
      report_id_to_delete = ent:report_id - max_reports - 1
    }
    if delete_old_reports then noop()
    fired {
      ent:reports := ent:reports.delete([report_id_to_delete])
    }
  }
}
