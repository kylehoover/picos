ruleset location {
  meta {
    use module google_keys
    provides get_random_location, calc_distance
    shares __testing, get_random_location, calc_distance
  }
  
  global {
    __testing = {
      "queries": [
        {"name": "get_random_location"},
        {"name": "calc_distance", "args": ["a", "b"]}
      ]
    }

    api_key = keys:google{"key"}

    get_random_location = function () {
      // Salt Lake City
      latitude = random:number(40.8, 40.6);
      longitude = random:number(-111.8, -112);
      latitude + "," + longitude
    }
    
    calc_distance = function (a, b) {
      url = <<https://maps.googleapis.com/maps/api/distancematrix/json?units=imperial&origins=#{a}&destinations=#{b}&key=#{api_key}>>;
      http:get(url){"content"}.decode(){"rows"}.head(){"elements"}.head(){["distance", "value"]}
    }
  }
}
