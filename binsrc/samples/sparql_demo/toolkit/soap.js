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
	OAT.Soap.command(target,data_func,return_func,customHeaders)
*/

OAT.Soap = {
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
	command:function(target, data_func, return_func, customHeaders) {
		var ref = function() {
			return OAT.Soap.generate(data_func);
		}
		var h = false;
		if (customHeaders) { h = customHeaders; }
		OAT.Ajax.command(OAT.Ajax.SOAP, target, ref, return_func, OAT.Ajax.TYPE_TEXT, customHeaders);
	}
}
OAT.Loader.pendingCount--;
