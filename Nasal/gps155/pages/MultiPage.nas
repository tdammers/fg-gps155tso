var MultiPage = {
    new: func (currentPageProp, modeKey, wrapLeft=1) {
        return {
            parents: [MultiPage, BasePage],
            currentPageProp: currentPageProp,
            modeKey: modeKey,
            wrapLeft: wrapLeft,
        };
    },

    start: func {
        call(BasePage.start, [], me);
        me.setSelectableFields();
        me.handleSubpageChange();
        me.redraw();
    },

    stop: func {},

    getCurrentPage: func {
        me.currentPageProp.getValue() or 0;
    },

    getNumPages: func {
        return 1; # Override as needed
    },

    setSelectableFields: func {
        me.selectableFields = [];
    },

    handleSubpageChange: func {
        # Override as needed
    },

    moveSubpage: func (amount=1) {
        var currentSubpage = me.currentPageProp.getValue() or 0;
        if (amount == 0) {
            return;
        }
        elsif (amount > 0) {
            me.currentPageProp.setValue(
                math.mod(currentSubpage + amount, me.getNumPages()));
        }
        elsif (amount < 0) {
            if (me.wrapLeft) {
                me.currentPageProp.setValue(
                    math.mod(currentSubpage + me.getNumPages() + amount, me.getNumPages()));
            }
            else {
                me.currentPageProp.setValue(
                    math.max(0, currentSubpage + amount));
            }
        }
        me.handleSubpageChange();
        me.setSelectableFields();
        unsetCursor();
        me.redraw();
    },

    handleInput: func (what, amount=0) {
        var self = me;
        if (call(BasePage.handleInput, [what, amount], me)) {
            return 1;
        }
        if (what == me.modeKey) {
            me.moveSubpage(1);
            return 1;
        }
        elsif (what == 'data-outer') {
            if (me.selectedField == -1) {
                me.moveSubpage(amount);
                return 1;
            }
            else {
                return 0;
            }
        }
        else {
            return 0;
        }
    },

};
