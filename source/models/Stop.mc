import Toybox.Lang;

module BusNearMe {
    class Stop {
        var id          as String;
        var name        as String;
        var indicator   as String;  // e.g. "Stop C", "Stop F"
        var lat         as Float;
        var lon         as Float;
        var distance    as Number;

        function initialize(
            id        as String,
            name      as String,
            indicator as String,
            lat       as Float,
            lon       as Float,
            distance  as Number
        ) {
            self.id        = id;
            self.name      = name;
            self.indicator = indicator;
            self.lat       = lat;
            self.lon       = lon;
            self.distance  = distance;
        }
    }
}
