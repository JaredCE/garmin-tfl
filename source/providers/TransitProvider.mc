import Toybox.Application;
import Toybox.Lang;

module BusNearMe {

    module ProviderResult {
        const SUCCESS       = 0;
        const ERROR_NETWORK = 1;
        const ERROR_AUTH    = 2;
        const ERROR_NODATA  = 3;
        const ERROR_PARSE   = 4;
    }

    // Static utility functions available to all providers
    module ProviderUtils {

        function getStringProperty(key as String) as String or Null {
            var val = Application.Properties.getValue(key);
            if (val == null || !(val instanceof String)) {
                return null;
            }
            var str = val as String;
            if (str.length() == 0) {
                return null;
            }
            return str;
        }

    }

    // Base class all providers extend
    class TransitProviderBase {

        function initialize() {}

        function fetchNearbyStops(
            lat      as Float,
            lon      as Float,
            radius   as Number,
            callback as Method
        ) as Void {}

        function fetchArrivals(stopId as String, callback as Method) as Void {}

    }

}
