--
--
--  $Id$
--
--  RDF Mappings
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

-- uninstall the things
drop table DB.DBA.SYS_GRDDL_MAPPING;

delete from DB.DBA.SYS_RDF_MAPPERS where RM_HOOK = 'DB.DBA.RDF_LOAD_HTML_RESPONSE';
delete from DB.DBA.SYS_RDF_MAPPERS where RM_HOOK = 'DB.DBA.RDF_LOAD_FLICKR_IMG';
delete from DB.DBA.SYS_RDF_MAPPERS where RM_HOOK = 'DB.DBA.RDF_LOAD_AMAZON_ARTICLE';

xpf_extension_remove ('http://www.openlinksw.com/virtuoso/xslt/:regexp-match');

drop procedure DB.DBA.XSLT_REGEXP_MATCH;
drop procedure DB.DBA.RDF_LOAD_AMAZON_ARTICLE;
drop procedure DB.DBA.RDF_LOAD_FLICKR_IMG;
drop procedure DB.DBA.RDF_LOAD_HTML_RESPONSE;

DB.DBA.VHOST_REMOVE (lhost=>'*ini*', vhost=>'*ini*', lpath=>'/sponger');
