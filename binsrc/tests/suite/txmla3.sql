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


create procedure test_bookmark (in _server varchar, in _server_http_port any, in _direction varchar)
{

-- for sample are using column U_NAME from table SYS_USERS.
-- on clear db "select U_NAME from SYS_USERS" returns:

-- SQL> select U_NAME from SYS_USERS;
-- U_NAME
-- VARCHAR NOT NULL
-- _______________________________________________________________________________

-- dba
-- dav
-- administrators
-- nobody
-- nogroup
-- SPARQL
-- XMLA

-- 7 Rows. -- 1 msec.
-- SQL>


-- This only check proper XMLA server version:

   declare state, message, meta, result any;
   exec ('select xmla_get_version ()', state, message, vector(), 0, meta, result);

   if (isarray (result))
    result := result[0][0];

   if (result <> '1.01')
    signal ('00000', 'Please upgrade Virtuoso DBMS server to use this exzample');

-- End check.

  declare resp, resp1, resp2, bookmarks, bookmark, unames, _name, idx any;

  _server_http_port := cast (_server_http_port as varchar);

-- First call

  dbg_obj_print ('First call. direction is ', _direction, ' get first 3 rows.');

  resp1 := soap_client (url=>'http://' || _server || ':' || _server_http_port || '/XMLA',
	 operation=>'Execute',
	 target_namespace=>'urn:schemas-microsoft-com:xml-analysis',
	 soap_action=>'urn:schemas-microsoft-com:xml-analysis:Execute',
	 parameters=>
	    vector ('Command', soap_box_structure ('Statement', 'select U_NAME from SYS_USERS'),
		    'Properties', soap_box_structure ('PropertyList',
		      soap_box_structure ('DataSourceInfo', xmla_service_name (), 'return-bookmark', 1, 'n-rows', 3,
			'skip', 2, 'direction', _direction, 'UserName', 'dba', 'Password', 'dba'))
	           ), style=>2);

  resp := xml_tree_doc (resp1[0]);
  bookmarks := xpath_eval ('//BOOKMARK', resp, 0);
  unames := xpath_eval ('//U_NAME', resp, 0);

  for (idx := 0; idx < length (bookmarks); idx := idx + 1)
    {
	_name := cast (unames[idx] as varchar);
	bookmark := cast (bookmarks[idx] as varchar);
	dbg_obj_print ('U_NAME = ', _name, ' bookmark = ', bookmark);
    }

-- Second call

  dbg_obj_print ('Second call. Direction is ''forward'' bookmark = ', bookmark, ' and get 2 rows.');

  resp2 := soap_client (url=>'http://' || _server || ':' || _server_http_port || '/XMLA',
	 operation=>'Execute',
	 target_namespace=>'urn:schemas-microsoft-com:xml-analysis',
	 soap_action=>'urn:schemas-microsoft-com:xml-analysis:Execute',
	 parameters=>
	    vector ('Command', soap_box_structure ('Statement', 'select U_NAME from SYS_USERS'),
		    'Properties', soap_box_structure ('PropertyList',
		      soap_box_structure ('DataSourceInfo', xmla_service_name (), 'return-bookmark', 1, 'n-rows', 2,
			'skip', 0, 'bookmark-from', bookmark, 'direction', 'forward', 'UserName', 'dba', 'Password', 'dba'))
	           ), style=>2);

  resp := xml_tree_doc (resp2[0]);
  bookmarks := xpath_eval ('//BOOKMARK', resp, 0);
  unames := xpath_eval ('//U_NAME', resp, 0);

  for (idx := 0; idx < length (bookmarks); idx := idx + 1)
    {
	_name := cast (unames[idx] as varchar);
	bookmark := cast (bookmarks[idx] as varchar);
	dbg_obj_print ('U_NAME = ', _name, ' bookmark = ', bookmark);
    }

-- For full dialog please enable next lines:
-- dbg_obj_print ('request 1 ', resp1[1]);
-- dbg_obj_print ('responce 1 ', resp1[2]);
-- dbg_obj_print ('request 2 ', resp2[1]);
-- dbg_obj_print ('responce 2 ', resp2[2]);
}
;

-- Expected output on server console:
-- 'First call. direction is ''forward'' get first 3 rows.'
-- 'U_NAME = ''dba'' bookmark = ''wbwDvAC8ALwA'
-- 'U_NAME = ''dav'' bookmark = ''wbwDvAC8AbwA'
-- 'U_NAME = ''administrators'' bookmark = ''wbwDvAC8ArwA'
-- 'Second call. Direction is \'forward\' bookmark = ''wbwDvAC8ArwA'' and get 2 rows.'
-- 'U_NAME = ''administrators'' bookmark = ''wbwDvAC8ALwA'
-- 'U_NAME = ''nobody'' bookmark = ''wbwDvAC8AbwA'

test_bookmark ('localhost', server_http_port(), 'forward')
;

-- Expected output:
-- 'First call. direction is ''backward'' get first 3 rows.'
-- 'U_NAME = ''XMLA'' bookmark = ''wbwDvAC8BrwB'
-- 'U_NAME = ''SPARQL'' bookmark = ''wbwDvAC8BbwB'
-- 'U_NAME = ''nogroup'' bookmark = ''wbwDvAC8BLwB'
-- 'Second call. Direction is \'forward\' bookmark = ''wbwDvAC8BLwB'' and get 2 rows.'
-- 'U_NAME = ''nogroup'' bookmark = ''wbwDvAC8ALwA'
-- 'U_NAME = ''SPARQL'' bookmark = ''wbwDvAC8AbwA'
test_bookmark ('localhost', server_http_port(), 'backward')
;

drop table TEST_XMLA
;

create table TEST_XMLA (val varchar)
;

insert into TEST_XMLA values ('a1')
;

insert into TEST_XMLA values ('a2')
;

insert into TEST_XMLA values ('a3')
;

insert into TEST_XMLA values ('a4')
;

insert into TEST_XMLA values ('a5')
;

insert into TEST_XMLA values ('a6')
;

insert into TEST_XMLA values ('a7')
;

create procedure test_bookmark_suite (in _server varchar, in _server_http_port any,
	in _direction1 varchar, in skip1 int, in exp1 any,
	in _direction2 varchar, in skip2 int, in exp2 any)
{

  declare resp, resp1, resp2, bookmarks, bookmark, unames, _name, idx any;

  _server_http_port := cast (_server_http_port as varchar);

  resp1 := soap_client (url=>'http://' || _server || ':' || _server_http_port || '/XMLA',
	 operation=>'Execute',
	 target_namespace=>'urn:schemas-microsoft-com:xml-analysis',
	 soap_action=>'urn:schemas-microsoft-com:xml-analysis:Execute',
	 parameters=>
	    vector ('Command', soap_box_structure ('Statement', 'select val from TEST_XMLA'),
		    'Properties', soap_box_structure ('PropertyList',
		      soap_box_structure ('DataSourceInfo', xmla_service_name (), 'return-bookmark', 1, 'n-rows', 3,
			'skip', skip1, 'direction', _direction1, 'UserName', 'dba', 'Password', 'dba'))
	           ), style=>2);

  resp := xml_tree_doc (resp1[0]);
  unames := xpath_eval ('//val', resp, 0);
  bookmarks := xpath_eval ('//BOOKMARK', resp, 0);

  for (idx := 0; idx < length (unames); idx := idx + 1)
    {
	_name := cast (unames[idx] as varchar);
	bookmark := cast (bookmarks[idx] as varchar);
	dbg_obj_print (_name, exp1[idx]);
  	if (_name <> exp1[idx])
    	  return 0;
    }

  resp2 := soap_client (url=>'http://' || _server || ':' || _server_http_port || '/XMLA',
	 operation=>'Execute',
	 target_namespace=>'urn:schemas-microsoft-com:xml-analysis',
	 soap_action=>'urn:schemas-microsoft-com:xml-analysis:Execute',
	 parameters=>
	    vector ('Command', soap_box_structure ('Statement', 'select val from TEST_XMLA'),
		    'Properties', soap_box_structure ('PropertyList',
		      soap_box_structure ('DataSourceInfo', xmla_service_name (), 'return-bookmark', 1, 'n-rows', 2,
			'skip', skip2, 'bookmark-from', bookmark, 'direction', _direction2, 'UserName', 'dba', 'Password', 'dba'))
	           ), style=>2);

  resp := xml_tree_doc (resp2[0]);
  unames := xpath_eval ('//val', resp, 0);

  for (idx := 0; idx < length (unames); idx := idx + 1)
    {
	_name := cast (unames[idx] as varchar);
  	dbg_obj_print (_name, exp2[idx]);
  	if (_name <> exp2[idx])
    	  return 0;
    }

    return 1;
}
;

select test_bookmark_suite ('localhost', server_http_port(),
'forward', 2, vector ('a3', 'a4', 'a5'),
'forward', 0, vector ('a5', 'a6'))
;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": XMLA Bookmark test 1 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select test_bookmark_suite ('localhost', server_http_port(),
'backward', 3, vector ('a4', 'a3', 'a2'),
'forward', 1, vector ('a3', 'a4'))
;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": XMLA Bookmark test 2 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select test_bookmark_suite ('localhost', server_http_port(),
'backward', 2, vector ('a5', 'a4', 'a3'),
'backward', 1, vector ('a2', 'a1'))
;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": XMLA Bookmark test 3 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select test_bookmark_suite ('localhost', server_http_port(),
'backward', 2, vector ('a5', 'a4', 'a3'),
'backward', 2, vector ('a1'))
;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": XMLA Bookmark test 4 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select test_bookmark_suite ('localhost', server_http_port(),
'forward', 1, vector ('a2', 'a3', 'a4'),
'forward', 3, vector ('a7'))
;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": XMLA Bookmark test 5 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
