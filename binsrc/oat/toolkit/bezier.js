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
	OAT.Bezier.setPointList(pointList);
	OAT.Bezier.create();
	OAT.Bezier.create2();
	OAT.Bezier.initFactorial(max);
*/

OAT.Bezier = {
	points:[],
	fac:[],

	setPoints:function(points) {
		OAT.Bezier.points = [];
		for (var i=0;i<points.length;i++) {
			OAT.Bezier.points.push(points[i]);
		}
	},

	recursion:function(t,i,j) {
		if (j==0) {
			return OAT.Bezier.points[i];
		} else {
			var r1 = OAT.Bezier.recursion(t,i-1,j-1);
			var r2 = OAT.Bezier.recursion(t,i,j-1);
			var x = (1-t)*r1[0]+t*r2[0];
			var y = (1-t)*r1[1]+t*r2[1];
			return [x,y];
		}
	},

	Bernstein:function(i,n,t) {
		var koef = OAT.Bezier.Factorial(n)/(OAT.Bezier.Factorial(i) * OAT.Bezier.Factorial(n-i));
		return Math.pow(t,i)*Math.pow(1-t,n-i)*koef;
	},

	initFactorial:function(max) {
		for (var i=0;i<=max;i++) {
			if (i==0) {
				OAT.Bezier.fac[0] = 1;
			} else {
				OAT.Bezier.fac[i] = i*OAT.Bezier.fac[i-1];
			}
		}
	},

	Factorial:function(n) {
		if (n < OAT.Bezier.fac.length) return OAT.Bezier.fac[n];
		if (n==0) return 1;
		if (n==1) return n;
		return n*OAT.Bezier.Factorial(n-1);
	},

	create:function() {
		var n = OAT.Bezier.points.length-1;
		var result = function(t) {
			return OAT.Bezier.recursion(t,n,n);
		}
		return result;
	},

	create2:function() {
		var n = OAT.Bezier.points.length-1;
		var result = function(t) {
			var x=0;
			var y=0;
			for (var i=0;i<OAT.Bezier.points.length;i++) {
				var b = OAT.Bezier.Bernstein(i,n,t);
				x += OAT.Bezier.points[i][0] * b;
				y += OAT.Bezier.points[i][1] * b;
			}
			return [x,y];
		}
		return result;
	}
}
