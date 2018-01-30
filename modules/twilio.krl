ruleset cs_465.twilio {
  meta {
    use module cs_465.twilio_keys
    provides messages, send_sms
  }

  global {
    get_base_url = function() {
      account_sid = keys:twilio{"account_sid"};
      auth_token = keys:twilio{"auth_token"};
      <<https://#{account_sid}:#{auth_token}@api.twilio.com/2010-04-01/Accounts/#{account_sid}/>>
    }

    messages = function(to, from, page_size) {
      qp = "?" +
           (to => <<To=#{to}&>> | "") +
           (from => <<From=#{from}&>> | "") +
           (page_size => <<PageSize=#{page_size}>> | "");
      url = get_base_url() + "Messages.json" + qp;
      resp = http:get(url){"content"}.decode(){"messages"};
      resp
    }

    send_sms = defaction(to, from, message) {
      url = get_base_url() + "Messages.json"
      http:post(url, form = {
        "From": from,
        "To": to,
        "Body": message
      }) setting(resp)
      returns resp
    }
  }
}