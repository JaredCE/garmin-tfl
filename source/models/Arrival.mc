import Toybox.Lang;

module BusNearMe {
    class Arrival {
        var line as String;          // e.g. "N29"
        var destination as String;   // e.g. "Trafalgar Square"
        var etaSeconds as Number;    // raw seconds from TfL

        function initialize(line as String, destination as String, etaSeconds as Number) {
            self.line = line;
            self.destination = destination;
            self.etaSeconds = etaSeconds;
        }

        // Returns display string: "Due", "1 min", "8 min" etc.
        function etaLabel() as String {
            if (self.etaSeconds < 60) {
                return "Due";
            }
            var mins = (self.etaSeconds / 60).toNumber();
            return mins + " min";
        }
    }
}
