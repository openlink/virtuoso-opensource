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
-- This SQL script demonstrate a database user creation and making a executable directory in web server space
CREATE USER VS_B_1
;

-- set the default qualifier for the VS_B_1
USER_SET_QUALIFIER ('VS_B_1', 'VS_B_1')
;

-- first remove the old definition if already defined.
VHOST_REMOVE (vhost=>'*ini*',lhost=>'*ini*',lpath=>'/vs_b_1')
;


VHOST_DEFINE (vhost=>'*ini*',lhost=>'*ini*',lpath=>'/vs_b_1',ppath=>TUTORIAL_VDIR_DIR() || '/tutorial/web/',vsp_user=>'VS_B_1', is_brws=>1, is_dav=>TUTORIAL_IS_DAV())
;

