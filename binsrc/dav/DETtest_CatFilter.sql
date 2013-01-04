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

set echo off;
set verbose off;

create procedure TEST_CATFILTER_MAKE_SCHEMA (in base varchar, in addon_uri varchar, in size integer)
{
  declare ctr integer;
  declare ses any;
  ses := string_output();
  http ('
<rdf:RDF
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
  xmlns:xsd="http://www.w3.org/2001/XMLSchema#"
  xmlns:owl="http://www.w3.org/2002/07/owl#"
  xmlns:virtrdf="http://www.openlinksw.com/schemas/virtrdf#"
  xmlns:dettest="' || base || '"
  xml:base="' || base || '" >
  <owl:Ontology rdf:about="' || base || '">
    <rdfs:label>An example of RDF schema with Virtuoso extensions for TEST_CatFilter.</rdfs:label>
    <rdfs:comment>This schema contains a set of properties that should be used by categorization of test resources.</rdfs:comment>
    <!-- document version -->
    <virtrdf:version>$$Id$$</virtrdf:version>
  </owl:Ontology>
', ses);

  for (ctr := 0; ctr < size; ctr := ctr + 1)
    {
  http ('
  <rdf:Property rdf:ID="prop' || cast (2000 + ctr as varchar) || '">
    <rdfs:Range rdf:resource="http://www.w3.org/2001/XMLSchema#varchar"/>
  </rdf:Property>
', ses );
    }

  http ('
</rdf:RDF>
', ses );

  DAV_RES_UPLOAD (addon_uri, string_output_string (ses), 'text/RDF+XML', '110100100R', 'dav', 'administrators', 'dav', 'dav' );
  DAV_REGISTER_RDF_SCHEMA (base, null, 'http://localdav.virt' || addon_uri, 'replacing');
}
;

create procedure TEST_CATFILTER_MAKE_SCHEMAS (in schema_count integer, in size integer)
{
  declare ctr integer;
  for (ctr := 0; ctr <= schema_count; ctr := ctr + 1)
    {
      declare mt, base0, base, addon_uri varchar;
      mt := sprintf ('test/mime%d', 1000 + ctr);
      base0 := 'http://www.openlinksw.com/schemas/DETtest_CatFilter1000#';
      base := sprintf ('http://www.openlinksw.com/schemas/DETtest_CatFilter%d#', 1000 + ctr);
      addon_uri := sprintf ('/DAV/DETtest_CatFilter/schema%d.rdf', 1000 + ctr);
      TEST_CATFILTER_MAKE_SCHEMA (base, addon_uri, size);
      DAV_REGISTER_MIME_TYPE (mt, 'Sample for DETtest_CatFilter', sprintf ('test%d', 1000 + ctr), 'test/mime1000', 'replacing');
      DAV_REGISTER_MIME_RDF (mt, base);
      DAV_REGISTER_MIME_RDF (mt, base0);
    }
}
;

create procedure TEST_CATFILTER_MAKE_USER (in cf_uname varchar)
{
  declare ctr integer;
  DAV_ADD_USER (cf_uname, cf_uname || '_pwd', 'DETtest_CatFilter', '110100000T', 0, '/DAV/home/' || cf_uname || '/', 'User 1 of group 1', cf_uname || '@localhost', 'dav', 'dav');
  DAV_COL_CREATE ('/DAV/home/' || cf_uname || '/', '110100000R', cf_uname, 'DETtest_CatFilter', 'dav', 'dav');
  for (ctr := 0; ctr < 10; ctr := ctr + 1)
    {
      DAV_COL_CREATE (sprintf ('/DAV/home/%s/private%d/', cf_uname, ctr), '110000000R', cf_uname, 'DETtest_CatFilter', 'dav', 'dav');
      DAV_COL_CREATE (sprintf ('/DAV/home/%s/group%d/', cf_uname, ctr), '110100000R', cf_uname, 'DETtest_CatFilter', 'dav', 'dav');
    }
}
;

create procedure TEST_CATFILTER_SINGLE_FILE (in cf_uname varchar, in uri varchar, in schema_idx integer, in schema_size integer)
{
  declare ctr integer;
  declare acc any;
  declare mt, base0, base, addon_uri varchar;
  --dbg_obj_princ ('TEST_CATFILTER_SINGLE_FILE (', cf_uname, uri, schema_idx, schema_size, ')');
  mt := sprintf ('test/mime%d', 1000 + schema_idx);
  base0 := 'http://www.openlinksw.com/schemas/DETtest_CatFilter1000#';
  base := sprintf ('http://www.openlinksw.com/schemas/DETtest_CatFilter%d#', 1000 + schema_idx);
  xte_nodebld_init (acc);
  for (ctr := 0; ctr < schema_size; ctr := ctr + 1)
    {
      xte_nodebld_acc (acc,
        xte_node (
          xte_head ('N3', 'N3S', 'http://local.virt/this',
	    'N3P', base || sprintf('prop%d', 2000 + ctr) ),
	  sprintf ('The value of property %d of schema %d, randomizer %d/4', 2000 + ctr, 1000 + schema_idx, rnd (4)) ) );
      xte_nodebld_acc (acc,
        xte_node (
          xte_head ('N3', 'N3S', 'http://local.virt/this',
	    'N3P', base || sprintf('prop%d', 2000 + ctr) ),
	  sprintf ('The value of property %d, randomizer %d/20', 2000 + ctr, rnd (20)) ) );
      xte_nodebld_acc (acc,
        xte_node (
          xte_head ('N3', 'N3S', 'http://local.virt/this',
	    'N3P', base0 || sprintf('prop%d', 2000 + ctr) ),
	  sprintf ('The value of property %d of schema %d, randomizer %d/4', 2000 + ctr, 1000 + schema_idx, rnd (4)) ) );
      xte_nodebld_acc (acc,
        xte_node (
          xte_head ('N3', 'N3S', 'http://local.virt/this',
	    'N3P', base0 || sprintf('prop%d', 2000 + ctr) ),
	  sprintf ('The value of property %d, randomizer %d/20', 2000 + ctr, rnd (20)) ) );
    }
  xte_nodebld_final (acc, xte_head (' root'));
  DAV_RES_UPLOAD (uri,
    '<html>This is ' || uri || '</html>',
    mt, '110100000R', cf_uname, 'DETtest_CatFilter', 'dav', 'dav' );
  DAV_PROP_SET_INT (uri, 'http://local.virt/DAV-RDF',
    DAV_RDF_PREPROCESS_RDFXML (xml_tree_doc (acc), N'http://local.virt/this', 1),
    'dav', 'dav', 0, 0, 1);
}
;

create procedure TEST_CATFILTER_INIT (in users_count integer, in files_per_user integer, in schema_count integer, in schema_size integer)
{
  declare user_ctr, ctr1, ctr2 integer;
  DAV_ADD_GROUP ('DETtest_CatFilter', 'dav', 'dav');
  DAV_COL_CREATE ('/DAV/DETtest_CatFilter/', '110100100R', 'dav', 'administrators', 'dav', 'dav');
  TEST_CATFILTER_MAKE_SCHEMAS (schema_count, schema_size);
  dbg_obj_princ ('TEST_CATFILTER_INIT: schemas done');
  for (user_ctr := 0; user_ctr < users_count; user_ctr := user_ctr + 1)
    {
      declare cf_uname varchar;
      cf_uname := sprintf ('cf%d', 10000 + user_ctr);
      TEST_CATFILTER_MAKE_USER (cf_uname);
    }
  dbg_obj_princ ('TEST_CATFILTER_INIT: users done');
  for (ctr1 := 0; ctr1 < files_per_user; ctr1 := ctr1 + 1)
    {
      declare colname varchar;
      colname := sprintf ('/%s%d/', case (rnd (1)) when 1 then 'private' else 'group' end, rnd(10));
      for (user_ctr := 0; user_ctr < users_count; user_ctr := user_ctr + 1)
	{
	  declare cf_uname varchar;
	  declare schema_idx integer;
          cf_uname := sprintf ('cf%d', 10000 + user_ctr);
	  schema_idx := rnd (schema_count + 1);
	  TEST_CATFILTER_SINGLE_FILE (cf_uname,
	    '/DAV/home/' || cf_uname || colname || sprintf ('file%d.test%d', ctr1, schema_idx),
	    schema_idx, schema_size );
	}
      commit work;
      dbg_obj_princ ('TEST_CATFILTER_INIT: files ', ctr1, '/', files_per_user);
    }
  dbg_obj_princ ('TEST_CATFILTER_INIT: files done');
}
;

DAV_COL_CREATE ('/DAV/home/', '110110000R', 'dav', 'administrators', 'dav', 'dav');

TEST_CATFILTER_INIT (
  3,	-- users
  200,	-- files per user
  20,	-- schemas
  10	-- properties per schema
  )
;
