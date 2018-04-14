ruleset registry {
  meta {
    shares __testing, drivers
  }
  
  global {
    __testing = {
      "queries": [
        {"name": "drivers"}
      ]
    }
    
    drivers = function () {
      ent:drivers
    }
    
    get_random_driver = function (ignore) {
      driver = ent:drivers[random:integer(ent:drivers.length() - 1)];
      driver == ignore => get_random_driver(ignore) | driver
    }
  }
  
  rule init {
    select when wrangler ruleset_added where rids >< meta:rid
    fired {
      ent:drivers := []
    }
  }
  
  rule register {
    select when ffd new_registration
    pre {
      is_driver = event:attr("is_driver")
      wellKnown_Rx = event:attr("wellKnown_Rx")
      make_connections = ent:drivers.length() > 0
    }
    if make_connections then noop()
    fired {
      raise explicit event "connections_requested"
        attributes {
          "eci": wellKnown_Rx,
          "is_driver": is_driver
        }
    } finally {
      ent:drivers := ent:drivers.append(wellKnown_Rx) if is_driver
    }
  }
  
  rule make_connections {
    select when explicit connections_requested
    pre {
      eci = event:attr("eci")
      is_driver = event:attr("is_driver")
      Rx_role = is_driver => "driver" | "store"
      connection = get_random_driver(eci)
    }
    event:send({
      "eci": eci,
      "domain": "wrangler",
      "type": "subscription",
      "attrs": {
        "name": "FFD Connection",
        "Rx_role": Rx_role,
        "Tx_role": "driver",
        "channel_type": "subscription",
        "wellKnown_Tx": connection
      }
    })
  }
}
