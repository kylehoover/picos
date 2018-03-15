ruleset manager_profile {
  meta {
    name "Sensor Profile"
    author "Kyle Hoover"
    use module twilio
    provides send_notification
    shares __testing, send_notification
  }

  global {
    send_notification = defaction (msg) {
      resp = "No notification sent"
      if ent:notification_number then twilio:send_sms(ent:notification_number, msg) setting(resp)
      returns resp
    }

    __testing = {
      "events": [
        {"domain": "profile", "type": "update_number", "attrs": ["number"]}
      ]
    }
  }

  rule init {
    select when wrangler ruleset_added where rids >< meta:rid
    fired {
      ent:notification_number := ""
    }
  }

  rule update_notification_number {
    select when profile update_number
    pre {
      new_number = event:attr("number")
    }
    fired {
      ent:notification_number := new_number
    }
  }
}
