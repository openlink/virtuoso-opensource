--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2019 OpenLink Software
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

-- Cluster explain check.  Get the query and look for expected regexp in compilation


create procedure explain_check (in q varchar, in r varchar)
{
  declare st, msg, res, md, inx, str, m any;
  if (sys_stat ('cl_run_local_only'))
    return;
 str := '';
  st := '00000';
  exec ('explain (?)', st, msg, vector (q), 0, md, res);
  if (st <> '00000') signal (st, msg);
  for (inx := 0; inx < length (res); inx := inx + 1)
    str := str || res[inx][0];
  m := regexp_match (r, str);
  if (m is null)
    signal ('xxxxx', sprintf ('Expected compilation to match %s for %s', r, q));
  return str;
}
