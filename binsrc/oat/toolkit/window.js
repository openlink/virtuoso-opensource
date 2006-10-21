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
*/

OAT.WindowData = {
	TYPE_WIN:1,
	TYPE_MAC:2,
	TYPE_ROUND:3
}

OAT.Window = function(optObj,type) {
	var self = this;

	/* get window type */
	var t = (navigator.platform.toString().match(/mac/i) ? 2 : 1);
	if (OAT.Preferences.windowTypeOverride) { t = OAT.Preferences.windowTypeOverride; }
	if (type) { t = type; }
	var obj = false;
	switch (t) {
		case OAT.WindowData.TYPE_WIN:
			var obj = new OAT.MsWin(optObj);
		break;
		case OAT.WindowData.TYPE_MAC:
			var obj = new OAT.MacWin(optObj);
		break;
		case OAT.WindowData.TYPE_ROUND:
			var obj = new OAT.RoundWin(optObj);
		break;
	}
	if (!obj) { return; }

	/* inherit properties */
	this.div = obj.div;
	this.content = obj.content;
	this.move = obj.move;
	this.caption = obj.caption;
	this.minBtn = obj.minBtn;
	this.maxBtn = obj.maxBtn;
	this.closeBtn = obj.closeBtn;
	this.resize = obj.resize;
	/* methods */
	this.onclose = function(){};
	this.onmax = function(){};
	this.onmin = function(){};
	if (this.closeBtn) { OAT.Dom.attach(this.closeBtn,"click",function(){self.onclose();}); }
	if (this.minBtn) { OAT.Dom.attach(this.minBtn,"click",function(){self.onmin();}); }
	if (this.maxBtn) { OAT.Dom.attach(this.maxBtn,"click",function(){self.onmax();}); }
	
	/* trick for easy stacking? need to be thoroughly tested.. */
	var upRef = function(event) {
		if (!obj.div.parentNode) { return; }
		obj.div.parentNode.appendChild(obj.div);
	}
//	OAT.Dom.attach(obj.div,"click",upRef);
}
OAT.Loader.pendingCount--;
