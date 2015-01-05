--
--  drop_sioc_proc
--
--  $Id$
--
--  script to clean the old variant of the ODS RDF data support : triggers over the apps
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2015 OpenLink Software
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

use DB;

create procedure DB.DBA._drop_sioc_procedures()
{
  for (select P_NAME from DB.DBA.SYS_PROCEDURES where P_NAME like 'sioc.DBA.%') do {
        db.dba.wa_exec_no_error(sprintf('drop procedure %s', P_NAME));
  }
}
;

-- dropping procedures for sioc
DB.DBA._drop_sioc_procedures();

db.dba.wa_exec_no_error('DB.DBA._drop_sioc_procedures');

