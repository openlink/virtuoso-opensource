--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2019 OpenLink Software
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
include(`test.m4')


changequote(`, ")
create procedure prop_set (in path varchar, in prop_assoc_set any, in prop_assoc_del any)
{
  declare idx int;
  for (idx := 0; idx < length (prop_assoc_set); idx := idx + 2)
   {
     if (DAV_HIDE_ERROR (DAV_PROP_SET (path, prop_assoc_set[idx], prop_assoc_set[idx+1], 'dav', 'dav')) is null)
 	return -1;
   }
  for (idx := 0; idx < length (prop_assoc_del); idx := idx + 1)
   {
     if (DAV_HIDE_ERROR (DAV_PROP_REMOVE (path, prop_assoc_del[idx], 'dav', 'dav')) is null)
 	return -1;
   }
  return 1;
}
;



create procedure upload_doc (in path varchar, in content any)
{
  return DAV_RES_UPLOAD (path, content,  'text/plain' , '110100100R', 'dav', 'administrators', 'dav', 'dav');
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
  if ((DAV_HIDE_ERROR(id) is not null) and (DAV_RES_CONTENT_INT (id, content, type, 0, 0, null, null) > 0))
    {
      return content;
    }
  dbg_obj_princ ('id = ', id);
  if (DAV_HIDE_ERROR (id) is not null)
    dbg_obj_princ ('content_int = ', DAV_RES_CONTENT_INT (id, content, type, 0, 0, null, null));
  return NULL;
}
;

create procedure get_doc_v (in path varchar, in ver int)
{
  declare content,id, mode any;
  declare type varchar;
  id := DAV_SEARCH_ID (path, 'R');
  dbg_obj_princ ('id: ', id);
  if ((id>0) and (DAV_GET_VERSION_CONTENT (id, ver, content, type, mode) >= 0))
    {
      return content;
    }
  return NULL;
}
;

create procedure check_file (in path varchar, in _type varchar(1):= 'R')
{
  declare id any;
  id := DAV_SEARCH_ID (path, _type);
  if (isinteger (id) and (id < 0))
    return 'not found';
  return 'found';
}
;

create procedure select_from_dir (in base varchar, in file varchar)
{
  declare _dirl any;
  _dirl := DAV_DIR_LIST (base, 0, 'dav', 'dav');
  foreach (any f in _dirl) do {
    if (aref (f, 10) = file)
      return 'found';
  }
  return 'not found';
}
;



create procedure get_doc_v_2 (in det_path varchar, in filename varchar, in ver_or_hist any)
{
  declare content,id any;
  declare mode varchar;

  declare full_path varchar;
  full_path := sprintf ('%s/%s/%s', det_path, filename, cast (ver_or_hist as varchar));
  id := DAV_SEARCH_ID (full_path, 'R');
  dbg_obj_princ ('id: ', id);
  if (isarray (id) and (DAV_RES_CONTENT (full_path, content, mode,  'dav', 'dav') > 0))
    {
      return content;
    }
  return NULL;
}
;

create procedure get_prop (in path varchar, in prop varchar)
{
  return DB.DBA.DAV_PROP_GET(path, prop, 'dav', 'dav');
}
;

create procedure mv (in src varchar, in target varchar, in overwrt int:=0)
{
  return DAV_MOVE (src, target, overwrt, 'dav', 'dav');
}
;


create procedure lock_res (in path varchar)
{
  declare _token varchar;
  _token := DB.DBA.DAV_LOCK (path, 'R', 'R', null, 'dav', null, null, 3600, 'dav', 'dav');
  if (isstring (_token))
    {
	registry_set ('DETVerTest.LockToken', _token);
	return 1;
    }
  else
	return _token;
}
;

create procedure unlock_res (in path varchar)
{
  return DB.DBA.DAV_UNLOCK (path, registry_get ('DETVerTest.LockToken'), 'dav', 'dav');
}
;

create function get_res_prop (in coll varchar, in res varchar, in idx int)
{
  foreach (any prop_v in DAV_DIR_LIST (coll, 0, 'dav', 'dav'))
  do {
      if (prop_v[0] = coll || res)
        return prop_v[idx];
    }
   return NULL;
}
;

create function copy (in source varchar, in dest varchar)
{
  declare _rc int;
  _rc := DAV_COPY (source, dest, 1, '110100000RR', 'dav', 'administrators',
     'dav', 'dav');
  return _rc;
}

changequote([, ])

ECHO BOTH "Checking versioning, Pass 0 ...\n";

ok(   [delete from WS.WS.SYS_DAV_LOCK],
	[" Clear all locks"] )
ok(   [DB.DBA.DAV_DELETE ('/DAV/versioning/', 1, 'dav','dav')],
	[" Deleting versioning collection"] )
ok(   [DB.DBA.DAV_DELETE ('/DAV/vers/', 1, 'dav','dav')],
	[" Deleting versioning collection"] )
valgt(   [select DB.DBA.DAV_COL_CREATE ('/DAV/versioning/', '110100000R', 'dav', 'administrators', 'dav', 'dav')], [0],
	[" Create test collection: "])

ok(   [update WS.WS.SYS_DAV_COL set COL_AUTO_VERSIONING='A' where COL_ID = DAV_SEARCH_ID ('/DAV/versioning/', 'C')],
	[" Set Versioning control on "])

valgt(   [select upload_docs ('/DAV/versioning/', 20)], [0],
	[ " Upload docs to collection /DAV/versioning/ "])

valgt(   [select DB.DBA.DAV_COL_CREATE ('/DAV/versioning/test_dir/',  '110100000R', 'dav', 'administrators', 'dav', 'dav')], [0],
	[ " Create /DAV/versioning/test_dir/ " ])

valgt(   [select DB.DBA.DAV_COL_CREATE ('/DAV/versioning/test_dir1/',  '110100000R', 'dav', 'administrators', 'dav', 'dav')], [0],
	[ " Create /DAV/versioning/test_dir1/ "])

valgt(   [select DB.DBA.DAV_COL_CREATE ('/DAV/versioning/test_dir2/',  '110100000R', 'dav', 'administrators', 'dav', 'dav')], [0],
	[ " Create /DAV/versioning/test_dir2/ "])

valgt(   [select upload_docs ('/DAV/versioning/test_dir/', 5)], [0],
	[ " upload docs to /DAV/versioning/test_dir/ " ])

valgt(   [select DB.DBA.DAV_COL_CREATE ('/DAV/versioning/test_dir/a2/',  '110100000R', 'dav', 'administrators', 'dav', 'dav')], [0],
	[ " Create /DAV/versioning/test_dir/a2/ " ])
val(   [select COL_AUTO_VERSIONING from WS.WS.SYS_DAV_COL where COL_ID = DAV_SEARCH_ID ('/DAV/versioning/test_dir/a2/', 'C')], [NULL],
	[" Check is test_dir/a2 under Versioning DET control "])

valgt(   [select upload_docs ('/DAV/versioning/test_dir/a2/', 10)], [0],
	[ " Upload docs to /DAV/versioning/test_dir/a2/ " ])

valgt(   [select DAV_SEARCH_ID ('/DAV/versioning/test_dir/test1.txt', 'R')], [0],
	[" Check /DAV/versioning/test_dir/test1.txt "])

valgt(   [select DAV_SEARCH_ID ('/DAV/versioning/test1.txt', 'R')], [0],
	[ " Check /DAV/versioning/test1.txt " ])

valgt(   [select DAV_SEARCH_ID ('/DAV/versioning/test2.txt', 'R')], [0],
	[ " Check /DAV/versioning/test2.txt " ])

valgt(   [select DAV_SEARCH_ID ('/DAV/versioning/test_dir/a2/test1.txt', 'R')], [0],
	[ " Check /DAV/versioning/test_dir/a2/test1.txt " ])

vallt(   [select DAV_SEARCH_ID ('/DAV/versioning/test_dir/testXX.txt', 'R')], [0],
	[ " Check /DAV/versioning/test_dir/testXX.txt " ])

valgt(   [select upload_doc ('/DAV/versioning/test2-1.txt', 'hello')], [0],
	[ " upload /DAV/versioning/test2-1.txt " ])
valgt(   [select upload_doc ('/DAV/versioning/test2-1.txt', 'hello')], [0],
	[ " second upload /DAV/versioning/test2-1.txt " ])
valgt(   [select DAV_SEARCH_ID ('/DAV/versioning/test2-1.txt', 'R')], [0],
	[ " check /DAV/versioning/test2-1.txt " ])

ECHO BOTH "Checking versioning, Pass 1 ...\n";
valgt(  [select upload_doc ('/DAV/versioning/file0.txt', 'content of file1.txt, version 1')], [0],
	[ " upload initial version of file0.txt "])
val(    [select RES_STATUS from WS.WS.SYS_DAV_RES where RES_FULL_PATH =  '/DAV/versioning/file0.txt'], ['AV'],
	[ " check status of file0.txt "])
val(    [select RV_ID from WS.WS.SYS_DAV_RES_VERSION where RV_RES_ID = DAV_SEARCH_ID ('/DAV/versioning/file0.txt', 'R')], [1],
	[ " check version of file0.txt "])


ECHO BOTH "Checking versioning, Pass 2 ...\n";

valgt(  [select upload_doc ('/DAV/versioning/file1.txt', 'content of file1.txt, version 1')], [0],
	[ " upload initial version of file1.txt "])
valgt(  [select upload_doc ('/DAV/versioning/file1.txt', 'content of file1.txt, version 2')], [0],
	[ " upload second version of file1.txt "])
valgt(  [select upload_doc ('/DAV/versioning/file1.txt', 'content of file1.txt, version 3')], [0],
	[ " upload third version of file1.txt "])
valgt(  [select upload_doc ('/DAV/versioning/file1.txt', 'content of file1.txt, version 4')], [0],
	[ " upload 4th version of file1.txt "])
valgt(  [select upload_doc ('/DAV/versioning/file1.txt', 'content of file1.txt, version 5')], [0],
	[ " upload 5th version of file1.txt "])
val(	[select get_doc ('/DAV/versioning/file1.txt')], ['content of file1.txt, version 5'],
	[ " check last version of file1.txt "])
val(	[select get_doc_v ('/DAV/versioning/file1.txt', 5)], ['content of file1.txt, version 5'],
	[ " check 5th version of file1.txt "])
val(	[select get_doc_v ('/DAV/versioning/file1.txt', 4)], ['content of file1.txt, version 4'],
	[ " check 4th version of file1.txt "])
val(	[select get_doc_v ('/DAV/versioning/file1.txt', 3)], ['content of file1.txt, version 3'],
	[ " check third version of file1.txt "])
val(	[select get_doc_v ('/DAV/versioning/file1.txt', 2)], ['content of file1.txt, version 2'],
	[ " check second version of file1.txt "])
val(	[select get_doc_v ('/DAV/versioning/file1.txt', 1)], ['content of file1.txt, version 1'],
	[ " check first version of file1.txt "])
val(	[select get_doc_v ('/DAV/versioning/file1.txt', 10)], [NULL],
	[ " check non-existent version of file1.txt "])
val(	[select get_doc_v ('/DAV/versioning/file1.txt', -1)], [NULL],
	[ " check non-existent version of file1.txt "])
valgt(	[select DB.DBA.DAV_DELETE ('/DAV/versioning/file1.txt', 1, 'dav','dav')], [0],
	[ " delete /DAV/versioning/file1.txt file "])

valgt(  [select upload_doc ('/DAV/versioning/test_dir/a2/file1.txt', 'content of file1.txt, version 1')], [0],
	[ " upload initial version of test_dir/a2/file1.txt "])
valgt(  [select upload_doc ('/DAV/versioning/test_dir/a2/file1.txt', 'content of file1.txt, version 2')], [0],
	[ " upload second version of test_dir/a2/file1.txt "])
valgt(  [select upload_doc ('/DAV/versioning/test_dir/a2/file1.txt', 'content of file1.txt, version 3')], [0],
	[ " upload third version of test_dir/a2/file1.txt "])
valgt(  [select upload_doc ('/DAV/versioning/test_dir/a2/file1.txt', 'content of file1.txt, version 4')], [0],
	[ " upload 4th version of test_dir/a2/file1.txt "])
valgt(  [select upload_doc ('/DAV/versioning/test_dir/a2/file1.txt', 'content of file1.txt, version 5')], [0],
	[ " upload 5th version of test_dir/a2/file1.txt "])

val(	[select get_doc ('/DAV/versioning/test_dir/a2/file1.txt')], ['content of file1.txt, version 5'],
	[ " check last version of test_dir/a2/file1.txt "])
val(	[select get_doc_v ('/DAV/versioning/test_dir/a2/file1.txt', 5)], [NULL],
	[ " check 5th version of test_dir/a2/file1.txt "])
val(	[select get_doc_v ('/DAV/versioning/test_dir/a2/file1.txt', 4)], [NULL],
	[ " check 4th version of test_dir/a2/file1.txt "])
val(	[select get_doc_v ('/DAV/versioning/test_dir/a2/file1.txt', 3)], [NULL],
	[ " check third version of test_dir/a2/file1.txt "])
val(	[select get_doc_v ('/DAV/versioning/test_dir/a2/file1.txt', 2)], [NULL],
	[ " check second version of test_dir/a2/file1.txt "])
val(	[select get_doc_v ('/DAV/versioning/test_dir/a2/file1.txt', 1)], [NULL],
	[ " check first version of test_dir/a2/file1.txt "])
val(	[select get_doc_v ('/DAV/versioning/test_dir/a2/file1.txt', 10)], [NULL],
	[ " check non-existent version of test_dir/a2/file1.txt "])
val(	[select get_doc_v ('/DAV/versioning/test_dir/a2/file1.txt', -1)], [NULL],
	[ " check non-existent version of test_dir/a2/file1.txt "])

ECHO BOTH "Checking versioning, Pass 3 ...\n";

valgt(  [select DB.DBA.DAV_COL_CREATE ('/DAV/vers/', '110100000R', 'dav', 'administrators', 'dav', 'dav')], [0],
	[ " create folder for versions browsing " ])
ok(	[update WS.WS.SYS_DAV_COL set COL_DET = 'Versioning' where COL_ID = DAV_SEARCH_ID ('/DAV/vers/', 'C')],
	[ " set DET " ])
val(	[select count (*) from WS.WS.SYS_DAV_COL where COL_DET = 'Versioning' and COL_ID = DAV_SEARCH_ID ('/DAV/vers/', 'C')], [1],
	[ " check DET field "])

ok(	[select DAV_PROP_SET ('/DAV/vers/', 'virt:Versioning-Collection', '/DAV/versioning/', 'dav', 'dav')],
	[ " set virt:Version-Collection " ])
ok(	[select DAV_PROP_SET ('/DAV/versioning/', 'virt:Versioning-History', '/DAV/vers/', 'dav', 'dav')],
	[ " set virt:Version-History " ])

valgt(  [select upload_doc ('/DAV/versioning/file1.txt', 'content of file1.txt, version 1')], [0],
	[ " upload initial version of file1.txt "])
valgt(  [select upload_doc ('/DAV/versioning/file1.txt', 'content of file1.txt, version 2')], [0],
	[ " upload second version of file1.txt "])
valgt(  [select upload_doc ('/DAV/versioning/file1.txt', 'content of file1.txt, version 3')], [0],
	[ " upload third version of file1.txt "])
valgt(  [select upload_doc ('/DAV/versioning/file1.txt', 'content of file1.txt, version 4')], [0],
	[ " upload 4th version of file1.txt "])
valgt(  [select upload_doc ('/DAV/versioning/file1.txt', 'content of file1.txt, version 5')], [0],
	[ " upload 5th version of file1.txt "])

val(	[select get_doc_v_2 ('/DAV/vers', 'file1.txt', 5)], ['content of file1.txt, version 5'],
	[ " check last version of file1.txt by DET "])
val(	[select get_doc_v_2 ('/DAV/vers', 'file1.txt', 4)], ['content of file1.txt, version 4'],
	[ " check 4th version of file1.txt by DET "])
val(	[select get_doc_v_2 ('/DAV/vers', 'file1.txt', 3)], ['content of file1.txt, version 3'],
	[ " check third version of file1.txt by DET "])
val(	[select get_doc_v_2 ('/DAV/vers', 'file1.txt', 2)], ['content of file1.txt, version 2'],
	[ " check second version of file1.txt by DET "])
val(	[select get_doc_v_2 ('/DAV/vers', 'file1.txt', 1)], ['content of file1.txt, version 1'],
	[ " check first version of file1.txt by DET "])
val(	[select get_doc_v_2 ('/DAV/vers', 'file1.txt', 10)], [NULL],
	[ " check non-existing version of file1.txt by DET "])

valgt(  [select DB.DBA.DAV_COL_CREATE ('/DAV/versioning/VVC/', '110100000R', 'dav', 'administrators', 'dav', 'dav')], [0],
	[ " create folder for versions browsing " ])
ok(	[select DAV_PROP_REMOVE ('/DAV/versioning/', 'virt:Versioning-History', 'dav', 'dav')],
	[ " remove virt:Version-History " ])

valgt(  [select DB.DBA.DAV_SET_VERSIONING_CONTROL ('/DAV/versioning/', NULL, 'A', 'dav', 'dav')], [0],
	[ " set versioning control " ])
val(	[select count (*) from WS.WS.SYS_DAV_COL where COL_DET = 'Versioning' and COL_ID = DAV_SEARCH_ID ('/DAV/versioning/VVC/', 'C')], [1],
	[ " check DET field "])
val(	[select get_doc_v_2 ('/DAV/versioning/VVC', 'file1.txt', 5)], ['content of file1.txt, version 5'],
	[ " check last version of file1.txt by DET "])
val(	[select get_doc_v_2 ('/DAV/versioning/VVC', 'file1.txt', 4)], ['content of file1.txt, version 4'],
	[ " check 4th version of file1.txt by DET "])
val(	[select get_doc_v_2 ('/DAV/versioning/VVC', 'file1.txt', 3)], ['content of file1.txt, version 3'],
	[ " check third version of file1.txt by DET "])
val(	[select get_doc_v_2 ('/DAV/versioning/VVC', 'file1.txt', 2)], ['content of file1.txt, version 2'],
	[ " check second version of file1.txt by DET "])
val(	[select get_doc_v_2 ('/DAV/versioning/VVC', 'file1.txt', 1)], ['content of file1.txt, version 1'],
	[ " check first version of file1.txt by DET "])
val(	[select get_doc_v_2 ('/DAV/versioning/VVC', 'file1.txt', 10)], [NULL],
	[ " check non-existing version of file1.txt by DET "])

val(	[select xpath_eval ('count (//version)', xtree_doc (get_doc_v_2 ('/DAV/versioning/VVC', 'file1.txt', 'history.xml')))], [5],
	[ " check number of versions in history "])

val(	[select check_file ('/DAV/versioning/VVC/file1.txt/last')], ['found'],
	[ " check of last version reference "])
val(	[select check_file ('/DAV/versioning/VVC/file1.txt/100')], ['not found'],
	[ " check of absent file "])
val(	[select select_from_dir ('/DAV/versioning/VVC/file1.txt/' , 'last')], ['found'],
	[ " check of last version reference by DAV_DIR_LIST "])
val(	[select select_from_dir ('/DAV/versioning/VVC/file1.txt/' , '100')], ['not found'],
	[ " check of non-existing version reference by DAV_DIR_LIST "])
val(	[select get_doc_v_2 ('/DAV/versioning/VVC', 'file1.txt', 'last')], ['content of file1.txt, version 5'],
	[ " check last version of file1.txt by DET "])
val(    [select mv ('/DAV/versioning/VVC/file1.txt/last', '/DAV/versioning/VVC/file1-mv1.txt')],[1],
	[ " move file file1 to file-mv1.txt "])
val(	[select get_doc ('/DAV/versioning/file1-mv1.txt')], ['content of file1.txt, version 5'],
	[ " check last version of file1-mv1.txt by DET "])
val(	[select get_doc_v_2 ('/DAV/versioning/VVC', 'file1-mv1.txt', 5)], ['content of file1.txt, version 5'],
	[ " check last version of file1-mv1.txt by DET "])
val(	[select get_doc_v_2 ('/DAV/versioning/VVC', 'file1-mv1.txt', 4)], ['content of file1.txt, version 4'],
	[ " check 4th version of file1-mv1.txt by DET "])
val(	[select get_doc_v_2 ('/DAV/versioning/VVC', 'file1-mv1.txt', 3)], ['content of file1.txt, version 3'],
	[ " check third version of file1-mv1.txt by DET "])
val(	[select get_doc_v_2 ('/DAV/versioning/VVC', 'file1-mv1.txt', 2)], ['content of file1.txt, version 2'],
	[ " check second version of file1-mv1.txt by DET "])
val(	[select get_doc_v_2 ('/DAV/versioning/VVC', 'file1-mv1.txt', 1)], ['content of file1.txt, version 1'],
	[ " check first version of file1-mv1.txt by DET "])
val(	[select check_file ('/DAV/versioning/file1-mv1.txt')], ['found'],
	[ " check file1-mv1.txt "])
val(	[select check_file ('/DAV/versioning/file1.txt')], ['not found'],
	[ " check is file1.txt removed "])
vallt(  [select mv ('/DAV/versioning/VVC/file2.txt/last', '/DAV/versioning/VVC/file1-mv1.txt')],[1],
	[ " move file file2 to file1-mv1.txt "])
vallt(    [select mv ('/DAV/versioning/VVC/file2.txt/last', '/DAV/versioning/VVC/file1-mv1.txt', 1)],[1],
	[ " move file file2 to file1-mv1.txt (overwrt = 1) "])
vallt(  [select mv ('/DAV/versioning/VVC/test10.txt/last', '/DAV/versioning/VVC/file1-mv1.txt')],[1],
	[ " move file test10 to file1-mv1.txt (overwrt = 0) "])
val(    [select mv ('/DAV/versioning/VVC/test10.txt/last', '/DAV/versioning/VVC/file1-mv1.txt', 1)],[1],
	[ " move file test10 to file1-mv1.txt (overwrt = 1) "])
val(    [select get_doc ('/DAV/versioning/file1-mv1.txt')],['hello world! - 10'],
	[ " check content of file1-mv1.txt "])
val(    [select get_doc_v ('/DAV/versioning/file1-mv1.txt', 1)],['hello world! - 10'],
	[ " check content of file1-mv1.txt "])
valgt(  [select upload_doc ('/DAV/versioning/file1-mv1.txt', 'content of file1-mv1.txt, version 2')], [0],
	[ " upload second version of file1.txt "])
valgt(  [select upload_doc ('/DAV/versioning/file1-mv1.txt', 'content of file1-mv1.txt, version 3')], [0],
	[ " upload 3th version of file1.txt "])

valgt(   [select DB.DBA.DAV_COL_CREATE ('/DAV/versioning/Attic/', '110100000R', 'dav', 'administrators', 'dav', 'dav')], [0],
	[" Create Attic collection: "])
ok(	[select DAV_PROP_SET ('/DAV/versioning/VVC/', 'virt:Versioning-Attic', '/DAV/versioning/Attic/', 'dav', 'dav')],
	[ " set virt:Versioning-Attic for VVC folder " ])

val(	[select DAV_DELETE ('/DAV/versioning/VVC/file1-mv1.txt/last', 0, 'dav', 'dav')], [1],
	[ " delete resource file1-mv1.txt "])
val(    [select check_file ('/DAV/versioning/file1-mv1.txt')], ['not found'],
        [ " check is file1-mv1.txt removed "])
val(    [select check_file ('/DAV/versioning/Attic/file1-mv1.txt')], ['found'],
        [ " check is file1-mv1.txt in Attic "])

valgt(	[select DAV_RES_RESTORE ('/DAV/versioning/VVC/', 'file1-mv1.txt', 'dav', 'dav')], [0],
	[ " restoring from Attic " ])
val(	[select get_doc ('/DAV/versioning/file1-mv1.txt')], ['content of file1-mv1.txt, version 3'],
	[ " check current content of file1-mv1.txt "])
val(	[select get_doc_v_2 ('/DAV/versioning/VVC', 'file1-mv1.txt', 3)], ['content of file1-mv1.txt, version 3'],
	[ " check last version of file1-mv1.txt by DET "])
val(	[select get_doc_v_2 ('/DAV/versioning/VVC', 'file1-mv1.txt', 2)], ['content of file1-mv1.txt, version 2'],
	[ " check second version of file1-mv1.txt by DET "])
val(	[select get_doc_v_2 ('/DAV/versioning/VVC', 'file1-mv1.txt', 1)], ['hello world! - 10'],
	[ " check first version of file1-mv1.txt by DET "])

val(	[select max (rd_from_id) from ws.ws.sys_dav_res_diff, (select rd_res_id, max (rd_to_id) as max_rd_res_id from ws.ws.sys_dav_res_diff group by rd_res_id) a where a.rd_res_id = rd_res_id and max_rd_res_id = rd_to_id and rd_res_id = DAV_SEARCH_ID ('/DAV/versioning/file1-mv1.txt', 'R')], [0],
	[ " check from_id for latest version "])


valgt(  [select upload_doc ('/DAV/versioning/file1-mv1.txt', 'content of file1-mv1.txt, version 4, \n new line1\n new line2\n')], [0],
	[ " upload 4th version of file1.txt with several lines "])
valgt(  [select upload_doc ('/DAV/versioning/file1-mv1.txt', 'content of file1-mv1.txt, version 5, \n new line1\n new line3\n')], [0],
	[ " upload 5th version of file1.txt with several lines "])
valgt(  [select upload_doc ('/DAV/versioning/file1-mv1.txt', 'content of file1-mv1.txt, version 6, \n new line1\n new line3\n new line4\nnew line5')], [0],
	[ " upload 6th version of file1.txt with several lines "])
val( 	[select get_doc_v ('/DAV/versioning/file1-mv1.txt', 4)], ['content of file1-mv1.txt, version 4, \n new line1\n new line2\n'],
	[ " 4th version of file1.txt with several lines "])
val(  	[select get_doc_v ('/DAV/versioning/file1-mv1.txt', 5)], ['content of file1-mv1.txt, version 5, \n new line1\n new line3\n'],
	[ " 5th version of file1.txt with several lines "])
val(  	[select get_doc_v ('/DAV/versioning/file1-mv1.txt', 6)], ['content of file1-mv1.txt, version 6, \n new line1\n new line3\n new line4\nnew line5'],
	[ " 6th version of file1.txt with several lines "])

val(	[select get_prop('/DAV/versioning/file1-mv1.txt', 'DAV:checked-in')],
	['/DAV/versioning/VVC/file1-mv1.txt/last'],
	[ " DAV:checked-in property" ])

val(	[select DAV_HIDE_ERROR(get_prop('/DAV/versioning/file1-mv1.txt', 'DAV:checked-out'))],
	[NULL],
	[ " DAV:checked-out property" ])
val(	[select get_prop('/DAV/versioning/file1-mv1.txt', 'DAV:auto-version')],
	['DAV:checkout-checkin'],
	[ " DAV:checkout-checkin property" ])


create procedure make_long_doc (in n int:=10000)
{
  declare line varchar;
  declare ses any;
  ses := string_output();
  line := 'hell\n';
  while (n > 0)
    {
      http (line, ses);
      n := n - 1;
    }
  return string_output_string (ses);
}
;

valgt(  [select upload_doc ('/DAV/versioning/upload_test.txt', make_long_doc ())], [0],
	[ " upload long doc 1 "])
valgt(  [select upload_doc ('/DAV/versioning/upload_test.txt', make_long_doc ())], [0],
	[ " upload long doc 2 "])
valgt(  [select upload_doc ('/DAV/versioning/upload_test.txt', make_long_doc ())], [0],
	[ " upload long doc 3 "])

valgt(  [select upload_doc ('/DAV/versioning/upload_test2.txt', make_long_doc ())], [0],
	[ " upload long doc 1 "])
valgt(  [select upload_doc ('/DAV/versioning/upload_test2.txt', make_long_doc ())], [0],
	[ " upload long doc 2 "])
valgt(  [select upload_doc ('/DAV/versioning/upload_test2.txt', make_long_doc ())], [0],
	[ " upload long doc 3 "])
val(	[select get_prop('/DAV/versioning/upload_test.txt', 'DAV:checked-in')],
	['/DAV/versioning/VVC/upload_test.txt/last'],
	[ " DAV:checked-in property" ])

val(	[select DAV_HIDE_ERROR(get_prop('/DAV/versioning/upload_test.txt', 'DAV:checked-out'))],
	[NULL],
	[ " DAV:checked-out property" ])

val(	[select get_prop('/DAV/versioning/upload_test2.txt', 'DAV:checked-in')],
	['/DAV/versioning/VVC/upload_test2.txt/last'],
	[ " DAV:checked-in property" ])

val(	[select  DAV_HIDE_ERROR(get_prop('/DAV/versioning/upload_test2.txt', 'DAV:checked-out'))],
	[NULL],
	[ " DAV:checked-out property" ])
val(	[select get_prop('/DAV/versioning/upload_test.txt', 'DAV:auto-version')],
	['DAV:checkout-checkin'],
	[ " DAV:checkout-checkin property" ])
val(	[select get_prop('/DAV/versioning/upload_test2.txt', 'DAV:auto-version')],
	['DAV:checkout-checkin'],
	[ " DAV:checkout-checkin property" ])

val(	[select get_prop('/DAV/versioning/upload_test2.txt', 'DAV:version-history')],
	['/DAV/versioning/VVC/upload_test2.txt/history.xml'],
	[ " DAV:version-history property" ])
val(	[select get_prop('/DAV/versioning/file1-mv1.txt', 'DAV:version-history')],
	['/DAV/versioning/VVC/file1-mv1.txt/history.xml'],
	[ " DAV:version-history property of file1-mv1.txt" ])


ifdef([enable_mkworkspace_test], [
vallt(	[select get_prop('/DAV/versioning/upload_test2.txt', 'DAV:workspace')],
	[0],
	[ " DAV:workspace property" ])
], [])

val(	[select get_prop('/DAV/versioning/upload_test2.txt', 'DAV:author')],
	['dav'],
	[ " DAV:author property" ])
val(	[select get_prop('/DAV/versioning/file1-mv1.txt', 'DAV:author')],
	['dav'],
	[ " DAV:author of file1-mv1.txt" ])


-- history
val(	[select get_prop('/DAV/versioning/VVC/upload_test2.txt/history.xml', 'DAV:root-version')],
	['<D:href>/DAV/versioning/VVC/upload_test2.txt/1</D:href>'],
	[ " DAV:root-version property" ])
val(	[select get_prop('/DAV/versioning/VVC/file1-mv1.txt/history.xml', 'DAV:version-set')],
	['<D:href>/DAV/versioning/VVC/file1-mv1.txt/1</D:href><D:href>/DAV/versioning/VVC/file1-mv1.txt/2</D:href><D:href>/DAV/versioning/VVC/file1-mv1.txt/3</D:href><D:href>/DAV/versioning/VVC/file1-mv1.txt/4</D:href><D:href>/DAV/versioning/VVC/file1-mv1.txt/5</D:href><D:href>/DAV/versioning/VVC/file1-mv1.txt/6</D:href>'],
	[ " DAV:version-set property" ])


ifdef([enable_mkworkspace_test], [
val(	[select DAV_MKWORKSPACE('/DAV/versioning/file1-mv1.txt')], ["/DAV/versioning/workspace!/file1-mv1.txt"],
	[ " DAV_MKWORKSPACE /DAV/versioning/file1-mv1.txt" ])
val(	[select get_prop('/DAV/versioning/file1-mv1.txt', 'DAV:workspace')],
	['/DAV/versioning/workspace!/file1-mv1.txt'],
	[ " DAV:workspace property" ])
val(	[select DAV_MKWORKSPACE('/DAV/versioning/test11.txt')], ["/DAV/versioning/workspace!/test11.txt"],
	[ " DAV_MKWORKSPACE /DAV/versioning/test11.txt" ])
val(	[select get_prop('/DAV/versioning/test11.txt', 'DAV:workspace')], ["/DAV/versioning/workspace!/test11.txt"],
	[ " DAV:workspace property /DAV/versioning/test11.txt" ])
val(	[select DAV_MKWORKSPACE('/DAV/versioning/test3.txt')], ["/DAV/versioning/workspace!/test3.txt"],
	[ " DAV_MKWORKSPACE /DAV/versioning/test3.txt" ])
val(	[select get_prop('/DAV/versioning/test3.txt', 'DAV:workspace')], ["/DAV/versioning/workspace!/test3.txt"],
	[ " DAV:workspace property /DAV/versioning/test3.txt" ])
], [])


-- checkout, update, checkin
ECHO BOTH "Checking versioning, Pass 4 ... [checkout, checkin]\n";
val(	[select COL_AUTO_VERSIONING from WS.WS.SYS_DAV_COL where COL_ID = DAV_SEARCH_ID ('/DAV/versioning/', 'C')],
	[A],
	[" COL_AUTO_VERSIONING is on, this must not spoil manual checkout and checkin "])
valgt(	[select DAV_CHECKOUT('/DAV/versioning/test11.txt', 'dav', 'dav')], [0],
	[" checking /DAV/versioning/test11.txt out"])
val(	[select get_prop ('/DAV/versioning/test11.txt', 'DAV:checked-out')], ["/DAV/versioning/VVC/test11.txt/last"],
	[" DAV:checked-out property /DAV/versioning/test11.txt "])
val(	[select  DAV_HIDE_ERROR(get_prop ('/DAV/versioning/test11.txt', 'DAV:checked-in'))], [NULL],
	[" DAV:checked-in after CHECKOUT"])
ifdef([enable_mkworkspace_test], [
val(	[select check_file ('/DAV/versioning/workspace!/test11.txt')], ["found"],
	[" check workspace copy "])
], [])
valgt(  [select upload_doc ('/DAV/versioning/test11.txt', 'content of test11.txt in workspace')], [0],
	[" upload new content of file [test11.txt] "])
val(	[select get_doc ('/DAV/versioning/VVC/test11.txt/last')],['hello world! - 11'],
	[" check content of test11.txt (last VR before CHECKIN) "])
valgt(	[select DAV_CHECKIN('/DAV/versioning/test11.txt', 'dav', 'dav')], [0],
	[" checking /DAV/versioning/test11.txt in"])
val(	[select get_doc ('/DAV/versioning/test11.txt')],['content of test11.txt in workspace'],
	[" check content of test11.txt "])
val(	[select get_doc ('/DAV/versioning/VVC/test11.txt/last')],['content of test11.txt in workspace'],
	[" check content of test11.txt (last VR after CHECKIN) "])
val(	[select  DAV_HIDE_ERROR(get_prop ('/DAV/versioning/test11.txt', 'DAV:checked-out'))], [NULL],
	[" DAV:checked-out property /DAV/versioning/test11.txt after CHECKIN"])
val(	[select get_prop ('/DAV/versioning/test11.txt', 'DAV:checked-in')], ["/DAV/versioning/VVC/test11.txt/last"],
	[" DAV:checked-in after CHECKIN"])
val(	[select check_file ('/DAV/versioning/workspace!/test11.txt')], ["not found"],
	[" check workspace copy "])
ifdef([enable_mkworkspace_test], [
val(	[select get_prop ('/DAV/versioning/test11.txt', 'DAV:workspace')], [-11],
	[" DAV:workspace after CHECKIN"])
], [])

-- checkin without checkout

val(	[select  DAV_HIDE_ERROR(DAV_CHECKIN('/DAV/versioning/test11.txt', 'dav', 'dav'))], [NULL],
	[" checking /DAV/versioning/test11.txt in with checkout"])
val(	[select get_doc ('/DAV/versioning/test11.txt')],['content of test11.txt in workspace'],
	[" check content of test11.txt "])
val(	[select  DAV_HIDE_ERROR(get_prop ('/DAV/versioning/test11.txt', 'DAV:checked-out'))], [NULL],
	[" DAV:checked-out property /DAV/versioning/test11.txt after CHECKIN"])
val(	[select get_prop ('/DAV/versioning/test11.txt', 'DAV:checked-in')], ["/DAV/versioning/VVC/test11.txt/last"],
	[" DAV:checked-in after CHECKIN"])

-- auto version:  DAV:checkout-unlocked-checkin
ECHO BOTH "Checking versioning, Pass 5... auto-version: DAV:checkout-unlocked-checkin\n";
ok(	[update WS.WS.SYS_DAV_COL set COL_AUTO_VERSIONING = 'B' where COL_ID = DAV_SEARCH_ID ('/DAV/versioning/' ,'C') ],
	[" set COL_AUTO_VERSION = B "])
ok(	[select DAV_PROP_SET_INT (RES_FULL_PATH, 'DAV:auto-version', 'DAV:checkout-unlocked-checkin', 'dav', 'dav', 1,1,1) from WS.WS.SYS_DAV_RES where RES_COL = DAV_SEARCH_ID ('/DAV/versioning/', 'C')],
	[" set DAV:auto-version to DAV:checkout-unlocked-checkin "])
val(	[select get_prop ('/DAV/versioning/test11.txt', 'DAV:auto-version')], ["DAV:checkout-unlocked-checkin"],
	[" DAV:auto-version prop for test11.txt "])

-- without lock must be equal to DAV:checkout-checkin
valgt(  [select upload_doc ('/DAV/versioning/test11.txt', 'content of test11.txt #1013')], [0],
	[" upload new content of file [test11.txt] "])
ifdef([enable_mkworkspace_test], [
val(	[select check_file ('/DAV/versioning/workspace!/test11.txt')], ["not found"],
	[" check workspace copy "])
], [])
val(	[select get_doc ('/DAV/versioning/test11.txt')],['content of test11.txt #1013'],
	[" check content of test11.txt "])
val(	[select  DAV_HIDE_ERROR(get_prop ('/DAV/versioning/test11.txt', 'DAV:checked-out'))], [NULL],
	[" DAV:checked-out property /DAV/versioning/test11.txt after implicit CHECKIN"])
val(	[select get_prop ('/DAV/versioning/test11.txt', 'DAV:checked-in')], ["/DAV/versioning/VVC/test11.txt/last"],
	[" DAV:checked-in after implicit CHECKIN"])
ifdef([enable_mkworkspace_test], [
val(	[select check_file ('/DAV/versioning/workspace!/test11.txt')], ["not found"],
	[" check workspace copy "])
val(	[select get_prop ('/DAV/versioning/test11.txt', 'DAV:workspace')], [-11],
	[" DAV:workspace after implicit CHECKIN"])
], [])

--with lock
valgt(  [select lock_res ('/DAV/versioning/test11.txt')], [0],
	[ " lock test11.txt" ])
valgt(  [select upload_doc ('/DAV/versioning/test11.txt', 'content of test11.txt #1014')], [0],
	[" upload new content of file [test11.txt] "])
ifdef([enable_mkworkspace_test], [
val(	[select check_file ('/DAV/versioning/workspace!/test11.txt')], ["found"],
	[" check workspace copy "])
], [])
val(	[select get_prop ('/DAV/versioning/test11.txt', 'DAV:checked-out')], ["/DAV/versioning/VVC/test11.txt/last"],
	[" DAV:checked-out property test11.txt "])
val(	[select isstring (get_prop ('/DAV/versioning/test11.txt', 'DAV:checked-in'))], [0],
	[" isstring (DAV:checked-in) after implicit CHECKOUT"])
val(	[select get_doc ('/DAV/versioning/VVC/test11.txt/last')],['content of test11.txt #1013'],
	[" check content of test11.txt VR before CHECKIN "])
valgt(	[select DAV_CHECKIN('/DAV/versioning/test11.txt', 'dav', 'dav')], [0],
	[" checking /DAV/versioning/test11.txt in"])
val(	[select get_doc ('/DAV/versioning/test11.txt')],['content of test11.txt #1014'],
	[" check content of test11.txt "])
val(	[select get_doc ('/DAV/versioning/VVC/test11.txt/last')],['content of test11.txt #1014'],
	[" check content of test11.txt (last VR after CHECKIN)"])
val(	[select  DAV_HIDE_ERROR(get_prop ('/DAV/versioning/test11.txt', 'DAV:checked-out'))], [NULL],
	[" DAV:checked-out property /DAV/versioning/test11.txt after CHECKIN"])
val(	[select get_prop ('/DAV/versioning/test11.txt', 'DAV:checked-in')], ["/DAV/versioning/VVC/test11.txt/last"],
	[" DAV:checked-in after CHECKIN"])
ifdef([enable_mkworkspace_test], [
val(	[select check_file ('/DAV/versioning/workspace!/test11.txt')], ["not found"],
	[" check workspace copy "])
val(	[select get_prop ('/DAV/versioning/test11.txt', 'DAV:workspace')], [-11],
	[" DAV:workspace after CHECKIN"])
],[])
val(	[select count (*) from ws.ws.sys_dav_res_version where rv_res_id = dav_search_id ('/DAV/versioning/test11.txt', 'R')],
	[4],
	[" count of versions in ws.ws.sys_dav_res_version table "])

valgt(  [select unlock_res ('/DAV/versioning/test11.txt')], [0],
	[ " unlock test11.txt" ])

-- auto_version: DAV:checkout
ECHO BOTH "Checking versioning, Pass 6... auto-version: DAV:checkout\n";
ok(	[update WS.WS.SYS_DAV_COL set COL_AUTO_VERSIONING = 'C' where COL_ID = DAV_SEARCH_ID ('/DAV/versioning/' ,'C') ],
	[" set COL_AUTO_VERSION = C "])
ok(	[select DAV_PROP_SET_INT (RES_FULL_PATH, 'DAV:auto-version', 'DAV:checkout', 'dav', 'dav', 1,1,1) from WS.WS.SYS_DAV_RES where RES_COL = DAV_SEARCH_ID ('/DAV/versioning/', 'C')],
	[" set DAV:auto-version to DAV:checkout "])
valgt(  [select upload_doc ('/DAV/versioning/test11.txt', 'content of test11.txt #1015')], [0],
	[" upload new content of file [test11.txt] "])
ifdef([enable_mkworkspace_test], [
val(	[select check_file ('/DAV/versioning/workspace!/test11.txt')], ["found"],
	[" check workspace copy "])
], [])
val(	[select get_prop ('/DAV/versioning/test11.txt', 'DAV:checked-out')], ["/DAV/versioning/VVC/test11.txt/last"],
	[" DAV:checked-out property test11.txt "])
val(	[select isstring (get_prop ('/DAV/versioning/test11.txt', 'DAV:checked-in'))], [0],
	[" isstring (DAV:checked-in) after implicit CHECKOUT"])
val(	[select get_doc ('/DAV/versioning/VVC/test11.txt/last')],['content of test11.txt #1014'],
	[" check content of test11.txt (last VR before CHECKIN) "])
valgt(	[select DAV_CHECKIN('/DAV/versioning/test11.txt', 'dav', 'dav')], [0],
	[" checking /DAV/versioning/test11.txt in"])
val(	[select get_doc ('/DAV/versioning/test11.txt')],['content of test11.txt #1015'],
	[" check content of test11.txt "])
val(	[select get_doc ('/DAV/versioning/VVC/test11.txt/last')],['content of test11.txt #1015'],
	[" check content of test11.txt (last VR after CHECKIN) "])
val(	[select  DAV_HIDE_ERROR(get_prop ('/DAV/versioning/test11.txt', 'DAV:checked-out'))], [NULL],
	[" DAV:checked-out property /DAV/versioning/test11.txt after CHECKIN"])
val(	[select get_prop ('/DAV/versioning/test11.txt', 'DAV:checked-in')], ["/DAV/versioning/VVC/test11.txt/last"],
	[" DAV:checked-in after CHECKIN"])
ifdef([enable_mkworkspace_test], [
val(	[select check_file ('/DAV/versioning/workspace!/test11.txt')], ["not found"],
	[" check workspace copy "])
val(	[select get_prop ('/DAV/versioning/test11.txt', 'DAV:workspace')], [-11],
	[" DAV:workspace after CHECKIN"])
], [])
val(	[select count (*) from ws.ws.sys_dav_res_version where rv_res_id = dav_search_id ('/DAV/versioning/test11.txt', 'R')],
	[5],
	[" count of versions in ws.ws.sys_dav_res_version table "])


-- auto_version: DAV:locked-checkout
ECHO BOTH "Checking versioning, Pass 7... auto-version: DAV:locked-checkout\n";
ok(	[update WS.WS.SYS_DAV_COL set COL_AUTO_VERSIONING = 'D' where COL_ID = DAV_SEARCH_ID ('/DAV/versioning/' ,'C') ],
	[" set COL_AUTO_VERSION = D "])
ok(	[select DAV_PROP_SET_INT (RES_FULL_PATH, 'DAV:auto-version', 'DAV:locked-checkout', 'dav', 'dav', 1,1,1) from WS.WS.SYS_DAV_RES where RES_COL = DAV_SEARCH_ID ('/DAV/versioning/', 'C')],
	[" set DAV:auto-version to DAV:locked-checkout "])

-- no lock
vallt(  [select upload_doc ('/DAV/versioning/test11.txt', 'content of test11.txt #1016')], [0],
	[" upload new content of file [test11.txt] "])
ifdef([enable_mkworkspace_test], [
val(	[select check_file ('/DAV/versioning/workspace!/test11.txt')], ["not found"],
	[" check workspace copy "])
], [])
val(	[select get_doc ('/DAV/versioning/test11.txt')],['content of test11.txt #1015'],
	[" check content of test11.txt "])
val(	[select  DAV_HIDE_ERROR(get_prop ('/DAV/versioning/test11.txt', 'DAV:checked-out'))], [NULL],
	[" DAV:checked-out property /DAV/versioning/test11.txt after implicit CHECKIN"])
val(	[select get_prop ('/DAV/versioning/test11.txt', 'DAV:checked-in')], ["/DAV/versioning/VVC/test11.txt/last"],
	[" DAV:checked-in after implicit CHECKIN"])
val(	[select check_file ('/DAV/versioning/workspace!/test11.txt')], ["not found"],
	[" check workspace copy "])
ifdef([enable_mkworkspace_test], [
val(	[select get_prop ('/DAV/versioning/test11.txt', 'DAV:workspace')], [-11],
	[" DAV:workspace after implicit CHECKIN"])
], [])
val(	[select count (*) from ws.ws.sys_dav_res_version where rv_res_id = dav_search_id ('/DAV/versioning/test11.txt', 'R')],
	[5],
	[" count of versions in ws.ws.sys_dav_res_version table "])


-- with lock
valgt(  [select lock_res ('/DAV/versioning/test11.txt')], [0],
	[ " lock test11.txt" ])
valgt(  [select upload_doc ('/DAV/versioning/test11.txt', 'content of test11.txt #1017')], [0],
	[" upload new content of file [test11.txt] "])
ifdef([enable_mkworkspace_test], [
val(	[select check_file ('/DAV/versioning/workspace!/test11.txt')], ["found"],
	[" check workspace copy "])
], [])
val(	[select get_prop ('/DAV/versioning/test11.txt', 'DAV:checked-out')], ["/DAV/versioning/VVC/test11.txt/last"],
	[" DAV:checked-out property test11.txt "])
val(	[select isstring (get_prop ('/DAV/versioning/test11.txt', 'DAV:checked-in'))], [0],
	[" isstring (DAV:checked-in) after implicit CHECKOUT"])
valgt(	[select unlock_res('/DAV/versioning/test11.txt')], [0],
	[" unlock resource "])
val(	[select get_doc ('/DAV/versioning/test11.txt')],['content of test11.txt #1017'],
	[" check content of test11.txt after implicit CHECKIN "])
val(	[select  DAV_HIDE_ERROR(get_prop ('/DAV/versioning/test11.txt', 'DAV:checked-out'))], [NULL],
	[" DAV:checked-out property /DAV/versioning/test11.txt  after implicit CHECKIN"])
val(	[select get_prop ('/DAV/versioning/test11.txt', 'DAV:checked-in')], ["/DAV/versioning/VVC/test11.txt/last"],
	[" DAV:checked-in after implicit CHECKIN"])
val(	[select check_file ('/DAV/versioning/workspace!/test11.txt')], ["not found"],
	[" check workspace copy "])
ifdef([enable_mkworkspace_test], [
val(	[select get_prop ('/DAV/versioning/test11.txt', 'DAV:workspace')], [-11],
	[" DAV:workspace after implicit CHECKIN"])
], [])
val(	[select count (*) from ws.ws.sys_dav_res_version where rv_res_id = dav_search_id ('/DAV/versioning/test11.txt', 'R')],
	[6],
	[" count of versions in ws.ws.sys_dav_res_version table "])

-- no lock, new file
valgt(  [select upload_doc ('/DAV/versioning/newfile.txt', 'content of newfile.txt #1017')], [0],
	[" upload new content of file [newfile.txt] "])
val(	[select get_prop ('/DAV/versioning/newfile.txt', 'DAV:checked-in')], ["/DAV/versioning/VVC/newfile.txt/last"],
	[" DAV:checked-in property newfile.txt "])
val(	[select isstring (get_prop ('/DAV/versioning/newfile.txt', 'DAV:checked-out'))], [0],
	[" isstring (DAV:checked-out) "])
val(	[select get_doc ('/DAV/versioning/newfile.txt')],['content of newfile.txt #1017'],
	[" check content of newfile.txt "])
val(	[select  DAV_HIDE_ERROR(get_prop ('/DAV/versioning/newfile.txt', 'DAV:checked-out'))], [NULL],
	[" DAV:checked-out property /DAV/versioning/newfile.txt "])
val(	[select count (*) from ws.ws.sys_dav_res_version where rv_res_id = dav_search_id ('/DAV/versioning/newfile.txt', 'R')],
	[1],
	[" count of versions in ws.ws.sys_dav_res_version table "])

ok(   [DB.DBA.DAV_DELETE ('/DAV/versioning2/', 1, 'dav','dav')],
	[" Deleting second versioning collection"] )
valgt(   [select DB.DBA.DAV_COL_CREATE ('/DAV/versioning2/', '110100000R', 'dav', 'administrators', 'dav', 'dav')], [0],
	[" Create test collection: "])
valgt(   [select upload_docs ('/DAV/versioning2/', 20)], [0],
	[ " Upload docs to collection /DAV/versioning2/ "])

valgt(  [select DB.DBA.DAV_VERSION_CONTROL ('/DAV/versioning2/test12.txt', 'dav', 'dav')], [0],
	[ " set versioning control on text2.txt " ])
val(	[select COL_DET from WS.WS.SYS_DAV_COL where COL_ID = DAV_SEARCH_ID ('/DAV/versioning2/VVC/', 'C')], [Versioning],
	[ " check COL_DET column "])
val(	[select get_prop ('/DAV/versioning2/test12.txt', 'DAV:checked-in')],
	["/DAV/versioning2/VVC/test12.txt/last"],
	[" check DAV:checked-in property of test12.txt "])
val(	[select  DAV_HIDE_ERROR(get_prop ('/DAV/versioning2/test12.txt', 'DAV:checked-out'))], [NULL],
	[" check DAV:checked-out property of test12.txt "])
val(	[select  DAV_HIDE_ERROR(get_prop ('/DAV/versioning2/test11.txt', 'DAV:checked-in'))], [NULL],
	[" check DAV:checked-in property of test11.txt "])
val(	[select  DAV_HIDE_ERROR(get_prop ('/DAV/versioning2/test11.txt', 'DAV:checked-out'))], [NULL],
	[" check DAV:checked-out property of test11.txt "])
val(	[select get_doc_v ('/DAV/versioning2/test12.txt', 1)], ["hello world! - 12"],
	[" check first version of test12.txt "])
valgt(  [select DB.DBA.DAV_VERSION_CONTROL ('/DAV/versioning2/test11.txt', 'dav', 'dav')], [0],
	[ " set versioning control on text2.txt " ])
val(	[select get_prop ('/DAV/versioning2/test11.txt', 'DAV:checked-in')],
	["/DAV/versioning2/VVC/test11.txt/last"],
	[" check DAV:checked-in property of test11.txt "])
val(	[select  DAV_HIDE_ERROR(get_prop ('/DAV/versioning2/test11.txt', 'DAV:checked-out'))], [NULL],
	[" check DAV:checked-out property of test11.txt "])
valgt(  [select DB.DBA.DAV_VERSION_CONTROL ('/DAV/versioning2/test11.txt', 'dav', 'dav')], [0],
	[ " set versioning control on text2.txt, second attempt " ])
val(	[select get_doc_v ('/DAV/versioning2/test11.txt', 1)], ["hello world! - 11"],
	[" check first version of test11.txt "])


-- uncheckout
valgt(	[select DAV_CHECKOUT ('/DAV/versioning2/test11.txt', 'dav', 'dav')], [0],
	[" checkout test11.txt "])
val(	[select  DAV_HIDE_ERROR(get_prop ('/DAV/versioning2/test11.txt', 'DAV:checked-in'))], [NULL],
	[" check DAV:checked-in property of test11.txt "])
val(	[select get_prop ('/DAV/versioning2/test11.txt', 'DAV:checked-out')],
	["/DAV/versioning2/VVC/test11.txt/last"],
	[" check DAV:checked-out property of test11.txt "])
valgt(  [select upload_doc ('/DAV/versioning2/test11.txt', 'content of test11.txt #1000')], [0],
	[" upload new content of file [test11.txt] "])
valgt(	[select DAV_UNCHECKOUT ('/DAV/versioning2/test11.txt', 'dav', 'dav')], [0],
	[" uncheckout test11.txt "])
val(	[select get_prop ('/DAV/versioning2/test11.txt', 'DAV:checked-in')],
	["/DAV/versioning2/VVC/test11.txt/last"],
	[" check DAV:checked-in property of test11.txt "])
val(	[select DAV_HIDE_ERROR(get_prop ('/DAV/versioning2/test11.txt', 'DAV:checked-out'))], [NULL],
	[" check DAV:checked-out property of test11.txt "])
val(	[select get_doc ('/DAV/versioning2/test11.txt')],['hello world! - 11'],
	[" check content of test11.txt "])

vallt(  [select upload_doc ('/DAV/versioning2/test11.txt', 'content of test11.txt #1000')], [0],
	[" upload new content of file [test11.txt] in checked-in file no auto-version"])
ok(	[select DAV_PROP_SET ('/DAV/versioning2/test11.txt', 'DAV:auto-version', 'DAV:checkout-checkin', 'dav', 'dav')],
	[ " set virt:Version-Collection " ])
valgt(  [select upload_doc ('/DAV/versioning2/test11.txt', 'content of test11.txt #1001')], [0],
	[" upload new content of file [test11.txt] in checked-in file auto-version=DAV:checkout-checkin "])
val(	[select get_doc ('/DAV/versioning2/test11.txt')],['content of test11.txt #1001'],
	[" check content of test11.txt "])
val(	[select count (*) from ws.ws.sys_dav_res_version where rv_res_id = dav_search_id ('/DAV/versioning2/test11.txt', 'R')],
	[2],
	[" count of versions in ws.ws.sys_dav_res_version table "])
val(	[select get_doc_v ('/DAV/versioning2/test11.txt', 1)],['hello world! - 11'],
	[" check content of ver1 test11.txt "])
val(	[select get_doc_v ('/DAV/versioning2/test11.txt', 2)],['content of test11.txt #1001'],
	[" check content of ver2 test11.txt "])

ok(	[select DAV_PROP_REMOVE ('/DAV/versioning2/test11.txt', 'DAV:auto-version', 'dav', 'dav')],
	[ " unset auto-version " ])
val(	[select prop_set ('/DAV/versioning2/test11.txt', vector ('my:prop1', 'prop1val', 'my:prop2', 'prop2val'), NULL)], [-1],
	[ " set new properties to checked-in VCR " ])
valgt(	[select DAV_CHECKOUT ('/DAV/versioning2/test11.txt', 'dav', 'dav')], [0],
	[" checkout test11.txt "])
val(	[select prop_set ('/DAV/versioning2/test11.txt', vector ('my:prop1', 'prop1val', 'my:prop2', 'prop2val'), NULL)], [1],
	[ " set new properties to checked-in VCR " ])
val(	[select DAV_HIDE_ERROR(get_prop('/DAV/versioning2/VVC/test11.txt/last', 'my:prop1'))], [NULL],
	[ " get new property from last VR " ])
val(	[select DAV_HIDE_ERROR(get_prop('/DAV/versioning2/VVC/test11.txt/last', 'my:prop2'))], [NULL],
	[ " get new property from last VR " ])
valgt(	[select DAV_CHECKIN ('/DAV/versioning2/test11.txt', 'dav', 'dav')], [0],
	[" checkin test11.txt "])
val(	[select count (*) from ws.ws.sys_dav_res_version where rv_res_id = dav_search_id ('/DAV/versioning2/test11.txt', 'R')],
	[3],
	[" count of versions in ws.ws.sys_dav_res_version table "])
val(	[select DAV_HIDE_ERROR(get_prop('/DAV/versioning2/test11.txt', 'my:prop1'))], ["prop1val"],
	[ " get new property from checked-out VCR " ])
val(	[select DAV_HIDE_ERROR(get_prop('/DAV/versioning2/test11.txt', 'my:prop2'))], ["prop2val"],
	[ " get new property from checked-out VCR " ])
val(	[select DAV_HIDE_ERROR(get_prop('/DAV/versioning2/VVC/test11.txt/last', 'my:prop1'))], ["prop1val"],
	[ " get new property from last VR " ])
val(	[select DAV_HIDE_ERROR(get_prop('/DAV/versioning2/VVC/test11.txt/last', 'my:prop2'))], ["prop2val"],
	[ " get new property from last VR " ])
val(	[select DAV_HIDE_ERROR(get_prop('/DAV/versioning2/VVC/test11.txt/last', 'my:prop3'))], [NULL],
	[ " get non-existing property from last VR " ])
valgt(	[select DAV_CHECKOUT ('/DAV/versioning2/test11.txt', 'dav', 'dav')], [0],
	[" checkout test11.txt "])
val(	[select prop_set ('/DAV/versioning2/test11.txt', NULL, vector ('my:prop1'))], [1],
	[ " delete a property my:prop1 from VCR " ])
valgt(	[select DAV_CHECKIN ('/DAV/versioning2/test11.txt', 'dav', 'dav')], [0],
	[" checkin test11.txt "])
val(	[select DAV_HIDE_ERROR(get_prop('/DAV/versioning2/test11.txt', 'my:prop1'))], [NULL],
	[ " get new property from checked-out VCR " ])
val(	[select DAV_HIDE_ERROR(get_prop('/DAV/versioning2/test11.txt', 'my:prop2'))], ["prop2val"],
	[ " get new property from checked-out VCR " ])
val(	[select DAV_HIDE_ERROR(get_prop('/DAV/versioning2/VVC/test11.txt/last', 'my:prop1'))], [NULL],
	[ " get new property from last VR " ])
val(	[select DAV_HIDE_ERROR(get_prop('/DAV/versioning2/VVC/test11.txt/last', 'my:prop2'))], ["prop2val"],
	[ " get new property from last VR " ])


-- uncheckout properties
valgt(	[select DAV_CHECKOUT ('/DAV/versioning2/test11.txt', 'dav', 'dav')], [0],
	[" checkout test11.txt "])
val(	[select prop_set ('/DAV/versioning2/test11.txt', vector ('my:prop3', 'prop3val', 'my:prop4', 'prop4val'), vector ('my:prop2'))], [1],
	[ " set new properties and delete my:prop2 to checked-in VCR " ])
valgt(	[select DAV_UNCHECKOUT ('/DAV/versioning2/test11.txt', 'dav', 'dav')], [0],
	[" uncheckout test11.txt "])
val(	[select DAV_HIDE_ERROR(get_prop('/DAV/versioning2/VVC/test11.txt/last', 'my:prop3'))], [NULL],
	[ " get non-existing property from last VR " ])
val(	[select DAV_HIDE_ERROR(get_prop('/DAV/versioning2/VVC/test11.txt/last', 'my:prop4'))], [NULL],
	[ " get non-existing property from last VR " ])
val(	[select DAV_HIDE_ERROR(get_prop('/DAV/versioning2/VVC/test11.txt/last', 'my:prop2'))], [prop2val],
	[ " get existing property from last VR " ])
val(	[select DAV_HIDE_ERROR(get_prop('/DAV/versioning2/test11.txt', 'my:prop3'))], [NULL],
	[ " get non-existing property from last VR " ])
val(	[select DAV_HIDE_ERROR(get_prop('/DAV/versioning2/test11.txt', 'my:prop4'))], [NULL],
	[ " get non-existing property from last VR " ])
val(	[select DAV_HIDE_ERROR(get_prop('/DAV/versioning2/test11.txt', 'my:prop2'))], [prop2val],
	[ " get existing property from last VR " ])

valgt(	[select DAV_DELETE ('/DAV/versioning/VVC/test11.txt/4', 0, 'dav', 'dav')], [0],
	[" old versions delete "])
val(	[select xpath_eval ('count (//version)', xtree_doc (get_doc_v_2 ('/DAV/versioning/VVC', 'test11.txt', 'history.xml')))], [2],
	[ " check number of versions in history "])
val(	[select count (*) from ws.ws.sys_dav_res_version where rv_res_id = dav_search_id ('/DAV/versioning/test11.txt', 'R')],
	[2],
	[" count of versions in ws.ws.sys_dav_res_version table "])


-- implicit restore of the file [not working]

val(	[select DAV_DELETE ('/DAV/versioning2/VVC/test11.txt/last', 0, 'dav', 'dav')], [1],
	[ " delete resource test11.txt "])
val(    [select check_file ('/DAV/versioning2/test11.txt')], ['not found'],
        [ " check is test11.txt removed "])
val(    [select check_file ('/DAV/versioning2/Attic/test11.txt')], ['found'],
        [ " check is test11.txt in Attic "])
valgt(  [select upload_doc ('/DAV/versioning2/test11.txt', 'content of test11.txt over delete file')], [0],
	[" upload new content of file [test11.txt] over delete file "])
valgt(  [select DB.DBA.DAV_VERSION_CONTROL ('/DAV/versioning2/test11.txt', 'dav', 'dav')], [0],
	[ " set versioning control on text11.txt, second attempt " ])
val(	[select xpath_eval ('number(count(/*/version))', xtree_doc (get_doc ('/DAV/versioning2/VVC/test11.txt/history.xml')))], [1],
	[ " number of versions of implicitly restored file " ])
val(    [select check_file ('/DAV/versioning2/Attic/test11.txt')], ['found'],
        [ " check is test11.txt in Attic "])

valgt(  [select DB.DBA.DAV_REMOVE_VERSION_CONTROL ('/DAV/versioning2/test11.txt', 'dav', 'dav')], [0],
	[ " set versioning control on text11.txt has been turned off " ])
val(	[select DAV_HIDE_ERROR(get_prop ('/DAV/versioning2/test11.txt', 'DAV:checked-out'))], [NULL],
	[" check DAV:checked-out property of test11.txt "])
val(	[select DAV_HIDE_ERROR(get_prop ('/DAV/versioning2/test11.txt', 'DAV:checked-in'))], [NULL],
	[" check DAV:checked-in property of test11.txt "])
val(    [select check_file ('/DAV/versioning2/Attic/test11.txt')], ['not found'],
        [ " check is test11.txt in Attic "])
val(    [select check_file ('/DAV/versioning2/VVC/test11.txt/1')], ['not found'],
        [ " check is first version test11.txt in VVC "])
val(    [select check_file ('/DAV/versioning2/VVC/test11.txt/last')], ['not found'],
        [ " check is last version of test11.txt in VVC "])
val(	[select DAV_HIDE_ERROR(get_prop('/DAV/versioning2/test11.txt', 'DAV:author'))], [NULL],
	[ " check DAV:author property " ])
val(	[select DAV_HIDE_ERROR(get_prop('/DAV/versioning2/test11.txt', 'DAV:version-history'))], [NULL],
	[ " check DAV:version-history property " ])
val(    [select check_file ('/DAV/versioning2/Attic/', 'C')], ['found'],
        [ " check is last version of test11.txt in VVC "])

vallt(  [select DB.DBA.DAV_REMOVE_VERSION_CONTROL ('/DAV/versioning2/test11.txt', 'dav', 'dav')], [0],
	[ " second attempt to turn off versioning  " ])
vallt(  [select DB.DBA.DAV_REMOVE_VERSION_CONTROL ('/DAV/versioning2/', 'dav', 'dav')], [0],
	[ " attempt to turn off versioning on wrong resource " ])
vallt(  [select DB.DBA.DAV_REMOVE_VERSION_CONTROL ('/DAV/versioning2/dfgdfg', 'dav', 'dav')], [0],
	[ " attempt to turn off versioning on wrong resource " ])
vallt(  [select DB.DBA.DAV_REMOVE_VERSION_CONTROL ('/DAV/versioning2/test9.txt', 'dav', 'dav')], [0],
	[ " attempt to turn off versioning on wrong resource " ])




-- reset versioning control
ECHO BOTH "Checking versioning, Pass 1R ... [set version control]\n";

ok(   [DB.DBA.DAV_DELETE ('/DAV/vers_test/', 1, 'dav','dav')],
	[" Deleting versioning collection"] )
valgt(   [select DB.DBA.DAV_COL_CREATE ('/DAV/vers_test/', '110100000R', 'dav', 'administrators', 'dav', 'dav')], [0],
	[" Create test collection: "])
ok(   [update WS.WS.SYS_DAV_COL set COL_AUTO_VERSIONING='A' where COL_ID = DAV_SEARCH_ID ('/DAV/vers_test/', 'C')],
	[" Set Versioning control on "])
valgt(   [select DB.DBA.DAV_COL_CREATE ('/DAV/vers_test/VVC/', '110100000R', 'dav', 'administrators', 'dav', 'dav')], [0],
	[" Create VVC test collection: "])
valgt(   [select DB.DBA.DAV_COL_CREATE ('/DAV/vers_test/Attic/', '110100000R', 'dav', 'administrators', 'dav', 'dav')], [0],
	[" Create Attic test collection: "])
valgt(  [select DB.DBA.DAV_SET_VERSIONING_CONTROL ('/DAV/vers_test/', NULL, 'A', 'dav', 'dav')], [0],
	[ " set versioning control " ])
valgt(   [select upload_docs ('/DAV/vers_test/', 20)], [0],
	[ " Upload docs to collection /DAV/vers_test/ "])

valgt(	[select DAV_REMOVE_VERSIONING_CONTROL_INT ('/DAV/vers_test/', 'dav', 'dav')], [0],
	[ " unset auto-version " ])
val(	[select DAV_HIDE_ERROR(get_prop('/DAV/vers_test/test11.txt', 'DAV:author'))], [NULL],
	[ " check DAV:author property " ])
val(	[select DAV_HIDE_ERROR(get_prop('/DAV/vers_test/test11.txt', 'DAV:version-history'))], [NULL],
	[ " check DAV:version-history property " ])
val(	[select DAV_HIDE_ERROR(get_prop('/DAV/vers_test/test11.txt', 'DAV:checked-in'))], [NULL],
	[ " check DAV:version-history property " ])
val(	[select DAV_HIDE_ERROR(get_prop('/DAV/vers_test/test11.txt', 'DAV:auto-version'))], [NULL],
	[ " check DAV:version-history property " ])

valgt(  [select DB.DBA.DAV_SET_VERSIONING_CONTROL ('/DAV/vers_test/', NULL, 'A', 'dav', 'dav')], [0],
	[ " set versioning control again " ])


ok(   [DB.DBA.DAV_DELETE ('/DAV/vers_test/', 1, 'dav','dav')],
	[" Deleting versioning collection"] )
valgt(   [select DB.DBA.DAV_COL_CREATE ('/DAV/vers_test/', '110100000R', 'dav', 'administrators', 'dav', 'dav')], [0],
	[" Create test collection: "])
ok(   [update WS.WS.SYS_DAV_COL set COL_AUTO_VERSIONING='A' where COL_ID = DAV_SEARCH_ID ('/DAV/vers_test/', 'C')],
	[" Set Versioning control on "])
valgt(   [select DB.DBA.DAV_COL_CREATE ('/DAV/vers_test/VVC/', '110100000R', 'dav', 'administrators', 'dav', 'dav')], [0],
	[" Create VVC test collection: "])
valgt(   [select DB.DBA.DAV_COL_CREATE ('/DAV/vers_test/Attic/', '110100000R', 'dav', 'administrators', 'dav', 'dav')], [0],
	[" Create Attic test collection: "])
valgt(  [select DB.DBA.DAV_SET_VERSIONING_CONTROL ('/DAV/vers_test/', NULL, 'A', 'dav', 'dav')], [0],
	[ " set versioning control " ])
valgt(   [select upload_docs ('/DAV/vers_test/', 20)], [0],
	[ " Upload docs to collection /DAV/vers_test/ "])

valgt(  [select DB.DBA.DAV_SET_VERSIONING_CONTROL ('/DAV/vers_test/', NULL, 'A', 'dav', 'dav')], [0],
	[ " set versioning control again " ])

ECHO BOTH "Bug 9958 check\n";

valgt(  [select upload_doc ('/DAV/versioning2/1.txt', 'content of test1.txt #1000')], [0],
	[" upload new content of file [1.txt] "])
valgt(  [select DB.DBA.DAV_VERSION_CONTROL ('/DAV/versioning2/1.txt', 'dav', 'dav')], [0],
	[ " set versioning control on text1.txt, second attempt " ])
ok(	[select DAV_PROP_SET ('/DAV/versioning2/1.txt', 'DAV:auto-version', 'DAV:checkout-checkin', 'dav', 'dav')],
	[ " set DAV:auto-version " ])
valgt(  [select upload_doc ('/DAV/versioning2/1.txt', 'content of test1.txt #')], [0],
	[" upload new content of file [1.txt] "])
valgt(	[select DAV_DELETE ('/DAV/versioning2/VVC/1.txt/1', 0, 'dav', 'dav')], [0],
	[" old versions delete "])
valgt(	[select DAV_CHECKOUT ('/DAV/versioning2/1.txt', 'dav', 'dav')], [0],
	[" checkout 1.txt "])
valgt(	[select DAV_UNCHECKOUT ('/DAV/versioning2/1.txt', 'dav', 'dav')], [0],
	[" uncheckout 1.txt "])
valgt(	[select DAV_CHECKOUT ('/DAV/versioning2/1.txt', 'dav', 'dav')], [0],
	[" checkout 1.txt "])
valgt(	[select DAV_UNCHECKOUT ('/DAV/versioning2/1.txt', 'dav', 'dav')], [0],
	[" uncheckout 1.txt "])
vallt(	[select DAV_UNCHECKOUT ('/DAV/versioning2/1.txt', 'dav', 'dav')], [0],
	[" uncheckout 1.txt "])
valgt(	[select DAV_CHECKOUT ('/DAV/versioning2/1.txt', 'dav', 'dav')], [0],
	[" checkout 1.txt "])
vallt(	[select DAV_CHECKOUT ('/DAV/versioning2/1.txt', 'dav', 'dav')], [0],
	[" checkout 1.txt "])
valgt(	[select DAV_UNCHECKOUT ('/DAV/versioning2/1.txt', 'dav', 'dav')], [0],
	[" uncheckout 1.txt "])

ECHO BOTH "set wrong auto-version value\n";
vallt(	[select DAV_PROP_SET ('/DAV/versioning2/1.txt', 'DAV:auto-version', 'DAV:checkin-checkout', 'dav', 'dav')],[0],
	[ " set DAV:auto-version " ])

ECHO BOTH "Bug 9959\n";
valgt(  [select upload_doc ('/DAV/versioning2/1.txt', 'content of test1.txt #1')], [0],
	[" upload new content of file [1.txt] "])
val(	[select get_res_prop ('/DAV/versioning2/VVC/1.txt/', '2', 2)], [22],
	[" size of 2nd version "])
val(	[select get_res_prop ('/DAV/versioning2/VVC/1.txt/', '3', 2)], [23],
	[" size of 3d version "])
val(	[select get_res_prop ('/DAV/versioning/VVC/test11.txt/', '6', 2)], [27],
	[" size of /DAV/versioning/VVC/test11.txt/6 "])



ECHO BOTH "deleting VVC folder, check consistency\n";
valgt(	[select DAV_DELETE ('/DAV/versioning2/VVC/', 0, 'dav', 'dav')], [0],
	[" delete VVC folder "])
val(	[select count(*) from WS.WS.SYS_DAV_RES_DIFF inner join WS.WS.SYS_DAV_RES on (RD_RES_ID = RES_ID) where RES_COL = DAV_SEARCH_ID ('/DAV/versioning2/', 'C')], [0],
	[" number of files under version control after VVC removed "])

val(	[select DAV_HIDE_ERROR (get_prop('/DAV/versioning2/1.txt', 'DAV:author'))], [NULL],
	[" DAV:author property "])
val(	[select DAV_HIDE_ERROR (get_prop('/DAV/versioning2/1.txt', 'DAV:auto-version'))], [NULL],
	[" DAV:auto-version property "])
val(	[select DAV_HIDE_ERROR (get_prop('/DAV/versioning2/1.txt', 'DAV:checked-in'))], [NULL],
	[" DAV:checked-in property "])
val(	[select DAV_HIDE_ERROR (get_prop('/DAV/versioning2/1.txt', 'DAV:version-history'))], [NULL],
	[" DAV:version-history property "])


ECHO BOTH "wrapping several versions in one\n";
ok(   [DB.DBA.DAV_DELETE ('/DAV/versioning3/', 1, 'dav','dav')],
	[" Deleting second versioning collection"] )
valgt(   [select DB.DBA.DAV_COL_CREATE ('/DAV/versioning3/', '110100000R', 'dav', 'administrators', 'dav', 'dav')], [0],
	[" Create test collection: "])
valgt(  [select upload_doc ('/DAV/versioning3/file1.txt', 'content of file1.txt, version 1')], [0],
	[ " upload initial version of file1.txt "])
valgt(  [select DB.DBA.DAV_VERSION_CONTROL ('/DAV/versioning3/file1.txt', 'dav', 'dav')], [0],
	[ " set versioning control " ])
ok(	[select DAV_PROP_SET ('/DAV/versioning3/file1.txt', 'DAV:auto-version', 'DAV:checkout-checkin', 'dav', 'dav')],
	[ " set DAV:auto-version " ])
valgt(  [select upload_doc ('/DAV/versioning3/file1.txt', 'content of file1.txt, version 2')], [0],
	[ " upload second version of file1.txt "])
valgt(  [select upload_doc ('/DAV/versioning3/file1.txt', 'content of file1.txt, version 3')], [0],
	[ " upload third version of file1.txt "])
valgt(  [select upload_doc ('/DAV/versioning3/file1.txt', 'content of file1.txt, version 4')], [0],
	[ " upload fourth version of file1.txt "])
val(	[select xpath_eval ('count (//version)', xtree_doc (get_doc_v_2 ('/DAV/versioning3/VVC', 'file1.txt', 'history.xml')))], [4],
	[ " check number of versions in history "])
valgt(  [select DAV_VERSION_FOLD_INT ('/DAV/versioning3/file1.txt', 2, 'dav')], [0],
	[ " folding versions to version 2 "])
val(	[select xpath_eval ('count (//version)', xtree_doc (get_doc_v_2 ('/DAV/versioning3/VVC', 'file1.txt', 'history.xml')))], [2],
	[ " check number of versions in history after folding"])
val(	[select get_doc_v ('/DAV/versioning3/file1.txt', 1)], ['content of file1.txt, version 1'],
	[ " check the content of first version "])
val( 	[select get_doc ('/DAV/versioning3/file1.txt')], ['content of file1.txt, version 4'],
	[ " check the content of last version "])
valgt(  [select upload_doc ('/DAV/versioning3/file1.txt', 'content of file1.txt, version 5')], [0],
	[ " upload third version of file1.txt "])
valgt(  [select DAV_VERSION_FOLD_INT ('/DAV/versioning3/file1.txt', 1, 'dav')], [0],
	[ " folding versions to version 1 "])
val(	[select xpath_eval ('count (//version)', xtree_doc (get_doc_v_2 ('/DAV/versioning3/VVC', 'file1.txt', 'history.xml')))], [1],
	[ " check number of versions in history after folding"])
val(	[select get_doc ('/DAV/versioning3/file1.txt')], ['content of file1.txt, version 5'],
	[ " check the content of last version "])



-- DAV_COPY test

ok(   [DB.DBA.DAV_DELETE ('/DAV/vers_copy/', 1, 'dav','dav')],
	[" Delete versioning collection"] )
valgt(   [select DB.DBA.DAV_COL_CREATE ('/DAV/vers_copy/', '110100000R', 'dav', 'administrators', 'dav', 'dav')], [0],
	[" Create test collection: "])
valgt(   [select upload_docs ('/DAV/vers_copy/', 20)], [0],
	[ " Upload docs to collection /DAV/vers_copy/ "])

valgt(  [select DB.DBA.DAV_VERSION_CONTROL ('/DAV/vers_copy/test1.txt', 'dav', 'dav')], [0],
	[ " set versioning control on text1.txt " ])
ok(	[select DAV_PROP_SET ('/DAV/vers_copy/test1.txt', 'DAV:auto-version', 'DAV:checkout-checkin', 'dav', 'dav')],
 	[ " set auto-version for test1.txt "] )

valgt(  [select DB.DBA.DAV_VERSION_CONTROL ('/DAV/vers_copy/test2.txt', 'dav', 'dav')], [0],
	[ " set versioning control on text2.txt " ])
ok(	[select DAV_PROP_SET ('/DAV/vers_copy/test2.txt', 'DAV:auto-version', 'DAV:checkout-checkin', 'dav', 'dav')],
 	[ " set auto-version for test2.txt "] )

valgt(  [select copy ('/DAV/vers_copy/test3.txt', '/DAV/vers_copy/test2.txt')], [0],
	[ " copy test3.txt to test2.txtt " ])

val(	[select get_doc_v_2 ('/DAV/vers_copy/VVC', 'test2.txt', 1)], ['hello world! - 2'],
	[ " check last version of file2.txt by DET "])
val(	[select get_doc_v_2 ('/DAV/vers_copy/VVC', 'test2.txt', 2)], ['hello world! - 3'],
	[ " check last version of file2.txt by DET "])


-- DAV_COPY test # 2

valgt(  [select DB.DBA.DAV_VERSION_CONTROL ('/DAV/vers_copy/test4.txt', 'dav', 'dav')], [0],
	[ " set versioning control on text4.txt " ])
ok(	[select DAV_PROP_SET ('/DAV/vers_copy/test4.txt', 'DAV:auto-version', 'DAV:locked-checkout', 'dav', 'dav')],
 	[ " set auto-version for test4.txt "] )
valgt(  [select lock_res ('/DAV/vers_copy/test4.txt')], [0],
	[ " lock test4.txt" ])
valgt(  [select copy ('/DAV/vers_copy/test5.txt', '/DAV/vers_copy/test4.txt')], [0],
	[ " copy test5.txt to test4.txtt " ])
valgt(	[select DAV_CHECKIN ('/DAV/vers_copy/test4.txt', 'dav', 'dav')], [0],
	[" checkin test4.txt "])
val(	[select get_doc_v_2 ('/DAV/vers_copy/VVC', 'test4.txt', 1)], ['hello world! - 4'],
	[ " check prev version of file4.txt by DET "])
val(	[select get_doc_v_2 ('/DAV/vers_copy/VVC', 'test4.txt', 2)], ['hello world! - 5'],
	[ " check last version of file4.txt by DET "])

valgt(  [select copy ('/DAV/vers_copy/test7.txt', '/DAV/vers_copy/test6.txt')], [0],
	[ " copy test7.txt to test6.txtt " ])
val(	[select get_doc ('/DAV/vers_copy/test6.txt')], ['hello world! - 7'],
	[ " check content of test6"])
valgt(  [select lock_res ('/DAV/vers_copy/test6.txt')], [0],
	[ " lock test6.txt" ])
vallt(  [select copy ('/DAV/vers_copy/test8.txt', '/DAV/vers_copy/test6.txt')], [0],
	[ " copy test8.txt to test6.txtt " ])
val(	[select get_doc ('/DAV/vers_copy/test6.txt')], ['hello world! - 7'],
	[ " check content of test6"])
