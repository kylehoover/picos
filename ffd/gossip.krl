ruleset gossip {
  meta {
    use module io.picolabs.subscription alias subscriptions
    shares __testing, stores, get_seen
  }
  
  global {
    __testing = {
      "queries": [
        {"name": "stores"},
        {"name": "get_seen"}
      ],
      "events": [
        {"domain": "gossip", "type": "interval_updated", "attrs": ["interval"]}
      ]
    }
    
    stores = function () {
      ent:stores
    }
    
    already_seen = function (store_id, order_id) {
      ent:stores{[store_id, "requests"]}
        .any(function (request) {
          request{"order_id"} == order_id
        })
    }
    
    connected_drivers = function () {
      subscriptions:established("Tx_role", "driver")
        .map(function (driver) {
          driver{"Tx"}
        })
    }
    
    get_delivery_request = function(store_id, order_id) {
      ent:stores{[store_id, "requests"]}
        .filter(function (request) {
          request{"order_id"} == order_id
        })
        .head()
    }
    
    get_seen = function () {
      ent:stores.map(function (driver) {
        driver{"highest"}
      })
    }
    
    get_Tx = function (Rx) {
      subscriptions:established("Rx", Rx).head(){"Tx"}
    }
  }
  
  rule init {
    select when wrangler ruleset_added where rids >< meta:rid
    fired {
      ent:interval := 10;
      ent:stores := {}
      // raise gossip event "schedule_heartbeat_requested"
    }
  }
  
  rule process_heartbeat {
    select when gossip heartbeat
    fired {
      raise gossip event "seen_all_needed";
      raise gossip event "schedule_heartbeat_requested"
    }
  }
  
  rule process_delivery_request {
    select when ffd delivery_requested
    pre {
      store_exists = ent:stores{event:attr("store_id")} != null
    }
    if store_exists then noop()
    fired {
      raise explicit event "new_delivery_request"
        attributes event:attrs
    } else {
      raise explicit event "new_store"
        attributes event:attrs
    }
  }
  
  rule add_store {
    select when explicit new_store
    pre {
      store_id = event:attr("store_id")
    }
    fired {
      ent:stores{store_id} := {
        "highest": -1,
        "requests": []
      };
      
      raise explicit event "new_delivery_request"
        attributes event:attrs
    }
  }
  
  rule save_delivery_request {
    select when explicit new_delivery_request
    pre {
      order_id = event:attr("order_id")
      store_id = event:attr("store_id")
      requests = ent:stores{[store_id, "requests"]}
      cur_highest = ent:stores{[store_id, "highest"]}
      new_highest = cur_highest + 1 == order_id => order_id | cur_highest
    }
    if not already_seen(store_id, order_id) then noop()
    fired {
      ent:stores{[store_id, "requests"]} := requests.append(event:attrs);
      raise gossip event "seen_all_needed"
    } finally {
      ent:stores{[store_id, "highest"]} := new_highest
    }
  }
  
  rule send_seen {
    select when gossip seen_needed
    event:send({
      "eci": event:attr("eci"),
      "domain": "gossip",
      "type": "new_seen",
      "attrs": {
        "seen": get_seen()
      }
    })
  }
  
  rule send_seen_all {
    select when gossip seen_all_needed
    foreach connected_drivers() setting(driver)
      fired{
        raise gossip event "seen_needed"
          attributes {
            "eci": driver
          }
      }
  }
  
  // find and send delivery requests that the sending driver is missing
  rule send_missing_requests {
    select when gossip new_seen
    foreach ent:stores setting(store, store_id)
      pre {
        seen = event:attr("seen")
        missing_order_id = seen{store_id} == null => 0 | seen{store_id} + 1
        missing = missing_order_id <= store{"highest"}
      }
      if missing then
        event:send({
          "eci": get_Tx(meta:eci),
          "domain": "ffd",
          "type": "delivery_requested",
          "attrs": get_delivery_request(store_id, missing_order_id)
        })
  }
  
  // find delivery requests that the sending driver has that I need, send seen to get them
  rule find_needed_requests {
    select when gossip new_seen
    pre {
      seen = event:attr("seen")
      needed = seen.keys().any(function (store_id) {
        ent:stores{store_id} == null || seen{store_id} > ent:stores{[store_id, "highest"]}
      })
    }
    if needed then noop()
    fired {
      raise gossip event "seen_needed"
        attributes {
          "eci": get_Tx(meta:eci)
        }
    }
  }
  
  rule schedule_heartbeat {
    select when gossip schedule_heartbeat_requested
    fired {
      schedule gossip event "heartbeat" at time:add(time:now(), {"minutes": ent:interval})
    }
  }
  
  rule update_interval {
    select when gossip interval_updated
    fired {
      ent:interval := event:attr("interval")
    }
  }
}
