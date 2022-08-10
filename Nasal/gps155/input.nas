var dataKnobValues = { inner: 0, outer: 0 };
var dataKnobProps = {};

var handleInput = func (what, amount=0) {
    if (!powered) return;
    if (currentPage != nil) {
        if (currentPage.handleInput(what, amount)) {
            return;
        }
    }
    # Page hasn't handled the key
};

var initInput = func {
    foreach (var which; ['inner', 'outer']) {
        (func (which) {
            dataKnobProps[which] = props.globals.getNode('controls/gps155/data-' ~ which, 1);
            dataKnobProps[which].setValue(dataKnobValues[which]);
            setlistener(dataKnobProps[which], func (node) {
                var val = node.getValue();
                var dist = val - dataKnobValues[which];
                if (dist > 500) {
                    dist -= 1000;
                }
                elsif (dist < -500) {
                    dist += 1000;
                }
                dataKnobValues[which] = val;
                handleInput('data-' ~ which, dist);
            }, 1, 0);
        })(which);
    }
    setlistener('controls/gps155/key', func (node) {
        var which = node.getValue();
        if (which != '') {
            handleInput(which);
        }
    }, 1, 0);
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
