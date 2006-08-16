--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2006 OpenLink Software
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
  sys_addr := split_and_decode (sys_connected_server_address (), 0, '\0\0:');
  options := vector (
    '__VIRT_CGI', 		'1'
   ,'SERVER_SOFTWARE', 		'Virtuoso Universal Server/3.0'
   ,'SERVER_SIGNATURE',		'Virtuoso Universal Server/3.0 on ' || sys_connected_server_address ()
   ,'SERVER_NAME', 		sys_addr[0]
   ,'SERVER_ADDR', 		sys_addr[0]
   ,'DOCUMENT_ROOT', 		http_root()
   ,'GATEWAY_INTERFACE',	'CGI/1.1'
   ,'SERVER_PROTOCOL',		http_request_get ('SERVER_PROTOCOL')
   ,'SERVER_PORT',		sys_addr[1]
   ,'REQUEST_METHOD',		http_request_get ('REQUEST_METHOD')
   ,'REQUEST_URI',		http_path()
   ,'PATH_INFO',		http_path()
   ,'PATH_TRANSLATED',		http_root() || http_physical_path ()
   ,'SCRIPT_NAME',		http_path ()
   ,'SCRIPT_FILENAME',		http_root() || http_physical_path ()
   ,'QUERY_STRING',		http_request_get ('QUERY_STRING')
 --,'REMOTE_HOST',		http_client_ip ()
   ,'REMOTE_ADDR',		http_client_ip ()
 --,'AUTH_TYPE',		http_client_ip ()
 --,'REMOTE_USER',		http_client_ip ()
 --,'REMOTE_IDENT',		http_client_ip ()
   ,'CONTENT_TYPE',		http_request_header (lines, 'Content-Type', NULL, '')
   ,'CONTENT_LENGTH',		http_request_header (lines, 'Content-Length', NULL, '0')
  );
  declare inx integer;
  inx := 1;
  while (inx < length (lines))
    {
      declare line,fld varchar;
      declare first_colon integer;
      line := lines[inx];
      first_colon := strchr (line, ':');
      if (first_colon is not null)
	{
	  fld := trim (subseq (line, 0, first_colon));
	  options := vector_concat (options, vector (
		       concat ('HTTP_', upper (replace (fld, '-', '_'))),
		       http_request_header (lines, fld)));
	}
      inx := inx + 1;
    }
  return options;
}
;

