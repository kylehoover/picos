ruleset pico_creator {
  meta {
    use module io.picolabs.wrangler alias wrangler
    shares __testing, get_registry_eci
  }

  global {
    mutual_rids = ["auto_subscribe", "location", "registration", "io.picolabs.subscription"]

    __testing = {
      "queries": [
        {"name": "get_registry_eci"}
      ],
      "events": [
        {"domain": "ffd", "type": "new_driver"},
        {"domain": "ffd", "type": "new_store"},
        {"domain": "ffd", "type": "new_registry"},
        {"domain": "explicit", "type": "reset"}
      ]
    }

    get_registry_eci = function () {
      wrangler:children()
        .filter(function (child) {
          child{"name"} == "Registry"
        })
        .head(){"eci"}
    }
  }

  rule init {
    select when wrangler ruleset_added where rids >< meta:rid
    fired {
      ent:driver_id := 0;
      ent:store_id := 0
    }
  }

  rule create_driver {
    select when ffd new_driver
    pre {
      id = ent:driver_id
      name = <<Driver_#{id}>>
      color = "#A4EBC4"
      rids = mutual_rids.append(["driver"])
    }
    fired {
      ent:driver_id := id + 1;
      raise wrangler event "child_creation"
        attributes {
          "name": name,
          "color": color,
          "rids": rids
        }
    }
  }
  
  rule create_registry {
    select when ffd new_registry
    pre {
      name = "Registry"
      color = "#D19EE3"
      rids = ["registry"]
    }
    fired {
      raise wrangler event "child_creation"
        attributes {
          "name": name,
          "color": color,
          "rids": rids
        }
    }
  }

  rule create_store {
    select when ffd new_store
    pre {
      id = ent:store_id
      name = <<Store_#{id}>>
      color = "#F7947B"
      rids = mutual_rids.append(["store"])
    }
    fired {
      ent:store_id := id + 1;
      raise wrangler event "child_creation"
        attributes {
          "name": name,
          "color": color,
          "rids": rids
        }
    }
  }

  rule send_registry_eci {
    select when wrangler child_initialized name re#Driver|Store#
    pre {
      name = event:attr("name")
      eci = event:attr("eci")
      is_driver = name.match(re#Driver#)
    }
    event:send({
      "eci": eci,
      "domain": "ffd",
      "type": "registry_eci_sent",
      "attrs": {
        "registry_eci": get_registry_eci(),
        "is_driver": is_driver
      }
    })
  }

  rule remove_picos {
    select when explicit reset
    foreach engine:listChildren() setting (picoId)
      pre {
        id = picoId
      }
      every {
        engine:removePico(picoId)
        send_directive(<<Removed #{id}>>)
      }
  }
  
  rule reset_entities {
    select when explicit reset
    send_directive("Reset entities")
    fired {
      ent:driver_id := 0;
      ent:store_id := 0
    }
  }
}
