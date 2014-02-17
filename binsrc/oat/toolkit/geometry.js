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
*/

OAT.Geometry = {
	sphericalData:{
		r:0,
		R:0,
		cx:0,
		cy:0
	},

	toSpherical:function(x,y) {
		var dx = x - OAT.Geometry.sphericalData.cx;
		var dy = y - OAT.Geometry.sphericalData.cy;
		var dist = dx*dx + dy*dy;
		var d = Math.sqrt(dist);
		if (d > OAT.Geometry.sphericalData.R) { return false; } /* not within circle - invisible */
		var pi2 = Math.PI / 2;

		var coef = Math.sin(pi2*d/OAT.Geometry.sphericalData.R);
		var new_d = d ? coef * (OAT.Geometry.sphericalData.r/d) : 0

		var new_x = OAT.Geometry.sphericalData.cx + dx * new_d;
		var new_y = OAT.Geometry.sphericalData.cy + dy * new_d;
		return [new_x,new_y];
	},

	fromSpherical:function(x,y) {
		var dx = x - OAT.Geometry.sphericalData.cx;
		var dy = y - OAT.Geometry.sphericalData.cy;
		var dist = dx*dx + dy*dy;
		var d = Math.sqrt(dist);
		if (d > OAT.Geometry.sphericalData.r) { return false; }
		var pi2 = Math.PI / 2;

		var coef = Math.asin(d/OAT.Geometry.sphericalData.r) / pi2;
		var new_d = d ? coef * (OAT.Geometry.sphericalData.R/d) : 0
		var new_x = OAT.Geometry.sphericalData.cx + dx * new_d;
		var new_y = OAT.Geometry.sphericalData.cy + dy * new_d;
		return [new_x,new_y];	},

	pointVsAbscissa:function(point,abscissa) {
		/* returns sign of a point against abscissa: -1 left, 1 right */
		var ax = abscissa[0][0];
		var ay = abscissa[0][1];
		var bx = abscissa[1][0];
		var by = abscissa[1][1];
		var cx = point[0];
		var cy = point[1];
		var result =  ax*(by - cy) + ay*(cx - bx) + bx*cy - cx*by;
		return (result <= 0 ? -1 : 1);
	},

	pointVsSet:function(point,pointSet,sign) {
		/* returns (ordered!) set of indexes from set which have 'sign' against first point */
		var result = [];
		var startIndex = -1;
		for (var i=0;i<pointSet.length;i++) {
			var a = pointSet[i];
			var b = pointSet[i+1 < pointSet.length ? i+1 : 0];
			var s = OAT.Geometry.pointVsAbscissa(point,[a,b]);
			if (s == sign) {
				if (startIndex == -1) { startIndex = i; }
				result.push(i);
			} else {
				startIndex = -1;
			}
		}
		if (result.length && startIndex != -1) {
			while (result[0] != startIndex) {
				var first = result.shift();
				result.push(first);
			}
		}
		return result;
	},

	enlargeConvexPolygon:function(point,polygon) {
		/* tries to add a new point to a polygonal CW oriented border */
		var subset = OAT.Geometry.pointVsSet(point,polygon,1);
		if (!subset.length) { return false; } /* point lies inside */
		if (subset.length == 1) {
			/* easy, just insert the point -> enlargement */
			var index = subset[0];
			polygon.splice(index+1,0,point);
		} else {
			/* harder, insert the point and delete others */
			/* typical contents of subset: [0,1,2,3] / [2,3] / [4,5,0] */
			var toDelete = [];
			for (var i=1;i<subset.length;i++) { toDelete.push(polygon[subset[i]]); }
			polygon.splice(subset[0]+1,0,point);
			for (var i=0;i<toDelete.length;i++) {
				var index = polygon.indexOf(toDelete[i]);
				polygon.splice(index,1);
			}
		}
		return polygon;
	},

	createConvexPolygon:function(pointSet) {
		if (pointSet.length < 3) { return false; }
		var polygon = [];
		polygon.push(pointSet[0]);
		polygon.push(pointSet[1]);
		var sign = OAT.Geometry.pointVsAbscissa(pointSet[2],polygon);
		if (sign == -1) { polygon.push(pointSet[2]); } else { polygon.splice(1,0,pointSet[2]); }
		/* we now have CW oriented triangle */
		for (var i=3;i<pointSet.length;i++) {
			OAT.Geometry.enlargeConvexPolygon(pointSet[i],polygon);
		}
		return polygon;
	},

	findCOG:function(polygon) {
		/* find center of gravity for CW oriented polygon */
		var last_x, last_y; /* prvni/posledni bod */
		var p_x, p_y; /* predchozi bod */
		var t_x = 0; /* teziste x */
		var t_y = 0; /* teziste y */
		var t_m = 0; /* suma jmenovatele */

		for (var i=0;i<polygon.length;i++) {
			var a = polygon[i];
			var b = polygon[i+1 < polygon.length ? i+1 : 0];

			var m = b[0] * a[1] - a[0] * b[1];
			t_x += (b[0] + a[0]) * m;
			t_y += (b[1] + a[1]) * m;
			t_m += m;
		}

		t_x /= t_m * 3.0;
		t_y /= t_m * 3.0;

		return [t_x,t_y];
	},

	movePoint:function(point,center,distance) { /* shifts point in direction from center by distance */
		var dx = point[0]-center[0];
		var dy = point[1]-center[1];
		var a = Math.atan2(dy,dx);
		var x = point[0] + distance * Math.cos(a);
		var y = point[1] + distance * Math.sin(a);
		return [x,y];
	},

	middleVector:function(center,a,b) { /* for center point C and two vectors returns vector which halves angle ACB */
		var pa = [];
		var pb = [];
		pa.push(center[0]+a[0]);
		pa.push(center[1]+a[1]);
		pb.push(center[0]+b[0]);
		pb.push(center[1]+b[1]);
		var v = [];
		v.push(pb[0]-pa[0]);
		v.push(pb[1]-pa[1]);
		return [v[1],-v[0]];
	},

	distance:function(a,b) {
		var dx = b[0]-a[0];
		var dy = b[1]-a[1];
		return Math.sqrt(dx*dx+dy*dy);
	}

}
