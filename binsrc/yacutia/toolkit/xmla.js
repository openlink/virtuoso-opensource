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
	endpoint
	dsn
	user
	password
	query
	-
	execute(callback)  <-- needs endpoint && dsn && user && password && query
	discover(callback) <-- needs endpoint
	dbschema(callback) <-- needs endpoint && dsn
	tables(catalog,callback)   <-- needs endpoint && dsn
	columns(catalog,schema,table,callback)  <-- needs endpoint && dsn
	execute_array(data)
	discover_array(data)
	dbschema_array(data)
	tables_array(data)
	columns_array(data)
	
*/

var Xmla = {
	endpoint:".",
	dsn:"",
	user:"",
	password:"",
	query:"",
	
	execute:function(callback) {
		var ref = function() {
			var data = '<n0:Execute  env:encodingStyle="http://www.w3.org/2003/05/soap-encoding"'+
				' xmlns:n0="urn:schemas-microsoft-com:xml-analysis" >'+
				'<Command><Statement xmlns:n1="http://www.w3.org/2001/XMLSchema-instance"'+
				' n1:type="http://www.w3.org/2001/XMLSchema:string" xmlns:n2="urn:schemas-microsoft-com:datatypes"'+
				' n2:dt="string" >'+Xmla.query+'</Statement></Command>'+
				'<Properties><PropertyList>'+
				'<DataSourceInfo xmlns:n1="http://www.w3.org/2001/XMLSchema-instance"'+
				' n1:type="http://www.w3.org/2001/XMLSchema:string" xmlns:n2="urn:schemas-microsoft-com:datatypes"'+
				' n2:dt="string" >'+Xmla.dsn+'</DataSourceInfo>'+
				'<UserName xmlns:n1="http://www.w3.org/2001/XMLSchema-instance"'+
				' n1:type="http://www.w3.org/2001/XMLSchema:string" xmlns:n2="urn:schemas-microsoft-com:datatypes"'+
				' n2:dt="string" >'+Xmla.user+'</UserName>'+
				'<Password xmlns:n1="http://www.w3.org/2001/XMLSchema-instance"'+
				' n1:type="http://www.w3.org/2001/XMLSchema:string" xmlns:n2="urn:schemas-microsoft-com:datatypes"'+
				' n2:dt="string" >'+Xmla.password+'</Password></PropertyList></Properties></n0:Execute>';
			return data;
		}
		Soap.command(Xmla.endpoint, ref, callback);
	},
	
	discover:function(callback) {
		var ref = function() {
			var data = '<n0:Discover  env:encodingStyle="http://www.w3.org/2003/05/soap-encoding"'+
				' xmlns:n0="urn:schemas-microsoft-com:xml-analysis" >'+
				'<RequestType xsi:type="xsd:string">DISCOVER_DATASOURCES</RequestType>'+
				'<Restrictions xsi:nil="1" ></Restrictions>'+
				'<Properties></Properties></n0:Discover>';
			return data;
		}
		Soap.command(Xmla.endpoint, ref, callback);
	},
	
	dbschema:function(callback) {
		var ref = function() {
			var data = '<n0:Discover  env:encodingStyle="http://www.w3.org/2003/05/soap-encoding"'+
				' xmlns:n0="urn:schemas-microsoft-com:xml-analysis" >'+
				'<RequestType xsi:type="xsd:string">DBSCHEMA_CATALOGS</RequestType>'+
				'<Restrictions xsi:nil="1" ></Restrictions>'+
				'<Properties><PropertyList>'+
				'<UserName xmlns:n1="http:// www.w3.org/2001/XMLSchema-instance"'+
				' n1:type="http://www.w3.org/2001/ XMLSchema:string" xmlns:n2="urn:schemas-microsoft-com:datatypes"'+
				' n2:dt="string" >'+Xmla.user+'</UserName>'+
				'<Password xmlns:n1="http:// www.w3.org/2001/XMLSchema-instance"'+
				' n1:type="http://www.w3.org/2001/ XMLSchema:string" xmlns:n2="urn:schemas-microsoft-com:datatypes"'+
				' n2:dt="string" >'+Xmla.password+'</Password>'+
				'<DataSourceInfo xsi:type="xsd:string">'+Xmla.dsn+'</DataSourceInfo>'+
				'</PropertyList></Properties></n0:Discover>';
			return data;
		}
		Soap.command(Xmla.endpoint, ref, callback);
	},
	
	tables:function(catalog,callback) {
		var ref = function() {
			var data = '<n0:Discover  env:encodingStyle="http://www.w3.org/2003/05/soap-encoding"'+
				' xmlns:n0="urn:schemas-microsoft-com:xml-analysis" >'+
				'<RequestType xsi:type="xsd:string">DBSCHEMA_TABLES</RequestType>'+
				'<Restrictions xsi:nil="1" ><RestrictionList>'+
				'<TABLE_CATALOG xmlns:n1="http://www.w3.org/2001/XMLSchema-instance"'+
				' n1:type="http://www.w3.org/2001/XMLSchema:string" xmlns:n2="urn:schemas-microsoft-com:datatypes"'+
				' n2:dt="string" >'+catalog+'</TABLE_CATALOG></RestrictionList></Restrictions>'+
				'<Properties><PropertyList>'+
				'<UserName xmlns:n1="http:// www.w3.org/2001/XMLSchema-instance"'+
				' n1:type="http://www.w3.org/2001/ XMLSchema:string" xmlns:n2="urn:schemas-microsoft-com:datatypes"'+
				' n2:dt="string" >'+Xmla.user+'</UserName>'+
				'<Password xmlns:n1="http:// www.w3.org/2001/XMLSchema-instance"'+
				' n1:type="http://www.w3.org/2001/ XMLSchema:string" xmlns:n2="urn:schemas-microsoft-com:datatypes"'+
				' n2:dt="string" >'+Xmla.password+'</Password>'+
 				'<DataSourceInfo xsi:type="xsd:string">'+Xmla.dsn+'</DataSourceInfo>'+
				'</PropertyList></Properties></n0:Discover>';
			return data;
		}
		var cback = function(data) {
			callback(catalog,data);
		}
		Soap.command(Xmla.endpoint, ref, cback);
	},

	columns:function(catalog,schema,table,callback) {
		var ref = function() {
			var data = '<n0:Discover  env:encodingStyle="http://www.w3.org/2003/05/soap-encoding"'+
				' xmlns:n0="urn:schemas-microsoft-com:xml-analysis" >'+
				'<RequestType xsi:type="xsd:string">DBSCHEMA_COLUMNS</RequestType>'+
				'<Restrictions xsi:nil="1" ><RestrictionList>'+
				'<TABLE_CATALOG xmlns:n1="http://www.w3.org/2001/XMLSchema-instance"'+
				' n1:type="http://www.w3.org/2001/XMLSchema:string" xmlns:n2="urn:schemas-microsoft-com:datatypes"'+
				' n2:dt="string" >'+catalog+'</TABLE_CATALOG>'+
				'<TABLE_SCHEMA xmlns:n1="http://www.w3.org/2001/XMLSchema-instance"'+
				' n1:type="http://www.w3.org/2001/XMLSchema:string" xmlns:n2="urn:schemas-microsoft-com:datatypes"'+
				' n2:dt="string" >'+schema+'</TABLE_SCHEMA>'+
				'<TABLE_NAME xmlns:n1="http://www.w3.org/2001/XMLSchema-instance"'+
				' n1:type="http://www.w3.org/2001/XMLSchema:string" xmlns:n2="urn:schemas-microsoft-com:datatypes"'+
				' n2:dt="string" >'+table+'</TABLE_NAME></RestrictionList></Restrictions>'+
				'<Properties><PropertyList>'+
				'<UserName xmlns:n1="http:// www.w3.org/2001/XMLSchema-instance"'+
				' n1:type="http://www.w3.org/2001/ XMLSchema:string" xmlns:n2="urn:schemas-microsoft-com:datatypes"'+
				' n2:dt="string" >'+Xmla.user+'</UserName>'+
				'<Password xmlns:n1="http:// www.w3.org/2001/XMLSchema-instance"'+
				' n1:type="http://www.w3.org/2001/ XMLSchema:string" xmlns:n2="urn:schemas-microsoft-com:datatypes"'+
				' n2:dt="string" >'+Xmla.password+'</Password>' +				
				'<DataSourceInfo xsi:type="xsd:string">'+Xmla.dsn+'</DataSourceInfo>'+
				'</PropertyList></Properties></n0:Discover>';
			return data;
		}
		Soap.command(Xmla.endpoint, ref, callback);
	},
	
	execute_array:function(data) {
		/* 
			query result, return: [array_of_headers,array_of_rows]
			array_of_headers indexed by numbers
			array_of_rows indexed by numbers, then by numbers
		*/
		data = data.replace(/[\n\r]/g,'');
		var result_1 = [];
		var result_2 = [];
		var tmp = [];
		var header = data.match(/<n0:choice[^>]*>.*?<\/n0:choice>/)[0];
		var heads = header.match(/name="[^"]*"/g);
		for (var i=0;i<heads.length;i++) {
			result_1[result_1.length] = heads[i].match(/name="([^"]*)"/)[1];
		}
		var rows = data.match(/<row[^>]*>.*?<\/row>/g);
		if (!rows) return [result_1,result_2];
		for (var i=0;i<rows.length;i++) {
			tmp = [];
			for (var j=0;j<result_1.length;j++) {
				var regexp = new RegExp('<'+result_1[j]+'[^>]*>(.*?)<\/'+result_1[j]+'>');
				var x = rows[i].match(regexp);
				tmp[tmp.length] = (x ? x[1] : "");
			}
			result_2[result_2.length] = tmp;
		}
		return [result_1,result_2];
	},
	
	discover_array:function(data) {
		/* list of datasources */
		var tmp;
		var names=[];
		var dsn = data.match(/<DataSourceInfo>.*?<\/DataSourceInfo>/g);
		if (!dsn) return names;
		for (var i=0;i<dsn.length;i++) {
			tmp = dsn[i].match(/<DataSourceInfo>(.*?)<\/DataSourceInfo>/)[1];
			names[names.length] = tmp;
		}
		return names;
	},
	
	dbschema_array:function(data) {
		/* list of catalogs */
		var tmp;
		var names=[];
		var catalogs = data.match(/<CATALOG_NAME[^>]*>.*?<\/CATALOG_NAME>/g);
		if (!catalogs) return names;
		for (var i=0;i<catalogs.length;i++) {
			tmp = catalogs[i].match(/<CATALOG_NAME[^>]*>(.*?)<\/CATALOG_NAME>/)[1];
			names[names.length] = tmp;
		}
		return names;
	},
	
	tables_array:function(data) {
		/* list of tables */
		var tmp;
		var names=[];
		var schema_names=[];
		var tables = data.match(/<TABLE_NAME[^>]*>.*?<\/TABLE_NAME>/g);
		var schemas = data.match(/<TABLE_SCHEMA[^>]*>.*?<\/TABLE_SCHEMA>/g);
		if (!tables) return [names,schema_names];
		for (var i=0;i<tables.length;i++) {
			tmp = tables[i].match(/<TABLE_NAME[^>]*>(.*?)<\/TABLE_NAME>/)[1];
			names[names.length] = tmp;
			tmp = schemas[i].match(/<TABLE_SCHEMA[^>]*>(.*?)<\/TABLE_SCHEMA>/)[1];
			schema_names[schema_names.length] = tmp;
		}
		return [names,schema_names];
	},

/* !!! table_schema is only a work-around of a Virtuoso's bug !!! */
	columns_array:function(data, table_schema) {
		/* list of columns */
		var tmpobj={};
		var names=[];
		var name,def,type,nn,spec,tmp;
		var cols = data.match(/<row[^>]*>.*?<\/row>/g);
		if (!cols) return names;
		for (var i=0;i<cols.length;i++) {
			tmpobj = {};
			name = cols[i].match(/<COLUMN_NAME[^>]*>(.*?)<\/COLUMN_NAME>/)[1];
			tmp = cols[i].match(/<COLUMN_DEFAULT[^>]*>(.*?)<\/COLUMN_DEFAULT>/);
			def = (tmp ? tmp[1] : "");
			type = cols[i].match(/<DATA_TYPE>(.*?)<\/DATA_TYPE>/)[1];
			nn = cols[i].match(/<IS_NULLABLE>(.*?)<\/IS_NULLABLE>/)[1];
			tmp = cols[i].match(/<CHARACTER_MAXIMUM_LENGTH[^>]*>(.*?)<\/CHARACTER_MAXIMUM_LENGTH>/);
			spec = (tmp ? tmp[1] : "");
			tmpobj["name"] = name;
			tmpobj["type"] = type;
			tmpobj["def"] = def;
			tmpobj["spec"] = spec;
			tmpobj["nn"] = nn;
			/* !!! */
			var schema = cols[i].match(/<TABLE_SCHEMA[^>]*>(.*?)<\/TABLE_SCHEMA>/)[1];
			if (schema == table_schema) { names[names.length] = tmpobj; }
			/* !!! */
		}
		return names;
	}
	
}
