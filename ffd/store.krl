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
        {"domain": "ffd", "type": "new_order"}
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
      ent:orders := {}; // uuid => {driver, distance, status} 
      ent:order_id := 0;
      ent:store_id := null
    }
  }
  
  rule save_name {
    select when ffd name_sent
    fired {
      ent:store_id := event:attr("name")
    }
  }
  
  rule process_order {
    select when ffd new_order
    pre {
      id = ent:order_id
    }
    fired {
      ent:orders{id} := {
        "driver": null,
        "distance": null,
        "status": "placed"
      };
      
      ent:order_id := id + 1;
      
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
  
  rule process_bid {
    select when ffd place_bid
    pre {
      // calc distance, possible replace current highest bidder
    }
  }
}
