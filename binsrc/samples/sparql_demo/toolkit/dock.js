/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2006 Ondrej Zara and OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
	var d = new OAT.Dock(numColumns)
	document.body.appendChild(d.div)
	d.addObject(colIndex, grabber, mover)

	CSS: .dock, .dock_column_0 .. .dock_column_n-1, .dock_blank
*/

OAT.Dock = function(numColumns) {
	var obj = this;
	this.div = OAT.Dom.create("div");
	this.div.className = "dock";
	this.columns = [];
	this.movers = [];
	this.dummies = [];
	this.gd = new OAT.GhostDrag();
	this.ghost = OAT.Dom.create("div",{border:"1px dashed #000",position:"absolute",display:"none"});
	document.body.appendChild(this.ghost);
	this.lock = 0;
	for (var i=0;i<numColumns;i++) {
		var col = OAT.Dom.create("div");
		col.className = "dock_column_"+i;
		this.columns.push(col);
		this.div.appendChild(col);
		var dummie = OAT.Dom.create("div",{border:"none",margin:"0px",padding:"0px",backgroundColor:"transparent"});
		this.dummies.push(dummie);
		this.gd.addTarget(dummie);
	}
	
	this.startDrag = function(elm) {
		obj.lock = 1;
		var dims = OAT.Dom.getWH(elm);
		for (var i=0;i<obj.columns.length;i++) { 
			obj.columns[i].appendChild(obj.dummies[i]);
			obj.dummies[i].style.height = dims[1] + "px";
		}
		
	}
	
	this.endDrag = function() {
		obj.lock = 0;
		OAT.Dom.hide(obj.ghost);
		/* 
			hack: 
			when we unlink dummies right after depressing mouse, 
			ghostdrag won't register a successful drop on them,
			so we have to delay it a little bit
		*/	
		var hideRef = function() {
			for (var i=0;i<obj.columns.length;i++) { OAT.Dom.unlink(obj.dummies[i]); }
		}
		setTimeout(hideRef,500); 
	}
	
	this.move = function(mover,target) { /* finally moving the panel 'mover' to place 'target' */
		if (mover == target) { return; }
		
		/* blank place to disappear */
		var dims = OAT.Dom.getWH(mover);
		var blank = OAT.Dom.create("div");
		blank.className = "dock_blank";
		blank.style.height = dims[1]+"px";
		mover.parentNode.insertBefore(blank,mover);
		var as = OAT.AnimationStructure.generate(blank,OAT.AnimationData.RESIZE,{w:dims[0],h:0,dist:5})
		var a = new OAT.Animation(as,5);
		a.endFunction = function(){OAT.Dom.unlink(blank);}
		a.start();

		/* put mover to right place */
		target.parentNode.insertBefore(mover,target);
	}
	
	this.getOverElm = function(event) {
		/* returns coordinates, dimensions */
		var exact = OAT.Dom.eventPos(event);
		var abs_x = exact[0]; /* here is the cursor */
		var abs_y = exact[1];
		var s_coords, s_dims;
		var index = -1;
		for (var i=0;i<obj.movers.length;i++) {
			var coords = OAT.Dom.position(obj.movers[i]);
			var dims = OAT.Dom.getWH(obj.movers[i]);
			if (abs_x >= coords[0] && abs_x <= coords[0]+dims[0] &&
				abs_y >= coords[1] && abs_y <= coords[1]+dims[1]) {
				index = i;
				s_coords = coords;
				s_dims = dims;
			}
		}
		if (index == -1) for (var i=0;i<obj.dummies.length;i++) {
			var coords = OAT.Dom.position(obj.dummies[i]);
			var dims = OAT.Dom.getWH(obj.dummies[i]);
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
			OAT.Dom.hide(obj.ghost);
		} else {
			OAT.Dom.show(obj.ghost);
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
			var dim = OAT.Dom.getWH(mover_elm);
			elm.style.width = dim[0]+"px";
			elm.style.height = dim[1]+"px";
			elm.style.border = "1px solid #000";
			OAT.Dom.attach(elm,"mouseup",obj.endDrag);
		}
		var callback = function(target,x,y) { obj.move(mover_elm,target); }
		this.gd.addSource(grabber_elm,postProcess,callback);
		this.gd.addTarget(mover_elm);
		OAT.Dom.attach(grabber_elm,"mousedown",function(){obj.startDrag(mover_elm);});
		OAT.Dom.attach(grabber_elm,"mouseup",obj.endDrag);
		
	}
	
	OAT.Dom.attach(document,"mousemove",obj.check);
}
OAT.Loader.pendingCount--;
