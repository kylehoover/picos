ruleset store {
  meta {
    use module location
    use module io.picolabs.subscription alias subscriptions
    shares __testing
  }
  
  global {
    __testing = {}
    
    drivers = function () {
      subscriptions:established("Tx_role", "driver")
    }
  }
  
  rule init {
    select when wrangler ruleset_added where rids >< meta:rid
    fired {
      ent:location := location:get_random_location();
      ent:orders := {}; // uuid => {driver, distance, status} 
      ent:order_id := 0
    }
  }
  
  rule process_order {
    select when ffd new_order
    pre {
      id = ent:order_id
      status = "placed"
    }
    fired {
      ent:orders{id} := {
        "driver": null,
        "distance": null,
        "status": status
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
      pre {
        order_id = event:attr("order_id")
        // message: store_id, order_id, eci
      }
  }
  
  rule process_bid {
    select when ffd place_bid
    pre {
      // calc distance, possible replace current highest bidder
    }
  }
}
