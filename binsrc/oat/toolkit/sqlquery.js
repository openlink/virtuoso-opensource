/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2012 OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
	var sq = new OAT.SqlQuery();
	sq.fromString(str)
	sq.toString(type)

	sq.limit
	sq.offset

	sq.columns.count
	sq.columns.items[index].column
	sq.columns.items[index].alias
	sq.columns.getFull(index)
	sq.columns.getResult(index)
	sq.columns.add()
	sq.columns.remove(index)

	sq.tablesString

	sq.tables

	sq.joins = [];

	sq.conditions.count
	sq.conditions.items[index].column
	sq.conditions.items[index].operator
	sq.conditions.items[index].value
	sq.conditions.items[index].logic
	sq.conditions.getFull(index);
	sq.conditions.add()
	sq.conditions.remove(index)

	sq.havings.count
	sq.havings.items[index].column
	sq.havings.items[index].operator
	sq.havings.items[index].value
	sq.havings.items[index].logic
	sq.havings.getFull(index);
	sq.havings.add()
	sq.havings.remove(index)

	sq.orders.count
	sq.orders.items[index].column
	sq.orders.items[index].type
	sq.orders.getFull(index)
	sq.orders.add()
	sq.orders.remove(index)

	sq.groups.count
	sq.groups.items[index].column
	sq.groups.getFull(index)
	sq.groups.add()
	sq.groups.remove(index)

*/

OAT.SqlQueryData = {
	TYPE_SQL:1,
	TYPE_FORXML_RAW:2,
	TYPE_FORXML_AUTO:3,
	TYPE_SQLX_ATTRIBUTES:4,
	TYPE_SQLX_ELEMENTS:5,
	columnQualifierPre:'"',
	columnQualifierPost:'"',

	escapedQualifiers:function() {
		var q1 = OAT.SqlQueryData.columnQualifierPre;
		var q2 = OAT.SqlQueryData.columnQualifierPost;
		var re = new RegExp(/[\.\[\]\(\)\^\$\*\?\+]/);
		var eq1 = (q1.match(re) ? "\\"+q1 : q1);
		var eq2 = (q2.match(re) ? "\\"+q2 : q2);
		return [eq1,eq2];
	},

	deQualifyOne:function(str) {
		if (str.charAt(0) != OAT.SqlQueryData.columnQualifierPre) { return str; }
		var l = str.length;
		return str.substring(1,l-1);
	},

	qualifyOne:function(str) {
		var tmp = OAT.SqlQueryData.deQualifyOne(str);
		return OAT.SqlQueryData.columnQualifierPre+tmp+OAT.SqlQueryData.columnQualifierPost;
	},

	deQualifyMulti:function(str) {
		var parts = str.split(".");
		for (var i=0;i<parts.length;i++) { parts[i] = OAT.SqlQueryData.deQualifyOne(parts[i]); }
		return parts.join(".");
	},

	qualifyMulti:function(str) {
		var parts = str.split(".");
		for (var i=0;i<parts.length;i++) { parts[i] = OAT.SqlQueryData.qualifyOne(parts[i]); }
		return parts.join(".");
	}
}

OAT.SqlQuery = function() {
	var self = this;

	this.limit = -1;
	this.offset = 0;

	this.tablesString = "";
	this.tables = [];

	this.columns = {
		count:0,
		items:[],
		getFull:function(index) {
			if (self.columns.items[index].alias != "") {
				return self.columns.items[index].column+" AS '"+self.columns.items[index].alias+"'";
			} else {
				return self.columns.items[index].column;
			}
		},
		getResult:function(index) {
			if (self.columns.items[index].alias != "") {
				return "'"+self.columns.items[index].alias+"'";
			} else {
				return self.columns.items[index].column;
			}
		},
		add:function() {
			var n = {
				column:"",
				alias:""
			};
			self.columns.items.push(n);
			self.columns.count++;
			return n;
		},
		remove:function(index) {
			self.columns.items.splice(index,1);
			self.columns.count--;
		}
	}

	this.conditions = {
		count:0,
		items:[],
		add:function() {
			var n = {
				column:"",
				operator:"",
				value:"",
				logic:""
			};
			self.conditions.items.push(n);
			self.conditions.count++;
			return n;
		},
		getFull:function(index) {
			var i = self.conditions.items[index];
			return i.column+" "+i.operator+" "+i.value;
		},
		remove:function(index) {
			self.conditions.items.splice(index,1);
			self.conditions.count--;
		}
	}

	this.havings = {
		count:0,
		items:[],
		add:function() {
			var n = {
				column:"",
				operator:"",
				value:"",
				logic:""
			};
			self.havings.items.push(n);
			self.havings.count++;
			return n;
		},
		getFull:function(index) {
			var i = self.havings.items[index];
			return i.column+" "+i.operator+" "+i.value;
		},
		remove:function(index) {
			self.havings.items.splice(index,1);
			self.havings.count--;
		}
	}

	this.orders = {
		count:0,
		items:[],
		add:function() {
			var n = {
				column:"",
				type:""
			};
			self.orders.items.push(n);
			self.orders.count++;
			return n;
		},
		getFull:function(index) {
			var i = self.orders.items[index];
			if (i.type != "") {
				return i.column+" "+i.type;
			} else {
				return i.column;
			}
		},
		remove:function(index) {
			self.orders.items.splice(index,1);
			self.orders.count--;
		}
	}

	this.groups = {
		count:0,
		items:[],
		add:function() {
			var n = {
				column:""
			};
			self.groups.items.push(n);
			self.groups.count++;
			return n;
		},
		getFull:function(index) {
			var i = self.groups.items[index];
			return i.column;
		},
		remove:function(index) {
			self.groups.items.splice(index,1);
			self.groups.count--;
		}
	}

	this.joins = []; /* {table1:"",table2:"",row1:"",row2:""} */

	this.toString = function(type) {
		var q = "";
		q += "SELECT ";
		if (self.limit != -1) { q += " TOP "+self.limit+" "; }
		var coltmp = [];
		for (var i=0;i<self.columns.count;i++) {
			coltmp.push(self.columns.getFull(i));
		}
		q += " "+coltmp.join(", ")+" ";

		q += " FROM "+self.tablesString+" ";

		if (self.conditions.count) {
			q += " WHERE ";
			for (var i=0;i<self.conditions.count;i++) {
				q += " "+(i ? self.conditions.items[i].logic : "")+" "+self.conditions.getFull(i)+" ";
			}
		}

		if (self.groups.count) {
			q += " GROUP BY ";
			var tmp = [];
			for (var i=0;i<self.groups.count;i++) {
				tmp.push(self.groups.getFull(i));
			}
			q += " "+tmp.join(", ")+" ";
		}

		if (self.havings.count) {
			q += " HAVING ";
			for (var i=0;i<self.havings.count;i++) {
				q += " "+self.havings.getFull(i)+" ";
				if (i+1 != self.havings.count) {
					q+= " "+self.havings.items[i].logic+" ";
				}
			}
		}

		if (self.orders.count) {
			q += " ORDER BY ";
			var tmp = [];
			for (var i=0;i<self.orders.count;i++) {
				tmp.push(self.orders.getFull(i));
			}
			q += " "+tmp.join(", ")+" ";
		}

		switch (type) {
			case OAT.SqlQueryData.TYPE_SQL:
				return q;
			break;

			case OAT.SqlQueryData.TYPE_FORXML_AUTO:
				return q + " FOR XML AUTO";
			break;
			case OAT.SqlQueryData.TYPE_FORXML_RAW:
				return q + " FOR XML RAW";
			break;
			case OAT.SqlQueryData.TYPE_SQLX_ATTRIBUTES:
				var sqlx_pre = "SELECT XMLELEMENT ('ROW', XMLATTRIBUTES (" + coltmp.join(", ") + ")) FROM (";
				var sqlx_post = " ) SUB";
				return sqlx_pre + "\n" + q + sqlx_post;
			break;

			case OAT.SqlQueryData.TYPE_SQLX_ELEMENTS:
				var sqlx_pre = "SELECT XMLELEMENT ('ROW', XMLFOREST (" + coltmp.join(", ") + ")) FROM (";
				var sqlx_post = " ) SUB";
				return sqlx_pre + "\n" + q + sqlx_post;
			break;
		}
		return false;
	}

	this.splitPiece = function(string) {
		var word = string.match(/^(\w+) (.*)/);
		switch (word[1]) {
			case "SELECT":
				var main = word[2];
				var tmp = word[2].match(/TOP +([^ ]+) +(.*)/)
				if (tmp) {
					self.limit = tmp[1];
					main = tmp[2];
				}
				var parts = main.split(","); /* list of columns with optional aliases */
				for (var i=0;i<parts.length;i++) {
					var part = parts[i];
					var c = self.columns.add();
					if (part.match(/ AS /)) { /* use alias */
						var tmp = part.match(/(.*?) AS '([^']*)'/);
						c.alias = tmp[2];
						c.column = tmp[1];
					} else { /* no alias */
						var trim = part.trim();
						c.alias = "";
						c.column = trim;
					}
				}
			break;

			case "FROM":
				self.tablesString = word[2];
				var corr = string+" ";
				var NAMES = {};
				/* detect qualifier character for smarter table analysis */
				var qChars = word[2].match(/^ *([^ ]).*([^ ]) *$/);
				if (qChars) {
					OAT.SqlQueryData.columnQualifierPre = qChars[1];
					OAT.SqlQueryData.columnQualifierPost = qChars[2];
				}
				var q = OAT.SqlQueryData.escapedQualifiers();
				var re1 = new RegExp(" "+q[0]+"[^"+q[1]+"]+"+q[1]+"\."+q[0]+"[^"+q[1]+"]+"+q[1]+"\."+q[0]+"[^"+q[1]+"]+"+q[1]+"[, ]","g"); /* with catalogs */
				var re2 = new RegExp(" "+q[0]+"[^"+q[1]+"]+"+q[1]+"[, ]","g"); /* without catalogs */
				var tables1 = corr.match(re1);
				var tables2 = corr.match(re2);
				var t1 = (tables1 ? tables1 : []);
				var t2 = (tables2 ? tables2 : []);
				var tables = t1.concat(t2);
				for (var i=0;i<tables.length;i++) {
					var name = tables[i].trim();
					var dq = OAT.SqlQueryData.deQualifyMulti(name);
					NAMES[dq] = 1;
				}
				for (p in NAMES) { self.tables.push(p); }

				/* also relations */
				var cat_tablecol = q[0]+"[^"+q[1]+"]+"+q[1]+"\."+q[0]+"[^"+q[1]+"]+"+q[1]+"\."+q[0]+"[^"+q[1]+"]+"+q[1]+"\."+q[0]+"[^"+q[1]+"]+"+q[1];
				var noncat_tablecol = q[0]+"[^"+q[1]+"]+"+q[1]+"\."+q[0]+"[^"+q[1]+"]+"+q[1];
				var cat_pattern = new RegExp(" "+cat_tablecol +" *= *"+cat_tablecol,"g");
				var noncat_pattern = new RegExp(" "+noncat_tablecol +" *= *"+noncat_tablecol,"g");
				var on1 = corr.match(cat_pattern);
				var on2 = corr.match(noncat_pattern);
				var patts1 = (on1 ? on1 : []);
				var patts2 = (on2 ? on2 : []);
				var patts = patts1.concat(patts2);
				for (var i=0;i<patts.length;i++) {
					var patt = patts[i];
					var restr = " *(.*)\."+q[0]+"([^"+q[1]+"]+)"+q[1]+" *= *(.*)\."+q[0]+"([^"+q[1]+"]+)"+q[1]+" *$";
					var re = new RegExp(restr);
					var r = patt.match(re);
					var o = {};
					o.table1 = r[1];
					o.table2 = r[3];
					o.row1 = r[2];
					o.row2 = r[4];
					self.joins.push(o);
				}
			break;

			case "WHERE":
				/* same technique as before - add newlines, than split by them */
				var str = word[2];
				str = str.replace(/ AND /," \nAND ");
				str = str.replace(/ OR /," \nOR ");
				var conds = str.split("\n");
				conds[0] = "AND "+conds[0]; /* add temporary AND */
				for (var i=0;i<conds.length;i++) {
					var c = self.conditions.add();
					var q = OAT.SqlQueryData.escapedQualifiers();
					var re = new RegExp("(AND|OR) *("+q[0]+".*"+q[1]+") *([^ ]+) *([^ ]+)");
					var parts = conds[i].match(re);
					c.column = parts[2];
					c.operator = parts[3];
					c.value = parts[4];
					c.logic = parts[1];
				}
			break;

			case "HAVING":
				/* same technique as before - add newlines, than split by them */
				var str = word[2];
				str = str.replace(/ AND /," \nAND ");
				str = str.replace(/ OR /," \nOR ");
				var conds = str.split("\n");
				conds[0] = "AND "+conds[0]; /* add temporary AND */

				for (var i=0;i<conds.length;i++) {
					var c = self.havings.add();
					var q = OAT.SqlQueryData.escapedQualifiers();
					var re = new RegExp("(AND|OR) *("+q[0]+".*"+q[1]+") *([^ ]+) *([^ ]+)");
					var parts = conds[i].match(re);
					c.column = parts[2];
					c.operator = parts[3];
					c.value = parts[4];
					if (i) { c.logic = parts[1]; }
				}
			break;

			case "ORDER":
				var main = string.match(/ORDER BY (.*)/)[1];
				var parts = main.split(",");
				for (var i=0;i<parts.length;i++) {
					var c = self.orders.add();
					var pieces = parts[i].match(/ *(.*?) +(ASC|DESC)/);
					if (pieces) {
						c.column = pieces[1];
						c.type = pieces[2];
					} else {
						c.column = parts[i];
					}
				}
			break;

			case "GROUP":
				var main = string.match(/GROUP BY (.*)/)[1];
				var parts = main.split(",");
				for (var i=0;i<parts.length;i++) {
					var c = self.groups.add();
					var pieces = parts[i].trim();
					c.column = pieces[1];
				}
			break;
		} /* switch */
	}

	this.fromString = function(str) {
		var keywords = ["SELECT","FROM","WHERE","ORDER BY","GROUP BY","HAVING"];
		/* normalize */
		var q = str.replace(/[\n\r]/g," ");
		/* sql templates? */
		if (q.match(/<sql/)) { q = q.match(/(SELECT .*)<\/sql/)[1]; }
		if (q.match(/<query/)) { q = q.match(/(SELECT .*)<\/query/)[1]; }
		if (q.match(/FOR XML/)) { q = q.match(/(SELECT .*)FOR XML/)[1]; }
		if (q.match(/SUB[ ]*$/)) { q = q.match(/FROM \((.*)\) SUB[ ]*$/)[1]; }

		for (var i=0;i<keywords.length;i++) {
			var re = new RegExp(keywords[i]);
			q = q.replace(re,"\n"+keywords[i]);
		}

		var pieces = q.split("\n");
		for (var i=1;i<pieces.length;i++) {	self.splitPiece(pieces[i]); }

	}
}
