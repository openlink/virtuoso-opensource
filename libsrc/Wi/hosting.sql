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
create procedure WS.WS.GET_CGI_VARS_VECTOR (inout lines any) returns ANY
{
  declare options any;
  declare sys_addr varchar;
  declare server_addr varchar;
  declare host varchar;
  declare line varchar;
  declare fld varchar;
  declare server_name varchar;
  declare first_colon integer;

  sys_addr := sys_connected_server_address ();
  server_addr := split_and_decode (sys_addr, 0, '\0\0:');
  server_name := server_addr[0];
  host := http_request_header (lines, 'HOST', null, null);
  if (host is not null)
    {
      first_colon := strchr (host, ':');
      if (first_colon is null)
	server_name := trim (host);
      else
	server_name := trim (subseq (host, 0, first_colon));
    }
  options := vector (
    '__VIRT_CGI', 		'1'
   ,'__VIRT_APP_UID', 		http_map_get ('vsp_uid')
   ,'__VIRT_APP_LPATH', 	http_map_get ('domain')
   ,'__VIRT_APP_PPATH', 	http_map_get ('mounted')
   ,'SERVER_SOFTWARE', 		'Virtuoso Universal Server/6.0'
   ,'SERVER_SIGNATURE',		'Virtuoso Universal Server/6.0 on ' || sys_addr
   ,'SERVER_NAME', 		server_name
   ,'SERVER_ADDR', 		server_addr[0]
   ,'DOCUMENT_ROOT', 		http_root()
   ,'GATEWAY_INTERFACE',	'CGI/1.1'
   ,'SERVER_PROTOCOL',		http_request_get ('SERVER_PROTOCOL')
   ,'SERVER_PORT',		server_addr[1]
   ,'REQUEST_METHOD',		http_request_get ('REQUEST_METHOD')
   ,'REQUEST_URI',		http_request_get ('REQUEST_URI')
 --,'PATH_INFO',		''
   ,'PATH_TRANSLATED',		http_root() || http_physical_path ()
   ,'SCRIPT_NAME',		http_path ()
   ,'SCRIPT_FILENAME',		http_root() || http_physical_path ()
   ,'QUERY_STRING',		http_request_get ('QUERY_STRING')
   ,'REMOTE_ADDR',		http_client_ip ()
   ,'AUTHORIZATION',		http_auth ()
   ,'CONTENT_TYPE',		http_request_header_full (lines, 'Content-Type', '')
   ,'CONTENT_LENGTH',		http_request_header_full (lines, 'Content-Length', '0')
  );
  if (is_https_ctx ())
    options := vector_concat (options, vector ('HTTPS', 'on'));

  declare inx integer;
  inx := 1;
  while (inx < length (lines))
    {
      line := lines[inx];
      first_colon := strchr (line, ':');
      if (first_colon is not null)
	{
	  fld := trim (subseq (line, 0, first_colon));
	  options := vector_concat (options, vector (
		       concat ('HTTP_', upper (replace (fld, '-', '_'))),
		       http_request_header_full (lines, fld)));
	}
      inx := inx + 1;
    }
  return options;
}
;

