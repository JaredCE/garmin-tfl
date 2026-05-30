import Toybox.Communications;
import Toybox.Lang;

module BusNearMe {
    // Handles the makeWebRequest response for stops
    // Holds the upstream callback as instance state instead of using bind()
    class StopsResponseHandler {
        var _callback as Method;

        function initialize(callback as Method) {
            _callback = callback;
        }

        function onResponse(responseCode as Number, data as Dictionary or String or Null) as Void {
            if (responseCode != 200) {
                var result = (responseCode == 401 || responseCode == 403)
                    ? ProviderResult.ERROR_AUTH
                    : ProviderResult.ERROR_NETWORK;
                _callback.invoke(result, null);
                return;
            }

            if (data == null || !(data instanceof Dictionary)) {
                _callback.invoke(ProviderResult.ERROR_PARSE, null);
                return;
            }

            var stops = TfLProvider.parseStops(data as Dictionary);
            if (stops == null) {
                _callback.invoke(ProviderResult.ERROR_PARSE, null);
                return;
            }

            _callback.invoke(ProviderResult.SUCCESS, stops);
        }
    }

    // Handles the makeWebRequest response for arrivals
    class ArrivalsResponseHandler {
        var _callback as Method;

        function initialize(callback as Method) {
            _callback = callback;
        }

        function onResponse(responseCode as Number, data as Dictionary or String or Null) as Void {
            if (responseCode != 200) {
                var result = (responseCode == 401 || responseCode == 403)
                    ? ProviderResult.ERROR_AUTH
                    : ProviderResult.ERROR_NETWORK;
                _callback.invoke(result, null);
                return;
            }

            if (data == null) {
                _callback.invoke(ProviderResult.ERROR_PARSE, null);
                return;
            }

            // Garmin types this as Dictionary but TfL returns a JSON array
            // which deserialises as Array at runtime — suppress via Object cast
            var rawData = data as Object;
            var arrivals = TfLProvider.parseArrivals(rawData as Array);
            if (arrivals == null) {
                _callback.invoke(ProviderResult.ERROR_PARSE, null);
                return;
            }

            _callback.invoke(ProviderResult.SUCCESS, arrivals);
        }
    }

    module TfLProvider {

        // Base URL — swap this out for a different city's API
        const BASE_URL = "https://api.tfl.gov.uk";

        // Fetch stops within radius metres of lat/lon
        // Only returns bus/coach/tram stops
        function fetchNearbyStops(
            lat      as Float,
            lon      as Float,
            radius   as Number,
            callback as Method
        ) as Void {

            var key = ProviderUtils.getStringProperty("tflAppKey");
            if (key == null) {
                callback.invoke(ProviderResult.ERROR_AUTH, null);
                return;
            }

            // Format lat/lon to 6 decimal places as strings
            // Garmin serialises floats unpredictably in query params — explicit strings are safer
            var latStr = lat.format("%.6f");
            var lonStr = lon.format("%.6f");

            var url = BASE_URL + "/StopPoint" +
                "?lat=" + latStr +
                "&lon=" + lonStr +
                "&radius=" + radius.toString() +
                "&stopTypes=NaptanPublicBusCoachTram" +
                "&useStopPointHierarchy=false" +
                "&returnLines=false";

            // Append key directly in URL — avoids any param serialisation issues
            if (key != null) {
                url = url + "&app_key=" + key;
            }

            var options = {
                :method       => Communications.HTTP_REQUEST_METHOD_GET,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            };

            // Pass null for params — everything is already in the URL
            var handler = new StopsResponseHandler(callback);
            Communications.makeWebRequest(
                url,
                null,
                options,
                handler.method(:onResponse)
            );
        }

        // Fetch arrivals for a given stop ID
        function fetchArrivals(stopId as String, callback as Method) as Void {

            var key = ProviderUtils.getStringProperty("tflAppKey");
            if (key == null) {
                callback.invoke(ProviderResult.ERROR_AUTH, null);
                return;
            }

            var url = BASE_URL + "/StopPoint/" + stopId + "/Arrivals" +
                "?app_key=" + key;

            var options = {
                :method       => Communications.HTTP_REQUEST_METHOD_GET,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            };

            var handler = new ArrivalsResponseHandler(callback);
            Communications.makeWebRequest(
                url,
                null,
                options,
                handler.method(:onResponse)
            );
        }

        // --- Private response handlers ---

        // Callback from makeWebRequest for stops
        // signature required by Garmin: (responseCode, data)
        // we prepend the upstream callback via bind above
        function onStopsResponse(
            callback     as Method,
            responseCode as Number,
            data         as Dictionary or Null
        ) as Void {

            if (responseCode != 200) {
                var result = (responseCode == 401 || responseCode == 403)
                    ? ProviderResult.ERROR_AUTH
                    : ProviderResult.ERROR_NETWORK;
                callback.invoke(result, null);
                return;
            }

            if (data == null) {
                callback.invoke(ProviderResult.ERROR_PARSE, null);
                return;
            }

            var stops = parseStops(data);
            if (stops == null) {
                callback.invoke(ProviderResult.ERROR_PARSE, null);
                return;
            }

            callback.invoke(ProviderResult.SUCCESS, stops);
        }

        // Callback from makeWebRequest for arrivals
        function onArrivalsResponse(
            callback     as Method,
            responseCode as Number,
            data         as Array or Null
        ) as Void {

            if (responseCode != 200) {
                var result = (responseCode == 401 || responseCode == 403)
                    ? ProviderResult.ERROR_AUTH
                    : ProviderResult.ERROR_NETWORK;
                callback.invoke(result, null);
                return;
            }

            if (data == null) {
                callback.invoke(ProviderResult.ERROR_PARSE, null);
                return;
            }

            var arrivals = parseArrivals(data);
            if (arrivals == null) {
                callback.invoke(ProviderResult.ERROR_PARSE, null);
                return;
            }

            callback.invoke(ProviderResult.SUCCESS, arrivals);
        }

        // --- Private parsers ---

        function parseStops(data as Dictionary) as Array or Null {
            if (!data.hasKey("stopPoints")) {
                return null;
            }

            var rawStops = data["stopPoints"] as Array;
            var stops = [] as Array<Stop>;

            for (var i = 0; i < rawStops.size() && i < 10; i++) {
                var raw = rawStops[i] as Dictionary;

                if (!raw.hasKey("id") || !raw.hasKey("commonName") ||
                    !raw.hasKey("lat") || !raw.hasKey("lon")) {
                    continue;
                }

                // indicator may be absent for some stop types
                var indicator = "";
                if (raw.hasKey("indicator") && raw["indicator"] != null) {
                    indicator = raw["indicator"].toString();
                }

                var stop = new Stop(
                    raw["id"].toString(),
                    raw["commonName"].toString(),
                    indicator,
                    (raw["lat"] as Float).toFloat(),
                    (raw["lon"] as Float).toFloat(),
                    raw.hasKey("distance") ? (raw["distance"] as Number).toNumber() : 0
                );

                stops.add(stop);
            }

            return stops;
        }

        function parseArrivals(data as Array) as Array<Arrival> or Null {
            // TfL arrivals is a flat array:
            // [ { "lineName", "destinationName", "timeToStation" }, ... ]
            var arrivals = [] as Array<Arrival>;

            for (var i = 0; i < data.size() && i < 20; i++) {
                var raw = data[i] as Dictionary;

                if (!raw.hasKey("lineName") || !raw.hasKey("destinationName") ||
                    !raw.hasKey("timeToStation")) {
                    continue;
                }

                var arrival = new Arrival(
                    raw["lineName"].toString(),
                    raw["destinationName"].toString(),
                    (raw["timeToStation"] as Number).toNumber()
                );

                arrivals.add(arrival);
            }

            // Sort by ETA ascending — simple bubble sort (no lambdas in Monkey C)
            for (var i = 0; i < arrivals.size() - 1; i++) {
                for (var j = 0; j < arrivals.size() - 1 - i; j++) {
                    if ((arrivals[j] as Arrival).etaSeconds > (arrivals[j + 1] as Arrival).etaSeconds) {
                        var tmp = arrivals[j];
                        arrivals[j] = arrivals[j + 1];
                        arrivals[j + 1] = tmp;
                    }
                }
            }

            arrivals = deduplicateArrivals(arrivals);
            return arrivals;
        }

        // Collapses multiple arrivals for the same line+destination into one,
        // keeping the first (earliest) as the representative row.
        // The full sorted array is still passed to buildEtaLabel for ETA collection.
        function deduplicateArrivals(arrivals as Array) as Array {
            var seen = [] as Array<String>;
            var deduped = [] as Array<Arrival>;

            for (var i = 0; i < arrivals.size(); i++) {
                var a = arrivals[i] as Arrival;
                var key = a.line + "|" + a.destination;

                var found = false;
                for (var j = 0; j < seen.size(); j++) {
                    if ((seen[j] as String).equals(key)) {
                        found = true;
                        break;
                    }
                }

                if (!found) {
                    seen.add(key);
                    deduped.add(a);
                }

                // Cap deduplicated list at 8 unique services
                if (deduped.size() >= 8) {
                    break;
                }
            }

            return deduped;
        }



    }
}
