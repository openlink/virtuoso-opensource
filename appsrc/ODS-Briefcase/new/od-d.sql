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

ODRIVE.WA.odrive_exec_no_error('
  drop table ODRIVE.WA.GROUPS
');

ODRIVE.WA.odrive_exec_no_error('
  drop table ODRIVE.WA.SETTINGS
');

VHOST_REMOVE (lpath => '/odrive');
VHOST_REMOVE (lpath => '/odrive/SOAP');

ODRIVE.WA.odrive_exec_no_error('delete from WA_TYPES where WAT_NAME = \'oDrive\'');
ODRIVE.WA.odrive_exec_no_error('DROP type wa_oDrive');

create procedure ODRIVE.WA.odrive_drop_procedures()
{
  for (select P_NAME from DB.DBA.SYS_PROCEDURES where P_NAME like 'ODRIVE.WA.%') do {
    if (P_NAME not in ('ODRIVE.WA.odrive_exec_no_error', 'ODRIVE.WA.odrive_drop_procedures'))
      ODRIVE.WA.odrive_exec_no_error(sprintf('drop procedure %s', P_NAME));
  }
}
;

-- dropping procedures for ODRIVE
ODRIVE.WA.odrive_drop_procedures()
;

ODRIVE.WA.odrive_exec_no_error('DROP procedure ODRIVE.WA.odrive_vhost');
ODRIVE.WA.odrive_exec_no_error('DROP procedure ODRIVE.WA.odrive_drop_procedures');
ODRIVE.WA.odrive_exec_no_error('DROP procedure ODRIVE.WA.odrive_exec_no_error');
