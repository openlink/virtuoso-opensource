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
	OAT.Calendar.show(x,y,callback,date) - will callback(date), date = [year,month,day]
	OAT.Calendar.dayNames = []
	OAT.Calendar.monthNames = []
	OAT.Calendar.specialDays = []
	OAT.Calendar.dayZeroIndex = 6 - which day is when date.getDay() == 0
	OAT.Calendar.weekStartIndex = 0
	
	CSS: .calendar, .calendar_selected, .calendar_special, .calendar_year, .calendar_month
*/

OAT.Calendar = {
	dayNames:["Mon","Tue","Wed","Thu","Fri","Sat","Sun"],
	monthNames:["January","February","March","April","May","June","July","August","September","October","November","December"],
	specialDays:[0,0,0,0,0,1,1],
	
	/* for some english-speaking countries, appropriate values should be 6, 6 */
	dayZeroIndex:6, /* which day is when date.getDay() == 0 */
	weekStartIndex:0,

	div:false,
	body:false,
	date:[0,0,0],
	oldDate:[0,0,0],
	textYear:false,
	textMonth:false,
	
	yearB:function() {
		OAT.Calendar.date[0]--;
		OAT.Calendar.setYear();
	},
	
	yearF:function() {
		OAT.Calendar.date[0]++;
		OAT.Calendar.setYear();
	},

	monthB:function() {
		OAT.Calendar.date[1]--;
		if (OAT.Calendar.date[1] == 0) {
			OAT.Calendar.date[1] = 12;
			OAT.Calendar.date[0]--;
			OAT.Calendar.setYear();
		}
		OAT.Calendar.setMonth();
	},

	monthF:function() {
		OAT.Calendar.date[1]++;
		if (OAT.Calendar.date[1] == 13) {
			OAT.Calendar.date[1] = 1;
			OAT.Calendar.date[0]++;
			OAT.Calendar.setYear();
		}
		OAT.Calendar.setMonth();
	},

	attach:function(td,day) {
		var callback = function(event) {
			OAT.Calendar.date[2] = day;
			OAT.Calendar.oldDate[0] = OAT.Calendar.date[0];
			OAT.Calendar.oldDate[1] = OAT.Calendar.date[1];
			OAT.Calendar.oldDate[2] = OAT.Calendar.date[2];
			OAT.Dom.hide(OAT.Calendar.div);
			OAT.Calendar.callback(OAT.Calendar.date);
			OAT.Calendar.createDays();
		}
		OAT.Dom.attach(td,"click",callback);
	},
	
	setYear:function() {
		OAT.Calendar.textYear.nodeValue = OAT.Calendar.date[0];
		OAT.Calendar.createDays();
	},
	
	setMonth:function() {
		OAT.Calendar.textMonth.nodeValue  = OAT.Calendar.monthNames[OAT.Calendar.date[1]-1];
		OAT.Calendar.createDays();
	},
	
	createDays:function() {
		OAT.Dom.clear(OAT.Calendar.body);
		var tmpdate = new Date();
		tmpdate.setFullYear(OAT.Calendar.date[0]);
		tmpdate.setMonth(OAT.Calendar.date[1]-1);
		tmpdate.setDate(1);
		var day = 1;
		var tr = OAT.Dom.create("tr");
		/* blank cells at the beginning... */
		var cellIndex = 0;
		var dayNum = tmpdate.getDay();
		var weekIndex = (dayNum + OAT.Calendar.dayZeroIndex - OAT.Calendar.weekStartIndex) % 7;
		for (var i=0;i<weekIndex;i++) {
			cellIndex++;
			var td = OAT.Dom.create("td");
			tr.appendChild(td);
		}
		/* let's go */
		while (tmpdate.getMonth()+1 == OAT.Calendar.date[1]) {
			var td = OAT.Dom.create("td",{cursor:"pointer"});
			td.innerHTML = day;
			tr.appendChild(td);
			td.className = "";
			/* selected? */
			if (OAT.Calendar.date[0] == OAT.Calendar.oldDate[0] &&
				OAT.Calendar.date[1] == OAT.Calendar.oldDate[1] &&
				day == OAT.Calendar.oldDate[2]) { td.className = "calendar_selected"; }
			/* special day? */
			if (OAT.Calendar.specialDays[(cellIndex + OAT.Calendar.weekStartIndex) % 7]) { td.className += " calendar_special"; }
			/* title */
			td.title = day+" "+OAT.Calendar.monthNames[OAT.Calendar.date[1]-1]+", "+OAT.Calendar.date[0];
			/* callback */
			OAT.Calendar.attach(td,day);
			cellIndex++;
			if (cellIndex > 6) {
				cellIndex = 0;
				OAT.Calendar.body.appendChild(tr);
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
			OAT.Calendar.body.appendChild(tr);
		}
	},
	
	show:function(x,y,callback,date) {
		OAT.Calendar.div.style.left = x+"px";
		OAT.Calendar.div.style.top = y+"px";
		OAT.Calendar.callback = callback;
		OAT.Calendar.div.style.display = "block";
		if (date) {
			OAT.Calendar.date = date;
			OAT.Calendar.oldDate[0] = OAT.Calendar.date[0];
			OAT.Calendar.oldDate[1] = OAT.Calendar.date[1];
			OAT.Calendar.oldDate[2] = OAT.Calendar.date[2];
			OAT.Calendar.setYear();
			OAT.Calendar.setMonth();
		}
	},
	
	init:function() {
		var t = OAT.Dom.create("table");
		OAT.Calendar.body = OAT.Dom.create("tbody");
		var head = OAT.Dom.create("thead");
		var tr = OAT.Dom.create("tr");
		for (var i=0;i<7;i++) {
			var td = OAT.Dom.create("td");
			var index = i + OAT.Calendar.weekStartIndex;
			if (index > 6) { index -= 7; }
			td.innerHTML = OAT.Calendar.dayNames[index];
			tr.appendChild(td);
		}
		head.appendChild(tr);
		t.appendChild(head);
		t.appendChild(OAT.Calendar.body);

		OAT.Calendar.div = OAT.Dom.create("div",{display:"none",position:"absolute"});
		OAT.Calendar.div.className = "calendar";
		
		var divYear = OAT.Dom.create("div");
		divYear.className = "calendar_year";
		var divMonth = OAT.Dom.create("div");
		divMonth.className = "calendar_month";
		OAT.Calendar.textYear = OAT.Dom.text("");
		OAT.Calendar.textMonth = OAT.Dom.text("");
		
		/* clickers for year/month changes */
		var div = OAT.Dom.create("div",{position:"absolute",left:"2px",cursor:"pointer"});
		div.innerHTML = " &laquo; ";
		divYear.appendChild(div);
		OAT.Dom.attach(div,"click",OAT.Calendar.yearB);
		var div = OAT.Dom.create("div",{position:"absolute",right:"2px",cursor:"pointer"});
		div.innerHTML = " &raquo; ";
		divYear.appendChild(div);
		OAT.Dom.attach(div,"click",OAT.Calendar.yearF);
		divYear.appendChild(OAT.Calendar.textYear);
		
		var div = OAT.Dom.create("div",{position:"absolute",left:"2px",cursor:"pointer"});
		div.innerHTML = " &laquo; ";
		divMonth.appendChild(div);
		OAT.Dom.attach(div,"click",OAT.Calendar.monthB);
		var div = OAT.Dom.create("div",{position:"absolute",right:"2px",cursor:"pointer"});
		div.innerHTML = " &raquo; ";
		divMonth.appendChild(div);
		OAT.Dom.attach(div,"click",OAT.Calendar.monthF);
		divMonth.appendChild(OAT.Calendar.textMonth);

		OAT.Calendar.div.appendChild(divYear);
		OAT.Calendar.div.appendChild(divMonth);
		OAT.Calendar.div.appendChild(t);
		document.body.appendChild(OAT.Calendar.div);
		
		var today = new Date();
		OAT.Calendar.date[0] = today.getFullYear();
		OAT.Calendar.date[1] = today.getMonth() + 1;
		OAT.Calendar.date[2] = 0; /* no day selected */
		OAT.Calendar.setYear();
		OAT.Calendar.setMonth();
		
		OAT.Drag.create(divYear,OAT.Calendar.div);
		OAT.Drag.create(divMonth,OAT.Calendar.div);
	}
}
OAT.Loader.preInit(OAT.Calendar.init);
OAT.Loader.pendingCount--;
