--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2023 OpenLink Software
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








-- Autogenerated test script


create procedure upload_doc (in path varchar, in content any)
{
  return DAV_RES_UPLOAD (path, content,  'plain/text' , '110100100R', 'dav', 'administrators', 'dav', 'dav');
}
;

create procedure upload_docs (in path varchar, in num int := 10)
{
 declare idx int;
 idx := num;
 while (idx > 0)
  {
    declare res int;
    res := upload_doc (path || sprintf ('test%d.txt', idx), sprintf ('hello world! - %d', idx) );
    if (res < 0)
    	return res;
    idx := idx - 1;
  }
 return 1;
}
;

create procedure get_doc (in path varchar)
{
  declare content,id any;
  declare type varchar;
  id := DAV_SEARCH_ID (path, 'R');
  --dbg_obj_princ ('id: ', id);
  if (isarray (id) and (DAV_RES_CONTENT_INT (id, content, type, 0, 0, null, null) > 0))
    {
      return content;
    }
  return NULL;
}
;

create procedure get_doc_v (in path varchar, in ver int)
{
  declare content,id any;
  declare mode varchar;
  id := DAV_SEARCH_ID (path, 'R');
  --dbg_obj_princ ('id: ', id);
  if (isarray (id) and (DAV_GET_VERSION_CONTENT (aref (id, 2), ver, content, mode) >= 0))
    {
      return content;
    }
  return NULL;
}
;

DB.DBA.DAV_DELETE ('/DAV/versioning/', 1, 'dav','dav');
ECHO BOTH $IF $EQU $STATE "OK" "PASSED:" "***FAILED:";
ECHO BOTH " Deleting versioning collection"  ":" $STATE "\n";
select DB.DBA.DAV_COL_CREATE ('/DAV/versioning/', '110100000R', 'dav', 'administrators', 'dav', 'dav');
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED:" "***FAILED:";
ECHO BOTH " Create test collection: " ":" $LAST[1] "\n";

update WS.WS.SYS_DAV_COL set COL_DET='Versioning' where COL_ID = DAV_SEARCH_ID ('/DAV/versioning/', 'C');
ECHO BOTH $IF $EQU $STATE "OK" "PASSED:" "***FAILED:";
ECHO BOTH " Set Versioning DET " ":" $STATE "\n";

select upload_docs ('/DAV/versioning/', 20);
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED:" "***FAILED:";
ECHO BOTH  " Upload docs to collection /DAV/versioning/ " ":" $LAST[1] "\n";

select DB.DBA.DAV_COL_CREATE ('/DAV/versioning/test_dir/',  '110100000R', 'dav', 'administrators', 'dav', 'dav');
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED:" "***FAILED:";
ECHO BOTH  " Create /DAV/versioning/test_dir/ "  ":" $LAST[1] "\n";

select DB.DBA.DAV_COL_CREATE ('/DAV/versioning/test_dir1/',  '110100000R', 'dav', 'administrators', 'dav', 'dav');
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED:" "***FAILED:";
ECHO BOTH  " Create /DAV/versioning/test_dir1/ " ":" $LAST[1] "\n";

select DB.DBA.DAV_COL_CREATE ('/DAV/versioning/test_dir2/',  '110100000R', 'dav', 'administrators', 'dav', 'dav');
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED:" "***FAILED:";
ECHO BOTH  " Create /DAV/versioning/test_dir2/ " ":" $LAST[1] "\n";

select upload_docs ('/DAV/versioning/test_dir/', 5);
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED:" "***FAILED:";
ECHO BOTH  " upload docs to /DAV/versioning/test_dir/ "  ":" $LAST[1] "\n";

select DB.DBA.DAV_COL_CREATE ('/DAV/versioning/test_dir/a2/',  '110100000R', 'dav', 'administrators', 'dav', 'dav');
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED:" "***FAILED:";
ECHO BOTH  " Create /DAV/versioning/test_dir/a2/ "  ":" $LAST[1] "\n";
select COL_DET from WS.WS.SYS_DAV_COL where COL_ID = DAV_SEARCH_ID ('/DAV/versioning/test_dir/a2/', 'C');
ECHO BOTH $IF $EQU $LAST[1] 'Versioning' "PASSED:" "***FAILED:";
ECHO BOTH " Check is test_dir/a2 under Versioning DET control " ":" $LAST[1] "\n";

select upload_docs ('/DAV/versioning/test_dir/a2/', 10);
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED:" "***FAILED:";
ECHO BOTH  " Upload docs to /DAV/versioning/test_dir/a2/ "  ":" $LAST[1] "\n";

select DAV_SEARCH_ID ('/DAV/versioning/test_dir/test1.txt', 'R');
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED:" "***FAILED:";
ECHO BOTH " Check /DAV/versioning/test_dir/test1.txt " ":" $LAST[1] "\n";

select DAV_SEARCH_ID ('/DAV/versioning/test1.txt', 'R');
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED:" "***FAILED:";
ECHO BOTH  " Check /DAV/versioning/test1.txt "  ":" $LAST[1] "\n";

select DAV_SEARCH_ID ('/DAV/versioning/test2.txt', 'R');
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED:" "***FAILED:";
ECHO BOTH  " Check /DAV/versioning/test2.txt "  ":" $LAST[1] "\n";

select DAV_SEARCH_ID ('/DAV/versioning/test_dir/a2/test1.txt', 'R');
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED:" "***FAILED:";
ECHO BOTH  " Check /DAV/versioning/test_dir/a2/test1.txt "  ":" $LAST[1] "\n";

select DAV_SEARCH_ID ('/DAV/versioning/test_dir/testXX.txt', 'R');
ECHO BOTH $IF $GT 0 $LAST[1] "PASSED:" "***FAILED:";
ECHO BOTH  " Check /DAV/versioning/test_dir/testXX.txt "  ":" $LAST[1] "\n";

select upload_doc ('/DAV/versioning/test2-1.txt', 'hello');
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED:" "***FAILED:";
ECHO BOTH  " upload /DAV/versioning/test2-1.txt "  ":" $LAST[1] "\n";
select upload_doc ('/DAV/versioning/test2-1.txt', 'hello');
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED:" "***FAILED:";
ECHO BOTH  " second upload /DAV/versioning/test2-1.txt "  ":" $LAST[1] "\n";
select DAV_SEARCH_ID ('/DAV/versioning/test2-1.txt', 'R');
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED:" "***FAILED:";
ECHO BOTH  " check /DAV/versioning/test2-1.txt "  ":" $LAST[1] "\n";

ECHO BOTH "Checking versioning, Pass 1 ...\n";
select upload_doc ('/DAV/versioning/file0.txt', 'content of file1.txt, version 1');
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED:" "***FAILED:";
ECHO BOTH  " upload initial version of file0.txt " ":" $LAST[1] "\n";
select RES_STATUS from WS.WS.SYS_DAV_RES where RES_FULL_PATH =  '/DAV/versioning/file0.txt';
ECHO BOTH $IF $EQU $LAST[1] 'AV' "PASSED:" "***FAILED:";
ECHO BOTH  " check status of file0.txt " ":" $LAST[1] "\n";
select RV_ID from WS.WS.SYS_DAV_RES_VERSION where RV_RES_ID = aref (DAV_SEARCH_ID ('/DAV/versioning/file0.txt', 'R'), 2);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED:" "***FAILED:";
ECHO BOTH  " check version of file0.txt " ":" $LAST[1] "\n";


ECHO BOTH "Checking versioning, Pass 2 ...\n";

select upload_doc ('/DAV/versioning/file1.txt', 'content of file1.txt, version 1');
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED:" "***FAILED:";
ECHO BOTH  " upload initial version of file1.txt " ":" $LAST[1] "\n";
select upload_doc ('/DAV/versioning/file1.txt', 'content of file1.txt, version 2');
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED:" "***FAILED:";
ECHO BOTH  " upload second version of file1.txt " ":" $LAST[1] "\n";
select upload_doc ('/DAV/versioning/file1.txt', 'content of file1.txt, version 3');
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED:" "***FAILED:";
ECHO BOTH  " upload third version of file1.txt " ":" $LAST[1] "\n";
select upload_doc ('/DAV/versioning/file1.txt', 'content of file1.txt, version 4');
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED:" "***FAILED:";
ECHO BOTH  " upload 4th version of file1.txt " ":" $LAST[1] "\n";
select upload_doc ('/DAV/versioning/file1.txt', 'content of file1.txt, version 5');
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED:" "***FAILED:";
ECHO BOTH  " upload 5th version of file1.txt " ":" $LAST[1] "\n";
select get_doc ('/DAV/versioning/file1.txt');
ECHO BOTH $IF $EQU $LAST[1] 'content of file1.txt, version 5' "PASSED:" "***FAILED:";
ECHO BOTH  " check last version of file1.txt " ":" $LAST[1] "\n";
select get_doc_v ('/DAV/versioning/file1.txt', 5);
ECHO BOTH $IF $EQU $LAST[1] 'content of file1.txt, version 5' "PASSED:" "***FAILED:";
ECHO BOTH  " check 5th version of file1.txt " ":" $LAST[1] "\n";
select get_doc_v ('/DAV/versioning/file1.txt', 4);
ECHO BOTH $IF $EQU $LAST[1] 'content of file1.txt, version 4' "PASSED:" "***FAILED:";
ECHO BOTH  " check 4th version of file1.txt " ":" $LAST[1] "\n";
select get_doc_v ('/DAV/versioning/file1.txt', 3);
ECHO BOTH $IF $EQU $LAST[1] 'content of file1.txt, version 3' "PASSED:" "***FAILED:";
ECHO BOTH  " check third version of file1.txt " ":" $LAST[1] "\n";
select get_doc_v ('/DAV/versioning/file1.txt', 2);
ECHO BOTH $IF $EQU $LAST[1] 'content of file1.txt, version 2' "PASSED:" "***FAILED:";
ECHO BOTH  " check second version of file1.txt " ":" $LAST[1] "\n";
select get_doc_v ('/DAV/versioning/file1.txt', 1);
ECHO BOTH $IF $EQU $LAST[1] 'content of file1.txt, version 1' "PASSED:" "***FAILED:";
ECHO BOTH  " check first version of file1.txt " ":" $LAST[1] "\n";
select get_doc_v ('/DAV/versioning/file1.txt', 10);
ECHO BOTH $IF $EQU $LAST[1] NULL "PASSED:" "***FAILED:";
ECHO BOTH  " check non-existent version of file1.txt " ":" $LAST[1] "\n";
select get_doc_v ('/DAV/versioning/file1.txt', -1);
ECHO BOTH $IF $EQU $LAST[1] NULL "PASSED:" "***FAILED:";
ECHO BOTH  " check non-existent version of file1.txt " ":" $LAST[1] "\n";
select DB.DBA.DAV_DELETE ('/DAV/versioning/file1.txt', 1, 'dav','dav');
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED:" "***FAILED:";
ECHO BOTH  " delete /DAV/versioning/file1.txt file " ":" $LAST[1] "\n";


-- select upload_doc ('/DAV/versioning/test_dir/a2/file1.txt', 'content of file1.txt, version 1');
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED:" "***FAILED:";

