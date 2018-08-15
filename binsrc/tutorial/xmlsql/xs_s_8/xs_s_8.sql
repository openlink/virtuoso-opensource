--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2018 OpenLink Software
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
drop table fth
;

create table fth (id integer not null primary key, dt varchar, c1 varchar)
;

create procedure fth_dt_index_hook (inout vtb any, inout d_id integer)
{
  declare data any;
  data := coalesce ((select concat (coalesce (dt, ''), ' ', c1) from fth where id = d_id), null);
  if (data is null)
    return 0;
  vt_batch_feed (vtb, data, 0);
  return 1;
}
;

create procedure fth_dt_unindex_hook (inout vtb any, inout d_id integer)
{
  declare data any;
  data := coalesce ((select concat (coalesce (dt, ''), ' ', c1) from fth where id = d_id), null);
  if (data is null)
    return 0;
  vt_batch_feed (vtb, data, 1);
  return 1;
}
;
