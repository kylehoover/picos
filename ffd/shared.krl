ruleset shared {
  meta {
    shares __testing
  }

  global {
    __testing = {}
    
    get_Rx = function () {
      engine:listChannels()
        .filter(function (channel) {
          channel{"name"} == "wellKnown_Rx"
        })
        .head(){"id"}
    }
  }
  
  rule init {
    select when wrangler ruleset_added where rids >< meta:rid
    fired {
      raise wrangler event "channel_creation_requested"
        attributes {
          "name": "system",
          "type": "comms"
        }
    }
  }
  
  rule auto_accept_ffd_subscriptions {
    select when wrangler inbound_pending_subscription_added
    pre {
      is_ffd_subscription = event:attr("name") == "FFD Connection"
    }
    if is_ffd_subscription then noop()
    fired {
      raise wrangler event "pending_subscription_approval"
        attributes event:attrs
    }
  }

  rule send_registration {
    select when ffd registry_eci_sent
    pre {
      registry_eci = event:attr("registry_eci")
      is_driver = event:attr("is_driver")
    }
    event:send({
      "eci": registry_eci,
      "domain": "ffd",
      "type": "new_registration",
      "attrs": {
        "is_driver": is_driver,
        "wellKnown_Rx": get_Rx()
      }
    })
  }
}
