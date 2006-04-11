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
	Soap.manage(id,event,target,data_func,return_func)
	Soap.command(target,data_func,return_func)
*/

var Soap = {
	generate:function(data_func) {
		var data = "";
		data += '<?xml version="1.0"?>\n'+
				'<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"'+
				' xmlns:xsd="http://www.w3.org/2001/XMLSchema"'+
				' xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'+
				'<env:Body>';
		data += data_func();
		data += '</env:Body></env:Envelope>';
		return data;
	},
	manage:function(elm, event, target, data_func, return_func) {
		var ref = function() {
			return Soap.generate(data_func);
		}
		Ajax.manage(elm, event, Ajax.SOAP, target, ref, return_func);
	},
	command:function(target, data_func, return_func) {
		var ref = function() {
			return Soap.generate(data_func);
		}
		Ajax.command(Ajax.SOAP, target, ref, return_func);
	}
}
