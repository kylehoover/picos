ruleset driver {
  meta {
    use module location
    shares __testing, deliveries
  }
  
  global {
    __testing = {
      "queries": [
        {"name": "deliveries"}
      ]
    }
    
    deliveries = function () {
      ent:deliveries
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
      ent:deliveries := {};
      ent:driver_id := null
    }
  }
  
  // after registering, get caught up on missing delivery requests
  rule catch_up {
    select when wrangler subscription_added
    pre {
      is_new_driver = event:attr("status") == "outbound"
    }
    if is_new_driver then noop()
    fired {
      raise gossip event "seen_all_needed"
    }
  }
  
  rule process_delivery_request {
    select when ffd delivery_requested
    pre {
      send_bid = random:integer(1)
    }
    if send_bid then
      event:send({
        "eci": event:attr("eci"),
        "domain": "ffd",
        "type": "new_bid",
        "attrs": {
          "eci": get_eci(),
          "driver_id": ent:driver_id,
          "order_id": event:attr("order_id"),
          "location": location:get_random_location()
        }
      })
  }
  
  rule process_bid_accepted {
    select when ffd bid_accepted
    pre {
      order_id = event:attr("order_id")
      store_id = event:attr("store_id")
      add_store = ent:deliveries{store_id} == null
    }
    // send twilio sms
    fired {
      ent:deliveries{store_id} := {} if add_store;
      ent:deliveries{[store_id, order_id]} := {
        "eci": event:attr("eci"),
        "store_location": event:attr("store_location"),
        "delivery_location": event:attr("delivery_location"),
        "status": event:attr("status")
      }
    }
  }
  
  rule save_name {
    select when ffd name_sent
    fired {
      ent:driver_id := event:attr("name")
    }
  }
}
