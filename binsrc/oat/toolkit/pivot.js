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
	p = new OAT.Pivot(div, chartDiv, filterDiv, headerRow, dataRows, headerRowIndexes, headerColIndexes, filterIndexes, dataColumnIndex, optObj) 
	div, filterDiv - dom element
	headerRow - array
	dataRows - array of arrays
	headerRowIndexes, headerColIndexes, filterIndexes - arrays
	dataColumnIndex - number
	optObj - options object
	
	p.toXML(xslStr,saveCredentials,noCredentials,query)  -- if query == false than data is dumped

	var defOpt = {
		headingBefore:1,
		headingAfter:1,
		agg:1,
		showChart:0
	}
	
	CSS: .pivot_table, .h1, .h2, .odd, .even
*/

OAT.PivotData = {
	TYPE_BASIC:[0,"Basic - 123,456"],
	TYPE_PERCENT:[1,"Percentual - 123,456%"],
	TYPE_SCI:[2,"Scientific - 123,456E+02"],
	TYPE_SPACE:[3,"With space - 1 234.567"]
}

OAT.Pivot = function(div,chartDiv,filterDiv,headerRow,dataRows,headerRowIndexes,headerColIndexes,filterIndexes,dataColumnIndex,optObj) {
	var obj = this;
	var self = this;
	this.options = {
		headingBefore:1,
		headingAfter:1,
		agg:1, /* index of default statistic function, SUM */
		showChart:0,
		type:OAT.PivotData.TYPE_BASIC[0]
	}
	if (optObj) for (p in optObj) { this.options[p] = optObj[p]; }
	this.gd = new OAT.GhostDrag();
	this.div = $(div);
	this.filterDiv = $(filterDiv);
	this.chartDiv = $(chartDiv);
	if (this.chartDiv) { this.barChart = new OAT.BarChart(this.chartDiv,{}); }
	this.headerRow = headerRow; /* store data */
	this.dataRows = dataRows;/* store data */
	this.dataColumnIndex = dataColumnIndex; /* store data */
	this.rowConditions = headerRowIndexes; /* indexes of row conditions */
	this.colConditions = headerColIndexes; /* indexes of column conditions */
	this.filterIndexes = filterIndexes; /* indexes of column conditions */
	this.colCount = headerRow.length; /* source columns */
	this.rowCount = dataRows.length; /* source rows */
	this.conditions = [];
	this.filterDiv.selects = [];
	this.numRows = 1; /* resulting table's width */
	this.numCols = 1; /* resulting table's height */
	/* supplemental routines */
	this.toXML = function(xslStr,saveCredentials,noCredentials,query) {
		var xml = '<?xml version="1.0" ?>\n';
		if (xslStr) { xml += xslStr+'\n'; }
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
			xml += OAT.Xmla.connection.toXML(saveCredentials,noCredentials);
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
			var elm = obj.gd.targets[i][0];
			elm.style.color = "#f00";
		}
	}
	
	this.lightOff = function() {
		for (var i=0;i<obj.gd.targets.length;i++) {
			var elm = obj.gd.targets[i][0];
			elm.style.color = "";
		}
	}
	this.gd.onFail = self.lightOff;
	
	this.isNull = function(data) {
		return (data == 0 || data == false || !data);
	}
	
	this.process = function(elm) {
		obj.lightOn();
		elm.style.backgroundColor = "#888";
		elm.style.padding = "2px";
		elm.style.cursor = "pointer";
		OAT.Dom.attach(elm,"mouseup",function(e) { obj.lightOff(); });
	}
	
	this.filterOK = function(index) {
		var hope = 1;
		var dataRow = this.dataRows[index];
		for (var i=0;i<this.filterIndexes.length;i++) { /* for all filters */
			var fi = this.filterIndexes[i]; /* this column is important */
			var s = this.filterDiv.selects[i]; /* select node */
			if (s.selectedIndex && $v(s) != dataRow[fi]) { hope = 0; }
		}
		if (!hope) { return hope; }
		for (var i=0;i<this.rowConditions.length;i++) {
			var value = dataRow[this.rowConditions[i]];
			var cond = this.conditions[this.rowConditions[i]];
			if (value in cond.blackList) { hope = 0; }
		}
		if (!hope) { return hope; }
		for (var i=0;i<this.colConditions.length;i++) {
			var value = dataRow[this.colConditions[i]];
			var cond = this.conditions[this.colConditions[i]];
			if (value in cond.blackList) { hope = 0; }
		}
		return hope;
	}

	this.createCondition = function(index) {
		/* 
			get list of distinct values, based on:
			1) data
			2) blacklist
			3) empty values hiding
		*/
		
		var cond = obj.conditions[index];
		cond.distinctValuesObj = {};
		cond.distinctValuesArr = [];
		cond.numDistinctValues = 0;
		for (var i=0;i<obj.rowCount;i++) {
			var value = obj.dataRows[i][index];
			if (!(value in cond.distinctValuesObj) && !(value in cond.blackList)) { 
				/* new value */
				cond.numDistinctValues++;
				cond.distinctValuesObj[value] = cond.numDistinctValues; 
				cond.distinctValuesArr.push(value);
			} /* if new value */
		} /* for all rows */
		/* if empty values hiding is on, then filter values with empty data */
		if (cond.hideNulls) {
			var tmpObj = {};
			for (var i=0;i<cond.distinctValuesArr.length;i++) {
				tmpObj[cond.distinctValuesArr[i]] = 0;
			} /* for distinct values to be tested */
			for (var i=0;i<obj.rowCount;i++) {
				var value = obj.dataRows[i][index]
				var data = obj.dataRows[i][obj.dataColumnIndex];
				if (value in tmpObj && !obj.isNull(data)) { tmpObj[value] = 1; }
			} /* for all data */
			for (var p in tmpObj) {
				/* testing finished, now fuck off all distinct values with only null data */
				if (!tmpObj[p]) {
					cond.numDistinctValues--;
					var idx = cond.distinctValuesArr.find(p);
					cond.distinctValuesArr.splice(idx,1);
					delete cond.distinctValuesObj[p];
				} /* not satisfied */
			}
		} /* if hide nulls */
	}

	/* init routines */
	this.initCondition = function(index) {
		var cond = {distinctValuesAll:{},blackList:{},distinctValuesObj:{},distinctValuesArr:[],numDistinctValues:0,span:1,sort:1,hideNulls:1};
		this.conditions.push(cond);
		for (var i=0;i<obj.rowCount;i++) {
			var value = obj.dataRows[i][index];
			if (!(value in cond.distinctValuesAll)) { 
				/* new value */
				cond.distinctValuesAll[value] = 1; 
			} /* if new value */
		} /* for all rows */
	}
	
	this.init = function() {
		this.propPage = OAT.Dom.create("div",{position:"absolute",border:"2px solid #000",padding:"2px",backgroundColor:"#fff"});
		document.body.appendChild(this.propPage);
		OAT.Instant.assign(this.propPage);
		for (var i=0;i<this.colCount;i++) {
			this.initCondition(i);
		}
	} /* init */
	
	/* callback routines */
	this.getOrderReference = function(conditionIndex) {
		return function(target,x,y) {
			/* somehow reorder conditions */
			obj.lightOff();
			
			/* filters? */
			if (target == obj.filterDiv) {
				obj.filterIndexes.push(conditionIndex);
				for (var i=0;i<obj.rowConditions.length;i++) {
					if (obj.rowConditions[i] == conditionIndex) { obj.rowConditions.splice(i,1); }
				}
				for (var i=0;i<obj.colConditions.length;i++) {
					if (obj.colConditions[i] == conditionIndex) { obj.colConditions.splice(i,1); }
				}
				obj.go();
				return;
			}
			
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
	
	this.getClickReference = function(cond) {
		return function(event) {
			var coords = OAT.Dom.eventPos(event);
			obj.propPage.style.left = coords[0] + "px";
			obj.propPage.style.top = coords[1] + "px";
			OAT.Dom.clear(obj.propPage);
			var refresh = function() {
				obj.propPage._Instant_hide();
				obj.go();
			}
			/* contents */
			var close = OAT.Dom.create("div",{position:"absolute",top:"3px",right:"3px",cursor:"pointer"});
			close.innerHTML = "X";
			OAT.Dom.attach(close,"click",refresh);
			obj.propPage.appendChild(close);
			
			var asc = OAT.Dom.create("div",{cursor:"pointer"});
			if (cond.sort == 1) { asc.style.fontWeight = "bold"; }
			asc.innerHTML = "Ascending";
			OAT.Dom.attach(asc,"click",function(){cond.sort=1;refresh();});
			obj.propPage.appendChild(asc);
			var desc = OAT.Dom.create("div",{cursor:"pointer"});
			if (cond.sort == -1) { desc.style.fontWeight = "bold"; }
			desc.innerHTML = "Descending";
			OAT.Dom.attach(desc,"click",function(){cond.sort=-1;refresh();});
			obj.propPage.appendChild(desc);
			var hr = OAT.Dom.create("hr");
			hr.style.width = "100px";
			obj.propPage.appendChild(hr);
			
			var showNulls = OAT.Dom.create("div");
			var ch = OAT.Dom.create("input");
			ch.setAttribute("type","checkbox");
			ch.checked = (cond.hideNulls ? false : true);
			ch.__checked = (cond.hideNulls ? "0" : "1");
			showNulls.appendChild(ch);
			showNulls.appendChild(OAT.Dom.text(" Show empty items"));
			OAT.Dom.attach(ch,"change",function(){cond.hideNulls = (cond.hideNulls ? 0 : 1);refresh();});
			obj.propPage.appendChild(showNulls);
			
			var hr = OAT.Dom.create("hr");
			hr.style.width = "100px";
			obj.propPage.appendChild(hr);
			var distinct = obj.distinctDivs(cond);
			obj.propPage.appendChild(distinct);
			
			obj.propPage._Instant_show();
		}
	}
	
	this.getDelFilterReference = function(index) {
		return function() {
			var idx = -1;
			for (var i=0;i<obj.filterIndexes.length;i++) {
				if (obj.filterIndexes[i] == index) { idx = i; }
			}
			obj.filterIndexes.splice(idx,1);
			obj.rowConditions.push(index);
			obj.go()
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
	
	this.distinctDivs = function(cond) {
		var getPair = function(text) {
			var div = OAT.Dom.create("div");
			var ch = OAT.Dom.create("input");
			ch.setAttribute("type","checkbox");
			var t = OAT.Dom.text(" "+text);
			div.appendChild(ch);
			div.appendChild(t);
			return [div,ch];
		}
		
		var getRef = function(ch,value) {
			return function() {
				if (ch.checked) {
					delete cond.blackList[value];
				} else {
					cond.blackList[value] = 1;
				}
				obj.go();
			}
		}
		
		var div = OAT.Dom.create("div");
		for (p in cond.distinctValuesAll) {
			var pair = getPair(p);
			div.appendChild(pair[0]);
			pair[1].checked = !(p in cond.blackList);
			pair[1].__checked = (p in cond.blackList ? "0" : "1");
			OAT.Dom.attach(pair[1],"change",getRef(pair[1],p));
		}
		return div;
	}
	
	this.count = function() {
		/* create filters */
		var savedValues = [];
		var div = self.filterDiv;
		for (var i=0;i<div.selects.length;i++) {
			savedValues.push([div.selects[i].filterIndex,div.selects[i].selectedIndex]);
		}
		OAT.Dom.clear(div);
		self.gd.addTarget(div);
		div.selects = [];
		if (!self.filterIndexes.length) {
			div.innerHTML = "[drag paging columns here]";
		}
		for (var i=0;i<self.filterIndexes.length;i++) {
			var index = self.filterIndexes[i];
			var s = OAT.Dom.create("select");
			OAT.Dom.option("[all]","",s);
			for (var j=0;j<self.conditions[index].numDistinctValues;j++) {
				OAT.Dom.option(self.conditions[index].distinctValuesArr[j],self.conditions[index].distinctValuesArr[j],s);
			}
			s.filterIndex = index;
			for (var j=0;j<savedValues.length;j++) {
				if (savedValues[j][0] == index) { s.selectedIndex = savedValues[j][1]; }
			}
			OAT.Dom.attach(s,"change",obj.go);
			div.selects.push(s);
			var d = OAT.Dom.create("div");
			d.innerHTML = self.headerRow[index]+": ";
			d.appendChild(s);
			var close = OAT.Dom.create("span");
			close.style.color = "#f00";
			close.style.cursor = "pointer";
			close.innerHTML = " X";
			var ref = self.getDelFilterReference(index);
			OAT.Dom.attach(close,"click",ref)
			d.appendChild(close);
			self.filterDiv.appendChild(d);
		}
		
		/* important point - take data and create a two-dimensional structure */
		self.data = [];
		var tmp = [];
		for (var i=0;i<self.numCols;i++) { /* blank arrays */
			self.data[i] = new Array(self.numRows);
			tmp[i] = new Array(self.numRows);
			for (var j=0;j<self.numRows;j++) { tmp[i][j] = []; }
		}
		for (var i=0;i<self.dataRows.length;i++) { /* reposition value array to grid */
			if (self.filterOK(i)) {
				var coords = self.getCoords(i);
				var x = coords[0];
				var y = coords[1];
				var val = self.dataRows[i][self.dataColumnIndex];
				val = val.toString();
				val = val.replace(/,/g,'.');
				val = val.replace(/%/g,'');
				val = val.replace(/ /g,''); 
				var value = parseFloat(val);
				if (isNaN(value)) { value = 0; }
				tmp[x][y].push(value);
			}
		}
		var func = OAT.Statistics[OAT.Statistics.list[self.options.agg].func];
		for (var i=0;i<self.numCols;i++) { /* statistics */
			for (var j=0;j<self.numRows;j++) { 
				var result = parseFloat(func(tmp[i][j]));
				/* format according to current numerical type */
				self.data[i][j] = result;
			}
		}
	} /* Pivot::count() */
	
	this.numericalType = function(event) {
		var coords = OAT.Dom.eventPos(event);
		obj.propPage.style.left = coords[0] + "px";
		obj.propPage.style.top = coords[1] + "px";
		OAT.Dom.clear(obj.propPage);
		var refresh = function() {
			obj.propPage._Instant_hide();
			obj.go();
		}
		/* contents */
		var type = OAT.Dom.text("Numerical type: ");
		obj.propPage.appendChild(type);
		var select = OAT.Dom.create("select");
		for (var p in OAT.PivotData) {
			var t = OAT.PivotData[p];
			var o = OAT.Dom.option(t[1],t[0],select);
			if (obj.options.type == t[0]) { o.selected = true; }
		}
		obj.propPage.appendChild(select);
		OAT.Dom.attach(select,"change",function(){obj.options.type=parseInt($v(select));refresh();});
		obj.propPage._Instant_show();
	}
	
	this.drawTable = function() {
		/* this is the crucial part */
		OAT.Dom.clear(this.div);
		var table = OAT.Dom.create("table");
		var tbody = OAT.Dom.create("tbody");
		table.className = "pivot_table";
		
		/* colConditions headings */
		for (var i=0;i<this.colConditions.length;i++) {
			var cond = this.conditions[this.colConditions[i]];
			var tr = OAT.Dom.create("tr");
			if (i == 0 && this.rowConditions.length) { /* left top corner */
				var th = OAT.Dom.create("th",{cursor:"pointer"});
				th.className = "h1";
				th.innerHTML = this.headerRow[this.dataColumnIndex];
				th.colSpan = this.rowConditions.length;
				th.rowSpan = this.colConditions.length;
				tr.appendChild(th);
				/* numerical type change */
				OAT.Dom.attach(th,"click",this.numericalType);
			}
			if (this.options.headingBefore) { /* column headings before */
				var th = OAT.Dom.create("th",{cursor:"pointer"});
				var div = OAT.Dom.create("div");
				th.className = "h1";
				div.innerHTML = this.headerRow[this.colConditions[i]];
				var ref = this.getClickReference(cond);
				OAT.Dom.attach(th,"click",ref);
				var callback = this.getOrderReference(this.colConditions[i]);
				this.gd.addSource(div,obj.process,callback);
				this.gd.addTarget(th);
				th.conditionIndex = this.colConditions[i];
				th.appendChild(div);
				tr.appendChild(th);
			}
			for (var j=0;j<cond.numCells;j++) { /* column values */
				var th = OAT.Dom.create("th");
				th.className = "h2";
				th.innerHTML = cond.distinctValuesArr[j % cond.numDistinctValues];
				th.colSpan = cond.span;
				tr.appendChild(th);
			}
			if (this.options.headingAfter) { /* column headings after */
				var th = OAT.Dom.create("th",{cursor:"pointer"});
				var div = OAT.Dom.create("div");
				th.className = "h1";
				div.innerHTML = this.headerRow[this.colConditions[i]];
				var ref = this.getClickReference(cond);
				OAT.Dom.attach(th,"click",ref);
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
			var tr = OAT.Dom.create("tr");
			for (var j=0;j<this.rowConditions.length;j++) { /* column headings before */
				var th = OAT.Dom.create("th",{cursor:"pointer"});
				var div = OAT.Dom.create("div");
				th.className = "h1";
				div.innerHTML = this.headerRow[this.rowConditions[j]];
				var ref = this.getClickReference(this.conditions[this.rowConditions[j]]);
				OAT.Dom.attach(th,"click",ref);
				var callback = this.getOrderReference(this.rowConditions[j]);
				this.gd.addSource(div,obj.process,callback);
				this.gd.addTarget(th);
				th.conditionIndex = this.rowConditions[j];
				th.appendChild(div);
				tr.appendChild(th);
			}
			var th = OAT.Dom.create("th"); /* blank space above */
			if (!this.colConditions.length) { 
				th.innerHTML = this.headerRow[this.dataColumnIndex];
				th.style.cursor = "pointer";
				th.className = "h1";
				th.conditionIndex = -1;
				this.gd.addTarget(th);
				/* numerical type change */
				OAT.Dom.attach(th,"click",this.numericalType);
			} else { th.style.border = "none"; }
			th.colSpan = this.numCols + (this.options.headingBefore ? 1 : 0);
			tr.appendChild(th);
			if (this.colConditions.length) { /* blank space after */
				var th = OAT.Dom.create("th",{border:"none"});
				tr.appendChild(th);
			}
			tbody.appendChild(tr);
		}

		/* data */
		for (var i=0;i<this.numRows;i++) {
			var tr = OAT.Dom.create("tr");
			for (var j=0;j<this.rowConditions.length;j++) { /* row values */
				var cond = this.conditions[this.rowConditions[j]];
				if ((i % cond.span) == 0) {
					var th = OAT.Dom.create("th");
					th.className = "h2";
					th.rowSpan = cond.span;
					th.innerHTML = cond.distinctValuesArr[Math.ceil(i/cond.span) % cond.numDistinctValues];
					tr.appendChild(th);
				}
			}
			if (this.colConditions.length && i==0 && this.options.headingBefore) { /* blank space before */
				var th = OAT.Dom.create("th");
				if (!this.rowConditions.length) { 
					th.style.cursor = "pointer";
					th.innerHTML = this.headerRow[this.dataColumnIndex]; 
					th.className = "h1";
					th.conditionIndex = -2;
					this.gd.addTarget(th);
					/* numerical type change */
					OAT.Dom.attach(th,"click",this.numericalType);
				} else { th.style.border = "none"; }
				th.rowSpan = this.numRows;
				tr.appendChild(th);
			}
			for (var j=0;j<this.numCols;j++) { /* data */
				var td = OAT.Dom.create("td");
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
				var result = this.data[j][i];
				switch (self.options.type) { /* numeric type */
					case OAT.PivotData.TYPE_BASIC[0]: result = result.toFixed(2); break;
					case OAT.PivotData.TYPE_PERCENT[0]: result = result.toFixed(2)+"%"; break;
					case OAT.PivotData.TYPE_SCI[0]: result = result.toExponential(2); break;
					case OAT.PivotData.TYPE_SPACE[0]: 
						result = result.toFixed(2); 
						result = result.toString();
						var l = result.length;
						if (l > 6) { 
							result = result.split("");
							result.splice(l-6,0,"&nbsp;");
							result = result.join(""); 
						}
					break;
				}
				td.innerHTML = result;
				tr.appendChild(td);
			}
			if (this.colConditions.length && i==0 && this.options.headingAfter) { /* blank space after */
				var th = OAT.Dom.create("th");
				if (!this.rowConditions.length) { 
					th.innerHTML = this.headerRow[this.dataColumnIndex]; 
					th.style.cursor = "pointer";
					th.className = "h1";
					th.conditionIndex = -2;
					this.gd.addTarget(th);
					/* numerical type change */
					OAT.Dom.attach(th,"click",this.numericalType);
				} else { th.style.border = "none"; }
				th.rowSpan = this.numRows;
				tr.appendChild(th);
			}
			tbody.appendChild(tr);
		}
		
		/* rowConditions headings */
		if (this.rowConditions.length && this.options.headingAfter) {
			var tr = OAT.Dom.create("tr");
			for (var j=0;j<this.rowConditions.length;j++) { /* row headings after */
				var th = OAT.Dom.create("th",{cursor:"pointer"});
				var div = OAT.Dom.create("div");
				th.className = "h1";
				div.innerHTML = this.headerRow[this.rowConditions[j]];
				var ref = this.getClickReference(this.conditions[this.rowConditions[j]]);
				OAT.Dom.attach(th,"click",ref);
				var callback = this.getOrderReference(this.rowConditions[j]);
				this.gd.addSource(div,obj.process,callback);
				this.gd.addTarget(th);
				th.conditionIndex = this.rowConditions[j];
				th.appendChild(div);
				tr.appendChild(th);
			}
			var th = OAT.Dom.create("th"); /* blank row below */
			if (!this.colConditions.length) { 
				th.innerHTML = this.headerRow[this.dataColumnIndex]; 
				th.style.cursor = "pointer";
				th.className = "h1";
				th.conditionIndex = -1;
				this.gd.addTarget(th);
				/* numerical type change */
				OAT.Dom.attach(th,"click",this.numericalType);
			} else { th.style.border = "none"; }
			th.colSpan = this.numCols;
			tr.appendChild(th);
			if (this.colConditions.length) { /* blank space after */
				var th = OAT.Dom.create("th",{border:"none"});
				tr.appendChild(th);
			}
			tbody.appendChild(tr);
		}
		
		table.appendChild(tbody);
		this.div.appendChild(table);
	} /* drawTable */
	
	this.drawChart = function() {
		var bc = obj.barChart;
		bc.options.legend = false;
		var defCArray = ["rgb(153,153,255)","rgb(153,51,205)","rgb(255,255,204)","rgb(204,255,255)","rgb(102,0,102)",
						"rgb(255,128,128)","rgb(0,102,204)","rgb(204,204,255)","rgb(0,0,128)","rgb(255,0,255)",
						"rgb(0,255,255)","rgb(255,255,0)"];
		var cArray = [];
		for (var i=0;i<obj.numRows;i++) { cArray.push(defCArray[i % defCArray.length]); }
		bc.options.colors = cArray;
		var data = [];
		for (var i=0;i<obj.numCols;i++) { 
			var col = [];
			for (var j=obj.numRows-1;j>=0;j--) { col.push(parseFloat(obj.data[i][j])); }
			data.push(col); 
		}
		bc.attachData(data);
		var textX = [];
		var textY = [];
		for (var i=0;i<obj.numCols;i++) {
			var value = [];
			for (var j=0;j<obj.colConditions.length;j++) {
				var cond = obj.conditions[obj.colConditions[j]];
				value.push(cond.distinctValuesArr[Math.floor(i/cond.span) % cond.numDistinctValues]);
			}
			textX.push(value.join("<br/>"));
		}
		for (var i=obj.numRows-1;i>=0;i--) {
			var value = [];
			for (var j=0;j<obj.rowConditions.length;j++) {
				var cond = obj.conditions[obj.rowConditions[j]];
				value.push(cond.distinctValuesArr[Math.floor(i/cond.span) % cond.numDistinctValues]);
			}
			textY.push(value.join(" - "));
		}
		bc.attachTextX(textX);
		bc.attachTextY(textY);
		bc.draw();
	}
	
	this.go = function() {
		for (var i=0;i<obj.conditions.length;i++) { obj.createCondition(i); }
		obj.gd.clearSources();
		obj.gd.clearTargets();
		obj.sort();
		obj.prepare();
		obj.count();
		obj.drawTable();
		if (obj.chartDiv) { 
			if (obj.options.showChart) {
				OAT.Dom.show(obj.chartDiv);
				obj.drawChart();
				var hideStr = OAT.Dom.create("a");
				hideStr.innerHTML = "[hide chart]";
				hideStr.href = "#";
				OAT.Dom.attach(hideStr,"click",function(){obj.options.showChart = 0; obj.go();});
				obj.div.appendChild(hideStr);
			} else {
				OAT.Dom.hide(obj.chartDiv);
				var hideStr = OAT.Dom.create("a");
				hideStr.innerHTML = "[show chart]";
				hideStr.href = "#";
				OAT.Dom.attach(hideStr,"click",function(){obj.options.showChart = 1; obj.go();});
				obj.div.appendChild(hideStr);
			}
		}
	}

	this.init();
	this.go();
}
OAT.Loader.featureLoaded("pivot");
