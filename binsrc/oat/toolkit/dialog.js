/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2017 OpenLink Software
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
	buttons:3, // bitmap 0x1=OK 0x2=cancel
	resize:1,
	close:1,
	autoEnter:1,
	type:false,
	def_layout:true,
        cancel_b_txt: "Cancel",
        ok_b_txt: "OK"
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

    if (options.buttons) {
	var btn_bar = OAT.Dom.create("div",
				     options.def_layout ? 
				     {marginTop:"1em", textAlign:"center", className: "dialog_btnbar"} : 
				     {className: "dialog_btnbar"});

	if (options.buttons & 1) {
	    var ok = OAT.Dom.create("input", {className: "dlg_b_ok"});
    ok.type = "button";
	    ok.value = options.ok_b_txt;
	    btn_bar.appendChild (ok);
	}

	if (options.buttons & 2) {
	    var cancel = OAT.Dom.create("input", 
					options.def_layout?{marginLeft:"2em", className: "dlg_b_cancel"}:{className: "dlg_b_cancel"});
    cancel.type = "button";
	    cancel.value = options.cancel_b_txt;
	    btn_bar.appendChild (cancel);
	}

	$(contentDiv).appendChild(btn_bar); 
    }

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
	if ((!!self.okBtn) && self.okBtn.disabled) { return; }
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
