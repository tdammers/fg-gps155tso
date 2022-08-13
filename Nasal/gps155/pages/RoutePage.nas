var RoutePage = {
    new: func () {
        return {
            parents: [RoutePage, BasePage],
            scrollPos: 0,
        };
    },

    start: func {
        call(BasePage.start, [], me);
        modeLightProp.setValue('RTE');
        var fp = flightplan();
        if (fp != nil) {
            me.scrollPos = fp.current;
            debug.dump(me.scrollPos);
        }
        me.redraw();
    },

    stop: func {
        call(BasePage.stop, [], me);
        modeLightProp.setValue('');
    },

    update: func {
        me.redraw();
    },

    redraw: func {
        var fp = flightplan();
        var from = deviceProps.wp[0].ident.getValue() or '';
        var to = deviceProps.wp[1].ident.getValue() or '';

        var lines = ['', '', 'NO ACTIVE ROUTE'];

        lines[0] = sprintf('%-5s' ~ sc.arrowR ~ '%-5s leg dtk', from, to);

        if (fp != nil) {
            for (var y = 0; y < 2; y += 1) {
                var wp = fp.getWP(me.scrollPos + y);
                var current = me.scrollPos + y == fp.current;
                var first = me.scrollPos == 0;
                var last = me.scrollPos >= fp.getPlanSize() - 1;
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

                if (wp != nil) {
                    distStr = formatDistance(wp.leg_distance);
                    bearingStr = formatHeading(wp.leg_bearing);
                    identStr = navid5(wp.id, 5);
                }
                lines[y+1] = sprintf('%1s %1s%-5s %5s %4s',
                    (y == 0) ? ' ' : scrollSymbol,
                    current ? sc.arrowR : ':',
                    identStr,
                    distStr,
                    bearingStr);
            }
        }

        putScreen(lines);
    },

    handleInput: func (what, amount) {
        if (call(BasePage.handleInput, [what, amount], me)) {
            return 1;
        }
        elsif (what == 'data-inner') {
            var fp = flightplan();
            if (fp == nil) {
                me.scrollPos = 0;
            }
            else {
                var maxPos = fp.getPlanSize() - 1;
                me.scrollPos += amount;
                if (me.scrollPos < 0) me.scrollPos = 0;
                if (me.scrollPos > maxPos) me.scrollPos = maxPos;
            }
            me.redraw();
        }
        elsif (what == 'RTE') {
            return 1;
        }
    },
};

