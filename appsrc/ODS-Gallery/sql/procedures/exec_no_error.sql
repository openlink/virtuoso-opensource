--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2012 OpenLink Software
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

-------------------------------------------------------------------------------
create procedure PHOTO.WA._exec_no_error(in expr varchar, in execType varchar := '', in execTable varchar := '', in execColumn varchar := '')
{
  declare
    state,
    message,
    meta,
    result any;

  log_enable(1);
  if (execType = 'C') {
    if (coalesce((select 1 from DB.DBA.SYS_COLS where (0=casemode_strcmp("COLUMN", execColumn)) and (0=casemode_strcmp ("TABLE", execTable))), 0))
      return;
  }
  if (execType = 'D') {
    if (not coalesce((select 1 from DB.DBA.SYS_COLS where (0=casemode_strcmp("COLUMN", execColumn)) and (0=casemode_strcmp ("TABLE", execTable))), 0))
      return;
  }
  if (execType = 'S') {
    declare S varchar;
    declare maxID integer;

    S := sprintf('select max(%s) from %s', execColumn, execTable);
    maxID := 1000;
    state := '00000';

    exec(S, state, message, vector(), 0, meta, result);
    if (state = '00000')
      if (not isnull(result[0][0]))
        maxID := result[0][0] + 1;

    expr := sprintf(expr, maxID);
  }
  exec(expr, state, message, vector(), 0, meta, result);
}
;
