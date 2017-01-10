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

vhost_remove (lpath=>'/yacutia');
vhost_remove (lpath=>'/vspx');
vhost_remove (lhost=>'*sslini*', vhost=>'*sslini*', lpath=>'/yacutia');
vhost_define (lpath=>'/yacutia',ppath=>'/yacutia/',vsp_user=>'dba',is_brws=>1, def_page=>'main_tabs.vspx');
vhost_define (lpath=>'/vspx',ppath=>'/vspx/',vsp_user=>'dba',is_brws=>1, def_page=>'index.vsp');
vhost_define (lhost=>'*sslini*', vhost=>'*sslini*', lpath=>'/yacutia',ppath=>'/yacutia/',vsp_user=>'dba',is_brws=>1, def_page=>'main_tabs.vspx');

registry_set('__no_vspx_temp', '0');
vhost_remove (lpath=>'/conductor');
vhost_define (lpath=>'/conductor',ppath=>'/yacutia/',vsp_user=>'dba',is_brws=>1, def_page=>'main_tabs.vspx');
