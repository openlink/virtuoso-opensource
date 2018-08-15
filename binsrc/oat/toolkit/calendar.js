/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2018 OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
	var o = new OAT.Calendar();
	o.show(x,y,callback,date) - will callback(date), date = [year,month,day]
	o.dayNames = []
	o.monthNames = []
	o.specialDays = []
	o.dayZeroIndex = 6 - which day is when date.getDay() == 0
	o.weekStartIndex = 0

	CSS: .calendar, .calendar_selected, .calendar_special, .calendar_year, .calendar_month
*/

OAT.Calendar = function(optObj) {
	var self = this;

	this.options = {
		popup:false
	}
	for (var p in optObj) { self.options[p] = optObj[p]; }

	this.dayNames = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"];
	this.monthNames = ["January","February","March","April","May","June","July","August","September","October","November","December"];
	this.specialDays = [0,0,0,0,0,1,1];

	/* for some english-speaking countries, appropriate values should be 6, 6 */
	this.dayZeroIndex = 6; /* which day is when date.getDay() == 0 */
	this.weekStartIndex = 0;

	this.div = false;
	this.body = false;
	this.date = [0,0,0];
	this.oldDate = [0,0,0];
	this.textYear = false;
	this.textMonth = false;

	this.allowFuture = true;
	this.allowToday = true;
	this.allowPast = true;

	this.yearB = function() {
		self.date[0]--;
		self.setYear();
	}

	this.yearF = function() {
		self.date[0]++;
		self.setYear();
	}

	this.monthB = function() {
		self.date[1]--;
		if (self.date[1] == 0) {
			self.date[1] = 12;
			self.date[0]--;
			self.setYear();
		}
		self.setMonth();
	}

	this.monthF = function() {
		self.date[1]++;
		if (self.date[1] == 13) {
			self.date[1] = 1;
			self.date[0]++;
			self.setYear();
		}
		self.setMonth();
	},

	this.attach = function(td,day) {
		var callback = function(event) {
			self.date[2] = day;

			var now = new Date();
			var today = new Date(now.getFullYear(), now.getMonth()+1 , now.getDate() ); /* today's 00:00:00 hrs */
			var selected = new Date(self.date[0], self.date[1], self.date[2]);

			var notAllowed = function(msg) {
				var notify = new OAT.Notify;
				notify.send(msg);
			}

			if (!self.allowPast && selected.getTime() < today.getTime())
				return notAllowed("Picking dates in the past is not allowed.");
			if (!self.allowToday && selected.getTime() == today.getTime())
				return notAllowed("Picking today's date is now allowed.");
			if (!self.allowFuture && selected.getTime() > today.getTime())
				return notAllowed("Picking dates in the future is not allowed.");

			self.oldDate[0] = self.date[0];
			self.oldDate[1] = self.date[1];
			self.oldDate[2] = self.date[2];
			OAT.Dom.hide(self.div);
			self.visible = false;
			self.callback(self.date);
			self.createDays();
		}
		OAT.Event.attach(td,"click",callback);
	}

	this.setYear = function() {
		self.textYear.nodeValue = self.date[0];
		self.createDays();
	}

	this.setMonth = function() {
		self.textMonth.nodeValue = self.monthNames[self.date[1]-1];
		self.createDays();
	}

	this.createDays = function() {
		OAT.Dom.clear(self.body);
		var tmpdate = new Date();
		tmpdate.setFullYear(self.date[0]);
		tmpdate.setDate(1);
		tmpdate.setMonth(self.date[1]-1);
		var day = 1;
		var tr = OAT.Dom.create("tr");
		/* blank cells at the beginning... */
		var cellIndex = 0;
		var dayNum = tmpdate.getDay();
		var weekIndex = (dayNum + self.dayZeroIndex - self.weekStartIndex) % 7;
		for (var i=0;i<weekIndex;i++) {
			cellIndex++;
			var td = OAT.Dom.create("td");
			tr.appendChild(td);
		}
		/* let's go */
		while (tmpdate.getMonth()+1 == self.date[1]) {
			var td = OAT.Dom.create("td",{cursor:"pointer"});
			td.innerHTML = day;
			tr.appendChild(td);
			td.className = "";
			/* selected? */
			if (self.date[0] == self.oldDate[0] &&
				self.date[1] == self.oldDate[1] &&
				day == self.oldDate[2]) { td.className = "calendar_selected"; }
			/* special day? */
			if (self.specialDays[(cellIndex + self.weekStartIndex) % 7]) { td.className += " calendar_special"; }
			/* title */
			td.title = day+" "+self.monthNames[self.date[1]-1]+", "+self.date[0];
			/* callback */
			self.attach(td,day);
			cellIndex++;
			if (cellIndex > 6) {
				cellIndex = 0;
				self.body.appendChild(tr);
				tr = OAT.Dom.create("tr");
			}
			day++;
			tmpdate.setDate(day);
		}
		/* remaining blank cells */
		if (cellIndex) {
			while (cellIndex < 7) {
				var td = OAT.Dom.create("td");
				tr.appendChild(td);
				cellIndex++;
			}
			self.body.appendChild(tr);
		}
	},

	this.show = function(x,y,callback,date) {
		if (!self.drawn) {
			self.draw();
			self.drawn = true;
		}
		document.body.appendChild(self.div);
		self.div.style.left = x+"px";
		self.div.style.top = y+"px";
		self.callback = callback;
		OAT.Dom.show(self.div);
		self.visible = false;
		setTimeout(function(){self.visible = true;},500);
		if (date) {
			self.date = date;
			self.oldDate[0] = date[0];
			self.oldDate[1] = date[1];
			self.oldDate[2] = date[2];

			self.setYear();
			self.setMonth();
		}
	}

	this.draw = function() {
		self.div = OAT.Dom.create("div",{position:"absolute"});
		OAT.Dom.hide(self.div);
		self.div.className = "calendar";
		var t = OAT.Dom.create("table");
		self.body = OAT.Dom.create("tbody");
		var head = OAT.Dom.create("thead");
		var tr = OAT.Dom.create("tr");
		for (var i=0;i<7;i++) {
			var td = OAT.Dom.create("td");
			var index = i + self.weekStartIndex;
			if (index > 6) { index -= 7; }
			td.innerHTML = self.dayNames[index];
			tr.appendChild(td);
		}
		head.appendChild(tr);
		t.appendChild(head);
		t.appendChild(self.body);


		var divYear = OAT.Dom.create("div");
		divYear.className = "calendar_year";
		var divMonth = OAT.Dom.create("div");
		divMonth.className = "calendar_month";
		self.textYear = OAT.Dom.text("");
		self.textMonth = OAT.Dom.text("");

		/* clickers for year/month changes */
		var div = OAT.Dom.create("div",{position:"absolute",left:"2px",cursor:"pointer"});
		div.innerHTML = " &laquo; ";
		divYear.appendChild(div);
		OAT.Event.attach(div,"click",self.yearB);
		var div = OAT.Dom.create("div",{position:"absolute",right:"2px",cursor:"pointer"});
		div.innerHTML = " &raquo; ";
		divYear.appendChild(div);
		OAT.Event.attach(div,"click",self.yearF);
		divYear.appendChild(self.textYear);

		var div = OAT.Dom.create("div",{position:"absolute",left:"2px",cursor:"pointer"});
		div.innerHTML = " &laquo; ";
		divMonth.appendChild(div);
		OAT.Event.attach(div,"click",self.monthB);
		var div = OAT.Dom.create("div",{position:"absolute",right:"2px",cursor:"pointer"});
		div.innerHTML = " &raquo; ";
		divMonth.appendChild(div);
		OAT.Event.attach(div,"click",self.monthF);
		divMonth.appendChild(self.textMonth);

		self.div.appendChild(divYear);
		self.div.appendChild(divMonth);
		self.div.appendChild(t);

		var today = new Date();
		self.date[0] = today.getFullYear();
		self.date[1] = today.getMonth() + 1;
		self.date[2] = 0; /* no day selected */
		self.setYear();
		self.setMonth();

		OAT.Drag.create(divYear,self.div);
		OAT.Drag.create(divMonth,self.div);
	}

	this.drawn = false;
	this.visible = false;
	if (self.options.popup) {
		var clickRef = function(event) {
			if (!self.visible) { return; }
			var target = OAT.Event.source(event);
			if (OAT.Dom.isChild(target,self.div)) { return; }
			self.visible = false;
			OAT.Dom.hide(self.div);
		}
		OAT.Event.attach(document,"click",clickRef);
	}
}
