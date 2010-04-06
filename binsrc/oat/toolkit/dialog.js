/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2010 OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
	var d = new OAT.Dialog(title,contentDiv,optObj);
*/

/**
 * @class Simple wrapper for ok/cancel dialog, that can contain any data.
 * @message DIALOG_OK
 * @message DIALOG_CANCEL
 */
OAT.Dialog = function(title,contentDiv,optObj) {
    var self = this;
    var options = {
	width:0,
	height:0,
	modal:0,
	zIndex:1000,
	buttons:1,
	resize:1,
	close:1,
	autoEnter:1,
	type:false
    }

    if (optObj) for (var p in optObj) { options[p] = optObj[p]; }

    var winbuttons = "";

    if (options.close) { winbuttons += "c"; }
    if (options.resize) { winbuttons += "r"; }

    var win = new OAT.Win({buttons:winbuttons,
	outerWidth:options.width,
	outerHeight:options.height,
	x:0, y:0,
	title:title, type:options.type,
	stackGroupBase:false});

    $(contentDiv).style.margin = "10px";

    var nav = OAT.Dom.create("table",{marginTop:"1em",width:"90%",textAlign:"center"});
    var tbody = OAT.Dom.create("tbody");
    var row = OAT.Dom.create("tr");
    var td = OAT.Dom.create("td",{border:"none"});
    var ok = OAT.Dom.create("input");
    ok.type = "button";
    ok.value = " OK ";
    td.appendChild(ok);

    var cancel = OAT.Dom.create("input",{marginLeft:"2em"});
    cancel.type = "button";
    cancel.value = "Cancel";
    td.appendChild(cancel);
    row.appendChild(td);

    tbody.appendChild(row);
    nav.appendChild(tbody);

    if (options.buttons) { $(contentDiv).appendChild(nav); }

    win.dom.content.appendChild($(contentDiv));
    win.dom.container.style.zIndex = options.zIndex;

    var message_ok = function() {
	OAT.MSG.send(self, "DIALOG_OK", self);
    }

    var message_cancel = function() {
	OAT.MSG.send(self, "DIALOG_CANCEL", self);
    }

    var onOk = function() {
	message_ok();
	self._ignoreMessage = true;
	win.close();
	self._ignoreMessage = false;
    }

    var onCancel = function() {
	message_cancel();
	self._ignoreMessage = true;
	win.close();
	self._ignoreMessage = false;
    }

    var keyPress = function(event) {
	if (self.okBtn.disabled) { return; }
	if (event.keyCode == 13) { onOk(); }
	if (event.keyCode == 27) { onCancel(); }
    }

    if (options.modal) {
	this.close = function() {
	    win.close();
	}

	this.open = function() {
	    win.open();
	    OAT.Dimmer.show(win.dom.container,{});
	    OAT.Dom.center(win.dom.container,1,1);
	}
	OAT.MSG.attach(win, "WINDOW_CLOSE", function() {
	    OAT.Dimmer.hide();
	    if (!self._ignoreMessage) { message_cancel(); }
	});
    } else {
	this.close = function() {
	    self._ignoreMessage = true;
	    win.close();
	    self._ignoreMessage = false;
	}
	this.open = function() {
	    win.open();
	    OAT.Dom.center(win.dom.container,1,1);
	}
	OAT.MSG.attach(win, "WINDOW_CLOSE", function() {
	    if (!self._ignoreMessage) { message_cancel(); }
	});
    }

    //
    //  XXX: another backwards-compat hack:
    //

    this.show = this.open;
    this.hide = this.close;

    this.accomodate = win.accomodate;

    this.okBtn = ok;
    this.cancelBtn = cancel;

    OAT.Event.attach(ok, "click", onOk);
    OAT.Event.attach(cancel, "click", onCancel);

    if (options.autoEnter) { OAT.Event.attach(win.dom.container,"keypress",keyPress); }
}
