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
	var sp = new OAT.SparqlQuery();
	so.fromString(str)
	so.toString()
	
	so.variables = ['a','b','c']
*/

OAT.SparqlQuery = function() {
	var self = this;
	this.variables = [];
	
	this.clear = function() {
		self.variables = [];
	}
	
	this.splitPiece = function(string) {
		var word = string.match(/^(\w+) (.*)/);
		switch (word[1].toUpperCase()) {
			case "SELECT":
				var main = word[2];
				var tmp = main.match(/(distinct)? *(.*)/i);
				var part = tmp[2];
				var tmp = part.match(/(\w+)/g);
				for (var i=0;i<tmp.length;i++) { self.variables.push(tmp[i]); }
			break;
		} /* switch */
	}
	
	this.fromString = function(str) {
		self.clear();
		
		var keywords = ["PREFIX","SELECT","FROM","WHERE","ORDER BY"];
		/* normalize */
		var q = str.replace(/[\n\r]/g," ");
		
		for (var i=0;i<keywords.length;i++) { 
			var re = new RegExp(keywords[i],"i");
			q = q.replace(re,"\n"+keywords[i]); 
		}
		
		var pieces = q.split("\n");
		for (var i=1;i<pieces.length;i++) {	self.splitPiece(pieces[i]); }
	}
	
	this.toString = function() {
	}
}
OAT.Loader.pendingCount--;
