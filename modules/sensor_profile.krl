ruleset sensor_profile {
  meta {
    name "Sensor Profile"
    author "Kyle Hoover"
    provides profile
    shares __testing, profile
  }

  global {
    profile = function () {
      {
        "name": ent:name,
        "location": ent:location,
        "threshold": ent:threshold,
        "notification_number": ent:notification_number
      }
    }

    __testing = {
      "queries": [
        {"name": "profile"}
      ],

      "events": [
        {"domain": "sensor", "type": "profile_updated", "attrs": ["name", "location", "threshold", "notification_number"]}
      ]
    }
  }

  rule init {
    select when wrangler ruleset_added where rids >< meta:rid
    fired {
      ent:name := "The Temp Sensor";
      ent:location := "The Living Room";
      ent:threshold := 75;
      ent:notification_number := ""
    }
  }

  rule update {
    select when sensor profile_updated
    pre {
      name = event:attr("name").defaultsTo(ent:name)
      location = event:attr("location").defaultsTo(ent:location)
      threshold = event:attr("threshold").defaultsTo(ent:threshold)
      not_num = event:attr("notification_number").defaultsTo(ent:notification_number)
    }
    // send_directive("here")
    fired {
      ent:name := name;
      ent:location := location;
      ent:threshold := threshold;
      ent:notification_number := not_num
    }
  }
}
