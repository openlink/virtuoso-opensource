--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2016 OpenLink Software
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
DROP TABLE MAIL_AUTO_REPLY;

CREATE TABLE MAIL_AUTO_REPLY (MA_NAME VARCHAR PRIMARY KEY);

CREATE TRIGGER MAIL_MESSAGE_MAIL_AUTO_REPLY AFTER INSERT ON DB.DBA.MAIL_MESSAGE ORDER 10
{
  declare pm any;
  declare rp any;
  declare sa, sb, rbo, addr varchar;
  if (not exists (SELECT 1 FROM MAIL_AUTO_REPLY WHERE MA_NAME = MM_OWN))
    return;
  addr := null;
  pm := vector('init');
  declare exit handler for sqlstate '*' { goto failure; };
    {
      pm := mime_tree (MM_BODY);
      sa := get_keyword ('Subject', aref (pm, 0));
      if (sa not like 'SOAPMethodName:%')
	goto failure;
      addr := get_keyword ('From', aref (pm, 0));
      sb := subseq (MM_BODY, aref (aref (pm,1), 0), aref (aref (pm,1), 1));
      rbo := http_get (sprintf ('http://localhost:%s/services', server_http_port ()),
	  rp, 'POST', concat ('Content-Type: text/xml\r\n',sa), sb);
      smtp_send (null, addr, get_keyword ('From', aref (pm, 0)), concat ('Subject: SOAPresponse\r\n\r\n', rbo));
      return;
    }
failure:;
  declare exit handler for sqlstate '*';
    {
      smtp_send (null, addr, get_keyword ('From', aref (pm, 0)), 'The request failed');
    }
  return;
}
;
