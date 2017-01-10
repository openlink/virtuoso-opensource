/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2017 OpenLink Software
 *
 *  See LICENSE file for details.
 */

OAT.Profiler = {
	enabled:true,
	data:{"_":{total:0,start:0,end:0}},
	start:function(label) {
		if (!OAT.Profiler.enabled) { return; }
		if (!(label in OAT.Profiler.data)) {
			OAT.Profiler.data[label] = {total:0,start:0,end:0};
		}
		var o = OAT.Profiler.data[label];

		var oo = OAT.Profiler.data["_"];
		var s = new Date().getTime();
		o.start = s;
		oo.start = s;
	},
	stop:function(label) {
		if (!OAT.Profiler.enabled) { return; }
		var t = new Date().getTime();
		var o = OAT.Profiler.data[label];
		var oo = OAT.Profiler.data["_"];
		o.end = t;
		o.total += (o.end - o.start);
		oo.end = t;
		oo.total += (oo.end - oo.start);
	},
	display:function() {
		if (!OAT.Profiler.enabled) { return; }
		var str = "";
		var total = OAT.Profiler.data["_"].total;
		for (var p in OAT.Profiler.data) {
			var o = OAT.Profiler.data[p];
			if (p != "_") {
				str += p + ": " + o.total + "msec (" + Math.round(o.total / total * 100) + "%)\n";
			}
		}
		var o = OAT.Profiler.data["_"];
		str += "TOTAL: " + o.total + "msec (" + Math.round(o.total / total * 100) + "%)\n";
		alert("OAT.Profiler.display:\n" + str);
	},
	clear:function() {
		OAT.Profiler.data = {"_":{total:0,start:0,end:0}};
	}
}
