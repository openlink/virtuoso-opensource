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
	OAT.Statistics.sum(array)
	OAT.Statistics.product(array)
	OAT.Statistics.amean(array)
	OAT.Statistics.max(array)
	OAT.Statistics.min(array)
	OAT.Statistics.distinct(array)
	OAT.Statistics.variance(array)
	OAT.Statistics.deviation(array)
	OAT.Statistics.median(array)
	OAT.Statistics.mode(array)
*/

OAT.Statistics = {
	list:[
		{longDesc:"Count", shortDesc:"COUNT", func:"count"},
		{longDesc:"Sum", shortDesc:"SUM", func:"sum"},
		{longDesc:"Product", shortDesc:"PRODUCT", func:"product"},
		{longDesc:"Arithmetic mean", shortDesc:"MEAN", func:"amean"},
		{longDesc:"Maximum", shortDesc:"MAX", func:"max"},
		{longDesc:"Minimum", shortDesc:"MIN", func:"min"},
		{longDesc:"Distinct values", shortDesc:"DISTINCT", func:"distinct"},
		{longDesc:"Variance", shortDesc:"VAR", func:"variance"},
		{longDesc:"Standard deviation", shortDesc:"STDDEV", func:"deviation"},
		{longDesc:"Median", shortDesc:"MEDIAN", func:"median"},
		{longDesc:"Mode", shortDesc:"MODE", func:"mode"}
	],

	count:function(arr) {
		return arr.length;
	},

	sum:function(arr) {
		var value = 0;
		for (var i=0;i<arr.length;i++) { value += arr[i]; }
		return value;
	},

	product:function(arr) {
		var value = 1;
		for (var i=0;i<arr.length;i++) { value *= arr[i]; }
		return value;
	},

	amean:function(arr) {
		var value = 0;
		for (var i=0;i<arr.length;i++) { value += arr[i]; }
		value = (arr.length ? value / arr.length : 0);
		return value;
	},

	max:function(arr) {
		var value = Number.MIN_VALUE;
		for (var i=0;i<arr.length;i++) if (arr[i] > value) { value = arr[i]; }
		return value;
	},

	min:function(arr) {
		var value = Number.MAX_VALUE;
		for (var i=0;i<arr.length;i++) if (arr[i] < value) { value = arr[i]; }
		return value;
	},

	distinct:function(arr) {
		var value = 0;
		var values = {};
		for (var i=0;i<arr.length;i++) { values[arr[i]] = 1; }
		for (p in values) { value++; }
		return value;
	},

	deviation:function(arr) {
		var v = OAT.Statistics.variance(arr);
		return Math.sqrt(v);
	},

	variance:function(arr) {
		if (arr.length < 2) { return 0; }
		var value = 0;
		var avg = OAT.Statistics.amean(arr);
		for (var i=0;i<arr.length;i++) { value += (arr[i]-avg)*(arr[i]-avg); }
		return (value / (arr.length-1));
	},

	median:function(arr) {
		var sorted = arr.sort(function(a,b){return a-b;});
		var i = Math.floor(arr.length/2);
		return sorted[i];
	},

	mode:function(arr) {
		var conversion = {};
		for (var i=0;i<arr.length;i++) {
			var val = arr[i];
			var index = val+"";
			if (!(index in conversion)) { conversion[index] = 1; } else { conversion[index]++; }
		}
		var max = 0;
		var prop = "";
		for (var p in conversion) {
			var cnt = conversion[p];
			if (cnt > max) {
				max = cnt;
				prop = p;
			}
		}
		return parseFloat(prop);
	}
}
