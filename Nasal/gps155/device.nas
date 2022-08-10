var currentPage = nil;

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
};

var updateTimer = maketimer(0.5, func { update(0.5); });
updateTimer.simulatedTime = 1;
