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
	Bezier.setPointList(pointList);
	Bezier.create();
	Bezier.create2();
	Bezier.initFactorial(max);
*/

var Bezier = {
	points:[],
	fac:[],
	
	setPoints:function(points) {
		Bezier.points = [];
		for (var i=0;i<points.length;i++) {
			Bezier.points.push(points[i]);
		}
	},
	
	recursion:function(t,i,j) {
		if (j==0) {
			return Bezier.points[i];
		} else {
			var r1 = Bezier.recursion(t,i-1,j-1);
			var r2 = Bezier.recursion(t,i,j-1);
			var x = (1-t)*r1[0]+t*r2[0];
			var y = (1-t)*r1[1]+t*r2[1];
			return [x,y];
		}
	},
	
	Bernstein:function(i,n,t) {
		var koef = Bezier.Factorial(n)/(Bezier.Factorial(i) * Bezier.Factorial(n-i));
		return Math.pow(t,i)*Math.pow(1-t,n-i)*koef;
	},
	
	initFactorial:function(max) {
		for (var i=0;i<=max;i++) {
			if (i==0) {
				Bezier.fac[0] = 1;
			} else {
				Bezier.fac[i] = i*Bezier.fac[i-1];
			}
		}
	},
	
	Factorial:function(n) {
		if (n < Bezier.fac.length) return Bezier.fac[n];
		if (n==0) return 1;
		if (n==1) return n;
		return n*Bezier.Factorial(n-1);
	},

	create:function() {
		var n = Bezier.points.length-1;
		var result = function(t) {
			return Bezier.recursion(t,n,n);
		}
		return result;
	},

	create2:function() {
		var n = Bezier.points.length-1;
		var result = function(t) {
			var x=0;
			var y=0;
			for (var i=0;i<Bezier.points.length;i++) {
				var b = Bezier.Bernstein(i,n,t);
				x += Bezier.points[i][0] * b;
				y += Bezier.points[i][1] * b;
			}
			return [x,y];
		}
		return result;
	}
}