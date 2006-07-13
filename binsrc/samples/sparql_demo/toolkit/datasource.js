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
	var simpleCallback = function(dataRow, currentIndex, totalCount) { alert(currentIndex); }
	var multiCallback = function(dataRows, currentPageIndex, totalCount) { alert(currentPageIndex); }

	d = new OAT.DataSource();
	
	d.bindRecord(simpleCallback);
	d.bindPage(multiCallback, pageSize);
	
	d.advancePage(something);   something: "-1","+1",number
	d.advanceRecord(something);   something: "-1","+1",number
	
	d.executeQuery(q);
	d.executeData(data);
	
*/

OAT.DataSource = function() {
	var self = this;
	self.boundRecords = [];
	self.boundPages = [];
	self.boundEmpties = [];
	self.boundHeaders = [];
	self.dataRows = [];
	self.index = 0;
	self.count = 0;
	
	this.bindEmpty = function(callback) {
		var index = self.boundEmpties.length;
		self.boundEmpties.push({callback:callback});
		return index;
	}
	
	this.bindRecord = function(callback) {
		var index = self.boundRecords.length;
		self.boundRecords.push({callback:callback});
		return index;
	}
	
	this.bindPage = function(callback,size) {
		/* page == set of records */
		var index = self.boundPages.length;
		self.boundPages.push({callback:callback,size:size,index:0});
		return index;
	}
	
	this.bindHeader = function(callback) {
		var index = self.boundHeaders.length;
		self.boundHeaders.push({callback:callback});
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

	this.executeQuery = function(q,oneShotCallback) {
		var recieveRef = function(data) {
			if (oneShotCallback) { oneShotCallback(); }
			self.executeHeader(data[0]);
			self.executeData(data[1]);
			
		}
		OAT.Xmla.query = q;
		OAT.Xmla.execute(recieveRef);
	}
	
	this.executeHeader = function(header) {
		for (var i=0;i<self.boundHeaders.length;i++) {
			self.boundHeaders[i].callback(header);
		}
	}
	
	this.executeData = function(data) {
		self.dataRows = data;
		self.index = -1;
		self.count = data.length;
		self.advancePage(0);
		self.advanceRecord(0);
		if (self.count == 0) {
			for (var i=0;i<self.boundEmpties.length;i++) {
				var callback = self.boundEmpties[i].callback;
				callback();
			}
		}
	}
	
	this.advanceRecord = function(something) {
		/* get new index */
		var newIndex = -1;
		if (typeof(something) == "string") {
			if (something == "+1" && self.index+1 < self.count) { newIndex = self.index+1; }
			if (something == "-1" && self.index > 0) { newIndex = self.index-1; }
		} else {
			if (something >= 0 && something < self.count) { newIndex = something; }
		}
		if (newIndex == -1 || newIndex == self.index) { return; }
		self.index = newIndex;
		self.actualize();
	}
	
	this.advancePage = function(something) {
		for (var i=0;i<self.boundPages.length;i++) {
			var bp = self.boundPages[i];
			/* find correct new index */
			var newIndex = -1;
			if (typeof(something) == "string") {
				if (something == "+1" && (bp.index+1)*bp.size < self.count) { newIndex = bp.index+1; }
				if (something == "-1" && bp.index > 0) { newIndex = bp.index-1; }
			} else {
				if (something > 0 && something*bp.size < self.count) { newIndex = something; }
			}
			if ((newIndex != -1 && bp.index != newIndex) || bp.size == -1) {
				bp.index = (bp.size == -1 ? 0 : newIndex);
				var data = [];
				var limit = Math.min(self.count,(bp.index+1)*bp.size);
				if (bp.size == -1) { limit = self.count; }
				for (var j=bp.index*bp.size;j<limit;j++) {
					data.push(self.dataRows[j]);
				}
				bp.callback(data,bp.index,self.count);
			} /* ok, let's populate it */
		} /* all page requesting objects */
	}
	
	this.actualize = function() {
		/* populate objects based on current index */
		var data = self.dataRows[self.index];
		for (var i=0;i<self.boundRecords.length;i++) {
			/* notify all recieving objects */
			var binding = self.boundRecords[i];
			binding.callback(data,self.index,self.count);
		}
	}
}
OAT.Loader.pendingCount--;
