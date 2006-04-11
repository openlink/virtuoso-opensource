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
	Statistics.sum(array)
	Statistics.product(array)
	Statistics.avg(array)
	Statistics.max(array)
	Statistics.min(array)
	Statistics.distinct(array)
	Statistics.variation(array)
	Statistics.deviation(array)
*/

var Statistics = {
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
	
	avg:function(arr) {
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
		var variation = Statistics.variation(arr);
		return Math.sqrt(variation);
	},
	
	variation:function(arr) {
		if (arr.length < 2) { return 0; }
		var value = 0;
		var avg = Statistics.avg(arr);
		for (var i=0;i<arr.length;i++) { value += (arr[i]-avg)*(arr[i]-avg); }
		return (value / (arr.length-1));
	}
}