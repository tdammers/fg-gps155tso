var currentPage = nil;

# Whichever waypoint is visible on the current page, if any.
var visibleWaypoint = nil;

# The currently selected 'reference' waypoint, as displayed on the NAV Position
# page.
var referenceWaypoint = nil;

var powered = 0;
var satellites = [];
var satsUsed = {};
var n = 0;
for (var i = 0; i < 7; i += 1) {
    n = math.floor(rand() * 32) + 1;
    while (contains(satsUsed, n)) {
        printf("%i already in list", n);
        n = math.floor(rand() * 32) + 1;
    }
    printf("new sat: %i", n);
    satsUsed[n] = 1;
    append(satellites, {
        ident: n,
        sgl: rand(),
    });
}

var deviceProps = {};

var refModes = ['apt', 'vor', 'ndb', 'int', 'wpt'];

var cycleValue = func (val, items, amount = 1) {
    if (size(items) == 0) return '';
    if (val == nil)
        val = items[0];
    var idx = vecindex(items, val);
    if (idx == nil) {
        idx = 0;
    }
    else {
        idx = math.mod(idx + amount, size(items));
        if (idx < 0) {
            idx += size(items);
        }
    }
    return items[idx];
};

var cycleProp = func (prop, items, amount = 1) {
    var val = prop.getValue();
    val = cycleValue(val, items, amount);
    prop.setValue(val);
};

var changeRefMode = func (amount = 1) {
    cycleProp(deviceProps.referenceMode, refModes, amount);
};

var unloadPage = func {
    if (currentPage == nil) return;
    unsetCursor();
    currentPage.stop();
    currentPage = nil;
};

var loadPage = func (page) {
    unloadPage();
    currentPage = page;
    if (currentPage == nil) {
        clearScreen();
    }
    else {
        currentPage.start();
    }
};

var update = func (dt) {
    if (!powered) return;
    if (currentPage != nil) {
        currentPage.update(dt);
    }
    var blinkState = blinkProp.getValue();
    blinkState -= 1;
    if (blinkState < 0) blinkState = 1;
    blinkProp.setValue(blinkState);
    updateCursorBlink();
    updateReference();
    updateInitialization(dt);
    updateReceiver(dt);
    updateSequencing();
};

var updateSequencing = func {
    var fp = flightplan();

    if (fp == nil) return;


    var mode = deviceProps.mode.getValue();
    var leg = nil;
    var nextLeg = nil;
    var legModeNext = 0;

    if (mode == 'obs') {
        # Nothing to do
        return;
    }
    elsif (mode == 'dto') {
        # direct-to is done, check if we should resume the following leg
        var lat = deviceProps.wp[1].latitude.getValue();
        var lng = deviceProps.wp[1].longitude.getValue();
        var index = fp.indexOfWP(lat, lng);
        
        if (index >= 0) {
            fp.current = index;
            legModeNext = 1;
        }
    }

    leg = fp.getWP(fp.current);
    nextLeg = fp.getWP(fp.current + 1);

    if (leg == nil) return;
    var acpos = geo.aircraft_position();
    var (crs, dist) = leg.courseAndDistanceFrom(acpos);
    var gs = deviceProps.groundspeed.getValue();
    var track = deviceProps.groundspeed.getValue();
    var alt = deviceProps.altitude.getValue();
    var advance = 0;
    if (leg.wp_type == 'hdgToAlt') {
        if (alt >= leg.alt_cstr) {
            advance = 1;
        }
    }
    elsif (leg.fly_type == 'flyOver' or nextLeg == nil) {
        if (dist < 0.25) {
            advance = 1;
        }
    }
    else {
        var courseDiff = math.min(90, math.abs(geo.normdeg180(nextLeg.leg_bearing - track)));
        var r = gs / 60 / math.pi;
        var thresholdDist = math.sin(courseDiff * D2R * 0.5) * r + 0.25;
        # debug.dump(leg.wp_name, gs, courseDiff, r, dist, thresholdDist);
        if (dist <= thresholdDist) {
            advance = 1;
        }
    }
    if (advance) {
        if (mode == 'dto') {
            if (legModeNext) {
                fp.current += 1;
                deviceProps.command.setValue('leg');
            }
            else {
                var crs = deviceProps.desiredCourse.getValue();
                deviceProps.selectedCourse.setValue(crs);
                deviceProps.command.setValue('obs');
            }
        }
        else {
            fp.current += 1;
        }
    }
};

var waypointTypesToFixTypes = {
    'apt': 'airport',
    'vor': 'vor',
    'ndb': 'ndb',
    'int': 'fix',
    'wpt': 'all',
};

var fixTypesToWaypointTypes = {
    'airport': 'apt',
    'vor': 'vor',
    'ndb': 'ndb',
    'fix': 'int',
};

var getWaypointType = func (waypoint, guess=0) {
    var ty = '';
    if (ghosttype(waypoint) == 'flightplan-leg') {
        ty = 'wpt';
    }
    elsif (ghosttype(waypoint) == 'airport')
        ty = 'airport';
    else
        ty = string.lc(waypoint.type);
    if (contains(fixTypesToWaypointTypes, ty))
        return fixTypesToWaypointTypes[ty];
    elsif (guess)
        return substr(ty, 0, 3);
    else
        return '';
};

var updateInitialization = func (dt) {
    var timeLeft = deviceProps.initializationTimer.getValue();
    if (timeLeft > 0) {
        deviceProps.initializationTimer.setValue(math.max(0, timeLeft - dt));
    }
};

var updateReference = func {
    var candidates = [];
    var range = 10;
    var mode = deviceProps.referenceMode.getValue() or '';
    var type = contains(waypointTypesToFixTypes, mode) ? waypointTypesToFixTypes[mode] : '';
    
    if (mode == 'wpt') {
        candidates = [referenceWaypoint];
    }
    elsif (type != '') {
        while (size(candidates) == 0 and range < 1000) {
            candidates = findNavaidsWithinRange(range, type);
            range *= 2;
        }
    }
    if (size(candidates) > 0) {
        referenceWaypoint = candidates[0];
        deviceProps.referenceID.setValue(referenceWaypoint.id);
        deviceProps.referenceName.setValue(referenceWaypoint.name);
        deviceProps.referenceLat.setValue(referenceWaypoint.lat);
        deviceProps.referenceLon.setValue(referenceWaypoint.lon);
        var wpDB = getWaypointDistanceAndBearing(referenceWaypoint);
        deviceProps.referenceDist.setValue(wpDB.distance);
        deviceProps.referenceBRG.setValue(wpDB.bearing);
    }
    else {
        referenceWaypoint = nil;
        deviceProps.referenceID.setValue('');
        deviceProps.referenceName.setValue('');
        deviceProps.referenceLat.setValue(0);
        deviceProps.referenceLon.setValue(0);
        deviceProps.referenceDist.setValue(-1);
        deviceProps.referenceBRG.setValue(-1);
    }
};

var setDTO = func (waypoint) {
    var fp = flightplan();
    # If no current flightplan, and the DTO target is an airport, create a
    # new flightplan; this is necessary to make the STAR select page work in
    # such a scenario.
    if (!fp.active and (ghosttype(waypoint) == 'airport' or ghosttype(waypoint) == 'FGAirport')) {
        var apt = findAirportsByICAO(waypoint.id)[0];
        if (fp.departure == nil) {
            fp.departure = apt;
        }
        elsif (fp.destination == nil) {
            fp.destination = apt;
            fp.activate();
        }
    }
    var db = getWaypointDistanceAndBearing(waypoint);
    var type = '';
    var name = '';
    if (ghosttype(waypoint) == 'flightplan-leg') {
        type = 'wpt';
        name = waypoint.wp_name;
    }
    elsif (ghosttype(waypoint) == 'airport') {
        type = 'airport';
        name = waypoint.name;
    }
    else {
        type = waypoint.type;
        name = waypoint.name;
    }
    deviceProps.scratch.setValues({
        'altitude-ft': -9999,
        'distance-nm': db.distance,
        'has-next': 0,
        'ident': waypoint.id,
        'name': name,
        'latitude-deg': waypoint.lat,
        'longitude-deg': waypoint.lon,
        'mag-bearing-deg': db.bearing, # TODO: apply mag var
        'true-bearing-deg': db.bearing,
        'type': type,
        'valid': 1,
    });
    deviceProps.command.setValue('direct');
};

var getWaypointDistanceAndBearing = func (waypoint) {
    var acpos = geo.aircraft_position();
    var wppos = geo.Coord.new();
    wppos.set_latlon(waypoint.lat, waypoint.lon);
    var distance = acpos.distance_to(wppos) * M2NM;
    var bearing = geo.normdeg(acpos.course_to(wppos));
    if (bearing < 0.5)
        bearing += 360;
    return {
        distance: distance,
        bearing: bearing,
    }
};

confirmWaypoint = func (waypoint, self, handle) {
    loadPage(WaypointConfirmPage.new(
        waypoint,
        func {
            handle(waypoint);
            loadPage(self);
        },
        func {
            loadPage(self);
        }
    ));
};

selectWaypoint = func (waypoints, self, handle) {
    loadPage(WaypointSelectPage.new(
        waypoints,
        func (wp) {
            confirmWaypoint(wp, self, handle);
        },
        func {
            loadPage(self);
        }
    ));
};

searchAndConfirmWaypoint = func (searchID, self, handle) {
    var candidates = positioned.sortByRange(positioned.findByIdent(searchID, 'vor,ndb,airport,fix,waypoint'));
    if (size(candidates) > 1) {
        selectWaypoint(candidates, self, handle);
    }
    elsif (size(candidates) == 1) {
        confirmWaypoint(candidates[0], self, handle);
    }
};



var updateTimer = nil;

var setPropDefault = func (prop, default) {
    if (prop.getValue() == nil or prop.getValue() == '') {
        prop.setValue(default);
    }
};

var RECEIVER_STATUS_SEARCH_SKY = -2;
var RECEIVER_STATUS_ACQUIRING = -1;
var RECEIVER_STATUS_OFF = 0;
var RECEIVER_STATUS_2DNAV = 1;
var RECEIVER_STATUS_3DNAV = 2;

var receiverStatusTexts = {};
receiverStatusTexts[RECEIVER_STATUS_SEARCH_SKY] = 'Search Sky';
receiverStatusTexts[RECEIVER_STATUS_ACQUIRING] = 'Acquiring';
receiverStatusTexts[RECEIVER_STATUS_OFF] = 'Not usable';
receiverStatusTexts[RECEIVER_STATUS_2DNAV] = '2D Nav';
receiverStatusTexts[RECEIVER_STATUS_3DNAV] = '3D Nav';

var updateReceiver = func (dt) {
    if (powered) {
        var status = deviceProps.receiver.status.getValue();
        if (status == RECEIVER_STATUS_ACQUIRING) {
            var t = deviceProps.receiver.acquiringTimeLeft.getValue() or 0;
            t -= dt;
            if (t <= 0) {
                t = 0;
                deviceProps.receiver.status.setValue(RECEIVER_STATUS_3DNAV);
            }
            deviceProps.receiver.acquiringTimeLeft.setValue(t);
        }
        foreach (var sat; satellites) {
            sat.sgl += (rand() - 0.5) * dt * 0.1;
            sat.sgl = math.max(0, math.min(1, sat.sgl));
        }
    }
    else {
        deviceProps.receiver.status.setValue(RECEIVER_STATUS_OFF);
    }
};

var captureCurrentCourse = func {
    var crs = deviceProps.desiredCourse.getValue();
    deviceProps.selectedCourse.setValue(crs);
};

var selectOBSMode = func { deviceProps.command.setValue('obs'); };
var selectLEGMode = func { deviceProps.command.setValue('leg'); };

var exitLEGMode = func (reason='other reason') {
    if (deviceProps.command.getValue() == 'leg') {
        logprint(LOG_INFO, 'switch GPS to OBS mode due to ' ~ reason);
        me._captureCurrentCourse();
        me._selectOBSMode();
    }
};

var FPDelegate = {
    new: func (fp) {
        logprint(LOG_INFO, 'creating GPS155TSO flightplan delegate');
        # make FlightPlan behaviour match GPS config state
        fp.followLegTrackToFix = getprop('/instrumentation/gps/config/follow-leg-track-to-fix') or 0;

        # similarly, make FlightPlan follow the performance category settings
        fp.aircraftCategory = getprop('/autopilot/settings/icao-aircraft-category') or 'A';
        return {
            parents: [FPDelegate],
            flightplan: fp,
        };
    },


    waypointsChanged: func
    {
    },

    activated: func
    {
        if (!me.flightplan.active)
            return;

        logprint(LOG_INFO,'flightplan activated, default GPS to LEG mode');
        selectLEGMode();

        # if (getprop(GPSPath ~ '/wp/wp[1]/from-flag')) {
        #     logprint(LOG_INFO, '\tat GPS activation, already passed active WP, sequencing');
        #     me.sequence();
        # }
    },

    deactivated: func
    {
        exitLEGMode('flightplan deactivated');
    },

    endOfFlightPlan: func
    {
        exitLEGMode('end of flightplan');
    },

    cleared: func
    {
        if (!me.flightplan.active)
            return;
        exitLEGMode('flightplan cleared');
    },

    sequence: func
    {
        if (!me.flightplan.active)
            return;

        var mode = deviceProps.command.getValue();
        if (mode == 'dto') {
            # direct-to is done, check if we should resume the following leg
            var index = me.flightplan.indexOfWP(deviceProps.wp[1].latitude,
                                                deviceProps.wp[1].longitude);
            if (index >= 0) {
                logprint(LOG_INFO, "default GPS reached Direct-To, resuming FP leg at " ~ index);
                me.flightplan.current = index + 1;
                selectLEGMode();
            } else {
                # revert to OBS mode
                logprint(LOG_INFO, "default GPS reached Direct-To, resuming to OBS");

                captureCurrentCourse();
                selectOBSMode();
            }
        }
        elsif (mode == 'leg') {
            # standard leg sequencing
            var nextIndex = me.flightplan.current + 1;
            if (nextIndex >= me.flightplan.numWaypoints()) {
                logprint(LOG_INFO, "default GPS sequencing, finishing flightplan");
                me.flightplan.finish();
            } elsif (me.flightplan.nextWP().wp_type == 'discontinuity') {
                exitLEGMode('DISCONTINUITY');
            } else {
                logprint(LOG_INFO, "default GPS sequencing to next WP");
                me.flightplan.current = nextIndex;
            }
        }
        else {
            # OBS, do nothing
        }
    },

    currentWaypointChanged: func { },
};

var initDevice = func {
    # Clean up for reloading purposes
    if (updateTimer != nil) {
        updateTimer.stop();
    }
    unregisterFlightPlanDelegate('GPS155TSO');
    registerFlightPlanDelegate(FPDelegate.new, 'GPS155TSO');

    updateTimer = maketimer(0.5, func { update(0.5); });
    updateTimer.simulatedTime = 1;

    # Set up some shared properties
    deviceProps['referenceMode'] = props.globals.getNode('instrumentation/gps155/reference/mode', 1);
    deviceProps['referenceMode'].setValue('apt');
    deviceProps['referenceID'] = props.globals.getNode('instrumentation/gps155/reference/id', 1);
    deviceProps['referenceID'].setValue('');
    deviceProps['referenceName'] = props.globals.getNode('instrumentation/gps155/reference/name', 1);
    deviceProps['referenceName'].setValue('');
    deviceProps['referenceSearchID'] = props.globals.getNode('instrumentation/gps155/reference/search-id', 1);
    deviceProps['referenceSearchID'].setValue('');
    deviceProps['referenceDist'] = props.globals.getNode('instrumentation/gps155/reference/dist-nm', 1);
    deviceProps['referenceDist'].setValue(-1);
    deviceProps['referenceBRG'] = props.globals.getNode('instrumentation/gps155/reference/bearing-mag-deg', 1);
    deviceProps['referenceBRG'].setValue(-1);
    deviceProps['referenceLat'] = props.globals.getNode('instrumentation/gps155/reference/latitude-deg', 1);
    deviceProps['referenceLat'].setValue(0);
    deviceProps['referenceLon'] = props.globals.getNode('instrumentation/gps155/reference/longitude-deg', 1);
    deviceProps['referenceLon'].setValue(0);
    deviceProps['powered'] = props.globals.getNode('instrumentation/gps155/powered', 1);
    setPropDefault(deviceProps.powered, 0);
    deviceProps['initializationTimer'] = props.globals.getNode('instrumentation/gps155/initializationTimer', 1);
    setPropDefault(deviceProps.initializationTimer, 5);
    deviceProps['receiver'] = {
        status: props.globals.getNode('instrumentation/gps155/receiver/status', 1),
        statusText: props.globals.getNode('instrumentation/gps155/receiver/status-text', 1),
        acquiringTimeLeft: props.globals.getNode('instrumentation/gps155/receiver/acquiring-time-left', 1),
    };
    setPropDefault(deviceProps.receiver.status, RECEIVER_STATUS_OFF);
    setPropDefault(deviceProps.receiver.statusText, 'Not usable');
    setPropDefault(deviceProps.receiver.acquiringTimeLeft, 1);

    deviceProps['settings'] = {
        units: {
            position: props.globals.getNode('instrumentation/gps155/settings/units/position', 1),
            altitude: props.globals.getNode('instrumentation/gps155/settings/units/altitude', 1),
            speed: props.globals.getNode('instrumentation/gps155/settings/units/speed', 1),
            vspeed: props.globals.getNode('instrumentation/gps155/settings/units/vertical-speed', 1),
            distance: props.globals.getNode('instrumentation/gps155/settings/units/distance', 1),
            runwayLength: props.globals.getNode('instrumentation/gps155/settings/units/runway-length', 1),
            fuel: props.globals.getNode('instrumentation/gps155/settings/units/fuel', 1),
            pressure: props.globals.getNode('instrumentation/gps155/settings/units/pressure', 1),
            temperature: props.globals.getNode('instrumentation/gps155/settings/units/temperature', 1),
        },
        fields: {
            cdi: {
                gs: props.globals.getNode('instrumentation/gps155/settings/fields/cdi/gs', 1),
                dist: props.globals.getNode('instrumentation/gps155/settings/fields/cdi/dist', 1),
                trk: props.globals.getNode('instrumentation/gps155/settings/fields/cdi/trk', 1),
                ete: props.globals.getNode('instrumentation/gps155/settings/fields/cdi/ete', 1),
            },
        },
        startupSpeed: props.globals.getNode('instrumentation/gps155/settings/startup-speed', 1),
    };

    setPropDefault(deviceProps.settings.units.position, 'dm');
    setPropDefault(deviceProps.settings.units.altitude, 'ft');
    setPropDefault(deviceProps.settings.units.speed, 'kt');
    setPropDefault(deviceProps.settings.units.vspeed, 'fpm');
    setPropDefault(deviceProps.settings.units.distance, 'nm');
    setPropDefault(deviceProps.settings.units.runwayLength, 'ft');
    setPropDefault(deviceProps.settings.units.fuel, 'lbs');
    setPropDefault(deviceProps.settings.units.pressure, 'hpa');
    setPropDefault(deviceProps.settings.units.temperature, 'degC');
    setPropDefault(deviceProps.settings.startupSpeed, 'realistic');

    deviceProps['currentPage'] = {
        nav: props.globals.getNode('instrumentation/gps155/currentPage/nav', 1),
        set: props.globals.getNode('instrumentation/gps155/currentPage/set', 1),
        rte: props.globals.getNode('instrumentation/gps155/currentPage/rte', 1),
    };
    setPropDefault(deviceProps.currentPage.nav, 0);
    setPropDefault(deviceProps.currentPage.set, 0);

    deviceProps['groundspeed'] = props.globals.getNode('instrumentation/gps/indicated-ground-speed-kt');
    deviceProps['track'] = props.globals.getNode('instrumentation/gps/indicated-track-true-deg');
    deviceProps['altitude'] = props.globals.getNode('instrumentation/gps/indicated-altitude-ft');

    deviceProps['scratch'] = props.globals.getNode('instrumentation/gps/scratch');
    deviceProps['command'] = props.globals.getNode('instrumentation/gps/command');
    deviceProps['mode'] = props.globals.getNode('instrumentation/gps/mode');
    deviceProps['selectedCourse'] = props.globals.getNode('instrumentation/gps/selected-course-deg');
    deviceProps['desiredCourse'] = props.globals.getNode('instrumentation/gps/desired-course-deg');
    deviceProps['wp'] = [
        {
            ident: props.globals.getNode('instrumentation/gps/wp/wp[0]/ID'),
            altitude: props.globals.getNode('instrumentation/gps/wp/wp[0]/altitude-ft'),
            latitude: props.globals.getNode('instrumentation/gps/wp/wp[0]/latitude-deg'),
            longitude: props.globals.getNode('instrumentation/gps/wp/wp[0]/longitude-deg'),
            name: props.globals.getNode('instrumentation/gps/wp/wp[0]/name'),
        },
        {
            ident: props.globals.getNode('instrumentation/gps/wp/wp[1]/ID'),
            altitude: props.globals.getNode('instrumentation/gps/wp/wp[1]/altitude-ft'),
            latitude: props.globals.getNode('instrumentation/gps/wp/wp[1]/latitude-deg'),
            longitude: props.globals.getNode('instrumentation/gps/wp/wp[1]/longitude-deg'),
            name: props.globals.getNode('instrumentation/gps/wp/wp[1]/name'),
        },
    ];

    deviceProps['delegateSequencing'] = props.globals.getNode('instrumentation/gps/config/delegate-sequencing');
    deviceProps['delegateSequencing'].setBoolValue(1);

    deviceProps['flightplanActive'] = props.globals.getNode('autopilot/route-manager/active');
    setlistener(deviceProps['flightplanActive'], func (node) {
        if (node.getBoolValue()) {
            selectLEGMode();
        }
        else {
            exitLEGMode('Flightplan deactivated');
        }
    });

    setlistener(deviceProps['referenceMode'], updateReference);

    # Allow device to be powered up
    setlistener('controls/gps155/power', func (node) {
        if (node.getBoolValue()) {
            powered = 1;
            updateTimer.start();
            deviceProps.receiver.status.setValue(RECEIVER_STATUS_ACQUIRING);

            var startupSpeed = deviceProps.settings.startupSpeed.getValue();
            if (startupSpeed == 'instant') {
                deviceProps.initializationTimer.setValue(0);
                deviceProps.receiver.acquiringTimeLeft.setValue(0);
            }
            elsif (startupSpeed == 'fast') {
                deviceProps.initializationTimer.setValue(3);
                deviceProps.receiver.acquiringTimeLeft.setValue(12);
            }
            else {
                deviceProps.initializationTimer.setValue(10);
                deviceProps.receiver.acquiringTimeLeft.setValue((rand() * 300) + 120);
            }
            loadPage(InitializationPage.new());
        }
        else {
            powered = 0;
            updateTimer.stop();
            loadPage(nil);
            deviceProps.receiver.status.setValue(RECEIVER_STATUS_OFF);
        }
    }, 1, 0);
};
