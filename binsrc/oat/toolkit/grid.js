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
	new OAT.Grid(something,autoNumber);
	Grid.rowOffset = 0;
	Grid.createRow(data, [index]);
	Grid.createHeader(data);
	Grid.rows[i].addCell(data, [index]);
	Grid.appendHeader(data, [index]);
	Grid.fromTable(table);
	Grid.removeColumn(index);
	Grid.clearData();
	Grid.imagesPath = "../images";
	Grid.rows[i].select()/deselect();
	
	OAT.GridData.LIMIT
	OAT.GridData.ALIGN_CENTER
	OAT.GridData.ALIGN_LEFT
	OAT.GridData.ALIGN_RIGHT
	OAT.GridData.SORT_NONE
	OAT.GridData.SORT_ASC
	OAT.GridData.SORT_DESC
	OAT.GridData.TYPE_AUTO
	OAT.GridData.TYPE_STRING
	OAT.GridData.TYPE_NUMERIC
	
	CSS: .grid .even, .odd, .hover, .index, .header_value, .row_value, .selected
*/


OAT.GridData = {
	dragging:false, /* object we are dragging */
	resizing:false, /* object we are resizing */
	index:0,        /* column in action */
	x:0,            /* actual x */
	w:0,            /* actual width */
	forbidSort:0,    /* don't sort now */
	
	LIMIT:15,       /* minimum width */
	ALIGN_CENTER:1,
	ALIGN_LEFT:2,
	ALIGN_RIGHT:3,
	SORT_NONE:1,
	SORT_ASC:2,
	SORT_DESC:3,
	TYPE_STRING:1,
	TYPE_NUMERIC:2,
	TYPE_AUTO:3,
	
	up:function(event) {
		if (OAT.GridData.resizing) {
			var obj = OAT.GridData.resizing;
			OAT.GridData.resizing = false;
			
			var w = OAT.GridData.w - 2;
			obj.header.cells[OAT.GridData.index].changeWidth(w);
			for (var i=0;i<obj.rows.length;i++) {
				obj.rows[i].cells[OAT.GridData.index].changeWidth(w);
			} /* for all rows */

			OAT.Dom.unlink(obj.tmp_resize);
			OAT.Dom.unlink(obj.tmp_resize_start);
			
			OAT.GridData.forbidSort = 1;
			var ref = function() { OAT.GridData.forbidSort = 0;	}
			setTimeout(ref,100);
		}
		
		if (OAT.GridData.dragging) {
			var obj = OAT.GridData.dragging;
			OAT.GridData.dragging = false;
			if (obj.tmp_drag) { /* reorder */
				var index = -1;
				for (var i=0;i<obj.header.cells.length;i++) {
					if (obj.header.cells[i].signal) {
						index = i;
						obj.header.cells[i].signalEnd();
					}
				}
				if (index == -1) { 
					alert('!');
				}
				
				/* we need to move OAT.GridData.index before index */
				var i1 = OAT.GridData.index;
				var i2 = index;

				obj.header.cells[i1].html.parentNode.insertBefore(obj.header.cells[i1].html,obj.header.cells[i2].html);
				var cell = obj.header.cells[i1];
				obj.header.cells.splice(i1,1);
				var newi = (i1 < i2 ? i2-1 : i2);
				obj.header.cells.splice(newi,0,cell);
				for (var i=0;i<obj.rows.length;i++) {
					obj.rows[i].cells[i1].html.parentNode.insertBefore(obj.rows[i].cells[i1].html,obj.rows[i].cells[i2].html);
					var cell = obj.rows[i].cells[i1];
					obj.rows[i].cells.splice(i1,1);
					obj.rows[i].cells.splice(newi,0,cell);
				}
				
				for (var i=0;i<obj.header.cells.length;i++) {
					obj.header.cells[i].number = i;
				}
				
				OAT.Dom.unlink(obj.tmp_drag);
				OAT.GridData.forbidSort = 1;
				if (obj.reorderNotifier && (i1 != i2)) { obj.reorderNotifier(i1,i2); }
				var ref = function() { OAT.GridData.forbidSort = 0;	}
				setTimeout(ref,100);
			}
		}
	}, /* OAT.GridData.up() */
	
	move:function(event) {
		if (OAT.GridData.resizing) {
			/* selection removal... */
			var selObj = false;
			if (document.getSelection && !OAT.Dom.isGecko()) { selObj = document.getSelection(); }
			if (window.getSelection) { selObj = window.getSelection(); }
			if (document.selection) { selObj = document.selection; }
			if (selObj) {
				if (selObj.empty) { selObj.empty(); }
				if (selObj.removeAllRanges) { selObj.removeAllRanges(); }
			}
			/* lec gou */
			var obj = OAT.GridData.resizing;
			var elm = obj.tmp_resize; /* vertical line */
			var offs_x = event.clientX - OAT.GridData.x; /* offset */
			var new_x = OAT.GridData.w + offs_x;
			if (new_x >= OAT.GridData.LIMIT) {
				elm.style.left = new_x + "px";
				OAT.GridData.w = new_x;
				OAT.GridData.x = event.clientX;
			} /* if > limit */
		} /* if resizing */
		
		if (OAT.GridData.dragging) {
			/* selection removal... */
			var selObj = false;
			if (document.getSelection && !OAT.Dom.isGecko()) { selObj = document.getSelection(); }
			if (window.getSelection) { selObj = window.getSelection(); }
			if (document.selection) { selObj = document.selection; }
			if (selObj) {
				if (selObj.empty) { selObj.empty(); }
				if (selObj.removeAllRanges) { selObj.removeAllRanges(); }
			}
			/* lec gou */
			var obj = OAT.GridData.dragging;
			if (!obj.tmp_drag) { /* just moved - create ghost */
				var container = obj.header.cells[OAT.GridData.index].container;
				obj.tmp_drag = OAT.Dom.create("div",{position:"absolute",left:"0px",top:"0px",backgroundColor:"#888",opacity:"0.5",filter:"alpha(opacity=50)"});
				obj.tmp_drag.appendChild(container.cloneNode(true));
				obj.tmp_drag.firstChild.style.width = obj.header.cells[OAT.GridData.index].html.offsetWidth+"px";
				container.appendChild(obj.tmp_drag);
				OAT.GridData.w = 0;
			}
			var offs_x = event.clientX - OAT.GridData.x;
			var new_x = OAT.GridData.w + offs_x;
			obj.tmp_drag.style.left = new_x + "px";
			OAT.GridData.x = event.clientX;
			OAT.GridData.w = new_x;
			/* signal? */
			var sig = -1;
			for (var i=0;i<obj.header.cells.length;i++) {
				var cell = obj.header.cells[i];
				var coords = OAT.Dom.position(cell.container);
				var w = cell.container.offsetWidth;
				var x = coords[0];
				if (event.clientX >= x && event.clientX <= x+w) { /* inside this header */
					if (cell.signal) { return; } /* not interesting */
					for (var i=0;i<obj.header.cells.length;i++) { if (obj.header.cells[i].signal) obj.header.cells[i].signalEnd(); }
					cell.signalStart();
				}
			}
		} /* if dragging */
	} /* OAT.GridData.move() */
} /* GridData */

OAT.Grid = function(something,autoNumber,allowHiding) {
	var self = this;

	this.reorderNotifier = false; /* notify app of reordering */
	this.sortFunc = false;        /* custom sorting routine */
	this.imagesPath = "../images";
	this.rowOffset = 0;
	this.allowHiding = allowHiding;
	this.autoNumber = (autoNumber ? 1 : 0);
	
	this.div = $(something);
	OAT.Dom.clear(this.div);
	if (this.allowHiding) { /* column hiding */
		var hide = OAT.Dom.create("a");
		hide.href = "#";
		hide.innerHTML = "visible columns";
		this.div.appendChild(hide);
		this.propPage = OAT.Dom.create("div",{position:"absolute",border:"2px solid #000",padding:"2px",backgroundColor:"#fff"});
		this.propPage.style.paddingRight = "16px";
		document.body.appendChild(this.propPage);
		OAT.Instant.assign(this.propPage);
		var refresh = function() {
			self.propPage._Instant_hide();
		}
		var generatePair = function(index) {
			var state = (self.header.cells[index].html.style.display != "none");
			var pair = OAT.Dom.create("div");
			var ch = OAT.Dom.create("input");
			ch.type = "checkbox";
			ch.checked = (state ? true : false);
			ch.__checked = (state ? "1" : "0");
			pair.appendChild(ch);
			var val = self.header.cells[index].value.innerHTML;
			pair.appendChild(OAT.Dom.text(" "+val));
			OAT.Dom.attach(ch,"change",function(){
				var newdisp = (self.header.cells[index].html.style.display == "none" ? "" : "none");
				self.header.cells[index].html.style.display = newdisp;
				for (var i=0;i<self.rows.length;i++) {
					self.rows[i].cells[index].html.style.display = newdisp;
				}
			});
			return pair;
		}
		var clickRef =  function(event) {
			var coords = OAT.Dom.eventPos(event);
			self.propPage.style.left = coords[0] + "px";
			self.propPage.style.top = coords[1] + "px";
			OAT.Dom.clear(self.propPage);
			/* contents */
			var close = OAT.Dom.create("div",{position:"absolute",top:"3px",right:"3px",cursor:"pointer"});
			close.innerHTML = "X";
			OAT.Dom.attach(close,"click",refresh);
			self.propPage.appendChild(close);
			var start = (self.autoNumber ? 1 : 0);
			for (var i=start;i<self.header.cells.length;i++) {
				var pair = generatePair(i);
				self.propPage.appendChild(pair);
			}
			self.propPage._Instant_show();
		} /* clickref */
		OAT.Dom.attach(hide,"click",clickRef);
	} /* if allowHiding */
	this.div.style.position = "relative";
	this.html = OAT.Dom.create("table");
	OAT.Dom.addClass(this.html,"grid");
	this.div.appendChild(this.html);

	this.header = new OAT.GridHeader(this);
	this.html.appendChild(this.header.html);
	
	this.rows = [];
	this.rowBlock = OAT.Dom.create("tbody");
	this.html.appendChild(this.rowBlock);
	
	var obj = this;
	var self = this;
	
	this.clearData = function() {
		self.rows = [];
		OAT.Dom.clear(self.rowBlock);
	}
	
	this.appendHeader = function(paramsObj,index) { /* append one header */
		var i = (!index ? this.header.cells.length : index);
		var cell = this.header.addCell(paramsObj,i);
//		cell.updateWidth();
		for (var i=0;i<this.header.cells.length;i++) {
			this.header.cells[i].number = i;
		}
		return cell;
	}
	
	this.ieFix = function() {
		for (var i=0;i<self.header.cells.length;i++) {
			var html = self.header.cells[i].html;
			OAT.Dom.addClass(html,"hover");
			OAT.Dom.removeClass(html,"hover");
			var value = self.header.cells[i].value;
			var dims = OAT.Dom.getWH(value);
			value.style.width = dims[0]+"px";
		}
	}

	this.createHeader = function(paramsList) { /* add new header */
		this.header.clear();
		if (this.autoNumber) {
			var cell = this.header.addCell({value:"&nbsp;#&nbsp;",align:OAT.GridData.ALIGN_CENTER,type:OAT.GridData.TYPE_NUMERIC,draggable:0,sortable:0});
			var click = function() {
				/* select all */
				for (var i=0;i<self.rows.length;i++) { self.rows[i].select(); }
			}
			OAT.Dom.attach(cell.html,"click",click);
		}
		for (var i=0;i<paramsList.length;i++) {
			this.appendHeader(paramsList[i]);
		}
		for (var i=0;i<this.header.cells.length;i++) { this.header.cells[i].updateWidth(); }
	} /* Grid::createHeader */
	
	this.createRow = function(paramsList, index) { /* add new row */
		var number = this.rows.length;
		if (!index) { index = number; }
		var row = new OAT.GridRow(obj,number);
		
		if (index == number) { 
			this.rowBlock.appendChild(row.html);
		} else {
			this.rowBlock.insertBefore(row.html,this.rowBlock.childNodes[index]);
		}

		if (this.autoNumber) {
			row.addCell({value:self.rowOffset+number+1,align:OAT.GridData.ALIGN_CENTER});
			OAT.Dom.addClass(row.cells[0].html,"index");
		} 

		for (var i=0;i<paramsList.length;i++) {
			row.addCell(paramsList[i]);
		}
		this.rows.splice(index,0,row);
		return row.html;
	} /* Grid::createRow() */
	
	this.removeColumn = function(index) {
		this.header.removeColumn(index);
		for (var i=0;i<this.rows.length;i++) { this.rows[i].removeColumn(index); }
	}
	
	this.sort = function(index,type) {
		if (OAT.GridData.forbidSort) { return; }
		
		if (this.sortFunc) {
			this.sortFunc(index,type);
			return;
		}
		for (var i=0;i<this.header.cells.length;i++) {
			this.header.cells[i].changeSort(OAT.GridData.SORT_NONE);
		}
		this.header.cells[index].changeSort(type);
		/* sort elements here */
		var coltype = this.header.cells[index].type;
		var c1, c2;
		switch (type) {
			case OAT.GridData.SORT_ASC: c1 = 1; c2 = -1; break;
			case OAT.GridData.SORT_DESC: c1 = -1; c2 = 1; break;
		}
		var numCmp = function(row_a,row_b) {
			var a = row_a.cells[index].value.innerHTML;
			var b = row_b.cells[index].value.innerHTML;
			if (a == b) { return 0; }
			return (parseInt(a) > parseInt(b) ? c1 : c2);
		}
		var strCmp = function(row_a,row_b) {
			var a = row_a.cells[index].value.innerHTML;
			var b = row_b.cells[index].value.innerHTML;
			if (a == b) { return 0; }
			return (a > b ? c1 : c2);
		}
		var cmp;
		var testValue = this.rows[0].cells[index].value.innerHTML;
		switch (coltype) {
			case OAT.GridData.TYPE_STRING: cmp = strCmp; break;
			case OAT.GridData.TYPE_NUMERIC: cmp = numCmp; break;
			case OAT.GridData.TYPE_AUTO: cmp = (testValue == parseInt(testValue) ? numCmp : strCmp); break;
		}
		this.rows.sort(cmp);
		
		/* redo dom, odd & even */
		for (var i=0;i<this.rows.length;i++) {
			this.rowBlock.appendChild(this.rows[i].html);
			var h = this.rows[i].html;
			OAT.Dom.removeClass(h,"even");
			OAT.Dom.removeClass(h,"odd");
			OAT.Dom.addClass(this.rows[i].html,( i % 2 ? "even" : "odd" ));
		}
	} /* Grid::sort() */

	this.fromTable = function(something) {
		var t = $(something);
		var head = t.getElementsByTagName("thead")[0];
		var body = t.getElementsByTagName("tbody")[0];
		var tmp = [];
		var cells = head.getElementsByTagName("td");
		for (var i=0;i<cells.length;i++) { tmp.push(cells[i].innerHTML); }
		this.createHeader(tmp);
		
		var rows = body.getElementsByTagName("tr");
		for (var i=0;i<rows.length;i++) { 
			tmp = [];
			var cells = rows[i].getElementsByTagName("td");
			for (var j=0;j<cells.length;j++) { tmp.push(cells[j].innerHTML); }
			this.createRow(tmp);
		}
		
		OAT.Dom.unlink(t);
	}
	
	this.toXML = function(ignoreSelection) {
		if (ignoreSelection) { return self.div.innerHTML; }
		var xhtml = '<table class="grid"><thead>';
		xhtml += self.header.html.innerHTML;
		xhtml += '</thead><tbody>';
		for (var i=0;i<self.rows.length;i++) if (self.rows[i].selected) {
			var r = self.rows[i];
			xhtml += '<tr>'+r.html.innerHTML+'</tr>';
		}
		xhtml += '</tbody></table>';
		return xhtml;
	}
} /* Grid */

OAT.GridHeader = function(obj) {
	this.obj = obj;
	this.cells = [];
	this.html = OAT.Dom.create("thead");
	this.container = OAT.Dom.create("tr");
	this.html.appendChild(this.container);
	
	this.clear = function() {
		OAT.Dom.clear(this.container);
		this.cells = [];
	}
	
	this.addCell = function(params,index) {
		var cell = new OAT.GridHeaderCell(this.obj,index,params);
		var tds = this.container.childNodes;
		
		if (tds.length && index < tds.length) {
			this.container.insertBefore(cell.html,tds[index]);
		} else { this.container.appendChild(cell.html); }
		
		this.cells.splice(index,0,cell);
		return cell;
	}
	
	this.removeColumn = function(index) {
		OAT.Dom.unlink(this.cells[index].html);
		this.cells.splice(index,1);
		for (var i=0;i<this.cells.length;i++) { this.cells[i].number = i; }
	}
} /* GridHeader */

OAT.GridHeaderCell = function(obj,number,params) {
	var self = this;
	var defaultObj = {
		value:"",
		sortable:1,
		draggable:1,
		resizable:1,
		align:OAT.GridData.ALIGN_LEFT,
		sort:OAT.GridData.SORT_NONE,
		type:OAT.GridData.TYPE_AUTO
	}
	
	if (typeof(params)=="string") {
		params = {value:params}
	}
	
	for (p in defaultObj) {
		if (!(p in params)) {
			params[p] = defaultObj[p];
		}
	}
	
	this.signalStart = function() {
		this.signal = 1;
		var h = this.container.offsetHeight;
		this.signalElm = OAT.Dom.create("div",{position:"absolute",width:"2px",height:(h+2)+"px",left:"-2px",top:"-1px",backgroundColor:"#f00"});
		this.container.appendChild(this.signalElm);
	}
	
	this.signalEnd = function() {
		this.signal = 0;
		OAT.Dom.unlink(this.signalElm);
	}
	
	this.changeWidth = function(width) {
		this.value.style.width = width + "px";
	}
	
	this.updateWidth = function() {
		if (this.sortable) {
			this.value.style.width = (this.value.offsetWidth + 14) + "px";
		}
	}
	
	this.changeSort = function(type) {
		this.sort = type;
		this.updateSortImage();
	}

	this.updateSortImage = function() {
		if (!self.sorter) { return; }
		var path = "none";
		switch (self.sort) {
			case OAT.GridData.SORT_NONE: path = "none"; break;
			case OAT.GridData.SORT_ASC: path = "asc"; break;
			case OAT.GridData.SORT_DESC: path = "desc"; break;
		}
		self.sorter.style.backgroundImage = "url("+obj.imagesPath+"/Grid_"+path+".gif)";	
	}
	
	this.signal = 0;
	this.sortable = params.sortable;
	this.draggable = params.draggable;
	this.resizable = params.resizable;
	this.sort = params.sort;
	this.type = params.type;
	this.number = number;
	
	this.html = OAT.Dom.create("td"); /* cell */
	this.container = OAT.Dom.create("div"); /* cell interior */
	this.html.appendChild(this.container);

	this.value = OAT.Dom.create("div",{overflow:"hidden"});
	OAT.Dom.addClass(this.value,"header_value");
	this.value.innerHTML = params.value;
	this.container.appendChild(this.value); /* place for text */
	
	if (this.sortable) {
		this.html.style.cursor = "pointer";
		this.sorter = OAT.Dom.create("div",{position:"absolute",right:"0px",bottom:"2px",width:"12px",height:"12px"});
		this.container.appendChild(this.sorter);
		this.updateSortImage();
		var callback = function(event) {
			var type = OAT.GridData.SORT_NONE;
			switch (self.sort) {
				case OAT.GridData.SORT_NONE: type = OAT.GridData.SORT_ASC; break;
				case OAT.GridData.SORT_ASC: type = OAT.GridData.SORT_DESC; break;
				case OAT.GridData.SORT_DESC: type = OAT.GridData.SORT_ASC; break;
			}
			obj.sort(self.number,type);
		}
		OAT.Dom.attach(this.container,"click",callback);
	}

	this.container.style.position = "relative";
	if (this.resizable) {
		var mover = OAT.Dom.create("div",{width:"7px",height:"100%",position:"absolute",right:"-5px",top:"0px",cursor:"e-resize"});
		mover.style.backgroundImage = "url("+obj.imagesPath+"/Grid_none.gif)";
		this.container.appendChild(mover);
		var callback = function (event) {
			var pos = OAT.Dom.eventPos(event);
			OAT.GridData.resizing = obj;
			OAT.GridData.index = self.number;
			OAT.GridData.x = pos[0];
			var h = obj.html.offsetHeight;
			var x = self.container.offsetWidth+1;
			OAT.GridData.w = x;
			obj.tmp_resize = OAT.Dom.create("div",{position:"absolute",left:x+"px",top:"-1px",backgroundColor:"#f00",width:"2px",height:h+"px"});
			obj.tmp_resize_start = OAT.Dom.create("div",{position:"absolute",left:"-2px",top:"-1px",backgroundColor:"#f00",width:"2px",height:h+"px"});
			self.container.appendChild(obj.tmp_resize);
			self.container.appendChild(obj.tmp_resize_start);
		}
		OAT.Dom.attach(mover,"mousedown",callback);
	}
	
	if (this.draggable) {
		var callback = function(event) {
			if (OAT.GridData.resizing) { return; } /* don't drag when resizing */
			OAT.GridData.dragging = obj;
			OAT.GridData.index = self.number;
			OAT.GridData.x = event.clientX;
			obj.tmp_drag = 0;
		}
		OAT.Dom.attach(this.container,"mousedown",callback);
	}

	switch (params.align) {
		case OAT.GridData.ALIGN_LEFT: 	this.html.style.textAlign = "left"; break;
		case OAT.GridData.ALIGN_CENTER: 	this.html.style.textAlign = "center"; break;
		case OAT.GridData.ALIGN_RIGHT: 	this.html.style.textAlign = "right"; break;
	}	
	
	var mouseover = function(event) {
		OAT.Dom.addClass(self.html,"hover");
	}
	var mouseout = function(event) {
		OAT.Dom.removeClass(self.html,"hover");
	}
	OAT.Dom.attach(this.html,"mouseover",mouseover);
	OAT.Dom.attach(this.html,"mouseout",mouseout);

	
} /* GridHeaderCell */

OAT.GridRow = function(obj,number) {
	var self = this;

	this.clear = function() {
		OAT.Dom.clear(this.html);
		this.cells = [];
	}
	
	this.removeColumn = function(index) {
		OAT.Dom.unlink(this.cells[index].html);
		this.cells.splice(index,1);
	}

	this.addCell = function(params,index) {
		var i = (!index ? this.cells.length : index);
		var cell = new OAT.GridRowCell(this.obj,i,params);
		var tds = this.html.childNodes;
		if (tds.length && i != tds.length) {
			this.html.insertBefore(cell.html,tds[i]);
		} else { this.html.appendChild(cell.html); }
		this.cells.splice(i,0,cell);
		return cell.value;
	}
	
	this.select = function() {
		self.selected = 1;
		OAT.Dom.addClass(self.html,"selected");
	}
	
	this.deselect = function() {
		self.selected = 0;
		OAT.Dom.removeClass(self.html,"selected");
	}
	
	this.obj = obj;
	this.cells = [];
	this.html = OAT.Dom.create("tr");
	this.selected = 0;
	
	OAT.Dom.addClass(this.html,( number % 2 ? "even" : "odd" ));
	
	var mouseover = function(event) {
		OAT.Dom.addClass(self.html,"hover");
	}
	var mouseout = function(event) {
		OAT.Dom.removeClass(self.html,"hover");
	}
	var click = function(event) {
		if (!event.shiftKey && !event.ctrlKey) {
			/* deselect all */
			for (var i=0;i<self.obj.rows.length;i++) {
				var r = self.obj.rows[i];
				if (r != self) { r.deselect(); }
			}
		}
		if (event.shiftKey) {
			/* select all above */
			var firstAbove = -1;
			var lastBelow = -1;
			var done = 0;
			for (var i=0;i<self.obj.rows.length;i++) {
				var r = self.obj.rows[i];
				if (r != self) { 
					if (!done && r.selected) { firstAbove = i; } /* first selected above */
					if (!done && firstAbove != -1) { r.select(); }
					if (done && r.selected) { lastBelow = i; } /* last selected below */
				} else {
					done = 1;
				}
			} /* all rows */
			/* if none are above, then try below */
			if (firstAbove == -1 && lastBelow != -1) {
				var done = 0;
				for (var i=0;i<self.obj.rows.length;i++) {
					var r = self.obj.rows[i];
					if (r == self) { done = 1; }
					if (done && r != self && i < lastBelow) { r.select(); }
				} /* all rows */
			} /* below */
		} /* if shift */
		
		self.selected ? self.deselect() : self.select();
	}
	
	OAT.Dom.attach(this.html,"mouseover",mouseover);
	OAT.Dom.attach(this.html,"mouseout",mouseout);
	OAT.Dom.attach(this.html,"click",click);
	
} /* GridRow */

OAT.GridRowCell = function(obj,number,params) {
	var defaultObj = {
		value:"",
		editable:0,
		align:OAT.GridData.ALIGN_LEFT
	}
	
	if (typeof(params)!="object") {
		params = {value:params}
	}
	
	for (p in defaultObj) {
		if (!(p in params)) {
			params[p] = defaultObj[p];
		}
	}
	
	this.html = OAT.Dom.create("td");
	this.container = OAT.Dom.create("div");
	this.html.appendChild(this.container);
	this.value = OAT.Dom.create("div",{overflow:"hidden"});
	OAT.Dom.addClass(this.value,"row_value");
	this.value.innerHTML = params.value;
	this.container.appendChild(this.value);
	this.html.setAttribute("title",params.value);
	
	switch (params.align) {
		case OAT.GridData.ALIGN_LEFT: this.html.style.textAlign = "left"; break;
		case OAT.GridData.ALIGN_CENTER: this.html.style.textAlign = "center"; break;
		case OAT.GridData.ALIGN_RIGHT: this.html.style.textAlign = "right"; break;
	}

	this.editable = params.editable;
	
	this.changeWidth = function(width) {
		this.value.style.width = width + "px";
	}
	
} /* GridRowCell */

OAT.Dom.attach(document,"mouseup",OAT.GridData.up);
OAT.Dom.attach(document,"mousemove",OAT.GridData.move);
OAT.Loader.pendingCount--;
