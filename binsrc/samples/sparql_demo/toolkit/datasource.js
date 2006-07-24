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
	var simpleCallback = function(dataRow, currentIndex) { alert(currentIndex); }
	var multiCallback = function(dataRows, currentPageIndex) { alert(currentPageIndex); }

	d = new OAT.DataSource(limit);
	
	d.bindRecord(simpleCallback);
	d.bindPage(multiCallback, pageSize);
	
	d.advancePage(something);   something: "-1","+1",number
	d.advanceRecord(something);   something: "-1","+1",number
	
	d.executeQuery(q);
	d.executeData(data);
	
*/

OAT.DataSource = function(pageSize) {
	var self = this;
	self.boundRecords = [];
	self.boundPages = [];
	self.boundEmpties = [];
	self.boundHeaders = [];
	self.dataRows = [];
	self.recordIndex = -1; /* 0 .. self.dataRows.length */
	self.pageIndex = -1; /* 0 .. self.dataRows.length */
	self.pageSize = pageSize; /* if 0 then fetch all */
	self.limit = pageSize;
	
	self.type = 0; /* 1 - sql, 2 - wsdl */
	self.query = "";
	self.wsdl = "";
	self.service = "";
	self.inputObj = {};
	self.outputFields = [];
	
	/* ------------------------------ binding -------------------------------*/
	
	this.bindEmpty = function(callback) {
		var index = self.boundEmpties.length;
		self.boundEmpties.push(callback);
		return index;
	}
	
	this.bindRecord = function(callback) {
		var index = self.boundRecords.length;
		self.boundRecords.push(callback);
		return index;
	}
	
	this.bindPage = function(callback) {
		/* page == set of records */
		var index = self.boundPages.length;
		self.boundPages.push(callback);
		return index;
	}
	
	this.bindHeader = function(callback) {
		var index = self.boundHeaders.length;
		self.boundHeaders.push(callback);
		return index;
	}
	
	this.unBindEmpty = function(index) {
		self.boundEmpties.splice(index,1);
	}
	
	this.unBindRecord = function(index) {
		self.boundRecords.splice(index,1);
	}
	
	this.unBindPage = function(index) {
		self.boundPages.splice(index,1);
	}
	
	this.unBindHeader = function(index) {
		self.boundHeaders.splice(index,1);
	}

	/* ------------------------------ processing -------------------------------*/
			
	/* set datasource to initial state */
	this.init = function(query) {
		self.recordIndex = -1;
		self.pageIndex = -1;
		self.dataRows = [];
		self.type = 0;
		}
	
	this.setQuery = function(query) {
		self.query = query;
		self.type = 1;
	}
	
	this.setWSDL = function(wsdl,service,inputObj,outputFields) {
		self.wsdl = wsdl;
		self.service = service;
		self.inputObj = inputObj;
		self.outputFields = outputFields;
		self.type = 2;
	}
	
	this.wsdl2table = function(obj) { /* converts wsdl's output object into two-dimensional structure */
		var allValues = {};
		var data = [];
		function getValues(o,propertyName) {
			var list = [];
			if (typeof(o) != "object") { return list; }
			for (var p in o) {
				var v = o[p];
				if (p == propertyName) { list.append(v); }
				if (v instanceof Object) {
					if (v instanceof Array) {
						for (var i=0;i<v.length;i++) {
							list.append(getValues(v[i],propertyName));
						}
					} else {
						list.append(getValues(v,propertyName));
					}
				} /* recursion */
			} /* for all properties */
			return list;
		}
		
		/* analyze maximum count */
		var max = 0;
		for (var i=0;i<self.outputFields.length;i++) {
			var name = self.outputFields[i];
			/* find number of appearances of this output field in output object */
			var values = getValues(obj,name);
			allValues[name] = values;
			var l = values.length;
			if (l > max) { max = l; }
		}
		for (var i=0;i<max;i++) {
			var row = [];
			for (var j=0;j<self.outputFields.length;j++) {
				var name = self.outputFields[j];
				var values = allValues[name];
				row.push(values[i % values.length]);
			}
			data.push(row);
		}
		return [self.outputFields,data];
	}
	
	/* test data for presence */
	this.checkAvailability = function(index,strict) { /* we want PAGE starting at 'index'. is it possible? */
		/*
			a) all data cached -> true
			b) all data missing -> false
			c) some data present -> true <=> !strict
		*/
		if (!self.pageSize) { return (strict ? false : true); }
		var end = index + self.pageSize;
		var count = 0;
		for (var i=index;i<end;i++) {
			if (self.dataRows[i]) { count++; }
		}
		if (!count) { return false; }
		if (count == self.pageSize) { return true; }
		return (strict ? false : true);
	}
	
	/* retrieve one record from cache */
	this.fetchRecord = function(index,callback) { 
		/* never sends queries, since appropriate page has to be recieved first! */
		if (self.dataRows[index]) { callback(); }
			}
	
	/* retrieve one page; either from cache or db */
	this.fetchPage = function(index,callback) {
		if (self.checkAvailability(index,true)) { callback(); return; }
		
		switch (self.type) {
			case 1: /* query */
				var ref = function(data) {
					self.processData(data,index);
					if (self.checkAvailability(index,false)) { callback(); }
		}
				OAT.Xmla.query = self.query;
				OAT.Xmla.execute(ref,{limit:self.limit,offset:index});
			break;
			
			case 2: /* wsdl */
				var ref = function(outputObj) {
					var data = self.wsdl2table(outputObj);
					self.processData(data,index);
					if (self.checkAvailability(index,false)) { callback(); }
	}
				OAT.WS.invoke(self.wsdl,self.service,ref,self.inputObj);
			break;
	
		}
		
	}
	
	/* add data to cache */
	this.processData = function(data,index) {
		self.header = data[0];
		var d = data[1];
		for (var i=0;i<d.length;i++) { 
			self.dataRows[i+index] = d[i];
		}
		if (self.recordIndex == -1) {
			/* very first time data arrived: headers, maybe blank */
			if (self.oneShotCallback) { self.oneShotCallback(); }
			for (var i=0;i<self.boundHeaders.length;i++) { self.boundHeaders[i](self.header); }
			if (!self.dataRows[index]) {
				for (var i=0;i<self.boundEmpties.length;i++) { self.boundEmpties[i](); }
			}
		}
	}
	
	/* calculate new index */
	this.getNewIndex = function(something,index,size) {
		/* get new index number specified by 'something', when located @ index with page size 'size' */
			var newIndex = -1;
			if (typeof(something) == "string") {
//			if (something == "+1" && (index+1)*size < self.count) { newIndex = index+1; }
			if (something == "+1") { newIndex = index+1; }
			if (something == "-1" && index > 0) { newIndex = index-1; }
			} else {
//			if (something >= 0 && something*size < self.count) { newIndex = something; }
			if (something >= 0) { newIndex = something; }
				}
		return newIndex;
	}
	
	/* go to record # */
	this.advanceRecord = function(something) {
		/* get the record number we want */
		var newIndex = self.getNewIndex(something,self.recordIndex,1); /* this is new requested index */
		if (newIndex == -1 || newIndex == self.index) { return; } /* do nothing if is not correct */
		
		var newPageIndex = (self.pageSize ? Math.floor(newIndex / self.pageSize) : 0) * self.pageSize;
		/* sometimes we also have to change page */
		var callback = function() {
			self.recordIndex = newIndex;
		/* populate objects based on current index */
			var data = self.dataRows[self.recordIndex];
		for (var i=0;i<self.boundRecords.length;i++) {
			/* notify all recieving objects */
				self.boundRecords[i](data,self.recordIndex);
			}
		}
		var command = function() { self.fetchRecord(newIndex,callback); }
		if (newPageIndex == self.pageIndex) { command(); } else {
			self.advancePage(newPageIndex,command);
	}
	}
	
	/* go to page #, not to be directly called! */
	this.advancePage = function(newIndex,command) {
		/* get the page we want */
		var callback = function() {
			var data = [];
			self.pageIndex = newIndex;
			var l = (self.pageSize ? Math.min(self.pageSize+self.pageIndex,self.dataRows.length) : self.dataRows.length);
			for (var j=self.pageIndex;j<l;j++) {
				data.push(self.dataRows[j]);
			}
			for (var i=0;i<self.boundPages.length;i++) {
				self.boundPages[i](data,self.pageIndex);
			} /* all page requesting objects */
			command();
		}
		self.fetchPage(newIndex,callback);
	}
	
}
OAT.Loader.pendingCount--;
