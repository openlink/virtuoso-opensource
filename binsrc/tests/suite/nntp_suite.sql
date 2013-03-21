--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2013 OpenLink Software
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
create procedure
test_nntp_create_group ()
{

  insert into DB.DBA.NEWS_GROUPS (NG_NAME, NG_UP_INT, NG_CLEAR_INT, NG_POST, NG_NEXT_NUM,
      NG_UP_TIME, NG_NUM, NG_FIRST, NG_LAST, NG_SERVER, NG_CREAT, NG_UP_MESS, NG_PASS)

  values ('test', 10, 100, 1, 0, now(), 0, 0, 0, NULL, now(), 0, 0);

  return 1;

}
;


create procedure
test_nntp_post ()
{
  declare new_post varchar;
  declare idx integer;

  new_post := file_to_string ('test_news_server_file');

  idx := 1;

  while (idx < 6 )
    {
      nntp_post ('localhost:$U{NNTPPORT}', concat (new_post, sprintf ('%i\r\n', idx), '.'));
      idx := idx + 1;
    }

  commit work;

  return 1;
}
;


create procedure
test_nntp_get_len ()
{

  if (length (nntp_get ('localhost:$U{NNTPPORT}', 'article', 'test')) = 5 )
    return 1;

  return NULL;
}
;


create procedure
test_nntp_message_id ()
{
  declare _id, _head, _test_str varchar;
  declare _messages any;

  _test_str := '@openlinksw.co.uk>';
  _messages := nntp_get ('localhost:$U{NNTPPORT}', 'head', 'test', 5, 5);
  _head := blob_to_string (aref (aref (_messages, 0) ,1));
  _id := substring (mail_header (_head, 'Message-ID'), 1, 128);

  if ("RIGHT" (_id, 18) = _test_str)
    return 1;

  return NULL;
}
;


create procedure
test_nntp_MD5 ()
{
  declare _body varchar;
  declare _messages any;

  _messages := nntp_get ('localhost:$U{NNTPPORT}', 'body', 'test');

  _body := blob_to_string (aref (aref (_messages, 0) , 1));

  if (not MD5 (_body) = 'fff04fc58d36e592e08da33d915f80a7')
    return NULL;

  _body := blob_to_string (aref (aref (_messages, 4) , 1));

  if (not MD5 (_body) = '914ad623a5a5f42eed126e7d733ff173')
    return NULL;

return 1;
}
;


create procedure
test_nntp_id_get ()
{
  declare id, test_str varchar;
  declare _messages, _messages2 any;
  declare len, idx integer;

  _messages := nntp_get ('localhost:$U{NNTPPORT}', 'stat', 'test');

  len := length (_messages);
  idx := 0;

  while (len > idx)
    {
      id := aref (aref (_messages, idx) , 1);
      _messages2 := nntp_id_get ('localhost:$U{NNTPPORT}', 'article', id);

      if (length (_messages2) = 0)
	return NULL;

      test_str := RIGHT (aref (aref (_messages2, 0), 1), 6);
      test_str := LEFT (test_str, 1);

      if (not atoi (test_str) - 1 = idx)
	return NULL;

      idx := idx + 1;
    }

return 1;
}
;


create procedure
test_nntp_add_to_access_list (in _mode integer)
{
  declare my_ip, ret integer;;

  my_ip := identify_self ();
  my_ip := my_ip [2];

  delete from DB.DBA.NEWS_ACL;
  DB.DBA.news_acl_insert (1, my_ip, 1, _mode);  -- 0 deny read group test
  							    -- 1 deny post group test

  if (_mode)
    DB.DBA.news_acl_insert (1, '127.0.0.1', 1, _mode);
  else
    DB.DBA.news_acl_insert (1, '127.0.0.%', 1, _mode);

  ret := ((select count (*) from DB.DBA.NEWS_ACL)) - 1;

return ret;
}
;


create procedure
test_nntp_acl_list_read ()
{
  declare _list any;

  _list := nntp_get ('localhost:$U{NNTPPORT}', 'list');
  dbg_obj_print (_list);

return length (_list) + 1;
}
;


create procedure
test_nntp_acl_list_post ()
{
  declare _post_avl varchar;
  declare _list any;

  _list := nntp_get ('localhost:$U{NNTPPORT}', 'list');
  _list := _list [0];
  _post_avl := _list [3];

  if (_post_avl = 'n')
    return 1;

return 0;
}
;


select test_nntp_create_group ();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": NTTP Create news group 'test' : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select test_nntp_post ();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": NNTP Post news (5 messages) : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select test_nntp_get_len ();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": NTTP Get all messages : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select test_nntp_message_id ();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": NNTP Test ID message 5 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select test_nntp_MD5 ();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": NTTP Test MD5 first and last messages : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select test_nntp_id_get ();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": NTTP test nntp_id_get  : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select length (nntp_get ('localhost:$U{NNTPPORT}', 'xover', 'test', 1, 10000));
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": NTTP test xover 1-1000 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select test_nntp_add_to_access_list (0);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": NTTP add group test to ACL deny read: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select test_nntp_acl_list_read ();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": NTTP test ACL (read): STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--select test_nntp_add_to_access_list (1);
--ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": NTTP add group test to ACL deny post: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--select test_nntp_acl_list_post ();
--ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": NTTP test ACL (post): STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

set MACRO_SUBSTITUTION OFF ;

FOREACH BLOB INSERT INTO DB.DBA.NEWS_MSG(NM_TYPE, NM_ID,NM_REF,NM_READ,NM_OWN,NM_REC_DATE,NM_STAT,NM_TRY_POST,NM_DELETED,NM_HEAD,NM_BODY,NM_BODY_ID) VALUES('NNTP', '<zMRYcqp4CHA.1460@cpmsftngxa06>','<u4O#5Oo4CHA.2412@TK2MSFTNGP09.phx.gbl>',0,NULL,stringdate('2003.03.13 18:37.30 000000'),NULL,NULL,NULL,?,?,959);
Á¼\3Á¼ µ\13X-Tomcat-IDµ\11624644810µ
Referencesµ\47<u4O#5Oo4CHA.2412@TK2MSFTNGP09.phx.gbl>µ\14MIME-Versionµ\31.0µ\14Content-Typeµ
text/plainµ\31Content-Transfer-Encodingµ\47bitµ\4Fromµ5HussAbOnline@microsoft.com (Hussein Abuthuraya(MSFT))µ\14Organizationµ\11Microsoftµ\4Dateµ\35Tue, 04 Mar 2003 22:09\c
:04 GMTµ\7Subjectµ)RE: Which DataAdapter/Reader/etc. to use?µ\13X-Tomcat-NGµ)microsoft.public.dotnet.framework.odbcnetµ
Message-IDµ\37<zMRYcqp4CHA.1460@cpmsftngxa06>µ
Newsgroupsµ)microsoft.public.dotnet.framework.odbcnetµ\5Linesµ
73        µ\21NNTP-Posting-Hostµ\34TOMCATIMPORT2 10.201.218.182µ\4Pathµ!TK2MSFTNGP08.phx.gbl!cpmsftngxa06µ\4XrefµCTK2MSFTNGP08.phx.gbl microsoft.public.dotnet.framew\c
ork.odbcnet:2722Á¼\4½\0\0\2\240½\0\0\15ä¼\0¼\0¼\0\c
BLOB
X-Tomcat-ID: 624644810\15
References: <u4O#5Oo4CHA.2412@TK2MSFTNGP09.phx.gbl>\15
MIME-Version: 1.0\15
Content-Type: text/plain\15
Content-Transfer-Encoding: 7bit\15
From: HussAbOnline@microsoft.com (Hussein Abuthuraya(MSFT))\15
Organization: Microsoft\15
Date: Tue, 04 Mar 2003 22:09:04 GMT\15
Subject: RE: Which DataAdapter/Reader/etc. to use?\15
X-Tomcat-NG: microsoft.public.dotnet.framework.odbcnet\15
Message-ID: <zMRYcqp4CHA.1460@cpmsftngxa06>\15
Newsgroups: microsoft.public.dotnet.framework.odbcnet\15
Lines: 73        \15
NNTP-Posting-Host: TOMCATIMPORT2 10.201.218.182\15
Path: TK2MSFTNGP08.phx.gbl!cpmsftngxa06\15
Xref: TK2MSFTNGP08.phx.gbl microsoft.public.dotnet.framework.odbcnet:2722\15
\15
Kyong,\15
\15
The future path for Data Access is to have specific .NET Data Provider for each backend database.  We started by developing the SQLClient .NET Data provider th\c
at is \15
specific to SQL Server and takes advantage of specific SQL Server features.  The same with the OracleClient .NET Data provider.  Third party vendors may build \c
specific \15
.NET providers for specific backend.  These specific prviders are talking to the back end databases directly without using any of the additional layers that ar\c
e there when \15
using OLEDB or ODBC.\15
\15
The .NET generic Data providers are OLEDB and ODBC .NET Data providers and they are built on top of the OLEDB providers and ODBC drivers.  Definitely there has\c
 \15
been many improvements and enhancements when you use a .NET Data provider that is written specific to only one backend verses the generic one.\15
\15
>>\15
There is the OleDbXXX methods which might work, but isn\47t that just an overlay of ODBC?\15
<<\15
\15
Simply this is not true.  OLEDB technology is totally different than ODBC.  Each has its own API\47s and you may programm directly to those APIs or use ADO that \c
is a \15
wrapper on to top of these APIs.  There is the MSDASQL (which is the OLEDB Provider for ODBC) which is an OLEDB provider that talks to the ODBC drivers for whi\c
ch that \15
there will be a translation layer and some additional overhead.  Maybe you confused MSDASQL with OLEDB .NET Data provider but as you can see they are not the \15
same.\15
\15
Now, go back to your question which one to use?  First you need to see what is available for each backend database.  If for all backend databases, you could ge\c
t hold of \15
OLEDB providers then you could use .NET OLEDB provider.  The same if you could find ODBC drivers for all of them then you dould use .NET ODBC Data provider.  T\c
he \15
problem comes if some of them offer ODBC drivers and some them offer OLEDB providers then building one solution for all backend databases using one .NET Data \15
provider seems impossible.\15
\15
Also, performance wise, the ODBC technology (in general) is not as good as the OLEDB technology but in some cases some OLEDB providers are not built in a good \c
\15
way which makes them as not performant as the ODBC drivers.  You need to look into some performance data comparing OELDB and ODBC for particular back end \15
which will give you better feeling to what to use.  Such data may be available from the vendors who built these drivers and providers.\15
\15
The recommended path for ADO.NET is to use specifc .NET Data Providers instead of the generic ones if possible.\15
\15
\15
Thanks,\15
Hussein Abuthuraya\15
Microsoft Developer Support\15
\15
This posting is provided "AS IS" with no warranties, and confers no rights. \15
\15
Are you secure? For information about the Microsoft Strategic Technology Protection Program and to order your FREE Security Tool Kit, please visit \15
http://www.microsoft.com/security.\15
\15
\15
.\15
END
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": NNTP Prepare data for bug4482 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- XXX
--delete from NEWS_MSG where NM_ID='<zMRYcqp4CHA.1460@cpmsftngxa06>';
--ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": NNTP bug4482 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
