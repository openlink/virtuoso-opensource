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
	var d = new Dock(numColumns)
	document.body.appendChild(d.div)
	d.addObject(colIndex, grabber, mover)

	CSS: .dock, .dock_column_0 .. .dock_column_n-1, .dock_blank
*/

function Dock(numColumns) {
	var obj = this;
	this.div = Dom.create("div");
	this.div.className = "dock";
	this.columns = [];
	this.movers = [];
	this.dummies = [];
	this.gd = new GhostDrag();
	this.ghost = Dom.create("div",{border:"1px dashed #000",position:"absolute",display:"none"});
	document.body.appendChild(this.ghost);
	this.lock = 0;
	for (var i=0;i<numColumns;i++) {
		var col = Dom.create("div");
		col.className = "dock_column_"+i;
		this.columns.push(col);
		this.div.appendChild(col);
		var dummie = Dom.create("div",{border:"none",margin:"0px",padding:"0px",backgroundColor:"transparent"});
		this.dummies.push(dummie);
		this.gd.addTarget(dummie);
	}
	
	this.startDrag = function(elm) {
		obj.lock = 1;
		var dims = Dom.getWH(elm);
		for (var i=0;i<obj.columns.length;i++) { 
			obj.columns[i].appendChild(obj.dummies[i]);
			obj.dummies[i].style.height = dims[1] + "px";
		}
		
	}
	
	this.endDrag = function() {
		obj.lock = 0;
		obj.ghost.style.display = "none";
		/* 
			hack: 
			when we unlink dummies right after depressing mouse, 
			ghostdrag won't register a successfull drop on them,
			so we have to delay it a little bit
		*/	
		var hideRef = function() {
			for (var i=0;i<obj.columns.length;i++) { Dom.unlink(obj.dummies[i]); }
		}
		setTimeout(hideRef,500); 
	}
	
	this.move = function(mover,target) { /* finally moving the panel 'mover' to place 'target' */
		if (mover == target) { return; }
		
		/* blank place to disappear */
		var dims = Dom.getWH(mover);
		var blank = Dom.create("div");
		blank.className = "dock_blank";
		blank.style.height = dims[1]+"px";
		mover.parentNode.insertBefore(blank,mover);
		var as = AnimationStructure.generate(blank,AnimationData.RESIZE,{w:dims[0],h:0,dist:5})
		var a = new Animation(as,5);
		a.endFunction = function(){Dom.unlink(blank);}
		a.start();

		/* put mover to right place */
		target.parentNode.insertBefore(mover,target);
	}
	
	this.getOverElm = function(event) {
		/* returns coordinates, dimensions */
		var abs_x = document.body.scrollLeft + event.clientX; /* here is the cursor */
		var abs_y = document.body.scrollTop + event.clientY;
		var s_coords, s_dims;
		var index = -1;
		for (var i=0;i<obj.movers.length;i++) {
			var coords = Dom.position(obj.movers[i]);
			var dims = Dom.getWH(obj.movers[i]);
			if (abs_x >= coords[0] && abs_x <= coords[0]+dims[0] &&
				abs_y >= coords[1] && abs_y <= coords[1]+dims[1]) {
				index = i;
				s_coords = coords;
				s_dims = dims;
			}
		}
		if (index == -1) for (var i=0;i<obj.dummies.length;i++) {
			var coords = Dom.position(obj.dummies[i]);
			var dims = Dom.getWH(obj.dummies[i]);
			if (abs_x >= coords[0] && abs_x <= coords[0]+dims[0] &&
				abs_y >= coords[1] && abs_y <= coords[1]+dims[1]) {
				index = i;
				s_coords = coords;
				s_dims = dims;
			}
		}
		if (index==-1) { return false; } else { return [s_coords,s_dims]; }
	}
	
	this.check = function(event) { /* mousemove routine */
		if (!obj.lock) { return; }
		var tmp = obj.getOverElm(event);
		if (!tmp) {
			obj.ghost.style.display = "none";
		} else {
			obj.ghost.style.display = "block";
			obj.ghost.style.width = (tmp[1][0] + 4) + "px";
			obj.ghost.style.height = (tmp[1][1] + 4) + "px";
			obj.ghost.style.left = (tmp[0][0] - 2) + "px";
			obj.ghost.style.top = (tmp[0][1] - 2) + "px";
		}
	}
	
	this.addObject = function(colIndex,grabber,mover) {
		var grabber_elm = $(grabber);
		var mover_elm = $(mover);
		grabber_elm.style.cursor = "pointer";
		this.movers.push(mover_elm);
		this.columns[colIndex].appendChild(mover_elm);
		var postProcess = function(elm) {
			var dim = Dom.getWH(mover_elm);
			elm.style.width = dim[0]+"px";
			elm.style.height = dim[1]+"px";
			elm.style.border = "1px solid #000";
			Dom.attach(elm,"mouseup",obj.endDrag);
		}
		var callback = function(target,x,y) { obj.move(mover_elm,target); }
		this.gd.addSource(grabber_elm,postProcess,callback);
		this.gd.addTarget(mover_elm);
		Dom.attach(grabber_elm,"mousedown",function(){obj.startDrag(mover_elm);});
		Dom.attach(grabber_elm,"mouseup",obj.endDrag);
		
	}
	
	Dom.attach(document,"mousemove",obj.check);
}
