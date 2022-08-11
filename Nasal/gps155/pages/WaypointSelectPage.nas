var WaypointSelectPage = {
    new: func (waypoints, accept, reject) {
        return {
            parents: [WaypointSelectPage, BasePage],
            waypoints: waypoints,
            selectedWP: 0,
            accept: accept,
            reject: reject,
        };
    },

    start: func {
        call(BasePage.start, [], me);
        me.redraw();
    },

    redraw: func {
        var waypoint = me.waypoints[me.selectedWP];
        var extraInfo = '';
        var type = '';
        if (ghosttype(waypoint) == 'airport') {
        }
        elsif (waypoint.type == 'VOR') {
            extraInfo = format25khz(waypoint.frequency / 100);
        }
        elsif (waypoint.type == 'NDB') {
            extraInfo = format1khz(waypoint.frequency / 100);
        }
        var db = getWaypointDistanceAndBearing(waypoint);
        var number = me.selectedWP + 1;
        var formattedNumber = '';
        if (number < 10) {
            formattedNumber = 'nr' ~ number;
        }
        else {
            formattedNumber = '#' ~ number;
        }
        putLine(0,
            sprintf("%4s %-3s %-5s %-7s",
                formattedNumber,
                getWaypointType(waypoint, 1),
                substr(waypoint.id, 0, 5),
                extraInfo));
        putLine(1,
            sprintf(' %3i' ~ sc.deg ~ ' %5s',
                db.bearing,
                formatDistance(db.distance)));
        putLine(2,
            sprintf(' %-20s',
                shorten(waypoint.name, 20)));
    },

    handleInput: func (what, amount) {
        if (call(BasePage.handleInput, [what, amount], me)) {
            return 1;
        }
        elsif (what == 'data-inner') {
            me.selectedWP += amount;
            me.selectedWP = math.min(size(me.waypoints) - 1, math.max(0, me.selectedWP));
            me.redraw();
        }
        elsif (what == 'ENT') {
            me.accept(me.waypoints[me.selectedWP]);
            return 1;
        }
        elsif (what == 'CLR') {
            me.reject();
            return 1;
        }
    },
};
