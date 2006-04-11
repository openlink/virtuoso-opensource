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
	p = new Pivot(div, headerRow, dataRows, headerRowIndexes, headerColIndexes, filterIndexes, dataColumnIndex, optObj) 
	div - dom element
	headerRow - array
	dataRows - array of arrays
	headerRowIndexes, headerColIndexes, filterIndexes - arrays
	dataColumnIndex - number
	optObj - options object
	
	p.toXML(xslStr,query)  -- if query == false than data is dumped

	var defOpt = {
		headingBefore:1,
		headingAfter:1
		agg:PivotData.AGG_SUM
	}
	
	PivotData.AGG_SUM
	PivotData.AGG_MAX
	PivotData.AGG_MIN
	PivotData.AGG_AVG
	PivotData.AGG_COUNT
	PivotData.AGG_DISTINCT
	PivotData.AGG_PRODUCT
	PivotData.AGG_VAR
	PivotData.AGG_DEVIATION

	CSS: .pivot_table, .h1, .h2, .odd, .even
*/

var PivotData = {
	AGG_SUM:1,
	AGG_MAX:2,
	AGG_MIN:3,
	AGG_AVG:4,
	AGG_COUNT:5,
	AGG_DISTINCT:6,
	AGG_PRODUCT:7,
	AGG_VAR:8,
	AGG_DEVIATION:9
}

function Pivot(div,headerRow,dataRows,headerRowIndexes,headerColIndexes,filterIndexes,dataColumnIndex,optObj) {
	var obj = this;
	var defOpt = {
		headingBefore:1,
		headingAfter:1,
		agg:PivotData.AGG_SUM
	}
	this.options = defOpt;
	if (optObj) for (p in optObj) { this.options[p] = optObj[p]; }
	this.gd = new GhostDrag();
	this.div = $(div);
	this.headerRow = headerRow; /* store data */
	this.dataRows = dataRows;/* store data */
	this.dataColumnIndex = dataColumnIndex; /* store data */
	this.rowConditions = headerRowIndexes; /* indexes of row conditions */
	this.colConditions = headerColIndexes; /* indexes of column conditions */
	this.filterIndexes = filterIndexes; /* indexes of column conditions */
	this.colCount = headerRow.length; /* source columns */
	this.rowCount = dataRows.length; /* source rows */
	this.conditions = [];
	this.filters = [];
	this.numRows = 1; /* resulting table's width */
	this.numCols = 1; /* resulting table's height */
	
	/* supplemental routines */
	this.toXML = function(xslStr,query) {
		var xml = '<?xml version="1.0" ?>\n';
		xml += xslStr+'\n';
		xml += '\t<pivot>\n';
		xml += '\t\t<headerRow>\n';
		for (var i=0;i<this.headerRow.length;i++) {
			xml += '\t\t\t<value>'+this.headerRow[i]+'</value>\n';
		}
		xml += '\t\t</headerRow>\n';

		xml += '\t\t<headerRowIndexes>\n';
		for (var i=0;i<this.rowConditions.length;i++) {
			xml += '\t\t\t<value>'+this.rowConditions[i]+'</value>\n';
		}
		xml += '\t\t</headerRowIndexes>\n';

		xml += '\t\t<headerColIndexes>\n';
		for (var i=0;i<this.colConditions.length;i++) {
			xml += '\t\t\t<value>'+this.colConditions[i]+'</value>\n';
		}
		xml += '\t\t</headerColIndexes>\n';

		xml += '\t\t<filterIndexes>\n';
		for (var i=0;i<this.filterIndexes.length;i++) {
			xml += '\t\t\t<value>'+this.filterIndexes[i]+'</value>\n';
		}
		xml += '\t\t</filterIndexes>\n';

		xml += '\t\t<dataColumnIndex>'+this.dataColumnIndex+'</dataColumnIndex>\n';
		
		if (query) {
			xml += '\t\t<query>'+query+'</query>\n';
			xml += '\t\t<connection dsn="'+Xmla.dsn+'" endpoint="'+Xmla.endpoint+'" user="'+Xmla.user+'" password="'+Xmla.password+'"></connection>\n';
		} else {
			xml += '\t\t<dataRows>\n';
			for (var i=0;i<this.dataRows.length;i++) {
				xml += '\t\t\t<dataRow>\n';
					for (var j=0;j<this.dataRows[i].length;j++) {
						xml += '\t\t\t\t<value>'+this.dataRows[i][j]+'</value>\n';
					}
				xml += '\t\t\t</dataRow>\n';
			}
			xml += '\t\t</dataRows>\n';
		}
		
		xml += '\t</pivot>\n';
		return xml;
	}
	
	this.lightOn = function() {
		for (var i=0;i<obj.gd.targets.length;i++) {
			var elm = obj.gd.targets[i];
			elm.style.color = "#f00";
		}
	}
	
	this.lightOff = function() {
		for (var i=0;i<obj.gd.targets.length;i++) {
			var elm = obj.gd.targets[i];
			elm.style.color = "";
		}
	}
	
	this.process = function(elm) {
		obj.lightOn();
		elm.style.backgroundColor = "#888";
		elm.style.padding = "2px";
		Dom.attach(elm,"mouseup",obj.lightOff);
	}
	
	this.filterOK = function(index) {
		var hope = 1;
		for (var i=0;i<this.filterIndexes.length;i++) { /* for all filters */
			var fi = this.filterIndexes[i]; /* this column is important */
			var s = this.filters[i]; /* select node */
			if (s.selectedIndex && $v(s) != this.dataRows[index][fi]) { hope = 0; }
		}
		return hope;
	}

	/* init routines */
	this.createCondition = function(index) {
		var cond = {distinctValuesObj:{},distinctValuesArr:[],numDistinctValues:0,span:1,sort:1};
		for (var i=0;i<this.rowCount;i++) {
			var value = this.dataRows[i][index];
			if (!(value in cond.distinctValuesObj)) { 
				/* new value */
				cond.numDistinctValues++;
				cond.distinctValuesObj[value] = cond.numDistinctValues; 
				cond.distinctValuesArr.push(value);
			} /* if new value */
		} /* for all rows */
		this.conditions.push(cond);
	}
	
	this.init = function() {
		for (var i=0;i<this.colCount;i++) {
			this.createCondition(i);
		}
		for (var i=0;i<this.filterIndexes.length;i++) {
			var index = this.filterIndexes[i];
			var s = Dom.create("select");
			Dom.option("[all]","",s);
			for (var j=0;j<this.conditions[index].numDistinctValues;j++) {
				Dom.option(this.conditions[index].distinctValuesArr[j],this.conditions[index].distinctValuesArr[j],s);
			}
			Dom.attach(s,"change",obj.go);
			this.filters.push(s);
		}
	} /* init */
	
	/* callback routines */
	this.getOrderReference = function(conditionIndex) {
		return function(target,x,y) {
			/* somehow reorder conditions */
			obj.lightOff();
			var sourceCI = conditionIndex; /* global index */
			var targetCI = target.conditionIndex; /* global index */
			if (sourceCI == targetCI) { return; } /* dragged onto the same */
			var sourceType = false; var sourceI = -1; /* local */
			var targetType = false; var targetI = -1; /* local */
			for (var i=0;i<obj.rowConditions.length;i++) {
				if (obj.rowConditions[i] == sourceCI) { sourceType = obj.rowConditions; sourceI = i; }
				if (obj.rowConditions[i] == targetCI) { targetType = obj.rowConditions; targetI = i; }
			}
			for (var i=0;i<obj.colConditions.length;i++) {
				if (obj.colConditions[i] == sourceCI) { sourceType = obj.colConditions; sourceI = i; }
				if (obj.colConditions[i] == targetCI) { targetType = obj.colConditions; targetI = i; }
			}
			if (targetCI == -1) {
				/* no cols - lets create one */
				obj.colConditions.push(sourceCI);
				obj.rowConditions.splice(sourceI,1);
				obj.go();
				return;
			}
			if (targetCI == -2) {
				/* no rows - lets create one */
				obj.rowConditions.push(sourceCI);
				obj.colConditions.splice(sourceI,1);
				obj.go();
				return;
			}
			if (sourceType == targetType) {
				/* same condition type */
				if (sourceI+1 == targetI) {
					/* dragged on condition immediately after */
					targetType.splice(targetI+1,0,sourceCI);
					targetType.splice(sourceI,1);
				} else {
					targetType.splice(sourceI,1);
					targetType.splice(targetI,0,sourceCI);
				}
			} else {
				/* different condition type */
				sourceType.splice(sourceI,1);
				targetType.splice(targetI,0,sourceCI);
			}
			obj.go();
		}
	}
	
	this.getSortReference = function(cond) {
		return function() { 
			cond.sort = -cond.sort;
			obj.go();
		}
	}
	
	this.sort = function() {
		/* sort distinct values */
		for (var i=0;i<this.colCount;i++) if (i != dataColumnIndex) {
			var sortFunc;
			var cond = this.conditions[i];
			var coef = cond.sort;
			var numSort = function(a,b) { 
				if (a==b) { return 0; }
				return coef*(parseInt(a) > parseInt(b) ? 1 : -1);
			}
			var dictSort = function(a,b) { 
				if (a==b) { return 0; }
				return coef*(a > b ? 1 : -1);
			}
			/* get data type, trial & error... */
			var testValue = cond.distinctValuesArr[0];
			if (testValue == parseInt(testValue)) { sortFunc = numSort; } else { sortFunc = dictSort; }
			cond.distinctValuesArr.sort(sortFunc);
		}
	} /* sort */

	this.prepare = function() {
		/* count important numbers: table dimensions, spans, cell counts */
		/* table dimensions */
		this.numRows = 1;
		this.numCols = 1;
		for (var i=0;i<this.rowConditions.length;i++) { 
			this.numRows *= this.conditions[this.rowConditions[i]].numDistinctValues;
			this.conditions[this.rowConditions[i]].span = 1;
		}
		for (var i=0;i<this.colConditions.length;i++) { 
			this.numCols *= this.conditions[this.colConditions[i]].numDistinctValues; 
			this.conditions[this.colConditions[i]].span = 1;
		}
		/* spans */
		if (this.rowConditions.length > 1) {
			for (var i=this.rowConditions.length-2;i>=0;i--) {
				this.conditions[this.rowConditions[i]].span = this.conditions[this.rowConditions[i+1]].span * this.conditions[this.rowConditions[i+1]].numDistinctValues;
			}
		}
		if (this.colConditions.length > 1) {
			for (var i=this.colConditions.length-2;i>=0;i--) {
				this.conditions[this.colConditions[i]].span = this.conditions[this.colConditions[i+1]].span * this.conditions[this.colConditions[i+1]].numDistinctValues;
			}
		}
		/* numCells */
		for (var i=0;i<this.rowConditions.length;i++) {
			var cond = this.conditions[this.rowConditions[i]];
			cond.numCells = cond.numDistinctValues;
			if (i) { cond.numCells *= this.conditions[this.rowConditions[i-1]].numDistinctValues; }
		}
		for (var i=0;i<this.colConditions.length;i++) {
			var cond = this.conditions[this.colConditions[i]];
			cond.numCells = cond.numDistinctValues;
			if (i) { cond.numCells *= this.conditions[this.colConditions[i-1]].numCells; }
		}
	}
	
	this.getCoords = function(index) {
		/* get coordinates of data in the resulting grid */
		var x=0;
		var y=0;
		for (var i=0;i<this.colConditions.length;i++) {
			var cond = this.conditions[this.colConditions[i]];
			var value = this.dataRows[index][this.colConditions[i]];
			for (var j=0;j<cond.numDistinctValues;j++) {
				if (value == cond.distinctValuesArr[j]) {
					x+=j*cond.span; 
				} /* if value ok */
			} /* for all distinct values */
		} /* for all x conditions */
		for (var i=0;i<this.rowConditions.length;i++) {
			var cond = this.conditions[this.rowConditions[i]];
			var value = this.dataRows[index][this.rowConditions[i]];
			for (var j=0;j<cond.numDistinctValues;j++) {
				if (value == cond.distinctValuesArr[j]) {
					y+=j*cond.span; 
				} /* if value ok */
			} /* for all distinct values */
		} /* for all y conditions */
		return [x,y];
	}
	
	this.count = function() {
		/* important point - take data and create a two-dimensional structure */
		this.data = [];
		var tmp = [];
		for (var i=0;i<this.numCols;i++) { /* blank arrays */
			this.data[i] = new Array(this.numRows);
			tmp[i] = new Array(this.numRows);
			for (var j=0;j<this.numRows;j++) { tmp[i][j] = []; }
		}
		for (var i=0;i<this.dataRows.length;i++) { /* reposition value array to grid */
			if (this.filterOK(i)) {
				var coords = this.getCoords(i);
				var x = coords[0];
				var y = coords[1];
				var value = parseFloat(this.dataRows[i][this.dataColumnIndex]);
				tmp[x][y].push(value);
			}
		}
		for (var i=0;i<this.numCols;i++) { /* statistics */
			for (var j=0;j<this.numRows;j++) { 
				switch (this.options.agg) {
					case PivotData.AGG_SUM: this.data[i][j] = Statistics.sum(tmp[i][j]); break;
					case PivotData.AGG_MAX: this.data[i][j] = Statistics.max(tmp[i][j]); break;
					case PivotData.AGG_MIN: this.data[i][j] = Statistics.min(tmp[i][j]); break;
					case PivotData.AGG_AVG: this.data[i][j] = Statistics.avg(tmp[i][j]); break;
					case PivotData.AGG_COUNT: this.data[i][j] = tmp[i][j].length; break;
					case PivotData.AGG_DISTINCT: this.data[i][j] = Statistics.distinct(tmp[i][j]); break;
					case PivotData.AGG_PRODUCT: this.data[i][j] = Statistics.product(tmp[i][j]); break;
					case PivotData.AGG_VAR: this.data[i][j] = Statistics.variation(tmp[i][j]); break;
					case PivotData.AGG_DEVIATION: this.data[i][j] = Statistics.deviation(tmp[i][j]); break;
				} /* switch */
			}
		}
	} /* Pivot::count() */
	
	this.drawTable = function() {
		/* this is the crucial part */
		Dom.clear(this.div);
		var table = Dom.create("table");
		var tbody = Dom.create("tbody");
		table.className = "pivot_table";
		
		/* colConditions headings */
		for (var i=0;i<this.colConditions.length;i++) {
			var cond = this.conditions[this.colConditions[i]];
			var tr = Dom.create("tr");
			if (i == 0 && this.rowConditions.length) { /* left top corner */
				var th = Dom.create("th");
				th.className = "h1";
				th.innerHTML = this.headerRow[this.dataColumnIndex];
				th.colSpan = this.rowConditions.length;
				th.rowSpan = this.colConditions.length;
				tr.appendChild(th);
			}
			if (this.options.headingBefore) { /* column headings before */
				var th = Dom.create("th",{cursor:"pointer"});
				var div = Dom.create("div");
				th.className = "h1";
				div.innerHTML = this.headerRow[this.colConditions[i]];
				var ref = this.getSortReference(cond);
				Dom.attach(th,"click",ref);
				var callback = this.getOrderReference(this.colConditions[i]);
				this.gd.addSource(div,obj.process,callback);
				this.gd.addTarget(th);
				th.conditionIndex = this.colConditions[i];
				th.appendChild(div);
				tr.appendChild(th);
			}
			for (var j=0;j<cond.numCells;j++) { /* column values */
				var th = Dom.create("th");
				th.className = "h2";
				th.innerHTML = cond.distinctValuesArr[j % cond.numDistinctValues];
				th.colSpan = cond.span;
				tr.appendChild(th);
			}
			if (this.options.headingAfter) { /* column headings after */
				var th = Dom.create("th",{cursor:"pointer"});
				var div = Dom.create("div");
				th.className = "h1";
				div.innerHTML = this.headerRow[this.colConditions[i]];
				var ref = this.getSortReference(cond);
				Dom.attach(th,"click",ref);
				var callback = this.getOrderReference(this.colConditions[i]);
				this.gd.addSource(div,obj.process,callback);
				this.gd.addTarget(th);
				th.conditionIndex = this.colConditions[i];
				th.appendChild(div);
				tr.appendChild(th);
			}
			tbody.appendChild(tr);
		}
		
		/* rowConditions headings */
		if (this.rowConditions.length && this.options.headingBefore) {
			var tr = Dom.create("tr");
			for (var j=0;j<this.rowConditions.length;j++) { /* column headings before */
				var th = Dom.create("th",{cursor:"pointer"});
				var div = Dom.create("div");
				th.className = "h1";
				div.innerHTML = this.headerRow[this.rowConditions[j]];
				var ref = this.getSortReference(this.conditions[this.rowConditions[j]]);
				Dom.attach(th,"click",ref);
				var callback = this.getOrderReference(this.rowConditions[j]);
				this.gd.addSource(div,obj.process,callback);
				this.gd.addTarget(th);
				th.conditionIndex = this.rowConditions[j];
				th.appendChild(div);
				tr.appendChild(th);
			}
			var th = Dom.create("th"); /* blank space above */
			if (!this.colConditions.length) { 
				th.innerHTML = this.headerRow[this.dataColumnIndex];
				th.className = "h1";
				th.conditionIndex = -1;
				this.gd.addTarget(th);
			} else { th.style.border = "none"; }
			th.colSpan = this.numCols + (this.options.headingBefore ? 1 : 0);
			tr.appendChild(th);
			if (this.colConditions.length) { /* blank space after */
				var th = Dom.create("th",{border:"none"});
				tr.appendChild(th);
			}
			tbody.appendChild(tr);
		}

		/* data */
		for (var i=0;i<this.numRows;i++) {
			var tr = Dom.create("tr");
			for (var j=0;j<this.rowConditions.length;j++) { /* row values */
				var cond = this.conditions[this.rowConditions[j]];
				if ((i % cond.span) == 0) {
					var th = Dom.create("th");
					th.className = "h2";
					th.rowSpan = cond.span;
					th.innerHTML = cond.distinctValuesArr[Math.ceil(i/cond.span) % cond.numDistinctValues];
					tr.appendChild(th);
				}
			}
			if (this.colConditions.length && i==0 && this.options.headingBefore) { /* blank space before */
				var th = Dom.create("th");
				if (!this.rowConditions.length) { 
					th.innerHTML = this.headerRow[this.dataColumnIndex]; 
					th.className = "h1";
					th.conditionIndex = -2;
					this.gd.addTarget(th);
				} else { th.style.border = "none"; }
				th.rowSpan = this.numRows;
				tr.appendChild(th);
			}
			for (var j=0;j<this.numCols;j++) { /* data */
				var td = Dom.create("td");
				var xCounter = 1;
				var yCounter = 1;
				if (this.colConditions.length > 1) {
					var cond = this.conditions[this.colConditions[this.colConditions.length-2]];
					var tmp = Math.floor(j / cond.span) % 2;
					xCounter = (tmp ? 1 : -1);
				}
				if (this.rowConditions.length > 1) {
					var cond = this.conditions[this.rowConditions[this.rowConditions.length-2]];
					var tmp = Math.floor(i / cond.span) % 2;
					yCounter = (tmp ? 1 : -1);
				}
				if (xCounter * yCounter == 1) { td.className = "odd"; } else { td.className = "even"; }
				td.innerHTML = this.data[j][i];
				tr.appendChild(td);
			}
			if (this.colConditions.length && i==0 && this.options.headingAfter) { /* blank space after */
				var th = Dom.create("th");
				if (!this.rowConditions.length) { 
					th.innerHTML = this.headerRow[this.dataColumnIndex]; 
					th.className = "h1";
					th.conditionIndex = -2;
					this.gd.addTarget(th);
				} else { th.style.border = "none"; }
				th.rowSpan = this.numRows;
				tr.appendChild(th);
			}
			tbody.appendChild(tr);
		}
		
		/* rowConditions headings */
		if (this.rowConditions.length && this.options.headingAfter) {
			var tr = Dom.create("tr");
			for (var j=0;j<this.rowConditions.length;j++) { /* row headings after */
				var th = Dom.create("th",{cursor:"pointer"});
				var div = Dom.create("div");
				th.className = "h1";
				div.innerHTML = this.headerRow[this.rowConditions[j]];
				var ref = this.getSortReference(this.conditions[this.rowConditions[j]]);
				Dom.attach(th,"click",ref);
				var callback = this.getOrderReference(this.rowConditions[j]);
				this.gd.addSource(div,obj.process,callback);
				this.gd.addTarget(th);
				th.conditionIndex = this.rowConditions[j];
				th.appendChild(div);
				tr.appendChild(th);
			}
			var th = Dom.create("th"); /* blank row below */
			if (!this.colConditions.length) { 
				th.innerHTML = this.headerRow[this.dataColumnIndex]; 
				th.className = "h1";
				th.conditionIndex = -1;
				this.gd.addTarget(th);
			} else { th.style.border = "none"; }
			th.colSpan = this.numCols;
			tr.appendChild(th);
			if (this.colConditions.length) { /* blank space after */
				var th = Dom.create("th",{border:"none"});
				tr.appendChild(th);
			}
			tbody.appendChild(tr);
		}
		
		table.appendChild(tbody);
		this.div.appendChild(table);
	}
	
	this.go = function() {
		obj.gd.clearSources();
		obj.gd.clearTargets();
		obj.sort();
		obj.prepare();
		obj.count();
		obj.drawTable();
	}

	this.init();
	this.go();
}