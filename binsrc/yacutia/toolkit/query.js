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
	queryObj = {
		
	}

*/

var Query = {
	blank:function() {
		var queryObj = {
			query:"", /* full query */
			queryNormalized:"", /* without xml garbage and newlines */
			selectClause:"", /* SELECT ... */
			fromClause:"", /* FROM ... */
			whereClause:"", /* WHERE ... */
			orderClause:"", /* ORDER BY ... */
			groupClause:"", /* GROUP BY ... */
			havingClause:"", /* HAVING ... */
			tables:[], /* fq table names */
			columnPairs:[], /* a AS aa, b AS bb, c, ... */
			columnNames:[], /* a, b, c, ... */
			columns:[], /* aa, bb, c, ... */
			aliases:[], /* aa, bb, "", ... */
			whereTriplets:[], /* a > 7, b = 'q', ... */
			whereOperators:[], /* AND, OR, ... */
			havingTriplets:[], /* a > 7, b = 'q', ... */
			havingOperators:[], /* AND, OR, ... */
			orderPairs:[], /* a ASC, b, ... */
			orderTypes:[], /* ASC, "", ... */
			orders:[], /* a, b, ... */
			groups:[] /* a, b, ... */
		}
		return queryObj;
	},

	split:function(query) {
		var queryObj = Query.blank();
		var keywords = ["SELECT","FROM","WHERE","ORDER BY","GROUP BY","HAVING"];
		var normalized = Query.normalize(query);
		queryObj.query = query;
		queryObj.queryNormalized = normalized;
		
		for (var i=0;i<keywords.length;i++) { 
			var re = new RegExp(keywords[i]);
			normalized = normalized.replace(re,"\n"+keywords[i]); 
		}
		var pieces = normalized.split("\n");
		for (var i=1;i<pieces.length;i++) {	Query.splitPiece(pieces[i],queryObj); }

		return queryObj;
	},
	
	normalize:function(query) {
		/* no newlines */
		var q = query.replace(/[\n\r]/g," ");
		/* sql templates? */
		if (q.match(/<sql/)) { q = q.match(/(SELECT .*)<\/sql/)[1]; }
		if (q.match(/SUB[ ]*$/)) { q = q.match(/FROM \((.*)\) SUB[ ]*$/)[1]; }
		return q;
	},
	
	glue:function(queryObj) {
		var q = "";
		q += queryObj.selectClause+" ";
		q += queryObj.fromClause+" ";
		q += queryObj.whereClause+" ";
		q += queryObj.groupClause+" ";
		q += queryObj.havingClause+" ";
		q += queryObj.orderClause+" ";
		queryObj.query = q;
		queryObj.queryNormalized = q;
	},
	
	createClauses:function(queryObj) {
		if (queryObj.columnPairs.length) { queryObj.selectClause = "SELECT "+queryObj.columnPairs.join(", "); }
//		if (queryObj.tables.length) { queryObj.selectClause = "FROM "+queryObj.columnPairs.join(", ");
		if (queryObj.whereTriplets.length) { 
			queryObj.whereClause = "WHERE ";
			for (var i=0;i<queryObj.whereTriplets.length;i++) {
				if (i) { queryObj.whereClause += " "+queryObj.whereOperators[i-1]+" "; }
				queryObj.whereClause += " "+queryObj.whereTriplets[i]+" ";
			}
		}
		if (queryObj.havingTriplets.length) { 
			queryObj.havingClause = "HAVING ";
			for (var i=0;i<queryObj.havingTriplets.length;i++) {
				if (i) { queryObj.havingClause += " "+queryObj.havingOperators[i-1]+" "; }
				queryObj.havingClause += " "+queryObj.havingTriplets[i]+" ";
			}
		}
		if (queryObj.orderPairs.length) { queryObj.orderClause = "ORDER BY "+queryObj.orderPairs.join(", "); }
		if (queryObj.groups.length) { queryObj.groupClause = "GROUP BY "+queryObj.groups.join(", "); }
	},
	
	
	splitPiece:function(string,queryObj) {
		var word = string.match(/^(\w+) (.*)/);
		switch (word[1]) {
			case "SELECT":
				queryObj.selectClause = string.replace(/\n/g,"");
				var main = word[2];
				var tmp = word[2].match(/TOP [^,]*, [^ ]* *(.*)/)
				if (tmp) { main = tmp[1];}
				var parts = main.split(","); /* list of columns with optional aliases */
				for (var i=0;i<parts.length;i++) {
					var part = parts[i];
					queryObj.columnPairs.push(part);
					if (part.match(/ AS /)) { /* use alias */
						var tmp = part.match(/([^ ]*) AS '([^']*)'/);
						queryObj.columnNames.push(tmp[1]);
						queryObj.aliases.push(tmp[2]);
						queryObj.columns.push(tmp[2]);
					} else { /* no alias */
						var tmp = part.match(/[^ ]+/);
						queryObj.columnNames.push(tmp[0]);
						queryObj.aliases.push("");
						queryObj.columns.push(tmp[0]);
					}
				}
			break;
			
			case "FROM":
				queryObj.fromClause = string.replace(/\n/g,"");
				var corr = string+" ";
				var NAMES = {};
				var tables = corr.match(/ \w*\.\w*\.\w*[, ]/g);
				for (var i=0;i<tables.length;i++) {
					var name = tables[i].match(/(\w*\.\w*\.\w*)/);
					NAMES[name[1]] = 1;
				}
				for (p in NAMES) { queryObj.tables.push(p); }
			break;
			
			case "WHERE":
				queryObj.whereClause = string.replace(/\n/g,"");
				/* same technique as before - add newlines, than split by them */
				var str = word[2];
				str = str.replace(/ AND /," \nAND ");
				str = str.replace(/ OR /," \nOR ");
				var conds = str.split("\n");
				conds[0] = "AND "+conds[0]; /* add temporary AND */
				
				for (var i=0;i<conds.length;i++) {
					var parts = conds[i].match(/(AND|OR) *([^ ]+) *([^ ]+) *([^ ]+)/);
					queryObj.whereTriplets.push(parts[2]+" "+parts[3]+" "+parts[4]);
					if (i) { queryObj.whereOperators.push(parts[1]); }
				}
			break;
			
			case "HAVING":
				queryObj.havingClause = string.replace(/\n/g,"");
				/* same technique as before - add newlines, than split by them */
				var str = word[2];
				str = str.replace(/ AND /," \nAND ");
				str = str.replace(/ OR /," \nOR ");
				var conds = str.split("\n");
				conds[0] = "AND "+conds[0]; /* add temporary AND */
				
				for (var i=0;i<conds.length;i++) {
					var parts = conds[i].match(/(AND|OR) *([^ ]+) *([^ ]+) *([^ ]+)/);
					queryObj.havingTriplets.push(parts[2]+" "+parts[3]+" "+parts[4]);
					if (i) { queryObj.havingOperators.push(parts[1]); }
				}
			break;

			case "ORDER":
				queryObj.orderClause = string.replace(/\n/g,"");
				var main = string.match(/ORDER BY (.*)/)[1];
				var parts = main.split(",");
				for (var i=0;i<parts.length;i++) {
					var pieces = parts[i].match(/([^ ]+) (ASC|DESC)/);
					var name = (pieces ? pieces[1] : parts[i]);
					var type = (pieces ? pieces[2] : "");
					var full = (type == "" ? name : name+" "+type);
					queryObj.orders.push(name);
					queryObj.orderTypes.push(type);
					queryObj.orderPairs.push(full);
				}
			break;

			case "GROUP":
				queryObj.groupClause = string.replace(/\n/g,"");
				var main = string.match(/GROUP BY (.*)/)[1];
				var parts = main.split(",");
				for (var i=0;i<parts.length;i++) {
					var pieces = parts[i].match(/([^ ]+)/);
					queryObj.groups.push(pieces[1]);
				}
			break;
		} /* switch */
	}
	
}