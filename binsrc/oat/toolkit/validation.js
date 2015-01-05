/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2015 OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
	OAT.Validation.create(something, type, params)
	OAT.Validation.TYPE_REGEXP
	OAT.Validation.TYPE_DATE

	params = {
		min:0,
		max:50,
		def:"_",
		defDate:[today.getFullYear(),today.getMonth()+1,today.getDate()],
		minDate:[1900,1,1],
		maxDate:[2010,12,31],
		regexp:""
	}
*/

OAT.Validation = {
	TYPE_REGEXP: 1,
	TYPE_DATE:2,

	getPos:function(elm) {
	    if (typeof elm.selectionStart != "undefined" && typeof elm.selectionEnd != "undefined")
			return [elm.selectionStart,elm.selectionEnd];
	    if (document.selection && document.selection.createRange) {
			var selRange = document.selection.createRange().duplicate();
			var range = elm.createTextRange().duplicate();
			range.setEndPoint("EndToStart",selRange);
			return [range.text.length,range.text.length + selRange.text.length];
		}
	},

	setPos:function(elm,begin,end) {
	    if (typeof elm.selectionStart != "undefined" && typeof elm.selectionEnd != "undefined") {
	        elm.setSelectionRange(begin, end);
	    } else if (document.selection && document.selection.createRange) {
	        var range = elm.createTextRange ();
	        range.move ("character", begin);
	        range.moveEnd ("character", end - begin);
	        range.select ();
	    }
	},

	printDate:function(date) {
		var year = date[0];
		var month = date[1];
		var day = date[2];
		if (month < 10) { month = "0"+date[1]; }
		if (day < 10) { day = "0"+date[2]; }
		return year+"/"+month+"/"+day;
	},

	validate:function(elm,event,type,params) {
		var key = event.keyCode;
		var pos = OAT.Validation.getPos(elm);
		var value = elm.value; /* test value for validity */

		switch (type) {
			case OAT.Validation.TYPE_REGEXP:
				var good = "";
				var maxLen = Math.min(value.length,params.max);
				for (var i=0;i<maxLen;i++) {
					var ch = value.charAt(i);
					var ok = ch.match(params.regexp);
					if (i >= params.min) {
						good += (ok ? ch : "");
					} else {
						good += (ok || ch == params.def ? ch : params.def);
					}
				}
				for (var i=maxLen;i<params.min;i++) { good += params.def; }
				elm.value = good;
			break;

			case OAT.Validation.TYPE_DATE:
				var strDate = [];
				var numDate = [];
				value = value.replace(/\/\//g,"/");
				value = value.replace(/[^0-9\/]/g,"");
				var parts = value.split("/");
				for (var i=0;i<3;i++) {
					strDate[i] = params.defDate[i].toString();
					if (parts.length > i) { strDate[i] = parts[i]; }
				}
				if (strDate[0].length > 4) { strDate[0] = strDate[0].substring(0,4); }
				if (strDate[1].length > 2) { strDate[1] = strDate[1].substring(0,2); }
				if (strDate[2].length > 2) { strDate[2] = strDate[2].substring(0,2); }
				for (var i=0;i<3;i++) { numDate[i] = Number(strDate[i]); }
				var date = new Date();
				date.setDate(numDate[2]);
				date.setMonth(numDate[1]-1);
				date.setFullYear(numDate[0]);
				var good = [date.getFullYear(),date.getMonth()+1,date.getDate()];
				if (date < params.minDateObj) { good = params.minDate; }
				if (date > params.maxDateObj) { good = params.maxDate; }
				elm.value = OAT.Validation.printDate(good);
			break;
		}
		OAT.Validation.setPos(elm,pos[0],pos[1]);
	},

	create:function(something,type,params) {
		var elm = $(something);
		var today = new Date;
		var paramsObj = {
			min:0,
			max:50,
			def:"_",
			defDate:[today.getFullYear(),today.getMonth()+1,today.getDate()],
			minDate:[1900,1,1],
			maxDate:[2010,12,31],
			regexp:""
		}
		if (params) for (p in params) paramsObj[p] = params[p];
		switch (type) {
			case OAT.Validation.TYPE_REGEXP:
				if (paramsObj.min) {
					var val = "";
					for (var i=0;i<paramsObj.min;i++) { val += paramsObj.def; }
					elm.value = val;
				}
			break;

			case OAT.Validation.TYPE_DATE:
				var minDateObj = new Date();
				var maxDateObj = new Date();
				minDateObj.setFullYear(paramsObj.minDate[0]);
				maxDateObj.setFullYear(paramsObj.maxDate[0]);
				minDateObj.setMonth(paramsObj.minDate[1]-1);
				maxDateObj.setMonth(paramsObj.maxDate[1]-1);
				minDateObj.setDate(paramsObj.minDate[2]);
				maxDateObj.setDate(paramsObj.maxDate[2]);
				paramsObj.minDateObj = minDateObj;
				paramsObj.maxDateObj = maxDateObj;
				elm.value = OAT.Validation.printDate(paramsObj.defDate);
			break;
		}
		OAT.Event.attach(elm,"keyup",function(event){OAT.Validation.validate(elm,event,type,paramsObj);});
	}
}
