import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

module BusNearMe {

    class AppView extends WatchUi.View {

        // Scroll index for stop list and arrivals list
        var scrollIndex as Number = 0;

        function initialize() {
            View.initialize();
        }

        function onUpdate(dc as Graphics.Dc) as Void {
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            dc.clear();

            var controller = getApp().controller;

            switch (controller.state) {
                case AppState.GPS:
                    drawCentered(dc, WatchUi.loadResource(Rez.Strings.Loading) as String);
                    break;
                case AppState.FETCHING_STOPS:
                    drawCentered(dc, WatchUi.loadResource(Rez.Strings.FetchingStops) as String);
                    break;
                case AppState.FETCHING_ARRIVALS:
                    drawCentered(dc, WatchUi.loadResource(Rez.Strings.FetchingArrivals) as String);
                    break;
                case AppState.STOPS:
                    drawStops(dc, controller.stops as Array, controller.scrollIndex);
                    break;
                case AppState.ARRIVALS:
                    drawArrivals(dc, controller.arrivals as Array, controller.selectedStop as Stop, controller.scrollIndex);
                    break;
                case AppState.ERROR:
                    drawError(dc, controller.errorMsg as String);
                    break;
            }
        }

        // --- Loading / error screens ---

        function drawCentered(dc as Graphics.Dc, msg as String) as Void {
            var w = dc.getWidth();
            var h = dc.getHeight();
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                w / 2, h / 2,
                Graphics.FONT_MEDIUM,
                msg,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }

        function drawError(dc as Graphics.Dc, msg as String) as Void {
            var w = dc.getWidth();
            var h = dc.getHeight();

            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                w / 2, (h / 2) - 20,
                Graphics.FONT_MEDIUM,
                msg,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );

            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                w / 2, (h / 2) + 20,
                Graphics.FONT_SMALL,
                WatchUi.loadResource(Rez.Strings.Refresh) as String,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }

        // --- Stop list ---

        function drawStops(dc as Graphics.Dc, stops as Array, scrollIndex as Number) as Void {
            var w  = dc.getWidth();   // 260
            var h  = dc.getHeight();  // 260
            var cx = w / 2;           // 130

            // Safe zone on a 260px circle:
            // Top safe y  ~ 40px  (narrow band, keep text short and centred tightly)
            // Bottom safe ~ 220px
            // At y=40, usable width ~ 200px

            var rowHeight   = 46;
            var visibleRows = 3;    // reduced from 4 — gives more vertical breathing room
            var listTop     = 52;   // start rows well inside the safe zone

            // Header — centred, short, sits in the narrow top band
            dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                cx, 36,
                Graphics.FONT_XTINY,
                "NEARBY STOPS",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );

            // Thin divider under header
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(60, 46, w - 60, 46);

            // Clamp scroll
            var maxScroll = stops.size() - visibleRows;
            if (maxScroll < 0) { maxScroll = 0; }
            var clampedIndex = scrollIndex;
            if (clampedIndex > maxScroll) { clampedIndex = maxScroll; }
            if (clampedIndex < 0)         { clampedIndex = 0; }

            for (var i = 0; i < visibleRows && (i + clampedIndex) < stops.size(); i++) {
                var stop       = stops[i + clampedIndex] as Stop;
                var y          = listTop + (i * rowHeight);
                var isSelected = (i + clampedIndex) == scrollIndex;
                var isLast     = (i + clampedIndex) == stops.size() - 1;

                drawStopRow(dc, stop, y, w, isSelected, isLast);
            }

            // Scroll hint at bottom — sits at safe y~215
            if (stops.size() > visibleRows) {
                drawScrollDots(dc, stops.size(), visibleRows, clampedIndex, w, 224);
            }

            // Press START hint
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                cx, 238,
                Graphics.FONT_XTINY,
                "START to select",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }


        function drawStopRow(
            dc         as Graphics.Dc,
            stop       as Stop,
            y          as Number,
            w          as Number,
            isSelected as Boolean,
            isLast     as Boolean
        ) as Void {
            var cx = w / 2;

            // At y~52-190, safe usable width is roughly 220px, so margins of ~20px each side
            var marginX = 22;

            // Highlight selected row
            if (isSelected) {
                dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_BLUE);
                dc.fillRectangle(marginX, y - 2, w - (marginX * 2), 42);
            }

            // Truncate stop name to fit safe width (~20 chars at FONT_SMALL)
            var name = stop.name;
            if (name.length() > 20) {
                name = name.substring(0, 18) + "..";
            }

            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                cx, y + 8,
                Graphics.FONT_SMALL,
                name,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );

            // Distance sub-label
            dc.setColor(isSelected ? Graphics.COLOR_WHITE : Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                cx, y + 26,
                Graphics.FONT_XTINY,
                stop.distance + "m",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );

            // Divider
            if (!isLast && !isSelected) {
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(50, y + 42, w - 50, y + 42);
            }
        }

        // --- Arrivals list ---

        function drawArrivals(
            dc          as Graphics.Dc,
            arrivals    as Array,
            stop        as Stop,
            scrollIndex as Number
        ) as Void {
            var w  = dc.getWidth();
            var h  = dc.getHeight();
            var cx = w / 2;

            var rowHeight   = 48;
            var visibleRows = 3;
            var listTop     = 52;

            // Stop name header
            var headerName = stop.name;
            if (headerName.length() > 18) {
                headerName = headerName.substring(0, 16) + "..";
            }

            dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                cx, 36,
                Graphics.FONT_XTINY,
                headerName,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );

            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(60, 46, w - 60, 46);

            if (arrivals.size() == 0) {
                drawCentered(dc, WatchUi.loadResource(Rez.Strings.NoArrivals) as String);
                return;
            }

            var maxScroll = arrivals.size() - visibleRows;
            if (maxScroll < 0) { maxScroll = 0; }
            var clampedIndex = scrollIndex;
            if (clampedIndex > maxScroll) { clampedIndex = maxScroll; }
            if (clampedIndex < 0)         { clampedIndex = 0; }

            for (var i = 0; i < visibleRows && (i + clampedIndex) < arrivals.size(); i++) {
                var arrival = arrivals[i + clampedIndex] as Arrival;
                var y       = listTop + (i * rowHeight);
                var isLast  = (i + clampedIndex) == arrivals.size() - 1;

                drawArrivalRow(dc, arrival, arrivals, y, w, isLast);
            }

            if (arrivals.size() > visibleRows) {
                drawScrollDots(dc, arrivals.size(), visibleRows, clampedIndex, w, 224);
            }

            // Refresh hint
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                cx, 238,
                Graphics.FONT_XTINY,
                "START to refresh",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }

        function drawArrivalRow(
            dc       as Graphics.Dc,
            arrival  as Arrival,
            arrivals as Array,
            y        as Number,
            w        as Number,
            isLast   as Boolean
        ) as Void {
            var cx = w / 2;

            // Line number — left-ish, bold feel using FONT_MEDIUM
            // Anchor at cx-80 so line+destination read left to right naturally
            var lineX = cx - 76;
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                lineX, y + 8,
                Graphics.FONT_SMALL,
                arrival.line,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
            );

            // Destination — truncated, follows line number
            var dest = arrival.destination;
            if (dest.length() > 14) {
                dest = dest.substring(0, 12) + "..";
            }
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                lineX + 46, y + 8,
                Graphics.FONT_SMALL,
                dest,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
            );

            // ETA row — green, centred under the line above
            var etaLabel = buildEtaLabel(arrivals, arrival);
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                cx, y + 28,
                Graphics.FONT_XTINY,
                etaLabel,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );

            if (!isLast) {
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(50, y + 44, w - 50, y + 44);
            }
        }

        // Collects ETAs for same line+destination and builds "Due · 8 · 16 min"
        // We only show the first matching arrival's row, so scan ahead for same service
        function buildEtaLabel(arrivals as Array, current as Arrival) as String {
            var label = "";
            var count = 0;
            var lastMinutes = -1;

            for (var i = 0; i < arrivals.size() && count < 3; i++) {
                var a = arrivals[i] as Arrival;
                if (!a.line.equals(current.line) || !a.destination.equals(current.destination)) {
                    continue;
                }

                if (count > 0) {
                    label = label + " · ";
                }

                label = label + a.etaLabel();
                count++;
            }

            // Append "min" suffix once at the end if any non-Due values
            // etaLabel() already includes "min" per value so we leave it as-is
            return label;
        }

        // --- Scroll indicator dots ---

        function drawScrollDots(
            dc          as Graphics.Dc,
            totalItems  as Number,
            visibleRows as Number,
            current     as Number,
            w           as Number,
            dotY        as Number    // explicit y — caller decides placement
        ) as Void {
            var totalDots = totalItems - visibleRows + 1;
            if (totalDots <= 1) { return; }

            var dotSize  = 4;
            var dotGap   = 8;
            var totalW   = (totalDots * dotSize) + ((totalDots - 1) * dotGap);
            var startX   = (w - totalW) / 2;

            for (var i = 0; i < totalDots; i++) {
                var x = startX + (i * (dotSize + dotGap));
                dc.setColor(
                    i == current ? Graphics.COLOR_WHITE : Graphics.COLOR_DK_GRAY,
                    Graphics.COLOR_TRANSPARENT
                );
                dc.fillCircle(x + dotSize / 2, dotY, dotSize / 2);
            }
        }

    }

}
