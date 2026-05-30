import Toybox.Lang;

module BusNearMe {
    class Stop {
        var id as String;
        var name as String;
        var lat as Float;
        var lon as Float;
        var distance as Number; // metres

        function initialize(id as String, name as String, lat as Float, lon as Float, distance as Number) {
            self.id = id;
            self.name = name;
            self.lat = lat;
            self.lon = lon;
            self.distance = distance;
        }
    }
}
