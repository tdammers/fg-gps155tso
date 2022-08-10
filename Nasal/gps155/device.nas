var currentPage = nil;
var powered = 0;

var deviceProps = {};

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

var referenceTypesToFixTypes = {
    'apt': 'airport',
    'vor': 'vor',
    'ndb': 'ndb',
    'int': 'fix',
    'wpt': 'all',
};

var updateReference = func {
    var reference = nil;
    var candidates = [];
    var range = 10;
    var mode = deviceProps.referenceMode.getValue() or '';
    var type = contains(referenceTypesToFixTypes, mode) ? referenceTypesToFixTypes[mode] : '';
    if (type != '') {
        while (size(candidates) == 0 and range < 1000) {
            candidates = findNavaidsWithinRange(range, type);
            range *= 2;
        }
    }
    if (size(candidates) > 0) {
        reference = candidates[0];
        deviceProps.referenceID.setValue(reference.id);
        deviceProps.referenceName.setValue(reference.name);
        deviceProps.referenceLat.setValue(reference.lat);
        deviceProps.referenceLon.setValue(reference.lon);
        var acpos = geo.aircraft_position();
        var refpos = geo.Coord.new();
        refpos.set_latlon(reference.lat, reference.lon);
        deviceProps.referenceDist.setValue(acpos.distance_to(refpos) * M2NM);
        deviceProps.referenceBRG.setValue(acpos.course_to(refpos));
    }
    else {
        deviceProps.referenceID.setValue('');
        deviceProps.referenceName.setValue('');
        deviceProps.referenceLat.setValue(0);
        deviceProps.referenceLon.setValue(0);
        deviceProps.referenceDist.setValue(-1);
        deviceProps.referenceBRG.setValue(-1);
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
