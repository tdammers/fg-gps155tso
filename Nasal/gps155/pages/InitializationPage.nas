var InitializationPage = {
    new: func {
        return {
            parents: [InitializationPage, BasePage],
            timeLeft: 10.0,
        };
    },

    start: func {
        putLine(0, sprintf(' GPS 155 Ver %s', version));
        putLine(1, sc.copy ~ "1994-95 GARMIN Corp");
        putLine(2, 'Performing self test');
        me.timeLeft = 10.0;
    },

    update: func (dt) {
        me.timeLeft -= dt;
        if (me.timeLeft <= 0.0) {
            loadPage(DatabaseConfirmationPage.new());
        }
    },

    handleInput: func (what, amount=0) {
        return 1;
    },
};


