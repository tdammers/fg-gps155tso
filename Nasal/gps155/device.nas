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
    updateReceiver(dt);
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
    if (ghosttype(waypoint) == 'airport')
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
    var db = getWaypointDistanceAndBearing(waypoint);
    var type = '';
    if (ghosttype(waypoint) == 'airport')
        type = 'airport';
    else
        type = waypoint.type;
    deviceProps.scratch.setValues({
        'altitude-ft': -9999,
        'distance-nm': db.distance,
        'has-next': 0,
        'ident': waypoint.id,
        'name': waypoint.name,
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

var updateTimer = maketimer(0.5, func { update(0.5); });
updateTimer.simulatedTime = 1;

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

var initDevice = func {
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
    deviceProps['receiver'] = {
        status: props.globals.getNode('instrumentation/gps155/receiver/status', 1),
        statusText: props.globals.getNode('instrumentation/gps155/receiver/status-text', 1),
        acquiringTimeLeft: props.globals.getNode('instrumentation/gps155/receiver/acquiring-time-left', 1),
    };
    setPropDefault(deviceProps.receiver.status, RECEIVER_STATUS_OFF);
    setPropDefault(deviceProps.receiver.statusText, 'Not usable');
    setPropDefault(deviceProps.receiver.acquiringTimeLeft, 0);

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
        }
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

    deviceProps['scratch'] = props.globals.getNode('instrumentation/gps/scratch');
    deviceProps['command'] = props.globals.getNode('instrumentation/gps/command');

    setlistener(deviceProps['referenceMode'], updateReference);

    # Allow device to be powered up
    setlistener('controls/gps155/power', func (node) {
        if (node.getBoolValue()) {
            powered = 1;
            loadPage(InitializationPage.new());
            updateTimer.start();
            deviceProps.receiver.status.setValue(RECEIVER_STATUS_ACQUIRING);
            deviceProps.receiver.acquiringTimeLeft.setValue(5); # debug
            # deviceProps.receiver.acquiringTimeLeft.setValue((rand() * 300) + 120);
        }
        else {
            powered = 0;
            updateTimer.stop();
            loadPage(nil);
            deviceProps.receiver.status.setValue(RECEIVER_STATUS_OFF);
        }
    }, 1, 0);
};
