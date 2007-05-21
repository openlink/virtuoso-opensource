/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2007 OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
	var d = new OAT.Dock(div,numColumns)
	d.addObject(colIndex, content, options)

	CSS: .dock, .dock_column_0 .. .dock_column_n-1, .dock_blank .dock_window .dock_header .dock_content
*/

OAT.DockWindow = function(content,options) {
	var self = this;
	this.options = {
		color:"#55f",
		titleColor:"#fff",
		title:"Dock window"
	}
	for (var p in options) { self.options[p] = options[p]; }
	this.state = 1;
	
	this.div = OAT.Dom.create("div",{marginBottom:"3px", border:"1px solid "+self.options.color,backgroundColor:"#fff"},"dock_window");
	
	this.header = OAT.Dom.create("div",{fontWeight:"bold",padding:"1px",color:self.options.titleColor,backgroundColor:self.options.color},"dock_header");

	this.toggle = OAT.Dom.create("div",{styleFloat:"left",cssFloat:"left",width:"16px"});
	this.toggle.innerHTML = "";
	this.headerContent = OAT.Dom.create("span");
	this.headerContent.innerHTML = self.options.title;
	
	this.content = OAT.Dom.create("div",{padding:"3px"},"dock_content");
	this.content.appendChild($(content));

	OAT.Dom.append([self.header,self.toggle,self.headerContent],[self.div,self.header,self.content]);

	/* toggling */
	this.actualizeState = function() {
		if (self.state) {
			self.toggle.innerHTML = "&ndash;";
			OAT.Dom.show(self.content);
		} else {
			self.toggle.innerHTML = "+";
			OAT.Dom.hide(self.content);
		}
	}
	
	var toggleRef = function() {
		self.state = ++self.state % 2;
		self.actualizeState();
	}
	
	var outRef = function() {
		self.toggle.innerHTML = "&#9786;";
	};	
	
	OAT.Dom.attach(self.toggle,"click",toggleRef);	
	OAT.Dom.attach(self.toggle,"mouseover",self.actualizeState);
	OAT.Dom.attach(self.toggle,"mouseout",outRef);

	this.actualizeState();
	outRef();
}

OAT.Dock = function(div,numColumns) {
	var self = this;
	this.div = $(div);
	OAT.Dom.addClass(this.div,"dock");
	this.columns = [];
	this.windows = [];
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
	
	this.startDrag = function(w) {
		self.lock = 1;
		var dims = OAT.Dom.getWH(w.div);
		for (var i=0;i<self.columns.length;i++) { 
			self.columns[i].appendChild(self.dummies[i]);
			self.dummies[i].style.height = dims[1] + "px";
		}
		
	}
	
	this.endDrag = function() {
		self.lock = 0;
		OAT.Dom.hide(self.ghost);
		/* 
			hack: 
			when we unlink dummies right after depressing mouse, 
			ghostdrag won't register a successful drop on them,
			so we have to delay it a little bit
		*/	
		var hideRef = function() {
			for (var i=0;i<self.columns.length;i++) { OAT.Dom.unlink(self.dummies[i]); }
		}
		
		/* setTimeout(hideRef,500); */ /* commenting this solved some unknown issue ;) */
	}
	
	this.move = function(mover,target) { /* finally moving the panel 'mover' to place 'target' */
		if (mover == target) { return; }
		
		/* coords */
		var oldX = self.columns.find(mover.parentNode);
		var newX = self.columns.find(target.parentNode);
		var oldY = -1;
		var newY = -1;
		var oldList = self.columns[oldX].childNodes;
		var newList = self.columns[newX].childNodes;
		for (var i=0;i<oldList.length;i++) { if (oldList[i] == mover) { oldY = i; } }
		for (var i=0;i<newList.length;i++) { if (newList[i] == target) { newY = i; } }


		/* blank place to disappear */
		var dims = OAT.Dom.getWH(mover);
		var blank = OAT.Dom.create("div");
		blank.className = "dock_blank";
		blank.style.height = dims[1]+"px";
		mover.parentNode.insertBefore(blank,mover);
		var sf = function(){OAT.Dom.unlink(blank);}
		var a = new OAT.AnimationSize(blank,{speed:5,delay:5,height:0,stopFunction:sf});
		OAT.MSG.attach(a.animation,OAT.MSG.ANIMATION_STOP,sf);
		a.start();


		/* put mover to right place */
		target.parentNode.insertBefore(mover,target);
		
		var o = {
			oldX:oldX,
			oldY:oldY,
			newX:newX,
			newY:newY
		}
		OAT.MSG.send(self,OAT.MSG.DOCK_DRAG,o);
	}
	
	this.getOverElm = function(event) {
		/* returns coordinates, dimensions */
		var exact = OAT.Dom.eventPos(event);
		var abs_x = exact[0]; /* here is the cursor */
		var abs_y = exact[1];
		var s_coords, s_dims;
		var index = -1;
		for (var i=0;i<self.windows.length;i++) {
			var coords = OAT.Dom.position(self.windows[i].div);
			var dims = OAT.Dom.getWH(self.windows[i].div);
			if (abs_x >= coords[0] && abs_x <= coords[0]+dims[0] &&
				abs_y >= coords[1] && abs_y <= coords[1]+dims[1]) {
				index = i;
				s_coords = coords;
				s_dims = dims;
			}
		}
		if (index == -1) for (var i=0;i<self.dummies.length;i++) {
			var coords = OAT.Dom.position(self.dummies[i]);
			var dims = OAT.Dom.getWH(self.dummies[i]);
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
		if (!self.lock) { return; }
		var tmp = self.getOverElm(event);
		if (!tmp) {
			OAT.Dom.hide(self.ghost);
		} else {
			OAT.Dom.show(self.ghost);
			self.ghost.style.width = (tmp[1][0] + 4) + "px";
			self.ghost.style.height = (tmp[1][1] + 4) + "px";
			self.ghost.style.left = (tmp[0][0] - 2) + "px";
			self.ghost.style.top = (tmp[0][1] - 2) + "px";
		}
	}
	
	this.addObject = function(colIndex,content,options) {
		var w = new OAT.DockWindow(content,options);
		self.windows.push(w);
		
		w.header.style.cursor = "pointer";
		this.columns[colIndex].appendChild(w.div);
		
		var postProcess = function(elm) {
			var dim = OAT.Dom.getWH(w.div);
			elm.style.width = dim[0]+"px";
			elm.style.height = dim[1]+"px";
			elm.style.border = "1px solid #000";
			OAT.Dom.attach(elm,"mouseup",self.endDrag);
		}
		
		var callback = function(target,x,y) { self.move(w.div,target); }
		this.gd.addSource(w.header,postProcess,callback);
		this.gd.addTarget(w.div);
		
		OAT.Dom.attach(w.header,"mousedown",function(){self.startDrag(w);});
		OAT.Dom.attach(w.header,"mouseup",self.endDrag);
		
	}
	
	OAT.Dom.attach(document,"mousemove",self.check);
}
OAT.Loader.featureLoaded("dock");
