/*
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2006 OpenLink Software
 *  
 *  This project is free software; you can redistribute it and/or modify it
 *  under the terms of the GNU General Public License as published by the
 *  Free Software Foundation; only version 2 of the License, dated June 1991.
 *  
 *  This program is distributed in the hope that it will be useful, but
 *  WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 *  General Public License for more details.
 *  
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 *  
 *  
*/
/*
	Calendar.show(x,y,callback,date) - will callback(date), date = [year,month,day]
	Calendar.dayNames = []
	Calendar.monthNames = []
	Calendar.specialDays = []
	Calendar.dayZeroIndex = 6 - which day is when date.getDay() == 0
	Calendar.weekStartIndex = 0
	
	CSS: .calendar, .calendar_selected, .calendar_special, .calendar_year, .calendar_month
*/

var Calendar = {
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
		Calendar.date[0]--;
		Calendar.setYear();
	},
	
	yearF:function() {
		Calendar.date[0]++;
		Calendar.setYear();
	},

	monthB:function() {
		Calendar.date[1]--;
		if (Calendar.date[1] == 0) {
			Calendar.date[1] = 12;
			Calendar.date[0]--;
			Calendar.setYear();
		}
		Calendar.setMonth();
	},

	monthF:function() {
		Calendar.date[1]++;
		if (Calendar.date[1] == 13) {
			Calendar.date[1] = 1;
			Calendar.date[0]++;
			Calendar.setYear();
		}
		Calendar.setMonth();
	},

	attach:function(td,day) {
		var callback = function(event) {
			Calendar.date[2] = day;
			Calendar.oldDate[0] = Calendar.date[0];
			Calendar.oldDate[1] = Calendar.date[1];
			Calendar.oldDate[2] = Calendar.date[2];
			Calendar.div.style.display = "none";
			Calendar.callback(Calendar.date);
			Calendar.createDays();
		}
		Dom.attach(td,"click",callback);
	},
	
	setYear:function() {
		Calendar.textYear.nodeValue = Calendar.date[0];
		Calendar.createDays();
	},
	
	setMonth:function() {
		Calendar.textMonth.nodeValue  = Calendar.monthNames[Calendar.date[1]-1];
		Calendar.createDays();
	},
	
	createDays:function() {
		Dom.clear(Calendar.body);
		var tmpdate = new Date();
		tmpdate.setFullYear(Calendar.date[0]);
		tmpdate.setMonth(Calendar.date[1]-1);
		tmpdate.setDate(1);
		day = 1;
		var tr = Dom.create("tr");
		/* blank cells at the beginning... */
		var cellIndex = 0;
		var dayNum = tmpdate.getDay();
		var weekIndex = (dayNum + Calendar.dayZeroIndex - Calendar.weekStartIndex) % 7;
		for (var i=0;i<weekIndex;i++) {
			cellIndex++;
			var td = Dom.create("td");
			tr.appendChild(td);
		}
		/* let's go */
		while (tmpdate.getMonth()+1 == Calendar.date[1]) {
			var td = Dom.create("td",{cursor:"pointer"});
			td.innerHTML = day;
			tr.appendChild(td);
			td.className = "";
			/* selected? */
			if (Calendar.date[0] == Calendar.oldDate[0] &&
				Calendar.date[1] == Calendar.oldDate[1] &&
				day == Calendar.oldDate[2]) { td.className = "calendar_selected"; }
			/* special day? */
			if (Calendar.specialDays[(cellIndex + Calendar.weekStartIndex) % 7]) { td.className += " calendar_special"; }
			/* title */
			td.title = day+" "+Calendar.monthNames[Calendar.date[1]-1]+", "+Calendar.date[0];
			/* callback */
			Calendar.attach(td,day);
			cellIndex++;
			if (cellIndex > 6) {
				cellIndex = 0;
				Calendar.body.appendChild(tr);
				tr = Dom.create("tr");
			}
			day++;
			tmpdate.setDate(day);
		}
		/* remaining blank cells */
		if (cellIndex) {
			while (cellIndex < 7) {
				var td = Dom.create("td");
				tr.appendChild(td);
				cellIndex++;
			}
			Calendar.body.appendChild(tr);
		}
	},
	
	show:function(x,y,callback,date) {
		Calendar.div.style.left = x+"px";
		Calendar.div.style.top = y+"px";
		Calendar.callback = callback;
		Calendar.div.style.display = "block";
		if (date) {
			Calendar.date = date[0];
			Calendar.oldDate[0] = Calendar.date[0];
			Calendar.oldDate[1] = Calendar.date[1];
			Calendar.oldDate[2] = Calendar.date[2];
			Calendar.setYear();
			Calendar.setMonth();
		}
	},
	
	init:function() {
		var t = Dom.create("table");
		Calendar.body = Dom.create("tbody");
		var head = Dom.create("thead");
		var tr = Dom.create("tr");
		for (var i=0;i<7;i++) {
			var td = Dom.create("td");
			var index = i + Calendar.weekStartIndex;
			if (index > 6) { index -= 7; }
			td.innerHTML = Calendar.dayNames[index];
			tr.appendChild(td);
		}
		head.appendChild(tr);
		t.appendChild(head);
		t.appendChild(Calendar.body);

		Calendar.div = Dom.create("div",{display:"none",position:"absolute"});
		Calendar.div.className = "calendar";
		
		var divYear = Dom.create("div");
		divYear.className = "calendar_year";
		var divMonth = Dom.create("div");
		divMonth.className = "calendar_month";
		Calendar.textYear = Dom.text("");
		Calendar.textMonth = Dom.text("");
		
		/* clickers for year/month changes */
		var div = Dom.create("div",{position:"absolute",left:"2px",cursor:"pointer"});
		div.innerHTML = " &laquo; ";
		divYear.appendChild(div);
		Dom.attach(div,"click",Calendar.yearB);
		var div = Dom.create("div",{position:"absolute",right:"2px",cursor:"pointer"});
		div.innerHTML = " &raquo; ";
		divYear.appendChild(div);
		Dom.attach(div,"click",Calendar.yearF);
		divYear.appendChild(Calendar.textYear);
		
		var div = Dom.create("div",{position:"absolute",left:"2px",cursor:"pointer"});
		div.innerHTML = " &laquo; ";
		divMonth.appendChild(div);
		Dom.attach(div,"click",Calendar.monthB);
		var div = Dom.create("div",{position:"absolute",right:"2px",cursor:"pointer"});
		div.innerHTML = " &raquo; ";
		divMonth.appendChild(div);
		Dom.attach(div,"click",Calendar.monthF);
		divMonth.appendChild(Calendar.textMonth);

		Calendar.div.appendChild(divYear);
		Calendar.div.appendChild(divMonth);
		Calendar.div.appendChild(t);
		document.body.appendChild(Calendar.div);
		
		var today = new Date();
		Calendar.date[0] = today.getFullYear();
		Calendar.date[1] = today.getMonth() + 1;
		Calendar.date[2] = 0; /* no day selected */
		Calendar.setYear();
		Calendar.setMonth();
		
		Drag.create(divYear,Calendar.div);
		Drag.create(divMonth,Calendar.div);
	}
}
Loader.loadAttacher(Calendar.init);