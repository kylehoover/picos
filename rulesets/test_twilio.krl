ruleset test_twilio {
  meta {
    use module twilio
    share __testing, test_messages
  }

  global {
    __testing = {
      "events": [
        {"domain": "sms", "type": "send", "attrs": ["to", "message"]}
      ],
      "queries": [
        {"name": "test_messages", "args": ["to", "from", "page_size"]}
      ]
    }

    test_messages = function(to, from, page_size) {
      twilio:messages(to, from, page_size)
    }
  }

  rule test_send_sms {
    select when sms send
    twilio:send_sms(
      event:attr("to"),
      event:attr("message")
    ) setting(resp)
    always {
      resp.klog("resp: ")
    }
  }
}
