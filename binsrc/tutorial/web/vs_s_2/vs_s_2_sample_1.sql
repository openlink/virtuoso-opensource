--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2017 OpenLink Software
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
create user VS_S_2
;

USER_SET_QUALIFIER ('VS_S_2', 'VS_S_2')
;

VHOST_REMOVE (lpath=>'/vs_s_2')
;

VHOST_DEFINE (lpath=>'/vs_s_2', ppath=>TUTORIAL_VDIR_DIR() || '/tutorial/web/vs_s_2/', vsp_user=>'VS_S_2', def_page=>'vs_s_2_sample_1.vsp', is_dav=>TUTORIAL_IS_DAV())
;

