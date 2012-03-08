--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2012 OpenLink Software
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

-- init the WA app
registry_set('_wa_path_', '/ods/');
load  sn.sql;
load  hosted_services.sql;
load  registration_xml.sql;
load  tags.sql;
load dashboard.sql;
load wa_search_procs.sql;
load wa_maps.sql;
load provinces.sql;
load wa_template.sql;

vhost_remove (lpath=>'/wa');
vhost_remove (lpath=>'/ods');
vhost_remove (lpath=>'/wa/images/icons');
vhost_remove (lpath=>'/ods/images/icons');
vhost_define (lpath=>'/ods', ppath=>'/wa/', is_dav=>0, vsp_user=>'dba', def_page=>'sfront.vspx', opts=>vector('xml_templates', 'yes',  '404_page','not_found.vspx'));
vhost_define (lpath=>'/ods/images/icons', ppath=>'/wa/icons', is_dav=>0);
