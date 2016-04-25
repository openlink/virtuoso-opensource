--  
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2016 OpenLink Software
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

USE "ODS"
;

create procedure COMMUNITY.community_uninstall()
{
  for select WAI_INST from DB.DBA.WA_INSTANCE WHERE WAI_TYPE_NAME = 'Community' do
  {
    (WAI_INST as ODS.COMMUNITY.wa_community).wa_drop_instance();
  }
}
;

community_uninstall()
;
drop procedure COMMUNITY.community_uninstall
;


DB.DBA.vhost_remove(lpath=>'/community/public')
;
DB.DBA.vhost_remove(lpath=>'/community/templates')
;
DB.DBA.vhost_remove(lpath=>'/community')
;


DELETE FROM DB.DBA.WA_MEMBER      WHERE WAM_INST      IN (SELECT WAI_NAME FROM DB.DBA.WA_INSTANCE WHERE WAI_TYPE_NAME = 'Community')
;
DELETE FROM DB.DBA.WA_INSTANCE    WHERE WAI_TYPE_NAME = 'Community'
;
DELETE FROM DB.DBA.WA_MEMBER_TYPE WHERE WMT_APP       = 'Community'
;
drop type wa_community
;
DELETE FROM DB.DBA.WA_TYPES       WHERE WAT_NAME      = 'Community'
;

drop table ODS.COMMUNITY.SYS_COMMUNITY_INFO
;
drop table ODS.COMMUNITY.COMMUNITY_MEMBER_APP
;

drop trigger DB.DBA.WA_INSTANCE_COMMUNITY_WAINAME_UP
;

-- Procedures
create procedure COMMUNITY._drop_procedures()
{
  for (select P_NAME from DB.DBA.SYS_PROCEDURES where P_NAME like 'ODS.COMMUNITY.%') do {
    if (P_NAME not in ('ODS.COMMUNITY.exec_no_error', 'ODS.COMMUNITY._drop_procedures'))
        ODS.COMMUNITY.exec_no_error(sprintf('drop procedure %s', P_NAME));
  }
}
;

-- dropping procedures for COMMUNITY
COMMUNITY._drop_procedures();

COMMUNITY.exec_no_error('DROP procedure ODS.COMMUNITY._drop_procedures');
COMMUNITY.exec_no_error('DROP procedure ODS.COMMUNITY.exec_no_error');
