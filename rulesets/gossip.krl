ruleset gossip {
  meta {
    name "Gossip"
    author "Kyle Hoover"
    use module io.picolabs.subscription alias subscriptions
    shares __testing, peers, create_rumor_message, create_seen_message,
      get_random_action, nodes, ent, get_new_seen_peer, get_rumor
  }

  global {
    __testing = {
      "queries": [
        {"name": "peers"},
        {"name": "nodes"},
        {"name": "ent"},
        {"name": "get_rumor", "args": ["originId", "sequence"]},
        {"name": "get_random_action"},
        {"name": "get_new_seen_peer"},
        {"name": "create_rumor_message"},
        {"name": "create_seen_message"}
      ],
      "events": [
        {"domain": "gossip", "type": "new_rumor"},
        {"domain": "gossip", "type": "fake_rumor", "attrs": ["sequence"]},
        {"domain": "gossip", "type": "new_seen"},
        {"domain": "gossip", "type": "interval_updated", "attrs": ["interval"]},
        {"domain": "gossip", "type": "peer_requested", "attrs": ["name", "eci", "host"]},
        {"domain": "gossip", "type": "peer_removed", "attrs": ["oid"]},
        {"domain": "gossip", "type": "node_removed", "attrs": ["oid"]}
      ]
    }

    ent = function () {
      {
        "interval": ent:interval,
        "sequence": ent:sequence,
        "newest_temp_reading": ent:newest_temp_reading,
        "my_rumors": ent:my_rumors
      }
    }

    nodes = function () {
      ent:nodes
    }

    peers = function () {
      ent:peers
    }

    nodes_peers_combined = function () {
      ent:peers.put(ent:nodes)
    }

    create_rumor_message = function () {
      m = {
        "messageId": <<#{meta:picoId}:#{ent:sequence + 1}>>,
        "sensorId": meta:picoId
      };
      m.put(ent:newest_temp_reading)
    }

    create_seen_message = function () {
      nodes_peers_combined().map(function (node, originId) {
        node{"highest"}
      })
    }

    get_peer_Tx = function (my_Rx) {
      subscriptions:established("Rx", my_Rx).head(){"Tx"}
    }

    get_random_action = function () {
      options = [{"type": "new_seen"}];
      options = options.append(ent:newest_temp_reading => {"type": "new_rumor"} | []);
      options[random:integer(options.length() - 1)]
    }

    // find peers who still need rumors we have already created
    old_rumors = function () {
      ent:peers.keys()
        .filter(function (originId) {
          ent:peers{[originId, "seen", meta:picoId]} < ent:sequence
        })
        .map(function (originId) {
          {"type": "old_rumor", "originId": originId}
        })
    }

    parse_message_id = function (m) {
      split = m.split(re#:#);
      {
        "originId": split[0],
        "sequence": split[1]
      }
    }

    already_seen = function (rumors, messageId) {
      rumors.filter(function (rumor) {
        rumor{"messageId"} == messageId
      }).length() > 0
    }

    get_random_peer = function (originIds) {
      index = random:integer(originIds.length() - 1);
      ent:peers{originIds[index]}
    }

    // randomly choose a peer who needs to be sent a seen message
    get_new_seen_peer = function () {
      nodes = nodes_peers_combined();
      options =
        ent:peers.filter(function (peer, originId) {
          peer{"seen"}.filter(function (sequence, seen_oid) {
            sequence > -1 &&
            seen_oid != meta:picoId &&
            (nodes{seen_oid} == null || nodes{[seen_oid, "highest"]} < sequence)
          }).length() > 0
        });

      options = options.length() > 0 => options.keys() | ent:peers.keys();
      get_random_peer(options)
    }

    get_rumor = function (originId, sequence) {
      nodes = nodes_peers_combined().put(meta:picoId, {"rumors": ent:my_rumors});
      nodes{[originId, "rumors"]}
        .filter(function (rumor) {
          rumor{"messageId"} == <<#{originId}:#{sequence}>>
        })
        .head()
    }
  }

  rule init {
    select when wrangler ruleset_added where rids >< meta:rid
    fired {
      ent:interval := 5;
      ent:sequence := -1;
      ent:newest_temp_reading := null;
      ent:nodes := {};
      ent:peers := {};
      ent:my_rumors := [];
      raise gossip event "schedule_heartbeat_requested"
    }
  }

  rule process_heartbeat {
    select when gossip heartbeat
    pre {
      action = get_random_action()
      has_peers = ent:peers.keys().length() > 0
    }
    if has_peers then noop()
    fired {
      raise gossip event action{"type"}
    } finally {
      raise gossip event "schedule_heartbeat_requested"
    }
  }

  rule send_new_rumor {
    select when gossip new_rumor
    pre {
      rumor = create_rumor_message()
      peer = get_random_peer(ent:peers.keys())
    }
    if rumor != null then
      event:send({
        "eci": peer{"Tx"},
        "domain": "gossip",
        "type": "rumor",
        "attrs": {
          "rumor": rumor
        }
      })
    fired {
      ent:sequence := ent:sequence + 1;
      ent:my_rumors := ent:my_rumors.append(rumor);
      ent:newest_temp_reading := null
    }
  }

  rule send_new_seen {
    select when gossip new_seen
    pre {
      seen = create_seen_message()
      peer = get_new_seen_peer()
    }
    event:send({
      "eci": peer{"Tx"},
      "domain": "gossip",
      "type": "seen",
      "attrs": {
        "originId": meta:picoId,
        "seen": seen
      }
    })
  }

  rule process_rumor {
    select when gossip rumor
    pre {
      rumor = event:attr("rumor")
      originId = parse_message_id(rumor{"messageId"}){"originId"}
      is_peer = ent:peers{originId} != null
      event_type = is_peer => "peer_rumor" | "node_rumor_received"
    }
    fired {
      raise gossip event event_type
        attributes event:attrs
    }
  }

  rule verify_node_exists {
    select when gossip node_rumor_received
    pre {
      originId = parse_message_id(event:attr("rumor"){"messageId"}){"originId"}
      exists = ent:nodes{originId} != null
      event_type = exists => "node_rumor" | "new_node"
    }
    fired {
      raise gossip event event_type
        attributes event:attrs
    }
  }

  rule add_node {
    select when gossip new_node
    pre {
      originId = parse_message_id(event:attr("rumor"){"messageId"}){"originId"}
    }
    fired {
      ent:nodes{originId} := {
        "highest": -1,
        "rumors": []
      };
      raise gossip event "node_rumor"
        attributes event:attrs
    }
  }

  rule process_node_rumor {
    select when gossip node_rumor
    pre {
      rumor = event:attr("rumor")
      parsed = parse_message_id(rumor{"messageId"})
      originId = parsed{"originId"}
      sequence = parsed{"sequence"}.as("Number")
      node = ent:nodes{originId}
      rumor_to_add = already_seen(node{"rumors"}, rumor{"messageId"}) => [] | rumor
      highest = node{"highest"} + 1 == sequence => sequence | node{"highest"}
    }
    fired {
      ent:nodes{[originId, "highest"]} := highest;
      ent:nodes{[originId, "rumors"]} := node{"rumors"}.append(rumor_to_add)
    }
  }

  rule process_peer_rumor {
    select when gossip peer_rumor
    pre {
      rumor = event:attr("rumor")
      parsed = parse_message_id(rumor{"messageId"})
      originId = parsed{"originId"}
      sequence = parsed{"sequence"}.as("Number")
      peer = ent:peers{originId}
      rumor_to_add = already_seen(peer{"rumors"}, rumor{"messageId"}) => [] | rumor
      highest = peer{"highest"} + 1 == sequence => sequence | peer{"highest"}
    }
    fired {
      ent:peers{[originId, "highest"]} := highest;
      ent:peers{[originId, "rumors"]} := peer{"rumors"}.append(rumor_to_add)
    }
  }



  rule process_seen {
    select when gossip seen
    pre {
      originId = event:attr("originId")
      seen = event:attr("seen")
    }
    fired {
      ent:peers{[originId, "seen"]} := seen;
      raise gossip event "seen_processed"
        attributes event:attrs
    }
  }

  rule find_my_missing_rumors {
    select when gossip seen_processed
    pre {
      oid = event:attr("originId")
      seen = event:attr("seen")
      missing = seen{meta:picoId} < ent:sequence
    }
    if missing then noop()
    fired {
      raise gossip event "found_missing_rumor"
        attributes {
          "sending_oid": oid,
          "missing_oid": meta:picoId,
          "seen": seen
        }
    }
  }

  rule find_missing_rumors {
    select when gossip seen_processed
    foreach nodes_peers_combined() setting (node, node_oid)
      pre {
        oid = event:attr("originId")
        seen = event:attr("seen")
        missing = node_oid != oid &&
                  node{"highest"} > -1 &&
                  (seen{node_oid} == null || seen{node_oid} < node{"highest"})
      }
      if missing then noop()
      fired {
        raise gossip event "found_missing_rumor"
          attributes {
            "sending_oid": oid,
            "missing_oid": node_oid,
            "seen": seen
          }
      }
  }

  rule prepare_missing_rumor {
    select when gossip found_missing_rumor
    pre {
      sending_oid = event:attr("sending_oid")
      missing_oid = event:attr("missing_oid")
      seen = event:attr("seen")
      missing_sequence = event:attr("missing_sequence") != null =>
        event:attr("missing_sequence") |
        (seen{missing_oid} == null => 0 | seen{missing_oid} + 1)
      missing_rumor = get_rumor(missing_oid, missing_sequence)
      more_missing_rumors = missing_sequence < nodes_peers_combined(){[missing_oid, "highest"]}
    }
    fired {
      raise gossip event "missing_rumor_prepared"
        attributes {
          "originId": sending_oid,
          "rumor": missing_rumor
        };
      raise gossip event "found_missing_rumor"
        attributes {
          "missing_sequence": missing_sequence + 1
        }.put(event:attrs)
        if more_missing_rumors
    }
  }

  rule send_missing_rumor {
    select when gossip missing_rumor_prepared
    pre {
      originId = event:attr("originId")
      rumor = event:attr("rumor")
      peer = ent:peers{originId}
    }
    event:send({
      "eci": peer{"Tx"},
      "domain": "gossip",
      "type": "rumor",
      "attrs": {
        "rumor": rumor
      }
    })
  }



  rule process_peer_requested {
    select when gossip peer_requested
    pre {
      peer_name = event:attr("name")
      peer_eci = event:attr("eci")
      peer_host = event:attr("host").defaultsTo(null)
    }
    fired {
      raise wrangler event "subscription"
        attributes {
          "Rx_role": "node",
          "Tx_role": "node",
          "channel_type": "subscription",
          "name": peer_name,
          "Tx_host": peer_host,
          "wellKnown_Tx": peer_eci,
          "originId": meta:picoId
        }
    }
  }

  rule process_subscription_added {
    select when wrangler subscription_added
    pre {
      is_peer_subscription = event:attr("Rx_role") == "node"
      originId = event:attr("originId")
      Rx = event:attr("Rx")
      Tx = get_peer_Tx(Rx)
    }
    if is_peer_subscription then
      event:send({
        "eci": Tx,
        "domain": "gossip",
        "type": "peer_added",
        "attrs": {
          "originId": meta:picoId,
          "Tx": Rx
        }
      })
    fired {
      raise gossip event "peer_added"
        attributes {
          "originId": originId,
          "Tx": Tx
        }
    }
  }

  rule add_peer {
    select when gossip peer_added
    pre {
      peerOriginId = event:attr("originId")
      myOriginId = meta:picoId
      Tx = event:attr("Tx")
      node = ent:nodes{peerOriginId}
      is_node = node != null
      highest = is_node => node{"highest"} | -1
      rumors = is_node => node{"rumors"} | []
    }
    fired {
      ent:peers{peerOriginId} := {
        "highest": highest,
        "rumors": rumors,
        "seen": {},
        "Tx": Tx
      };
      ent:peers{[peerOriginId, "seen", myOriginId]} := -1;
      ent:nodes := ent:nodes.delete([peerOriginId]) if is_node
    }
  }

  rule schedule_heartbeat {
    select when gossip schedule_heartbeat_requested
    fired {
      schedule gossip event "heartbeat" at time:add(time:now(), {"seconds": ent:interval})
    }
  }

  rule track_new_temp_readings {
    select when wovyn new_temperature_reading
    fired {
      ent:newest_temp_reading := event:attrs
    }
  }

  rule update_interval {
    select when gossip interval_updated
    foreach schedule:list() setting (scheduled_event)
      pre {
        interval = event:attr("interval")
        scheduled_event_id = scheduled_event{"id"}
      }
      schedule:remove(scheduled_event_id)
      fired {
        ent:interval := interval on final;
        raise gossip event "schedule_heartbeat_requested" on final
      }
  }

  rule fake_rumor {
    select when gossip fake_rumor
    pre {
      originId = ent:peers.keys().head()
      sequence = event:attr("sequence")
      rumor = {
        "messageId": <<#{originId}:#{sequence}>>,
        "sensorId": originId,
        "temperature": 22,
        "timestamp": time:now()
      }
    }
    fired {
      raise gossip event "rumor"
        attributes {
          "rumor": rumor
        }
    }
  }

  rule remove_peer {
    select when gossip peer_removed
    pre {
      oid = event:attr("oid")
    }
    fired {
      ent:peers := ent:peers.delete([oid])
    }
  }

  rule remove_node {
    select when gossip node_removed
    pre {
      oid = event:attr("oid")
    }
    fired {
      ent:nodes := ent:nodes.delete([oid])
    }
  }
}
