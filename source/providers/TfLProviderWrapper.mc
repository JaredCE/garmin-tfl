import Toybox.Lang;

module BusNearMe {

    class TfLProviderWrapper extends TransitProviderBase {

        function initialize() {
            TransitProviderBase.initialize();
        }

        function fetchNearbyStops(
            lat      as Float,
            lon      as Float,
            radius   as Number,
            callback as Method
        ) as Void {
            TfLProvider.fetchNearbyStops(lat, lon, radius, callback);
        }

        function fetchArrivals(stopId as String, callback as Method) as Void {
            TfLProvider.fetchArrivals(stopId, callback);
        }

    }

}
