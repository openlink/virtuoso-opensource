--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2007 OpenLink Software
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
use SIOC;

create procedure fill_ods_calendar_sioc (in graph_iri varchar, in site_iri varchar, in _wai_name varchar := null)
{
  return;
}
;

create procedure ods_calendar_sioc_init ()
{
  declare sioc_version any;

  sioc_version := registry_get ('__ods_sioc_version');
  if (registry_get ('__ods_sioc_init') <> sioc_version)
    return;
  if (registry_get ('__ods_calendar_sioc_init') = sioc_version)
    return;
  fill_ods_calendar_sioc (get_graph (), get_graph ());
  registry_set ('__ods_calendar_sioc_init', sioc_version);
  return;
}
;

CAL.WA.exec_no_error('ods_calendar_sioc_init ()');

use DB;
