/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2006 Ondrej Zara and OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
	var d = new OAT.Dialog(title,contentDiv,optObj);
*/

OAT.Dialog = function(title,contentDiv,optObj) {
	var self = this;
	var options = {
		width:0,
		height:0,
		modal:0,
		onshow:function(){},
		onhide:function(){},
		zIndex:1000,
		buttons:1,
		resize:1
	}
	if (optObj) for (var p in optObj) { options[p] = optObj[p]; }
	var win = new OAT.Window({close:1, max:0, min:0, width:options.width, height:options.height, x:0, y:0, title:title,resize:options.resize});
 	$(contentDiv).style.margin = "1em";
 	var nav = OAT.Dom.create("table",{marginTop:"1em",width:"90%",textAlign:"center"});
 	var tbody = OAT.Dom.create("tbody");
 	var row = OAT.Dom.create("tr");
 	var td = OAT.Dom.create("td",{border:"none"});
 	var ok = OAT.Dom.create("input");
 	ok.setAttribute("type","button");
 	ok.value = " OK ";
 	td.appendChild(ok);
 	var cancel = OAT.Dom.create("input",{marginLeft:"2em"});
 	cancel.setAttribute("type","button");
 	cancel.value = "Cancel";
 	td.appendChild(cancel);
 	row.appendChild(td);
 	
 	tbody.appendChild(row);
 	nav.appendChild(tbody);
 	if (options.buttons) { $(contentDiv).appendChild(nav); }
 	document.body.appendChild(win.div);
	win.content.appendChild($(contentDiv)); 
	win.div.style.zIndex = options.zIndex;
	if (options.modal) {
		this.show = function() { OAT.Dimmer.show(win.div,{}); OAT.Dom.center(win.div,1,1); options.onshow(); }
		this.hide = function() { OAT.Dimmer.hide(); options.onhide(); }
	} else {
		this.show = function() { OAT.Dom.show(win.div); OAT.Dom.center(win.div,1,1); options.onshow(); }
		this.hide = function() { OAT.Dom.hide(win.div); options.onhide(); }
	}
	OAT.Dom.hide(win.div); 
	
	win.onclose = this.hide;
	this.ok = function(){};
	this.cancel = function(){};
	this.okBtn = ok;
	this.cancelBtn = cancel;
	OAT.Dom.attach(ok,"click",function(){self.ok();});
	OAT.Dom.attach(cancel,"click",function(){self.cancel();});
	
	var keyPress = function(event) {
		if (self.okBtn.getAttribute("disabled") == "disabled") { return; }
		if (event.keyCode == 13) { self.ok(); }
		if (event.keyCode == 27) { self.cancel(); }
	}
	OAT.Dom.attach(win.div,"keypress",keyPress);
}
OAT.Loader.pendingCount--;
