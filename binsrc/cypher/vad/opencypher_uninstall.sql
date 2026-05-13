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
--  openCypher VAD package - uninstaller.
--
--  Drops every PL routine the installer creates.  We discover them
--  from SYS_PROCEDURES rather than hard-coding a list so the script
--  stays correct as the translator grows new helpers.
--

create procedure DB.DBA.OPENCYPHER_VAD_DROP_ROUTINES ()
{
  declare nm varchar;
  for select P_NAME from DB.DBA.SYS_PROCEDURES
        where (P_NAME like 'DB.DBA.CYP\\_%' escape '\\'
               or P_NAME like 'DB.DBA.CYPHER\\_%' escape '\\'
               or P_NAME like 'DB.DBA.CYPHER%'
               or P_NAME like 'DB.DBA.OPENCYPHER\\_%' escape '\\'
               or P_NAME like 'DB.DBA.OPENCYPHER%')
          and P_NAME <> 'DB.DBA.OPENCYPHER_VAD_DROP_ROUTINES'
        do
    {
      nm := P_NAME;
      declare exit handler for sqlstate '*' { goto next_drop; };
      exec (concat ('drop procedure ', nm));
    next_drop: ;
    }
}
;

DB.DBA.OPENCYPHER_VAD_DROP_ROUTINES ();
drop procedure DB.DBA.OPENCYPHER_VAD_DROP_ROUTINES;
