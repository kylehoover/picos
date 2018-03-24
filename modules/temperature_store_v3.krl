ruleset temperature_store {
  meta {
    name "Temperature Store"
    author "Kyle Hoover"
    use module io.picolabs.subscription alias subscriptions
    provides temperatures, threshold_violations, inrange_temperatures
    shares temperatures, threshold_violations, inrange_temperatures, __testing
  }

  global {
    temperatures = function () {
      ent:temps.defaultsTo([]).reverse()
    }

    threshold_violations = function () {
      ent:violations.defaultsTo([]).reverse()
    }

    inrange_temperatures = function () {
      ent:temps.defaultsTo([]).filter(function (temp) {
        ent:violations.defaultsTo([]).map(function (violation) {
          violation{"temperature"} == temp{"temperature"} &&
          violation{"timestamp"} == temp{"timestamp"}
        }).none(function (bool) {
          bool
        })
      }).reverse()
    }

    __testing = {
      "queries": [
        {"name": "temperatures"},
        {"name": "threshold_violations"},
        {"name": "inrange_temperatures"}
      ],
      "events": [
        {"domain": "sensor", "type": "reading_reset"},
        {"domain": "wovyn", "type": "fake_temperature_reading", "attrs": ["temp"]}
      ]
    }
  }

  rule collect_temperatures {
    select when wovyn new_temperature_reading
    fired {
      ent:temps := ent:temps.defaultsTo([]).append(event:attrs)
    }
  }

  rule collect_threshold_violations {
    select when wovyn threshold_violation
    fired {
      ent:violations := ent:violations.defaultsTo([]).append(event:attrs)
    }
  }

  rule clear_temperatures {
    select when sensor reading_reset
    fired {
      ent:temps := [];
      ent:violations := []
    }
  }

  rule add_fake_temp {
    select when wovyn fake_temperature_reading
    pre {
      temp = event:attr("temp")
    }
    fired {
      ent:temps := ent:temps.defaultsTo([]).append({
        "temperature": temp,
        "timestamp": time:now()
      })
    }
  }

  rule create_temp_report {
    select when sensor temp_report
    foreach subscriptions:established("Tx_role", "manager") setting(manager)
      pre {
        report_id = event:attr("report_id")
        rx = meta:eci.klog("<<< ECI >>>: ")
        isOriginator = manager{"Rx"} == rx
        temps = temperatures()
      }
      if isOriginator then
      event:send({
        "eci": manager{"Tx"},
        "domain": "sensor",
        "type": "temp_report_created",
        "attrs": {
          "report_id": report_id,
          "rx": rx,
          "temps": temps
        }
      })
  }
}
