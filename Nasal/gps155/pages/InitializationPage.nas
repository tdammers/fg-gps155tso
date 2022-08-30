var InitializationPage = {
    new: func {
        return {
            parents: [InitializationPage, BasePage],
        };
    },

    start: func {
        call(BasePage.start, [], me);
        me.redraw();
    },

    redraw: func {
        if (deviceProps.initializationTimer.getValue() > 0.1) {
            putLine(0, sprintf(' GPS 155 Ver %s', version));
            putLine(1, sc.copy ~ "1994-95 GARMIN Corp");
            putLine(2, 'Performing self test');
        }
        else {
            var status = deviceProps.receiver.status.getValue() or 0;
            putScreen(formatSatStatus(status, satellites));
        }
    },

    update: func (dt) {
        if (deviceProps.receiver.acquiringTimeLeft.getValue() <= 0.0) {
            loadPage(NavPage.new());
        }
        me.redraw();
    },

    handleInput: func (what, amount=0) {
        return 1;
    },
};


