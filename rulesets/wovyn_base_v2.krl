ruleset wovyn_base {
  meta {
    name "Wovyn Base"
    author "Kyle Hoover"
    use module twilio
    use module sensor_profile
    shares __testing
  }

  global {
    __testing = {
      "events": [
        {"domain": "wovyn", "type": "heartbeat"}
      ]
    }
  }

  rule process_heartbeat {
    select when wovyn heartbeat genericThing re#.+#
    send_directive("processing heartbeat")
    fired {
      temp = event:attr("genericThing"){"data"}{"temperature"}[0]{"temperatureF"};
      raise wovyn event "new_temperature_reading"
        attributes {
          "temperature": temp,
          "timestamp": time:now()
        }
    }
  }

  rule find_high_temps {
    select when wovyn new_temperature_reading
    pre {
      temp = event:attr("temperature")
      temperature_threshold = sensor_profile:profile(){"threshold"}
      violation = temp > temperature_threshold
    }
    send_directive("looking for temperature violations", {"violation_occurred": violation})
    fired {
      raise wovyn event "threshold_violation"
        attributes event:attrs
        if violation
    }
  }

  rule threshold_notification {
    select when wovyn threshold_violation
    pre {
      number = sensor_profile:profile(){"notification_number"}
    }
    if number then twilio:send_sms(
      number,
      <<Temperature threshold violation detected at #{event:attr("timestamp")}. Temp: #{event:attr("temperature")} F>>
    )
  }
}
