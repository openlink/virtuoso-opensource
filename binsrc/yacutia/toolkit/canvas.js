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
	new Canvas(canvas);
	Canvas.point(x,y,color);
	Canvas.circle(x,y,r,color);
	Canvas.save();
	Canvas.restore();
	Canvas.clear();
	Canvas.line(points,color);
	Canvas.poly(x1,y1,x2,y2,color);
*/

function Canvas(canvas) {
	this.elm = $(canvas);
	this.ctx = this.elm.getContext('2d');
	this.point = function(x,y,color) {
		this.ctx.fillStyle = color;
		this.ctx.fillRect(x,y,1,1);
	}
	this.circle = function(x,y,r,color) {
		this.ctx.fillStyle = color;
		this.ctx.beginPath();
		this.ctx.arc(x,y,r,0,Math.PI*2,1);
		this.ctx.fill();
	}
	this.save = function() {
		this.ctx.save();
	}
	this.restore = function() {
		this.ctx.restore();
	}
	this.clear = function() {
		var w = this.elm.getAttribute("width");
		var h = this.elm.getAttribute("height");
		this.ctx.clearRect(0,0,w,h);
	}
	this.beginPath = function() {
		this.ctx.beginPath();
	}
	this.closePath = function() {
		this.ctx.closePath();
	}
	this.line = function(points,color) {
		for (var i=0;i<points.length;i++) {
			if (i==0) {
				this.ctx.beginPath();
				this.ctx.moveTo(points[i][0],points[i][1]);
			} else {
				this.ctx.lineTo(points[i][0],points[i][1]);
			}
		}
		this.ctx.strokeStyle = color;
		this.ctx.stroke();
	}
	this.poly = function(x1,y1,x2,y2,color) {
		this.ctx.beginPath();
		this.ctx.moveTo(x1,y1);
		this.ctx.bezierCurveTo((x1+x2)/2-10,(y1+y2)/2-10,(x1+x2)/2+10,(y1+y2)/2+10,x2,y2);
		this.ctx.strokeStyle = color;
		this.ctx.stroke();
	}
}
