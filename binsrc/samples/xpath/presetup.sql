--  
--  $Id$
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
--  
create procedure "XP"."XP"."__XP_PRE_INIT"()
{
  if (not exists (select * from "DB"."DBA"."HTTP_PATH" where "HP_LPATH" = '/xpdemo/'))
    DB.DBA.VHOST_DEFINE (lpath=>'/xpdemo/', ppath=>'/xpdemo/', vsp_user=>'XP', def_page=>'demo.vsp');
}
;

create user "XP"
;

DB.DBA.USER_SET_QUALIFIER ('XP', 'XP')
;

grant all privileges to XP
;


"XP"."XP"."__XP_PRE_INIT"()
;
