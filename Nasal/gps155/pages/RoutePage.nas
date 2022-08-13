var RoutePage = {
    new: func () {
        return {
            parents: [RoutePage, BasePage],
            editableWaypointID: '',
            deletingWaypoint: 0,
        };
    },

    scrollResetTimer: 0,
    scrollPos: 0,

    start: func {
        call(BasePage.start, [], me);
        modeLightProp.setValue('RTE');
        var fp = flightplan();
        if (fp != nil) {
            var idx = RoutePage.scrollPos + 1;
            if (idx < fp.getPlanSize()) {
                me.editableWaypointID = fp.getWP(idx).id;
            }
        }
        me.setSelectableFields();
        me.redraw();
    },

    stop: func {
        call(BasePage.stop, [], me);
        modeLightProp.setValue('');
    },

    editingWaypoint: func {
        return (me.selectedField >= 0 and me.selectedField < 5);
    },

    setSelectableFields: func {
        var self = me;
        me.selectableFields = [];
        for (var i = 0; i < 5; i += 1) {
            (func (i) {
                append(self.selectableFields, {
                    row: 2,
                    col: 3 + i,
                    changeValue: func (amount) {
                        self.editableWaypointID = scrollChar(self.editableWaypointID, i, amount);
                        self.redraw();
                    }
                });
            })(i);
        }
    },

    update: func (dt) {
        var fp = flightplan();
        if (me.selectedField < 0 and fp != nil) {
            RoutePage.scrollResetTimer -= dt;
            if (RoutePage.scrollResetTimer <= 0)
                RoutePage.scrollPos = math.max(0, fp.current - 1);
        }
        else {
            RoutePage.scrollResetTimer = 10;
        }
        me.redraw();
    },

    redraw: func {
        var fp = flightplan();
        var fromID = deviceProps.wp[0].ident.getValue() or '';
        var tgtID = deviceProps.wp[1].ident.getValue() or '';
        var mode = deviceProps.mode.getValue() or 'obs';
        var legInfo = '_____' ~ sc.arrowR ~ '_____';

        var lines = ['', 'NO ACTIVE ROUTE', ''];
        if (mode == 'dto') {
            legInfo = sprintf('go to:%-5s', navid5(tgtID));
        }
        elsif (mode == 'leg') {
            legInfo = sprintf('%-5s' ~ sc.arrowR ~ '%-5s',
                            navid5(fromID), navid5(tgtID));
        }

        lines[0] = sprintf('%-11s leg dtk', legInfo);

        if (fp != nil and fp.getPlanSize() > 1) {
            for (var y = 0; y < 2; y += 1) {
                var wp = fp.getWP(RoutePage.scrollPos + y);
                var current = RoutePage.scrollPos + y == fp.current;
                var first = RoutePage.scrollPos == 0;
                var last = RoutePage.scrollPos >= fp.getPlanSize() - 1;
                var scrollSymbol = ' ';
                if (!first) {
                    if (!last) {
                        scrollSymbol = sc.updown;
                    }
                    else {
                        scrollSymbol = sc.arrowUp;
                    }
                }
                else {
                    if (!last) {
                        scrollSymbol = sc.arrowDn;
                    }
                    else {
                        scrollSymbol = ' ';
                    }
                }

                var distStr = '__.___';
                var bearingStr = '___°';
                var identStr = '';

                if (y == 1 and me.editingWaypoint()) {
                    identStr = me.editableWaypointID;
                }
                elsif (wp != nil) {
                    distStr = formatDistance(wp.leg_distance);
                    bearingStr = formatHeading(wp.leg_bearing);
                    identStr = navid5(wp.id, 5);
                }

                if (me.deletingWaypoint and y == 1) {
                    lines[y+1] = sprintf('%1s %1s%-5s    Delete?',
                        (y == 0) ? ' ' : scrollSymbol,
                        current ? sc.arrowR : ':',
                        identStr);
                }
                else {
                    lines[y+1] = sprintf('%1s %1s%-5s %5s %4s',
                        (y == 0) ? ' ' : scrollSymbol,
                        current ? sc.arrowR : ':',
                        identStr,
                        distStr,
                        bearingStr);
                }
            }
        }
        else {
            if (me.editingWaypoint()) {
                lines[2] = sprintf('   %-5s _____ ___°', me.editableWaypointID);
            }
        }

        putScreen(lines);
    },

    handleInput: func (what, amount) {
        var fp = flightplan();
        if (call(BasePage.handleInput, [what, amount], me)) {
            return 1;
        }
        elsif (what == 'data-inner') {
            if (fp == nil) {
                RoutePage.scrollPos = 0;
            }
            else {
                var maxPos = fp.getPlanSize() - 1;
                RoutePage.scrollPos += amount;
                if (RoutePage.scrollPos < 0) RoutePage.scrollPos = 0;
                if (RoutePage.scrollPos > maxPos) RoutePage.scrollPos = maxPos;
            }
            var idx = RoutePage.scrollPos + 1;
            if (fp != nil and idx < fp.getPlanSize()) {
                me.editableWaypointID = fp.getWP(idx).id;
            }
            RoutePage.scrollResetTimer = 10;
            me.redraw();
        }
        elsif (what == 'ENT' and me.deletingWaypoint) {
            fp.deleteWP(RoutePage.scrollPos + 1);
            me.deletingWaypoint = 0;
            me.selectedField = -1;
            unsetCursor();
            me.redraw();
        }
        elsif (what == 'ENT' and me.editingWaypoint()) {
            var self = me;
            searchAndConfirmWaypoint(me.editableWaypointID, self, func (waypoint) {
                var leg = createWP(waypoint.lat, waypoint.lon, waypoint.ident);
                if (fp.getPlanSize() == 1 and (ghosttype(waypoint) == 'airport' or ghosttype(waypoint) == 'FGAirport')) {
                    fp.destination = findAirportsByICAO(waypoint.id)[0];
                }
                elsif (RoutePage.scrollPos >= fp.getPlanSize())
                    fp.appendWP(leg);
                else
                    fp.insertWPAfter(leg, RoutePage.scrollPos);
                RoutePage.scrollPos += 1;
            });
        }
        elsif (what == 'ENT' and deviceProps.mode.getValue() != 'leg') {
            deviceProps.command.setValue('leg');
            # TODO: find closest leg
            me.redraw();
        }
        elsif (what == 'CLR' and me.deletingWaypoint) {
            me.deletingWaypoint = 0;
            me.redraw();
        }
        elsif (what == 'CLR' and me.editingWaypoint() and me.scrollPos + 1 < fp.getPlanSize()) {
            me.deletingWaypoint = 1;
            me.redraw();
        }
    },
};

