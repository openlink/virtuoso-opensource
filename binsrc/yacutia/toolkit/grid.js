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
	new Grid(something,autoNumber);
	Grid.createRow(data, [index]);
	Grid.createHeader(data);
	Grid.rows[i].addCell(data, [index]);
	Grid.appendHeader(data, [index]);
	Grid.fromTable(table);
	Grid.removeColumn(index);
	Grid.clearData();
	Grid.imagesPath = "images";
	
	Grid.LIMIT
	Grid.ALIGN_CENTER
	Grid.ALIGN_LEFT
	Grid.ALIGN_RIGHT
	Grid.SORT_NONE
	Grid.SORT_ASC
	Grid.SORT_DESC
	Grid.TYPE_AUTO
	Grid.TYPE_STRING
	Grid.TYPE_NUMERIC
	
	CSS: .grid .even, .odd, .hover, .index, .header_value, .row_value
*/


var GridData = {
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
		if (GridData.resizing) {
			var obj = GridData.resizing;
			GridData.resizing = false;
			
			var w = GridData.w - 2;
			obj.header.cells[GridData.index].changeWidth(w);
			for (var i=0;i<obj.rows.length;i++) {
				obj.rows[i].cells[GridData.index].changeWidth(w);
			} /* for all rows */

			Dom.unlink(obj.tmp_resize);
			Dom.unlink(obj.tmp_resize_start);
			GridData.forbidSort = 1;
			var ref = function() { GridData.forbidSort = 0;	}
			setTimeout(ref,100);
		}
		
		if (GridData.dragging) {
			var obj = GridData.dragging;
			GridData.dragging = false;
			if (obj.tmp_drag) {
				/* reorder */
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
				
				/* we need to move GridData.index before index */
				var i1 = GridData.index;
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
				
				Dom.unlink(obj.tmp_drag);
				GridData.forbidSort = 1;
				if (obj.reorderNotifier && (i1 != i2)) { obj.reorderNotifier(i1,i2); }
				var ref = function() { GridData.forbidSort = 0;	}
				setTimeout(ref,100);
			}
		}
	}, /* GridData.up() */
	
	init:function() {
		Dom.attach(document.body,"mouseup",GridData.up);
		Dom.attach(document.body,"mousemove",GridData.move);
	},
	
	move:function(event) {
		if (GridData.resizing) {
			/* selection removal... */
			var selObj = false;
			if (document.getSelection && !Dom.isGecko()) { selObj = document.getSelection(); }
			if (window.getSelection) { selObj = window.getSelection(); }
			if (document.selection) { selObj = document.selection; }
			if (selObj) {
				if (selObj.empty) { selObj.empty(); }
				if (selObj.removeAllRanges) { selObj.removeAllRanges(); }
			}
			/* lec gou */
			var obj = GridData.resizing;
			var elm = obj.tmp_resize; /* vertical line */
			var offs_x = event.clientX - GridData.x; /* offset */
			var new_x = GridData.w + offs_x;
			if (new_x >= GridData.LIMIT) {
				elm.style.left = new_x + "px";
				GridData.w = new_x;
				GridData.x = event.clientX;
			} /* if > limit */
		} /* if resizing */
		
		if (GridData.dragging) {
			/* selection removal... */
			var selObj = false;
			if (document.getSelection && !Dom.isGecko()) { selObj = document.getSelection(); }
			if (window.getSelection) { selObj = window.getSelection(); }
			if (document.selection) { selObj = document.selection; }
			if (selObj) {
				if (selObj.empty) { selObj.empty(); }
				if (selObj.removeAllRanges) { selObj.removeAllRanges(); }
			}
			/* lec gou */
			var obj = GridData.dragging;
			if (!obj.tmp_drag) { /* just moved - create ghost */
				var container = obj.header.cells[GridData.index].container;
				obj.tmp_drag = Dom.create("div",{position:"absolute",left:"0px",top:"0px",backgroundColor:"#888",opacity:"0.5",filter:"alpha(opacity=50)"});
				obj.tmp_drag.appendChild(container.cloneNode(true));
				obj.tmp_drag.firstChild.style.width = obj.header.cells[GridData.index].html.offsetWidth+"px";
				container.appendChild(obj.tmp_drag);
				GridData.w = 0;
			}
			var offs_x = event.clientX - GridData.x;
			var new_x = GridData.w + offs_x;
			obj.tmp_drag.style.left = new_x + "px";
			GridData.x = event.clientX;
			GridData.w = new_x;
			/* signal? */
			var sig = -1;
			for (var i=0;i<obj.header.cells.length;i++) {
				var cell = obj.header.cells[i];
				var coords = Dom.position(cell.container);
				var w = cell.container.offsetWidth;
				var x = coords[0];
				if (event.clientX >= x && event.clientX <= x+w) { /* inside this header */
					if (cell.signal) { return; } /* not interesting */
					for (var i=0;i<obj.header.cells.length;i++) { if (obj.header.cells[i].signal) obj.header.cells[i].signalEnd(); }
					cell.signalStart();
				}
			}
		} /* if dragging */
	} /* GridData.move() */
} /* Grid */

function Grid(something,autoNumber) {
	this.reorderNotifier = false; /* notify app of reordering */
	this.sortFunc = false;        /* custom sorting routine */
	this.imagesPath = "images";
	
	this.div = $(something);
	Dom.clear(this.div);
	this.div.style.position = "relative";
	this.html = Dom.create("table");
	this.html.className = "grid";
	this.div.appendChild(this.html);
	this.autoNumber = (autoNumber ? 1 : 0);

	this.header = new GridHeader(this);
	this.html.appendChild(this.header.html);
	
	this.rows = [];
	this.rowBlock = Dom.create("tbody");
	this.html.appendChild(this.rowBlock);
	
	var obj = this;
	
	this.clearData = function() {
		this.rows = [];
		Dom.clear(this.rowBlock);
	}
	
	this.appendHeader = function(paramsObj,index) { /* append one header */
		var i = (!index ? this.header.cells.length : index);
		var cell = this.header.addCell(paramsObj,i);
		cell.updateWidth();
		for (var i=0;i<this.header.cells.length;i++) {
			this.header.cells[i].number = i;
		}
		return cell;
	}

	this.createHeader = function(paramsList) { /* add new header */
		this.header.clear();
		if (this.autoNumber) {
			this.header.addCell({value:"&nbsp;#&nbsp;",align:GridData.ALIGN_CENTER,type:GridData.TYPE_NUMERIC,draggable:0});
			this.header.cells[0].updateWidth();
		}
		for (var i=0;i<paramsList.length;i++) {
			this.appendHeader(paramsList[i]);
		}
	} /* Grid::createHeader */
	
	this.createRow = function(paramsList, index) { /* add new row */
		var number = this.rows.length;
		if (!index && index != 0) { index = number; }
		var row = new GridRow(obj,number);
		
		if (index == number) { 
			this.rowBlock.appendChild(row.html);
		} else {
			this.rowBlock.insertBefore(row.html,this.rowBlock.childNodes[index]);
		}

		if (this.autoNumber) {
			row.addCell({value:number+1,align:GridData.ALIGN_CENTER});
			row.cells[row.cells.length-1].classes.push("index");
			row.cells[row.cells.length-1].updateClass();
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
		if (GridData.forbidSort) { return; }
		
		if (this.sortFunc) {
			this.sortFunc(index,type);
			return;
		}
		for (var i=0;i<this.header.cells.length;i++) {
			this.header.cells[i].changeSort(GridData.SORT_NONE);
		}
		this.header.cells[index].changeSort(type);
		/* sort elements here */
		var coltype = this.header.cells[index].type;
		var c1, c2;
		switch (type) {
			case GridData.SORT_ASC: c1 = 1; c2 = -1; break;
			case GridData.SORT_DESC: c1 = -1; c2 = 1; break;
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
			case GridData.TYPE_STRING: cmp = strCmp; break;
			case GridData.TYPE_NUMERIC: cmp = numCmp; break;
			case GridData.TYPE_AUTO: cmp = (testValue == parseInt(testValue) ? numCmp : strCmp); break;
		}
		this.rows.sort(cmp);
		
		/* redo dom, odd & even */
		for (var i=0;i<this.rows.length;i++) {
			this.rowBlock.appendChild(this.rows[i].html);
			this.rows[i].classes = [];
			this.rows[i].classes.push( i % 2 ? "even" : "odd" );
			this.rows[i].updateClass();
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
		
		Dom.unlink(t);
	}
} /* Grid */

function GridHeader(obj) {
	this.obj = obj;
	this.cells = [];
	this.html = Dom.create("thead");
	this.container = Dom.create("tr");
	this.html.appendChild(this.container);
	
	this.clear = function() {
		Dom.clear(this.container);
		this.cells = [];
	}
	
	this.addCell = function(params,index) {
		var cell = new GridHeaderCell(this.obj,index,params);
		var tds = this.container.childNodes;
		
		if (tds.length && index < tds.length) {
			this.container.insertBefore(cell.html,tds[index]);
		} else { this.container.appendChild(cell.html); }
		
		this.cells.splice(index,0,cell);
		return cell;
	}
	
	this.removeColumn = function(index) {
		Dom.unlink(this.cells[index].html);
		this.cells.splice(index,1);
		for (var i=0;i<this.cells.length;i++) { this.cells[i].number = i; }
	}
} /* GridHeader */

function GridHeaderCell(obj,number,params) {
	var defaultObj = {
		value:"",
		sortable:1,
		draggable:1,
		resizable:1,
		align:GridData.ALIGN_LEFT,
		sort:GridData.SORT_NONE,
		type:GridData.TYPE_AUTO
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
		this.signalElm = Dom.create("div",{position:"absolute",width:"2px",height:(h+2)+"px",left:"-2px",top:"-1px",backgroundColor:"#f00"});
		this.container.appendChild(this.signalElm);
	}
	
	this.signalEnd = function() {
		this.signal = 0;
		Dom.unlink(this.signalElm);
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
		var path = "none";
		switch (this.sort) {
			case GridData.SORT_NONE: path = "none"; break;
			case GridData.SORT_ASC: path = "asc"; break;
			case GridData.SORT_DESC: path = "desc"; break;
		}
		this.sorter.style.backgroundImage = "url("+obj.imagesPath+"/Grid_"+path+".gif)";	
	}
	
	this.updateClass = function() {
		this.html.className = this.classes.join(" ");
	}

	this.signal = 0;
	this.classes = [];
	this.sortable = params.sortable;
	this.draggable = params.draggable;
	this.resizable = params.resizable;
	this.sort = params.sort;
	this.type = params.type;
	this.number = number;
	
	this.html = Dom.create("td"); /* cell */
	this.container = Dom.create("div"); /* cell interior */
	this.html.appendChild(this.container);

	this.value = Dom.create("div",{overflow:"hidden"});
	this.value.className = "header_value";
	this.value.innerHTML = params.value;
	this.container.appendChild(this.value); /* place for text */
	
	var cell = this;
	if (this.sortable) {
		this.html.style.cursor = "pointer";
		this.sorter = Dom.create("div",{position:"absolute",right:"0px",bottom:"2px",width:"12px",height:"12px"});
		this.container.appendChild(this.sorter);
		this.updateSortImage();
		var callback = function(event) {
			var type = GridData.SORT_NONE;
			switch (cell.sort) {
				case GridData.SORT_NONE: type = GridData.SORT_ASC; break;
				case GridData.SORT_ASC: type = GridData.SORT_DESC; break;
				case GridData.SORT_DESC: type = GridData.SORT_ASC; break;
			}
			obj.sort(cell.number,type);
		}
		Dom.attach(this.container,"click",callback);
	}

	this.container.style.position = "relative";
	if (this.resizable) {
		var mover = Dom.create("div",{width:"7px",height:"100%",position:"absolute",right:"-5px",top:"0px",cursor:"e-resize"});
		mover.style.backgroundImage = "url("+obj.imagesPath+"/Grid_none.gif)";
		this.container.appendChild(mover);
		var callback = function (event) {
			GridData.resizing = obj;
			GridData.index = cell.number;
			GridData.x = event.clientX;
			var h = obj.html.offsetHeight;
			var x = cell.container.offsetWidth+1;
			GridData.w = x;
			obj.tmp_resize = Dom.create("div",{position:"absolute",left:x+"px",top:"-1px",backgroundColor:"#f00",width:"2px",height:h+"px"});
			obj.tmp_resize_start = Dom.create("div",{position:"absolute",left:"-2px",top:"-1px",backgroundColor:"#f00",width:"2px",height:h+"px"});
			cell.container.appendChild(obj.tmp_resize);
			cell.container.appendChild(obj.tmp_resize_start);
		}
		Dom.attach(mover,"mousedown",callback);
	}
	
	if (this.draggable) {
		var callback = function(event) {
			if (GridData.resizing) { return; } /* don't drag when resizing */
			GridData.dragging = obj;
			GridData.index = cell.number;
			GridData.x = event.clientX;
			obj.tmp_drag = 0;
		}
		Dom.attach(this.container,"mousedown",callback);
	}

	switch (params.align) {
		case GridData.ALIGN_LEFT: 	this.html.style.textAlign = "left"; break;
		case GridData.ALIGN_CENTER: 	this.html.style.textAlign = "center"; break;
		case GridData.ALIGN_RIGHT: 	this.html.style.textAlign = "right"; break;
	}	
	
	var mouseover = function(event) {
		for (var i=0;i<cell.classes.length;i++) { 
			if (cell.classes[i] == "hover") { return; }
		}
		cell.classes.push("hover");
		cell.updateClass();
	}
	var mouseout = function(event) {
		for (var i=0;i<cell.classes.length;i++) {
			if (cell.classes[i] == "hover") { cell.classes.splice(i,1); }
		}
		cell.updateClass();
	}
	Dom.attach(this.html,"mouseover",mouseover);
	Dom.attach(this.html,"mouseout",mouseout);

	
} /* GridHeaderCell */

function GridRow(obj,number) {
	this.clear = function() {
		Dom.clear(this.html);
		this.cells = [];
	}
	
	this.removeColumn = function(index) {
		Dom.unlink(this.cells[index].html);
		this.cells.splice(index,1);
	}

	this.addCell = function(params,index) {
		var i = (!index ? this.cells.length : index);
		var cell = new GridRowCell(this.obj,i,params);
		var tds = this.html.childNodes;
		if (tds.length && i != tds.length) {
			this.html.insertBefore(cell.html,tds[i]);
		} else { this.html.appendChild(cell.html); }
		this.cells.splice(i,0,cell);
		return cell.value;
	}
	
	this.updateClass = function() {
		this.html.className = this.classes.join(" ");
	}

	this.obj = obj;
	this.cells = [];
	this.classes = [];
	this.html = Dom.create("tr");
	this.classes.push( number % 2 ? "even" : "odd" );
	this.updateClass();
	
	var x = this;
	
	var mouseover = function(event) {
		x.classes.push("hover");
		x.updateClass();
	}
	var mouseout = function(event) {
		for (var i=0;i<x.classes.length;i++) {
			if (x.classes[i] == "hover") { x.classes.splice(i,1); }
		}
		x.updateClass();
	}
	
	Dom.attach(this.html,"mouseover",mouseover);
	Dom.attach(this.html,"mouseout",mouseout);
	
} /* GridRow */

function GridRowCell(obj,number,params) {
	var defaultObj = {
		value:"",
		editable:0,
		align:GridData.ALIGN_LEFT
	}
	
	if (typeof(params)!="object") {
		params = {value:params}
	}
	
	for (p in defaultObj) {
		if (!(p in params)) {
			params[p] = defaultObj[p];
		}
	}
	
	this.updateClass = function() {
		this.html.className = this.classes.join(" ");
	}

	this.classes = [];
	this.html = Dom.create("td");
	this.container = Dom.create("div");
	this.html.appendChild(this.container);
	this.value = Dom.create("div",{overflow:"hidden"});
	this.value.className = "row_value";
	this.value.innerHTML = params.value;
	this.container.appendChild(this.value);
	this.html.setAttribute("title",params.value);
	
	switch (params.align) {
		case GridData.ALIGN_LEFT: this.html.style.textAlign = "left"; break;
		case GridData.ALIGN_CENTER: this.html.style.textAlign = "center"; break;
		case GridData.ALIGN_RIGHT: this.html.style.textAlign = "right"; break;
	}

	this.editable = params.editable;
	
	this.changeWidth = function(width) {
		this.value.style.width = width + "px";
	}
	
} /* GridRowCell */

Loader.loadAttacher(GridData.init);
