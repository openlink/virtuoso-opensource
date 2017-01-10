/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2017 OpenLink Software
 *
 *  See LICENSE file for details.
 */

/*
	var sp = new OAT.SparqlQuery();
	so.fromString(str)
	so.toString()

	so.prefixes = [{"label": 'foaf',"uri":'http://xmlns.com/foaf/0.1/'}];
	so.distinct = false;
	so.variables = ['a','b','c']
	so.from = '<http://example.com/graph>' || ['<http://example.com/graph1>','<http://example.com/graph2>']
	so.from_named = ['<http://example.com/named1>','<http://example.com/named2>'];
	so.where = {}; // Look at the OAT.SparqlQueryData* for description.
	so.limit = 10
	so.offset = 5
	so.orders = [{"desc": false,"variable":'?a'},{"desc": true,"variable":'?b'}]
*/

//OAT.SparqlQueryDataBasic = function(pobj,obj) {
//	this.parent = pobj;
//	this.obj = obj;
//	this.type = '';
//}

OAT.SparqlQueryDataGroup = function(pobj,obj) {
	this.parent = pobj;
	this.obj = obj;
  this.type = 'group';
	this.children = [];
}
//OAT.SparqlQueryDataGroup.prototype = new OAT.SparqlQueryDataBasic();

OAT.SparqlQueryDataOptional = function(pobj,obj) {
	this.parent = pobj;
	this.obj = obj;
  this.type = 'optional';
	this.content = false;
}
//OAT.SparqlQueryDataOptional.prototype = new OAT.SparqlQueryDataBasic();

OAT.SparqlQueryDataGraph = function(pobj,obj) {
	this.parent = pobj;
	this.obj = obj;
  this.type = 'graph';
  this.name = '';
	this.content = false;
}
//OAT.SparqlQueryDataGraph.prototype = new OAT.SparqlQueryDataBasic();

OAT.SparqlQueryDataUnion = function(pobj,obj) {
	this.parent = pobj;
	this.obj = obj;
  this.type = 'union';
	this.children = [];
}
//OAT.SparqlQueryDataUnion.prototype = new OAT.SparqlQueryDataBasic();

OAT.SparqlQueryDataPattern = function(pobj,obj) {
	this.parent = pobj;
	this.obj = obj;
  this.type = 'pattern';
	this.s = '';
	this.p = '';
	this.o = '';
	this.otype = '';
	this.separator = '';
	this.filter = '';
	this.filterRegex = false;
}
//OAT.SparqlQueryDataPattern.prototype = new OAT.SparqlQueryDataBasic();

OAT.SparqlQuery = function() {
	var self = this;
	this.variables = [];
	this.distinct = false;
	this.mode = "SELECT";
	this.prefixes = [];
	this.orders = [];
	this.limit = false;
	this.offset = false;
	this.from = '';
	this.from_named = [];
	this.where = [];
	self.construct = false;

	this.clear = function() {
		self.variables = [];
		self.distinct = false;
		self.mode = "SELECT";
		self.prefixes = [];
		self.orders = [];
		self.limit = false;
		self.offset = false;
		self.from = '';
		self.from_named = [];
		self.where = [];
		self.construct = false;
	}

	this.splitPiece = function(string) {
		var word = string.match(/^(\w+)\s*(.*)/);
		switch (word[1].toUpperCase()) {
			case "DESCRIBE":
				self.mode = "DESCRIBE";
			case "SELECT":
				self.mode = "SELECT";
				var main = word[2];
  				var tmp = main.match(/(distinct)?\s*(.*)/i);
  				var part = tmp[2];
  				if (tmp[1]) self.distinct = true;
  				if (tmp[2].trim() != '*')
  				{
    				var tmp = part.match(/(\w+)/g);
    				for (var i=0;i<tmp.length;i++) { self.variables.push(tmp[i]); }
    			}
			break;
			case "PREFIX":
				var main = word[2];
				var tmp = main.match(/(\w*):\W*<(.*)>/i);
				var label = tmp[1];
				var uri = tmp[2];
				self.prefixes.push({"label": label,"uri":uri});
			break;
			case "ORDER":
				var main = word[2];
				var tmp = main.match(/\W*by(.*)/i);
				var orders = tmp[1].trim();
				var tmp = orders.match(/((desc)?\W*\(?\W*\w+[^\?\w]*\)?)/ig);
				for (var i=0;i<tmp.length;i++) {
  				var ord = tmp[i].match(/((desc)?\W*\(?\W*(\w+)[^\?\w]*\)?)/i);
				  var desc = false;
				  var variable = ord[3];
				  if (ord[2] != undefined)
				    desc = true;
  				self.orders.push({"desc": desc,"variable":variable});
				}
			break;
			case "LIMIT":
				var main = word[2];
				var tmp = main.match(/\W*([0-9]*)/i);
				self.limit = tmp[1];
			break;
			case "OFFSET":
				var main = word[2];
				var tmp = main.match(/\W*([0-9]*)/i);
				self.offset = tmp[1];
			break;
			case "FROM":
				var main = word[2];
				var tmp = main.match(/(named)?\s*(.*)/i);
				if (tmp[1])
				  self.from_named.push(self.expandPrefix(tmp[2]));
				else
				  if (self.from instanceof Array)
				    self.from.push(self.expandPrefix(tmp[2]));
				  else
				    if (self.from.trim() != '')
				      self.from = Array(self.from,self.expandPrefix(tmp[2]));
				    else
				      self.from = self.expandPrefix(tmp[2]);
			break;
			case "INSERT":
			case "DELETE":
				self.mode = word[1];
				var main = word[2];
				window.m = main;
				var regs = main.match(/\s*(INTO|FROM)\s*GRAPH\s*(<[^>]+>)(.*)/);
				self.from = regs[2];
				var main = regs[3];
				var bidx = main.indexOf('{');
				var eidx = main.lastIndexOf('}');
				self.parseWhere(main.substring(bidx + 1,eidx));
			break
			case "WHERE":
				var main = word[2];
				var bidx = main.indexOf('{');
				var eidx = main.lastIndexOf('}');
				self.parseWhere(main.substring(bidx + 1,eidx));
			break;
			case "CONSTRUCT":
				var main = word[2];
				var bidx = main.indexOf('{');
				var eidx = main.lastIndexOf('}');
				self.parseConstruct(main.substring(bidx + 1,eidx));
			break;
		} /* switch */
	}

	this.parseWhere = function(where) {
	  self.where = self.parseParts(where,self);
	}

	this.parseConstruct = function(construct) {
	  self.construct = self.parseParts(construct,self);
	}

	this.parseParts = function(str,pobj,prev) {
	  str = str.trim();

	  // separate the parts
		var parts = self.getParts(str);
	  // If we have more than one part then this is a group and we process each part separately
		if (parts.length > 1)
		{
	    var obj = new OAT.SparqlQueryDataGroup(pobj,self);
	    prev = false;
		  for (var i = 0; i < parts.length; i++)
		  {
		    var part = self.parseParts(parts[i],obj,prev);
		    if (part)
		    {
		      obj.children.push(part);
		      prev = part;
		    }
		  }
		} else {
	  // We don't have parts, so we try to determine the type of this section
		  var tmp = '';
	    // Is it union?  {  } union {  } we need another function for this - breakUnions
		  if ((tmp = self.breakUnions(str)))
		  {
	      var obj = new OAT.SparqlQueryDataUnion(pobj,self);
  		  for (var t = 0; t < tmp.length; t++)
  		    obj.children.push(self.parseParts(tmp[t],obj));
	    }
	    // Is it graph?   graph ?g {  }
		  else if ((tmp = str.match(/graph\s*([^ ]*)\s*{+(.*)}+\W*$/i)))
		  {
	      var obj = new OAT.SparqlQueryDataGraph(pobj,self);
	      obj.name = self.expandPrefix(tmp[1]);
	      obj.content = self.parseParts(tmp[2],obj)
	    }
	    // Is it optional?   optional {  }
		  else if ((tmp = str.match(/optional\s*{+(.*)}+\W*$/i)))
		  {
	      var obj = new OAT.SparqlQueryDataOptional(pobj,self);
	      obj.content = self.parseParts(tmp[1],obj)
	    }
	    // So we must be pattern
		  else
		  {
		    str = str.trim();
		    var tmp;
		    if ((tmp = str.match(/^{(.*)}$/)))
		      str = tmp[1].trim();
	      var obj = new OAT.SparqlQueryDataPattern(pobj,self);
		    //Get the separator
	      if ((tmp = str.match(/([\.,;])$/)))
	      {
	        obj.separator = tmp[1];
	        str = str.match(/(.*)[\.,;]$/)[1].trim();
	      }
	      if ((tmp = str.match(/^(.*)filter\W+(regex)?\W*\((.*)\)\W*$/i)))
	      {
	        var RegEx = false;
	        if (tmp[2] != undefined)
	          RegEx = true;
	        if (tmp[1].trim() == '')
	        {
	          prev.filterRegex = RegEx;
	          prev.filter = tmp[3].trim()
	          return false;
	        } else {
	          obj.filterRegex = RegEx;
	          obj.filter = tmp[3].trim();
	          str = tmp[1].trim()
	        }

	      }
	      // We get the pattern reversed - o p s NOT s p o
	      var ptrparts = self.patternParts(str);
	      if (prev && prev.separator == ',')
	      {
	        obj.p = prev.p;
	        obj.s = prev.s;
	      } else if (prev && prev.separator == ';') {
	        obj.p = self.expandPrefix(ptrparts[1]);
	        obj.s = prev.s;
	      } else {
	        obj.p = self.expandPrefix(ptrparts[1]);
	        obj.s = self.expandPrefix(ptrparts[2]);
	      }
	      var o = ptrparts[0];
	      // object
	      // do we have a type?
	      if ((tmp = o.match(/^"(.*)"\^\^(.*)$/)))
	      {
	        obj.o = tmp[1];
	        obj.otype = self.expandPrefix(tmp[2]);
	      // or we are one of the xsd equivalents
	      } else if ((tmp = o.match(/^"(.*)"$/))) {
	        obj.o = tmp[1];
	        obj.otype = self.expandPrefix('xsd:string');
	      } else if ((tmp = o.match(/^([0-9]*)$/))) {
	        obj.o = tmp[1];
	        obj.otype = self.expandPrefix('xsd:integer');
	      } else if ((tmp = o.match(/^([0-9]*\.[0-9]*)$/))) {
	        obj.o = tmp[1];
	        obj.otype = self.expandPrefix('xsd:decimal');
	      } else if ((tmp = o.match(/^([0-9]*\.[0-9e]*)$/))) {
	        obj.o = tmp[1];
	        obj.otype = self.expandPrefix('xsd:double');
	      } else if (o == 'true' || o == 'false') {
	        obj.o = o;
	        obj.otype = self.expandPrefix('xsd:boolean');
	      } else
	      // ok then ... I don't know you
	        obj.o = self.expandPrefix(o);
	    }
		}
		return obj;
	}

	this.patternParts = function(str)
	{
	  var ret = []
	  var cnt = 0;
	  var bgn = 0;
	  var inquot = false;

	  for(var i = 0;i<str.length;i++)
	  {
	    if (str.charAt(i) == ' ')
	    {
	      // If cnt is 0 then this is one part
	      if (cnt == 0)
	      {
	        // if find a space time to break
          var tmp = str.substring(bgn,i + 1).trim();
          ret.unshift(tmp);
          i = i + str.substring(i).match(/^ */)[0].length - 1;
          bgn = i;
	      }
	    }
      // We care for quots
	    else if (str.charAt(i) == '"' && ((i > 1 && str.charAt(i - 1) != "\\") || i == 0 || i == bgn))
	    {
	      if (!inquot)
	      {
	        cnt++;
	        inquot = true;
	      } else {
	        cnt--;
	        inquot = false;
	      }
	    }
	  }
	  // if there is still something left we consider it a part
	  if (bgn < str.length)
      ret.unshift(str.substring(bgn).trim());
	  return ret;
	}

	this.breakUnions = function(str)
	{
	  var ret = []
	  var cnt = 0;
	  var bgn = 0;
	  var inquot = false;

	  var isUnion = false;
	  for(var i = 0;i<str.length;i++)
	  {
	    if (str.charAt(i) == '{')
	      cnt++;
	    else if (str.charAt(i) == '}')
	    {
	      cnt--;
	      // If cnt is 0 then this is one part
	      if (cnt == 0)
	      {
	        // if we have an union then break the part and start another
	        if(str.substring(i + 1).match(/^\W*union/i))
	        {
	          //So we found 1 union
	          isUnion = true;
	          // We get the string before now remove the brackets and set it as part
	          var tmp = str.substring(bgn,i + 1);
	          // Clear the brackets
	          tmp = tmp.trim().match(/^{(.*)}$/)[1];
	          ret.push(tmp);
	          // Let see where to continue from
	          i = i + str.substring(i + 1).match(/^\W*union/i)[0].length + 1;
	          bgn = i;
	        }
	      }
	    }
      // We care for quots
	    else if (str.charAt(i) == '"' && ((i > 1 && str.charAt(i - 1) != "\\") || i == 0))
	    {
	      if (!inquot)
	      {
	        cnt++;
	        inquot = true;
	      } else {
	        cnt--;
	        inquot = false;
	      }
	    }
	  }
	  // if we are not an union return false
	  if (!isUnion) return false;
	  // if we are an union and there is still something left we consider it a part
	  if (bgn < str.length)
	  {
	    var tmp = str.substring(bgn);
      // Clear the brackets
      tmp = tmp.trim().match(/^{(.*)}$/)[1];
      ret.push(tmp);
    }
	  return ret;
	}

	this.getParts = function(str)
	{
	  var ret = [];
	  var cnt = 0;
	  var bgn = 0;
	  var inquot = false;
	  for(var i = 0;i<str.length;i++)
	  {
      if (str.charAt(i) == '<')
	      cnt++;
	    else if (str.charAt(i) == '>')
	      cnt--;
	    else if (str.charAt(i) == '{' || str.charAt(i) == '(')
	      cnt++;
	    else if (str.charAt(i) == '}' || str.charAt(i) == ')')
	    {
	      cnt--;
	      // If cnt is 0 then this is one part
	      if (cnt == 0)
	      {
	        // if we have an union after it we leave it as one part and continue
	        if(str.substring(i + 1).match(/^\s*union/i))
	          ;
	        else
	        {
	          // We get the ending strings add the part to array and start looking for another
	          var tmp = str.substring(i + 1).match(/^([\s\.;,]*)/i);
	          i = i + tmp[1].length;
	          ret.push(str.substring(bgn,i + 1));
	          bgn = i + 1;
	        }
	      }
	    }
      // We care for quots
	    else if (str.charAt(i) == '"' && i > 1 && str.charAt(i - 1) != "\\")
	    {
	      if (!inquot)
	      {
	        cnt++;
	        inquot = true;
	      } else {
	        cnt--;
	        inquot = false;
	      }
	    }
      // a part can also be . or ; there can also be GRAPH or OPTIONAL there
	    else if (cnt == 0 && (str.charAt(i) == '.' || str.charAt(i) == ';' || str.charAt(i) == ',' ||
	             (str.substring(i + 1).match(/^graph/i) && str.charAt(i) != '?')||
	             (str.substring(i + 1).match(/^optional/i) && str.charAt(i) != '?')))
      {
        //if . then we must check that this is not some number
        if (!(str.charAt(i) == '.' && str.substring(i + 1).match(/^[0-9]/)))
        {
          var tmp = str.substring(i + 1).match(/^([\s\.;,]*)/i);
          i = i + tmp[1].length;
          ret.push(str.substring(bgn,i + 1));
          bgn = i + 1;
        }
      }
	  }
	  // if there is still something left we consider it a part
	  if (bgn < str.length)
      ret.push(str.substring(bgn));
	  return ret;
	}

  this.putPrefix = function(str)
  {
    var tmp = '';
    if ((tmp = str.match(/^<(.*)>$/)))
    {
      for(var i = 0;i < self.prefixes.length; i++)
      {
        if (tmp[1].substring(0,self.prefixes[i].uri.length) == self.prefixes[i].uri &&
            !tmp[1].substring(self.prefixes[i].uri.length,tmp[1].length).match(/\//))
        {
          return self.prefixes[i].label + ':' + tmp[1].substring(self.prefixes[i].uri.length);
        }
      }
    }
    return str;
  }

	this.expandPrefix = function(str)
	{
	  var tmp = '';
	  if(str.match(/^\?/))
	    return str;
	  else if (str == 'a')
	    return '<http://www.w3.org/1999/02/22-rdf-syntax-ns#type>';
	  else if((tmp = str.match(/<(.*)>/)))
	    return str;
	  else
	  {
	    var idx = str.indexOf(':');
      if (idx != -1)
      {
        var prefix = str.substring(0,idx);
        for(var i = 0;i < self.prefixes.length; i++)
        {
          if (self.prefixes[i].label == prefix)
            return '<' + self.prefixes[i].uri + str.substring(idx + 1) + '>';
        }
      }
	  }
	  return str;
	}

	this.fromURL = function(url) {
		var part = url.match(/query=([^&]*)/);
		var decoded = decodeURIComponent(part[1]);
		self.fromString(decoded);
	}

	this.fromString = function(str) {
		self.clear();
		try {
			var keywords = ["PREFIX","SELECT","INSERT INTO GRAPH","DELETE FROM GRAPH","DESCRIBE","CONSTRUCT","ASK","FROM","WHERE","ORDER","LIMIT","OFFSET"];

			var pieces = self.splitOnKeywords(str,keywords);
			for (var i=1;i<pieces.length;i++) {
				var piece = pieces[i];
				/* hack */
				if (piece == "DELETE ") {
					piece += pieces[i+1];
					pieces.splice(i+1,1);
				}
				self.splitPiece(piece);
			}
		} catch (e) {
			alert('OAT.SparqlQuery.fromString:\nInvalid query!\nThere was a problem parsing the query. Please, check the syntax.');
		}
	}

	this.splitOnKeywords = function (str,keywords) {
	  var ret = []
	  var cnt = 0;
	  var bgn = 0;
	  var part = '';
	  var inquot = false;
	  var re = new RegExp("(^" + keywords.join(")|(^") + ")","i");
	  for(var i = 0;i<str.length;i++)
	  {
		var ch = str.charAt(i);
	    if (ch == '{' && !inquot)
	    {
	      cnt++;
	      part += ch;
	    } else if (ch == '}' && !inquot) {
	      cnt--;
	      part += ch;
	    } else if ((ch == '\n' || ch == '\r') && !inquot)
	      ;
	    else if (str.substring(i).search(re) != -1)
	    {
	      // If cnt is 0 then this is one part
	      if (cnt == 0)
	      {
	        // if find a match time to break
          ret.push(part);
          part = ch;
          bgn = i;
	      }
	    }
      // We care for quotes
	    else if (ch == '"' && ((i > 1 && str.charAt(i - 1) != "\\") || i == 0))
	    {
	      if (!inquot)
	      {
	        cnt++;
	        inquot = true;
	      } else {
	        cnt--;
	        inquot = false;
	      }
	      part += ch;
	    }
	    else
	      part += ch;
	  }
	  // if there is still something left we consider it a part
	  if (bgn < str.length)
      ret.push(part);
	  return ret;
	}

	this.toString = function() {
		var fullquery = '';

		// prefixes
		for (var i = 0;i<self.prefixes.length;i++) { fullquery += 'PREFIX ' + self.prefixes[i].label + ': <' + self.prefixes[i].uri + '>\n'; }

		// select
		if (fullquery != '') fullquery += '\n';
		switch (self.mode) {
			case "CONSTRUCT":
				var construct = '';
				if (self.construct.type != 'group')
					construct = '{\n' + self.genWhere(self.construct,1) + '}';
				else
					construct = self.genWhere(self.construct,0);
				fullquery += 'CONSTRUCT ' + construct;
			break;
			case "SELECT":
			case "DESCRIBE":
				fullquery += self.mode+" ";
				if (self.distinct && self.mode != "DESCRIBE") fullquery += 'DISTINCT '; /* no DESCRIBE & DISTINCT?? */
				if (self.variables.length == 0) fullquery += '*';
				else fullquery += '?' + self.variables.join(' ?');
			break;
			case "INSERT":
			case "DELETE":
				fullquery += self.mode+" "+(self.mode == "INSERT" ? "INTO GRAPH " : "FROM GRAPH ");
				var graph = "<http://URIQAREPLACEME/dataspace>";
				if (self.from instanceof Array && self.from.length) {
					graph = self.from[0];
				} else if (self.from && !(self.from instanceof Array)) { graph = self.from; }
				fullquery += graph+" ";
				fullquery += self.genWhere(self.where,0);
			break;
		}
		if (fullquery != '') fullquery += '\n';

		if (self.mode != "INSERT" && self.mode != "DELETE") {
			// from
			if (self.from instanceof Array)  {
				for (var i = 0;i<self.from.length ;i++) {
					if (self.from[i]) { fullquery += "FROM " + self.from[i] + '\n'; }
				}
			} else {
				if (self.from) { fullquery += "FROM " + self.from + '\n'; }
			}
			for (var i = 0;i<self.from_named.length ;i++) { fullquery += 'FROM NAMED ' + self.from_named[i] + '\n'; }

			// where
			var where = '';
			if (self.where.type != 'group') {
				where = '{\n' + self.genWhere(self.where,1) + '}';
			} else { where = self.genWhere(self.where,0); }
			fullquery += 'WHERE ' + where;

			if (self.orders.length > 0) {
				fullquery += '\nORDER BY';
				for(var i = 0;i<self.orders.length ;i++) {
					var order = '?' + self.orders[i].variable;
					if (self.orders[i].desc) { order = 'DESC(' + order + ')'; }
					fullquery += ' ' + order;
				}
			}

			if (self.limit) fullquery += '\nLIMIT ' + self.limit;
			if (self.offset) fullquery += '\nOFFSET ' + self.offset;
		}
		return fullquery;
	}

	this.genWhere = function(obj,depth,next,prev) {
	  ret = '';
	  indent = '  ';

	  var tmp = '';
    // Is it union?  {  } union {  } we need another function for this - breakUnions

		switch (obj.type) {
		  case 'group':
			if (obj.parent.type != 'graph' && obj.parent.type != 'optional')
			  ret += indent.repeat(depth);
			ret += '{\n';
			  for (var i = 0; i < obj.children.length; i++)
			  {
				var nxt = false;
				var prv = false;
				if (obj.children[i+1])
				  nxt = obj.children[i+1];
				if (i > 0)
				  prv = obj.children[i-1];
				ret += self.genWhere(obj.children[i],depth + 1,nxt,prv);
			  }
			ret += indent.repeat(depth) + '}\n';
		  break;
		  case 'union':
			  for (var i = 0; i < obj.children.length; i++)
			  {
				if (i > 0)
				  ret += indent.repeat(depth) + 'UNION\n';
			  if (obj.children[i].type != 'group')
			  {
				  ret += indent.repeat(depth) + '{\n' + self.genWhere(obj.children[i],depth + 1);
				  ret += indent.repeat(depth) + '}\n';
				} else ret += self.genWhere(obj.children[i],depth);
			  }
		  break;
		// Is it graph?   graph ?g {  }
		  case 'graph':
				ret += indent.repeat(depth) + 'GRAPH ' + self.putPrefix(obj.name) + ' ';
				if (obj.content.type != 'group')
				  ret += '{\n';
				ret += self.genWhere(obj.content,depth + 1);
				if (obj.content.type != 'group')
				{
				  ret += indent.repeat(depth) + '}';
				  ret += '\n';
				}
		  break;
		// Is it optional?   optional {  }
		  case 'optional':
				ret += indent.repeat(depth) + 'OPTIONAL';
				if (obj.content.type != 'group')
				  ret += ' {';
			if (obj.content.type != 'pattern' && obj.content.type != 'group')
			  ret += '\n';
				ret += self.genWhere(obj.content,depth + 1);
			if (obj.content.type != 'pattern')
				ret += indent.repeat(depth)
				if (obj.content.type != 'group')
				{
				  ret += '}';
				  ret += '\n';
				}
		  break;
		// So we must be pattern
		  case "pattern":
			if (obj.parent.type != 'optional')
			  ret += indent.repeat(depth);
			if (prev && obj.s == prev.s)
			  ret += ' '.repeat(self.putPrefix(obj.s).length);
			else
			  ret += self.putPrefix(obj.s);
			ret += ' ';
			if (prev && obj.s == prev.s && obj.p == prev.p)
			  ret += ' '.repeat(self.putPrefix(obj.p).length);
			else
			  ret += self.putPrefix(obj.p);

			ret += ' ';
			switch (obj.otype) {
			  case '<http://www.w3.org/2001/XMLSchema#string>':
			  case 'xsd:string':
				ret += '"' + obj.o + '"';
				break;
			  case '<http://www.w3.org/2001/XMLSchema#integer>':
			  case 'xsd:integer':
			  case '<http://www.w3.org/2001/XMLSchema#decimal>':
			  case 'xsd:decimal':
			  case '<http://www.w3.org/2001/XMLSchema#double>':
			  case 'xsd:double':
			  case '<http://www.w3.org/2001/XMLSchema#boolean>':
			  case 'xsd:boolean':
				ret += obj.o;
				break;
			  case '':
				ret += self.putPrefix(obj.o);
				break;
			  default:
				ret += '"' + obj.o + '"^^' + self.putPrefix(obj.otype);
			  break;
			}
			if (obj.filter != '') {
			  ret += ' ';
			  ret += 'FILTER ';
			  if (obj.filterRegex)
				ret += 'regex';
			  ret += '(';
			  ret += obj.filter;
			  ret += ')';
			}
			if (obj.parent.type != 'optional') {
			  ret += ' ';
			  if (next && obj.s == next.s && obj.p == next.p)
				ret += ',';
			  else if (next && obj.s == next.s)
				ret += ';';
			  else
				ret += '.';
			  ret += ' \n';
			}
		  default:
		  break;
		}
		return ret;
	}
}
