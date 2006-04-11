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
	JSON.parse(jsonString)
	JSON.stringify(something)
*/

var JSON = {
	tt:{'\b':'\\b', '\t':'\\t', '\n':'\\n',	'\f':'\\f',	
		'\r':'\\r',	'"' :'\\"',	'\\':'\\\\' },

	parse:function(jsonString) {
		return eval('('+jsonString+')');
	},
	stringify:function(something) {
		var result = "";
		switch (typeof something) {
			case 'boolean':
				return something.toString();
			break;
			
			case 'number':
				return something.toString();
			break;
			
			case 'string':
				var tmp = "";
				for (var i=0;i<something.length;i++) {
					var r = something.charAt(i);
					for (var p in JSON.tt) {
						if (r==p) { r = JSON.tt[p]; }
					}
					tmp += r;
				}
				return '"'+tmp+'"';
			break;
			
			case 'object':
				if (something instanceof Array) {
					var members = [];
					for (var i=0;i<something.length;i++) {
						members.push(JSON.stringify(something[i]));
					}
					result = "["+members.join(",")+"]";
					return result;
				}
				if (something instanceof Object) {
					var members = [];
					for (var p in something) {
						members.push('"'+p+'":'+JSON.stringify(something[p]));
					}
					result = "{"+members.join(",")+"}";
				}
			break;
		}
		return result;
	}
}