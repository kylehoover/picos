ruleset registration {
  meta {
    shares __testing
  }

  global {
    __testing = {
      "queries": [
      ]
    }

    get_Rx = function () {
      engine:listChannels()
        .filter(function (channel) {
          channel{"name"} == "wellKnown_Rx"
        })
        .head(){"id"}
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
