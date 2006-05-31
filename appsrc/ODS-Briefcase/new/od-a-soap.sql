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
--

-----------------------------------------------------------------------------
--
create procedure DBA.SOAPODRIVE.Browse (
  in uName varchar,
  in uPassword varchar,
  in path varchar,
  in dateBegin dateTime,
  in dateEnd dateTime) returns xmltype
{
  declare N, M integer;
  declare tags, tags2, data, sql, params, state, msg, meta, result any;
  declare sVersions, aVersions any;

  ODRIVE.WA.dav_dc_set_base(data, 'path', path);

  ODRIVE.WA.dav_dc_set_advanced(data, 'modifyDate11',  '>=');
  ODRIVE.WA.dav_dc_set_advanced(data, 'modifyDate12',  cast(dateBegin as varchar));
  ODRIVE.WA.dav_dc_set_advanced(data, 'modifyDate21',  '<=');
  ODRIVE.WA.dav_dc_set_advanced(data, 'modifyDate22',  cast(dateEnd as varchar));

  sql := 'select TOP 100 rs.* from ODRIVE.WA.odrive_proc(rs0, rs1, rs2, rs3, rs4, rs5)(c0 varchar, c1 varchar, c2 integer, c3 varchar, c4 varchar, c5 varchar, c6 varchar, c7 varchar, c8 varchar, c9 varchar) rs where rs0 = ? and rs1 = ? and rs2 = ? and rs3 = ? and rs4 = ? and rs5 = ?';
  sql := concat(sql, ' order by c9, c3, c1');
  params := vector(path, 0, 20, data, uName, uPassword);

  set_user_id('dba');
  state := '00000';
  exec(sql, state, msg, params, 0, meta, result);
  if (state <> '00000')
    signal (state, msg);

  declare sStream any;

  sStream := string_output();
  http ('<?xml version="1.0"?>\n', sStream);
  http ('<rows>\n', sStream);
  for (N := 0; N < length(result); N := N + 1) {
    tags := DB.DBA.DAV_PROP_GET(result[N][0], ':virtpublictags', uName, uPassword);
    if (not isstring(tags))
      tags := '';
    tags := DB.DBA.DAV_PROP_GET(result[N][0], ':virtprivatetags', uName, uPassword);
    if (not isstring(tags2))
      tags2 := '';
    http (sprintf('<row number="%d">\n', N+1), sStream);
      http ('<name>', sStream);
        http_value (ODRIVE.WA.utf2wide(result[N][0]), null, sStream);
      http ('</name>\n', sStream);
      http ('<dateModified>', sStream);
        http_value (result[N][3], null, sStream);
      http ('</dateModified>', sStream);
      http ('<kind>', sStream);
        http_value (result[N][9], null, sStream);
      http ('</kind>\n', sStream);
      http ('<size>', sStream);
        http_value (cast(result[N][2] as varchar), null, sStream);
      http ('</size>\n', sStream);
      http ('<owner>', sStream);
        http_value (result[N][5], null, sStream);
      http ('</owner>\n', sStream);
      http ('<group>', sStream);
        http_value (result[N][6], null, sStream);
      http ('</group>\n', sStream);
      http ('<permissions>', sStream);
        http_value (result[N][7], null, sStream);
      http ('</permissions>\n', sStream);
      http ('<tags>', sStream);
        http_value (ODRIVE.WA.tags_join(tags, tags2), null, sStream);
      http ('</tags>\n', sStream);
      sVersions := DB.DBA.DAV_PROP_GET(ODRIVE.WA.DAV_GET_VERSION_HISTORY_PATH(result[N][0]), 'DAV:version-set', uName, uPassword);
      if (isstring(sVersions)) {
        http ('<versions>\n', sStream);
        aVersions := xpath_eval ('/href', xtree_doc(sVersions), 0);
        for (M := 0; M < length(aVersions); M := M + 1) {
          http (sprintf('<version number="%d">', M+1), sStream);
            http_value (cast(aVersions[M] as varchar), null, sStream);
          http ('</version>\n', sStream);
        }
        http ('</versions>\n', sStream);
      }
    http ('</row>\n', sStream);
  }
  http ('</rows>\n', sStream);

  return new xmltype(string_output_string(sStream));
}
;

grant execute on DBA.SOAPODRIVE.Browse to SOAPODrive
;
