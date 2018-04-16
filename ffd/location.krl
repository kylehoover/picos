ruleset location {
  meta {
    use module google_keys
    provides get_random_location, calc_distance
    shares __testing, get_random_location, calc_distance
  }
  global {
    __testing = {}

    api_key = keys:google_keys{"key"};

    get_random_location = function () {
        latitude = random:number(rangeEnd = 90, rangeBegin = -90);
        longitude = random:number(rangeEnd = 180, rangeBegin = -180);
        latitude + "|" + longitude;
    }
    
    calc_distance = function (a, b) {
        url = <<https://maps.googleapis.com/maps/api/distancematrix/json?units=imperial&origins=#{a.replace(re#\,#\|)}&destinations=#{b}&key=#{api_key}>>;
        http:get(url);
    }
  }
}
