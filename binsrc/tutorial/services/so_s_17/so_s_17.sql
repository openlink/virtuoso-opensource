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
create user EMLV
;

grant all privileges to EMLV
;

user_set_qualifier ('EMLV', 'EMLV')
;

VHOST_REMOVE (vhost=>'*ini*',lhost=>'*ini*',lpath=>'/email_services')
;


VHOST_DEFINE (vhost=>'*ini*',lhost=>'*ini*',lpath=>'/email_services',ppath=>'/SOAP/',soap_user=>'EMLV')
;


create procedure EMLV.EMLV.emailValidate (in server varchar, in address varchar)
{
  declare s any;
  declare str, r varchar;
  if (server is null or length(server) < 1)
    signal ('22023','The server address cannot be empty');
  s := ses_connect (server);
  str := '<mail_validate>\n';
  str := concat (str, '<data type="in">', sprintf ('%V', ses_read_line (s)),'</data>\n');
  ses_write ('HELO Virtuoso_Web_Service\r\n',s);
  r := ses_read_line (s);
  if (r like '220 %')
    {
      str := concat (str, '<data type="in">', sprintf ('%V', r),'</data>\n');
      r := ses_read_line (s);
    }
  str := concat (str, '<data>HELO Virtuoso_Web_Service</data>\n');
  str := concat (str, '<data type="in">', sprintf ('%V', r),'</data>\n');
  ses_write (sprintf('MAIL FROM: <%s>\r\n', address),s);
  str := concat (str, sprintf ('<data>MAIL FROM: &lt;%V&gt;</data>\n', address));
  str := concat (str, '<data type="in">', sprintf ('%V', ses_read_line (s)),'</data>\n');
  ses_write (sprintf('RCPT TO: <%s>\r\n', address),s);
  str := concat (str, sprintf ('<data>RCPT TO: &lt;%V&gt;</data>\n', address));
  r := ses_read_line (s);
  if (r like '2%')
    {
      str := concat (str, '<mail_validated ind="yes" />\n');
      str := concat (str, '<data type="in">', sprintf ('%V', r),'</data>\n');
    }
  else
    {
      str := concat (str, '<mail_validated ind="no" />\n');
      str := concat (str, '<data type="error">', sprintf ('%V', r),'</data>\n');
    }
  ses_write ('QUIT\r\n',s);
  str := concat (str, '<data>QUIT</data>\n');
  str := concat (str, '<data type="in">', sprintf ('%V', ses_read_line (s)),'</data>\n');
  str := concat(str, '</mail_validate>');
  ses_disconnect(s);
  return str;
}
;

grant execute on EMLV.EMLV.emailValidate to EMLV;
