ruleset temperature_store {
  meta {
    name "Temperature Store"
    author "Kyle Hoover"
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
        {"domain": "sensor", "type": "reading_reset"}
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
}
