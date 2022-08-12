var SatPage = {
    new: func {
        return {
            parents: [SatPage, BasePage],
        };
    },

    start: func {
        me.redraw();
    },

    redraw: func {
        var status = deviceProps.receiver.status.getValue() or 0;
        putScreen(formatSatStatus(status, satellites));
    },

    handleInput: func (what, amount=0) {
        return 1;
    },

    update: func (dt) {
        if (deviceProps.receiver.status.getValue() > 0) {
            loadPage(NavPage.new());
        }
        else {
            me.redraw();
        }
    },

};
