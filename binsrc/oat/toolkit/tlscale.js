/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2018 OpenLink Software
 *
 *  See LICENSE file for details.
 */

OAT.TlScale = {
	defWidth:80,
	findScale:function(t1,t2,oldTime,override) {
		var name = "_years";
		var d = (t2.getTime() - t1.getTime()) / 60000; /* in minutes */
		if (d <= 2) { name = "_fiveseconds"; } else
		if (d <= 30) { name = "_fiveminutes"; } else
		if (d <= 60*5) { name = "_hours"; } else
		if (d <= 60*24) { name = "_fourhours"; } else
		if (d <= 3*24*60) { name = "_days"; } else
		if (d <= 20*24*60) { name = "_weeks"; } else
		if (d <= 150*24*60) { name = "_months"; }
		if (override) { name = override; }
		var s = new OAT.TlScale[name]();
		if (oldTime) { s.currentTime = oldTime; }
		return s;
	},

	genericElement:function() {
		var l = OAT.Dom.create("div",{position:"absolute",height:"100%",top:"0px",zIndex:2,className:"timeline_bar"});
		l.txt = OAT.Dom.create("div",{position:"absolute",left:"3px",bottom:"2px",className:"timeline_date"});
		l.appendChild(l.txt);
		return l;
	},

	_years:function() {
		var self = this;
		this.format = "Y";
		this.currentTime = new Date();
		this.initBefore = function(date) {
			self.currentTime = new Date(date.getTime());
			self.currentTime.setMonth(0);
			self.currentTime.setDate(1);
			self.currentTime.setHours(0);
			self.currentTime.setMinutes(0);
			self.currentTime.setSeconds(0);
			self.currentTime.setMilliseconds(0);
			var l = OAT.TlScale.genericElement();
			l._date = new Date(self.currentTime.getTime());
			l._format = self.format;
			// l.txt.innerHTML = self.currentTime.getFullYear();
			return l;
		}
		this.isRound = function() {
			var t = self.currentTime;
			if (t.getMonth()) { return false; }
			if (t.getDate() != 1) { return false; }
			if (t.getHours()) { return false; }
			if (t.getMinutes()) { return false; }
			if (t.getSeconds()) { return false; }
			if (t.getMilliseconds()) { return false; }
			return true;
		}
		this.generateSet = function() {
			/* set == one year */
			var l = {};
			l.elm = OAT.TlScale.genericElement();
			l.width = OAT.TlScale.defWidth;
			l.startTime = new Date(self.currentTime.getTime());
			var y = parseInt(self.currentTime.getFullYear());
			self.currentTime.setFullYear(y+1);
			/*
				trick: if the date is not 'round' (in our scope), take the first 'round' before
			*/
			if (!self.isRound()) { l.elm = self.initBefore(self.currentTime); }
			l.endTime = new Date(self.currentTime.getTime());
			l.elm._date = l.endTime;
			l.elm._format = self.format;
/*			l.elm.txt.innerHTML = self.currentTime.getFullYear();
			l.elm.txt.title = self.currentTime.toHumanString(); */

			return [l];
		}
	},

	_months:function() {
		var self = this;
		this.format = "Y/m";
		this.currentTime = new Date();
		this.initBefore = function(date) {
			self.currentTime = new Date(date.getTime());
			self.currentTime.setDate(1);
			self.currentTime.setHours(0);
			self.currentTime.setMinutes(0);
			self.currentTime.setSeconds(0);
			self.currentTime.setMilliseconds(0);
			var l = OAT.TlScale.genericElement();
			l._date = new Date(self.currentTime.getTime());
			l._format = self.format;
			return l;
		}
		this.isRound = function() {
			var t = self.currentTime;
			if (t.getDate() != 1) { return false; }
			if (t.getHours()) { return false; }
			if (t.getMinutes()) { return false; }
			if (t.getSeconds()) { return false; }
			if (t.getMilliseconds()) { return false; }
			return true;
		}
		this.generateSet = function() {
			/* set == one month */
			var l = {};
			l.elm = OAT.TlScale.genericElement();
			l.width = OAT.TlScale.defWidth;
			l.startTime = new Date(self.currentTime.getTime());
			var m = (self.currentTime.getMonth()+1) % 12;
			self.currentTime.setMonth(m);
			if (!m) {
				var y = parseInt(self.currentTime.getFullYear());
				self.currentTime.setFullYear(y+1);
			}
			/*
				trick: if the date is not 'round' (in our scope), take the first 'round' before
			*/
			if (!self.isRound()) { l.elm = self.initBefore(self.currentTime); }
			l.endTime = new Date(self.currentTime.getTime());
			l.elm._date = l.endTime;
			l.elm._format = self.format;
			return [l];
		}
	},

	_weeks:function() {
		var self = this;
		this.format = "j.n.";
		this.currentTime = new Date();
		this.initBefore = function(date) {
			self.currentTime = new Date(date.getTime());
			self.currentTime.setHours(0);
			self.currentTime.setMinutes(0);
			self.currentTime.setSeconds(0);
			self.currentTime.setMilliseconds(0);
			var l = OAT.TlScale.genericElement();
			l._date = new Date(self.currentTime.getTime());
			l._format = self.format;
			return l;
		}
		this.isRound = function() {
			var t = self.currentTime;
			if (t.getHours()) { return false; }
			if (t.getMinutes()) { return false; }
			if (t.getSeconds()) { return false; }
			if (t.getMilliseconds()) { return false; }
			return true;
		}
		this.generateSet = function() {
			/* set == one week */
			var l = {};
			l.width = OAT.TlScale.defWidth;
			l.startTime = new Date(self.currentTime.getTime());
			self.currentTime.setTime(self.currentTime.getTime() + 1000 * 60 * 60 * 24 * 7);
			/*
				trick: if the date is not 'round' (in our scope), take the first 'round' before
			*/
			if (!self.isRound()) { l.elm = self.initBefore(self.currentTime); }
			l.endTime = new Date(self.currentTime.getTime());
			l.elm = OAT.TlScale.genericElement();
			l.elm._date = l.endTime;
			l.elm._format = self.format;
			return [l];
		}
	},

	_days:function() {
		var self = this;
		this.format = "j.n."
		this.currentTime = new Date();
		this.initBefore = function(date) {
			self.currentTime = new Date(date.getTime());
			self.currentTime.setHours(0);
			self.currentTime.setMinutes(0);
			self.currentTime.setSeconds(0);
			self.currentTime.setMilliseconds(0);
			var l = OAT.TlScale.genericElement();
			l._date = new Date(self.currentTime.getTime());
			l._format = self.format;
			return l;
		}
		this.isRound = function() {
			var t = self.currentTime;
			if (t.getHours()) { return false; }
			if (t.getMinutes()) { return false; }
			if (t.getSeconds()) { return false; }
			if (t.getMilliseconds()) { return false; }
			return true;
		}
		this.generateSet = function() {
			/* set == one day */
			var l = {};
			l.width = OAT.TlScale.defWidth;
			l.startTime = new Date(self.currentTime.getTime());
			self.currentTime.setTime(self.currentTime.getTime() + 1000 * 60 * 60 * 24);
			/*
				trick: if the date is not 'round' (in our scope), take the first 'round' before
			*/
			if (!self.isRound()) { l.elm = self.initBefore(self.currentTime); }
			l.endTime = new Date(self.currentTime.getTime());
			l.elm = OAT.TlScale.genericElement();
			l.elm._date = l.endTime;
			l.elm._format = self.format;
			return [l];
		}
	},

	_fourhours:function() {
		var self = this;
		this.format = "H:00";
		this.currentTime = new Date();
		this.initBefore = function(date) {
			self.currentTime = new Date(date.getTime());
			self.currentTime.setMinutes(0);
			self.currentTime.setSeconds(0);
			self.currentTime.setMilliseconds(0);
			var l = OAT.TlScale.genericElement();
			l._date = new Date(self.currentTime.getTime());
			l._format = self.format;
			return l;
		}
		this.isRound = function() {
			var t = self.currentTime;
			if (t.getMinutes()) { return false; }
			if (t.getSeconds()) { return false; }
			if (t.getMilliseconds()) { return false; }
			return true;
		}
		this.generateSet = function() {
			/* set == 4 hours */
			var l = {};
			l.width = OAT.TlScale.defWidth;
			l.startTime = new Date(self.currentTime.getTime());
			self.currentTime.setTime(self.currentTime.getTime() + 1000 * 60 * 60 * 4);
			/*
				trick: if the date is not 'round' (in our scope), take the first 'round' before
			*/
			if (!self.isRound()) { l.elm = self.initBefore(self.currentTime); }
			l.endTime = new Date(self.currentTime.getTime());
			l.elm = OAT.TlScale.genericElement();
			l.elm._date = l.endTime;
			l.elm._format = self.format;
			return [l];
		}
	},

	_hours:function() {
		var self = this;
		this.format = "H:00";
		this.currentTime = new Date();
		this.initBefore = function(date) {
			self.currentTime = new Date(date.getTime());
			self.currentTime.setMinutes(0);
			self.currentTime.setSeconds(0);
			self.currentTime.setMilliseconds(0);
			var l = OAT.TlScale.genericElement();
			l._date = new Date(self.currentTime.getTime());
			l._format = self.format;
			return l;
		}
		this.isRound = function() {
			var t = self.currentTime;
			if (t.getMinutes()) { return false; }
			if (t.getSeconds()) { return false; }
			if (t.getMilliseconds()) { return false; }
			return true;
		}
		this.generateSet = function() {
			/* set == one hour */
			var l = {};
			l.width = OAT.TlScale.defWidth;
			l.startTime = new Date(self.currentTime.getTime());
			self.currentTime.setTime(self.currentTime.getTime() + 1000 * 60 * 60);
			/*
				trick: if the date is not 'round' (in our scope), take the first 'round' before
			*/
			if (!self.isRound()) { l.elm = self.initBefore(self.currentTime); }
			l.endTime = new Date(self.currentTime.getTime());
			l.elm = OAT.TlScale.genericElement();
			l.elm._date = l.endTime;
			l.elm._format = self.format;
			return [l];
		}
	},

	_fiveminutes:function() {
		var self = this;
		this.format = "H:i";
		this.currentTime = new Date();
		this.initBefore = function(date) {
			self.currentTime = new Date(date.getTime());
			self.currentTime.setSeconds(0);
			self.currentTime.setMilliseconds(0);
			var l = OAT.TlScale.genericElement();
			l._date = new Date(self.currentTime.getTime());
			l._format = self.format;
			return l;
		}
		this.isRound = function() {
			var t = self.currentTime;
			if (t.getSeconds()) { return false; }
			if (t.getMilliseconds()) { return false; }
			return true;
		}
		this.generateSet = function() {
			/* set == 5 minutes */
			var l = {};
			l.width = OAT.TlScale.defWidth;
			l.startTime = new Date(self.currentTime.getTime());
			self.currentTime.setTime(self.currentTime.getTime() + 1000 * 60 * 5);
			/*
				trick: if the date is not 'round' (in our scope), take the first 'round' before
			*/
			if (!self.isRound()) { l.elm = self.initBefore(self.currentTime); }
			l.endTime = new Date(self.currentTime.getTime());
			l.elm = OAT.TlScale.genericElement();
			l.elm._date = l.endTime;
			l.elm._format = self.format;
			return [l];
		}
	},

	_halfminute:function() {
		var self = this;
		this.format = "i:s";
		this.currentTime = new Date();
		this.initBefore = function(date) {
			self.currentTime = new Date(date.getTime());
			self.currentTime.setSeconds(0);
			self.currentTime.setMilliseconds(0);
			var l = OAT.TlScale.genericElement();
			l._date = new Date(self.currentTime.getTime());
			l._format = self.format;
			return l;
		}
		this.isRound = function() {
			var t = self.currentTime;
			if (t.getSeconds() % 30) { return false; }
			if (t.getMilliseconds()) { return false; }
			return true;
		}
		this.generateSet = function() {
			/* set == 30 seconds */
			var l = {};
			l.width = OAT.TlScale.defWidth;
			l.startTime = new Date(self.currentTime.getTime());
			self.currentTime.setTime(self.currentTime.getTime() + 1000 * 30);
			/*
				trick: if the date is not 'round' (in our scope), take the first 'round' before
			*/
			if (!self.isRound()) { l.elm = self.initBefore(self.currentTime); }
			l.endTime = new Date(self.currentTime.getTime());
			l.elm = OAT.TlScale.genericElement();
			l.elm._date = l.endTime;
			l.elm._format = self.format;
			return [l];
		}
	},

	_fiveseconds:function() {
		var self = this;
		this.format = "i:s.x";
		this.currentTime = new Date();
		this.initBefore = function(date) {
			self.currentTime = new Date(date.getTime());
			self.currentTime.setSeconds(0);
			self.currentTime.setMilliseconds(0);
			var l = OAT.TlScale.genericElement();
			l._date = new Date(self.currentTime.getTime());
			l._format = self.format;
			return l;
		}
		this.isRound = function() {
			var t = self.currentTime;
			if (t.getSeconds() % 5) { return false; }
			if (t.getMilliseconds()) { return false; }
			return true;
		}
		this.generateSet = function() {
			/* set == 5 seconds */
			var l = {};
			l.width = OAT.TlScale.defWidth;
			l.startTime = new Date(self.currentTime.getTime());
			self.currentTime.setTime(self.currentTime.getTime() + 1000 * 5);
			/*
				trick: if the date is not 'round' (in our scope), take the first 'round' before
			*/
			if (!self.isRound()) { l.elm = self.initBefore(self.currentTime); }
			l.endTime = new Date(self.currentTime.getTime());
			l.elm = OAT.TlScale.genericElement();
			l.elm._date = l.endTime;
			l.elm._format = self.format;
			return [l];
		}
	},

	_seconds:function() {
		var self = this;
		this.format = "i:s.x";
		this.currentTime = new Date();
		this.initBefore = function(date) {
			self.currentTime = new Date(date.getTime());
			self.currentTime.setSeconds(0);
			self.currentTime.setMilliseconds(0);
			var l = OAT.TlScale.genericElement();
			l._date = new Date(self.currentTime.getTime());
			l._format = self.format;
			return l;
		}
		this.isRound = function() {
			var t = self.currentTime;
			if (t.getMilliseconds()) { return false; }
			return true;
		}
		this.generateSet = function() {
			/* set == 1 second */
			var l = {};
			l.width = OAT.TlScale.defWidth;
			l.startTime = new Date(self.currentTime.getTime());
			self.currentTime.setTime(self.currentTime.getTime() + 1000);
			/*
				trick: if the date is not 'round' (in our scope), take the first 'round' before
			*/
			if (!self.isRound()) { l.elm = self.initBefore(self.currentTime); }
			l.endTime = new Date(self.currentTime.getTime());
			l.elm = OAT.TlScale.genericElement();
			l.elm._date = l.endTime;
			l.elm._format = self.format;
			return [l];
		}
	}
}
