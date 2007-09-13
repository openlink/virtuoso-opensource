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

ODRIVE.WA.exec_no_error('
  drop table ODRIVE.WA.GROUPS
');

ODRIVE.WA.exec_no_error('
  drop table ODRIVE.WA.SETTINGS
');

VHOST_REMOVE (lpath => '/odrive');
VHOST_REMOVE (lpath => '/odrive/SOAP');
VHOST_REMOVE (lpath => '/dataspace/services/briefcase');

ODRIVE.WA.exec_no_error('delete from WA_TYPES where WAT_NAME = \'oDrive\'');
ODRIVE.WA.exec_no_error('DROP type wa_oDrive');

create procedure ODRIVE.WA.drop_procedures()
{
  for (select P_NAME from DB.DBA.SYS_PROCEDURES where P_NAME like 'ODRIVE.WA.%') do {
    if (P_NAME not in ('ODRIVE.WA.exec_no_error', 'ODRIVE.WA.drop_procedures'))
      ODRIVE.WA.exec_no_error(sprintf('drop procedure %s', P_NAME));
  }
}
;

-- dropping procedures for ODRIVE
ODRIVE.WA.drop_procedures()
;

ODRIVE.WA.exec_no_error('DROP procedure ODRIVE.WA.odrive_vhost');
ODRIVE.WA.exec_no_error('DROP procedure ODRIVE.WA.drop_procedures');

-- dropping SIOC procs and triggers
drop trigger WS.WS.SYS_DAV_RES_BRIEFCASE_SIOC_I;
drop trigger WS.WS.SYS_DAV_RES_BRIEFCASE_SIOC_U;
drop trigger WS.WS.SYS_DAV_RES_BRIEFCASE_SIOC_D;

ODRIVE.WA.exec_no_error('DROP procedure SIOC.DBA.briefcase_links_to');
ODRIVE.WA.exec_no_error('DROP procedure SIOC.DBA.fill_ods_briefcase_sioc');
ODRIVE.WA.exec_no_error('DROP procedure SIOC.DBA.briefcase_sioc_insert');
ODRIVE.WA.exec_no_error('DROP procedure SIOC.DBA.briefcase_sioc_delete');
ODRIVE.WA.exec_no_error('DROP procedure SIOC.DBA.ods_briefcase_sioc_init');

-- SOAP procs
ODRIVE.WA.exec_no_error('DROP procedure DBA.SOAPODRIVE.Browse');

-- dropping ODS procs
ODRIVE.WA.exec_no_error('DROP procedure DB.DBA.wa_collect_odrive_tags');

-- final proc
ODRIVE.WA.exec_no_error('DROP procedure ODRIVE.WA.exec_no_error');
