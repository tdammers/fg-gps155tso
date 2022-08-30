var NavPage = {
    new: func {
        var m = MultiPage.new(deviceProps.currentPage.nav, 'NAV', 0);
        m.parents = [NavPage] ~ m.parents;
        return m;
    },

    SUBPAGE_CDI: 0,
    SUBPAGE_POSITION: 1,
    SUBPAGE_MENU1: 2,
    SUBPAGE_MENU2: 3,

    getNumPages: func { return 2; },

    start: func {
        call(MultiPage.start, [], me);
        modeLightProp.setValue('NAV');
    },

    stop: func {
        call(MultiPage.stop, [], me);
        modeLightProp.setValue('');
    },

    handleSubpageChange: func {
        me.updateVisibleWaypoint();
    },

    updateVisibleWaypoint: func {
        if (me.getCurrentPage() == 1) {
            visibleWaypoint = referenceWaypoint;
        }
        else {
            visibleWaypoint = nil;
        }
    },

    setSelectableFields: func {
        var self = me;
        if (me.getCurrentPage() == NavPage.SUBPAGE_CDI) {
            me.selectableFields = [
                { row: 2, col: 6,
                    changeValue: func (amount) {},
                    erase: func {
                        var mode = deviceProps.mode.getValue();
                        if (mode == 'dto' and flightplan() != nil and flightplan().getPlanSize() > 1) {
                            deviceProps.command.setValue('leg');
                        }
                        else {
                            deviceProps.command.setValue('obs');
                        }
                    }
                },
                { row: 0, col: 12,
                    changeValue: func (amount) {
                        cycleProp(deviceProps.settings.fields.cdi.gs,
                            ['gs', 'str'],
                            amount);
                        self.redraw();
                    }
                },
                { row: 1, col: 12,
                    changeValue: func (amount) {
                        cycleProp(deviceProps.settings.fields.cdi.trk,
                            ['trk', 'brg', 'dtk'], # TODO: cts, trn
                            amount);
                        self.redraw();
                    }
                },
                { row: 2, col: 12,
                    changeValue: func (amount) {
                        cycleProp(deviceProps.settings.fields.cdi.ete,
                            ['eta', 'ete', 'trk'], # TODO: vn
                            amount);
                        self.redraw();
                    }
                },
            ];
        }
        elsif (me.getCurrentPage() == NavPage.SUBPAGE_POSITION) {
            me.selectableFields = [
                { row: 2, col:  1,
                    changeValue: func (amount) {
                        changeRefMode(amount);
                        self.updateVisibleWaypoint();
                        self.setSelectableFields();
                        self.redraw();
                    }
                },
            ];
            if (deviceProps.referenceMode.getValue() == 'wpt') {
                for (var i = 0; i < 5; i += 1) {
                    (func (i) {
                        append(me.selectableFields, {
                            row: 2,
                            col: 5 + i,
                            changeValue: func (amount) {
                                var str = deviceProps.referenceSearchID.getValue();
                                deviceProps.referenceSearchID.setValue(scrollChar(str, i, amount));
                                self.redraw();
                            },
                            accept: func {
                                var searchID = deviceProps.referenceSearchID.getValue();

                                searchAndConfirmWaypoint(searchID, self, func (waypoint) {
                                    referenceWaypoint = waypoint;
                                    deviceProps.referenceSearchID.setValue(referenceWaypoint.id);
                                    updateReference();
                                });
                                return 1;
                            }
                        });
                    })(i);
                }
            }
        }
        else {
            me.selectableFields = [];
        }
    },

    handleInput: func (what, amount=0) {
        var self = me;
        if (call(MultiPage.handleInput, [what, amount], me)) {
            return 1;
        }
        else {
            return 0;
        }
    },

    update: func (dt) {
        me.updateVisibleWaypoint();
        me.redraw();
    },

    redraw: func {
        if (me.getCurrentPage() == 0)
            me.redrawCDI();
        elsif (me.getCurrentPage() == 1)
            me.redrawPosition();
        elsif (me.getCurrentPage() == 2)
            me.redrawNavMenu(0);
        elsif (me.getCurrentPage() == 3)
            me.redrawNavMenu(1);
    },

    redrawNavMenu: func (n) {
        putLine(0, "NAV MENU " ~ (n+1));
        putLine(1, "");
        putLine(2, "(not implemented)");
    },

    redrawCDI: func {
        var mode = getprop('/instrumentation/gps/mode') or 'obs';
        var cte = getprop('/instrumentation/gps/cdi-deflection') or 0;
        var tgtID = getprop('/instrumentation/gps/wp/wp[1]/ID') or '';
        var fromID = getprop('/instrumentation/gps/wp/wp[0]/ID') or '';
        var fromFlag = getprop('/instrumentation/gps/from-flag') or 0;

        var tgtBRG = getprop('/instrumentation/gps/wp/wp[1]/bearing-mag-deg');
        var tgtDST = getprop('/instrumentation/gps/wp/wp[1]/distance-nm');
        var legTRK = getprop('/instrumentation/gps/wp/leg-mag-course-deg');
        var ete = getprop('/instrumentation/gps/wp/wp[1]/TTW') or '';
        var gs = getprop('/instrumentation/gps/indicated-ground-speed-kt') or 0;
        var cte = getprop('/instrumentation/gps/wp/wp[1]/course-error-nm') or 0;
        var trk = getprop('/instrumentation/gps/indicated-track-magnetic-deg') or 0;

        var cdiFormatted = 'No actv wpt';
        var gsFormatted = '___ ';
        var distanceFormatted = "___" ~ smallStr('.__') ~ sc.nm;
        var trackFormatted = "___";
        var legInfo = "_____" ~ sc.arrowR ~ "_____";
        var eteFormatted = "__:__";

        if (tgtID != '' or mode == 'obs') {
            var needlePos = 5 + math.min(5, math.max(-5, math.round(cte / 2)));
            cdiFormatted = '';
            var i = 0;
            for (i = 0; i < needlePos; i += 1)
                cdiFormatted ~= sc.dot;
            if (fromFlag)
                cdiFormatted ~= sc.arrowDn;
            else
                cdiFormatted ~= sc.arrowUp;
            for (i = needlePos + 1; i < 11; i += 1)
                cdiFormatted ~= sc.dot;
            if (mode != 'obs')
                distanceFormatted = formatDistance(tgtDST);
            if (mode == 'dto') {
                legInfo = sprintf('go to:%-5s', navid5(tgtID));
            }
            elsif (mode == 'leg') {
                legInfo = sprintf('%-5s' ~ sc.arrowR ~ '%-5s',
                                navid5(fromID), navid5(tgtID));
            }
        }

        var formatCDIField = func (type) {
            var mode = deviceProps.mode.getValue();
            if (type == 'gs') {
                return 'gs ' ~ formatSpeed(gs, 'kt');
            }
            elsif (type == 'str') {
                var deviation = formatDistanceShort(math.abs(cte));
                if (cte < -0.01)
                    return 'strL' ~ deviation;
                elsif (cte > 0.01)
                    return 'strR' ~ deviation;
                else
                    return 'strC' ~ deviation;
            }
            elsif (type == 'trk') {
                return 'trk ' ~ formatHeading(trk);
            }
            elsif (type == 'brg') {
                if (mode == 'obs')
                    return 'brg ____';
                else
                    return 'brg ' ~ formatHeading(tgtBRG);
            }
            elsif (type == 'dtk') {
                if (mode == 'obs')
                    return 'dtk ____';
                else
                    return 'dtk ' ~ formatHeading(legTRK);
            }
            elsif (type == 'ete') {
                if (substr(ete or '__:__', 0, 3) == '00:')
                    return 'ete' ~ substr(ete or '__:__', 3, 5);
                elsif (substr(ete or '__:__', 0, 1) == '0:')
                    return 'ete' ~ substr(ete or '__:__', 1, 4);
                else
                    return 'ete' ~ substr(ete or '__:__', 0, 5);
            }
            else {
                # TODO: dis, cts, trn, vn
                return sprintf('%-3s ____', type);
            }
        };

        var formattedFields = {};
        foreach (var f; ['gs', 'trk', 'ete']) {
            var mode = deviceProps.settings.fields.cdi[f].getValue();
            formattedFields[f] = formatCDIField(mode);
        }

        putLine(0, cdiFormatted ~ " " ~ formattedFields.gs);
        putLine(1, "dis " ~ distanceFormatted ~ '  ' ~ formattedFields.trk);
        putLine(2, legInfo ~ " " ~ formattedFields.ete);
    },

    redrawPosition: func {
        var lat = getprop('/instrumentation/gps/indicated-latitude-deg') or 0;
        var lon = getprop('/instrumentation/gps/indicated-longitude-deg') or 0;
        var searchID = deviceProps.referenceSearchID.getValue() or '';
        var refID = deviceProps.referenceID.getValue() or '';
        var refBRG = deviceProps.referenceBRG.getValue() or 0;
        var refDST = deviceProps.referenceDist.getValue() or -1;
        var refMode = deviceProps.referenceMode.getValue() or '';
        var alt = getprop('/instrumentation/altimeter/indicated-altitude-ft') or 0;

        var formattedLat = '___.__' ~ sc.deg ~ '__' ~ smallStr('.___');
        var formattedLon = '____.__' ~ sc.deg ~ '__' ~ smallStr('.___');
        var formattedDistance = '__' ~ smallStr('.__') ~ '_';
        var formattedBearing = '___';
        var line2 = '____ ____ ___' ~ sc.deg ~ formattedDistance;
        var visibleID = '_____';

        if (refMode == 'wpt' and me.selectedField > 0 and me.selectedField < 5)
            visibleID = searchID;
        else
            visibleID = refID;
        
        if (lat and lon) {
            formattedLat = formatLat(lat);
            formattedLon = formatLon(lon);
        }
        if (refDST >= 0)
            formattedDistance = formatDistanceShort(refDST);
        if (refBRG >= 0)
            formattedBearing = sprintf('%03.0f', refBRG);
        line2 = sc.fr ~ refMode ~ ' ' ~ sprintf('%-5s', visibleID) ~ ' ' ~
                    formattedBearing ~ sc.deg ~
                    formattedDistance;

        putLine(0, sprintf('alt %6s', formatAltitude(alt)));
        putLine(1, formattedLat ~ ' ' ~ formattedLon);
        putLine(2, line2);
    },
};
