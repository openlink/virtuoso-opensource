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
set echo off;

create procedure TDAV_RDF_QUAD_CHECK (in resname varchar, in propuri varchar, in encoded_propval varchar, in should_present integer := 1)
{
  declare status varchar;
  result_names (status);
  declare uriqa_default_host, new_dav_graph, full_res_uri, propval varchar;
  declare crop, actual integer;
  uriqa_default_host := cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost');
  if (uriqa_default_host is null or uriqa_default_host = '')
    signal('OBLOM', 'No uriqa_default_host!');
  crop := 0;
  if (isstring (encoded_propval))
    propval := "CatFilter_DECODE_CATVALUE" (encoded_propval, crop);
  else
    propval := encoded_propval;
  new_dav_graph := sprintf('http://%s/DAV/', uriqa_default_host);
  --dbg_obj_princ('dav_graph::', new_dav_graph);
  full_res_uri := DB.DBA.DAV_FULL_PATH_TO_IRI (new_dav_graph, '/DAV/tdav_meta_home/zip_samples/' || resname);
  dbg_obj_princ ('TDAV_RDF_QUAD_CHECK: ', full_res_uri, propuri, encoded_propval);
  if (crop <> 0)
    return;
  if (exists (sparql ask where { graph ?:new_dav_graph {
          ?:full_res_uri ?:propuri ?:propval } } ))
    actual := 1;
  else
    actual := 0;
  dbg_obj_princ ('TDAV_RDF_QUAD_CHECK: should be ', should_present, ', actual ', actual);
  if (isiri_id(propval))
    propval := concat ('<', DB.DBA.RDF_QNAME_OF_IID(propval), '>');
  if (should_present)
    {
      if (actual)
        result (sprintf ('PASSED: found triplet S=%s P=%s O=%s', resname, propuri, cast (propval as varchar)));
      else
        result (sprintf ('***' || 'FAI' || 'LED: there should be triplet S=%s P=%s O=%s', resname, propuri, cast (propval as varchar)));
    }
  else
    {
      if (actual)
        result (sprintf ('***' || 'FAI' || 'LED: there should be no triplet S=%s P=%s O=%s', resname, propuri, cast (propval as varchar)));
      else
        result (sprintf ('PASSED: no triplet S=%s P=%s O=%s', resname, propuri, cast (propval as varchar)));
    }
}
;

--replicate all
DAV_COL_CREATE('/DAV/tdav_meta_home/zip_samples/test/', '100100100R', 'tdav_meta', 'tdav_meta_grp', 'dav', 'dav');
DAV_COL_CREATE('/DAV/tdav_meta_home/zip_samples/test11/', '100100100R', 'tdav_meta', 'tdav_meta_grp', 'dav', 'dav');
update WS.WS.SYS_DAV_RES set RES_PERMS = '100100100RR';
update WS.WS.SYS_DAV_COL set COL_PERMS = '100100100RR';
DB.DBA.DAV_REPLICATE_ALL_TO_RDF_QUAD (1);
load 'tdav_meta_rdf_checks.sql'; 

--create procedure TDAV_RDF_QUAD_CHECK2 (in resname varchar, in propuri varchar, in encoded_propval varchar)
--{
--    declare res_id2 integer;
--    res_id2 := (select RES_ID from WS.WS.SYS_DAV_RES where RES_FULL_PATH = concat('/DAV/tdav_meta_home/zip_samples', resname));
--    insert into WS.WS.SYS_DAV_PROP (PROP_NAME, PROP_TYPE, PROP_PARENT, PROP_VALUE) values('http://local.virt/DAV-RDF', 'R', res_id2, );
--}
--;

create procedure TDAV_RDF_QUAD_CHECK3(in resname varchar, in propuri varchar, in encoded_propval varchar)
{
    declare res_id2, owner integer;
    res_id2 := DAV_SEARCH_ID ('/DAV/tdav_meta_home/zip_samples/' || resname, 'R');
    if (DAV_HIDE_ERROR (res_id2) is null)
      signal ('OBLOM', 'No named resource');
    delete from WS.WS.SYS_DAV_TAG where DT_RES_ID = res_id2 and DT_U_ID = http_nobody_uid();
    insert into WS.WS.SYS_DAV_TAG (DT_RES_ID, DT_U_ID, DT_FT_ID, DT_TAGS)
        values (res_id2, http_nobody_uid(), WS.WS.GETID('T'), 'test1,test2');
    TDAV_RDF_QUAD_CHECK (resname, 'http://www.openlinksw.com/schemas/DAV#tag', 'test1');
    TDAV_RDF_QUAD_CHECK (resname, 'http://www.openlinksw.com/schemas/DAV#tag', 'test2');
    update WS.WS.SYS_DAV_TAG set DT_TAGS = 'test2,test3' where DT_RES_ID = res_id2 and DT_U_ID = http_nobody_uid();
    TDAV_RDF_QUAD_CHECK (resname, 'http://www.openlinksw.com/schemas/DAV#tag', 'test1', 0);
    TDAV_RDF_QUAD_CHECK (resname, 'http://www.openlinksw.com/schemas/DAV#tag', 'test2');
    TDAV_RDF_QUAD_CHECK (resname, 'http://www.openlinksw.com/schemas/DAV#tag', 'test3');
    delete from WS.WS.SYS_DAV_TAG where DT_RES_ID = res_id2 and DT_U_ID = http_nobody_uid();
    TDAV_RDF_QUAD_CHECK (resname, 'http://www.openlinksw.com/schemas/DAV#tag', 'test1', 0);
    TDAV_RDF_QUAD_CHECK (resname, 'http://www.openlinksw.com/schemas/DAV#tag', 'test2', 0);
    TDAV_RDF_QUAD_CHECK (resname, 'http://www.openlinksw.com/schemas/DAV#tag', 'test3', 0);
}
;

create procedure TDAV_RDF_QUAD_CHECK44(in resname varchar, in propuri varchar, in encoded_propval varchar)
{
    declare uriqa_default_host, new_dav_graph, full_res_uri varchar;
    declare rc integer;
    uriqa_default_host := cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost');
    if (uriqa_default_host is null or uriqa_default_host = '')
      signal('OBLOM', 'No uriqa_default_host!');
    new_dav_graph := sprintf('http://%s/DAV/', uriqa_default_host);
    full_res_uri := concat('/DAV/tdav_meta_home/zip_samples/',resname);
    TDAV_RDF_QUAD_CHECK (resname, propuri, encoded_propval);
    rc := DAV_MOVE(full_res_uri, concat(full_res_uri, '.mod'), 1, 'dav', 'dav');
    if (DAV_HIDE_ERROR (rc) is null)
        signal ('OBLOM', 'res move error');
    TDAV_RDF_QUAD_CHECK (resname, propuri, encoded_propval, 0);
    TDAV_RDF_QUAD_CHECK (concat(resname, '.mod'), propuri, encoded_propval);
}
;

create procedure TDAV_RDF_QUAD_CHECK4(in resname varchar, in propuri varchar, in encoded_propval varchar)
{
    declare uriqa_default_host, new_dav_graph, full_res_uri varchar;
    uriqa_default_host := cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost');
    if (uriqa_default_host is null or uriqa_default_host = '')
      signal('OBLOM', 'No uriqa_default_host!');
    new_dav_graph := sprintf('http://%s/DAV/', uriqa_default_host);
    full_res_uri := concat(new_dav_graph, 'tdav_meta_home/zip_samples/',resname);
    update WS.WS.SYS_DAV_RES set RES_NAME = concat(resname, '.mod') where RES_FULL_PATH = full_res_uri;
    TDAV_RDF_QUAD_CHECK (concat(resname, '.mod'), propuri, encoded_propval);
    TDAV_RDF_QUAD_CHECK (resname, propuri, encoded_propval, 0);
}
;

create procedure TDAV_RDF_QUAD_CHECK_COL44(in col_full_path varchar, in propuri varchar, in encoded_propval varchar)
{
    declare colid, rc integer;
    declare resname varchar;
    colid := DAV_SEARCH_ID(concat(col_full_path, '/'), 'C');
    if (DAV_HIDE_ERROR (colid) is null)
      signal ('OBLOM', sprintf ('Failed to find a collection named "%s"', col_full_path));
    resname := (select COL_NAME from WS.WS.SYS_DAV_COL where COL_ID = colid);
    rc := DAV_MOVE(concat(col_full_path, '/'), concat(col_full_path, '.mod/'), 1, 'dav', 'dav');
    if (DAV_HIDE_ERROR (rc) is null)
        signal ('OBLOM', 'col move error');
    TDAV_RDF_QUAD_CHECK (concat(resname, '.mod/'), propuri, encoded_propval);
    TDAV_RDF_QUAD_CHECK (concat(resname, '/'), propuri, encoded_propval, 0);
}
;

create procedure TDAV_RDF_QUAD_CHECK_COL4(in col_full_path varchar, in propuri varchar, in encoded_propval varchar)
{
    declare colid integer;
    declare resname varchar;
    colid := DAV_SEARCH_ID(col_full_path, 'C');
    if (DAV_HIDE_ERROR (colid) is null)
      signal ('OBLOM', sprintf ('Failed to find a collection named "%s"', col_full_path));
    resname := (select COL_NAME from WS.WS.SYS_DAV_COL where COL_ID = colid);
    update WS.WS.SYS_DAV_COL set COL_NAME = concat(resname, '.mod') where COL_ID = colid;
    TDAV_RDF_QUAD_CHECK (concat(resname, '.mod'), propuri, encoded_propval);
    TDAV_RDF_QUAD_CHECK (resname, propuri, encoded_propval, 0);
}
;

create procedure TDAV_RDF_QUAD_CHECK5(in resname varchar, in propuri varchar, in encoded_propval varchar)
{
    declare uriqa_default_host, new_dav_graph, full_res_path varchar;
    uriqa_default_host := cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost');
    if (uriqa_default_host is null or uriqa_default_host = '')
      signal('OBLOM', 'No uriqa_default_host!');
    new_dav_graph := sprintf('http://%s/DAV/', uriqa_default_host);
    full_res_path := concat('/DAV/tdav_meta_home/zip_samples/',resname);
    TDAV_RDF_QUAD_CHECK (resname, propuri, encoded_propval);
    update WS.WS.SYS_DAV_RES set RES_NAME = concat(RES_NAME, '.mod') where RES_FULL_PATH = full_res_path;
    TDAV_RDF_QUAD_CHECK (concat(resname, '.mod'), propuri, encoded_propval);
    TDAV_RDF_QUAD_CHECK (resname, propuri, encoded_propval, 0);
    update WS.WS.SYS_DAV_RES set RES_NAME = resname where RES_FULL_PATH = concat (full_res_path, '.mod');
    TDAV_RDF_QUAD_CHECK (concat(resname, '.mod'), propuri, encoded_propval, 0);
    TDAV_RDF_QUAD_CHECK (resname, propuri, encoded_propval);
}
;

create procedure TDAV_RDF_QUAD_CHECK6(in resname varchar, in propuri varchar, in encoded_propval varchar)
{
    declare uriqa_default_host, new_dav_graph, full_res_path varchar;
    uriqa_default_host := cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost');
    if (uriqa_default_host is null or uriqa_default_host = '')
      signal('OBLOM', 'No uriqa_default_host!');
    new_dav_graph := sprintf('http://%s/DAV/', uriqa_default_host);
    full_res_path := concat('/DAV/tdav_meta_home/zip_samples/',resname);
    TDAV_RDF_QUAD_CHECK (resname, propuri, encoded_propval);
    update WS.WS.SYS_DAV_RES set RES_PERMS = '111111011RR' where RES_FULL_PATH = full_res_path;
    TDAV_RDF_QUAD_CHECK (resname, propuri, encoded_propval, 0);
    update WS.WS.SYS_DAV_RES set RES_PERMS = '100100100RR' where RES_FULL_PATH = full_res_path;
    TDAV_RDF_QUAD_CHECK (resname, propuri, encoded_propval);
}
;

create procedure TDAV_RDF_QUAD_CHECK_COL6(in col_full_path varchar, in propuri varchar, in encoded_propval varchar)
{
  declare colid integer;
  declare resname varchar;
  colid := DAV_SEARCH_ID(concat(col_full_path, '/'), 'C');
  if (DAV_HIDE_ERROR (colid) is null)
    signal ('OBLOM', sprintf ('Failed to find a collection named "%s"', col_full_path));
  resname := (select COL_NAME from WS.WS.SYS_DAV_COL where COL_ID = colid);
  TDAV_RDF_QUAD_CHECK (concat(resname, '/'), propuri, encoded_propval);
  update WS.WS.SYS_DAV_COL set COL_PERMS = '111111011RR' where COL_ID = colid;
  TDAV_RDF_QUAD_CHECK (concat(resname, '/'), propuri, encoded_propval, 0);
  update WS.WS.SYS_DAV_COL set COL_PERMS = '111111111RR' where COL_ID = colid;
  TDAV_RDF_QUAD_CHECK (concat(resname, '/'), propuri, encoded_propval);
}
;

create procedure TDAV_RDF_QUAD_CHECK7(in resname varchar)
{
  declare uriqa_default_host, new_dav_graph, full_res_uri varchar;
  uriqa_default_host := cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost');
  if (uriqa_default_host is null or uriqa_default_host = '')
    signal('OBLOM', 'No uriqa_default_host!');
  new_dav_graph := sprintf('http://%s/DAV/', uriqa_default_host);
  full_res_uri := concat('/DAV/tdav_meta_home/zip_samples/',resname);
  declare email varchar;
  email := DB.DBA.RDF_MAKE_IID_OF_QNAME(DB.DBA.DAV_MAKE_USER_IRI(2));
  update WS.WS.SYS_DAV_RES set RES_OWNER = 0 where RES_FULL_PATH = full_res_uri;
  TDAV_RDF_QUAD_CHECK (resname, 'http://www.openlinksw.com/schemas/DAV#ownerUser', email, 0);
  update WS.WS.SYS_DAV_RES set RES_OWNER = 2 where RES_FULL_PATH = full_res_uri;
  TDAV_RDF_QUAD_CHECK (resname, 'http://www.openlinksw.com/schemas/DAV#ownerUser', email);
}
;

create procedure TDAV_RDF_QUAD_CHECK_COL7(in col_full_path varchar)
{
  declare colid integer;
  colid := DAV_SEARCH_ID(concat (col_full_path, '/'), 'C');
  if (DAV_HIDE_ERROR (colid) is null)
    signal ('OBLOM', sprintf ('Failed to find a collection named "%s"', col_full_path));
  declare resname varchar;
  resname := (select COL_NAME from WS.WS.SYS_DAV_COL where COL_ID = colid);
  declare email varchar;
  email := DB.DBA.RDF_MAKE_IID_OF_QNAME(DB.DBA.DAV_MAKE_USER_IRI(2));
  update WS.WS.SYS_DAV_COL set COL_OWNER = 0 where COL_ID = colid;
  TDAV_RDF_QUAD_CHECK (concat(resname, '/'), 'http://www.openlinksw.com/schemas/DAV#ownerUser', email, 0);
  update WS.WS.SYS_DAV_COL set COL_OWNER = 2 where COL_ID = colid;
  TDAV_RDF_QUAD_CHECK (concat(resname, '/'), 'http://www.openlinksw.com/schemas/DAV#ownerUser', email);
}
;

create procedure TDAV_RDF_QUAD_CHECK8(in resname varchar)
{
  declare uriqa_default_host, new_dav_graph, fullpath varchar;
  uriqa_default_host := cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost');
  if (uriqa_default_host is null or uriqa_default_host = '')
    signal('OBLOM', 'No uriqa_default_host!');
  new_dav_graph := sprintf('http://%s/DAV/', uriqa_default_host);
  fullpath := concat('/DAV/tdav_meta_home/zip_samples/',resname);
  TDAV_RDF_QUAD_CHECK (resname, 'http://purl.org/dc/terms/extent', 4, 0);
  update WS.WS.SYS_DAV_RES set RES_CONTENT = 'test' where RES_FULL_PATH = fullpath;
  TDAV_RDF_QUAD_CHECK (resname, 'http://purl.org/dc/terms/extent', 4);
}
;

create procedure TDAV_RDF_QUAD_CHECK9(in resname varchar)
{
  declare uriqa_default_host, new_dav_graph, fullpath varchar;
  uriqa_default_host := cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost');
  if (uriqa_default_host is null or uriqa_default_host = '')
    signal('OBLOM', 'No uriqa_default_host!');
  new_dav_graph := sprintf('http://%s/DAV/', uriqa_default_host);
  fullpath := concat('/DAV/tdav_meta_home/zip_samples/',resname);
  declare dt  datetime;
  dt := now();
  TDAV_RDF_QUAD_CHECK (resname, 'http://purl.org/dc/terms/created', dt, 0);
  update WS.WS.SYS_DAV_RES set RES_CR_TIME = dt where RES_FULL_PATH = fullpath;
  TDAV_RDF_QUAD_CHECK (resname, 'http://purl.org/dc/terms/created', dt);
}
;

create procedure TDAV_RDF_QUAD_CHECK_COL9(in col_full_path varchar)
{
  declare colid integer;
  colid := DAV_SEARCH_ID(concat (col_full_path, '/'), 'C');
  if (DAV_HIDE_ERROR (colid) is null)
    signal ('OBLOM', sprintf ('Failed to find a collection named "%s"', col_full_path));
  declare resname varchar;
  resname := (select COL_NAME from WS.WS.SYS_DAV_COL where COL_ID = colid);
  declare dt  datetime;
  dt := now();
  TDAV_RDF_QUAD_CHECK (concat(resname, '/'), 'http://purl.org/dc/terms/created', dt, 0);
  update WS.WS.SYS_DAV_COL set COL_CR_TIME = dt where COL_ID = colid;
  TDAV_RDF_QUAD_CHECK (concat(resname, '/'), 'http://purl.org/dc/terms/created', dt);
}
;

create procedure TDAV_RDF_QUAD_CHECK10(in resname varchar)
{
  declare uriqa_default_host, new_dav_graph, fullpath varchar;
  uriqa_default_host := cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost');
  if (uriqa_default_host is null or uriqa_default_host = '')
    signal('OBLOM', 'No uriqa_default_host!');
  new_dav_graph := sprintf('http://%s/DAV/', uriqa_default_host);
  fullpath := concat('/DAV/tdav_meta_home/zip_samples/',resname);
  declare dt datetime;
  dt := now();
  TDAV_RDF_QUAD_CHECK (resname, 'http://purl.org/dc/terms/modified', dt, 0);
  update WS.WS.SYS_DAV_RES set RES_MOD_TIME = dt where RES_FULL_PATH = fullpath;
  TDAV_RDF_QUAD_CHECK (resname, 'http://purl.org/dc/terms/modified', dt);
}
;

create procedure TDAV_RDF_QUAD_CHECK_COL10(in col_full_path varchar)
{
  declare colid integer;
  colid := DAV_SEARCH_ID(concat (col_full_path, '/'), 'C');
  if (DAV_HIDE_ERROR (colid) is null)
    signal ('OBLOM', sprintf ('Failed to find a collection named "%s"', col_full_path));
  declare resname varchar;
  resname := (select COL_NAME from WS.WS.SYS_DAV_COL where COL_ID = colid);
  declare dt  datetime;
  dt := now();
  TDAV_RDF_QUAD_CHECK (concat (resname, '/'), 'http://purl.org/dc/terms/modified', dt, 0);
  update WS.WS.SYS_DAV_COL set COL_MOD_TIME = dt where COL_ID = colid;
  TDAV_RDF_QUAD_CHECK (concat (resname, '/'), 'http://purl.org/dc/terms/modified', dt);
}
;


create procedure TDAV_RDF_QUAD_CHECK11(in resname varchar, in propuri varchar, in encoded_propval varchar)
{
  declare uriqa_default_host, new_dav_graph, fullpath varchar;
  uriqa_default_host := cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost');
  if (uriqa_default_host is null or uriqa_default_host = '')
    signal('OBLOM', 'No uriqa_default_host!');
  new_dav_graph := sprintf('http://%s/DAV/', uriqa_default_host);
  fullpath := concat('/DAV/tdav_meta_home/zip_samples/', resname);
  TDAV_RDF_QUAD_CHECK (resname, propuri, encoded_propval);
  delete from WS.WS.SYS_DAV_RES where RES_FULL_PATH = fullpath;
  TDAV_RDF_QUAD_CHECK (resname, propuri, encoded_propval, 0);
}
;

create procedure TDAV_RDF_QUAD_CHECK_COL11(in col_full_path varchar, in propuri varchar, in encoded_propval varchar)
{
  declare colid integer;
  colid := DAV_SEARCH_ID(concat (col_full_path, '/'), 'C');
  if (DAV_HIDE_ERROR (colid) is null)
    signal ('OBLOM', sprintf ('Failed to find a collection named "%s"', col_full_path));
  declare resname varchar;
  resname := (select COL_NAME from WS.WS.SYS_DAV_COL where COL_ID = colid);
  TDAV_RDF_QUAD_CHECK (concat(resname, '/'), propuri, encoded_propval);
  delete from WS.WS.SYS_DAV_COL where COL_ID = colid;
  TDAV_RDF_QUAD_CHECK (concat(resname, '/'), propuri, encoded_propval, 0);
}
;


--- tests!
--set echo on;
TDAV_RDF_QUAD_CHECK3 ('George Kodinov.vcf', 'http://www.w3.org/2001/vcard-rdf/3.0#Address-Country', 'Bulgaria');
TDAV_RDF_QUAD_CHECK44 ('George Kodinov.vcf', 'http://www.w3.org/2001/vcard-rdf/3.0#Address-Country', 'Bulgaria');
TDAV_RDF_QUAD_CHECK5 ('George Kodinov.vcf.mod', 'http://www.w3.org/2001/vcard-rdf/3.0#Address-Country', 'Bulgaria');
TDAV_RDF_QUAD_CHECK6 ('George Kodinov.vcf.mod', 'http://www.w3.org/2001/vcard-rdf/3.0#Address-Country', 'Bulgaria');
TDAV_RDF_QUAD_CHECK7 ('George Kodinov.vcf.mod');
TDAV_RDF_QUAD_CHECK8 ('George Kodinov.vcf.mod');	
TDAV_RDF_QUAD_CHECK9 ('George Kodinov.vcf.mod');
TDAV_RDF_QUAD_CHECK10 ('George Kodinov.vcf.mod');
TDAV_RDF_QUAD_CHECK11 ('Dimitar Dimitrov.vcf', 'http://www.w3.org/2001/vcard-rdf/3.0#Org-Orgname', 'OpenLink Bulgaria');
TDAV_RDF_QUAD_CHECK_COL44 ('/DAV/tdav_meta_home/zip_samples/test', 'http://www.openlinksw.com/schemas/DAV#ownerUser', DB.DBA.RDF_MAKE_IID_OF_QNAME('mailto:tdav_meta@localhost'));
TDAV_RDF_QUAD_CHECK_COL6('/DAV/tdav_meta_home/zip_samples/test.mod', 'http://www.openlinksw.com/schemas/DAV#ownerUser', DB.DBA.RDF_MAKE_IID_OF_QNAME('mailto:tdav_meta@localhost'));
TDAV_RDF_QUAD_CHECK_COL7 ('/DAV/tdav_meta_home/zip_samples/test.mod');
TDAV_RDF_QUAD_CHECK_COL9 ('/DAV/tdav_meta_home/zip_samples/test.mod');
TDAV_RDF_QUAD_CHECK_COL10 ('/DAV/tdav_meta_home/zip_samples/test.mod');
TDAV_RDF_QUAD_CHECK_COL11 ('/DAV/tdav_meta_home/zip_samples/test11', 'http://www.openlinksw.com/schemas/DAV#ownerUser', DB.DBA.RDF_MAKE_IID_OF_QNAME('mailto:tdav_meta@localhost'));
TDAV_RDF_QUAD_CHECK ('test11/', 'http://www.openlinksw.com/schemas/DAV#ownerUser',
DB.DBA.RDF_MAKE_IID_OF_QNAME('mailto:tdav_meta@localhost'), 0);
