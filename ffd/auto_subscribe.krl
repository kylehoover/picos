ruleset auto_subscribe {
  meta {
    shares __testing
  }
  
  global {
    __testing = {}
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
}
