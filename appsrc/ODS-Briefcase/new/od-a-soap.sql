--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2006 OpenLink Software
--
--  This project is free software; you can redistribute it and/or modify it
--  under the terms of the GNU General Public License as published by the
--  Free Software Foundation; only version 2 of the License, dated June 1991.
--
--  This program is distributed in the hope that it will be useful, but
--  WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
--  General Public License for more details.
--
--  You should have received a copy of the GNU General Public License along
--  with this program; if not, write to the Free Software Foundation, Inc.,
--  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
--

SOAP_LOAD_SCH (
'<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
 <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" elementFormDefault="qualified" targetNamespace="http://www.openlinksw.com/odrive" xmlns:od="http://www.openlinksw.com/odrive">
	<xs:element name="version">
 		<xs:complexType mixed="true">
 			<xs:attribute name="number" use="required" type="xs:integer"/>
 		</xs:complexType>
 	</xs:element>
 	<xs:element name="versions">
 		<xs:complexType>
 			<xs:sequence>
 				<xs:element ref="od:version"/>
 			</xs:sequence>
 		</xs:complexType>
 	</xs:element>
 	<xs:element name="row">
 		<xs:complexType>
 			<xs:sequence>
		    <xs:element name="uri" type="xs:string"/>
		    <xs:element name="path" type="xs:string"/>
		    <xs:element name="name" type="xs:string"/>
		    <xs:element name="dateModified" type="xs:dateTime"/>
		    <xs:element name="kind" type="xs:string"/>
		    <xs:element name="size" type="xs:integer"/>
		    <xs:element name="owner" type="xs:string"/>
		    <xs:element name="group" type="xs:string"/>
		    <xs:element name="permissions" type="xs:string"/>
		    <xs:element name="tags" type="xs:string"/>
		    <xs:element ref="od:versions" minOccurs="0"/>
 			</xs:sequence>
 			<xs:attribute name="number" use="required" type="xs:integer"/>
 		</xs:complexType>
 	</xs:element>
  <xs:complexType name="rows">
    <xs:sequence>
      <xs:element ref="od:row" maxOccurs="unbounded"/>
    </xs:sequence>
  </xs:complexType>
 </xs:schema>')
;

-----------------------------------------------------------------------------
--
create procedure DBA.SOAPODRIVE.Browse (
  in uName varchar,
  in uPassword varchar,
  in path varchar,
  in dateBegin dateTime,
  in dateEnd dateTime) __SOAP_OPTIONS (__SOAP_TYPE:='http://www.openlinksw.com/odrive:rows', "PartName" := 'rows')
{
  declare N, M integer;
  declare tags, tags2, data, sql, params, state, msg, meta, rows any;
  declare sVersions, aVersions any;

  ODRIVE.WA.search_set_base (data, 'path', path);

  ODRIVE.WA.search_set_criteria (data, '0', 'RES_MOD_TIME',  '>=', cast (dateBegin as varchar));
  ODRIVE.WA.search_set_criteria (data, '1', 'RES_MOD_TIME',  '<=', cast (dateEnd as varchar));

  sql := 'select TOP 100 rs.* from ODRIVE.WA.odrive_proc(rs0, rs1, rs2, rs3, rs4, rs5)(c0 varchar, c1 varchar, c2 integer, c3 varchar, c4 varchar, c5 varchar, c6 varchar, c7 varchar, c8 varchar, c9 varchar) rs where rs0 = ? and rs1 = ? and rs2 = ? and rs3 = ? and rs4 = ? and rs5 = ? order by c9, c3, c1';
  params := vector(path, 20, data, null, uName, uPassword);

  set_user_id('dba');
  state := '00000';
  exec(sql, state, msg, params, 0, meta, rows);
  if (state <> '00000')
    signal (state, msg);

  declare sStream, resource any;

  sStream := string_output();
  http ('<?xml version="1.0"?>\n', sStream);
  http ('<rows>\n', sStream);
  for (N := 0; N < length(rows); N := N + 1)
  {
    resource := DB.DBA.DAV_DIR_LIST(rows[N][0], -1, uName, uPassword);
    if (ODRIVE.WA.DAV_ERROR (resource))
      goto _end;
    tags := DB.DBA.DAV_PROP_GET(rows[N][0], ':virtpublictags', uName, uPassword);
    if (ODRIVE.WA.DAV_ERROR (tags))
      tags := '';
    tags2 := DB.DBA.DAV_PROP_GET(rows[N][0], ':virtprivatetags', uName, uPassword);
    if (ODRIVE.WA.DAV_ERROR (tags2))
      tags2 := '';
    http (sprintf('<row number="%d">\n', N+1), sStream);
      http ('<uri>', sStream);
        http_value (sprintf('%s/%s', ODRIVE.WA.host_url (), ODRIVE.WA.utf2wide(rows[N][0])), null, sStream);
      http ('</uri>\n', sStream);
      http ('<path>', sStream);
        http_value (ODRIVE.WA.utf2wide(rows[N][0]), null, sStream);
      http ('</path>\n', sStream);
      http ('<name>', sStream);
        http_value (resource[0][10], null, sStream);
      http ('</name>\n', sStream);
      http ('<dateModified>', sStream);
        http_value (rows[N][3], null, sStream);
      http ('</dateModified>', sStream);
      http ('<kind>', sStream);
        http_value (rows[N][9], null, sStream);
      http ('</kind>\n', sStream);
      http ('<size>', sStream);
        http_value (cast(rows[N][2] as varchar), null, sStream);
      http ('</size>\n', sStream);
      http ('<owner>', sStream);
        http_value (rows[N][5], null, sStream);
      http ('</owner>\n', sStream);
      http ('<group>', sStream);
        http_value (rows[N][6], null, sStream);
      http ('</group>\n', sStream);
      http ('<permissions>', sStream);
        http_value (rows[N][7], null, sStream);
      http ('</permissions>\n', sStream);
      http ('<tags>', sStream);
        http_value (ODRIVE.WA.tags_join(tags, tags2), null, sStream);
      http ('</tags>\n', sStream);
      sVersions := DB.DBA.DAV_PROP_GET(ODRIVE.WA.DAV_GET_VERSION_HISTORY_PATH(rows[N][0]), 'DAV:version-set', uName, uPassword);
      if (isstring(sVersions))
      {
        http ('<versions>\n', sStream);
        aVersions := xpath_eval ('/href', xtree_doc(sVersions), 0);
        for (M := 0; M < length(aVersions); M := M + 1)
        {
          http (sprintf('<version number="%d">', M+1), sStream);
            http_value (cast(aVersions[M] as varchar), null, sStream);
          http ('</version>\n', sStream);
        }
        http ('</versions>\n', sStream);
      }
    http ('</row>\n', sStream);
  _end:;
  }
  http ('</rows>\n', sStream);

  return xml_tree_doc(string_output_string(sStream));
}
;

grant execute on "http://www.openlinksw.com/odrive:rows" to SOAPODrive
;
grant execute on DBA.SOAPODRIVE.Browse to SOAPODrive
;
