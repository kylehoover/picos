ruleset wovyn_base {
  meta {
    name "Wovyn Base"
    author "Kyle Hoover"
    use module sensor_profile
    use module io.picolabs.subscription alias subscriptions
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

  rule threshold_violation {
    select when wovyn threshold_violation
    foreach subscriptions:established("Tx_role", "manager") setting(manager)
      pre {
        manager_eci = manager{"Tx"}
      }
      event:send({
        "eci": manager_eci,
        "domain": "sensor",
        "type": "threshold_violation",
        "attrs": event:attrs
      })
  }

  rule auto_accept_subscription {
    select when wrangler inbound_pending_subscription_added
    pre {
      attrs = event:attrs
    }
    fired {
      raise wrangler event "pending_subscription_approval"
        attributes attrs
    }
  }
}
