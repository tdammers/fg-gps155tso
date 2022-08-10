var currentPage = nil;

# Whichever waypoint is visible on the current page, if any.
var visibleWaypoint = nil;

# The currently selected 'reference' waypoint, as displayed on the NAV Position
# page.
var referenceWaypoint = nil;

var powered = 0;

var deviceProps = {};

var refModes = ['apt', 'vor', 'ndb', 'int', 'wpt'];

var changeRefMode = func (amount = 1) {
    var mode = deviceProps.referenceMode.getValue();
    var refModeIdx = vecindex(refModes, mode);
    if (refModeIdx == nil) {
        refModeIdx = 0;
    }
    else {
        refModeIdx = math.mod(refModeIdx + amount, size(refModes));
        if (refModeIdx < 0) {
            refModeIdx += size(refModes);
        }
    }
    deviceProps.referenceMode.setValue(refModes[refModeIdx]);
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

    deviceProps['scratch'] = props.globals.getNode('instrumentation/gps/scratch');
    deviceProps['command'] = props.globals.getNode('instrumentation/gps/command');

    setlistener(deviceProps['referenceMode'], updateReference);

    # Allow device to be powered up
    setlistener('controls/gps155/power', func (node) {
        if (node.getBoolValue()) {
            powered = 1;
            loadPage(InitializationPage.new());
            updateTimer.start();
        }
        else {
            powered = 0;
            updateTimer.stop();
            loadPage(nil);
        }
    }, 1, 0);
};
