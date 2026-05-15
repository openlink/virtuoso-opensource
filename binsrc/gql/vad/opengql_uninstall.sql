--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2026 OpenLink Software
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
--
--  openGQL: GQL for Virtuoso - Uninstaller
--
--  Drops all openGQL procedures discovered at uninstall time.
--

create procedure DB.DBA.OPENGQL_VAD_DROP_ROUTINES ()
{
  declare _pname varchar;
  declare _stmt varchar;

  declare exit handler for sqlstate '*'
    {
      goto next_routine;
    };

  for (select P_NAME as _pname from DB.DBA.SYS_PROCEDURES
       where P_NAME like 'DB.DBA.GQL\_%' escape '\'
          or P_NAME = 'DB.DBA.GQL'
          or P_NAME like 'DB.DBA.OPENGQL%'
       order by P_NAME) do
    {
      _stmt := sprintf ('DROP PROCEDURE %s', _pname);
      exec (_stmt);
    next_routine:;
    }
  exec ('DROP PROCEDURE DB.DBA.OPENGQL_VAD_DROP_ROUTINES');
}
;

DB.DBA.OPENGQL_VAD_DROP_ROUTINES ();
