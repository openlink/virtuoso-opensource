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
*/

OAT.Graph = function(c) {
	var self = this;
	this.canvas = $(c);
	this.Nodes = {
		distLimit:300, /* nodes further removed than this won't move */
		distCoef:0.5,  /* node on the same line will move this fast, relative to moving node */
		list:[],
		moving:false,

		clear:function() {
			for (var i=0;i<self.Nodes.list.length;i++) { OAT.Dom.unlink(self.Nodes.list[i].div); }
			self.Nodes.list = [];
		},

		create:function(x,y,text) {
			this.x = x;
			this.y = y;
			this.text = text
			this.div = OAT.Dom.create("div",{position:"absolute",padding:"2px",border:"1px solid #000",backgroundColor:"#ffa",cursor:"move"});
			var obj = this; /* ie sux */
			this.moveBy = function(dx,dy) {
				obj.x += dx;
				obj.y += dy;
				obj.position();
			}
			this.position = function() {
				obj.div.style.left = obj.x+"px";
				obj.div.style.top = obj.y+"px";
			}
			this.position();
			this.div.innerHTML = text;
			var obj = this; /* ie sux */
			var callback_down = function(event) {
				self.Nodes.moving = obj;
				obj.mouseX = event.clientX;
				obj.mouseY = event.clientY;
			}
			var callback_up = function(event) { self.Nodes.moving = false; }
			OAT.Event.attach(this.div,"mousedown",callback_down);
			OAT.Event.attach(this.div,"mouseup",callback_up);
			self.canvas.elm.parentNode.appendChild(this.div);
			return this;
		},

		add:function(x,y,text) {
			var node = new self.Nodes.create(x,y,text);
			self.Nodes.list.push(node);
			return node;
		},

		move:function(event) {
			if (!self.Nodes.moving) { return; }
			var elm = self.Nodes.moving;
			self.canvas.clear();

			var dx = event.clientX - elm.mouseX;
			var dy = event.clientY - elm.mouseY;
			elm.moveBy(dx,dy);
			/*
				experimental:
					move other in certain distance from this one
					assume the user is moving a point along the perimeter of a sphere
					move other nodes based on their distance to this perimeter
			*/
			self.Nodes.sphereMove(elm,dx,dy);


			elm.mouseX = event.clientX;
			elm.mouseY = event.clientY;
			for (var i=0;i<self.Edges.list.length;i++) { self.Edges.list[i].draw("#888"); }
		},

		sphereMove:function(elm,dx,dy) {
			OAT.Dom.clear("info");
			self.Nodes.distLimit = parseFloat($v("dist"));
			self.Nodes.distCoef = parseFloat($v("inhibit"));
			var a1 = elm.x;
			var a2 = elm.y;
			for (var i=0;i<self.Nodes.list.length;i++) if (self.Nodes.list[i] != elm) {
				var node = self.Nodes.list[i];
				var dist = self.Nodes.dist([elm.x,elm.y],[node.x,node.y],[dx,dy]);

				var fraction =  1 - (dist / self.Nodes.distLimit); /* interval [0,1] */
				if (fraction >= 0) {
					var newdx = Math.round(dx*fraction*self.Nodes.distCoef);
					var newdy = Math.round(dy*fraction*self.Nodes.distCoef);
					node.moveBy(newdx,newdy);
				}
			}
		},

		dist:function(point1,point2,vector) {
			return Math.abs(vector[0]*(point1[1]-point2[1]) + vector[1]*(point2[0]-point1[0])) / Math.sqrt(vector[0]*vector[0] + vector[1]*vector[1]);
		}
	};

	this.Edges = {
		list:[],

		clear:function() {
			self.canvas.clear();
			self.Edges.list = [];
		},

		create:function(node1,node2) {
			this.node1 = node1;
			this.node2 = node2;
			this.draw = function(color) {
				var x1 = node1.x + Math.round(node1.div.offsetWidth/2);
				var x2 = node2.x + Math.round(node2.div.offsetWidth/2);
				var y1 = node1.y + Math.round(node1.div.offsetHeight/2);
				var y2 = node2.y + Math.round(node2.div.offsetHeight/2);
				/*
					choose one drawing routine...
				*/
				switch ($("type").selectedIndex) {
					case 0: self.canvas.line([[x1,y1],[x2,y2]],color);	break;
					case 1:	self.canvas.poly(x1,y1,x2,y2,color); break;
				}
			}
			this.draw("#888");
			return this;
		},

		add:function(node1,node2) {
			var line = new self.Edges.create(node1,node2);
			self.Edges.list.push(line);
		}
	}
}
