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

VHOST_REMOVE (lpath=>'/tutorial/web/vx_s_13');
VHOST_REMOVE (lpath=>'/countries/Gdata');

VHOST_DEFINE (lpath=>'/tutorial/web/vx_s_13', ppath=>TUTORIAL_VDIR_DIR()||'/tutorial/web/vx_s_13/', vsp_user=>'dba', opts=>vector('xml_templates', 'yes'), is_dav=>case when TUTORIAL_VDIR_DIR () like '/DAV/%' then 1 else 0 end);
VHOST_DEFINE (lpath=>'/countries/Gdata', ppath=>'/SOAP/Http/gdata', soap_user=>'GDEMO');

DB.DBA.USER_CREATE ('GDEMO', uuid(), vector ('DISABLED', 1, 'LOGIN_QUALIFIER', 'GDEMO'));

create procedure vx_s_13_make_desc (in name varchar, in code varchar, in url varchar)
{
  return
      '<div>' ||
      '<b>' || name || '</b><br />' ||
      'ISO code: <i>' || code || '</i><br/>'  ||
      '<img src="'|| url ||'" border="0" />' ||
      '</div>';
};

create procedure GDEMO.GDEMO.gdata (in q varchar := null, in alt varchar := 'atom') __SOAP_HTTP 'text/xml'
{
  declare path, ppath, mask varchar;
  declare country varchar;
  declare pars, lines, full_path, p_full_path any;

  pars := http_param ();
  lines := http_request_header ();
  ppath := http_physical_path ();
  path := split_and_decode (ppath, 0, '\0\0/');

  country := null;
  mask := null;

  if (length (path) > 4)
    country := path[4];

  if (country is not null)
    mask := country;
  else if (q is not null)
    mask := '%'||q||'%';

  set_user_id ('dba');
  full_path := '/tutorial/web/vx_s_13/'||alt||'.xml';
  p_full_path := http_physical_path_resolve (full_path, 1);
  http_internal_redirect (full_path, p_full_path);

  if (mask is not null)
    pars := vector_concat (pars, vector (':mask', lower (mask)));

  if (TUTORIAL_VDIR_DIR () like '/DAV/%')
    WS.WS."GET" (path, pars, lines);
  else
    WS.WS."DEFAULT" (path, pars, lines);

  return null;
};

grant execute on GDEMO.GDEMO.gdata to GDEMO;
