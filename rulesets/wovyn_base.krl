ruleset wovyn_base {
  meta {
    name "Wovyn Base"
    author "Kyle Hoover"
    use module cs_465.twilio alias twilio
    shares __testing
  }

  global {
    notification_number = "+18013807668"
    temperature_threshold = 80

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
    twilio:send_sms(
      notification_number,
      <<Temperature threshold violation detected at #{event:attr("timestamp")}. Temp: #{event:attr("temperature")} F>>
    ) setting(resp)
    always {
      log debug resp
    }
  }
}
