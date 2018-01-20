ruleset hello_world {
  meta {
    name "Hello World"
    description <<
      A first ruleset for the Quickstart
    >>
    author "Kyle Hoover"
    logging on
    shares hello, __testing
  }

  global {
    hello = function (obj) {
      msg = "Hello" + obj;
      msg
    }

    __testing = {
      "queries": [
        {"name": "hello", "args": ["obj"]},
        {"name": "__testing"}
      ],
      "events": [
        {"domain": "echo", "type": "hello", "attrs": ["name"]},
        {"domain": "echo", "type": "monkey", "attrs": ["name"]}
      ]
    }
  }

  rule hello_world {
    select when echo hello
    pre {
      name = event:attr("name").klog("the passed in name: ")
    }
    send_directive("say", {"something": "Hello " + name})
  }

  rule echo_monkey {
    select when echo monkey
    pre {
      name = event:attr("name").defaultsTo("Monkey").klog("value used for name: ")
    }
    send_directive("Hello " + name)
  }

  rule echo_monkey_ternary {
    select when echo monkey
    pre {
      name = event:attr("name") => event:attr("name") | "Monkey"
    }
    send_directive("Hello " + name)
  }
}
