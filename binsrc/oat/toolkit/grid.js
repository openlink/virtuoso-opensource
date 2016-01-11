/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2016 OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
	new OAT.Grid(something,optObj);
	optObj = {
		autoNumber:false,
		allowHiding:false,
		rowOffset:0,
		sortFunc:false,
		imagePath:OAT.Preferences.imagePath
	}
	Grid.createRow(data, [index]); - one row
	Grid.createHeader(data); - one header row
	Grid.rows[i].addCell(data, [index]); - one standard cell
	Grid.appendHeader(data, [index]); - one header cell
	Grid.fromTable(table);
	Grid.removeColumn(index); - remove column
	Grid.clearData();
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
			var grid = OAT.GridData.resizing;
			OAT.GridData.resizing = false;
			grid.header.cells[OAT.GridData.index].changeWidth(OAT.GridData.w);
			for (var i=0;i<grid.rows.length;i++) {
				grid.rows[i].cells[OAT.GridData.index].changeWidth(OAT.GridData.w);
			} /* for all rows */

			OAT.Dom.unlink(grid.tmp_resize);
			OAT.Dom.unlink(grid.tmp_resize_start);

			OAT.GridData.forbidSort = 1;
			var ref = function() { OAT.GridData.forbidSort = 0;	}
			setTimeout(ref,100);
		}

		if (OAT.GridData.dragging) {
			var grid = OAT.GridData.dragging;
			OAT.GridData.dragging = false;
			if (grid.tmp_drag) { /* reorder */
				var index = -1;
				for (var i=0;i<grid.header.cells.length;i++) {
					if (grid.header.cells[i].signal) {
						index = i;
						grid.header.cells[i].signalEnd();
					}
				}
				if (index == -1) { return; } /* nothing signaled? wtf? */

				/* we need to move OAT.GridData.index before index */
				var i1 = OAT.GridData.index;
				var i2 = index;

				grid.header.cells[i1].html.parentNode.insertBefore(grid.header.cells[i1].html,grid.header.cells[i2].html);
				var cell = grid.header.cells[i1];
				grid.header.cells.splice(i1,1);
				var newi = (i1 < i2 ? i2-1 : i2);
				grid.header.cells.splice(newi,0,cell);
				for (var i=0;i<grid.rows.length;i++) {
					grid.rows[i].cells[i1].html.parentNode.insertBefore(grid.rows[i].cells[i1].html,grid.rows[i].cells[i2].html);
					var cell = grid.rows[i].cells[i1];
					grid.rows[i].cells.splice(i1,1);
					grid.rows[i].cells.splice(newi,0,cell);
				}

				for (var i=0;i<grid.header.cells.length;i++) { grid.header.cells[i].number = i; } /* renumber */

				OAT.Dom.unlink(grid.tmp_drag);
				OAT.GridData.forbidSort = 1;
				if (grid.options.reorderNotifier && (i1 != i2)) { grid.options.reorderNotifier(i1,i2); }
				var ref = function() { OAT.GridData.forbidSort = 0;	}
				setTimeout(ref,100);
			}
		}
	}, /* OAT.GridData.up() */

	move:function(event) {
		if (OAT.GridData.resizing) {
			OAT.Dom.removeSelection(); /* selection removal... */
			var grid = OAT.GridData.resizing;
			var elm = grid.tmp_resize; /* vertical line */
			var pos = OAT.Event.position(event);
			var offs_x = pos[0] - OAT.GridData.mouseX; /* offset */
			var new_x = OAT.GridData.w + offs_x;
			if (new_x >= OAT.GridData.LIMIT) {
				OAT.GridData.w = new_x;
				OAT.GridData.x += offs_x; /* line position */
				OAT.GridData.mouseX = pos[0];
				elm.style.left = OAT.GridData.x + "px";
			} /* if > limit */
		} /* if resizing */

		if (OAT.GridData.dragging) {
			OAT.Dom.removeSelection(); /* selection removal... */
			var grid = OAT.GridData.dragging;
			if (!grid.tmp_drag) { /* just moved - create ghost */
				var container = grid.header.cells[OAT.GridData.index].container;
				grid.tmp_drag = OAT.Dom.create("div",{position:"absolute",left:"0px",top:"0px",backgroundColor:"#888"});
				OAT.Style.set(grid.tmp_drag,{opacity:0.5});
				grid.tmp_drag.appendChild(container.cloneNode(true));
				var dims = OAT.Dom.getWH(grid.header.cells[OAT.GridData.index].html);
				grid.tmp_drag.firstChild.style.width = dims[0]+"px";
				container.appendChild(grid.tmp_drag);
				OAT.GridData.w = 0;
			}
			var pos = OAT.Event.position(event);
			var offs_x = pos[0] - OAT.GridData.x;
			var new_x = OAT.GridData.w + offs_x;
			grid.tmp_drag.style.left = new_x + "px";
			OAT.GridData.x = pos[0];
			OAT.GridData.w = new_x;
			/* signal? */
			var sig = -1;
			for (var i=0;i<grid.header.cells.length;i++) {
				var cell = grid.header.cells[i];
				var coords = OAT.Dom.position(cell.container);
				var dims = OAT.Dom.getWH(cell.container)
				var x = coords[0];
				/* IE7 has a *wrong* value of offsetLeft, so we have to do a small hack here */
				if (OAT.Browser.isIE7) { x -= OAT.Dom.position(cell.container.offsetParent)[0]; }
				if (pos[0] >= x && pos[0] <= x+dims[0]) { /* inside this header */
					if (cell.signal) { return; } /* already in */
					for (var i=0;i<grid.header.cells.length;i++) { if (grid.header.cells[i].signal) grid.header.cells[i].signalEnd(); }
					cell.signalStart();
				} /* if inside some header */
			} /* for all cells */
		} /* if dragging */
	} /* OAT.GridData.move() */
} /* GridData */

/**
 * @class Advanced grid (table) control.
 * @message GRID_ROWCLICK row clicked
 * @message GRID_CELLCLICK cell clicked
 */
OAT.Grid = function(element,optObj,allowHiding /* OBSOLETE! */) {
	var self = this;
	this.options = {
		autoNumber:false,
		allowHiding:false,
		rowOffset:0,
		sortFunc:false,
		imagePath:OAT.Preferences.imagePath,
		reorderNotifier:false
	}
	if (typeof(optObj) == "object") {
		for (var p in optObj) { self.options[p] = optObj[p]; }
	} else {
		self.options.autoNumber = optObj;
	}
	if (allowHiding) { self.options.allowHiding = true; }

	this.div = $(element);

	/**
	 * create table, header, initialize properties
	 */
	this._init = function() {
		/* column hiding */
		if (self.options.allowHiding) {
			var hide = OAT.Dom.create("a");
			hide.href = "#";
			hide.innerHTML = "visible columns";
			self.div.appendChild(hide);
			self.propPage = OAT.Dom.create("div",{padding:"5px"});
			OAT.Anchor.assign(hide, {	title:"Visible columns",
							content:self.propPage,
							result_control:false,
							activation:"click",
							type:OAT.Win.Rect,
							width:75
				} );
			var refresh = function() { self.propPage._Instant_hide(); }
			var generatePair = function(index) {
				var state = (self.header.cells[index].html.style.display != "none");
				var pair = OAT.Dom.create("div");
				var ch = OAT.Dom.create("input");
				ch.type = "checkbox";
				ch.checked = (state ? true : false);
				ch.__checked = (state ? "1" : "0");
				pair.appendChild(ch);
				var span  = OAT.Dom.create("span");
				span.innerHTML = " "+self.header.cells[index].value.innerHTML;
				pair.appendChild(span);
				OAT.Event.attach(ch,"change",function(){
					var newdisp = (self.header.cells[index].html.style.display == "none" ? "" : "none");
					self.header.cells[index].html.style.display = newdisp;
					for (var i=0;i<self.rows.length;i++) {
						self.rows[i].cells[index].html.style.display = newdisp;
					}
				});
				return pair;
			}
			var clickRef =  function(event) {
				var coords = OAT.Event.position(event);
				self.propPage.style.left = coords[0] + "px";
				self.propPage.style.top = coords[1] + "px";
				OAT.Dom.clear(self.propPage);
				/* contents */
				var start = (self.autoNumber ? 1 : 0);
				for (var i=start;i<self.header.cells.length;i++) {
					var pair = generatePair(i);
					self.propPage.appendChild(pair);
				}
			} /* clickref */
			OAT.Event.attach(hide,"click",clickRef);
		} /* if allowHiding */

		OAT.Dom.makePosition(self.div);
		self.html = OAT.Dom.create("table");
		OAT.Dom.addClass(self.html,"grid");
		self.header = new OAT.GridHeader(self);
		self.rows = [];
		self.rowBlock = OAT.Dom.create("tbody");
		OAT.Dom.append([self.div,self.html],[self.html,self.header.html,self.rowBlock]);
	}

	/**
	 * clears all inner data (preserves headers)
	 */
	this.clearData = function() {
		self.rows = [];
		OAT.Dom.clear(self.rowBlock);
	}

	/**
	 * adds new table header row
	 * @param {array} paramsObj column header contents
	 * @param {integer} index index of the header
	 */
	this.appendHeader = function(paramsObj,index) {
		var i = (!index ? self.header.cells.length : index);
		var cell = self.header.addCell(paramsObj,i);
		for (var i=0;i<self.header.cells.length;i++) {
			self.header.cells[i].number = i;
		}
		return cell;
	}

	/**
 	 * reset css classes after sorting/adding/removing rows
 	 */
	this.redraw = function() {
		/* redo dom, odd & even */
		for (var i=0;i<self.rows.length;i++) {
			self.rowBlock.appendChild(self.rows[i].html);
			var h = self.rows[i].html;
			OAT.Dom.removeClass(h,"even");
			OAT.Dom.removeClass(h,"odd");
			OAT.Dom.addClass(self.rows[i].html,( i & 1 ? "odd" : "even" ));
		}
	}

	/**
	 * xxx ? :>
	 */
	this._ieFix = function() {
		for (var i=0;i<self.header.cells.length;i++) {
			var html = self.header.cells[i].html;
			OAT.Dom.addClass(html,"hover");
			OAT.Dom.removeClass(html,"hover");
			var value = self.header.cells[i].value;
			var dims = OAT.Dom.getWH(value);
		}
	}

	/**
	 * create header row
	 * @param {array} paramsList list of column header names
	 */
	this.createHeader = function(paramsList) {
		self.header.clear();
		if (self.options.autoNumber) {
			var cell = self.header.addCell({value:"&nbsp;#&nbsp;",align:OAT.GridData.ALIGN_CENTER,type:OAT.GridData.TYPE_NUMERIC,draggable:0,sortable:0});
			var click = function() { for (var i=0;i<self.rows.length;i++) { self.rows[i].select(); } } /* select all */
			OAT.Event.attach(cell.html,"click",click);
		}
		for (var i=0;i<paramsList.length;i++) {
			self.appendHeader(paramsList[i]);
		}
		if (OAT.Browser.isIE) { self._ieFix(); }
	}

	/**
	 * create new data row
	 * @param {array} paramsList list of cell contents
	 * @param {integer} index where to insert the row (end of table if not specified)
	 */
	this.createRow = function(paramsList, index) {
		var number = (!index ? self.rows.length : index);
		var row = new OAT.GridRow(self,number);
		if (index == number || number == self.rows.length) {
			self.rowBlock.appendChild(row.html);
		} else {
			self.rowBlock.insertBefore(row.html,self.rowBlock.childNodes[number]);
		}
		if (self.options.autoNumber) {
			row.addCell({value:self.options.rowOffset+number+1,align:OAT.GridData.ALIGN_CENTER});
			OAT.Dom.addClass(row.cells[0].html,"index");
		}

		for (var i=0;i<paramsList.length;i++) {	row.addCell(paramsList[i]);	}
		self.rows.splice(number,0,row);
		return row.html;
	}

	/**
	 * removes data row from table
	 * @param {integer} index index of row to remove, last if not specified
	 */
	this.removeRow = function(index) {
		var number = (arguments.length? arguments[0] : self.rows.length-1);
		var row = self.rows.splice(number,1)[0];
		/* clear rows cell objects & nodes */
		row.clear();
		OAT.Dom.unlink(row.html);
	}

	/**
	 * removes column from table
	 * @param {integer} index index of column to remove
	 */
	this.removeColumn = function(index) {
		self.header.removeColumn(index);
		for (var i=0;i<self.rows.length;i++) { self.rows[i].removeColumn(index); }
	}

	/**
	 * sorts grid data according to specified column
	 * @param {integer} index index of column according which to sort
	 * @param {constant} type order of sorting, OAT.GridData.TYPE_ASC/TYPE_DESC for ascending/descending order
	 */
	this.sort = function(index,type) {
		if (OAT.GridData.forbidSort) { return; }

		if (self.options.sortFunc) {
			self.options.sortFunc(index,type);
			return;
		}
		for (var i=0;i<self.header.cells.length;i++) {
			self.header.cells[i].changeSort(OAT.GridData.SORT_NONE);
		}
		self.header.cells[index].changeSort(type);
		/* sort elements here */
		var coltype = self.header.cells[index].options.type;
		var c1, c2;
		switch (type) {
			case OAT.GridData.SORT_ASC: c1 = 1; c2 = -1; break;
			case OAT.GridData.SORT_DESC: c1 = -1; c2 = 1; break;
		}
		var numCmp = function(row_a,row_b) {
			var a = row_a.cells[index].value.innerHTML;
			var b = row_b.cells[index].value.innerHTML;
			if (a == b) { return 0; }
			return (parseFloat(a) > parseFloat(b) ? c1 : c2);
		}
		var strCmp = function(row_a,row_b) {
			var a = row_a.cells[index].value.innerHTML;
			var b = row_b.cells[index].value.innerHTML;
			if (a == b) { return 0; }
			return (a > b ? c1 : c2);
		}
		var cmp;

		if (!self.rows.length) { return; } /* no work to be done */

		var testValue = self.rows[0].cells[index].value.innerHTML;
		switch (coltype) {
			case OAT.GridData.TYPE_STRING: cmp = strCmp; break;
			case OAT.GridData.TYPE_NUMERIC: cmp = numCmp; break;
			case OAT.GridData.TYPE_AUTO: cmp = (testValue == parseFloat(testValue) ? numCmp : strCmp); break;
		}
		self.rows.sort(cmp);
		self.redraw();
	}

	/**
	 * creates grid from table element
	 * @param {elm} something table element
	 */
	this.fromTable = function(something) {
		/* backwards compatibility fix */
			if (self.reorderNotifier) { self.options.reorderNotifier = self.reorderNotifier; }
			if (self.sortFund) { self.options.sortFunc = self.sortFunc; }
			if (self.imagePath) { self.options.imagePath = self.imagePath; }
		/**/
		self.clearData();
		var t = $(something);
		var head = t.getElementsByTagName("thead")[0];
		var body = t.getElementsByTagName("tbody")[0];
		var tmp = [];
		var cells = head.getElementsByTagName("td");
		for (var i=0;i<cells.length;i++) { tmp.push(cells[i].innerHTML); }
		self.createHeader(tmp);

		var rows = body.getElementsByTagName("tr");
		for (var i=0;i<rows.length;i++) {
			tmp = [];
			var cells = rows[i].getElementsByTagName("td");
			for (var j=0;j<cells.length;j++) { tmp.push(cells[j].innerHTML); }
			self.createRow(tmp);
		}
		OAT.Dom.unlink(t);
	}

	/**
	 * serializes table to xml file
	 * @param {boolean} ignoreSelection return only innerHTML
	 */
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

	self._init();
} /* Grid */

OAT.GridHeader = function(grid) {
	var self = this;
	this.cells = [];
	this.grid = grid;
	this.html = OAT.Dom.create("thead");
	this.container = OAT.Dom.create("tr");
	this.html.appendChild(self.container);

	this.clear = function() {
		OAT.Dom.clear(self.container);
		self.cells = [];
	}

	this.addCell = function(params,index) {
		var cell = new OAT.GridHeaderCell(self.grid,params,index);
		var tds = self.container.childNodes;

		if (tds.length && index < tds.length) {
			self.container.insertBefore(cell.html,tds[index]);
		} else { self.container.appendChild(cell.html); }

		self.cells.splice(index,0,cell);
		return cell;
	}

	self.removeColumn = function(index) {
		OAT.Dom.unlink(self.cells[index].html);
		self.cells.splice(index,1);
		for (var i=0;i<self.cells.length;i++) { self.cells[i].number = i; }
	}
} /* GridHeader */

OAT.GridHeaderCell = function(grid,params_,number) {
	var self = this;
	this.options = {
		value:"",
		sortable:1,
		draggable:1,
		resizable:1,
		align:OAT.GridData.ALIGN_LEFT,
		sort:OAT.GridData.SORT_NONE,
		type:OAT.GridData.TYPE_AUTO
	}

	var params = (typeof(params_) == "object" ? params_ : {value:params_});
	for (var p in params) { self.options[p] = params[p]; }

	this.signalStart = function() { /* red line */
		self.signal = 1;
		var dims = OAT.Dom.getWH(self.container);
		self.signalElm = OAT.Dom.create("div",{position:"absolute",width:"2px",height:(dims[1]+2)+"px",left:"-2px",top:"-1px",backgroundColor:"#f00"});
		self.container.appendChild(self.signalElm);
	}

	this.signalEnd = function() {
		self.signal = 0;
		OAT.Dom.unlink(self.signalElm);
	}

	this.changeWidth = function(width) {
		var w = width;
		if (!w) {
			self.value.style.width = "";
			return;
		}

		w -= parseInt(OAT.Style.get(self.value,"paddingLeft"));
		w -= parseInt(OAT.Style.get(self.value,"paddingRight"));
		self.value.style.width = w + "px";
	}

	this.changeSort = function(type) {
		self.options.sort = type;
		self.updateSortImage();
	}

	this.updateSortImage = function() {
		if (!self.sorter) { return; }
		var path = "none";
		switch (self.options.sort) {
			case OAT.GridData.SORT_NONE: path = "none"; break;
			case OAT.GridData.SORT_ASC: path = "asc"; break;
			case OAT.GridData.SORT_DESC: path = "desc"; break;
		}
		self.sorter.style.backgroundImage = "url("+self.grid.options.imagePath+"Grid_"+path+".gif)";
	}

	this.signal = 0;
	this.number = number;
	this.grid = grid;

	this.html = OAT.Dom.create("td"); /* cell */
	this.container = OAT.Dom.create("div",{position:"relative"}); /* cell interior */
	this.value = OAT.Dom.create("div",{overflow:"hidden"});
	OAT.Dom.addClass(self.value,"header_value");
	OAT.Dom.append([self.html,self.container],[self.container,self.value]);
	this.value.innerHTML = params.value;

	if (self.options.sortable) {
		self.html.style.cursor = "pointer";
		self.value.style.paddingRight = "14px";
		self.sorter = OAT.Dom.create("div",{position:"absolute",right:"0px",bottom:"2px",width:"12px",height:"12px"});
		self.container.appendChild(self.sorter);
		self.updateSortImage();
		var callback = function(event) {
			var type = OAT.GridData.SORT_NONE;
			switch (self.options.sort) {
				case OAT.GridData.SORT_NONE: type = OAT.GridData.SORT_ASC; break;
				case OAT.GridData.SORT_ASC: type = OAT.GridData.SORT_DESC; break;
				case OAT.GridData.SORT_DESC: type = OAT.GridData.SORT_ASC; break;
			}
			self.grid.sort(self.number,type);
		}
		OAT.Event.attach(self.container,"click",callback);
	}

	if (self.options.resizable) {
		var mover = OAT.Dom.create("div",{width:"7px",height:"100%",position:"absolute",right:"-5px",top:"0px",cursor:"e-resize"});
		mover.style.backgroundImage = "url("+self.grid.options.imagePath+"Grid_none.gif)";
		self.container.appendChild(mover);
		var callback = function (event) { /* start resizing */
			var pos = OAT.Event.position(event);
			var dims_grid = OAT.Dom.getWH(self.grid.html);
			var dims_container = OAT.Dom.getWH(self.container);

			OAT.GridData.resizing = self.grid;
			OAT.GridData.index = self.number;
			OAT.GridData.mouseX = pos[0];
			OAT.GridData.w = dims_container[0]; /* total width to be changed */
			var left1 = -2;
			var left2 = dims_container[0];
			if (OAT.Browser.isIE6 && !self.value.style.width) {
				left1 -= 2;
				left2 -= 4;
			}
			OAT.GridData.x = left2; /* initial position of moving red line */
			self.grid.tmp_resize_start = OAT.Dom.create("div",{position:"absolute",left:left1+"px",top:"-1px",backgroundColor:"#f00",width:"2px",height:dims_grid[1]+"px"});
			self.grid.tmp_resize = OAT.Dom.create("div",{position:"absolute",left:left2+"px",top:"-1px",backgroundColor:"#f00",width:"2px",height:dims_grid[1]+"px"});
			self.container.appendChild(self.grid.tmp_resize);
			self.container.appendChild(self.grid.tmp_resize_start);
		}
		var nullCallback = function() {
			self.changeWidth(false);
			for (var i=0;i<self.grid.rows.length;i++) {
				self.grid.rows[i].cells[self.number].changeWidth(false);
			}
		}
		OAT.Event.attach(mover,"mousedown",callback);
		OAT.Event.attach(mover,"dblclick",nullCallback);
	}

	if (self.options.draggable) {
		var callback = function(event) {
			if (OAT.GridData.resizing) { return; } /* don't drag when resizing */
			OAT.GridData.dragging = self.grid;
			OAT.GridData.index = self.number;
			var pos = OAT.Event.position(event);
			OAT.GridData.x = pos[0];
			self.grid.tmp_drag = false;
		}
		OAT.Event.attach(self.container,"mousedown",callback);
	}

	switch (self.options.align) {
		case OAT.GridData.ALIGN_LEFT: self.html.style.textAlign = "left"; break;
		case OAT.GridData.ALIGN_CENTER: self.html.style.textAlign = "center"; break;
		case OAT.GridData.ALIGN_RIGHT: self.html.style.textAlign = "right"; break;
	}

	var mouseover = function(event) { OAT.Dom.addClass(self.html,"hover"); }
	var mouseout = function(event) { OAT.Dom.removeClass(self.html,"hover"); }
	OAT.Event.attach(self.html,"mouseover",mouseover);
	OAT.Event.attach(self.html,"mouseout",mouseout);
} /* GridHeaderCell */

OAT.GridRow = function(grid,number) {
	var self = this;

	this.clear = function() {
		OAT.Dom.clear(self.html);
		self.cells = [];
	}

	this.removeColumn = function(index) {
		OAT.Dom.unlink(self.cells[index].html);
		self.cells.splice(index,1);
	}

	this.addCell = function(params,index) {
		var i = (!index ? self.cells.length : index);
		var cell = new OAT.GridRowCell(params,i,this);
		var tds = self.html.childNodes;
		if (tds.length && i != tds.length) {
			self.html.insertBefore(cell.html,tds[i]);
		} else {
			self.html.appendChild(cell.html);
		}
		self.cells.splice(i,0,cell);
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

	this.grid = grid; /* parent */
	this.cells = [];
	this.html = OAT.Dom.create("tr");
	this.selected = 0;

	OAT.Dom.addClass(self.html,( number % 2 ? "even" : "odd" ));

	var mouseover = function(event) { OAT.Dom.addClass(self.html,"hover"); }
	var mouseout = function(event) { OAT.Dom.removeClass(self.html,"hover"); }
	var click = function(event) {
		if (!event.shiftKey && !event.ctrlKey) {
			/* deselect all */
			for (var i=0;i<self.grid.rows.length;i++) {
				var r = self.grid.rows[i];
				if (r != self) { r.deselect(); }
			}
		}
		if (event.shiftKey) {
			/* select all above */
			var firstAbove = -1;
			var lastBelow = -1;
			var done = 0;
			for (var i=0;i<self.grid.rows.length;i++) {
				var r = self.grid.rows[i];
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
				for (var i=0;i<self.grid.rows.length;i++) {
					var r = self.grid.rows[i];
					if (r == self) { done = 1; }
					if (done && r != self && i < lastBelow) { r.select(); }
				} /* all rows */
			} /* below */
		} /* if shift */
		OAT.MSG.send(grid, "GRID_ROWCLICK", self);
		self.selected ? self.deselect() : self.select();
	}

	OAT.Event.attach(self.html,"mouseover",mouseover);
	OAT.Event.attach(self.html,"mouseout",mouseout);
	OAT.Event.attach(self.html,"click",click);

} /* GridRow */

OAT.GridRowCell = function(params_,number,row) {
	var self = this;

	this.options = {
		value:"",
		align:OAT.GridData.ALIGN_LEFT
	}

	var params = (typeof(params_) == "object" ? params_ : {value:params_});
	for (p in params) { self.options[p] = params[p]; }

	this.html = OAT.Dom.create("td");
	this.value = OAT.Dom.create("div",{overflow:"hidden"});
	OAT.Dom.addClass(self.value,"row_value");
	this.value.innerHTML = self.options.value;
	this.html.setAttribute("title",self.options.value);
	OAT.Dom.append([self.html,self.value]);

 	OAT.Event.attach(this.html, "click", function() {
 		OAT.MSG.send(row.grid, "GRID_CELLCLICK", self);
 	});

	switch (self.options.align) {
		case OAT.GridData.ALIGN_LEFT: self.html.style.textAlign = "left"; break;
		case OAT.GridData.ALIGN_CENTER: self.html.style.textAlign = "center"; break;
		case OAT.GridData.ALIGN_RIGHT: self.html.style.textAlign = "right"; break;
	}

	this.changeWidth = function(width) {
		var w = width;
		if (!w) {
			self.value.style.width = "";
			return;
		}

		w -= parseInt(OAT.Style.get(self.value,"paddingLeft"));
		w -= parseInt(OAT.Style.get(self.value,"paddingRight"));
		self.value.style.width = w + "px";
	}

} /* GridRowCell */

OAT.Event.attach(document,"mouseup",OAT.GridData.up);
OAT.Event.attach(document,"mousemove",OAT.GridData.move);
