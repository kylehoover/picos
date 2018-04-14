ruleset driver {
  meta {
    shares __testing
  }
  
  global {
    __testing = {}
  }
  
  rule process_delivery_request {
    select when ffd delivery_requested
    pre {
      // randomly choose to send bid or not
    }
  }
  
  rule process_bid_accepted {
    select when ffd bid_accepted
    // send twilio sms
  }
}
