ruleset store {
  meta {
    use module location
    use module io.picolabs.subscription alias subscriptions
    shares __testing, orders
  }
  
  global {
    __testing = {
      "queries": [
        {"name": "orders"}
      ],
      "events": [
        {"domain": "ffd", "type": "new_order"},
        {"domain": "store", "type": "wait_time_updated", "attrs": ["wait_time"]}
      ]
    }
    
    drivers = function () {
      subscriptions:established("Tx_role", "driver")
        .map(function (driver) {
          driver{"Tx"}
        })
    }
    
    orders = function () {
      ent:orders
    }
    
    get_eci = function () {
      engine:listChannels()
        .filter(function (channel) {
          channel{"name"} == "system" && channel{"type"} == "comms"
        })
        .head(){"id"}
    }
  }
  
  rule init {
    select when wrangler ruleset_added where rids >< meta:rid
    fired {
      ent:location := location:get_random_location();
      ent:orders := {}; // order_id => {driver_id, distance, location, eci, status} 
      ent:order_id := 0;
      ent:store_id := null;
      ent:wait_time := 5
    }
  }
  
  rule process_order {
    select when ffd new_order
    pre {
      id = ent:order_id
    }
    fired {
      ent:order_id := id + 1;
      ent:orders{id} := {
        "location": location:get_random_location(),
        "status": "accepting_bids"
      };
      
      raise explicit event "delivery_needed"
        attributes {
          "order_id": id
        }
    }
  }
  
  rule send_delivery_requests {
    select when explicit delivery_needed
    foreach drivers() setting(driver)
      event:send({
        "eci": driver,
        "domain": "ffd",
        "type": "delivery_requested",
        "attrs": {
          "eci": get_eci(),
          "order_id": event:attr("order_id"),
          "store_id": ent:store_id
        }
      })
  }
  
  rule set_collecting_bids_timeout {
    select when explicit delivery_needed
    fired {
      schedule explicit event "collecting_bids_timed_out"
        at time:add(time:now(), {"seconds": ent:wait_time})
        attributes {
          "order_id": event:attr("order_id")
        }
    }
  }
  
  rule process_bid {
    select when ffd new_bid
    pre {
      eci = event:attr("eci")
      driver_id = event:attr("driver_id")
      location = event:attr("location")
      order_id = event:attr("order_id")
      order = ent:orders{order_id}
      distance = random:integer(20)
      // distance = location:calc_distance(location, ent:location)
      better_bid = order{"status"} == "accepting_bids" &&
                   (order{"driver_id"} == null || distance < order{"distance"})
    }
    if better_bid then noop()
    fired {
      ent:orders{order_id} := {
        "driver_id": driver_id,
        "distance": distance,
        "eci": eci,
        "status": order{"status"}
      }
    }
  }
  
  rule check_bids {
    select when explicit collecting_bids_timed_out
    pre {
      order_id = event:attr("order_id")
      bids_collected = ent:orders{[order_id, "driver_id"]} != null
    }
    if bids_collected then noop()
    fired {
      ent:orders{[order_id, "status"]} := "out_for_delivery";
      raise ffd event "notify_driver_needed"
        attributes {
          "order_id": order_id
        }
    } else {
      raise explicit event "delivery_needed"
        attributes {
          "order_id": order_id
        }
    }
  }
  
  rule notify_driver {
    select when ffd notify_driver_needed
    pre {
      order_id = event:attr("order_id")
      eci = ent:orders{[order_id, "eci"]}
      delivery_location = ent:orders{[order_id, "location"]}
    }
    event:send({
      "eci": eci,
      "domain": "ffd",
      "type": "bid_accepted",
      "attrs": {
        "eci": get_eci(),
        "order_id": order_id,
        "store_id": ent:store_id,
        "store_location": ent:location,
        "delivery_location": delivery_location,
        "status": "out_for_delivery"
      }
    })
  }
  
  rule save_name {
    select when ffd name_sent
    fired {
      ent:store_id := event:attr("name")
    }
  }
  
  rule update_wait_time {
    select when store wait_time_updated
    fired {
      ent:wait_time := event:attr("wait_time")
    }
  }
}
