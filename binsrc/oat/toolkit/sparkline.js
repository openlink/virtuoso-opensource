/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2014 OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
	s = new OAT.Sparkline(div,optObj)
	s.attachData(dataArray)
	s.draw()
*/
OAT.Sparkline = function(div,optObj) {
	var self = this;
	var options = {
		axes:false,
		grid:false,
		paddingLeft:2,
		paddingTop:2,
		paddingRight:1,
		paddingBottom:2,
		legend:false,
		gridDesc:false,
		desc:false,
		colors:["#888"],
		markers:[OAT.LineChartMarker.MARKER_NONE],
		sparklineMarkers:true
	}
	for (var p in optObj) { options[p] = optObj[p]; }
	this.obj = new OAT.LineChart(div,options);

	this.attachData = function(arr) {
		var data = [];
		var dims = OAT.Dom.getWH(div);
		var limit = dims[0] - options.paddingLeft - options.paddingRight;
		if (arr.length <= limit) { data = arr; } else {
			for (var i=0;i<limit;i++) {
				data.push(arr[Math.round(i*arr.length/limit)]);
			}
		}
		self.obj.attachData(data);
	}
	this.draw = function() { self.obj.draw(); }
}
