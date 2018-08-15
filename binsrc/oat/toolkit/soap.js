/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2018 OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
	OAT.Soap.command(target, data, callback, optObj)
*/

OAT.Soap = {
	generate:function(data,wsdlFormat) {
		var data_ = "";
		if (wsdlFormat) {
			data_ += '<?xml version="1.0" ?>\n'+
				'<env:Envelope env:encodingType="http://schemas.xmlsoap.org/soap/encoding/" ' +
	 			'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" ' +
				'xmlns:xsd="http://www.w3.org/2001/XMLSchema" ' +
				'xmlns:env="http://schemas.xmlsoap.org/soap/envelope/" ' +
				'xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" ' +
				'xmlns:dt="urn:schemas-microsoft-com:datatypes"><env:Body>';
		} else {
			data_ += '<?xml version="1.0"?>\n'+
				'<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"'+
				' xmlns:xsd="http://www.w3.org/2001/XMLSchema"'+
				' xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'+
				'<env:Body>';
		}
		data_ += data;
		data_ += '</env:Body></env:Envelope>';
		return data_;
	},
	command:function(target, data, callback, optObj, wsdlFormat) {
		var data_ = OAT.Soap.generate(data,wsdlFormat);
		OAT.AJAX.SOAP(target, data_, callback, optObj);
	}
}
