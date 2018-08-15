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

--drop table ODS.COMMUNITY.SYS_COMMUNITY_INFO;
--drop table ODS.COMMUNITY.COMMUNITY_MEMBER_APP

ODS.COMMUNITY.exec_no_error('
  create table ODS.COMMUNITY.SYS_COMMUNITY_INFO (
   CI_COMMUNITY_ID     VARCHAR references wa_instance,
   CI_OWNER            INT,
   CI_HOME             VARCHAR,
   CI_TITLE            VARCHAR,
   CI_TEMPLATE         VARCHAR,
   CI_CSS              VARCHAR,
   primary key (CI_COMMUNITY_ID)) 
')
;

ODS.COMMUNITY.exec_no_error('ALTER TABLE ODS.COMMUNITY.SYS_COMMUNITY_INFO DROP FOREIGN KEY (CI_COMMUNITY_ID) REFERENCES wa_instance')
;
ODS.COMMUNITY.exec_no_error('ALTER TABLE ODS.COMMUNITY.SYS_COMMUNITY_INFO ADD FOREIGN KEY (CI_COMMUNITY_ID) REFERENCES wa_instance ON UPDATE CASCADE ON DELETE CASCADE')
;


ODS.COMMUNITY.exec_no_error('
    create table ODS.COMMUNITY.COMMUNITY_MEMBER_APP (
     CM_COMMUNITY_ID  VARCHAR references wa_instance,
     CM_MEMBER_APP    VARCHAR references wa_instance,
     CM_MEMBER_DATA   ANY,
     primary key (CM_COMMUNITY_ID, CM_MEMBER_APP)
    )
    ') 
;

ODS.COMMUNITY.exec_no_error('ALTER TABLE ODS.COMMUNITY.COMMUNITY_MEMBER_APP DROP FOREIGN KEY (CM_COMMUNITY_ID) REFERENCES wa_instance')
;
ODS.COMMUNITY.exec_no_error('ALTER TABLE ODS.COMMUNITY.COMMUNITY_MEMBER_APP ADD FOREIGN KEY (CM_COMMUNITY_ID) REFERENCES wa_instance ON UPDATE CASCADE ON DELETE CASCADE')
;

ODS.COMMUNITY.exec_no_error('ALTER TABLE ODS.COMMUNITY.COMMUNITY_MEMBER_APP DROP FOREIGN KEY (CM_MEMBER_APP) REFERENCES wa_instance')
;
ODS.COMMUNITY.exec_no_error('ALTER TABLE ODS.COMMUNITY.COMMUNITY_MEMBER_APP ADD FOREIGN KEY (CM_MEMBER_APP) REFERENCES wa_instance ON UPDATE CASCADE ON DELETE CASCADE')
;
