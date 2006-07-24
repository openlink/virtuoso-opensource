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
	OAT.Soap.command(target,data_func,return_func,return_type,customHeaders)
*/

OAT.Soap = {
	generate:function(data_func,wsdlFormat) {
		var data = "";
		if (wsdlFormat) {
			data += '<?xml version="1.0" ?>\n'+
				'<env:Envelope env:encodingType="http://schemas.xmlsoap.org/soap/encoding/" ' + 
	 			'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" ' +
				'xmlns:xsd="http://www.w3.org/2001/XMLSchema" ' +
				'xmlns:env="http://schemas.xmlsoap.org/soap/envelope/" ' +
				'xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" ' +
				'xmlns:dt="urn:schemas-microsoft-com:datatypes"><env:Body>';
		} else {
		data += '<?xml version="1.0"?>\n'+
				'<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"'+
				' xmlns:xsd="http://www.w3.org/2001/XMLSchema"'+
				' xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'+
				'<env:Body>';
		}
		data += data_func();
		data += '</env:Body></env:Envelope>';
		return data;
	},
	command:function(target, data_func, return_func, return_type, customHeaders, wsdlFormat) {
		var ref = function() {
			var wsdl = false;
			if (wsdlFormat) { wsdl = true; }
			return OAT.Soap.generate(data_func,wsdl);
		}
		var h = false;
		var rt = OAT.Ajax.TYPE_TEXT;
		if (customHeaders) { h = customHeaders; }
		if (return_type) { rt = return_type; }
		OAT.Ajax.command(OAT.Ajax.SOAP, target, ref, return_func, rt, customHeaders);
	}
}
OAT.Loader.pendingCount--;
