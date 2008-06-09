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

--drop table DB.DBA.RDF_QUAD;
--drop table DB.DBA.RDF_OBJ;
--drop table DB.DBA.RDF_URL;
--drop table DB.DBA.RDF_DATATYPE;
--drop table DB.DBA.RDF_LANGUAGE;

-----
-- Database schema


create table DB.DBA.RDF_QUAD (
  G IRI_ID,
  S IRI_ID,
  P IRI_ID,
  O any,
  primary key (G,S,P,O)
  )
create bitmap index RDF_QUAD_OGPS on DB.DBA.RDF_QUAD (O, G, P, S)
;

--create trigger RDF_QUAD_O_AUDIT before insert on DB.DBA.RDF_QUAD
--{
--  if (not rdf_box_is_storeable (O))
--    signal ('RDFXX', 'non-storeable O');
--}
--;


create table DB.DBA.RDF_URL (
  RU_IID IRI_ID not null primary key,
  RU_QNAME varchar )
create unique index RU_QNAME on DB.DBA.RDF_URL (RU_QNAME)
;

--create table DB.DBA.RDF_PREFIX (RP_NAME varchar primary key, RP_ID int not null unique)
--;

--create table DB.DBA.RDF_IRI (RI_NAME varchar primary key, RI_ID IRI_ID not null unique)
--;

create table DB.DBA.RDF_OBJ (
  RO_ID integeR primary key,
  RO_VAL varchar,
  RO_LONG long varchar,
  RO_DIGEST any
)
create index RO_VAL on DB.DBA.RDF_OBJ (RO_VAL, RO_DIGEST)
;

--#IF VER=5
alter table DB.DBA.RDF_OBJ add RO_DIGEST any
;
--#ENDIF

create table DB.DBA.RDF_DATATYPE (
  RDT_IID IRI_ID not null primary key,
  RDT_TWOBYTE integer not null unique,
  RDT_QNAME varchar not null unique )
;

create table DB.DBA.RDF_LANGUAGE (
  RL_ID varchar not null primary key,
  RL_TWOBYTE integer not null unique )
;

create table DB.DBA.SYS_SPARQL_HOST (
  SH_HOST	varchar not null primary key,
  SH_GRAPH_URI	varchar,
  SH_USER_URI	varchar,
  SH_DEFINES	long varchar
)
;

--#IF VER=5
alter table DB.DBA.SYS_SPARQL_HOST add SH_DEFINES long varchar
;
--#ENDIF

create table DB.DBA.RDF_OBJ_FT_RULES (
  ROFR_G varchar not null,
  ROFR_P varchar not null,
  ROFR_REASON varchar not null,
  primary key (ROFR_G, ROFR_P, ROFR_REASON) )
;

create table DB.DBA.SYS_SPARQL_SW_LOG (
    PL_SERVER varchar,
    PL_URI    varchar,
    PL_TS     timestamp,
    PL_RC     varchar,
    PL_MSG    long varchar,
    primary key (PL_SERVER, PL_URI, PL_TS))
;

create table DB.DBA.SYS_XML_PERSISTENT_NS_DECL
(
  NS_PREFIX varchar not null primary key,
  NS_URL varchar not null
)
;

sequence_set ('RDF_URL_IID_NAMED', 1000000, 1)
;

sequence_set ('RDF_PREF_SEQ', 1, 1)
;

sequence_set ('RDF_URL_IID_BLANK', iri_id_num (min_bnode_iri_id ()), 1)
;

sequence_set ('RDF_URL_IID_NAMED_BLANK', iri_id_num (min_named_bnode_iri_id ()), 1)
;

sequence_set ('RDF_RO_ID', 1, 1)
;

sequence_set ('RDF_DATATYPE_TWOBYTE', 258, 1)
;

sequence_set ('RDF_LANGUAGE_TWOBYTE', 258, 1)
;

create procedure DB.DBA.RDF_OBJ_RO_DIGEST_INDEX_HOOK (inout vtb any, inout d_id any)
{
  for (select RO_LONG, RO_VAL, RO_DIGEST
    from DB.DBA.RDF_OBJ where RO_ID=d_id and RO_DIGEST is not null) do
    {
      if (__tag of XML = rdf_box_data_tag (RO_DIGEST))
        vt_batch_feed (vtb, xml_tree_doc (__xml_deserialize_packed (RO_LONG)), 0);
      else
        vt_batch_feed (vtb, coalesce (RO_LONG, RO_VAL), 0);
    }
  return 1;
}
;

create procedure DB.DBA.RDF_OBJ_RO_DIGEST_UNINDEX_HOOK (inout vtb any, inout d_id any)
{
  for (select RO_LONG, RO_VAL, RO_DIGEST
    from DB.DBA.RDF_OBJ where RO_ID=d_id and RO_DIGEST is not null) do
    {
      if (__tag of XML = rdf_box_data_tag (RO_DIGEST))
        vt_batch_feed (vtb, xml_tree_doc (__xml_deserialize_packed (RO_LONG)), 1);
      else
        vt_batch_feed (vtb, coalesce (RO_LONG, RO_VAL), 1);
    }
  return 1;
}
;

--!AWK PUBLIC
create function DB.DBA.XML_SET_NS_DECL (in prefix varchar, in url varchar, in persist integer := 1) returns integer
{
  declare res integer;
  res := __xml_set_ns_decl (prefix, url, persist);
  if (bit_and (res, 2))
    {
      insert soft DB.DBA.SYS_XML_PERSISTENT_NS_DECL (NS_PREFIX, NS_URL) values (prefix, url);
      commit work;
    }
  return res;
}
;

--!AWK PUBLIC
create procedure DB.DBA.XML_REMOVE_NS_BY_PREFIX (in prefix varchar, in persist integer := 1)
{
  declare res integer;
  __xml_remove_ns_by_prefix (prefix, persist);
  if (bit_and (persist, 2))
    {
      delete from DB.DBA.SYS_XML_PERSISTENT_NS_DECL where NS_PREFIX=prefix;
      commit work;
    }
}
;

--!AWK PUBLIC
create procedure DB.DBA.XML_CLEAR_ALL_NS_DECLS (in persist integer := 1)
{
  declare res integer;
  __xml_clear_all_ns_decls (persist);
  if (bit_and (persist, 2))
    {
      delete from DB.DBA.SYS_XML_PERSISTENT_NS_DECL;
      commit work;
    }
}
;

--!AWK PUBLIC
create procedure DB.DBA.XML_SELECT_ALL_NS_DECLS (in persist integer := 3)
{
  declare decls any;
  declare ctr, len integer;
  declare PREFIX, URI varchar;
  decls := __xml_get_all_ns_decls (persist);
  result_names (PREFIX, URI);
  len := length (decls);
  for (ctr := 0; ctr < len; ctr := ctr + 2)
    result (decls[ctr], decls[ctr+1]);
}
;

create procedure DB.DBA.XML_LOAD_ALL_NS_DECLS ()
{
  for (select NS_PREFIX, NS_URL from DB.DBA.SYS_XML_PERSISTENT_NS_DECL) do
    {
      __xml_set_ns_decl (NS_PREFIX, NS_URL, 2);
    }
}
;

DB.DBA.XML_LOAD_ALL_NS_DECLS ()
;

rdf_inf_const_init ()
;

create procedure DB.DBA.RDF_LOAD_ALL_FT_RULES ()
{
  whenever sqlstate '*' goto again;
again:
  for (select ROFR_G as rule_g, ROFR_P as rule_p, ROFR_REASON as reason from DB.DBA.RDF_OBJ_FT_RULES) do
    {
      declare rule_g_iid, rule_p_iid IRI_ID;
      rule_g_iid := case (rule_g) when '' then null else iri_to_id (rule_g, 1) end;
      rule_p_iid := case (rule_p) when '' then null else iri_to_id (rule_p, 1) end;
      -- dbg_obj_princ ('__rdf_obj_ft_rule_add (', rule_g_iid, rule_p_iid, reason, ')');
      __rdf_obj_ft_rule_add (rule_g_iid, rule_p_iid, reason);
    }
}
;

DB.DBA.RDF_LOAD_ALL_FT_RULES ()
;

create procedure DB.DBA.RDF_GLOBAL_RESET (in hard integer := 0)
{
--  checkpoint;
  __atomic (1);
  iri_id_cache_flush ();
  __rdf_obj_ft_rule_zap_all ();
  for select rs_name from sys_rdf_schema do
    rdf_inf_clear (rs_name);
  delete from sys_rdf_schema;
  delete from DB.DBA.RDF_QUAD;
  delete from DB.DBA.RDF_OBJ_FT_RULES;
  if (hard)
    {
      delete from DB.DBA.RDF_URL;
      delete from DB.DBA.RDF_IRI;
      delete from DB.DBA.RDF_PREFIX;
      delete from DB.DBA.RDF_OBJ;
      delete from DB.DBA.RDF_DATATYPE;
      delete from DB.DBA.RDF_LANGUAGE;
      delete from DB.DBA.VTLOG_DB_DBA_RDF_OBJ;
      delete from DB.DBA.RDF_OBJ_RO_DIGEST_WORDS;
      sequence_set ('RDF_URL_IID_NAMED', 1000000, 0);
      sequence_set ('RDF_URL_IID_BLANK', iri_id_num (min_bnode_iri_id ()), 0);
      sequence_set ('RDF_URL_IID_NAMED_BLANK', iri_id_num (min_named_bnode_iri_id ()), 0);
      sequence_set ('RDF_PREF_SEQ', 1, 0);
      sequence_set ('RDF_RO_ID', 1, 0);
      sequence_set ('RDF_DATATYPE_TWOBYTE', 258, 0);
      sequence_set ('RDF_LANGUAGE_TWOBYTE', 258, 0);
      __atomic (0);
      exec ('checkpoint');
      raw_exit ();
    }
  sequence_set ('RDF_URL_IID_NAMED', 1000000, 1);
  sequence_set ('RDF_URL_IID_BLANK', iri_id_num (min_bnode_iri_id ()), 1);
  sequence_set ('RDF_URL_IID_NAMED_BLANK', iri_id_num (min_named_bnode_iri_id ()), 1);
  sequence_set ('RDF_PREF_SEQ', 1, 1);
  sequence_set ('RDF_RO_ID', 1, 1);
  sequence_set ('RDF_DATATYPE_TWOBYTE', 258, 1);
  sequence_set ('RDF_LANGUAGE_TWOBYTE', 258, 1);
  DB.DBA.RDF_LOAD_ALL_FT_RULES ();
  DB.DBA.TTLP (
    cast ( DB.DBA.XML_URI_GET (
        'http://www.openlinksw.com/sparql/virtrdf-data-formats.ttl', '' ) as varchar ),
    '', 'http://www.openlinksw.com/schemas/virtrdf#' );
  DB.DBA.TTLP ('
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix owl: <http://www.w3.org/2002/07/owl#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
@prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#> .
@prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#> .
@prefix atom: <http://atomowl.org/ontologies/atomrdf#> .

virtrdf:DefaultQuadStorage
  rdf:type virtrdf:QuadStorage ;
  virtrdf:qsUserMaps virtrdf:DefaultQuadStorage-UserMaps ;
  virtrdf:qsDefaultMap virtrdf:DefaultQuadMap ;
  virtrdf:qsMatchingFlags virtrdf:SPART_QS_NO_IMPLICIT_USER_QM .
virtrdf:DefaultQuadStorage-UserMaps
      rdf:type virtrdf:array-of-QuadMap .
  ', '', 'http://www.openlinksw.com/schemas/virtrdf#' );
  delete from SYS_HTTP_SPONGE where HS_PARSER = 'DB.DBA.RDF_LOAD_HTTP_RESPONSE';
  commit work;
  sequence_set ('RDF_URL_IID_NAMED', 1010000, 1);
  sequence_set ('RDF_URL_IID_BLANK', iri_id_num (min_bnode_iri_id ()) + 10000, 1);
  sequence_set ('RDF_URL_IID_NAMED_BLANK', iri_id_num (min_named_bnode_iri_id ()) + 10000, 1);
  sequence_set ('RDF_PREF_SEQ', 101, 1);
  sequence_set ('RDF_RO_ID', 1001, 1);
  iri_id_cache_flush ();
  DB.DBA.SPARQL_RELOAD_QM_GRAPH ();
  __atomic (0);
  exec ('checkpoint');
}
;

create procedure DB.DBA.RDF_64BIT_UPGRADE ()
{
  declare stat, msg varchar;
  if (min_bnode_iri_id() = #ib0)
    signal ('22023', 'DB.DBA.RDF_64BIT_UPGRADE () is called, but the RDF storage is 64-bit already');
  whenever sqlstate '*' goto kill_server;
  -- dbg_obj_princ ('__atomic(1) ...');
  __atomic (1);
  -- dbg_obj_princ ('iri_id_cache_flush () ...');
  iri_id_cache_flush ();
  set triggers off;
  -- dbg_obj_princ ('drop indexes...');
  exec ('drop index RDF_QUAD_OGPS');
  exec ('drop index RU_QNAME');
  exec ('drop index DB_DBA_RDF_DATATYPE_UNQC_RDT_TWOBYTE', stat, msg);
  exec ('drop index RDT_TWOBYTE', stat, msg);
  exec ('drop index RO_VAL');
  -- dbg_obj_princ ('create new tables...');
  exec ('create table DB.DBA.RDF_QUAD_NEW (
  G IRI_ID_8,
  S IRI_ID_8,
  P IRI_ID_8,
  O any,
  primary key (G,S,P,O)
  )');
  exec ('create table DB.DBA.RDF_URL_NEW (
  RU_IID IRI_ID_8 not null primary key,
  RU_QNAME varchar )');
  exec ('create table DB.DBA.RDF_DATATYPE_NEW (
  RDT_IID IRI_ID_8 not null primary key,
  RDT_TWOBYTE integer not null,
  RDT_QNAME varchar not null )');
  exec ('create table DB.DBA.RDF_OBJ_NEW (
  RO_ID integeR primary key,
  RO_VAL varchar,
  RO_LONG long varchar,
  RO_DIGEST any )');
  exec ('create table DB.DBA.RDF_OBJ_RO_DIGEST_WORDS_NEW (
  VT_WORD varchar,
  VT_D_ID integer,
  VT_D_ID_2 integer,
  VT_DATA varchar,
  VT_LONG_DATA long varchar,
  primary key (VT_WORD, VT_D_ID, VT_D_ID_2) )');
  -- dbg_obj_princ ('data copying...');
  exec ('create procedure DB.DBA.RDF_64BIT_UPGRADE_I () {
    for (select G as g_old, S as s_old, P as p_old, O as o_old from RDF_QUAD) do
      {
        insert into DB.DBA.RDF_QUAD_NEW (G,S,P,O) values (
          iri_id_bnode32_to_bnode64 (g_old),
          iri_id_bnode32_to_bnode64 (s_old),
          iri_id_bnode32_to_bnode64 (p_old),
          iri_id_bnode32_to_bnode64 (o_old) );
      }
    for (select RU_IID as ru_iid_old, RU_QNAME ru_qname_old from DB.DBA.RDF_URL) do
      {
        insert into DB.DBA.RDF_URL_NEW (RU_IID, RU_QNAME) values (
          ru_iid_old, ru_qname_old );
      }
    for (select RDT_IID as rdt_iid_old, RDT_TWOBYTE as rdt_twobyte_old,
        RDT_QNAME as rdt_qname_old from DB.DBA.RDF_DATATYPE) do
      {
        insert into DB.DBA.RDF_DATATYPE_NEW (RDT_IID, RDT_TWOBYTE, RDT_QNAME)
          values (rdt_iid_old, rdt_twobyte_old, rdt_qname_old);
      }
    for (select RO_ID as ro_id_old, RO_VAL as ro_val_old, RO_LONG as ro_long_old,
        RO_DIGEST as ro_digest_old from DB.DBA.RDF_OBJ) do
      {
        insert into DB.DBA.RDF_OBJ_NEW (RO_ID, RO_VAL, RO_LONG, RO_DIGEST)
          values (ro_id_old, ro_val_old, ro_long_old, ro_digest_old);
      }
    for (select VT_WORD as vt_word_old, VT_D_ID as vt_d_id_old, VT_D_ID_2 as vt_d_id_2_old,
        VT_DATA as vt_data_old, VT_LONG_DATA vt_long_data_old
        from DB.DBA.RDF_OBJ_RO_DIGEST_WORDS ) do
      {
        insert into DB.DBA.RDF_OBJ_RO_DIGEST_WORDS_NEW (VT_WORD, VT_D_ID, VT_D_ID_2, VT_DATA, VT_LONG_DATA)
          values (vt_word_old, vt_d_id_old, vt_d_id_2_old, vt_data_old, vt_long_data_old);
      }
  }');
  exec ('DB.DBA.RDF_64BIT_UPGRADE_I ()');
  -- dbg_obj_princ ('permissions copying...');
  for (select G_USER as g_user_old, G_OP as g_op_old, G_OBJECT as g_object_old,
      G_COL as g_col_old, G_GRANTOR as g_grantor_old, G_ADMIN_OPT as g_admin_opt_old
      from DB.DBA.SYS_GRANTS
      where G_OBJECT in ('DB.DBA.RDF_OBJ', 'DB.DBA.RDF_OBJ_RO_DIGEST_WORDS',
          'DB.DBA.RDF_QUAD', 'DB.DBA.RDF_URL', 'DB.DBA.RDF_DATATYPE') ) do
    {
      insert soft DB.DBA.SYS_GRANTS (G_USER, G_OP, G_OBJECT, G_COL, G_GRANTOR, G_ADMIN_OPT)
      values (g_user_old, g_op_old, g_object_old || '_NEW', g_col_old, g_grantor_old, g_admin_opt_old);
    }
  -- dbg_obj_princ ('drop old tables...');
  exec ('drop table DB.DBA.RDF_OBJ_RO_DIGEST_WORDS');
  exec ('drop table DB.DBA.RDF_OBJ');
  exec ('drop table DB.DBA.RDF_QUAD');
  exec ('drop table DB.DBA.RDF_URL');
  exec ('drop table DB.DBA.RDF_DATATYPE');
  -- dbg_obj_princ ('rename new tables to original names...');
  exec ('alter table DB.DBA.RDF_QUAD_NEW rename DB.DBA.RDF_QUAD');
  exec ('alter table DB.DBA.RDF_URL_NEW rename DB.DBA.RDF_URL');
  exec ('alter table DB.DBA.RDF_DATATYPE_NEW rename DB.DBA.RDF_DATATYPE');
  exec ('alter table DB.DBA.RDF_OBJ_NEW rename DB.DBA.RDF_OBJ');
  exec ('alter table DB.DBA.RDF_OBJ_RO_DIGEST_WORDS_NEW rename DB.DBA.RDF_OBJ_RO_DIGEST_WORDS');
  -- dbg_obj_princ ('create indexes...');
  exec ('create bitmap index RDF_QUAD_OGPS on DB.DBA.RDF_QUAD (O, G, P, S)');
  exec ('create unique index RU_QNAME on DB.DBA.RDF_URL (RU_QNAME)');
  exec ('create unique index RDT_TWOBYTE on DB.DBA.RDF_DATATYPE (RDT_TWOBYTE)');
  exec ('create index RO_VAL on DB.DBA.RDF_OBJ (RO_VAL, RO_DIGEST)');
  -- dbg_obj_princ ('final __set_64bit_min_bnode_iri_id ()...');
  __set_64bit_min_bnode_iri_id ();
  sequence_set ('RDF_URL_IID_BLANK',
    iri_id_num ( iri_id_bnode32_to_bnode64 (
        iri_id_from_num (sequence_next ('RDF_URL_IID_BLANK')) ) ),
    1 );
  -- dbg_obj_princ ('checkpoint');
  exec ('checkpoint');
  log_message ('DB.DBA.RDF_64BIT_UPGRADE () has changed tables of RDF storage, now all ID columns are 64-bit wide');
  log_message ('For security reasons, this operation requires database server shutdown. Bye.');
  raw_exit ();
  return;

kill_server:
  log_message ('DB.DBA.RDF_64BIT_UPGRADE () failed: ' || __SQL_STATE || ': ' || __SQL_MESSAGE);
  log_message ('Remove the transaction log and start previous version of Virtuoso.');
  log_message ('You may use the database with new version of Virtuoso server for');
  log_message ('diagnostics and error recovery; to make it possible, add parameter');
  log_message ('"RecoveryMode=1" to the [SPARQL] section of ' || virtuoso_ini_path ());
  log_message ('and restart the server; remove the parameter and restart as soon as possible');
  log_message ('This error is critical. The server will now exit. Sorry.');
  raw_exit ();
}
;

-----
-- Handling of IRI IDs

create function DB.DBA.RDF_MAKE_IID_OF_QNAME (in qname varchar) returns IRI_ID
{
  return iri_to_id (qname, 1);
}
;

create procedure DB.DBA.RDF_MIGRATE_URL_TO_IRI ()
{
  declare ctr integer;
  declare iid IRI_ID;
  declare qname, tail varchar;
  __atomic (1);
  declare exit handler for sqlstate '*'
    {
      __atomic (0);
      resignal;
    };
  if (not exists (select top 1 1 from DB.DBA.RDF_URL))
    goto rdf_url_is_empty;

again:
  ctr := 0;
  declare cr cursor for select RU_IID, RU_QNAME from DB.DBA.RDF_URL for update;
  open cr (exclusive);
  whenever not found goto rdf_url_is_empty;

next_fetch:
  fetch cr into iid, qname;
  declare parts any;
  declare prefix_id integer;
  parts := iri_to_rdf_prefix_and_local (qname);
  if (parts is null)
    {
      log_message ('The function DB.DBA.RDF_MIGRATE_URL_TO_IRI() can not migrate an abnormally long URL.');
      log_message ('This means that this version of Virtuoso server can not process RDF data stored in the database.');
      log_message ('To fix the problem, remove the transaction log and start previous version of Virtuoso.');
      log_message ('The example of unsupported RDF node URL is');
      log_message (qname);
      log_message ('This error is critical. The server will now exit. Sorry.');
      raw_exit();
    }
  prefix_id := (select RP_ID from DB.DBA.RDF_PREFIX where RP_NAME = parts[0]);
  if (prefix_id is null)
    {
      prefix_id := sequence_next ('RDF_PREF_SEQ');
      insert into DB.DBA.RDF_PREFIX (RP_NAME, RP_ID) values (parts[0], prefix_id);
    }
  tail := parts[1];
  tail[0] := bit_and (255, bit_shift (prefix_id, -24));
  tail[1] := bit_and (255, bit_shift (prefix_id, -16));
  tail[2] := bit_and (255, bit_shift (prefix_id, -8));
  tail[3] := bit_and (255, prefix_id);
  insert into DB.DBA.RDF_IRI (RI_NAME, RI_ID) values (tail, iid);
  delete from DB.DBA.RDF_URL where current of cr;
  ctr := ctr + 1;
  if (ctr > 1000)
    {
      commit work;
      close cr;
      goto again;
    }
  goto next_fetch;

rdf_url_is_empty:

  if (exists (select top 1 1 from DB.DBA.RDF_DATATYPE where RDT_TWOBYTE < 512 and RDT_QNAME[0] < 32))
    update DB.DBA.RDF_DATATYPE set RDT_QNAME = id_to_iri (RDT_IID) where RDT_QNAME[0] < 32;
  commit work;
  __atomic (0);
}
;

DB.DBA.RDF_MIGRATE_URL_TO_IRI ()
;

create function DB.DBA.RDF_MAKE_IID_OF_QNAME_SAFE (in qname any) returns IRI_ID
{
  whenever sqlstate '*' goto retnull;
  return iri_to_id (qname, 1);
retnull:
  return null;
}
;

create function DB.DBA.RDF_MAKE_IID_OF_LONG (in qname any) returns IRI_ID
{
  if (isiri_id (qname))
    return qname;
  if (not isstring (qname))
    {
      if (__tag of rdf_box = __tag (qname) and rdf_box_is_complete (qname))
        qname := rdf_box_data (qname, 1);
      else
        qname := DB.DBA.RDF_STRSQLVAL_OF_LONG (qname);
    }
  whenever sqlstate '*' goto retnull;
  return iri_to_id (qname, 1);
retnull:
  return null;
}
;

create function DB.DBA.RDF_QNAME_OF_IID (in iid IRI_ID) returns varchar -- DEPRECATED
{
  return id_to_iri_nosignal (iid);
}
;

create function DB.DBA.RDF_MAKE_GRAPH_IIDS_OF_QNAMES (in qnames any) returns any
{
  if (__tag of vector <> __tag (qnames))
    return vector ();
  declare res_acc any;
  vectorbld_init (res_acc);
  foreach (any qname in qnames) do
    {
      declare iid IRI_ID;
      whenever sqlstate '*' goto skip_acc;
      iid := iri_to_id (qname, 0, 0);
      if (not isinteger (iid))
        vectorbld_acc (res_acc, iid);
skip_acc: ;
    }
  vectorbld_final (res_acc);
  return res_acc;
}
;

-----
-- Datatypes and languages

create function DB.DBA.RDF_TWOBYTE_OF_DATATYPE (in iid IRI_ID) returns integer
{
  declare res integer;
  if (iid is null)
    return 257;
  if (not isiri_id (iid))
    {
      declare new_iid IRI_ID;
      new_iid := iri_to_id (iid, 1);
      if (new_iid is NULL or new_iid >= min_bnode_iri_id ())
        signal ('RDFXX', 'Invalid datatype IRI_ID passes as an argument to DB.DBA.RDF_TWOBYTE_OF_DATATYPE()');
      iid := new_iid;
    }
  whenever not found goto mknew;
  set isolation='committed';
  select RDT_TWOBYTE into res from DB.DBA.RDF_DATATYPE where RDT_IID = iid;
  return res;

mknew:
  set isolation='serializable';
  declare tb_cr cursor for select RDT_TWOBYTE from DB.DBA.RDF_DATATYPE where RDT_IID = iid;
  open tb_cr (exclusive);
  whenever not found goto mknew_ser;
  fetch tb_cr into res;
  return res;

mknew_ser:
  res := sequence_next ('RDF_DATATYPE_TWOBYTE');
  if (0 = bit_and (res, 255))
    res := sequence_next ('RDF_DATATYPE_TWOBYTE');
  insert into DB.DBA.RDF_DATATYPE
    (RDT_IID, RDT_TWOBYTE, RDT_QNAME)
  values (iid, res, id_to_iri (iid));
  return res;
}
;

create function DB.DBA.RDF_TWOBYTE_OF_LANGUAGE (in id varchar) returns integer
{
  declare res integer;
  if (id is null)
    return 257;
  id := lower (id);
  whenever not found goto mknew;
  set isolation='committed';
  select RL_TWOBYTE into res from DB.DBA.RDF_LANGUAGE where RL_ID = id;
  return res;

mknew:
  set isolation='serializable';
  declare tb_cr cursor for select RL_TWOBYTE from DB.DBA.RDF_LANGUAGE where RL_ID = id;
  open tb_cr (exclusive);
  whenever not found goto mknew_ser;
  fetch tb_cr into res;
  return res;

mknew_ser:
  res := sequence_next ('RDF_LANGUAGE_TWOBYTE');
  if (0 = bit_and (res, 255))
    res := sequence_next ('RDF_LANGUAGE_TWOBYTE');
  insert into DB.DBA.RDF_LANGUAGE (RL_ID, RL_TWOBYTE) values (id, res);
  return res;
}
;

-----
-- Conversions from and to _table fields_ in short representation

create function DB.DBA.RQ_LONG_OF_O (in o_col any) returns any -- DEPRECATED
{
  return __rdf_long_of_obj (o_col);
}
;

create procedure DB.DBA.RDF_BOX_COMPLETE (inout o_col any) -- DEPRECATED
{
  __rdf_box_make_complete (o_col);
}
;

create function DB.DBA.RQ_SQLVAL_OF_O (in o_col any) returns any -- DEPRECATED
{
  return __rdf_sqlval_of_obj (o_col);
}
;

create function DB.DBA.RQ_BOOL_OF_O (in o_col any) returns any
{
  declare t, len integer;
  if (isiri_id (o_col))
    return NULL;
  if (isinteger (o_col))
    {
      if (o_col)
        return 1;
      return 0;
    }
  if (__tag of rdf_box = __tag (o_col))
    {
      declare twobyte integer;
      declare dtqname any;
      if (__tag of varchar <> rdf_box_data_tag (o_col))
        {
          whenever sqlstate '*' goto retnull;
          return neq (rdf_box_data (o_col), 0.0);
        }
      twobyte := rdf_box_type (o_col);
      if (257 = twobyte)
        goto type_ok;
      whenever not found goto badtype;
      select RDT_QNAME into dtqname from DB.DBA.RDF_DATATYPE where RDT_TWOBYTE = twobyte;
      if (dtqname <> UNAME'http://www.w3.org/2001/XMLSchema#string')
        return null;

type_ok:
      return case (length (rdf_box_data (o_col))) when 0 then 0 else 1 end;

badtype:
      signal ('RDFXX', sprintf ('Unknown datatype in DB.DBA.RQ_BOOL_OF_O, bad string "%s"', o_col));
    }
  if (o_col is null)
    return null;
  whenever sqlstate '*' goto retnull;
  return neq (o_col, 0.0);
retnull:
  return null;
}
;

create function DB.DBA.RQ_IID_OF_O (in shortobj any) returns IRI_ID -- DEPRECATED
{
  return id_to_iri_nosignal (shortobj);
}
;

create function DB.DBA.RQ_O_IS_LIT (in shortobj any) returns integer -- DEPRECATED
{
  if (isiri_id (shortobj))
    return 0;
  return 1;
}
;

-----
-- Conversions from and to values in short representation that may be not field values (may perform more validation checks)

create function DB.DBA.RDF_OBJ_ADD (in dt_twobyte integeR, in v varchar, in lang_twobyte integeR, in ro_id_dict any := null) returns varchar
{
  declare llong, id, need_digest integer;
  declare digest, old_digest any;
  -- dbg_obj_princ ('DB.DBA.RDF_OBJ_ADD (', dt_twobyte, v, lang_twobyte, case (isnull (ro_id_dict)) when 1 then '/*no_ft*/' else '/*want_ft*/' end,')');
  if (126 = __tag (v))
    v := blob_to_string (v);
      need_digest := rdf_box_needs_digest (v, ro_id_dict);
  if (__tag of rdf_box = __tag (v))
    {
      if (0 = need_digest)
        return v;
      if (1 = need_digest)
        {
          if (0 <> rdf_box_ro_id (v))
            return v;
        }
      dt_twobyte := rdf_box_type (v);
      lang_twobyte := rdf_box_lang (v);
      v := __rdf_sqlval_of_obj (v, 1);
    }
  else
    {
      if (dt_twobyte <> 257 or lang_twobyte <> 257)
        need_digest := 3;
      else if (0 = need_digest)
        return v;
      if (dt_twobyte < 257)
        signal ('RDFXX', sprintf ('Bad datatype code: DB.DBA.RDF_OBJ_ADD (%d, %s, %d)',
          dt_twobyte, "LEFT" (cast (v as varchar), 100), lang_twobyte) );
      if (lang_twobyte < 257)
        signal ('RDFXX', sprintf ('Bad lang code: DB.DBA.RDF_OBJ_ADD (%d, %s, %d)',
          dt_twobyte, "LEFT" (cast (v as varchar), 100), lang_twobyte) );
    }
  if (not isstring (v))
    {
      declare sum64 varchar;
      if (__tag of XML <> __tag (v))
        signal ('RDFXX', sprintf ('Bad call: DB.DBA.RDF_OBJ_ADD (%d, %s, %d)',
          dt_twobyte, "LEFT" (cast (v as varchar), 100), lang_twobyte) );
      sum64 := xtree_sum64 (v);
      whenever not found goto serializable_xtree;
      set isolation='committed';
      select RO_ID, RO_DIGEST into id, old_digest
      from DB.DBA.RDF_OBJ table option (index RO_VAL)
      where RO_VAL = sum64
      and equ (dt_twobyte, case (isnull (RO_DIGEST)) when 0 then rdf_box_type (RO_DIGEST) else 257 end)
      and equ (lang_twobyte, case (isnull (RO_DIGEST)) when 0 then rdf_box_lang (RO_DIGEST) else 257 end)
      and rdf_box_data_tag (RO_DIGEST) = __tag of XML;
      --!TBD ... and paranoid check

      goto found_xtree;
serializable_xtree:
      whenever not found goto new_xtree;
      set isolation='serializable';
      declare id_cr cursor for
        select RO_ID, RO_DIGEST from DB.DBA.RDF_OBJ table option (index RO_VAL) where RO_VAL = sum64
        and equ (dt_twobyte, case (isnull (RO_DIGEST)) when 0 then rdf_box_type (RO_DIGEST) else 257 end)
        and equ (lang_twobyte, case (isnull (RO_DIGEST)) when 0 then rdf_box_lang (RO_DIGEST) else 257 end)
      and rdf_box_data_tag (RO_DIGEST) = __tag of XML;
      --!TBD ... and paranoid check
      open id_cr (exclusive);
      fetch id_cr into id, old_digest;
found_xtree:
      digest := old_digest;
      if (ro_id_dict is not null)
        dict_put (ro_id_dict, id, 1);
      if (not (rdf_box_is_storeable (digest)))
        signal ('RDFX2', 'DB.DBA.RDF_OBJ_ADD() tries to return bad digest');
      return digest;
      -- goto recheck;
new_xtree:
      id := sequence_next ('RDF_RO_ID');
      digest := rdf_box (v, dt_twobyte, lang_twobyte, id, 1);
      insert into DB.DBA.RDF_OBJ (RO_ID, RO_VAL, RO_LONG, RO_DIGEST) values (id, sum64, __xml_serialize_packed (v), digest);
      if (ro_id_dict is not null)
        dict_put (ro_id_dict, id, 1);
      if (not (rdf_box_is_storeable (digest)))
        signal ('RDFX3', 'DB.DBA.RDF_OBJ_ADD() tries to return bad digest');
      return digest;
      -- old_digest := null;
      -- goto recheck;
    }
  if ((dt_twobyte = 257) and (lang_twobyte = 257) and (length (v) <= 20))
    {
      if (1 >= need_digest)
        return v;
      whenever not found goto serializable_veryshort;
      set isolation='committed';
      select RO_ID into id
      from DB.DBA.RDF_OBJ table option (index RO_VAL)
      where RO_VAL = v and RO_DIGEST = v;
      goto found_veryshort;
serializable_veryshort:
      whenever not found goto new_veryshort;
      set isolation='serializable';
      declare id_cr cursor for select RO_ID
      from DB.DBA.RDF_OBJ table option (index RO_VAL)
      where RO_VAL = v and RO_DIGEST = v;
      open id_cr (exclusive);
      fetch id_cr into id;
found_veryshort:
      if (ro_id_dict is not null)
        dict_put (ro_id_dict, id, 1);
      if (not (rdf_box_is_storeable (v)))
        signal ('RDFX4', 'DB.DBA.RDF_OBJ_ADD() tries to return bad digest');
      return v;
      -- digest := v;
      -- goto recheck;
new_veryshort:
      id := sequence_next ('RDF_RO_ID');
      insert into DB.DBA.RDF_OBJ (RO_ID, RO_VAL, RO_DIGEST) values (id, v, v);
      if (ro_id_dict is not null)
        dict_put (ro_id_dict, id, 1);
      if (not (rdf_box_is_storeable (v)))
        signal ('RDFX5', 'DB.DBA.RDF_OBJ_ADD() tries to return bad digest');
      return v;
      -- digest := v;
      -- old_digest := null;
      -- goto recheck;
    }
  llong := 1010;
  if (length (v) > llong)
    {
      declare tridgell varchar;
      tridgell := tridgell32 (v, 1);
      whenever not found goto serializable_long;
      set isolation='committed';
      select RO_ID, RO_DIGEST into id, old_digest
      from DB.DBA.RDF_OBJ table option (index RO_VAL)
      where RO_VAL = tridgell
      and equ (dt_twobyte, case (isnull (RO_DIGEST)) when 0 then rdf_box_type (RO_DIGEST) else 257 end)
      and equ (lang_twobyte, case (isnull (RO_DIGEST)) when 0 then rdf_box_lang (RO_DIGEST) else 257 end)
      and blob_to_string (RO_LONG) = v;
      goto found_long;
serializable_long:
      whenever not found goto new_long;
      set isolation='serializable';
      declare id_cr cursor for
        select RO_ID, RO_DIGEST from DB.DBA.RDF_OBJ table option (index RO_VAL) where RO_VAL = tridgell
        and equ (dt_twobyte, case (isnull (RO_DIGEST)) when 0 then rdf_box_type (RO_DIGEST) else 257 end)
        and equ (lang_twobyte, case (isnull (RO_DIGEST)) when 0 then rdf_box_lang (RO_DIGEST) else 257 end)
        and blob_to_string (RO_LONG) = v;
      open id_cr (exclusive);
      fetch id_cr into id, old_digest;
found_long:
      if (old_digest is null)
        {
          digest := rdf_box (v, dt_twobyte, lang_twobyte, id, 1);
          if (1 < need_digest)
            update DB.DBA.RDF_OBJ set RO_DIGEST = digest where RO_ID = id;
        }
      else
        digest := old_digest;
      if (ro_id_dict is not null)
        dict_put (ro_id_dict, id, 1);
      if (not (rdf_box_is_storeable (digest)))
        signal ('RDFX6', 'DB.DBA.RDF_OBJ_ADD() tries to return bad digest');
      return digest;
      -- goto recheck;
new_long:
      id := sequence_next ('RDF_RO_ID');
      digest := rdf_box (v, dt_twobyte, lang_twobyte, id, 1);
      if (1 < need_digest)
        insert into DB.DBA.RDF_OBJ (RO_ID, RO_VAL, RO_LONG, RO_DIGEST) values (id, tridgell, v, digest);
      else
        {
          set triggers off;
          insert into DB.DBA.RDF_OBJ (RO_ID, RO_VAL, RO_LONG) values (id, tridgell, v);
          set triggers on;
        }
      if (ro_id_dict is not null)
        dict_put (ro_id_dict, id, 1);
      if (not (rdf_box_is_storeable (digest)))
        signal ('RDFX7', 'DB.DBA.RDF_OBJ_ADD() tries to return bad digest');
      return digest;
      -- old_digest := null;
      -- goto recheck;
    }
  else
    {
      whenever not found goto serializable_short;
      set isolation='committed';
      select RO_ID, RO_DIGEST into id, old_digest
      from DB.DBA.RDF_OBJ table option (index RO_VAL)
      where RO_VAL = v
      and equ (dt_twobyte, case (isnull (RO_DIGEST)) when 0 then rdf_box_type (RO_DIGEST) else 257 end)
      and equ (lang_twobyte, case (isnull (RO_DIGEST)) when 0 then rdf_box_lang (RO_DIGEST) else 257 end);
      goto found_short;
serializable_short:
      whenever not found goto new_short;
      set isolation='serializable';
      declare id_cr cursor for select RO_ID, RO_DIGEST
      from DB.DBA.RDF_OBJ table option (index RO_VAL)
      where RO_VAL = v
      and equ (dt_twobyte, case (isnull (RO_DIGEST)) when 0 then rdf_box_type (RO_DIGEST) else 257 end)
      and equ (lang_twobyte, case (isnull (RO_DIGEST)) when 0 then rdf_box_lang (RO_DIGEST) else 257 end);
      open id_cr (exclusive);
      fetch id_cr into id, old_digest;
found_short:
      if (old_digest is null)
        {
          digest := rdf_box (v, dt_twobyte, lang_twobyte, id, 1);
          if (1 < need_digest)
            update DB.DBA.RDF_OBJ set RO_DIGEST = digest where RO_ID = id;
        }
      else
        digest := old_digest;
      if (ro_id_dict is not null)
        dict_put (ro_id_dict, id, 1);
      if (not (rdf_box_is_storeable (digest)))
        signal ('RDFX8', 'DB.DBA.RDF_OBJ_ADD() tries to return bad digest');
      return digest;
      -- goto recheck;
new_short:
      id := sequence_next ('RDF_RO_ID');
      digest := rdf_box (v, dt_twobyte, lang_twobyte, id, 1);
      if (1 < need_digest)
        insert into DB.DBA.RDF_OBJ (RO_ID, RO_VAL, RO_DIGEST) values (id, v, digest);
      else
        {
          set triggers off;
          insert into DB.DBA.RDF_OBJ (RO_ID, RO_VAL) values (id, v);
          set triggers on;
        }
      if (ro_id_dict is not null)
        dict_put (ro_id_dict, id, 1);
      if (not (rdf_box_is_storeable (digest)))
        signal ('RDFX9', 'DB.DBA.RDF_OBJ_ADD() tries to return bad digest');
      return digest;
      -- old_digest := null;
      -- goto recheck;
    }
recheck:
  -- dbg_obj_princ ('recheck: id=', id, ', old_digest=', old_digest, ', need_digest=', need_digest, ', digest=', digest);
  signal ('FUNNY', 'Debug code of DB.DBA.RDF_OBJ_ADD() is reached. This can not happen (I believe). Please report this error.');
  --if (not need_digest and old_digest is null)
  --  return digest;
  --if (not exists (select top 1 1
  --  from DB.DBA.RDF_OBJ as a table option (index RDF_OBJ)
  --  where (a.RO_ID = id) option (LOOP) ))
  --  signal ('RDFXX', sprintf ('Lost RO_ID index entry (lookup): RO_ID=%d (digest=%U)', id, serialize (digest)));
  --if (not exists (select top 1 1
  --  from DB.DBA.RDF_OBJ as a table option (index RO_DIGEST)
  --  where (a.RO_DIGEST = digest) option (LOOP) ))
  --  signal ('RDFXX', sprintf ('Lost RO_DIGEST index entry (lookup): RO_DIGEST=%U (id=%d)', serialize (digest), id));
  --if (not exists (select top 1 1
  --  from DB.DBA.RDF_OBJ as a table option (index RDF_OBJ)
  --  join DB.DBA.RDF_OBJ as b table option (index RO_DIGEST)
  --  on ((a.RO_DIGEST = b.RO_DIGEST) or (a.RO_DIGEST is null and b.RO_DIGEST is null))
  --  where (a.RO_ID = id) option (LOOP) ))
  --  signal ('RDFXX', sprintf ('Lost RO_DIGEST index entry (LOOP join): RO_ID=%d (digest=%U)', id, serialize (digest)));
  --if (not exists (select top 1 1
  --  from DB.DBA.RDF_OBJ as a table option (index RO_DIGEST)
  --  join DB.DBA.RDF_OBJ as b table option (index RDF_OBJ)
  --  on ((a.RO_DIGEST = b.RO_DIGEST) or (a.RO_DIGEST is null and b.RO_DIGEST is null))
  --  where (a.RO_DIGEST = digest) option (LOOP) ))
  --  signal ('RDFXX', sprintf ('Lost RO_DIGEST index entry (LOOP join): RO_DIGEST=%U (id=%d)', serialize (digest), id));
  --if (not exists (select top 1 1
  --  from DB.DBA.RDF_OBJ as a table option (index RDF_OBJ)
  --  join DB.DBA.RDF_OBJ as b table option (index RO_DIGEST)
  --  on ((a.RO_DIGEST = b.RO_DIGEST) or (a.RO_DIGEST is null and b.RO_DIGEST is null))
  --  where (a.RO_ID = id) option (HASH) ))
  --  signal ('RDFXX', sprintf ('Lost RO_DIGEST index entry (HASH join): RO_ID=%d (digest=%U)', id, serialize (digest)));
  --if (not exists (select top 1 1
  --  from DB.DBA.RDF_OBJ as a table option (index RO_DIGEST)
  --  join DB.DBA.RDF_OBJ as b table option (index RDF_OBJ)
  --  on ((a.RO_DIGEST = b.RO_DIGEST) or (a.RO_DIGEST is null and b.RO_DIGEST is null))
  --  where (a.RO_DIGEST = digest) option (HASH) ))
  --  signal ('RDFXX', sprintf ('Lost RO_DIGEST index entry (HASH join): RO_DIGEST=%U (id=%d)', serialize (digest), id));
  --  if (ro_id_dict is not null)
  --    dict_put (ro_id_dict, id, 1);
  --return digest;
}
;

create function DB.DBA.RDF_OBJ_FIND_EXISTING (in dt_twobyte integeR, in v varchar, in lang_twobyte integeR) returns varchar
{
  declare llong, id, need_digest integer;
  declare digest, old_digest any;
  -- dbg_obj_princ ('DB.DBA.RDF_OBJ_FIND_EXISTING (', dt_twobyte, v, lang_twobyte, ')');
  if (126 = __tag (v))
    v := blob_to_string (v);
  need_digest := rdf_box_needs_digest (v, NULL);
  if (__tag of rdf_box = __tag (v))
    {
      if (0 = need_digest)
        return v;
      if (1 = need_digest)
        {
          if (0 <> rdf_box_ro_id (v))
        return v;
        }
      dt_twobyte := rdf_box_type (v);
      lang_twobyte := rdf_box_lang (v);
      v := __rdf_sqlval_of_obj (v, 1);
    }
  else
    {
      if (dt_twobyte <> 257 or lang_twobyte <> 257)
        need_digest := 3;
      else if (0 = need_digest)
        return v;
      if (dt_twobyte < 257)
        signal ('RDFXX', sprintf ('Bad datatype code: DB.DBA.RDF_OBJ_FIND_EXISTING (%d, %s, %d)',
          dt_twobyte, "LEFT" (cast (v as varchar), 100), lang_twobyte) );
      if (lang_twobyte < 257)
        signal ('RDFXX', sprintf ('Bad lang code: DB.DBA.RDF_OBJ_FIND_EXISTING (%d, %s, %d)',
          dt_twobyte, "LEFT" (cast (v as varchar), 100), lang_twobyte) );
    }
  if (not isstring (v))
    {
      declare sum64 varchar;
      if (__tag of XML <> __tag (v))
        signal ('RDFXX', sprintf ('Bad call: DB.DBA.RDF_OBJ_FIND_EXISTING (%d, %s, %d)',
          dt_twobyte, "LEFT" (cast (v as varchar), 100), lang_twobyte) );
      sum64 := xtree_sum64 (v);
      return coalesce ((select rdf_box (v, dt_twobyte, lang_twobyte, RO_ID, 1)
          from DB.DBA.RDF_OBJ table option (index RO_VAL)
        where RO_VAL = sum64
        and equ (dt_twobyte, case (isnull (RO_DIGEST)) when 0 then rdf_box_type (RO_DIGEST) else 257 end)
        and equ (lang_twobyte, case (isnull (RO_DIGEST)) when 0 then rdf_box_lang (RO_DIGEST) else 257 end)
          and rdf_box_data_tag (RO_DIGEST) = __tag of XML ));
        --!TBD ... and paranoid check
    }
  if ((dt_twobyte = 257) and (lang_twobyte = 257) and (length (v) <= 20))
    return v;
  llong := 1010;
  if (length (v) > llong)
    {
      declare tridgell varchar;
      tridgell := tridgell32 (v, 1);
      return ((select rdf_box (v, dt_twobyte, lang_twobyte, RO_ID, 1)
        from DB.DBA.RDF_OBJ table option (index RO_VAL)
        where RO_VAL = tridgell
        and equ (dt_twobyte, case (isnull (RO_DIGEST)) when 0 then rdf_box_type (RO_DIGEST) else 257 end)
        and equ (lang_twobyte, case (isnull (RO_DIGEST)) when 0 then rdf_box_lang (RO_DIGEST) else 257 end)
          and blob_to_string (RO_LONG) = v ));
    }
  else
    {
      return ((select rdf_box (v, dt_twobyte, lang_twobyte, RO_ID, 1)
        from DB.DBA.RDF_OBJ table option (index RO_VAL)
        where RO_VAL = v
        and equ (dt_twobyte, case (isnull (RO_DIGEST)) when 0 then rdf_box_type (RO_DIGEST) else 257 end)
          and equ (lang_twobyte, case (isnull (RO_DIGEST)) when 0 then rdf_box_lang (RO_DIGEST) else 257 end) ));
    }
}
;

create function DB.DBA.RDF_MAKE_OBJ_OF_SQLVAL (in v any) returns any
{
  declare t int;
  t := __tag (v);
  if (not t in (126, __tag of varchar, 217, __tag of nvarchar, __tag of XML, __tag of rdf_box))
    return v;
  if (__tag of nvarchar = t)
    v := charset_recode (v, '_WIDE_', 'UTF-8');
  else if (t in (126, 217))
    v := cast (v as varchar);
  return DB.DBA.RDF_OBJ_ADD (257, v, 257);
}
;

create function DB.DBA.RDF_MAKE_OBJ_OF_SQLVAL_FT (in v any, in g_iid IRI_ID, in p_iid IRI_ID, in ro_id_dict any := null) returns any
{
  declare t int;
  t := __tag (v);
  if (not t in (126, __tag of varchar, 217, __tag of nvarchar, __tag of XML, __tag of rdf_box))
    return v;
  if (__tag of nvarchar = t)
    v := charset_recode (v, '_WIDE_', 'UTF-8');
  else if (t in (126, 217))
    v := cast (v as varchar);
  if (not __rdf_obj_ft_rule_check (g_iid, p_iid))
    ro_id_dict := null;
  else
    {
      if (ro_id_dict is null)
        {
          declare res any;
          ro_id_dict := dict_new ();
          res := DB.DBA.RDF_OBJ_ADD (257, v, 257, ro_id_dict);
          DB.DBA.RDF_OBJ_ADD_KEYWORD_FOR_GRAPH (g_iid, ro_id_dict);
          return res;
        }
    }
  return DB.DBA.RDF_OBJ_ADD (257, v, 257, ro_id_dict);
}
;

create function DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL (in v any, in dt_iid IRI_ID, in lang varchar) returns any
{
  declare t, dt_twobyte, lang_twobyte int;
retry_unrdf:
  t := __tag (v);
  if (not t in (126, __tag of varchar, 217, __tag of nvarchar, __tag of XML))
    {
      if (__tag of rdf_box = t)
        {
          v := rdf_box_data (v);
          goto retry_unrdf;
        }
      -- dbg_obj_princ ('DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL() should accept only string representations of typed values, real arguments are ', v, dt_iid, lang);
      return v;
    }
  if (__tag of nvarchar = t)
    v := charset_recode (v, '_WIDE_', 'UTF-8');
  else if (217 = t or 126 = t)
    v := cast (v as varchar);
  if (dt_iid is not null)
    dt_twobyte := DB.DBA.RDF_TWOBYTE_OF_DATATYPE (dt_iid);
  else
    dt_twobyte := 257;
  if (lang is not null)
    lang_twobyte := DB.DBA.RDF_TWOBYTE_OF_LANGUAGE (lang);
  else
    lang_twobyte := 257;
  return DB.DBA.RDF_OBJ_ADD (dt_twobyte, v, lang_twobyte);
}
;

create function DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL_FT (in v any, in dt_iid IRI_ID, in lang varchar, in g_iid IRI_ID, in p_iid IRI_ID, in ro_id_dict any := null) returns any
{
  declare t, dt_twobyte, lang_twobyte int;
retry_unrdf:
  t := __tag (v);
  if (not t in (126, __tag of varchar, 217, __tag of nvarchar, __tag of XML))
    {
      if (__tag of rdf_box = t)
        {
          v := rdf_box_data (v);
          goto retry_unrdf;
        }
      -- dbg_obj_princ ('DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL_FT() should accept only string representations of typed values, real arguments are ', v, dt_iid, lang, g_iid, p_iid);
      return v;
    }
  if (__tag of nvarchar = t)
    v := charset_recode (v, '_WIDE_', 'UTF-8');
  else if (217 = t or 126 = t)
    v := cast (v as varchar);
  if (dt_iid is not null)
    dt_twobyte := DB.DBA.RDF_TWOBYTE_OF_DATATYPE (dt_iid);
  else
    dt_twobyte := 257;
  if (lang is not null)
    lang_twobyte := DB.DBA.RDF_TWOBYTE_OF_LANGUAGE (lang);
  else
    lang_twobyte := 257;
  if (not __rdf_obj_ft_rule_check (g_iid, p_iid))
    ro_id_dict := null;
  else
    {
      if (ro_id_dict is null)
        {
          declare res any;
          ro_id_dict := dict_new ();
          res := DB.DBA.RDF_OBJ_ADD (dt_twobyte, v, lang_twobyte, ro_id_dict);
          DB.DBA.RDF_OBJ_ADD_KEYWORD_FOR_GRAPH (g_iid, ro_id_dict);
          return res;
        }
    }
  return DB.DBA.RDF_OBJ_ADD (dt_twobyte, v, lang_twobyte, ro_id_dict);
}
;

create function DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL_STRINGS (
  in o_val any, in o_type varchar, in o_lang varchar ) returns any
{
  if (__tag (o_type) in (__tag of varchar, 217))
    {
      declare parsed any;
      parsed := __xqf_str_parse_to_rdf_box (o_val, o_type, isstring (o_val));
      if (parsed is not null)
        {
          if (__tag of rdf_box = __tag (parsed))
            rdf_box_set_type (parsed,
              DB.DBA.RDF_TWOBYTE_OF_DATATYPE (DB.DBA.RDF_MAKE_IID_OF_QNAME (o_type)));
          return parsed;
        }
      return DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL (
        o_val,
        DB.DBA.RDF_MAKE_IID_OF_QNAME (o_type),
        o_lang );
    }
  if (isstring (o_lang))
    {
      return DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL (
        o_val, NULL, o_lang );
    }
  return DB.DBA.RDF_MAKE_OBJ_OF_SQLVAL (o_val);
}
;

create function DB.DBA.RDF_LONG_OF_OBJ (in shortobj any) returns any -- DEPRECATED
{
  return __rdf_long_of_obj (shortobj);
}
;

create function DB.DBA.RDF_DATATYPE_OF_OBJ (in shortobj any, in dflt varchar := 'http://www.w3.org/2001/XMLSchema#string') returns any
{
  declare twobyte integer;
  declare res any;
  if (__tag of rdf_box <> __tag (shortobj))
    {
      if (isiri_id (shortobj))
        return null;
      return iri_to_id (__xsd_type (shortobj, dflt));
    }
  twobyte := rdf_box_type (shortobj);
  if (257 = twobyte)
    return case (rdf_box_lang (shortobj)) when 257 then iri_to_id (dflt) else null end;
  whenever not found goto badtype;
  select RDT_IID into res from DB.DBA.RDF_DATATYPE where RDT_TWOBYTE = twobyte;
  return res;

badtype:
  signal ('RDFXX', sprintf ('Unknown datatype in DB.DBA.RQ_DATATYPE_OF_OBJ, bad type id %d, string value "%s"',
    twobyte, cast (rdf_box_data (shortobj) as varchar) ) );
}
;

create function DB.DBA.RDF_LANGUAGE_OF_OBJ (in shortobj any, in dflt varchar := '') returns any
{
  declare twobyte integer;
  declare res varchar;
  if (__tag of rdf_box <> __tag (shortobj))
    return case (isiri_id (shortobj)) when 0 then dflt else null end;
  twobyte := rdf_box_lang (shortobj);
  if (257 = twobyte)
    return dflt;
  whenever not found goto badtype;
  select lower (RL_ID) into res from DB.DBA.RDF_LANGUAGE where RL_TWOBYTE = twobyte;
  return res;

badtype:
  signal ('RDFXX', sprintf ('Unknown language in DB.DBA.RDF_LANGUAGE_OF_OBJ, bad string "%s"', shortobj));
}
;

create function DB.DBA.RDF_SQLVAL_OF_OBJ (in shortobj any) returns any -- DEPRECATED
{
  return __rdf_sqlval_of_obj (shortobj);
}
;

create function DB.DBA.RDF_BOOL_OF_OBJ (in shortobj any) returns any
{
  if (isiri_id (shortobj))
    return null;
  if (isinteger (shortobj))
    {
      if (shortobj)
        return 1;
      return 0;
    }
  if (__tag of rdf_box <> __tag (shortobj))
    {
      if (shortobj is null)
        return null;
      if (equ (shortobj, 0.0) or equ (shortobj, '')) return 0; else return 1;
    }
  declare twobyte integer;
  twobyte := rdf_box_type (shortobj);
  if (257 = twobyte)
    goto type_ok;
  declare dtqname varchar;
  whenever not found goto badtype;
  select RDT_QNAME into dtqname from DB.DBA.RDF_DATATYPE where RDT_TWOBYTE = twobyte;
  if (dtqname <> UNAME'http://www.w3.org/2001/XMLSchema#string')
    return null;

type_ok:
  return case length (rdf_box_data (shortobj)) when 0 then 0 else 1 end;

badtype:
  signal ('RDFXX', sprintf ('Unknown datatype in DB.DBA.RDF_BOOL_OF_OBJ, bad type id %d, string value "%s"',
    twobyte, cast (rdf_box_data (shortobj) as varchar) ) );
}
;

create function DB.DBA.RDF_QNAME_OF_OBJ (in shortobj any) returns varchar -- DEPRECATED
{
  return id_to_iri_nosignal (shortobj);
}
;

create function DB.DBA.RDF_STRSQLVAL_OF_OBJ (in shortobj any)
{
  declare t, len integer;
  if (isiri_id (shortobj))
    {
      declare res varchar;
      res := id_to_iri (shortobj);
--      res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = shortobj));
      if (res is null)
        signal ('RDFXX', 'Wrong iid in DB.DBA.RDF_STRSQLVAL_OF_OBJ()');
      return res;
    }
  if (__tag of rdf_box <> __tag (shortobj))
    {
      if (__tag of datetime = __tag (shortobj))
        {
          declare vc varchar;
          vc := cast (shortobj as varchar); --!!!TBD: replace with proper serialization
          return replace (vc, ' ', 'T');
        }
      if (__tag of nvarchar =  __tag (shortobj))
        return charset_recode (shortobj, '_WIDE_', 'UTF-8');
      return cast (shortobj as varchar);
    }
  __rdf_box_make_complete (shortobj);
  if (__tag of varchar = rdf_box_data_tag (shortobj))
    return rdf_box_data (shortobj);
  if (__tag of datetime = rdf_box_data_tag (shortobj))
    {
      declare vc varchar;
      vc := cast (rdf_box_data (shortobj) as varchar); --!!!TBD: replace with proper serialization
      return replace (vc, ' ', 'T');
    }
  return cast (rdf_box_data (shortobj) as varchar);
}
;


create function DB.DBA.RDF_OBJ_OF_LONG (in longobj any) returns any
{
  if (__tag of rdf_box <> __tag(longobj))
    return longobj;
  if (0 = rdf_box_needs_digest (longobj))
    return longobj;
  return DB.DBA.RDF_OBJ_ADD (257, longobj, 257);
}
;

create function DB.DBA.RDF_OBJ_OF_SQLVAL (in v any) returns any
{
  declare t int;
  t := __tag (v);
  if (not t in (__tag of varchar, 217, __tag of nvarchar))
    return v;
  if (__tag of nvarchar = t)
    v := charset_recode (v, '_WIDE_', 'UTF-8');
  else if (t in (126, 217))
    v := cast (v as varchar);
  return DB.DBA.RDF_OBJ_ADD (257, v, 257);
}
;

-----
-- Functions for long object representation.

create function DB.DBA.RDF_MAKE_LONG_OF_SQLVAL (in v any) returns any
{
  declare t int;
  declare res any;
  t := __tag (v);
--  if (not t in (126, __tag of varchar, 217, __tag of nvarchar, __tag of XML))
  if (0 = position (t, vector (126, __tag of varchar, 217, __tag of nvarchar, __tag of XML)))
    return v;
  if (__tag of nvarchar = t)
    v := charset_recode (v, '_WIDE_', 'UTF-8');
  else if (217 = t or 126 = t)
    v := cast (v as varchar);
  res := rdf_box (v, 257, 257, 0, 1);
  return res;
}
;


create function DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL (in v any, in dt_iid IRI_ID, in lang varchar) returns any
{
  declare t, dt_twobyte, lang_twobyte int;
  declare res any;
  t := __tag (v);
--  if (not t in (__tag of varchar, 217, __tag of nvarchar, __tag of XML))
--    signal ('RDFXX', 'DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL() accepts only string representations of typed values');
  if (__tag of nvarchar = t)
    v := charset_recode (v, '_WIDE_', 'UTF-8');
  else if (217 = t)
    v := cast (v as varchar);
  if (__tag of varchar <> __tag (v))
    {
      declare xsdt IRI_ID;
      if (lang is not null)
        signal ('RDFXX', 'Language is set for typed literal in DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL()');
      xsdt := cast (__xsd_type (v, UNAME'http://www.w3.org/2001/XMLSchema#string', NULL) as varchar);
      if (dt_iid = case (isiri_id (dt_iid)) when 1 then iri_to_id (xsdt) else xsdt end)
        return v;
      -- dbg_obj_princ ('no opt -- ', dt_iid, case (isiri_id (dt_iid)) when 1 then iri_to_id (xsdt) else xsdt end);
    }
  if (dt_iid is not null)
    dt_twobyte := DB.DBA.RDF_TWOBYTE_OF_DATATYPE (dt_iid);
  else
    dt_twobyte := 257;
  if (lang is not null)
    lang_twobyte := DB.DBA.RDF_TWOBYTE_OF_LANGUAGE (lang);
  else
    lang_twobyte := 257;
  res := rdf_box (v, dt_twobyte, lang_twobyte, 0, 1);
  return res;
}
;

create function DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL_STRINGS (
  in o_val any, in o_type varchar, in o_lang varchar ) returns any
{
  if (__tag (o_type) in (__tag of varchar, 217))
    {
      declare parsed any;
      parsed := __xqf_str_parse_to_rdf_box (o_val, o_type, isstring (o_val));
      if (parsed is not null)
        {
          if (__tag of rdf_box = __tag (parsed))
            rdf_box_set_type (parsed,
              DB.DBA.RDF_TWOBYTE_OF_DATATYPE (DB.DBA.RDF_MAKE_IID_OF_QNAME (o_type)));
          return parsed;
        }
      return DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL (
        o_val,
        DB.DBA.RDF_MAKE_IID_OF_QNAME (o_type),
        o_lang );
    }
  if (isstring (o_lang))
    return DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL (o_val, NULL, o_lang);
  return DB.DBA.RDF_MAKE_LONG_OF_SQLVAL (o_val);
}
;

create function DB.DBA.RDF_SQLVAL_OF_LONG (in longobj any) returns any -- DEPRECATED
{
  return __rdf_sqlval_of_obj (longobj);
}
;

create function DB.DBA.RDF_BOOL_OF_LONG (in longobj any) returns any
{
  if (isiri_id (longobj))
    return NULL;
  if (isinteger (longobj))
    {
      if (longobj)
        return 1;
      return 0;
    }
  if (__tag of rdf_box <> __tag (longobj))
    {
      if (longobj is null)
        return null;
      if (equ (longobj, 0.0) or equ (longobj, '')) return 0; else return 1;
    }
  declare dtqname any;
  if (257 = rdf_box_type (longobj))
    goto type_ok;
  whenever not found goto badtype;
  select RDT_QNAME into dtqname from DB.DBA.RDF_DATATYPE where RDT_TWOBYTE = rdf_box_type (longobj);
  if (dtqname <> UNAME'http://www.w3.org/2001/XMLSchema#string')
    return null;

type_ok:
  return case (length (rdf_box_data (longobj))) when 0 then 0 else 1 end;

badtype:
  signal ('RDFXX', sprintf ('Unknown datatype in DB.DBA.RDF_BOOL_OF_LONG (code %d)', rdf_box_type(longobj)));
}
;

create function DB.DBA.RDF_DATATYPE_OF_LONG (in longobj any, in dflt any := UNAME'http://www.w3.org/2001/XMLSchema#string') returns any
{
  if (__tag of rdf_box = __tag (longobj))
    {
      declare twobyte integer;
      declare res varchar;
      twobyte := rdf_box_type (longobj);
      if (257 = twobyte)
        return case (rdf_box_lang (longobj)) when 257 then iri_to_id (dflt) else null end;
      whenever not found goto badtype;
      select RDT_IID into res from DB.DBA.RDF_DATATYPE where RDT_TWOBYTE = twobyte;
      return res;

badtype:
  signal ('RDFXX', sprintf ('Unknown datatype in DB.DBA.RDF_DATATYPE_OF_LONG, bad id %d', twobyte));
    }
  if (isiri_id (longobj))
    return NULL;
  return iri_to_id (__xsd_type (longobj, dflt));
}
;

create function DB.DBA.RDF_DATATYPE_IRI_OF_LONG (in longobj any, in dflt any := UNAME'http://www.w3.org/2001/XMLSchema#string') returns any
{
  if (__tag of rdf_box = __tag (longobj))
    {
      declare twobyte integer;
      declare res varchar;
      twobyte := rdf_box_type (longobj);
      if (257 = twobyte)
        return case (rdf_box_lang (longobj)) when 257 then dflt else null end;
      whenever not found goto badtype;
      select RDT_QNAME into res from DB.DBA.RDF_DATATYPE where RDT_TWOBYTE = twobyte;
      return res;

badtype:
  signal ('RDFXX', sprintf ('Unknown datatype in DB.DBA.RDF_DATATYPE_IRI_OF_LONG, bad id %d', twobyte));
    }
  if (isiri_id (longobj))
    return NULL;
  return __xsd_type (longobj, dflt);
}
;

create function DB.DBA.RDF_LANGUAGE_OF_LONG (in longobj any, in dflt varchar := '') returns any
{
  if (__tag of rdf_box = __tag (longobj))
    {
      declare twobyte integer;
      declare res varchar;
      twobyte := rdf_box_lang (longobj);
      if (257 = twobyte)
        return dflt;
      whenever not found goto badlang;
      select lower (RL_ID) into res from DB.DBA.RDF_LANGUAGE where RL_TWOBYTE = twobyte;
      return res;

badlang:
  signal ('RDFXX', sprintf ('Unknown language in DB.DBA.RDF_LANGUAGE_OF_LONG, bad id %d', twobyte));
    }
  return case (isiri_id (longobj)) when 0 then dflt else null end;
}
;

create function DB.DBA.RDF_STRSQLVAL_OF_LONG (in longobj any)
{
  declare t, len integer;
  if (__tag of rdf_box = __tag (longobj))
    {
      if (rdf_box_is_complete (longobj))
        {
          if (__tag of varchar = rdf_box_data_tag (longobj))
            return rdf_box_data (longobj);
          if (__tag of datetime = rdf_box_data_tag (longobj))
            {
              declare vc varchar;
              vc := cast (rdf_box_data (longobj) as varchar); --!!!TBD: replace with proper serialization
              return replace (vc, ' ', 'T');
            }
          if (__tag of XML = rdf_box_data_tag (longobj))
            {
              return serialize_to_UTF8_xml (rdf_box_data (longobj));
            }
          return cast (rdf_box_data (longobj) as varchar);
        }
      declare id integer;
      declare v2 any;
      id := rdf_box_ro_id (longobj);
      if (__tag of XML = rdf_box_data_tag (longobj))
        {
          v2 := (select xml_tree_doc (__xml_deserialize_packed (RO_LONG)) from DB.DBA.RDF_OBJ where RO_ID = id);
          rdf_box_set_data (longobj, v2, 1);
          return serialize_to_UTF8_xml (v2);
        }
      else
        v2 := (select case (isnull (RO_LONG)) when 0 then blob_to_string (RO_LONG) else RO_VAL end from DB.DBA.RDF_OBJ where RO_ID = id);
      if (v2 is null)
        signal ('RDFXX', sprintf ('Integrity violation in DB.DBA.RDF_STRSQLVAL_OF_LONG, bad id %d', id));
      rdf_box_set_data (longobj, v2, 1);
      return v2;
    }
  if (isiri_id (longobj))
    {
      declare res varchar;
      res := id_to_iri (longobj);
--      res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = longobj));
      if (res is null)
        signal ('RDFXX', 'Wrong iid in DB.DBA.RDF_STRSQLVAL_OF_LONG()');
      return res;
    }
  if (__tag of datetime = __tag (longobj))
    {
      declare vc varchar;
      vc := cast (longobj as varchar); --!!!TBD: replace with proper serialization
      return replace (vc, ' ', 'T');
    }
  if (__tag of nvarchar = __tag (longobj))
    return charset_recode (longobj, '_WIDE_', 'UTF-8');
  if (__tag of XML = __tag (longobj))
    {
      return serialize_to_UTF8_xml (longobj);
    }
  return cast (longobj as varchar);
}
;

--!AWK PUBLIC
create function DB.DBA.RDF_DATATYPE_OF_SQLVAL (in v any,
  in strg_datatype any := UNAME'http://www.w3.org/2001/XMLSchema#string',
  in default_res any := NULL) returns any
{
  if (__tag of rdf_box = __tag (v))
    {
      declare twobyte integer;
      declare res varchar;
      twobyte := rdf_box_type (v);
      if (257 = twobyte)
        return case (rdf_box_lang (v)) when 257 then iri_to_id (strg_datatype) else null end;
      whenever not found goto badtype;
      select RDT_IID into res from DB.DBA.RDF_DATATYPE where RDT_TWOBYTE = twobyte;
      return res;

badtype:
  signal ('RDFXX', sprintf ('Unknown datatype in DB.DBA.RDF_DATATYPE_OF_SQLVAL, bad id %d', twobyte));
    }
  return iri_to_id (__xsd_type (v, strg_datatype, default_res));
}
;

create function DB.DBA.RDF_LONG_OF_SQLVAL (in v any) returns any
{
  declare t int;
  t := __tag (v);
  if (not t in (126, __tag of varchar, 217, __tag of nvarchar))
    return v;
  if (__tag of nvarchar = t)
    v := charset_recode (v, '_WIDE_', 'UTF-8');
  else if (t in (126, 217))
    v := cast (v as varchar);
  return rdf_box (v, 257, 257, 0, 1);
}
;

-----
-- Conversions for SQL values

--!AWK PUBLIC
create function DB.DBA.RDF_STRSQLVAL_OF_SQLVAL (in sqlval any)
{
  declare t, len integer;
  if (__tag of rdf_box = __tag (sqlval))
    {
      signal ('RDFXX', 'Long object in DB.DBA.RDF_STRSQLVAL_OF_SQLVAL()');
    }
  if (isiri_id (sqlval))
    {
      declare res varchar;
      res := id_to_iri (sqlval);
--      res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = sqlval));
      if (res is null)
        signal ('RDFXX', 'Wrong iid in DB.DBA.RDF_STRSQLVAL_OF_SQLVAL()');
      return res;
    }
  if (__tag of datetime = __tag (sqlval))
    {
      declare vc varchar;
      vc := cast (sqlval as varchar); --!!!TBD: replace with proper serialization
      return replace (vc, ' ', 'T');
    }
  if (__tag of nvarchar = __tag (sqlval))
    return charset_recode (sqlval, '_WIDE_', 'UTF-8');
  return cast (sqlval as varchar);
}
;

--!AWK PUBLIC
create function DB.DBA.RDF_LANGUAGE_OF_SQLVAL (in v any, in dflt varchar := '') returns any
{
  declare t int;
  return case (isiri_id (v)) when 0 then dflt else null end;
--  t := __tag (v);
--  if (not t in (__tag of varchar, 217, __tag of nvarchar))
--    return NULL;
--  return NULL; -- !!!TBD: uncomment this and make a support for UTF8 'language name' codepoint plane
}
;

--!AWK PUBLIC
create function DB.DBA.RDF_IS_BLANK_REF (in v any) returns any
{
  if (not isstring (v))
    return 0;
  if ("LEFT" (v, 9) <> 'nodeID://')
    return 0;
  return 1;
}
;

--!AWK PUBLIC
create function DB.DBA.RDF_IS_URI_REF (in v any) returns any
{
  if (not (__tag (v) in (__tag of varchar, 217)))
    return 0;
  if ("LEFT" (v, 9) = 'nodeID://')
    return 0;
  return 1;
}
;

-----
-- Partial emulation of XQuery Core Function Library (temporary, to be deleted soon)

--!AWK PUBLIC
create function DB.DBA."http://www.w3.org/2001/XMLSchema#boolean" (in strg any) returns integer
{
  if (isstring (strg))
    {
      if (('true' = strg) or ('1' = strg))
        return 1;
      if (('false' = strg) or ('0' = strg))
        return 0;
    }
  if (isinteger (strg))
    return case (strg) when 0 then 0 else 1 end;
  return NULL;
}
;

--!AWK PUBLIC
create function DB.DBA."http://www.w3.org/2001/XMLSchema#date" (in strg any) returns date
{
  if (__tag of datetime = __tag (strg))
    return strg;
  whenever sqlstate '*' goto ret_null;
  if (isstring (strg))
    return __xqf_str_parse ('date', strg);
  return cast (strg as date);
ret_null:
  return NULL;
}
;

--!AWK PUBLIC
create function DB.DBA."http://www.w3.org/2001/XMLSchema#dateTime" (in strg any) returns datetime
{
  if (__tag of datetime = __tag (strg))
    return strg;
  whenever sqlstate '*' goto ret_null;
  if (isstring (strg))
    return __xqf_str_parse ('dateTime', strg);
  return cast (strg as datetime);
ret_null:
  return NULL;
}
;

--!AWK PUBLIC
create function DB.DBA."http://www.w3.org/2001/XMLSchema#double" (in strg varchar) returns double precision
{
  whenever sqlstate '*' goto ret_null;
  return cast (strg as double precision);
ret_null:
  return NULL;
}
;

--!AWK PUBLIC
create function DB.DBA."http://www.w3.org/2001/XMLSchema#float" (in strg varchar) returns float
{
  whenever sqlstate '*' goto ret_null;
  return cast (strg as float);
ret_null:
  return NULL;
}
;

--!AWK PUBLIC
create function DB.DBA."http://www.w3.org/2001/XMLSchema#integer" (in strg varchar) returns integer
{
  whenever sqlstate '*' goto ret_null;
  return cast (strg as integer);
ret_null:
  return NULL;
}
;

--!AWK PUBLIC
create function DB.DBA."http://www.w3.org/2001/XMLSchema#int" (in strg varchar) returns integer
{
  whenever sqlstate '*' goto ret_null;
  return cast (strg as integer);
ret_null:
  return NULL;
}
;

--!AWK PUBLIC
create function DB.DBA."http://www.w3.org/2001/XMLSchema#time" (in strg any) returns time
{
  if (__tag of datetime = __tag (strg))
    return strg;
  whenever sqlstate '*' goto ret_null;
  if (isstring (strg))
    return __xqf_str_parse ('time', strg);
  return cast (strg as time);
ret_null:
  return NULL;
}
;

--!AWK PUBLIC
create function DB.DBA."http://www.w3.org/2001/XMLSchema#string" (in strg any) returns any
{
  whenever sqlstate '*' goto ret_null;
  declare t, dt_twobyte, lang_twobyte int;
  t := __tag (strg);
  if (__tag of nvarchar = t)
    strg := charset_recode (strg, '_WIDE_', 'UTF-8');
  else if (__tag of varchar <> t)
    strg := cast (strg as varchar);
  return DB.DBA.RDF_OBJ_ADD (
    DB.DBA.RDF_TWOBYTE_OF_DATATYPE ('http://www.w3.org/2001/XMLSchema#string'),
    strg, 257 );

ret_null:
  return NULL;
}
;

-----
-- Boolean operators as functions (temporary, will be replaced with 'LET' SQL extension soon)

--!AWK PUBLIC
create function DB.DBA.__and (in e1 any, in e2 any) returns integer
{
  if (e1 and e2)
    return 1;
  return 0;
}
;

--!AWK PUBLIC
create function DB.DBA.__or (in e1 any, in e2 any) returns integer
{
  if (e1 or e2)
    return 1;
  return 0;
}
;

--!AWK PUBLIC
create function DB.DBA.__not (in e1 any) returns integer
{
  if (e1)
    return 0;
  return 1;
}
;


-----
-- Data loading

create procedure DB.DBA.RDF_QUAD_URI (in g_uri varchar, in s_uri varchar, in p_uri varchar, in o_uri varchar)
{
  insert soft DB.DBA.RDF_QUAD (G,S,P,O)
  values (
    DB.DBA.RDF_MAKE_IID_OF_QNAME (g_uri),
    DB.DBA.RDF_MAKE_IID_OF_QNAME (s_uri),
    DB.DBA.RDF_MAKE_IID_OF_QNAME (p_uri),
    DB.DBA.RDF_MAKE_IID_OF_QNAME (o_uri) );
}
;

create procedure DB.DBA.RDF_QUAD_URI_L (in g_uri varchar, in s_uri varchar, in p_uri varchar, in o_lit any, in ro_id_dict any := null)
{
  declare g_iid, p_iid IRI_ID;
  g_iid := DB.DBA.RDF_MAKE_IID_OF_QNAME (g_uri);
  p_iid := DB.DBA.RDF_MAKE_IID_OF_QNAME (p_uri);
  insert soft DB.DBA.RDF_QUAD (G,S,P,O)
  values (
    g_iid,
    DB.DBA.RDF_MAKE_IID_OF_QNAME (s_uri),
    p_iid,
    DB.DBA.RDF_MAKE_OBJ_OF_SQLVAL_FT (o_lit, g_iid, p_iid, ro_id_dict) );
}
;

create procedure DB.DBA.RDF_QUAD_URI_L_TYPED (in g_uri varchar, in s_uri varchar, in p_uri varchar, in o_lit any, in dt any, in lang varchar, in ro_id_dict any := null)
{
  declare g_iid, p_iid IRI_ID;
  g_iid := DB.DBA.RDF_MAKE_IID_OF_QNAME (g_uri);
  p_iid := DB.DBA.RDF_MAKE_IID_OF_QNAME (p_uri);
  if (dt is null and lang is null)
    {
      insert soft DB.DBA.RDF_QUAD (G,S,P,O)
      values (
        g_iid,
        DB.DBA.RDF_MAKE_IID_OF_QNAME (s_uri),
        p_iid,
        DB.DBA.RDF_MAKE_OBJ_OF_SQLVAL_FT (o_lit, g_iid, p_iid, ro_id_dict) );
      return;
    }
  insert soft DB.DBA.RDF_QUAD (G,S,P,O)
  values (
    g_iid,
    DB.DBA.RDF_MAKE_IID_OF_QNAME (s_uri),
    p_iid,
    DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL_FT (
      o_lit, DB.DBA.RDF_MAKE_IID_OF_QNAME (dt), lang, g_iid, p_iid, ro_id_dict ) );
}
;

create procedure DB.DBA.TTLP_EV_NEW_GRAPH (inout g varchar, inout app_env any) {
  -- dbg_obj_princ ('DB.DBA.TTLP_EV_NEW_GRAPH(', g, app_env, ')');
  ;
}
;

create procedure DB.DBA.TTLP_EV_NEW_BLANK (inout g varchar, inout app_env any, inout res IRI_ID) {
  res := iri_id_from_num (sequence_next ('RDF_URL_IID_BLANK'));
  -- dbg_obj_princ ('DB.DBA.TTLP_EV_NEW_BLANK (', g, app_env, ') returns ', res);
}
;

create procedure DB.DBA.TTLP_EV_GET_IID (inout uri varchar, inout g varchar, inout app_env any, inout res IRI_ID) {
  -- dbg_obj_princ ('DB.DBA.TTLP_EV_GET_IID (', uri, g, app_env, ')');
  res := DB.DBA.RDF_MAKE_IID_OF_QNAME (uri);
  -- dbg_obj_princ ('DB.DBA.TTLP_EV_GET_IID (', uri, g, app_env, ') returns ', res);
}
;

create procedure DB.DBA.TTLP_EV_TRIPLE (
  inout g_iid IRI_ID, inout s_uri varchar, inout p_uri varchar,
  inout o_uri varchar,
  inout app_env any )
{
  -- dbg_obj_princ ('DB.DBA.TTLP_EV_TRIPLE (', g_iid, s_uri, p_uri, o_uri, ');');
  insert soft DB.DBA.RDF_QUAD (G,S,P,O)
  values (g_iid, iri_to_id (s_uri, 1), iri_to_id (p_uri, 1),
    iri_to_id (o_uri, 1) );
}
;

create procedure DB.DBA.TTLP_EV_TRIPLE_L (
  inout g_iid IRI_ID, inout s_uri varchar, inout p_uri varchar,
  inout o_val any, inout o_type varchar, inout o_lang varchar,
  inout app_env any )
{
  -- dbg_obj_princ ('DB.DBA.TTLP_EV_TRIPLE_L (', g_iid, s_uri, p_uri, o_val, o_type, o_lang, app_env, ');');
  declare log_mode integer;
  declare p_iid IRI_ID;
  declare ro_id_dict any;
  log_mode := app_env[0];
  ro_id_dict := app_env[1];
  p_iid := iri_to_id (p_uri, 1);
  if (isstring (o_type))
    {
      declare parsed any;
      parsed := __xqf_str_parse_to_rdf_box (o_val, o_type, isstring (o_val));
      if (parsed is not null)
        {
          if (__tag of rdf_box = __tag (parsed))
            rdf_box_set_type (parsed,
              DB.DBA.RDF_TWOBYTE_OF_DATATYPE (DB.DBA.RDF_MAKE_IID_OF_QNAME (o_type)));
          insert soft DB.DBA.RDF_QUAD (G,S,P,O)
          values (g_iid, iri_to_id (s_uri, 1), p_iid, parsed);
          return;
        }
      insert soft DB.DBA.RDF_QUAD (G,S,P,O)
      values (g_iid, iri_to_id (s_uri, 1), p_iid,
        DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL_FT (
          o_val,
          DB.DBA.RDF_MAKE_IID_OF_QNAME (o_type),
          case (isstring (o_lang)) when 0 then null else o_lang end,
          g_iid, p_iid, ro_id_dict ) );
      return;
    }
  if (isstring (o_lang))
    {
      insert soft DB.DBA.RDF_QUAD (G,S,P,O)
      values (g_iid, iri_to_id (s_uri, 1), p_iid,
        DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL_FT (o_val, NULL, o_lang, g_iid, p_iid, ro_id_dict) );
      return;
    }
  if (isstring (o_val) or (__tag of XML = __tag (o_val)))
    {
      insert soft DB.DBA.RDF_QUAD (G,S,P,O)
      values (g_iid, iri_to_id (s_uri, 1), p_iid,
        DB.DBA.RDF_MAKE_OBJ_OF_SQLVAL_FT (o_val, g_iid, p_iid, ro_id_dict) );
    }
  else
    {
      insert soft DB.DBA.RDF_QUAD (G,S,P,O)
      values (g_iid, iri_to_id (s_uri, 1), p_iid,
        o_val );
    }
}
;

create procedure DB.DBA.TTLP_EV_COMMIT (inout g varchar, inout app_env any) {
  -- dbg_obj_princ ('DB.DBA.TTLP_COMMIT(', g, app_env, ')');
  declare log_mode integer;
  declare ro_id_dict any;
  log_mode := app_env[0];
  ro_id_dict := app_env[1];
  if (ro_id_dict is not null)
    DB.DBA.RDF_OBJ_ADD_KEYWORD_FOR_GRAPH (iri_to_id (g), ro_id_dict);
}
;


create procedure DB.DBA.TTLP (in strg varchar, in base varchar, in graph varchar := null, in flags integer := 0)
{
  declare ro_id_dict, app_env any;
  if (126 = __tag (strg))
    strg := cast (strg as varchar);
  if (__rdf_obj_ft_rule_count_in_graph (iri_to_id (graph)))
    ro_id_dict := dict_new (__max (length (strg) / 100, 100000));
  else
    ro_id_dict := null;
  app_env := vector (flags, ro_id_dict);
  return rdf_load_turtle (strg, base, graph, flags,
    vector (
      'DB.DBA.TTLP_EV_NEW_GRAPH',
      'DB.DBA.TTLP_EV_NEW_BLANK',
      'DB.DBA.TTLP_EV_GET_IID',
      'DB.DBA.TTLP_EV_TRIPLE',
      'DB.DBA.TTLP_EV_TRIPLE_L',
      'DB.DBA.TTLP_EV_COMMIT' ),
    app_env);
}
;

create procedure DB.DBA.RDF_TTL2HASH_EXEC_NEW_GRAPH (inout g varchar, inout app_env any) {
  -- dbg_obj_princ ('DB.DBA.RDF_TTL2HASH_EXEC_NEW_GRAPH(', g, app_env, ')');
  ;
}
;

create procedure DB.DBA.RDF_TTL2HASH_EXEC_NEW_BLANK (inout g varchar, inout app_env any, inout res IRI_ID) {
  res := iri_id_from_num (sequence_next ('RDF_URL_IID_BLANK'));
  -- dbg_obj_princ ('DB.DBA.RDF_TTL2HASH_EXEC_NEW_BLANK (', g, app_env, ') returns ', res);
}
;

create procedure DB.DBA.RDF_TTL2HASH_EXEC_GET_IID (inout uri varchar, inout g varchar, inout app_env any, inout res IRI_ID) {
  -- dbg_obj_princ ('DB.DBA.RDF_TTL2HASH_EXEC_GET_IID (', uri, g, app_env, ')');
  res := DB.DBA.RDF_MAKE_IID_OF_QNAME (uri);
  -- dbg_obj_princ ('DB.DBA.RDF_TTL2HASH_EXEC_GET_IID (', uri, g, app_env, ') returns ', res);
}
;

create procedure DB.DBA.RDF_TTL2HASH_EXEC_TRIPLE (
  inout g_iid IRI_ID, inout s_uri varchar, inout p_uri varchar,
  inout o_uri varchar,
  inout app_env any )
{
  dict_put (app_env,
    vector (
      iri_to_id (s_uri, 1),
      iri_to_id (p_uri, 1),
      iri_to_id (o_uri, 1) ),
    0 );
}
;

create procedure DB.DBA.RDF_TTL2HASH_EXEC_TRIPLE_L (
  inout g_iid IRI_ID, inout s_uri varchar, inout p_uri varchar,
  inout o_val any, inout o_type varchar, inout o_lang varchar,
  inout app_env any )
{
  if (not isstring (o_type))
    o_type := null;
  if (not isstring (o_lang))
    o_lang := null;
  dict_put (app_env,
    vector (
      iri_to_id (s_uri, 1),
      iri_to_id (p_uri, 1),
      DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL_STRINGS (o_val,
        case (isstring (o_type)) when 0 then null else o_type end,
        case (isstring (o_lang)) when 0 then null else o_lang end) ),
    0 );
}
;

create function DB.DBA.RDF_TTL2HASH (in strg varchar, in base varchar, in graph varchar := null, in flags integer := 0) returns any
{
  declare res any;
  res := dict_new ();
  if (126 = __tag (strg))
    strg := cast (strg as varchar);
  res := dict_new (length (strg) / 100);
  rdf_load_turtle (strg, base, graph, flags,
    vector (
      'DB.DBA.RDF_TTL2HASH_EXEC_NEW_GRAPH',
      'DB.DBA.RDF_TTL2HASH_EXEC_NEW_BLANK',
      'DB.DBA.RDF_TTL2HASH_EXEC_GET_IID',
      'DB.DBA.RDF_TTL2HASH_EXEC_TRIPLE',
      'DB.DBA.RDF_TTL2HASH_EXEC_TRIPLE_L',
      '' ),
    res);
  return res;
}
;

create procedure DB.DBA.RDF_LOAD_RDFXML (in strg varchar, in base varchar, in graph varchar)
{
  declare ro_id_dict, app_env any;
  if (__rdf_obj_ft_rule_count_in_graph (iri_to_id (graph)))
    ro_id_dict := dict_new (__max (length (strg) / 100, 100000));
  else
    ro_id_dict := null;
  app_env := vector (null, ro_id_dict);
  rdf_load_rdfxml (strg, 0,
    graph,
    vector (
      'DB.DBA.TTLP_EV_NEW_GRAPH',
      'DB.DBA.TTLP_EV_NEW_BLANK',
      'DB.DBA.TTLP_EV_GET_IID',
      'DB.DBA.TTLP_EV_TRIPLE',
      'DB.DBA.TTLP_EV_TRIPLE_L',
      'DB.DBA.TTLP_EV_COMMIT' ),
    app_env,
    base );
  return graph;
}
;

create procedure DB.DBA.RDF_RDFXML_TO_DICT (in strg varchar, in base varchar, in graph varchar)
{
  declare res any;
  res := dict_new (length (strg) / 100);
  rdf_load_rdfxml (strg, 0,
    graph,
    vector (
      'DB.DBA.RDF_TTL2HASH_EXEC_NEW_GRAPH',
      'DB.DBA.RDF_TTL2HASH_EXEC_NEW_BLANK',
      'DB.DBA.RDF_TTL2HASH_EXEC_GET_IID',
      'DB.DBA.RDF_TTL2HASH_EXEC_TRIPLE',
      'DB.DBA.RDF_TTL2HASH_EXEC_TRIPLE_L',
      '' ),
    res,
    base );
  return res;
}
;


-----
-- Fast rewriting from serialization to serialization without storing

--!AWK PUBLIC
create procedure DB.DBA.RDF_XML_IRI_TO_TTL (inout obj any, inout ses any)
{
  declare res varchar;
  if (isiri_id (obj))
    {
      if (obj >= min_bnode_iri_id ())
        {
          if (obj >= #ib0)
            http (sprintf ('_:bb%d ', iri_id_num (obj) - iri_id_num (#ib0)), ses);
          else
            http (sprintf ('_:b%d ', iri_id_num (obj)), ses);
        }
      else
        {
          res := coalesce (id_to_iri (obj), sprintf ('_:bad_iid_%d', iri_id_num (obj)));
--          res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = obj), sprintf ('_:bad_iid_%d', iri_id_num (obj)));
          http ('<', ses);
          http_escape (res, 12, ses, 1, 1);
          http ('> ', ses);
        }
    }
  else if (__tag of varchar = __tag (obj))
    {
      if ("LEFT" (obj, 9) = 'nodeID://')
        {
          http ('_:', ses);
          http (subseq (obj, 9), ses);
          http (' ', ses);
        }
      else
        {
          http ('<', ses);
          http_escape (obj, 12, ses, 1, 1);
          http ('> ', ses);
        }
    }
  else
    {
      http ('<', ses);
      http_escape (cast (obj as varchar), 12, ses, 1, 1);
      http ('> ', ses);
    }
}
;

--!AWK PUBLIC
create procedure DB.DBA.RDF_XML_OBJ_TO_TTL (
  inout o_val any, inout o_type varchar, inout o_lang varchar,
  inout ses any)
{
  declare res varchar;
  if (isiri_id (o_val))
    {
      if (o_val >= min_bnode_iri_id ())
        {
          if (o_val >= #ib0)
            http (sprintf ('_:bb%d ', iri_id_num (o_val) - iri_id_num (#ib0)), ses);
          else
            http (sprintf ('_:b%d ', iri_id_num (o_val)), ses);
        }
      else
        {
          res := coalesce (id_to_iri (o_val), sprintf ('_:bad_iid_%d', iri_id_num (o_val)));
          http ('<', ses);
          http_escape (res, 12, ses, 1, 1);
          http ('> ', ses);
        }
      return;
    }
  http ('"', ses);
  if (__tag of XML = o_val)
    http_escape (serialize_to_UTF8_xml (o_val), 11, ses, 1, 1);
  else
    http_escape (o_val, 11, ses, 1, 1);
  if (isstring (o_type))
    {
      http ('"^^<', ses);
      http_escape (o_type, 12, ses, 1, 1);
      http ('> ', ses);
    }
  else if (isstring (o_lang))
    {
      http ('"@', ses);
      http (o_lang, ses);
      http (' ', ses);
    }
  else
    http ('" ', ses);
}
;

--!AWK PUBLIC
create procedure DB.DBA.RDF_CONVERT_RDFXML_TO_TTL_EV_NEW_BLANK (inout g varchar, inout app_env any, inout res IRI_ID)
{
  ; -- empty procedure
}
;

--!AWK PUBLIC
create procedure DB.DBA.RDF_CONVERT_RDFXML_TO_TTL_EV_TRIPLE (
  inout g_iid IRI_ID, inout s_uri varchar, inout p_uri varchar,
  inout o_uri varchar,
  inout app_env any )
{
  DB.DBA.RDF_XML_IRI_TO_TTL (s_uri, app_env);
  DB.DBA.RDF_XML_IRI_TO_TTL (p_uri, app_env);
  DB.DBA.RDF_XML_IRI_TO_TTL (o_uri, app_env);
  http ('.\n', app_env);
}
;

--!AWK PUBLIC
create procedure DB.DBA.RDF_CONVERT_RDFXML_TO_TTL_EV_TRIPLE_L (
  inout g_iid IRI_ID, inout s_uri varchar, inout p_uri varchar,
  inout o_val any, inout o_type varchar, inout o_lang varchar,
  inout app_env any )
{
  DB.DBA.RDF_XML_IRI_TO_TTL (s_uri, app_env);
  DB.DBA.RDF_XML_IRI_TO_TTL (p_uri, app_env);
  DB.DBA.RDF_XML_OBJ_TO_TTL (o_val, o_type, o_lang, app_env);
  http ('.\n', app_env);
}
;

--!AWK PUBLIC
create procedure DB.DBA.RDF_CONVERT_RDFXML_TO_TTL (in strg varchar, in base varchar, inout ttl_ses any)
{
  rdf_load_rdfxml (strg, 0,
    'http://example.com',
    vector (
      'DB.DBA.TTLP_EV_NEW_GRAPH',
      'DB.DBA.RDF_CONVERT_RDFXML_TO_TTL_EV_NEW_BLANK',
      'DB.DBA.TTLP_EV_GET_IID',
      'DB.DBA.RDF_CONVERT_RDFXML_TO_TTL_EV_TRIPLE',
      'DB.DBA.RDF_CONVERT_RDFXML_TO_TTL_EV_TRIPLE_L',
      '' ),
    ttl_ses,
    base );
}
;

--!AWK PUBLIC
create procedure DB.DBA.RDF_CONVERT_RDFXML_FILE_TO_TTL_FILE (in rdfxml_source_filename varchar, in base varchar, in ttl_target_filename varchar)
{
  declare in_ses, out_ses any;
  in_ses := file_to_string_output (rdfxml_source_filename);
  out_ses := string_output ();
  DB.DBA.RDF_CONVERT_RDFXML_TO_TTL (in_ses, base, out_ses);
  string_to_file (ttl_target_filename, out_ses, -2);
}
;

-----
-- Export into external serializations

create procedure DB.DBA.RDF_LONG_TO_TTL (inout obj any, inout ses any)
{
  declare res varchar;
  if (obj is null)
    signal ('RDFXX', 'DB.DBA.RDF_LONG_TO_TTL(): object is NULL');
  if (isiri_id (obj))
    {
      if (obj >= min_bnode_iri_id ())
        {
          if (obj >= #ib0)
            http (sprintf ('_:bb%d ', iri_id_num (obj) - iri_id_num (#ib0)), ses);
          else
            http (sprintf ('_:b%d ', iri_id_num (obj)), ses);
        }
      else
        {
          res := coalesce (id_to_iri (obj), sprintf ('_:bad_iid_%d', iri_id_num (obj)));
--          res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = obj), sprintf ('_:bad_iid_%d', iri_id_num (obj)));
          http ('<', ses);
          http_escape (res, 12, ses, 1, 1);
          http ('> ', ses);
        }
    }
  else if (__tag of rdf_box = __tag (obj))
    {
      http ('"', ses);
      if (__tag of varchar = rdf_box_data_tag (obj))
        http_escape (__rdf_sqlval_of_obj (obj, 1), 11, ses, 1, 1);
      else if (__tag of datetime = rdf_box_data_tag (obj))
        __rdf_long_to_ttl (obj, ses);
      else if (__tag of XML = rdf_box_data_tag (obj))
        http_escape (serialize_to_UTF8_xml (__rdf_sqlval_of_obj (obj, 1)), 11, ses, 1, 1);
      else
        http_escape (cast (__rdf_sqlval_of_obj (obj, 1) as varchar), 11, ses, 1, 1);
      if (257 <> rdf_box_type (obj))
        {
          res := coalesce ((select RDT_QNAME from DB.DBA.RDF_DATATYPE where RDT_TWOBYTE = rdf_box_type (obj)));
          if (res is null)
            signal ('RDFXX', sprintf ('Bad rdf box type (%d), box "%s"', rdf_box_type (obj), cast (rdf_box_data (obj) as varchar)));
          http ('"^^<', ses);
          http_escape (res, 12, ses, 1, 1);
          http ('> ', ses);
        }
      else if (257 <> rdf_box_lang (obj))
        {
          res := coalesce ((select lower (RL_ID) from DB.DBA.RDF_LANGUAGE where RL_TWOBYTE = rdf_box_lang (obj)));
          http ('"@', ses); http (res, ses); http (' ', ses);
        }
      else
        http ('" ', ses);
    }
  else if (__tag of varchar = __tag (obj))
    {
      if (1 = __box_flags (obj))
        {
          http ('<', ses);
          http_escape (obj, 12, ses, 1, 1);
          http ('> ', ses);
        }
      else
        {
      http ('"', ses);
      http_escape (obj, 11, ses, 1, 1);
      http ('" ', ses);
    }
    }
  else if (__tag of datetime = rdf_box_data_tag (obj))
    {
      http ('"', ses);
     __rdf_long_to_ttl (obj, ses);
      http ('"^^<', ses);
      http_escape (cast (__xsd_type (obj) as varchar), 12, ses, 1, 1);
      http ('> ', ses);
    }
  else if (__tag of varbinary =  __tag (obj))
    {
      http ('"', ses);
      http_escape (obj, 11, ses, 0, 0);
      http ('" ', ses);
    }
  else
    {
      http ('"', ses);
      http_escape (DB.DBA.RDF_STRSQLVAL_OF_LONG (obj), 11, ses, 1, 1);
      http ('"^^<', ses);
      http_escape (cast (__xsd_type (obj) as varchar), 12, ses, 1, 1);
      http ('> ', ses);
    }
}
;


create procedure DB.DBA.RDF_TRIPLES_TO_TTL (inout triples any, inout ses any)
{
  declare tcount, tctr integer;
  declare prev_s, prev_p IRI_ID;
  declare res varchar;
  declare string_subjs_found, string_preds_found integer;
  string_subjs_found := 0;
  string_preds_found := 0;
  tcount := length (triples);
  -- dbg_obj_princ ('DB.DBA.RDF_TRIPLES_TO_TTL:'); for (tctr := 0; tctr < tcount; tctr := tctr + 1) -- dbg_obj_princ (triples[tctr]);
  if (0 = tcount)
    {
      http ('# Empty TURTLE\n', ses);
      return;
    }
  for (tctr := 0; tctr < tcount; tctr := tctr + 1)
    {
      declare subj,pred any;
      subj := triples[tctr][0];
      pred := triples[tctr][1];
      if (not (isiri_id (subj)))
        {
          if (isstring (subj) and (1 = __box_flags (subj)))
            string_subjs_found := 1;
          else
        {
          if (subj is null)
            signal ('RDFXX', 'DB.DBA.TRIPLES_TO_TTL(): subject is NULL');
          signal ('RDFXX', 'DB.DBA.TRIPLES_TO_TTL(): subject is literal');
        }
        }
      if (not isiri_id (pred))
        {
          if (isstring (pred) and (1 = __box_flags (pred)))
            string_preds_found := 1;
          else
            {
          if (pred is null)
            signal ('RDFXX', 'DB.DBA.TRIPLES_TO_TTL(): predicate is NULL');
          signal ('RDFXX', 'DB.DBA.TRIPLES_TO_TTL(): predicate is literal');
        }
        }
      if (pred >= min_bnode_iri_id ())
        signal ('RDFXX', 'DB.DBA.TRIPLES_TO_TTL(): blank node as predicate');
    }
  if (not string_preds_found)
  rowvector_digit_sort (triples, 1, 1);
  if (not string_subjs_found)
  rowvector_digit_sort (triples, 0, 1);
  prev_s := null;
  prev_p := null;
  for (tctr := 0; tctr < tcount; tctr := tctr + 1)
    {
      declare subj,pred,obj any;
      subj := triples[tctr][0];
      pred := triples[tctr][1];
      obj := triples[tctr][2];
      if (prev_s = subj)
        {
          if (prev_p = pred)
            {
              http (',\n\t\t', ses);
              goto print_o;
            }
          http (';\n\t', ses);
          goto print_p;
        }
      if (prev_s is not null)
        http ('.\n', ses);
      if (isstring (subj))
        {
          if (subj like 'nodeID://%')
            {
              http ('_:', ses);
              http_escape (subseq (subj, 9), 12, ses, 1, 1);
	      http (' ', ses);
            }
          else
            {
              http ('<', ses);
              http_escape (subj, 12, ses, 1, 1);
              http ('> ', ses);
            }
        }
      else if (subj >= min_bnode_iri_id ())
        {
          if (subj >= #ib0)
            http (sprintf ('_:bb%d ', iri_id_num (subj) - iri_id_num (#ib0)), ses);
          else
            http (sprintf ('_:b%d ', iri_id_num (subj)), ses);
        }
      else
        {
          res := id_to_iri (subj);
          http ('<', ses);
          http_escape (res, 12, ses, 1, 1);
	  http ('> ', ses);
        }
      prev_s := subj;
      prev_p := null;
print_p:
      if (isstring (pred))
        {
          if (pred like 'nodeID://%')
            {
              http ('_:', ses);
              http_escape (subseq (pred, 9), 12, ses, 1, 1);
	      http (' ', ses);
            }
          else
            {
              http ('<', ses);
              http_escape (pred, 12, ses, 1, 1);
              http ('> ', ses);
            }
        }
      else
        {
      res := id_to_iri (pred);
      http ('<', ses);
      http_escape (res, 12, ses, 1, 1);
      http ('> ', ses);
        }
      prev_p := pred;
print_o:
      DB.DBA.RDF_LONG_TO_TTL (obj, ses);
    }
  http ('.\n', ses);
}
;

create procedure DB.DBA.RDF_GRAPH_TO_TTL (in graph_iri varchar, inout ses any)
{
  declare tcount integer;
  declare res varchar;
  declare prev_s, prev_p IRI_ID;
  -- dbg_obj_princ ('DB.DBA.RDF_GRAPH_TO_TTL (', graph_iri, ', ...)');
  tcount := 0;
  prev_s := null;
  prev_p := null;
  for (select S as subj, P as pred, O as obj from RDF_QUAD where G = iri_to_id (graph_iri)) do
    {
      if (prev_s = subj)
        {
          if (prev_p = pred)
            {
              http (',\n\t\t', ses);
              goto print_o;
            }
          http (';\n\t', ses);
          goto print_p;
        }
      if (prev_s is not null)
        http ('.\n', ses);
      if (subj >= min_bnode_iri_id ())
        {
          if (subj >= #ib0)
            http (sprintf ('_:bb%d ', iri_id_num (subj) - iri_id_num (#ib0)), ses);
          else
            http (sprintf ('_:b%d ', iri_id_num (subj)), ses);
        }
      else
        {
          res := id_to_iri (subj);
          http ('<', ses);
          http_escape (res, 12, ses, 1, 1);
          http ('> ', ses);
        }
      prev_s := subj;
      prev_p := null;
print_p:
      if (pred >= min_bnode_iri_id ())
        signal ('RDFXX', 'DB.DBA.RDF_GRAPH_TO_TTL(): blank node as predicate');
      else
        {
          res := id_to_iri (pred);
          http ('<', ses);
          http_escape (res, 12, ses, 1, 1);
          http ('> ', ses);
        }
      prev_p := pred;
print_o:
       DB.DBA.RDF_LONG_TO_TTL (obj, ses);
       tcount := tcount + 1;
    }
  if (0 = tcount)
    http ('# Empty TURTLE\n', ses);
  else
    http ('.\n', ses);
}
;

--create procedure DB.DBA.TEST_SPARQL_TTL (in query varchar, in dflt_graph varchar)
--{
--  declare ses, rset, triples any;
--  declare txt varchar;
--  ses := string_output ();
--  rset := DB.DBA.SPARQL_EVAL_TO_ARRAY (query, dflt_graph, 1);
--  triples := dict_list_keys (rset[0][0], 1);
--  DB.DBA.RDF_TRIPLES_TO_TTL (triples, ses);
--  txt := string_output_string (ses);
--  dump_large_text (txt);
--}
--;

create procedure DB.DBA.RDF_TRIPLES_TO_RDF_XML_TEXT (inout triples any, in print_top_level integer, inout ses any)
{
  declare tcount, tctr integer;
  tcount := length (triples);
  if (print_top_level)
    {
       http ('<?xml version="1.0" encoding="utf-8" ?>\n<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" '||
      			'xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#">', ses);
    }
  for (tctr := 0; tctr < tcount; tctr := tctr + 1)
    {
      declare subj, pred, obj any;
      declare pred_tagname varchar;
      declare res varchar;
      subj := triples[tctr][0];
      pred := triples[tctr][1];
      obj := triples[tctr][2];
      http ('\n<rdf:Description', ses);
      if (not isiri_id (subj))
        {
          if (isstring (subj) and (1 = __box_flags (subj)))
            {
              if (subj like 'nodeID://%')
                {
                  http (' rdf:nodeID="', ses); http_value (subj, 0, ses); http ('"/>', ses);
                }
              else
                {
                  http (' rdf:about="', ses); http_value (subj, 0, ses); http ('">', ses);
                }
            }
          else if (subj is null)
            signal ('RDFXX', 'DB.DBA.TRIPLES_TO_RDF_XML_TEXT(): subject is NULL');
          else
          signal ('RDFXX', 'DB.DBA.TRIPLES_TO_RDF_XML_TEXT(): subject is literal');
        }
      else if (subj >= min_bnode_iri_id ())
        http (sprintf (' rdf:nodeID="b%d">', iri_id_num (subj)), ses);
      else
        {
          res := id_to_iri (subj);
--          res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = subj));
          http (' rdf:about="', ses); http_value (res, 0, ses); http ('">', ses);
        }
      if (not isiri_id (pred))
        {
          if (isstring (pred) and (1 = __box_flags (pred)))
            {
              if (pred like 'nodeID://%')
                signal ('RDFXX', 'DB.DBA.TRIPLES_TO_RDF_XML_TEXT(): blank node as predicate');
              res := pred;
              goto res_for_pred;
            }
          else if (pred is null)
            signal ('RDFXX', 'DB.DBA.TRIPLES_TO_RDF_XML_TEXT(): predicate is NULL');
          else
          signal ('RDFXX', 'DB.DBA.TRIPLES_TO_RDF_XML_TEXT(): predicate is literal');
        }
      if (pred >= min_bnode_iri_id ())
        signal ('RDFXX', 'DB.DBA.TRIPLES_TO_RDF_XML_TEXT(): blank node as predicate');
          res := id_to_iri (pred);
res_for_pred:
          declare delim, delim1, delim2, delim3 integer;
	  delim1 := coalesce (strrchr (res, '/'), -1);
	  delim2 := coalesce (strrchr (res, '#'), -1);
	  delim3 := coalesce (strrchr (res, ':'), -1);
          delim := __max (delim1, delim2, delim3);
	  if (delim < 0)
	    delim := null;
          if (delim is null)
            {
              pred_tagname := res;
              http ('<', ses); http (pred_tagname, ses);
            }
          else
            {
              pred_tagname := 'ns0pred:' || subseq (res, delim+1);
              http ('<', ses); http (pred_tagname, ses);
              http (' xmlns:ns0pred="', ses); http_value (subseq (res, 0, delim+1), 0, ses);
              http ('"', ses);
            }
      if (obj is null)
        signal ('RDFXX', 'DB.DBA.TRIPLES_TO_RDF_XML_TEXT(): object is NULL');
      if (isiri_id (obj))
        {
          if (obj >= min_bnode_iri_id ())
            http (sprintf (' rdf:nodeID="b%d"/>', iri_id_num (obj)), ses);
          else
            {
              res := coalesce (id_to_iri(obj), sprintf ('_:bad_iid_%d', iri_id_num (obj)));
--              res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = obj), sprintf ('_:bad_iid_%d', iri_id_num (obj)));
              http (' rdf:resource="', ses); http_value (res, 0, ses); http ('"/>', ses);
            }
        }
      else if (__tag of rdf_box = __tag (obj))
        {
          declare dat any;
          if (257 <> rdf_box_type (obj))
            {
              res := coalesce ((select RDT_QNAME from DB.DBA.RDF_DATATYPE where RDT_TWOBYTE = rdf_box_type (obj)));
              http (' rdf:datatype="', ses); http_value (res, 0, ses); http ('"', ses);
            }
          else if (257 <> rdf_box_lang (obj))
            {
              res := coalesce ((select lower (RL_ID) from DB.DBA.RDF_LANGUAGE where RL_TWOBYTE = rdf_box_lang (obj)));
              http (' xml:lang="', ses); http_value (res, 0, ses); http ('"', ses);
            }
          dat := __rdf_sqlval_of_obj (obj, 1);
          if (__tag of XML = __tag (dat))
            {
              http (' rdf:parseType="Literal">', ses);
              http_value (dat, 0, ses);
              http ('</', ses); http (pred_tagname, ses); http ('>', ses);
            }
          else if (__tag of datetime = rdf_box_data_tag (obj))
            {
	      if (257 = rdf_box_type (obj))
		{
		  http (' rdf:datatype="', ses);
		  http_escape (cast (__xsd_type (dat) as varchar), 12, ses, 1, 1);
		  http ('">', ses);
		}
	      else
		http ('>', ses);
              __rdf_long_to_ttl (dat, ses);
              http ('</', ses); http (pred_tagname, ses); http ('>', ses);
            }
          else
            {
	      declare tmp any;
              http ('>', ses);
	      tmp := DB.DBA.RDF_STRSQLVAL_OF_LONG (obj);
	      if (__tag of varchar = __tag (tmp))
		tmp := charset_recode (tmp, 'UTF-8', '_WIDE_');
              http_value (tmp, 0, ses);
              http ('</', ses); http (pred_tagname, ses); http ('>', ses);
            }
        }
      else if (__tag of varchar = __tag (obj))
        {
          if (1 = __box_flags (obj))
            {
              if (obj like 'nodeID://%')
                {
                  http (' rdf:nodeID="', ses); http_value (obj, 0, ses); http ('"/>', ses);
                }
              else
                {
                  http (' rdf:resource="', ses); http_value (obj, 0, ses); http ('"/>', ses);
                }
            }
          else
            {
          http ('>', ses);
	  obj := charset_recode (obj, 'UTF-8', '_WIDE_');
          http_value (obj, 0, ses);
          http ('</', ses); http (pred_tagname, ses); http ('>', ses);
        }
        }
      else if (__tag of varbinary = __tag (obj))
        {
          http ('>', ses);
          http_value (obj, 0, ses);
          http ('</', ses); http (pred_tagname, ses); http ('>', ses);
        }
      else if (__tag of datetime = rdf_box_data_tag (obj))
        {
          http (' rdf:datatype="', ses);
          http_escape (cast (__xsd_type (obj) as varchar), 12, ses, 1, 1);
          http ('">', ses);
          __rdf_long_to_ttl (obj, ses);
          http ('</', ses); http (pred_tagname, ses); http ('>', ses);
        }
      else
        {
          http (' rdf:datatype="', ses);
          http_value (__xsd_type (obj), 0, ses);
          http ('">', ses);
          http_value (DB.DBA.RDF_STRSQLVAL_OF_LONG (obj), 0, ses);
          http ('</', ses); http (pred_tagname, ses); http ('>', ses);
        }
      http ('</rdf:Description>', ses);
    }
  if (print_top_level)
    {
      http ('\n</rdf:RDF>', ses);
    }
}
;

--create procedure DB.DBA.TEST_SPARQL_RDF_XML_TEXT (in query varchar, in dflt_graph varchar)
--{
--  declare ses, rset, triples any;
--  declare txt varchar;
--  ses := string_output ();
--  rset := DB.DBA.SPARQL_EVAL_TO_ARRAY (query, dflt_graph, 1);
--  triples := dict_list_keys (rset[0][0], 1);
--  DB.DBA.RDF_TRIPLES_TO_RDF_XML_TEXT (triples, 1, ses);
--  txt := string_output_string (ses);
--  dump_large_text (txt);
--}
--;

-----
-- Export into external serializations for 'define output:format "..."'

create procedure DB.DBA.RDF_FORMAT_RESULT_SET_AS_TTL_INIT (inout _env any)
{
  _env := string_output();
  http ('@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rs: <http://www.w3.org/2005/sparql-results#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
[ rdf:type rs:results ;', _env);
}
;

create procedure DB.DBA.RDF_FORMAT_RESULT_SET_AS_TTL_ACC (inout _env any, inout colvalues any, inout colnames any)
{
  declare col_ctr, col_count integer;
  declare blank_ids any;
  if (185 <> __tag(_env))
    DB.DBA.RDF_FORMAT_RESULT_SET_AS_TTL_INIT (_env);
  http ('\n  rs:result [', _env);
  col_count := length (colnames);
  for (col_ctr := 0; col_ctr < col_count; col_ctr := col_ctr + 1)
    {
      declare _name varchar;
      declare _val any;
      _name := colnames[col_ctr];
      _val := colvalues[col_ctr];
      if (_val is null)
        goto end_of_binding;
      http ('\n      rs:binding [ rs:name "', _env);
      http_value (colnames[col_ctr], 0, _env);
      http ('" ; rs:value ', _env);
      if (isiri_id (_val))
        {
          if (_val >= min_bnode_iri_id ())
	    {
	      http (sprintf ('_:nodeID%d ] ;', iri_id_num (_val)), _env);
	    }
	  else
	    {
              declare res varchar;
              res := id_to_iri (_val);
--              res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = _val));
              if (res is null)
                res := sprintf ('<bad://%d>', iri_id_num (_val));
	      http (sprintf ('<%V> ] ;', res), _env);
	    }
	}
      else
        {
          DB.DBA.RDF_LONG_TO_TTL (_val, _env);
          http (sprintf (' ] ;'), _env);
        }
end_of_binding: ;

    }
  http ('\n      ] ;', _env);
}
;

create function DB.DBA.RDF_FORMAT_RESULT_SET_AS_TTL_FIN (inout _env any) returns long varchar
{
  if (185 <> __tag(_env))
    DB.DBA.RDF_FORMAT_RESULT_SET_AS_TTL_INIT (_env);

  http ('\n    ] .', _env);
  return string_output_string (_env);
}
;

create aggregate DB.DBA.RDF_FORMAT_RESULT_SET_AS_TTL (in colvalues any, in colnames any) returns long varchar
from DB.DBA.RDF_FORMAT_RESULT_SET_AS_TTL_INIT, DB.DBA.RDF_FORMAT_RESULT_SET_AS_TTL_ACC, DB.DBA.RDF_FORMAT_RESULT_SET_AS_TTL_FIN
;

create procedure DB.DBA.RDF_FORMAT_RESULT_SET_AS_RDF_XML_INIT (inout _env any)
{
  _env := string_output();
  http ('<rdf:RDF
 xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
 xmlns:rs="http://www.w3.org/2005/sparql-results#"
 xmlns:xsd="http://www.w3.org/2001/XMLSchema#" >
  <rs:results rdf:nodeID="rset">', _env);
}
;

create procedure DB.DBA.RDF_FORMAT_RESULT_SET_AS_RDF_XML_ACC (inout _env any, inout colvalues any, inout colnames any)
{
  declare sol_id varchar;
  declare col_ctr, col_count integer;
  declare blank_ids any;
  if (185 <> __tag(_env))
    DB.DBA.RDF_FORMAT_RESULT_SET_AS_RDF_XML_INIT (_env);
  sol_id := cast (length (_env) as varchar);
  http ('\n  <rs:result rdf:nodeID="sol' || sol_id || '">', _env);
  col_count := length (colnames);
  for (col_ctr := 0; col_ctr < col_count; col_ctr := col_ctr + 1)
    {
      declare _name varchar;
      declare _val any;
      _name := colnames[col_ctr];
      _val := colvalues[col_ctr];
      if (_val is null)
        goto end_of_binding;
      http ('\n   <rs:binding rdf:nodeID="sol' || sol_id || '-' || cast (col_ctr as varchar) || '" rs:name="', _env);
      http_value (colnames[col_ctr], 0, _env);
      http ('"><rs:value', _env);
      if (isiri_id (_val))
        {
          if (_val >= min_bnode_iri_id ())
	    {
	      http (sprintf (' rdf:nodeID="%d"/></rs:binding>', iri_id_num (_val)), _env);
	    }
	  else
	    {
              declare res varchar;
              res := id_to_iri (_val);
--              res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = _val));
              if (res is null)
                res := sprintf ('bad://%d', iri_id_num (_val));
	      http (sprintf (' rdf:resource="%V"/></rs:binding>', res), _env);
	    }
	}
      else
        {
	  declare lang, dt varchar;
	  lang := DB.DBA.RDF_LANGUAGE_OF_LONG (_val, null);
	  dt := DB.DBA.RDF_DATATYPE_IRI_OF_LONG (_val, null);
	  if (lang is not null)
	    {
	      if (dt is not null)
                http (sprintf (' xml:lang="%V" rdf:datatype="%V">',
		    cast (lang as varchar), cast (dt as varchar)), _env);
	      else
                http (sprintf (' xml:lang="%V">',
		    cast (lang as varchar)), _env);
	    }
	  else
	    {
	      if (dt is not null)
                http (sprintf (' rdf:datatype="%V">',
		    cast (dt as varchar)), _env);
	      else
                http (sprintf ('>'), _env);
	    }
	  http_value (DB.DBA.RDF_STRSQLVAL_OF_LONG (_val), 0, _env);
          http ('</rs:value></rs:binding>', _env);
        }
end_of_binding: ;

    }
  http ('\n  </rs:result>', _env);
}
;

create function DB.DBA.RDF_FORMAT_RESULT_SET_AS_RDF_XML_FIN (inout _env any) returns long varchar
{
  if (185 <> __tag(_env))
    DB.DBA.RDF_FORMAT_RESULT_SET_AS_RDF_XML_INIT (_env);

  http ('\n </rs:results>\n</rdf:RDF>', _env);
  return string_output_string (_env);
}
;

create aggregate DB.DBA.RDF_FORMAT_RESULT_SET_AS_RDF_XML (in colvalues any, in colnames any) returns long varchar
from DB.DBA.RDF_FORMAT_RESULT_SET_AS_RDF_XML_INIT, DB.DBA.RDF_FORMAT_RESULT_SET_AS_RDF_XML_ACC, DB.DBA.RDF_FORMAT_RESULT_SET_AS_RDF_XML_FIN
;

create function DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_TTL (inout triples_dict any) returns long varchar
{
  declare triples, ses any;
  ses := string_output ();
  if (214 <> __tag (triples_dict))
    {
      triples := vector ();
    }
  else
    triples := dict_list_keys (triples_dict, 1);
  DB.DBA.RDF_TRIPLES_TO_TTL (triples, ses);
  return ses;
}
;

create function DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_RDF_XML (inout triples_dict any) returns long varchar
{
  declare triples, ses any;
  ses := string_output ();
  if (214 <> __tag (triples_dict))
    {
      triples := vector ();
    }
  else
    triples := dict_list_keys (triples_dict, 1);
  DB.DBA.RDF_TRIPLES_TO_RDF_XML_TEXT (triples, 1, ses);
  return ses;
}
;

--!AWK PUBLIC
create procedure DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_RDF_XML_INIT (inout _env any)
{
  _env := 0;
}
;

--!AWK PUBLIC
create procedure DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_RDF_XML_ACC (inout _env any, inout one any)
{
  _env := 1;
}
;

--!AWK PUBLIC
create function DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_RDF_XML_FIN (inout _env any) returns long varchar
{
  declare ses any;
  declare ans varchar;
  ses := string_output ();
  if (isinteger (_env) and _env)
    ans := '1';
  else
    ans := '0';
  http ('<rdf:RDF
 xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
 xmlns:rs="http://www.w3.org/2005/sparql-results#"
 xmlns:xsd="http://www.w3.org/2001/XMLSchema#" >
  <rs:results rdf:nodeID="rset">
   <rs:boolean rdf:datatype="http://www.w3.org/2001/XMLSchema#boolean">' || ans || '</rs:boolean></results></rdf:RDF>', ses);
  return ses;
}
;

create aggregate DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_RDF_XML (inout one any) returns long varchar
from DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_RDF_XML_INIT, DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_RDF_XML_ACC, DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_RDF_XML_FIN
;

--!AWK PUBLIC
create procedure DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_TTL_INIT (inout _env any)
{
  _env := 0;
}
;

--!AWK PUBLIC
create procedure DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_TTL_ACC (inout _env any, inout one any)
{
  _env := 1;
}
;

--!AWK PUBLIC
create function DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_TTL_FIN (inout _env any) returns long varchar
{
  declare ses any;
  declare ans varchar;
  ses := string_output ();
  if (isinteger (_env) and _env)
    ans := 'TRUE';
  else
    ans := 'FALSE';
  http ('@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rs: <http://www.w3.org/2005/sparql-results#> .\n', ses);
  http (sprintf ('[ rdf:type rs:results ; rs:boolean %s ]', ans), ses);
  return ses;
}
;

create aggregate DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_TTL (inout one any) returns long varchar
from DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_TTL_INIT, DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_TTL_ACC, DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_TTL_FIN
;

-----
-- Insert, delete, modify operations for lists of triples

create procedure DB.DBA.RDF_INSERT_TRIPLES (in graph_iri any, in triples any, in log_mode integer := null)
{
  declare ctr, old_log_enable integer;
  declare ro_id_dict any;
  if (not isiri_id (graph_iri))
    graph_iri := DB.DBA.RDF_MAKE_IID_OF_QNAME (graph_iri);
  old_log_enable := log_enable (log_mode, 1);
  declare exit handler for sqlstate '*' { log_enable (old_log_enable, 1); resignal; };
  ro_id_dict := null;
  for (ctr := length (triples) - 1; ctr >= 0; ctr := ctr - 1)
    {
      declare p_iid, o_orig, o_final any;
      declare need_digest integer;
      p_iid := triples[ctr][1];
      o_final := o_orig := triples[ctr][2];
      if (isiri_id (o_final))
        goto do_insert;
      if (ro_id_dict is null and __rdf_obj_ft_rule_check (graph_iri, p_iid))
        ro_id_dict := dict_new ();
      need_digest := rdf_box_needs_digest (o_final, ro_id_dict);
      if (1 < need_digest)
        {
          o_final := DB.DBA.RDF_MAKE_OBJ_OF_SQLVAL_FT (o_final, graph_iri, p_iid, ro_id_dict);
          if (not rdf_box_is_storeable (o_final))
            {
              -- dbg_obj_princ ('OBLOM', 'Bad O after MAKE_OBJ_OF_SQLVAL_FT', o_orig, '=>', o_final);
              signal ('OBLOM', 'Bad O after MAKE_OBJ_OF_SQLVAL_FT');
        }
        }
      else --if (1 = need_digest)
        {
          o_final := DB.DBA.RDF_OBJ_OF_LONG (o_final);
          if (not rdf_box_is_storeable (o_final))
            {
              -- dbg_obj_princ ('OBLOM', 'Bad O after RDF_OBJ_OF_LONG', o_orig, '=>', o_final);
              signal ('OBLOM', 'Bad O after MAKE_OBJ_OF_SQLVAL_FT');
            }
        }
do_insert:
      -- dbg_obj_princ ('DB.DBA.RDF_INSERT_TRIPLES: ', graph_iri, triples[ctr][0], p_iid, o_final);
      insert soft DB.DBA.RDF_QUAD (G,S,P,O)
      values (graph_iri, triples[ctr][0], p_iid, o_final);
    }
  if (ro_id_dict is not null)
    DB.DBA.RDF_OBJ_ADD_KEYWORD_FOR_GRAPH (graph_iri, ro_id_dict);
  log_enable (old_log_enable, 1);
}
;

create procedure DB.DBA.RDF_DELETE_TRIPLES (in graph_iri any, in triples any, in log_mode integer := null)
{
  declare ctr, old_log_enable integer;
  if (not isiri_id (graph_iri))
    graph_iri := DB.DBA.RDF_MAKE_IID_OF_QNAME (graph_iri);
  old_log_enable := log_enable (log_mode, 1);
  declare exit handler for sqlstate '*' { log_enable (old_log_enable, 1); resignal; };
  for (ctr := length (triples) - 1; ctr >= 0; ctr := ctr - 1)
    {
      declare o_short any;
      o_short := DB.DBA.RDF_OBJ_OF_LONG (triples[ctr][2]);
--      {
--        whenever sqlstate '*' goto strange_fail;
        delete from DB.DBA.RDF_QUAD
        where G = graph_iri and S = triples[ctr][0] and P = triples[ctr][1] and O = o_short;
--        goto complete;
--      }
--strange_fail:
--      if (not exists (select top 1 1 from DB.DBA.RDF_QUAD
--      where G = graph_iri and S = triples[ctr][0] and P = triples[ctr][1] and O = o_short ) )
--        goto complete;
--      delete from DB.DBA.RDF_QUAD
--      where G = graph_iri and S = triples[ctr][0] and P = triples[ctr][1] and O = o_short;
-- complete: ;
    }
  log_enable (old_log_enable, 1);
}
;

create procedure DB.DBA.RDF_MODIFY_TRIPLES (in graph_iri any, in del_triples any, in ins_triples any, in log_mode integer := null)
{
  DB.DBA.RDF_DELETE_TRIPLES (graph_iri, del_triples, log_mode);
  DB.DBA.RDF_INSERT_TRIPLES (graph_iri, ins_triples, log_mode);
}
;

--!AWK PUBLIC
create procedure DB.DBA.SPARQL_INS_OR_DEL_OR_MODIFY_CTOR_INIT (inout _env any)
{
  _env := 0; -- No actual initialization
}
;

--!AWK PUBLIC
create procedure DB.DBA.SPARQL_INS_OR_DEL_CTOR_IMPL (inout _env any, in graph_iri any, in opcodes any, in vars any, in log_mode integer, in ctor_op integer)
{
  declare triple_ctr integer;
  declare blank_ids any;
  declare action_ctr integer;
  declare old_log_enable integer;
  old_log_enable := log_enable (log_mode, 1);
  declare exit handler for sqlstate '*' { log_enable (old_log_enable, 1); resignal; };
  if (not (isarray (_env)))
    _env := vector (iri_to_id (graph_iri, 1), 0, 0);
  blank_ids := 0;
  action_ctr := 0;
  for (triple_ctr := length (opcodes) - 1; triple_ctr >= 0; triple_ctr := triple_ctr-1)
    {
      declare fld_ctr integer;
      declare triple_vec any;
      triple_vec := vector (0,0,0);
      for (fld_ctr := 2; fld_ctr >= 0; fld_ctr := fld_ctr - 1)
        {
          declare op integer;
          declare arg any;
          op := opcodes[triple_ctr][fld_ctr * 2];
          arg := opcodes[triple_ctr][fld_ctr * 2 + 1];
          if (1 = op)
            {
              declare i IRI_ID;
              i := vars[arg];
              if (i is null)
                goto end_of_adding_triple;
              if ((2 > fld_ctr) and not isiri_id (i))
                signal ('RDF01',
                  sprintf ('Bad variable value in INSERT: "%.100s" is not a valid %s, only object of a triple can be a literal',
                    DB.DBA.RDF_STRSQLVAL_OF_LONG (i),
                    case (fld_ctr) when 1 then 'predicate' else 'subject' end ) );
              if ((1 = fld_ctr) and isiri_id (i) and (i >= min_bnode_iri_id ()))
                signal ('RDF01', 'Bad variable value in INSERT: blank node can not be used as predicate');
              triple_vec[fld_ctr] := i;
            }
          else if (2 = op)
            {
	      if (isinteger (blank_ids))
	        blank_ids := vector (iri_id_from_num (sequence_next ('RDF_URL_IID_BLANK')));
              while (arg >= length (blank_ids))
                blank_ids := vector_concat (blank_ids, vector (iri_id_from_num (sequence_next ('RDF_URL_IID_BLANK'))));
              if (1 = fld_ctr)
                signal ('RDF01', 'Bad triple for INSERT: blank node can not be used as predicate');
              triple_vec[fld_ctr] := blank_ids[arg];
            }
          else if (3 = op)
            {
              if (arg is null)
                goto end_of_adding_triple;
              if ((2 > fld_ctr) and not isiri_id (arg))
                signal ('RDF01', sprintf ('Bad const value in INSERT: "%.100s" is not a valid %s, only object of a triple can be a literal',
                  DB.DBA.RDF_STRSQLVAL_OF_LONG (arg),
                  case (fld_ctr) when 1 then 'predicate' else 'subject' end ) );
              if ((1 = fld_ctr) and isiri_id (arg) and (arg >= min_bnode_iri_id ()))
                signal ('RDF01', 'Bad const value in CONSTRUCT: blank node can not be used as predicate');
              triple_vec[fld_ctr] := arg;
            }
          else signal ('RDFXX', 'Bad opcode in DB.DBA.SPARQL_INSERT_CTOR()');
        }
      -- dbg_obj_princ ('generated triple:', triple_vec);
      if (1 = ctor_op)
        {
          delete from DB.DBA.RDF_QUAD
          where G = _env[0] and S = triple_vec[0] and P = triple_vec[1] and O = DB.DBA.RDF_OBJ_OF_LONG(triple_vec[2]);
        }
      else
        {
          insert soft DB.DBA.RDF_QUAD (G,S,P,O)
          values (_env[0], triple_vec[0], triple_vec[1], DB.DBA.RDF_OBJ_OF_LONG(triple_vec[2]));
        }
      action_ctr := action_ctr + 1;
end_of_adding_triple: ;
    }
  _env[ctor_op] := _env[ctor_op] + action_ctr;
  log_enable (old_log_enable, 1);
}
;

--!AWK PUBLIC
create function DB.DBA.SPARQL_DELETE_CTOR_ACC (inout _env any, in graph_iri any, in opcodes any, in vars any, in log_mode integer)
{
  DB.DBA.SPARQL_INS_OR_DEL_CTOR_IMPL (_env, graph_iri, opcodes, vars, log_mode, 1);
}
;

--!AWK PUBLIC
create procedure DB.DBA.SPARQL_INSERT_CTOR_ACC (inout _env any, in graph_iri any, in opcodes any, in vars any, in log_mode integer)
{
  DB.DBA.SPARQL_INS_OR_DEL_CTOR_IMPL (_env, graph_iri, opcodes, vars, log_mode, 2);
}
;

--!AWK PUBLIC
create procedure DB.DBA.SPARQL_MODIFY_CTOR_ACC (inout _env any, in graph_iri any, in del_opcodes any, in ins_opcodes any, in vars any, in log_mode integer)
{
  DB.DBA.SPARQL_INS_OR_DEL_CTOR_IMPL (_env, graph_iri, del_opcodes, vars, log_mode, 1);
  DB.DBA.SPARQL_INS_OR_DEL_CTOR_IMPL (_env, graph_iri, ins_opcodes, vars, log_mode, 2);
}
;

--!AWK PUBLIC
create procedure DB.DBA.SPARQL_INS_OR_DEL_OR_MODIFY_CTOR_FIN (inout _env any)
{
  return _env;
}
;

--!AWK PUBLIC
create aggregate DB.DBA.SPARQL_DELETE_CTOR (in graph_iri any, in opcodes any, in vars any, in log_mode integer) returns any
from DB.DBA.SPARQL_INS_OR_DEL_OR_MODIFY_CTOR_INIT, DB.DBA.SPARQL_DELETE_CTOR_ACC, DB.DBA.SPARQL_INS_OR_DEL_OR_MODIFY_CTOR_FIN
;

--!AWK PUBLIC
create aggregate DB.DBA.SPARQL_INSERT_CTOR (in graph_iri any, in opcodes any, in vars any, in log_mode integer) returns any
from DB.DBA.SPARQL_INS_OR_DEL_OR_MODIFY_CTOR_INIT, DB.DBA.SPARQL_INSERT_CTOR_ACC, DB.DBA.SPARQL_INS_OR_DEL_OR_MODIFY_CTOR_FIN
;

--!AWK PUBLIC
create aggregate DB.DBA.SPARQL_MODIFY_CTOR (in graph_iri any, in del_opcodes any, in ins_opcodes any, in vars any, in log_mode integer) returns any
from DB.DBA.SPARQL_INS_OR_DEL_OR_MODIFY_CTOR_INIT, DB.DBA.SPARQL_MODIFY_CTOR_ACC, DB.DBA.SPARQL_INS_OR_DEL_OR_MODIFY_CTOR_FIN
;

create function DB.DBA.SPARQL_INSERT_DICT_CONTENT (in graph_iri any, in triples_dict any, in log_mode integer := null) returns varchar
{
  declare triples any;
  declare ins_count integer;
  triples := dict_list_keys (triples_dict, 1);
  ins_count := 0;
  if (__tag of vector = __tag (graph_iri))
    {
      ins_count := graph_iri[2]; -- 2, not 1
      graph_iri := graph_iri[0]; -- the last op.
    }
  ins_count := ins_count + length (triples);
  DB.DBA.RDF_INSERT_TRIPLES (graph_iri, triples, log_mode);
  if (isiri_id (graph_iri))
    graph_iri := id_to_iri (graph_iri);
  return sprintf ('Insert into <%s>, %d triples -- done', graph_iri, ins_count);
}
;

create function DB.DBA.SPARQL_DELETE_DICT_CONTENT (in graph_iri any, in triples_dict any, in log_mode integer := null) returns varchar
{
  declare triples any;
  declare del_count integer;
  triples := dict_list_keys (triples_dict, 1);
  del_count := 0;
  if (__tag of vector = __tag (graph_iri))
    {
      del_count := graph_iri[1];
      graph_iri := graph_iri[0]; -- the last op.
    }
  del_count := del_count + length (triples);
  DB.DBA.RDF_DELETE_TRIPLES (graph_iri, triples, log_mode);
  if (isiri_id (graph_iri))
    graph_iri := id_to_iri (graph_iri);
  return sprintf ('Delete from <%s>, %d triples -- done', graph_iri, del_count);
}
;

create function DB.DBA.SPARQL_MODIFY_BY_DICT_CONTENTS (in graph_iri any, in del_triples_dict any, in ins_triples_dict any, in log_mode integer := null) returns varchar
{
  declare del_count, ins_count integer;
  del_count := 0;
  ins_count := 0;
  if (__tag of vector = __tag (graph_iri))
    {
      del_count := graph_iri[1];
      ins_count := graph_iri[2];
      graph_iri := graph_iri[0]; -- the last op.
    }
  if (del_triples_dict is not null)
    {
      del_count := del_count + dict_size (del_triples_dict);
      DB.DBA.SPARQL_DELETE_DICT_CONTENT (graph_iri, del_triples_dict, log_mode);
    }
  if (ins_triples_dict is not null)
    {
      ins_count := ins_count + dict_size (ins_triples_dict);
      DB.DBA.SPARQL_INSERT_DICT_CONTENT (graph_iri, ins_triples_dict, log_mode);
    }
  if (isiri_id (graph_iri))
    graph_iri := id_to_iri (graph_iri);
  return sprintf ('Modify <%s>, delete %d and insert %d triples -- done', graph_iri, del_count, ins_count);
}
;

create function DB.DBA.SPARUL_CLEAR (in graph_iri any, in inside_sponge integer := 0) returns varchar
{
  commit work;
  delete from DB.DBA.RDF_QUAD
  where G = iri_to_id (graph_iri) and
  case (gt (__trx_disk_log_length (0, S, O), 1000000))
  when 0 then 1 else 1 + exec (coalesce ('commit work', S, O)) end;
  commit work;
  delete from DB.DBA.RDF_OBJ_RO_DIGEST_WORDS
  where VT_WORD = cast (iri_to_id (graph_iri) as varchar) and
  case (gt (__trx_disk_log_length (0, VT_D_ID, VT_D_ID_2), 1000000))
  when 0 then 1 else 1 + exec (coalesce ('commit work', VT_D_ID, VT_D_ID_2)) end;
  commit work;
  if (not inside_sponge)
  delete from DB.DBA.SYS_HTTP_SPONGE where HS_LOCAL_IRI = graph_iri;
  commit work;
  if (isiri_id (graph_iri))
    graph_iri := id_to_iri (graph_iri);
  return sprintf ('Clear <%s> -- done', graph_iri);
}
;

create function DB.DBA.SPARUL_LOAD (in graph_iri any, in resource varchar) returns varchar
{
  declare grab_params any;
  declare grabbed any;
  grabbed := dict_new();
  if (isiri_id (graph_iri))
    graph_iri := id_to_iri (graph_iri);
  grab_params := vector ('base_iri', resource, 'get:destination', graph_iri,
    'resolver', 'DB.DBA.RDF_GRAB_RESOLVER_DEFAULT', 'loader', 'DB.DBA.RDF_SPONGE_UP',
    'get:soft', 'replacing',
    'get:refresh', -1,
    'get:error-recovery', 'signal',
    -- 'flags', flags,
    'grabbed', grabbed );
  if (DB.DBA.RDF_GRAB_SINGLE (resource, grabbed, grab_params))
    return sprintf ('Load <%s> into graph <%s> -- done', resource, graph_iri);
  else
    return sprintf ('Load <%s> into graph <%s> -- failed', resource, graph_iri);
}
;

create function DB.DBA.SPARUL_RUN (in results any) returns varchar
{
  declare ses any;
  commit work;
  ses := string_output ();
  foreach (varchar r in results) do
    {
      http (r || '\n', ses);
    }
  http ('Commit -- done\n', ses);
  return string_output_string (ses);
}
;

-----
-- Built-in operations of SPARQL as SQL functions

--!AWK PUBLIC
create function DB.DBA.RDF_REGEX (in s varchar, in p varchar, in coll varchar := null)
{
-- !!!TBD proper use of third argument
  if (not iswidestring (s) and not isstring (s))
    return 0;
  if (regexp_match (p, s, 0) is not null)
    return 1;
  return 0;
}
;

--!AWK PUBLIC
create function DB.DBA.RDF_LANGMATCHES (in r varchar, in t varchar)
{
  if ('*' = t)
    {
      if (r <> '')
        return 1;
      return 0;
    }
  if ((t is null) or (r is null))
    return 0;
  t := upper (t);
  r := upper (r);
  if (r = t)
    return 1;
  if (r like t || '-%')
    return 1;
  return 0;
}
;

--!AWK PUBLIC
create procedure DB.DBA.SPARQL_CONSTRUCT_INIT (inout _env any)
{
  _env := 0; -- No actual initialization
}
;

--!AWK PUBLIC
create procedure DB.DBA.SPARQL_CONSTRUCT_ACC (inout _env any, in opcodes any, in vars any, in stats any)
{
  declare triple_ctr integer;
  declare blank_ids any;
  if (214 <> __tag(_env))
    {
      _env := dict_new ();
      if (0 < length (stats))
        DB.DBA.SPARQL_CONSTRUCT_ACC (_env, stats, vector(), vector());
    }
  blank_ids := 0;
  for (triple_ctr := length (opcodes) - 1; triple_ctr >= 0; triple_ctr := triple_ctr-1)
    {
      declare fld_ctr integer;
      declare triple_vec any;
      triple_vec := vector (0,0,0);
      for (fld_ctr := 2; fld_ctr >= 0; fld_ctr := fld_ctr - 1)
        {
          declare op integer;
          declare arg any;
          op := opcodes[triple_ctr][fld_ctr * 2];
          arg := opcodes[triple_ctr][fld_ctr * 2 + 1];
          if (1 = op)
            {
              declare i IRI_ID;
              i := vars[arg];
              if (i is null)
                goto end_of_adding_triple;
              if ((2 > fld_ctr) and not (isiri_id (i) or (isstring (i) and (1 = __box_flags (i)))))
                signal ('RDF01',
                  sprintf ('Bad variable value in CONSTRUCT: "%.100s" is not a valid %s, only object of a triple can be a literal',
                    DB.DBA.RDF_STRSQLVAL_OF_LONG (i),
                    case (fld_ctr) when 1 then 'predicate' else 'subject' end ) );
              if ((1 = fld_ctr) and (
                  (isiri_id (i) and (i >= min_bnode_iri_id ())) or
                  (isstring (i) and (i like 'bnode://%')) ) )
                signal ('RDF01', 'Bad variable value in CONSTRUCT: blank node can not be used as predicate');
              triple_vec[fld_ctr] := i;
            }
          else if (2 = op)
            {
	      if (isinteger (blank_ids))
	        blank_ids := vector (iri_id_from_num (sequence_next ('RDF_URL_IID_BLANK')));
              while (arg >= length (blank_ids))
                blank_ids := vector_concat (blank_ids, vector (iri_id_from_num (sequence_next ('RDF_URL_IID_BLANK'))));
              if (1 = fld_ctr)
                signal ('RDF01', 'Bad triple for CONSTRUCT: blank node can not be used as predicate');
              triple_vec[fld_ctr] := blank_ids[arg];
            }
          else if (3 = op)
            {
              if (arg is null)
                goto end_of_adding_triple;
              if ((2 > fld_ctr) and not (isiri_id (arg) or (isstring (arg) and (1 = __box_flags (arg)))))
                signal ('RDF01', sprintf ('Bad const value in CONSTRUCT: "%.100s" is not a valid %s, only object of a triple can be a literal',
                  DB.DBA.RDF_STRSQLVAL_OF_LONG (arg),
                  case (fld_ctr) when 1 then 'predicate' else 'subject' end ) );
              if ((1 = fld_ctr) and (
                  (isiri_id (arg) and (arg >= min_bnode_iri_id ())) or
                  (isstring (arg) and (arg like 'bnode://%')) ) )
                signal ('RDF01', 'Bad const value in CONSTRUCT: blank node can not be used as predicate');
              triple_vec[fld_ctr] := arg;
            }
          else signal ('RDFXX', 'Bad opcode in DB.DBA.SPARQL_CONSTRUCT()');
        }
      -- dbg_obj_princ ('generated triple:', triple_vec);
      dict_put (_env, triple_vec, 0);
end_of_adding_triple: ;
    }
}
;

--!AWK PUBLIC
create procedure DB.DBA.SPARQL_CONSTRUCT_FIN (inout _env any)
{
  if (214 <> __tag(_env))
    _env := dict_new ();
  return _env;
}
;

--!AWK PUBLIC
create aggregate DB.DBA.SPARQL_CONSTRUCT (in opcodes any, in vars any, in stats any) returns any
from DB.DBA.SPARQL_CONSTRUCT_INIT, DB.DBA.SPARQL_CONSTRUCT_ACC, DB.DBA.SPARQL_CONSTRUCT_FIN
;

create procedure DB.DBA.SPARQL_DESC_AGG_INIT (inout _env any)
{
  _env := 0; -- No actual initialization
}
;

create procedure DB.DBA.SPARQL_DESC_AGG_ACC (inout _env any, in vars any)
{
  declare var_ctr integer;
  declare blank_ids any;
  if (214 <> __tag(_env))
    _env := dict_new ();
  for (var_ctr := length (vars) - 1; var_ctr >= 0; var_ctr := var_ctr - 1)
    {
      declare i any;
      i := vars[var_ctr];
      if (isiri_id (i))
        dict_put (_env, i, 0);
    }
}
;

create procedure DB.DBA.SPARQL_DESC_AGG_FIN (inout _env any)
{
  declare subjects, options, res any;
  declare subj_ctr integer;
  if (214 <> __tag(_env))
    return dict_new ();
  return _env;
}
;

create aggregate DB.DBA.SPARQL_DESC_AGG (in vars any) returns any
from DB.DBA.SPARQL_DESC_AGG_INIT, DB.DBA.SPARQL_DESC_AGG_ACC, DB.DBA.SPARQL_DESC_AGG_FIN
;

create procedure DB.DBA.SPARQL_DESC_DICT (in subj_dict any, in consts any, in graphs any, in storage_name any, in options any)
{
  declare all_subj_descs, phys_subjects, sorted_graphs, res any;
  declare g_ctr, g_count, s_ctr, all_s_count, phys_s_count integer;
  declare rdf_type_iid IRI_ID;
  rdf_type_iid := iri_to_id (UNAME'http://www.w3.org/1999/02/22-rdf-syntax-ns#type', 1);
  res := dict_new ();
  if (isinteger (consts))
    return res;
  foreach (any c in consts) do
    {
      if (isiri_id (c))
        dict_put (subj_dict, c, 0);
    }
  all_subj_descs := dict_list_keys (subj_dict, 1);
  all_s_count := length (all_subj_descs);
  if (0 = all_s_count)
    return res;
  gvector_sort (all_subj_descs, 1, 0, 0);
  vectorbld_init (sorted_graphs);
  foreach (any g in graphs) do
    {
      if (isiri_id (g))
        vectorbld_acc (sorted_graphs, __min (g, min_bnode_iri_id ()));
    }
  vectorbld_final (sorted_graphs);
  g_count := length (sorted_graphs);
  vectorbld_init (phys_subjects);
  if (isinteger (storage_name))
    storage_name := 'http://www.openlinksw.com/schemas/virtrdf#DefaultQuadStorage';
  else if ('' = storage_name)
    {
      for (s_ctr := 0; s_ctr < all_s_count; s_ctr := s_ctr + 1)
        {
          declare s, phys_s any;
          s := all_subj_descs [s_ctr];
          if (isiri_id (s))
            vectorbld_acc (phys_subjects, s);
          else
            {
              phys_s := iri_to_id (s, 0, 0);
              if (not isinteger (phys_s))
                vectorbld_acc (phys_subjects, phys_s);
            }
        }
      vectorbld_final (phys_subjects);
      goto describe_physical_subjects;
    }
  -- dbg_obj_princ ('storage_name=',storage_name, ' sorted_graphs=', sorted_graphs);
  for (s_ctr := 0; s_ctr < all_s_count; s_ctr := s_ctr + 1)
    {
      declare s, phys_s, maps any;
      declare maps_len integer;
      s := all_subj_descs [s_ctr];
      maps := sparql_quad_maps_for_quad (NULL, s, NULL, NULL, storage_name, sorted_graphs);
      -- dbg_obj_princ ('s = ', s, ' maps = ', maps);
      maps_len := length (maps);
      if ((maps_len > 0) and (maps[maps_len-1][0] = UNAME'http://www.openlinksw.com/schemas/virtrdf#DefaultQuadMap'))
        {
          if (isiri_id (s))
            {
              phys_s := s;
              vectorbld_acc (phys_subjects, phys_s);
            }
          else
            {
              phys_s := iri_to_id (s, 0, 0);
              if (not isinteger (phys_s))
                vectorbld_acc (phys_subjects, phys_s);
            }
          maps := subseq (maps, 0, maps_len-1);
          maps_len := maps_len - 1;
        }
      if (maps_len > 0)
        all_subj_descs [s_ctr] := vector (s, maps);
      else
        all_subj_descs [s_ctr] := 0;
      -- dbg_obj_princ ('s = ', s, ' maps = ', maps);
      -- dbg_obj_princ ('all_subj_descs [', s_ctr, '] = ', all_subj_descs [s_ctr]);
    }
  vectorbld_final (phys_subjects);
  for (s_ctr := 0; s_ctr < all_s_count; s_ctr := s_ctr + 1)
    {
      declare s_desc, s, maps any;
      declare map_ctr, maps_len integer;
      declare fname varchar;
      s_desc := all_subj_descs [s_ctr];
      if (isinteger (s_desc))
        goto end_of_s;
      s := s_desc[0];
      maps := s_desc[1];
      maps_len := length (maps);
      fname := sprintf ('SPARQL_DESC_DICT_QMV1_%U', md5 (storage_name || md5_box (maps)));
      if (not exists (select top 1 1 from Db.DBA.SYS_PROCEDURES where P_NAME = 'DB.DBA.' || fname))
        {
          declare ses, txt, saved_user any;
          ses := string_output ();
          http ('create procedure DB.DBA."' || fname || '" (in subj any, inout res any)\n', ses);
          http ('{\n', ses);
          http ('  for (sparql define output:valmode "LONG" define input:storage <' || storage_name || '> select ?p1 ?o1\n', ses);
          http ('      where { graph ?g {\n', ses);
          for (map_ctr := 0; map_ctr < maps_len; map_ctr := map_ctr + 1)
            {
              if (map_ctr > 0) http ('              union\n', ses);
              http ('              { quad map <' || maps[map_ctr][0] || '> { `iri(?:subj)` ?p1 ?o1 } }\n', ses);
            }
          http ('            } } ) do { dict_put (res, vector (subj, "p1", "o1"), 1); } }\n', ses);
          txt := string_output_string (ses);
          -- dbg_obj_princ ('Procedure text: ', txt);
	  saved_user := user;
	  set_user_id ('dba', 1);
          exec (txt);
	  set_user_id (saved_user);
        }
      -- dbg_obj_princ ('call (''DB.DBA.', fname, ''')(', s, res, ')');
      call ('DB.DBA.' || fname)(s, res);
end_of_s: ;
    }

describe_physical_subjects:
  gvector_sort (phys_subjects, 1, 0, 0);
  phys_s_count := length (phys_subjects);
  -- dbg_obj_princ ('phys_subjects = ', phys_subjects);
  if (0 = phys_s_count)
    return res;
  if (0 = length (sorted_graphs))
    {
      declare g_dict any;
      g_dict := dict_new ();
      for (s_ctr := phys_s_count - 1; s_ctr >= 0; s_ctr := s_ctr - 1)
        {
          declare subj, graph any;
          subj := phys_subjects [s_ctr];
          graph := coalesce ((select top 1 G as g1 from DB.DBA.RDF_QUAD where O = subj));
          if (graph is not null)
            dict_put (g_dict, graph, 0);
        }
      sorted_graphs := dict_list_keys (g_dict, 1);
    }
  if (0 = length (sorted_graphs))
    {
      declare g_dict any;
      g_dict := dict_new ();
      for (s_ctr := phys_s_count - 1; s_ctr >= 0; s_ctr := s_ctr - 1)
        {
          declare subj, graph any;
          subj := phys_subjects [s_ctr];
          graph := coalesce ((select top 1 G as g1 from DB.DBA.RDF_QUAD where S = subj and P = rdf_type_iid));
          if (graph is not null)
            dict_put (g_dict, graph, 0);
        }
      sorted_graphs := dict_list_keys (g_dict, 1);
    }
  -- dbg_obj_princ ('sorted_graphs = ', sorted_graphs);
  gvector_sort (sorted_graphs, 1, 0, 0);
  g_count := length (sorted_graphs);
  -- dbg_obj_princ ('sorted_graphs = ', sorted_graphs);
  for (g_ctr := g_count - 1; g_ctr >= 0; g_ctr := g_ctr - 1)
    {
      declare graph any;
      graph := sorted_graphs [g_ctr];
      for (s_ctr := phys_s_count - 1; s_ctr >= 0; s_ctr := s_ctr - 1)
        {
          declare subj any;
          subj := phys_subjects [s_ctr];
          for (select P as p1, O as obj1 from DB.DBA.RDF_QUAD where G = graph and S = subj) do
            {
              -- dbg_obj_princ ('found ', subj, p1, ' in ', graph);
              dict_put (res, vector (subj, p1, __rdf_long_of_obj (obj1)), 0);
--              if (isiri_id (obj1))
--                {
--                  for (select P as p2, O as obj2
--                    from DB.DBA.RDF_QUAD
--                    where G = graph and S = obj1 and not (isiri_id (O)) ) do
--                    {
--                      dict_put (dict, vector (obj1, p2, __rdf_long_of_obj (obj2)), 0);
--                    }
--                }
            }
          for (select S as s1, P as p1 from DB.DBA.RDF_QUAD
            where G = graph and O = subj and P <> rdf_type_iid
            option (QUIETCAST)) do
            {
              -- dbg_obj_princ ('found ', s1, p1, subj, ' in ', graph);
              dict_put (res, vector (s1, p1, subj), 1);
            }
        }
    }
  return res;
}
;


-----
-- Internal functions used in SQL generated by SPARQL compiler.
-- They will change frequently, don't try to use them in applications!

create function DB.DBA.RDF_TYPEMIN_OF_OBJ (in obj any) returns any
{
  declare tag integer;
  if (obj is null)
    return NULL;
  tag := __tag (obj);
  if (tag in (__tag of integer, __tag of double precision, __tag of numeric))
    return -3.40282347e+38;
  if (tag = __tag of datetime)
    return cast ('0101-01-01' as datetime);
  if (tag = __tag of rdf_box)
    return rdf_box ('', rdf_box_type (obj), 257, 0, 1);
  if (tag = (__tag of varchar))
    return '';
  return NULL; -- Nothing else can be compared hence no min.
}
;

create function DB.DBA.RDF_TYPEMAX_OF_OBJ (in obj any) returns any
{
  declare tag integer;
  if (obj is null)
    return NULL;
  tag := __tag (obj);
  if (tag in (__tag of integer, __tag of double precision, __tag of numeric))
    return 3.40282347e+38;
  if (tag = __tag of datetime)
    return cast ('9999-12-30' as datetime);
  if (tag = __tag of rdf_box)
    return rdf_box ('\377\377\377\377\377\377', rdf_box_type (obj), 257, 0, 1);
  if (tag = (__tag of varchar))
    return '\377\377\377\377\377\377';
  return NULL; -- Nothing else can be compared hence no max.
}
;

create function DB.DBA.RDF_IID_CMP (in obj1 any, in obj2 any) returns integer
{
  return NULL;
}
;

create function DB.DBA.RDF_OBJ_CMP (in obj1 any, in obj2 any) returns integer
{
  declare tag1, tag2 integer;
  if (obj1 is null or obj2 is null)
    return NULL;
  tag1 := __tag (obj1);
  tag2 := __tag (obj2);
  if (tag1 = __tag of rdf_box)
    {
      if (tag2 = __tag of rdf_box)
        {
          if (obj1 = obj2)
            return 0;
          if (rdf_box_type (obj1) <> rdf_box_type (obj2))
            return null;
          if (not rdf_box_is_complete (obj1))
            {
              declare id1 integer;
              declare full1 varchar;
              id1 := rdf_box_ro_id (obj1);
              if (__tag of XML = rdf_box_data_tag (obj1))
                return null;
              full1 := (select case (isnull (RO_LONG)) when 0 then blob_to_string (RO_LONG) else RO_VAL end from DB.DBA.RDF_OBJ where RO_ID = id1);
              if (full1 is null)
                signal ('RDFXX', sprintf ('Integrity violation in DB.DBA.RDF_OBJ_CMP, bad id %d', id1));
              rdf_box_set_data (obj1, full1, 1);
            }
          if (not rdf_box_is_complete (obj2))
            {
              declare id2 integer;
              declare full2 varchar;
              id2 := rdf_box_ro_id (obj2);
              if (__tag of XML = rdf_box_data_tag (obj2))
                return null;
              full2 := (select case (isnull (RO_LONG)) when 0 then blob_to_string (RO_LONG) else RO_VAL end from DB.DBA.RDF_OBJ where RO_ID = id2);
              if (full2 is null)
                signal ('RDFXX', sprintf ('Integrity violation in DB.DBA.RDF_OBJ_CMP, bad id %d', id2));
              rdf_box_set_data (obj2, full2, 1);
            }
          return rdf_box_strcmp (obj1, obj2);
        }
       return null;
     }
  if (tag1 in (__tag of integer, __tag of double precision, __tag of numeric))
    {
      if (tag2 in (__tag of integer, __tag of double precision, __tag of numeric))
        {
          if (obj1 <> obj2)
            {
              if (obj1 < obj2)
                return -1;
              return 1;
            }
          return 0;
        }
      return null;
    }
  if (tag1 = __tag of datetime)
    {
      if (tag2 = __tag of datetime)
        {
          if (obj1 <> obj2)
            {
              if (obj1 < obj2)
                return -1;
              return 1;
            }
          return 0;
        }
      return null;
    }
  return NULL;
}
;

create function DB.DBA.RDF_LONG_CMP (in long1 any, in long2 any) returns integer
{
  declare tag1, tag2 integer;
  if (long1 is null or long2 is null)
    return NULL;
  tag1 := __tag (long1);
  tag2 := __tag (long2);
  if (tag1 = __tag of rdf_box)
    {
      if (tag2 = __tag of rdf_box)
        return rdf_box_strcmp (long1, long2);
       return null;
     }
  if (tag1 in (__tag of integer, __tag of double precision, __tag of numeric))
    {
      if (tag2 in (__tag of integer, __tag of double precision, __tag of numeric))
        {
          if (long1 <> long2)
            {
              if (long1 < long2)
                return -1;
              return 1;
            }
          return 0;
        }
      return null;
    }
  if (tag1 = __tag of datetime)
    {
      if (tag2 = __tag of datetime)
        {
          if (long1 <> long2)
            {
              if (long1 < long2)
                return -1;
              return 1;
            }
          return 0;
        }
      return null;
    }
  return NULL;
}
;


--!AWK PUBLIC
create function DB.DBA.RDF_DIST_SER_LONG (in val any) returns any -- DEPRECATED
{
  if (not (isstring (val)))
    {
      if (__tag of rdf_box = __tag (val))
        {
	  if (rdf_box_is_storeable (val))
	    return serialize (val);
          return serialize (vector (rdf_box_data (val), rdf_box_type (val), rdf_box_lang (val), rdf_box_is_complete (val)));
	}
      return serialize (val);
    }
  if ('' = val)
    return val;
  if (val[0] < 128)
    return val;
  return serialize (val);
}
;

--!AWK PUBLIC
create function DB.DBA.RDF_DIST_DESER_LONG (in strg any) returns any -- DEPRECATED
{
  if (not (isstring (strg)))
    return strg;
  if ('' = strg)
    return strg;
  if (strg[0] < 128)
    return strg;
  declare res any;
  res := deserialize (strg);
  if (__tag of vector <> __tag (res))
    return res;
  return rdf_box (res[0], res[1], res[2], 0, res[3]);
}
;

-----
-- JSO procedures

create function JSO_MAKE_INHERITANCE (in jgraph varchar, in class varchar, in rootinst varchar, in destinst varchar, in dest_iid iri_id, inout noinherits any, inout inh_stack any)
{
  declare base_iid iri_id;
  declare baseinst varchar;
  -- dbg_obj_princ ('JSO_MAKE_INHERITANCE (', jgraph, class, rootinst, destinst, ')');
  inh_stack := vector_concat (inh_stack, vector (destinst));
  baseinst := null;
  if (not exists (sparql
      define input:storage ""
      prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
      ask where {
        graph ?:jgraph { ?:dest_iid rdf:type `iri(?:class)`
          } } ) )
    signal ('22023', 'JSO_MAKE_INHERITANCE has not found object <' || destinst || '> of type <' || class || '>');
/* This fails. !!!TBD: fix sparql2sql.c to preserve data about equalities, fixed values and globals when triples are moved from gp to gp
  for (sparql
    define input:storage ""
    prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
    select ?srcinst
    where {
        graph ?:jgraph {
            { {
                ?destnode rdf:type `iri(?:class)` .
                filter (?destnode = iri(?:destinst)) }
              union
              {
                ?destnode rdf:type `iri(?:class)` .
                ?destnode rdf:name `iri(?:destinst)` } } .
            ?destnode virtrdf:inheritFrom ?srcinst .
            ?srcinst rdf:type `iri(?:class)` .
          } } ) do
*/
  for (sparql
    define input:storage ""
    define output:valmode "LONG"
    prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
    select ?src_iid
    where {
        graph ?:jgraph { ?:dest_iid virtrdf:inheritFrom ?src_iid } } ) do
    {
      declare srcinst varchar;
      srcinst := id_to_iri_nosignal ("src_iid");
      if (baseinst is null)
        {
          if (not exists (sparql
              define input:storage ""
              prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
              ask where { graph ?:jgraph { ?:"src_iid" rdf:type `iri(?:class)` } } ) )
            signal ('22023', 'JSO_MAKE_INHERITANCE has found that the object <' || destinst || '> has wrong virtrdf:inheritFrom <' || srcinst || '> that is not an instance of type <' || class || '>');
          base_iid := "src_iid";
          baseinst := srcinst;
        }
      else if (baseinst <> srcinst)
        signal ('22023', 'JSO_MAKE_INHERITANCE has found that the object <' || destinst || '> has multiple virtrdf:inheritFrom declarations: <' || baseinst || '> and <' || srcinst || '>');
    }
  if (position (baseinst, inh_stack))
    signal ('22023', 'JSO_MAKE_INHERITANCE has found that the object <' || baseinst || '> is recursively inherited from itself');
/* This fails. !!!TBD: fix sparql2sql.c to preserve data about equalities, fixed values and globals when triples are moved from gp to gp
  for (sparql
    define input:storage ""
    prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
    select ?pred
    where {
        graph ?:jgraph {
            { {
                ?destnode rdf:type `iri(?:class)` .
                filter (?destnode = iri(?:destinst)) }
              union
              {
                ?destnode rdf:type `iri(?:class)` .
                ?destnode rdf:name `iri(?:destinst)` } } .
            ?destnode virtrdf:noInherit ?pred .
          } } ) do
*/
  for (sparql
    define input:storage ""
    prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
    select ?pred
    where {
        graph ?:jgraph {
            ?:dest_iid virtrdf:noInherit ?pred
          } } ) do
    {
      if (baseinst is null)
        signal ('22023', 'JSO_MAKE_INHERITANCE has found that the object <' || destinst || '> has set virtrdf:noInherit but has no virtrdf:inheritFrom');
      dict_put (noinherits, "pred", destinst);
    }
  if (baseinst is null)
    return;
  for (select "pred", "predval"
    from (sparql
      define input:storage ""
      define output:valmode "LONG"
      prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
      select ?pred, ?predval
      where {
          graph ?:jgraph {
              ?:base_iid ?pred ?predval
            } } ) as "t00"
      where not exists (sparql
          define input:storage ""
          prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
          ask where { graph ?:jgraph { ?:"t00"."pred" virtrdf:loadAs virtrdf:jsoTriple } } )
      ) do
    {
      "pred" := id_to_iri ("pred");
      if (DB.DBA.RDF_LANGUAGE_OF_LONG ("predval", null) is not null)
        signal ('22023', 'JSO_MAKE_INHERITANCE does not support language marks on objects');
      if ('http://www.w3.org/1999/02/22-rdf-syntax-ns#type' = "pred")
        ;
      else if ('http://www.w3.org/1999/02/22-rdf-syntax-ns#name' = "pred")
        ;
      else if ('http://www.openlinksw.com/schemas/virtrdf#inheritFrom' = "pred")
        ;
      else if ('http://www.openlinksw.com/schemas/virtrdf#noInherit' = "pred")
        ;
      else if (dict_get (noinherits, "pred", baseinst) = baseinst) -- trick here, instead of (dict_get (noinherits, pred, null) is null) that does not handle inheritance of booleans properly.
        {
          jso_set (class, rootinst, "pred", __rdf_sqlval_of_obj ("predval"), isiri_id ("predval"));
          dict_put (noinherits, "pred", baseinst);
        }
    }
  JSO_MAKE_INHERITANCE (jgraph, class, rootinst, baseinst, base_iid, noinherits, inh_stack);
}
;

create function JSO_LOAD_INSTANCE (in jgraph varchar, in jinst varchar, in delete_first integer, in make_new integer, in jsubj_iid iri_id := 0)
{
  declare jinst_iid, jgraph_iid IRI_ID;
  declare jclass varchar;
  declare noinherits, inh_stack any;
  -- dbg_obj_princ ('JSO_LOAD_INSTANCE (', jgraph, ')');
  noinherits := dict_new ();
  jinst_iid := DB.DBA.RDF_MAKE_IID_OF_QNAME (jinst);
  jgraph_iid := DB.DBA.RDF_MAKE_IID_OF_QNAME (jgraph);
  if (jsubj_iid is null)
    {
      jsubj_iid := (sparql
        define input:storage ""
        define output:valmode "LONG"
        define sql:table-option "LOOP, index RDF_QUAD"
        select ?s
        where { graph ?:jgraph { ?s rdf:name ?:jinst } } );
      if (jsubj_iid is null)
        jsubj_iid := jinst_iid;
    }
  jclass := (sparql
    define input:storage ""
    define sql:table-option "LOOP, index RDF_QUAD"
    select ?t
    where {
      graph ?:jgraph { ?:jsubj_iid rdf:type ?t } } );
  if (jclass is null)
    {
      if (exists (sparql
          define input:storage ""
          define sql:table-option "LOOP, index RDF_QUAD"
          select ?x
            where { graph ?:jgraph {
                { ?:jinst ?x ?o }
                union
                { ?x rdf:name ?ji .
                  filter (str (?ji) = ?:jinst)
                  } } } ) )
        signal ('22023', 'JSO_LOAD_INSTANCE can not detect the type of <' || jinst || '>');
      else
        signal ('22023', 'JSO_LOAD_INSTANCE can not find an object <' || jinst || '>');
    }
  if (delete_first)
    jso_delete (jclass, jinst, 1);
  if (make_new)
    jso_new (jclass, jinst);
  for (select "p", coalesce ("o2", "o1") as "o"
      from (sparql
          define input:storage ""
          define output:valmode "LONG"
          define sql:table-option "LOOP, index RDF_QUAD"
          select ?p ?o1 ?o2
          where {
          graph ?:jgraph {
              { ?:jsubj_iid ?p ?o1 }  optional { ?o1 rdf:name ?o2 }
            } }
        ) as "t00"
      where not exists (sparql
          define input:storage ""
          prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
          ask where { graph ?:jgraph_iid { ?:"t00"."p" virtrdf:loadAs virtrdf:jsoTriple } } )
      ) do
    {
      "p" := id_to_iri ("p");
      if (DB.DBA.RDF_LANGUAGE_OF_LONG ("o", null) is not null)
        signal ('22023', 'JSO_LOAD_INSTANCE does not support language marks on objects');
      if ('http://www.w3.org/1999/02/22-rdf-syntax-ns#type' = "p")
        {
	  if (__rdf_sqlval_of_obj ("o") <> jclass)
            signal ('22023', 'JSO_LOAD_INSTANCE has found that the object <' || jinst || '> has multiple type declarations');
	}
      else if ('http://www.w3.org/1999/02/22-rdf-syntax-ns#name' = "p")
        ;
      else if ('http://www.openlinksw.com/schemas/virtrdf#inheritFrom' = "p")
        ;
      else if ('http://www.openlinksw.com/schemas/virtrdf#noInherit' = "p")
        ;
      else
        {
          jso_set (jclass, jinst, "p", __rdf_sqlval_of_obj ("o"), isiri_id ("o"));
          dict_put (noinherits, "p", jinst);
        }
    }
  inh_stack := vector ();
  JSO_MAKE_INHERITANCE (jgraph, jclass, jinst, jinst, jsubj_iid, noinherits, inh_stack);
}
;

create procedure JSO_LIST_INSTANCES_OF_GRAPH (in jgraph varchar, out instances any)
{
  -- dbg_obj_princ ('JSO_LIST_INSTANCES_OF_GRAPH (', jgraph, '...)');
  instances := (
    select vector_agg (
      vector (
        id_to_iri ("jclass"),
        id_to_iri ("jinst"),
        coalesce ("s", "jinst") ) )
    from ( sparql
      define output:valmode "LONG"
      define input:storage ""
      define sql:table-option "LOOP, index RDF_QUAD"
      select ?jclass ?jinst ?s
      where {
        graph ?:jgraph {
          { ?jinst rdf:type ?jclass .
            filter (!isBLANK (?jinst)) }
          union
          { ?s rdf:type ?jclass .
            ?s rdf:name ?jinst .
            filter (isBLANK (?s))
            } } }
      ) as inst );
  -- dbg_obj_princ ('... gets ', instances);
}
;

create function JSO_LOAD_GRAPH (in jgraph varchar, in pin_now integer := 1)
{
  declare jgraph_iid IRI_ID;
  declare instances, chk any;
  -- dbg_obj_princ ('JSO_LOAD_GRAPH (', jgraph, ')');
  jgraph_iid := DB.DBA.RDF_MAKE_IID_OF_QNAME (jgraph);
  JSO_LIST_INSTANCES_OF_GRAPH (jgraph, instances);
/* Pass 1. Deleting all obsolete instances. */
  foreach (any j in instances) do
    jso_delete (j[0], j[1], 1);
/* Pass 2. Creating all instances. */
  foreach (any j in instances) do
    jso_new (j[0], j[1]);
/* Pass 3. Loading all instances, including loading inherited values. */
  foreach (any j in instances) do
    JSO_LOAD_INSTANCE (jgraph, j[1], 0, 0, j[2]);
/* Pass 4. Validation all instances. */
  foreach (any j in instances) do
    jso_validate (j[0], j[1], 1);
/* Pass 5. Pin all instances. */
  if (pin_now)
    {
      foreach (any j in instances) do
        jso_pin (j[0], j[1]);
    }
/* Pass 6. Load all separate triples */
  for (sparql
      define input:storage ""
      define sql:table-option "LOOP, index RDF_QUAD"
      prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
      select ?s ?p ?o
      where { graph ?:jgraph_iid { ?p virtrdf:loadAs virtrdf:jsoTriple . ?s ?p ?o } } ) do
    jso_triple_add ("s", "p", "o");
  chk := jso_triple_get_objs (
    UNAME'http://www.openlinksw.com/schemas/virtrdf#loadAs',
    UNAME'http://www.openlinksw.com/schemas/virtrdf#loadAs' );
  if ((1 <> length (chk)) or (cast (chk[0] as varchar) <> 'http://www.openlinksw.com/schemas/virtrdf#jsoTriple'))
    signal ('22023', 'JSO_LOAD_GRAPH has not found expected metadata in the graph');
}
;

create function JSO_PIN_GRAPH (in jgraph varchar)
{
  declare instances any;
  JSO_LIST_INSTANCES_OF_GRAPH (jgraph, instances);
  foreach (any j in instances) do
    jso_pin (j[0], j[1]);
}
;

--!AWK PUBLIC
create function JSO_SYS_GRAPH () returns varchar
{
  return 'http://www.openlinksw.com/schemas/virtrdf#';
}
;

create procedure JSO_LOAD_AND_PIN_SYS_GRAPH (in graphiri varchar := null)
{
  if (graphiri is null)
    graphiri := JSO_SYS_GRAPH();
  commit work;
  JSO_LOAD_GRAPH (graphiri, 0);
  JSO_PIN_GRAPH (graphiri);
  for (select P_NAME from SYS_PROCEDURES where P_NAME like 'DB.DBA.SPARQL_DESC_DICT_QMV1_%' for update) do
    {
      exec ('drop procedure DB.DBA."' || subseq (P_NAME, 7) || '"');
    }
  commit work;
}
;

create function JSO_DUMP_IRI (in v varchar, inout ses any)
{
--            0         1         2         3      %
--            01234567890123456789012345678901234567-
  if (v like 'http://www.w3.org/2000/01/rdf-schema#%')
    { http ('rdfs:' || subseq (v, 37), ses); return; }
--            0         1         2         3         4  %
--            01234567890123456789012345678901234567890123-
  if (v like 'http://www.w3.org/1999/02/22-rdf-syntax-ns#%')
    { http ('rdf:' || subseq (v, 43), ses); return; }
--            0         1         2         %
--            0123456789012345678901234567890-
  if (v like 'http://www.w3.org/2002/07/owl#%')
    { http ('owl:' || subseq (v, 30), ses); return; }
--            0         1         2         3  %
--            0123456789012345678901234567890123-
  if (v like 'http://www.w3.org/2001/XMLSchema#%')
    { http ('xsd:' || subseq (v, 33), ses); return; }
--            0         1         2         3         4 %
--            0123456789012345678901234567890123456789012-
  if (v like 'http://www.openlinksw.com/schemas/virtrdf#%')
    { http ('virtrdf:' || subseq (v, 42), ses); return; }
--            0         1         2         3         4      %
--            012345678901234567890123456789012345678901234567-
  if (v like 'http://www.openlinksw.com/virtrdf-data-formats#%')
    { http ('rdfdf:' || subseq (v, 47), ses); return; }
  http ('<', ses);
  http_escape (v, 12, ses, 1, 1);
  http ('>', ses);
}
;

create function JSO_DUMP_FLD (in v any, inout ses any)
{
  declare v_tag integer;
  v_tag := __tag(v);
  if (v_tag = 217)
    JSO_DUMP_IRI (cast (v as varchar), ses);
  else if (v_tag = 243)
    JSO_DUMP_IRI (id_to_iri (v), ses);
  else if (v_tag = 203)
    http (jso_dbg_dump_rtti (v), ses);
  else if (v_tag = __tag of varchar)
    {
      http ('"', ses);
      http_escape (v, 11, ses, 1, 1);
      http ('"', ses);
    }
  else if (isinteger (v))
    http_value (v, 0, ses);
  else if (v_tag = __tag of rdf_box)
    DB.DBA.RDF_LONG_TO_TTL (v, ses);
  else
    {
      http ('"', ses);
      http_escape (DB.DBA.RDF_STRSQLVAL_OF_LONG (v), 11, ses, 1, 1);
      http ('"^^<', ses);
      http_escape (cast (__xsd_type (v) as varchar), 12, ses, 1, 1);
      http ('>', ses);
    }
}
;

create function DB.DBA.JSO_VECTOR_TO_TTL (inout proplist any) returns any
{
  declare prev_obj, ses any;
  declare ctr, len integer;
  ses := string_output ();
  len := length (proplist);
  gvector_sort (proplist, 1, 0, 1);
  prev_obj := null;
  for (ctr := 0; ctr < len; ctr := ctr+1)
    {
      declare obj, p, o any;
      declare base IRI_ID;
      obj := proplist[ctr][0];
      p := proplist[ctr][1];
      o := proplist[ctr][2];
      if (obj = prev_obj)
        http (';\n  ', ses);
      else
        {
	  if (prev_obj is null)
	    http (
'@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix owl: <http://www.w3.org/2002/07/owl#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
@prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#> .
@prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#> .
', ses );
          else
	    http ('.\n', ses);
	  prev_obj := obj;
	  JSO_DUMP_FLD (obj, ses);
          http ('\n  ', ses);
	}
      JSO_DUMP_FLD (p, ses);
      http ('\t', ses);
      JSO_DUMP_FLD (o, ses);
    }
  if (prev_obj is not null)
    http ('.\n', ses);
  return ses;
}
;

create function DB.DBA.JSO_FILTERED_PROPLIST (in only_custom integer := 0, in loading_status integer := 1, in long_valmode integer := 1) returns any
{
  declare proplist, res any;
  declare sys_dict, sys_inh any;
  declare sys_txt, sys_vect any;
  declare ctr, len integer;
  declare inh_id IRI_ID;
  if (loading_status = 0)
    {
      proplist := ((select VECTOR_AGG (vector ("sub"."s", "sub"."p", "sub"."o")) from (
            sparql define input:storage "" define output:valmode "LONG"
            select ?s ?p ?o from <http://www.openlinksw.com/schemas/virtrdf#>
             where { ?s ?p ?o } ) as "sub"));
    }
  else
    {
      proplist := vector_concat (jso_proplist (loading_status), jso_triple_list ());
    }
  gvector_sort (proplist, 1, 0, 1);
  if (not only_custom and not long_valmode)
    return proplist;
  if (only_custom)
    {
      sys_txt := cast ( DB.DBA.XML_URI_GET (
          'http://www.openlinksw.com/sparql/virtrdf-data-formats.ttl', '' ) as varchar );
      sys_dict := DB.DBA.RDF_TTL2HASH (sys_txt, '');
      sys_vect := dict_list_keys (sys_dict, 0);
      -- dbg_obj_princ ('Part of sys_dict is', subseq (sys_vect, 0, 10));
      inh_id := iri_to_id ('http://www.openlinksw.com/schemas/virtrdf#inheritFrom');
      sys_inh := dict_new (127);
      foreach (any triple in sys_vect) do
        {
          if (triple[1] = inh_id)
            dict_put (sys_inh, triple[0], triple[2]);
        }
    }
  len := length (proplist);
  vectorbld_init (res);
  for (ctr := 0; ctr < len; ctr := ctr+1)
    {
      declare obj, p, o any;
      declare obj_long, p_long, o_long any;
      declare base IRI_ID;
      obj := proplist[ctr][0];
      p := proplist[ctr][1];
      o := proplist[ctr][2];
          if (217 = __tag (obj))
            obj_long := DB.DBA.RDF_MAKE_IID_OF_QNAME (obj);
          else
            obj_long := obj;
          if (217 = __tag (p))
            p_long := DB.DBA.RDF_MAKE_IID_OF_QNAME (p);
          else
            p_long := p;
          if (217 = __tag (o))
            o_long := DB.DBA.RDF_MAKE_IID_OF_QNAME (o);
          else
            o_long := __rdf_long_of_obj (DB.DBA.RDF_MAKE_OBJ_OF_SQLVAL (o));
          -- dbg_obj_princ ('key sample: ', vector (obj_long, p_long, o_long));
      if (only_custom)
        {
          if (dict_get (sys_dict, vector (obj_long, p_long, o_long)) is not null)
            goto end_of_step;
          base := dict_get (sys_inh, obj_long);
          if (base is not null and dict_get (sys_dict, vector (base, p_long, o_long)) is not null)
            goto end_of_step;
        }
      if (long_valmode)
        vectorbld_acc (res, vector (obj_long, p_long, o_long));
      else
        vectorbld_acc (res, proplist[ctr]);
end_of_step: ;
    }
  vectorbld_final (res);
  return res;
}
;

create function DB.DBA.JSO_DUMP_ALL (in only_custom integer := 0, in loading_status integer := 1) returns any
    {
  declare proplist any;
  proplist := DB.DBA.JSO_FILTERED_PROPLIST (only_custom, loading_status, 0);
  return DB.DBA.JSO_VECTOR_TO_TTL (proplist);
}
;

-----
-- Metadata audit / backup / restore / recovery

create function DB.DBA.RDF_BACKUP_METADATA (in save_to_file integer := 0, in backup_name varchar := null) returns varchar
{
  declare proplist any;
  proplist := DB.DBA.JSO_FILTERED_PROPLIST (1, 0, 1);
  if (backup_name is null)
    backup_name := replace (cast (now() as varchar), ' ', 'T');
  if (save_to_file)
    {
      declare proplist_debug any;
      proplist_debug := DB.DBA.JSO_FILTERED_PROPLIST (0, 0, 1);
      string_to_file (backup_name || '.ttl', '# RDF_BACKUP_METADATA #\n', -2);
      string_to_file (backup_name || '.ttl', DB.DBA.JSO_VECTOR_TO_TTL (proplist), -1);
      string_to_file (backup_name || '-DEBUG.ttl', '# RDF_BACKUP_METADATA - DEBUG #\n', -2);
      string_to_file (backup_name || '-DEBUG.ttl', DB.DBA.JSO_VECTOR_TO_TTL (proplist_debug), -1);
      return backup_name || '.ttl';
    }
  else
    {
      if (exists (sparql define input:storage "" ask where { graph `iri(?:backup_name)` { ?s ?p ?o }}))
        signal ('22023', sprintf ('Can not backup RDF metadata into nonempty graph <%.300s>', backup_name));
      foreach (any triple in proplist) do
        {
          declare s,p,o any;
          s := triple[0];
          p := triple[1];
          o := triple[2];
          sparql insert into graph iri(?:backup_name) { ?:s ?:p ?:o };
        }
      commit work;
    }
  return backup_name;
}
;

create function DB.DBA.RDF_RESTORE_METADATA (in read_from_file integer, in backup_name varchar) returns any
{
  declare graphiri_id IRI_ID;
  declare proplist any;
  if (read_from_file)
    {
      declare txt any;
      txt := file_to_string (backup_name);
      if (not ("LEFT" (txt, 23) = '# RDF_BACKUP_METADATA #'))
        signal ('22023', sprintf ('Can not restore RDF metadata from file %.300s: file does not start with signature "# RDF_BACKUP_METADATA #"', backup_name));
      proplist := dict_list_keys (DB.DBA.RDF_TTL2HASH (txt, ''), 1);
    }
  else
    proplist := ((select VECTOR_AGG (vector ("sub"."s", "sub"."p", "sub"."o")) from (
          sparql define input:storage "" define output:valmode "LONG"
          select ?s ?p ?o where { graph `iri(?:backup_name)` { ?s ?p ?o } } ) as "sub"));
  if (0 = length (proplist))
    signal ('22023', sprintf ('There are no metadata in %.200 to restore', backup_name));
  graphiri_id := iri_to_id (DB.DBA.JSO_SYS_GRAPH (), 1);
  sparql define input:storage "" clear graph ?:graphiri_id;
  commit work;
  DB.DBA.SPARQL_RELOAD_QM_GRAPH ();
  commit work;
  foreach (any triple in proplist) do
    {
      declare sl,pl,ol any;
      sl := triple[0];
      pl := triple[1];
      ol := triple[2];
      if (pl <> iri_to_id ('http://www.openlinksw.com/schemas/virtrdf#status', 1))
        {
          -- dbg_obj_princ ('s=', sl, ' p=', pl, ' o=', ol);
          sparql define input:storage "" insert into graph ?:graphiri_id { ?:sl ?:pl ?:ol };
        }
    }
  commit work;
  DB.DBA.SPARQL_RELOAD_QM_GRAPH ();
  commit work;
  return backup_name;
}
;

create procedure DB.DBA.RDF_AUDIT_METADATA (in fix_bugs integer := 0, in unlocker varchar := null, in graphiri varchar := null, in call_result_names integer := 1)
{
  declare chksum varchar;
  declare chksum_acc any;
  declare STAT, MSG varchar;
  declare graphiri_id IRI_ID;
  declare all_lists, prev_list, prev_subj any;
  if (call_result_names)
    result_names (STAT, MSG);
  if (graphiri is null)
    graphiri := DB.DBA.JSO_SYS_GRAPH ();
  else
    {
      if (graphiri <> DB.DBA.JSO_SYS_GRAPH ())
      result ('00000', 'Note: non-default graph IRI <' || graphiri || '> is used');
    }
  graphiri_id := iri_to_id (graphiri, 1);
  vectorbld_init (chksum_acc);
  for (sparql define input:storage ""
    select ?st ?trx where { graph ?:graphiri_id {
            ?st virtrdf:qsAlterInProgress ?trx } } ) do
    {
      result ('00000', 'Quad storage <' || "st" || '> is flagged as being edited ' || cast ("trx" as varchar));
      vectorbld_acc (chksum_acc, vector ("st", "trx"));
    }
  vectorbld_final (chksum_acc);
  if (length (chksum_acc))
    {
      chksum := md5 (serialize (chksum_acc));
      if ((fix_bugs = 0) or (unlocker is null) or ((chksum <> unlocker) and (unlocker <> '*')))
        {
          result ('42000', 'Can not process data that are being edited by someone else.');
          result ('00000', 'To force tests/bugfixing, pass 1 as first argument and either ''' || chksum || ''' or ''*'' as second argument of the DB.DBA.RDF_AUDIT_METADATA() call');
          return;
        }
      sparql define input:storage ""
      delete from graph ?:graphiri_id {
          ?st virtrdf:qsAlterInProgress ?trx }
      where { graph ?:graphiri_id {
              ?st virtrdf:qsAlterInProgress ?trx } };
    }
  if ((graphiri = DB.DBA.JSO_SYS_GRAPH ()) and fix_bugs)
    {
      declare txt1 varchar;
      declare dict1, lst1 any;
      result ('00000', 'Reloading built-in metadata, this might fix some errors without accurate reporting that they did exist');
      txt1 := cast ( DB.DBA.XML_URI_GET (
          'http://www.openlinksw.com/sparql/virtrdf-data-formats.ttl', '' ) as varchar );
      dict1 := DB.DBA.RDF_TTL2HASH (txt1, '');
      lst1 := dict_list_keys (dict1, 1);
      foreach (any triple in lst1) do
        {
          delete from DB.DBA.RDF_QUAD table option (index RDF_QUAD) where G = graphiri_id and S = triple[0] and P = triple[1];
        }
      DB.DBA.RDF_INSERT_TRIPLES (graphiri_id, lst1);
      commit work;
      result ('00000', 'Built-in metadata were reloaded');
      if (fix_bugs > 1)
        {
          for (sparql
            define input:storage ""
            prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
            select ?s from <http://www.openlinksw.com/schemas/virtrdf#> where {
                ?s rdf:type virtrdf:array-of-QuadMap } ) do
            {
              if (DB.DBA.RDF_QM_GC_SUBTREE ("s", 1) is null)
                result ('00000', 'Quad map array <' || "s" || '> is not used, removed');
            }
          for (sparql
            define input:storage ""
            prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
            select ?s from <http://www.openlinksw.com/schemas/virtrdf#> where {
                ?s rdf:type virtrdf:QuadMap } ) do
            {
              if (DB.DBA.RDF_QM_GC_MAPPING_SUBTREE ("s", 1) is null)
                result ('00000', 'Quad map <' || "s" || '> is not used, removed');
            }
          for (sparql
            define input:storage ""
            prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
            select ?s from <http://www.openlinksw.com/schemas/virtrdf#> where {
                ?s rdf:type virtrdf:array-of-QuadMapFormat } ) do
            {
              if (DB.DBA.RDF_QM_GC_SUBTREE ("s", 1) is null)
                result ('00000', 'Quad map format array <' || "s" || '> is not used, removed');
            }
          for (sparql
            define input:storage ""
            prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
            select ?s from <http://www.openlinksw.com/schemas/virtrdf#> where {
                ?s rdf:type virtrdf:QuadMapFormat } ) do
            {
              if (DB.DBA.RDF_QM_GC_SUBTREE ("s", 1) is null)
                result ('00000', 'Quad map format <' || "s" || '> is not used, removed');
            }
        }
    }
  for (select * from (sparql define input:storage "" define output:valmode "LONG"
      select ?lst ?p ?itm where { graph ?:graphiri_id {
              ?lst ?p ?itm .
              optional { ?itm a ?t } .
              filter (! bound (?t) && isiri (?itm) && str(?p) > str(rdf:_) && str(?p) < str(rdf:_A))
               } } ) as sub for update) do
    {
      result ('00000', 'List <' || id_to_iri("lst") || '> contains IRI <' || id_to_iri("itm") || '> that has no type');
      if (fix_bugs)
        {
          sparql delete from graph ?:graphiri_id { ?:"lst" ?:"p" ?:"itm" };
        }
    }
  vectorbld_init (all_lists);
  prev_subj := #i0;
  for (
    select "sub"."lst", cast ("sub"."idx" as integer) as "idx", "sub"."itm", "sub"."t"
    from (sparql define input:storage "" define output:valmode "LONG"
      select ?lst
        (bif:aref (bif:sprintf_inverse (str(?p),
            bif:concat (str (rdf:_), "%d"), 2 ),
          0 ) ) as ?idx
       ?itm ?t where { graph ?:graphiri_id {
              ?lst ?p ?itm .
              optional { ?itm a ?t } .
              filter (
              str(?p) > str(rdf:_) && str(?p) < str(rdf:_A))
               } } ) as "sub"
    order by 1, 2, 3 ) do
    {
      if (prev_subj <> "lst")
        {
          if (prev_subj <> #i0)
            {
              vectorbld_final (prev_list);
              vectorbld_acc (all_lists, vector (prev_subj, prev_list));
            }
          prev_subj := "lst";
          vectorbld_init (prev_list);
        }
      vectorbld_acc (prev_list, vector ("idx", "itm", "t"));
    }
  if (prev_subj <> #i0)
    {
      vectorbld_final (prev_list);
      vectorbld_acc (all_lists, vector (prev_subj, prev_list));
    }
  vectorbld_final (all_lists);
  foreach (any pair in all_lists) do
    {
      declare subj, items any;
      declare pos, len, last_idx, list_needs_rebuild integer;
      list_needs_rebuild := 0;
      last_idx := 0;
      subj := pair[0];
      items := pair[1];
      len := length (items);
      last_idx := 0;
      for (pos := 0; pos < len; pos := pos+1)
        {
          declare curr_idx integer;
          curr_idx := items[pos][0];
          if (curr_idx <= last_idx)
            {
              result ('42000', sprintf ('Item rdf:_%d is out of order in list <%s>', curr_idx, id_to_iri (subj)));
              list_needs_rebuild := 1;
            }
          else if ((last_idx + 3) < curr_idx)
            {
              result ('42000', sprintf ('Items rdf:_%d to rdf:_%d are not set in list <%s>', last_idx, curr_idx - 1, id_to_iri (subj)));
              list_needs_rebuild := 1;
            }
          else
            {
              while ((last_idx + 1) < curr_idx)
                {
                  result ('42000', sprintf ('Item rdf:_%d is not set in list <%s>', last_idx, id_to_iri (subj)));
                  last_idx := last_idx + 1;
                  list_needs_rebuild := 1;
                }
            }
          last_idx := curr_idx;
        }
      if (fix_bugs and list_needs_rebuild)
        {
          for (pos := 0; pos < len; pos := pos+1)
            {
              declare curr_idx integer;
              curr_idx := items[pos][0];
              sparql define input:storage ""
              delete from graph ?:graphiri_id {
                `iri(?:subj)` ?p ?o }
              where { graph ?:graphiri_id {
                `iri(?:subj)` ?p ?o .
                filter (?p = iri (bif:sprintf ("%s%d", str (rdf:_), ?:curr_idx))) } };
            }
          for (pos := 0; pos < len; pos := pos+1)
            {
              declare curr_idx integer;
              declare obj any;
              curr_idx := items[pos][0];
              obj := items[pos][1];
              sparql define input:storage ""
              insert into graph ?:graphiri_id {
                `iri(?:subj)` `iri (bif:sprintf ("%s%d", str (rdf:_), 1 + ?:pos))` ?:obj };
            }
        }
    }
  commit work;
  if ((graphiri = DB.DBA.JSO_SYS_GRAPH ()) and fix_bugs)
    {
      whenever sqlstate '*' goto jso_load_failed;
      DB.DBA.JSO_LOAD_AND_PIN_SYS_GRAPH ();
      result ('00000', 'Metadata from system graph are cached in memory-resident JSOs (JavaScript Objects)');
      return;
    }
  return;

jso_load_failed:
  result (__SQL_STATE, __SQL_MESSAGE);
  result ('42000', 'The previous error can not be fixed automatically. Sorry.');
  return;
}
;

-----
-- Internal routines for SPARQL quad map syntax extensions

create procedure DB.DBA.RDF_QM_CHANGE (in warninglist any)
{
  declare STATE, MESSAGE varchar;
  result_names (STATE, MESSAGE);
  foreach (any warnings in warninglist) do
    {
     foreach (any warning in warnings) do
       result (warning[0], warning[1]);
    }
  commit work;
}
;

create procedure DB.DBA.RDF_QM_CHANGE_OPT (in cmdlist any)
{
  declare cmdctr, cmdcount integer;
  declare eaqs varchar;
  declare STATE, MESSAGE varchar;
  cmdcount := length (cmdlist);
  result_names (STATE, MESSAGE);
  eaqs := '';
  for (cmdctr := 0; cmdctr < cmdcount; cmdctr := cmdctr + 1)
    {
      declare cmd, exectext, arglist, warnings,md,rs any;
      declare argctr, argcount integer;
      cmd := cmdlist[cmdctr];
      exectext := string_output();
      http ('select ', exectext);
      http_value (cmd[0], 0, exectext);
      http (' (', exectext);
      if (length (cmd) > 2)
        arglist := vector_concat (cmd[1], vector (cmd[2]));
      else
        arglist := cmd[1];
      argcount := length (arglist);
      for (argctr := 0; argctr < argcount; argctr := argctr + 1)
        {
          if (argctr > 0)
            http (',', exectext);
          http ('?', exectext);
        }
      http (')', exectext);
      STATE := '00000';
      warnings := exec (string_output_string (exectext), STATE, MESSAGE, arglist, md, rs);
      -- dbg_obj_princ ('warnings = ', warnings);
      if (__tag of vector = __tag (warnings))
        {
          foreach (any warning in warnings) do
            result (warning[0], warning[1]);
        }
      commit work;
      if (STATE <> '00000')
        {
          result (STATE, MESSAGE);
          if ('' <> eaqs)
            exec ('DB.DBA.RDF_QM_END_ALTER_QUAD_STORAGE (?)', STATE, MESSAGE, vector (eaqs));
          DB.DBA.RDF_AUDIT_METADATA (1, null, null, 0);
          return;
        }
      if (UNAME'DB.DBA.RDF_QM_BEGIN_ALTER_QUAD_STORAGE' = cmd[0])
        eaqs := arglist[0];
      else if (UNAME'DB.DBA.RDF_QM_END_ALTER_QUAD_STORAGE' = cmd[0])
        eaqs := '';
    }
  result ('00000', sprintf ('%d RDF metadata manipulation operations done', cmdcount));
}
;

create function DB.DBA.RDF_QM_APPLY_CHANGES (in deleted any, in affected any) returns any
{
  declare ctr, len integer;
  commit work;
  DB.DBA.JSO_LOAD_AND_PIN_SYS_GRAPH ();
  len := length (deleted);
  for (ctr := 0; ctr < len; ctr := ctr + 2)
    jso_delete (deleted [ctr], deleted [ctr+1], 1);
  len := length (affected);
  for (ctr := 0; ctr < len; ctr := ctr + 1)
    jso_mark_affected (affected [ctr]);
  return vector (vector ('00000', 'Transaction committed, SPARQL compiler re-configured'));
}
;

create function DB.DBA.RDF_QM_ASSERT_JSO_TYPE (in inst varchar, in expected varchar, in allow_missing integer := 0) returns integer
{
  declare actual varchar;
  if (expected is null)
    {
      actual := coalesce ((sparql
          define input:storage ""
          prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
          select ?t where {
            graph <http://www.openlinksw.com/schemas/virtrdf#> { `iri(?:inst)` rdf:type ?t } } ));
      if (actual is not null)
        signal ('22023', 'The RDF QM schema object <' || inst || '> already exists, type <' || cast (actual as varchar) || '>');
    }
  else
    {
      declare hit integer;
      hit := 0;
      for (sparql
        define input:storage ""
        prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
        select ?t where {
          graph <http://www.openlinksw.com/schemas/virtrdf#> { `iri(?:inst)` rdf:type ?t } } ) do
        {
          if ("t" <> expected)
            signal ('22023', 'The RDF QM schema object <' || inst || '> has type <' || cast (actual as varchar) || '>, cannot use same identifier for <' || expected || '>');
          hit := 1;
        }
      if (not hit)
        {
          if (allow_missing)
            return 0;
          signal ('22023', 'The RDF QM schema object <' || inst || '> does not exists, should be of type <' || expected || '>');
        }
    }
  return 1;
}
;

create procedure DB.DBA.RDF_QM_ASSERT_STORAGE_FLAG (in storage varchar, in req_flag integer)
{
  declare graphiri varchar;
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  DB.DBA.RDF_QM_ASSERT_JSO_TYPE (storage, 'http://www.openlinksw.com/schemas/virtrdf#QuadStorage');
  for (sparql define input:storage ""
    prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
    select ?startdt where {
        graph ?:graphiri {
            `iri(?:storage)` virtrdf:qsAlterInProgress ?startdt .
          } } ) do
    {
      if (req_flag)
        return;
      signal ('22023', 'The quad storage "' || storage || '" is edited by other client, started ' || cast ("startdt" as varchar));
    }
  if (not req_flag)
    return;
  signal ('22023', 'The quad storage "' || storage || '" is not flagged as being edited, cannot change it' );
}
;

create procedure DB.DBA.RDF_QM_ASSERT_STORAGE_CONTAINS_MAPPING (in storage varchar, in qmid varchar, in must_contain integer)
{
  declare graphiri varchar;
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  if (exists (sparql define input:storage ""
        ask where {
          graph ?:graphiri {
            { `iri(?:storage)` virtrdf:qsDefaultMap `iri(?:qmid)` }
            union
            { `iri(?:storage)` virtrdf:qsUserMaps ?qmlist .
              ?qmlist ?p `iri(?:qmid)` .
            } } } ) )
    {
      if (must_contain)
        return;
      signal ('22023', 'The quad storage "' || storage || '" contains quad map ' || qmid );
    }
  if (not must_contain)
    return;
  signal ('22023', 'The quad storage "' || storage || '" does not contains quad map ' || qmid );
}
;

create procedure DB.DBA.RDF_QM_ASSERT_STORAGE_IS_FLAGGED (in storage varchar)
{
  if (not DB.DBA.RDF_QM_GET_STORAGE_FLAG (storage))
    signal ('22023', 'The quad storage "' || storage || '" is not flagged as being edited' );
}
;

create function DB.DBA.RDF_QM_GC_SUBTREE (in seed any, in quick_gc_only integer := 0) returns integer
{
  declare graphiri varchar;
  declare seed_id, graphiri_id, subjs, objs any;
  declare o_to_s, s_to_o any;
  declare subjs_of_o, objs_of_s any;
  set isolation = 'serializable';
  -- dbg_obj_princ ('DB.DBA.RDF_QM_GC_SUBTREE (', seed, '), ', seed, '=', id_to_iri(iri_to_id(seed)));
  o_to_s := dict_new ();
  s_to_o := dict_new ();
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  graphiri_id := DB.DBA.RDF_MAKE_IID_OF_QNAME (graphiri);
  seed_id := DB.DBA.RDF_MAKE_IID_OF_QNAME (seed);
  for (sparql define input:storage ""
    define output:valmode "LONG"
    select ?s
    from <http://www.openlinksw.com/schemas/virtrdf#>
    where { ?s virtrdf:item ?:seed_id } ) do
    {
      -- dbg_obj_princ ('DB.DBA.RDF_QM_GC_SUBTREE (', seed, ') found virtrdf:item subject ', "s");
      return "s";
    }
  for (sparql define input:storage ""
    define output:valmode "LONG"
    select ?s
    from <http://www.openlinksw.com/schemas/virtrdf#>
    where { ?s a [] ; ?p ?:seed_id } ) do
    {
      -- dbg_obj_princ ('DB.DBA.RDF_QM_GC_SUBTREE (', seed, ') found use case ', "s");
      if (quick_gc_only)
        return "s";
      goto do_full_gc;
    }
  vectorbld_init (objs_of_s);
  for (sparql define input:storage ""
    define output:valmode "LONG"
    define sql:table-option "LOOP"
    select ?o
    from <http://www.openlinksw.com/schemas/virtrdf#>
    where { ?:seed_id a [] ; ?p ?o . ?o a [] } ) do
    {
      vectorbld_acc (objs_of_s, "o");
    }
  vectorbld_final (objs_of_s);
  -- dbg_obj_princ ('DB.DBA.RDF_QM_GC_SUBTREE (', seed, ') found descendants ', objs_of_s);
  delete from DB.DBA.RDF_QUAD where G = graphiri_id and S = seed_id;
  commit work;
  foreach (IRI_ID descendant in objs_of_s) do
    {
      DB.DBA.RDF_QM_GC_SUBTREE (descendant, 1);
    }
  -- dbg_obj_princ ('DB.DBA.RDF_QM_GC_SUBTREE (', seed, ') done in quick way');
  return null;

do_full_gc:
  for (sparql define input:storage ""
    define output:valmode "LONG"
    define sql:table-option "LOOP"
    select ?s ?o
    from <http://www.openlinksw.com/schemas/virtrdf#>
    where { ?s a [] ; ?p ?o . ?o a [] } ) do
    {
      -- dbg_obj_princ ('DB.DBA.RDF_QM_GC_SUBTREE () caches ', "s", ' -> ', "o");
      subjs_of_o := dict_get (o_to_s, "o", NULL);
      if (subjs_of_o is null)
        dict_put (o_to_s, "o", vector ("s"));
      else if (0 >= position ("s", subjs_of_o))
        dict_put (o_to_s, "o", vector_concat (vector ("s"), subjs_of_o));
      objs_of_s := dict_get (s_to_o, "s", NULL);
      if (objs_of_s is null)
        dict_put (s_to_o, "s", vector ("o"));
      else if (0 >= position ("o", objs_of_s))
        dict_put (s_to_o, "s", vector_concat (vector ("o"), objs_of_s));
    }
  subjs := vector (seed_id);
again:
  vectorbld_init (objs);
  foreach (IRI_ID nod in subjs) do
    {
      -- dbg_obj_princ ('DB.DBA.RDF_QM_GC_SUBTREE () tries to delete ', nod, id_to_iri_nosignal (nod));
      declare subjs_of_nod, objs_of_nod any;
      subjs_of_nod := dict_get (o_to_s, nod, NULL);
      if (subjs_of_nod is not null)
        {
          -- dbg_obj_princ ('DB.DBA.RDF_QM_GC_SUBTREE () does not delete ', nod, id_to_iri_nosignal (nod), ': side links ', subjs_of_nod);
          if (nod = seed_id)
            return subjs_of_nod[0];
          goto nop_nod; -- see below;
        }
--      sparql define input:storage ""
--        delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { `iri(?:nod)` ?p ?o }
--        where { graph ?:graphiri { `iri(?:nod)` ?p ?o } };
      delete from DB.DBA.RDF_QUAD where G = graphiri_id and S = nod;
      objs_of_nod := dict_get (s_to_o, nod, NULL);
      dict_remove (s_to_o, nod);
      foreach (IRI_ID sub in objs_of_nod) do
        {
          declare subjs_of_sub any;
          declare nod_pos integer;
          subjs_of_sub := dict_get (o_to_s, sub, NULL);
          nod_pos := position (nod, subjs_of_sub);
          if (0 < nod_pos)
            subjs_of_sub := vector_concat (subseq (subjs_of_sub, 0, nod_pos - 1), subseq (subjs_of_sub, nod_pos));
          if (0 = length (subjs_of_sub))
            {
              -- dbg_obj_princ ('DB.DBA.RDF_QM_GC_SUBTREE () condemns ', sub, id_to_iri_nosignal (sub));
              dict_remove (o_to_s, sub);
              vectorbld_acc (objs, sub);
            }
          else
            {
              dict_put (o_to_s, sub, subjs_of_sub);
              -- dbg_obj_princ ('DB.DBA.RDF_QM_GC_SUBTREE () stores subjects ', subjs_of_sub, ' for not condemned ', sub, id_to_iri_nosignal (sub));
            }
        }
nop_nod: ;
    }
  vectorbld_final (objs);
  if (0 < length (objs))
    {
      -- dbg_obj_princ ('DB.DBA.RDF_QM_GC_SUBTREE () sets a new list of subjects: ', subjs);
      subjs := objs;
      goto again; -- see above
    }
  -- dbg_obj_princ ('DB.DBA.RDF_QM_GC_SUBTREE () finishes GC of ', seed);
  return NULL;
}
;

create function DB.DBA.RDF_QM_GC_MAPPING_SUBTREE (in mapname any, in quick_gc integer) returns any
{
  declare gc_res, submaps any;
  submaps := (select VECTOR_AGG (s1."subm") from (
      sparql define input:storage ""
      select ?subm where {
          graph <http://www.openlinksw.com/schemas/virtrdf#> {
            `iri(?:mapname)` virtrdf:qmUserSubMaps ?submlist .
                    ?submlist ?p ?subm } } ) as s1 );
  gc_res := DB.DBA.RDF_QM_GC_SUBTREE (mapname, quick_gc);
  if (gc_res is not null)
    return gc_res;
  commit work;
  foreach (any submapname in submaps) do
    {
      DB.DBA.RDF_QM_GC_MAPPING_SUBTREE (submapname, quick_gc);
    }
  return NULL;
}
;

create function DB.DBA.RDF_QM_DROP_MAPPING (in storage varchar, in mapname any) returns any
{
  declare graphiri varchar;
  declare qmid, qmgraph varchar;
  qmid := get_keyword_ucase ('ID', mapname, NULL);
  qmgraph := get_keyword_ucase ('GRAPH', mapname, NULL);
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  if (qmid is null)
    {
      qmid := coalesce ((sparql
          define input:storage ""
          prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
          select ?s from <http://www.openlinksw.com/schemas/virtrdf#> where {
              ?s rdf:type virtrdf:QuadMap .
              ?s virtrdf:qmGraphRange-rvrFixedValue `iri(?:qmgraph)` .
              ?s virtrdf:qmTableName "" .
              } ));
      if (qmid is null)
        return vector (vector ('00100', 'Quad map for graph <' || qmgraph || '> is not found'));
    }
  DB.DBA.RDF_QM_ASSERT_JSO_TYPE (qmid, 'http://www.openlinksw.com/schemas/virtrdf#QuadMap');
  if (storage is null)
    {
      for (sparql
        define input:storage ""
        select ?st where {
            graph <http://www.openlinksw.com/schemas/virtrdf#> {
                  { ?st virtrdf:qsUserMaps ?subm .
                    ?subm ?p `iri(?:qmid)` }
                union
                  { ?st virtrdf:qsDefaultMap `iri(?:qmid)` }
              } } ) do
        {
          -- dbg_obj_princ ('Will run DB.DBA.RDF_QM_DELETE_MAPPING_FROM_STORAGE (', "st", ', NULL, ', qmid, ')');
          DB.DBA.RDF_QM_DELETE_MAPPING_FROM_STORAGE ("st", NULL, qmid);
        }
      DB.DBA.RDF_QM_GC_MAPPING_SUBTREE (qmid, 0);
      return vector (vector ('00000', 'Quad map <' || qmid || '> is deleted'));
    }
  else
    {
      DB.DBA.RDF_QM_DELETE_MAPPING_FROM_STORAGE (storage, NULL, qmid);
      DB.DBA.RDF_QM_GC_MAPPING_SUBTREE (qmid, 1);
      return vector (vector ('00000', 'Quad map <' || qmid || '> is no longer used in storage <' || storage || '>'));
    }
}
;

create function DB.DBA.RDF_QM_MACROEXPAND_TEMPLATE (in iritmpl varchar) returns varchar
{
  if (strstr (iritmpl, '^{URIQADefaultHost}^') is not null)
    {
      declare host varchar;
      host := registry_get ('URIQADefaultHost');
      if (not isstring (host))
        signal ('22023', 'Can not use ^{URIQADefaultHost}^ in IRI template if there is no DefaultHost parameter in [URIQA] section of Virtuoso configuration file');
      iritmpl := replace (iritmpl, '^{URIQADefaultHost}^', host);
    }
  return iritmpl;
}
;

create function DB.DBA.RDF_QM_CBD_OF_IRI_CLASS (in classiri varchar) returns any
{
  declare descr any;
  descr := ((sparql define input:storage ""
      construct {
        <class> ?cp ?co .
        <class> virtrdf:qmfValRange-rvrSprintffs <sprintffs> .
        <sprintffs> ?sffp ?sffo .
        <class> virtrdf:qmfSuperFormats <sups> .
        <sups> ?supp ?supo . }
      from <http://www.openlinksw.com/schemas/virtrdf#>
      where {
          {
            `iri(?:classiri)` ?cp ?co .
            filter (!(?cp in (virtrdf:qmfValRange-rvrSprintffs, virtrdf:qmfSuperFormats)))
          } union {
            `iri(?:classiri)` virtrdf:qmfValRange-rvrSprintffs ?sffs .
            optional { ?sffs ?sffp ?sffo . }
          } union {
            `iri(?:classiri)` virtrdf:qmfSuperFormats ?sups .
            optional { ?sups ?supp ?supo . }
          } } ) );
  descr := dict_list_keys (descr, 2);
  rowvector_digit_sort (descr, 1, 1);
  return descr;
}
;

create function DB.DBA.RDF_QM_DEFINE_IRI_CLASS_FORMAT (in classiri varchar, in iritmpl varchar, in arglist any, in options any, in origclassiri varchar := null) returns any
{
  declare graphiri varchar;
  declare sprintffsid, superformatsid varchar;
  declare basetype, basetypeiri varchar;
  declare bij, deref integer;
  declare sffs, res any;
  declare argctr, arglist_len, isnotnull, sff_ctr, sff_count, bij_sff_count integer;
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  bij := get_keyword_ucase ('BIJECTION', options, 0);
  deref := get_keyword_ucase ('DEREF', options, 0);
  sffs := get_keyword_ucase ('RETURNS', options);
  if (sffs is null)
    sffs := vector (iritmpl); -- note that this is before macroexpand
  sff_count := length (sffs);
  iritmpl := DB.DBA.RDF_QM_MACROEXPAND_TEMPLATE (iritmpl);
  sprintffsid := classiri || '--Sprintffs';
  superformatsid := classiri || '--SuperFormats';
  res := vector ();
  foreach (any arg in arglist) do
    if (UNAME'in' <> arg[0])
      signal ('22023', 'Only "in" parameters are now supported in argument lists of class formats, "' || arg[0] || '" is not supported in CREATE IRI CLASS <' || classiri || '>' );
  arglist_len := length (arglist);
  isnotnull := 1;
  if (arglist_len <> 1)
    {
      basetype := 'multipart-uri';
      for (argctr := 0; (argctr < arglist_len) and isnotnull; argctr := argctr + 1)
        {
          if (not (coalesce (arglist[argctr][3], 0)))
            isnotnull := 0;
        }
    }
  else /* arglist is 1 item long */
    {
      basetype := lower (arglist[0][2]);
      if (not (basetype in ('integer', 'varchar', 'date', 'datetime', 'doubleprecision', 'numeric')))
        signal ('22023', 'The datatype "' || basetype || '" is not supported in CREATE IRI CLASS <' || classiri || '>' );
      basetype := 'sql-' || basetype || '-uri';
      if (not (coalesce (arglist[0][3], 0)))
        isnotnull := 0;
    }
  if (not isnotnull)
    basetype := basetype || '-nullable';
  basetypeiri := 'http://www.openlinksw.com/virtrdf-data-formats#' || basetype;
  if (origclassiri is null)
    {
      if (isnotnull and (arglist_len > 0))
        {
          declare arglist_copy any;
          if (classiri like '%-nullable')
            signal ('22023', 'The name of non-nullable IRI class in CREATE IRI CLASS <' || classiri || '> is misleading' );
          arglist_copy := arglist;
          for (argctr := 0; (argctr < arglist_len); argctr := argctr + 1)
            arglist_copy[argctr][3] := 0;
          res := vector_concat (res,
            DB.DBA.RDF_QM_DEFINE_IRI_CLASS_FORMAT (classiri || '-nullable', iritmpl, arglist_copy, options, NULL) );
        }
      origclassiri := classiri;
    }
  if (DB.DBA.RDF_QM_ASSERT_JSO_TYPE (classiri, 'http://www.openlinksw.com/schemas/virtrdf#QuadMapFormat', 1))
    {
      declare side_s IRI_ID;
      side_s := DB.DBA.RDF_QM_GC_SUBTREE (classiri);
      if (side_s is not null)
        {
          declare tmpname varchar;
          declare old_descr, new_descr any;
          tmpname := uuid();
          { declare exit handler for sqlstate '*' {
              signal ('22023', 'Can not change IRI class <' || classiri || '> because it is used by other quad map objects, e.g., <' || id_to_iri_nosignal (side_s) || '>; moreover, the new declaration may be invalid.'); };
            DB.DBA.RDF_QM_DEFINE_IRI_CLASS_FORMAT (tmpname, iritmpl, arglist, options, classiri);
          }
          old_descr := DB.DBA.RDF_QM_CBD_OF_IRI_CLASS(classiri);
          new_descr := DB.DBA.RDF_QM_CBD_OF_IRI_CLASS(tmpname);
          if (md5 (serialize (old_descr)) = md5 (serialize (new_descr)))
            {
              sparql define input:storage ""
              delete from graph <http://www.openlinksw.com/schemas/virtrdf#>  { `iri(?:tmpname)` ?p ?o }
              where { `iri(?:tmpname)` ?p ?o };
              return vector (vector ('00000', 'Previous definition of IRI class <' || classiri || '> is identical to the new one, not touched'));
            }
          signal ('22023', 'Can not change iri class <' || classiri || '> because it is used by other quad map objects, e.g., <' || id_to_iri_nosignal (side_s) || '>');
        }
      res := vector_concat (res, vector (vector ('00000', 'Previous definition of IRI class <' || classiri || '> has been dropped')));
    }
  else
    res := vector ();
  if ((not bij) and __sprintff_is_proven_bijection (iritmpl))
    bij := 1;
  bij_sff_count := 0;
  for (sff_ctr := 0; sff_ctr < sff_count; sff_ctr := sff_ctr + 1)
    {
      declare sff varchar;
      sff := sffs [sff_ctr];
      sff := DB.DBA.RDF_QM_MACROEXPAND_TEMPLATE (sff);
      if ((not bij) and __sprintff_is_proven_bijection (sff))
        bij_sff_count := bij_sff_count + 1;
      sparql define input:storage ""
      prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
      insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
          `iri(?:sprintffsid)`
            `iri (bif:sprintf ("%s%d", str (rdf:_), ?:sff_ctr+1))` ?:sff };
    }
  if ((not bij) and (bij_sff_count = sff_count) and (bij_sff_count > 0))
    bij := 1;
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  insert in graph <http://www.openlinksw.com/schemas/virtrdf#>
    {
      `iri(?:classiri)`
        rdf:type virtrdf:QuadMapFormat ;
        virtrdf:inheritFrom `iri(?:basetypeiri)`;
        virtrdf:noInherit virtrdf:qmfName ;
        virtrdf:noInherit virtrdf:qmfCustomString1 ;
        virtrdf:qmfName `bif:concat (?:basetype, '-user-', ?:origclassiri)` ;
        virtrdf:qmfCustomString1 `?:iritmpl` ;
        virtrdf:qmfColumnCount ?:arglist_len ;
        virtrdf:qmfSuperFormats `iri(?:superformatsid)` ;
        virtrdf:qmfIsBijection ?:bij ;
        virtrdf:qmfDerefFlags ?:deref ;
        virtrdf:qmfValRange-rvrRestrictions
          virtrdf:SPART_VARR_IS_REF ,
          virtrdf:SPART_VARR_IS_IRI ,
          virtrdf:SPART_VARR_SPRINTFF ;
        virtrdf:qmfValRange-rvrSprintffs `iri(?:sprintffsid)` ;
        virtrdf:qmfValRange-rvrSprintffCount ?:sff_count .
      `iri(?:sprintffsid)`
        rdf:type virtrdf:array-of-string .
      `iri(?:superformatsid)`
        rdf:type virtrdf:array-of-QuadMapFormat };
  if (isnotnull)
    {
      sparql define input:storage ""
      prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
      insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
          `iri(?:classiri)`
            virtrdf:qmfValRange-rvrRestrictions
              virtrdf:SPART_VARR_NOT_NULL .
          `iri(?:superformatsid)`
            rdf:_1 `iri(bif:concat (?:classiri, "-nullable"))` };
    }
  return vector_concat (res, vector_concat (res, vector (vector ('00000', 'IRI class <' || classiri || '> has been defined (inherited from rdfdf:' || basetype || ')'))));
}
;

create function DB.DBA.RDF_QM_DEFINE_IRI_CLASS_FUNCTIONS (in classiri varchar, in fheaders any, in options any, in origclassiri varchar := null) returns any
{
/*
fheaders is, say,
     vector ( '
            vector ( 'DB.DBA.RDF_DF_GRANTEE_ID_URI' ,
                vector (
                    vector ( 306,  'id' ,  'integer' ,  NULL ) ),  'varchar' ,  NULL ),
            vector ( 'DB.DBA.RDF_DF_GRANTEE_ID_URI_INVERSE' ,
                vector (
                    vector ( 306,  'id_iri' ,  'varchar' ,  NULL ) ),  'integer' ,  NULL ) ) )
*/
  declare uriprint any;
  declare uriprintname, uriparsename varchar;
  declare arglist_len, isnotnull integer;
  declare graphiri varchar;
  declare superformatsid varchar;
  declare bij, deref integer;
  declare sffs any;
  declare res any;
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  superformatsid := classiri || '--SuperFormats';
  bij := get_keyword_ucase ('BIJECTION', options, 0);
  deref := get_keyword_ucase ('DEREF', options, 0);
  sffs := get_keyword_ucase ('RETURNS', options);
  DB.DBA.RDF_QM_ASSERT_JSO_TYPE (classiri, NULL);
  DB.DBA.RDF_QM_CHECK_CLASS_FUNCTION_HEADERS (fheaders, 1, 0, 'IRI composing', 'IRI parsing', bij, deref);
  uriprint := fheaders[0];
  uriprintname := uriprint[0];
  declare arglist, basetype, basetypeiri varchar;
  arglist := uriprint[1];
  arglist_len := length (arglist);
  if (arglist_len <> 1)
    {
      basetype := 'multipart-uri-fn-nullable';
      isnotnull := 0;
    }
  else
    {
      basetype := lower (arglist[0][2]);
      if (not (basetype in ('integer', 'varchar', /* 'date', 'doubleprecision', */ 'numeric')))
        signal ('22023', 'The datatype "' || basetype || '" is not supported in CREATE IRI CLASS <' || classiri || '> USING FUNCTION' );
      basetype := 'sql-' || basetype || '-uri-fn';
      if (coalesce (arglist[0][3], 0))
        isnotnull := 1;
      else
        {
          basetype := basetype || '-nullable';
          isnotnull := 0;
        }
    }
  basetypeiri := 'http://www.openlinksw.com/virtrdf-data-formats#' || basetype;
  if (origclassiri is null)
    origclassiri := classiri;
  if (DB.DBA.RDF_QM_ASSERT_JSO_TYPE (classiri, 'http://www.openlinksw.com/schemas/virtrdf#QuadMapFormat', 1))
    {
      declare side_s IRI_ID;
      side_s := DB.DBA.RDF_QM_GC_SUBTREE (classiri);
      if (side_s is not null)
        {
          declare tmpname varchar;
          declare old_descr, new_descr any;
          tmpname := uuid();
          { declare exit handler for sqlstate '*' {
              signal ('22023', 'Can not change IRI class <' || classiri || '> because it is used by other quad map objects, e.g., <' || id_to_iri_nosignal (side_s) || '>; moreover, the new declaration may be invalid.'); };
            DB.DBA.RDF_QM_DEFINE_IRI_CLASS_FUNCTIONS (tmpname, fheaders, options, classiri);
          }
          old_descr := DB.DBA.RDF_QM_CBD_OF_IRI_CLASS(classiri);
          new_descr := DB.DBA.RDF_QM_CBD_OF_IRI_CLASS(tmpname);
          if (md5 (serialize (old_descr)) = md5 (serialize (new_descr)))
            {
              sparql define input:storage ""
              delete from graph <http://www.openlinksw.com/schemas/virtrdf#>  { `iri(?:tmpname)` ?p ?o }
              where { `iri(?:tmpname)` ?p ?o };
              return vector (vector ('00000', 'Previous definition of IRI class <' || classiri || '> is identical to the new one, not touched'));
            }
            signal ('22023', 'Can not change class <' || classiri || '> because it is used by other quad map objects, e.g., <' || id_to_iri_nosignal (side_s) || '>');
        }
      res := vector (vector ('00000', 'Previous definition of class <' || classiri || '> has been dropped'));
    }
  else
    res := vector ();
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
      `iri(?:classiri)`
        rdf:type virtrdf:QuadMapFormat;
        virtrdf:inheritFrom `iri(?:basetypeiri)`;
        virtrdf:noInherit virtrdf:qmfName ;
        virtrdf:noInherit virtrdf:qmfCustomString1 ;
        virtrdf:qmfName `bif:concat (?:basetype, '-user-', ?:origclassiri)` ;
        virtrdf:qmfColumnCount ?:arglist_len ;
        virtrdf:qmfCustomString1 ?:uriprintname ;
        virtrdf:qmfSuperFormats `iri(?:superformatsid)` ;
        virtrdf:qmfIsBijection ?:bij ;
        virtrdf:qmfDerefFlags ?:deref ;
        virtrdf:qmfValRange-rvrRestrictions
          virtrdf:SPART_VARR_IS_REF ,
          virtrdf:SPART_VARR_IS_IRI ,
          virtrdf:SPART_VARR_IRI_CALC .
      `iri(?:superformatsid)`
        rdf:type virtrdf:array-of-QuadMapFormat };
  if (isnotnull)
    {
      sparql define input:storage ""
      prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
      insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
          `iri(?:classiri)`
            virtrdf:qmfValRange-rvrRestrictions
              virtrdf:SPART_VARR_NOT_NULL };
    }
  if (sffs is not null)
    {
      declare sff_count, sff_ctr integer;
      declare sffsid varchar;
      sffsid := classiri || '--Sprintffs';
      sff_count := length (sffs);
      sparql define input:storage ""
      prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
      insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
          `iri(?:classiri)`
            virtrdf:qmfValRange-rvrRestrictions
              virtrdf:SPART_VARR_SPRINTFF ;
            virtrdf:qmfValRange-rvrSprintffs `iri(?:sffsid)` ;
            virtrdf:qmfValRange-rvrSprintffCount ?:sff_count .
          `iri(?:sffsid)`
            rdf:type virtrdf:array-of-string };
      for (sff_ctr := 0; sff_ctr < sff_count; sff_ctr := sff_ctr + 1)
        {
          declare sff varchar;
          sff := sffs [sff_ctr];
          sff := DB.DBA.RDF_QM_MACROEXPAND_TEMPLATE (sff);
          sparql define input:storage ""
          prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
          insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
              `iri(?:sffsid)`
                `iri (bif:sprintf ("%s%d", str (rdf:_), ?:sff_ctr+1))` ?:sff };
        }
    }
  return vector_concat (res, vector (vector ('00000', 'IRI class <' || classiri || '> has been defined (inherited from rdfdf:' || basetype || ') using ' || uriprintname)));
}
;

create function DB.DBA.RDF_QM_DEFINE_LITERAL_CLASS_FUNCTIONS (in classiri varchar, in fheaders any, in options any, in origclassiri varchar := null) returns any
{
/*
fheaders is identical to DB.DBA.RDF_QM_DEFINE_IRI_CLASS_FUNCTIONS
*/
  declare uriprint any;
  declare uriprintname, uriparsename varchar;
  declare arglist_len integer;
  declare superformatsid varchar;
  declare res any;
  declare const_dt, dt_expn, const_lang varchar;
  declare bij, deref integer;
  superformatsid := classiri || '--SuperFormats';
  const_dt := get_keyword_ucase ('DATATYPE', options);
  const_lang := get_keyword_ucase ('LANG', options);
  bij := get_keyword_ucase ('BIJECTION', options, 0);
  deref := get_keyword_ucase ('DEREF', options, 0);
  DB.DBA.RDF_QM_ASSERT_JSO_TYPE (classiri, NULL);
  DB.DBA.RDF_QM_CHECK_CLASS_FUNCTION_HEADERS (fheaders, 0, 0, 'LITERAL composing', 'LITERAL parsing', bij, deref);
  uriprint := fheaders[0];
  uriprintname := uriprint[0];
  declare arglist, basetype, basetypeiri varchar;
  arglist := uriprint[1];
  arglist_len := length (arglist);
  if (arglist_len <> 1)
    basetype := 'multipart-literal-fn-nullable';
  else
    {
      basetype := lower (arglist[0][2]);
      if (not (basetype in ('integer', 'varchar' /*, 'date', 'doubleprecision'*/)))
        signal ('22023', 'The datatype "' || basetype || '" is not supported in CREATE IRI CLASS <' || classiri || '> USING FUNCTION' );
      basetype := 'sql-' || basetype || '-literal-fn';
      if (not (coalesce (arglist[0][3], 0)))
        basetype := basetype || '-nullable';
    }
  basetypeiri := 'http://www.openlinksw.com/virtrdf-data-formats#' || basetype;
  if (const_dt is not null)
    dt_expn := ' ' || WS.WS.STR_SQL_APOS (const_dt);
  else
    dt_expn := NULL;
  if (origclassiri is null)
    origclassiri := classiri;
  if (DB.DBA.RDF_QM_ASSERT_JSO_TYPE (classiri, 'http://www.openlinksw.com/schemas/virtrdf#QuadMapFormat', 1))
    {
      declare side_s IRI_ID;
      side_s := DB.DBA.RDF_QM_GC_SUBTREE (classiri);
      if (side_s is not null)
        {
          declare tmpname varchar;
          declare old_descr, new_descr any;
          tmpname := uuid();
          { declare exit handler for sqlstate '*' {
              signal ('22023', 'Can not change IRI class <' || classiri || '> because it is used by other quad map objects, e.g., <' || id_to_iri_nosignal (side_s) || '>; moreover, the new declaration may be invalid.'); };
            DB.DBA.RDF_QM_DEFINE_LITERAL_CLASS_FUNCTIONS (tmpname, fheaders, options, classiri);
          }
          old_descr := DB.DBA.RDF_QM_CBD_OF_IRI_CLASS(classiri);
          new_descr := DB.DBA.RDF_QM_CBD_OF_IRI_CLASS(tmpname);
          if (md5 (serialize (old_descr)) = md5 (serialize (new_descr)))
            {
              sparql define input:storage ""
              delete from graph <http://www.openlinksw.com/schemas/virtrdf#>  { `iri(?:tmpname)` ?p ?o }
              where { `iri(?:tmpname)` ?p ?o };
              return vector (vector ('00000', 'Previous definition of literal class <' || classiri || '> is identical to the new one, not touched'));
            }
          signal ('22023', 'Can not change class <' || classiri || '> because it is used by other quad map objects, e.g., <' || id_to_iri_nosignal (side_s) || '>');
        }
      res := vector (vector ('00000', 'Previous definition of class <' || classiri || '> has been dropped'));
    }
  else
    res := vector ();
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
      `iri(?:classiri)`
        rdf:type virtrdf:QuadMapFormat ;
        virtrdf:inheritFrom `iri(?:basetypeiri)` ;
        virtrdf:noInherit virtrdf:qmfName ;
        virtrdf:noInherit virtrdf:qmfCustomString1 ;
        virtrdf:qmfName `bif:concat (?:basetype, '-user-', ?:origclassiri)` ;
        virtrdf:qmfColumnCount ?:arglist_len ;
        virtrdf:qmfCustomString1 ?:uriprintname ;
        virtrdf:qmfDatatypeOfShortTmpl ?:dt_expn ;
        virtrdf:qmfIsBijection ?:bij ;
        virtrdf:qmfDerefFlags ?:deref ;
        virtrdf:qmfValRange-rvrRestrictions virtrdf:SPART_VARR_IS_LIT ;
        virtrdf:qmfValRange-rvrDatatype ?:const_dt ;
        virtrdf:qmfValRange-rvrLanguage ?:const_lang ;
        virtrdf:qmfSuperFormats `iri(?:superformatsid)` .
      `iri(?:superformatsid)`
        rdf:type virtrdf:array-of-QuadMapFormat };
  if (const_dt is not null)
    {
      sparql define input:storage ""
      prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
      insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
          `iri(?:classiri)`
            virtrdf:qmfValRange-rvrRestrictions virtrdf:SPART_VARR_TYPED };
    }
  return vector_concat (res, vector (vector ('00000', 'LITERAL class <' || classiri || '> has been defined (inherited from rdfdf:' || basetype || ') using ' || uriprintname)));
}
;

--!AWK PUBLIC
create function DB.DBA.RDF_BAD_CLASS_INV_FUNCTION (inout val any) returns any
{
  return NULL;
}
;

create procedure DB.DBA.RDF_QM_CHECK_CLASS_FUNCTION_HEADERS (inout fheaders any, in is_iri_decl integer, in only_one_arg integer, in pdesc varchar, in invdesc varchar, in bij integer, in deref integer)
{
  declare uriprint any;
  declare uriprintname varchar;
  declare argctr, argcount integer;
  uriprint := fheaders[0];
  uriprintname := uriprint[0];
  argcount := length (uriprint[1]);
  if (only_one_arg and (1 <> length (uriprint[1])))
    signal ('22023', pdesc || ' function "' || uriprintname || '" should have exactly one argument');
  if (1 = length (fheaders))
    {
      if (bij or deref)
        {
          if (0 = argcount)
            signal ('22023',
              sprintf ('%s function "%s" can not be used in a class with OPTION (BIJECTION) or OPTION (DEREF), because it has no arguments.',
                pdesc, uriprintname ) );
          signal ('22023',
            sprintf ('%s function "%s" can not be used in a class with OPTION (BIJECTION) or OPTION (DEREF) without related %d inverse functions',
              pdesc, uriprintname, argcount ) );
        }
    }
  if (is_iri_decl and (uriprint[2] <> 'varchar'))
    signal ('22023', pdesc || ' function "' || uriprintname || '" should return varchar, not ' || uriprint[2]);
  foreach (any arg in uriprint[1]) do
    if (UNAME'in' <> arg[0])
      signal ('22023', 'Only "in" parameters are now supported in argument lists of ' || pdesc || ' functions, not "' || arg[0] || '"');
  if (argcount <> (length (fheaders) - 1))
    {
      if ((1 <> length (fheaders)) or (0 = argcount))
        signal ('22023',
          sprintf ('%s function "%s" has %d arguments but %d inverse functions',
            pdesc, uriprintname, argcount, (length (fheaders) - 1)
            ) );
      declare inv any;
      inv := vector ('DB.DBA.RDF_BAD_CLASS_INV_FUNCTION', vector (vector ('in', 'val', 'any', 0)), 'any', 0);
      fheaders := make_array (1 + argcount, 'any');
      fheaders[0] := uriprint;
      for (argctr := 0; argctr < argcount; argctr := argctr + 1)
        {
          inv[2] := uriprint[1][argctr][2];
          fheaders[argctr+1] := inv;
        }
    }
  else if (1 = argcount)
    {
      if (fheaders[1][0] <> uriprintname || '_INVERSE')
        signal ('22023', 'Name of ' || invdesc || ' function should be "' || uriprintname || '_INVERSE", not "' || fheaders[1][0] || '", other variants are not supported by the current version' );
    }
  else
    {
      for (argctr := 0; argctr < argcount; argctr := argctr + 1)
        {
          declare uriparsename varchar;
          uriparsename := sprintf ('%s_INV_%d', uriprintname, argctr+1);
          if (fheaders[argctr + 1][0] <> uriparsename)
            signal ('22023', 'Name of inverse function should be "' || uriparsename || '", not "' || fheaders[argctr + 1][0] || '", other variants are not supported by the current version' );
        }
    }
  for (argctr := 0; argctr < argcount; argctr := argctr + 1)
    {
      declare uriparse any;
      uriparse := fheaders [argctr + 1];
      if (1 <> length (uriparse[1]))
        signal ('22023', invdesc || ' function ' || uriparse[0] || ' should have only one argument');
      if (UNAME'in' <> uriparse[1][0][0])
        signal ('22023', 'Only "in" parameters are now supported in argument lists of ' || invdesc || ' functions, not "' || uriparse[1][0][0] || '"');
      if ((uriparse[1][0][2] <> uriprint[2]) and (uriparse[1][0][2] <> 'any'))
        signal ('22023', invdesc || ' function "' || uriparse[0] || '" should have argument of type ' || uriprint[2] || ', not ' || uriparse[1][0][2]);
      if ((uriparse[2] <> uriprint[1][argctr][2]) and (uriprint[1][argctr][2] <> 'any'))
        signal ('22023', 'The return value of "' || uriparse[0] || '" and the argument #' || cast (argctr+1 as varchar) || ' of "' || uriprintname || '" should be of the same data type');
      if (coalesce (uriparse[1][0][3], 0))
        signal ('22023', invdesc || ' function ' || uriparse[0] || ' should have nullable argument');
    }
}
;

create function DB.DBA.RDF_QM_DEFINE_SUBCLASS (in subclassiri varchar, in superclassiri varchar) returns any
{
  DB.DBA.RDF_QM_ASSERT_JSO_TYPE (subclassiri, 'http://www.openlinksw.com/schemas/virtrdf#QuadMapFormat');
  DB.DBA.RDF_QM_ASSERT_JSO_TYPE (superclassiri, 'http://www.openlinksw.com/schemas/virtrdf#QuadMapFormat');
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
      `iri(?:subclassiri)` virtrdf:isSubclassOf `iri(?:superclassiri)` };
  return vector (vector ('00000', 'IRI class <' || subclassiri || '> is now known as a subclass of <' || superclassiri || '>'));
}
;

create function DB.DBA.RDF_QM_DROP_CLASS (in classiri varchar) returns any
{
  if (DB.DBA.RDF_QM_ASSERT_JSO_TYPE (classiri, 'http://www.openlinksw.com/schemas/virtrdf#QuadMapFormat', 1))
    {
      declare side_s IRI_ID;
      side_s := DB.DBA.RDF_QM_GC_SUBTREE (classiri);
      if (side_s is not null)
        signal ('22023', 'Can not drop class <' || classiri || '> because it is used by other quad map objects, e.g., <' || id_to_iri_nosignal (side_s) || '>');
    }
  return vector (vector ('00000', 'Previous definition of class <' || classiri || '> has been dropped'));
}
;

create function DB.DBA.RDF_QM_DROP_QUAD_STORAGE (in storage varchar) returns any
{
  declare graphiri varchar;
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  DB.DBA.RDF_QM_ASSERT_STORAGE_FLAG (storage, 0);
  DB.DBA.RDF_QM_GC_SUBTREE (storage);
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> {
      `iri(?:storage)` ?p ?o
    }
  where { graph ?:graphiri { `iri(?:storage)` ?p ?o } };
  return vector (vector ('00000', 'Quad storage <' || storage || '> is removed from the quad mapping schema'));
}
;

create function DB.DBA.RDF_QM_DEFINE_QUAD_STORAGE (in storage varchar) returns any
{
  declare graphiri, qsusermaps varchar;
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  DB.DBA.RDF_QM_ASSERT_JSO_TYPE (storage, NULL);
  qsusermaps := storage || '--UserMaps';
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
      `iri(?:storage)`
        rdf:type virtrdf:QuadStorage ;
        virtrdf:qsUserMaps `iri(?:qsusermaps)` .
      `iri(?:qsusermaps)`
        rdf:type virtrdf:array-of-QuadMap };
  return vector (vector ('00000', 'A new empty quad storage <' || storage || '> is added to the quad mapping schema'));
}
;

create function DB.DBA.RDF_QM_BEGIN_ALTER_QUAD_STORAGE (in storage varchar) returns any
{
  declare graphiri varchar;
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  DB.DBA.RDF_QM_ASSERT_STORAGE_FLAG (storage, 0);
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
      `iri(?:storage)` virtrdf:qsAlterInProgress `bif:now NIL` };
  return vector (vector ('00000', 'Quad storage <' || storage || '> is flagged as being edited'));
}
;

create function DB.DBA.RDF_QM_END_ALTER_QUAD_STORAGE (in storage varchar) returns any
{
  declare graphiri varchar;
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  DB.DBA.RDF_QM_ASSERT_JSO_TYPE (storage, 'http://www.openlinksw.com/schemas/virtrdf#QuadStorage');
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> {
      `iri(?:storage)` virtrdf:qsAlterInProgress ?dtstart }
  where { graph ?:graphiri {
          `iri(?:storage)` virtrdf:qsAlterInProgress ?dtstart } };
  return vector (vector ('00000', 'Quad storage <' || storage || '> is unflagged and can be edited by other transactions'));
}
;

create function DB.DBA.RDF_QM_STORE_ATABLES (in qmvid varchar, in atablesid varchar, inout atables any)
{
  declare atablectr, atablecount integer;
  atablecount := length (atables);
  for (atablectr := 0; atablectr < atablecount; atablectr := atablectr + 1)
    {
      declare pair any;
      declare qtable, alias, inner_id varchar;
      pair := atables [atablectr];
      alias := pair[0];
      qtable := pair[1];
      inner_id := qmvid || '-atable-' || alias || '-' || qtable;
      sparql define input:storage ""
      prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
      insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
          `iri(?:atablesid)`
            `iri (bif:sprintf ("%s%d", str (rdf:_), ?:atablectr+1))` `iri(?:inner_id)` .
          `iri(?:inner_id)`
            rdf:type virtrdf:QuadMapATable ;
            virtrdf:qmvaAlias ?:alias ;
            virtrdf:qmvaTableName ?:qtable };
    }
}
;

create function DB.DBA.RDF_QM_FT_USAGE (in ft_type varchar, in ft_alias varchar, in ft_aliased_col any, in sqlcols any, in conds any, in options any := null)
{
  declare ft_tbl, ft_col, ftid, ftcondsid varchar;
  declare condctr, condcount, ft_isxml integer;
  ft_tbl := ft_aliased_col[0];
  ft_col := ft_aliased_col[2];
  ft_isxml := case (isnull (ft_type)) when 0 then 1 else null end;
  if (ft_alias <> ft_aliased_col[1])
    signal ('22023', sprintf ('"TEXT LITERAL %I.%I" should be at the end of "FROM ... AS %I" declaration', ft_aliased_col[1], ft_aliased_col, ft_alias));
  condcount := length (conds);
  ftid := 'sys:ft-' || md5 (serialize (vector (ft_alias, ft_tbl, ft_col, conds, options)));
  if (condcount > 0)
    ftcondsid := ftid || '-conds';
  else
    ftcondsid := NULL;
/* Trick to avoid repeating re-declarations */
  if (exists (sparql define input:storage ""
    prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
    ask where {
        graph <http://www.openlinksw.com/schemas/virtrdf#> {
          ?:ftid
            rdf:type virtrdf:QuadMapFText ;
            virtrdf:qmvftAlias ?:ft_alias ;
            virtrdf:qmvftTableName ?:ft_tbl ;
            virtrdf:qmvftColumnName ?:ft_col ;
            virtrdf:qmvftConds `iri(?:ftcondsid)` } } ) )
    return ftid;
  if (ftcondsid is not null)
    DB.DBA.RDF_QM_GC_SUBTREE (ftcondsid);
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
      `iri(?:ftid)`
        rdf:type virtrdf:QuadMapFText ;
        virtrdf:qmvftAlias ?:ft_alias ;
        virtrdf:qmvftTableName ?:ft_tbl ;
        virtrdf:qmvftColumnName ?:ft_col ;
        virtrdf:qmvftXmlIndex ?:ft_isxml ;
        virtrdf:qmvftConds `iri(?:ftcondsid)` .
      `iri(?:ftcondsid)`
        rdf:type virtrdf:array-of-string };
  for (condctr := 0; condctr < condcount; condctr := condctr + 1)
    {
      declare sqlcond varchar;
      sqlcond := conds [condctr];
      sparql define input:storage ""
      prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
      insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
          `iri(?:ftcondsid)`
            `iri (bif:sprintf ("%s%d", str (rdf:_), ?:condctr+1))` ?:sqlcond };
    }
  return ftid;
}
;

create function DB.DBA.RDF_QM_CHECK_COLUMNS_FORM_KEY (in sqlcols any) returns integer
{
  declare alias, tbl varchar;
  declare colctr, colcount integer;
  colcount := length (sqlcols);
  if (0 = colcount)
    return 0;
  tbl := sqlcols[0][0];
  alias := sqlcols[0][1];
  for (colctr := 1; colctr < colcount; colctr := colctr + 1)
    {
      if ((sqlcols[colctr][0] <> tbl) or (sqlcols[colctr][1] <> alias))
        return 0;
    }
  for (select KEY_ID, KEY_N_SIGNIFICANT from DB.DBA.SYS_KEYS where (KEY_TABLE = tbl) and KEY_IS_UNIQUE) do
    {
      declare keycolnames any;
      if (KEY_N_SIGNIFICANT > colcount)
        goto no_match;
      for (select "COLUMN" as COL
        from DB.DBA.SYS_KEY_PARTS join DB.DBA.SYS_COLS on (KP_COL = COL_ID)
        where KP_KEY_ID = KEY_ID and KP_NTH < KEY_N_SIGNIFICANT ) do
        {
          for (colctr := 0; colctr < colcount; colctr := colctr + 1)
            {
              if (sqlcols[colctr][2] = COL)
                goto col_ok;
            }
          goto no_match;
col_ok: ;
        }
      return 1;

no_match: ;
    }
  return 0;
}
;

create function DB.DBA.RDF_QM_DEFINE_MAP_VALUE (in qmv any, in fldname varchar, inout tablename varchar) returns varchar
{
/* iqi qmv: vector ( UNAME'http://www.openlinksw.com/schemas/oplsioc#user_iri' , vector ( vector ('DB.DBA.SYS_USERS', 'alias1', 'U_ID') ) ) */
  declare atables, sqlcols, conds any;
  declare ftextid varchar;
  declare atablectr, atablecount integer;
  declare colctr, colcount, fmtcolcount integer;
  declare condctr, condcount integer;
  declare columnsformkey integer;
  declare fmtid, iriclassid, qmvid, qmvatablesid, qmvcolsid, qmvcondsid varchar;
  -- dbg_obj_princ ('DB.DBA.RDF_QM_DEFINE_MAP_VALUE (', qmv, fldname, tablename, ')');
  fmtid := qmv[0];
  atables := qmv[1];
  sqlcols := qmv[2];
  conds := qmv[3];
  ftextid := qmv[4];
  atablecount := length (atables);
  colcount := length (sqlcols);
  condcount := length (conds);
  if (fmtid <> UNAME'literal')
    {
      DB.DBA.RDF_QM_ASSERT_JSO_TYPE (fmtid, 'http://www.openlinksw.com/schemas/virtrdf#QuadMapFormat');
      fmtcolcount := ((sparql select ?cc from <http://www.openlinksw.com/schemas/virtrdf#>
          where { `iri(?:fmtid)` virtrdf:qmfColumnCount ?cc } ) );
      if (fmtcolcount <> colcount)
        signal ('22023', 'Number of columns of quad map value does not match number of arguments of format <' || fmtid || '>');
    }
  for (colctr := 0; colctr < colcount; colctr := colctr + 1)
    {
      declare sqlcol any;
      sqlcol := sqlcols [colctr];
      if (not exists (select top 1 1 from DB.DBA.SYS_COLS where "TABLE" = sqlcol[0]))
        {
          if (sqlcol[1] is not null)
            signal ('22023', 'No table ' || sqlcol[0] || ' (alias ' || sqlcol[1] || ') in database, please check spelling and character case');
          else
            signal ('22023', 'No table ' || sqlcol[0] || ' in database, please check spelling and character case');
        }
      if (not exists (select top 1 1 from DB.DBA.SYS_COLS where "TABLE" = sqlcol[0] and "COLUMN" = sqlcol[2]))
        {
          if (sqlcol[1] is not null)
            signal ('22023', 'No column ' || sqlcol[2] || ' in table ' || sqlcol[0] || ' (alias ' || sqlcol[1] || ') in database, please check spelling and character case');
          else
            signal ('22023', 'No column ' || sqlcol[2] || ' in table ' || sqlcol[0] || ' in database, please check spelling and character case');
        }
      if (tablename is null)
        tablename := sqlcol[0];
      else if (tablename <> sqlcol[0])
        tablename := '';
    }
  if (tablename is null)
    tablename := '';
  if (fmtid = UNAME'literal')
    {
      declare coldtp, colnullable integer;
      declare coltype varchar;
      select COL_DTP, coalesce (COL_NULLABLE, 1) into coldtp, colnullable
      from DB.DBA.SYS_COLS where "TABLE" = sqlcols[0][0] and "COLUMN" = sqlcols[0][2];
      coltype := case (coldtp)
        when __tag of long varchar then 'longvarchar'
        when __tag of timestamp then 'datetime' -- timestamp
        when __tag of date then 'date'
        when __tag of long varbinary then 'longvarbinary'
        when 188 then 'integer'
        when __tag of integer then 'integer'
        when __tag of varchar then 'varchar'
        when __tag of real then 'doubleprecision' -- actually single precision float
        when __tag of double precision then 'doubleprecision'
        when 192 then 'varchar' -- actually character
        when __tag of datetime then 'datetime'
        when __tag of numeric then 'numeric'
        else NULL end;
      if (coltype is null)
        signal ('22023', 'The datatype of column "' || sqlcols[0][2] ||
          '" of table "' || sqlcols[0][0] || '" (COL_DTP=' || cast (coldtp as varchar) ||
          ') can not be mapped to an RDF literal in current version of Virtuoso' );
      fmtid := 'http://www.openlinksw.com/virtrdf-data-formats#sql-' || coltype;
      if (colnullable)
        fmtid := fmtid || '-nullable';
      iriclassid := null;
    }
  else
    iriclassid := fmtid;
  qmvid := 'sys:qmv-' || md5 (serialize (vector (fmtid, sqlcols)));
  qmvatablesid := qmvid || '-atables';
  qmvcolsid := qmvid || '-cols';
  qmvcondsid := qmvid || '-conds';
/* Trick to avoid repeating re-declarations */
  if (exists (sparql define input:storage ""
    prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
    ask where {
        graph <http://www.openlinksw.com/schemas/virtrdf#> {
          ?:qmvid
            rdf:type virtrdf:QuadMapValue ;
            virtrdf:qmvATables `iri(?:qmvatablesid)` ;
            virtrdf:qmvColumns `iri(?:qmvcolsid)` ;
            virtrdf:qmvConds `iri(?:qmvcondsid)` ;
            virtrdf:qmvFormat `iri(?:fmtid)` . } } ) )
    return qmvid;
/* Create everything if qmv has not been found */
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> {
    `iri(?:qmvid)` ?p ?o . }
  where { graph <http://www.openlinksw.com/schemas/virtrdf#> {
          `iri(?:qmvid)` ?p ?o .
        } };
  for (sparql define input:storage ""
    prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
    select ?atable where { graph <http://www.openlinksw.com/schemas/virtrdf#> {
            `iri(?:qmvatablesid)` ?p ?atable } } ) do {
      DB.DBA.RDF_QM_GC_SUBTREE ("atable");
    }
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> {
    `iri(?:qmvatablesid)` ?p ?o }
  where { graph <http://www.openlinksw.com/schemas/virtrdf#> {
          `iri(?:qmvatablesid)` ?p ?o .
        } };
  for (sparql define input:storage ""
    prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
    select ?col where { graph <http://www.openlinksw.com/schemas/virtrdf#> {
            `iri(?:qmvcolsid)` ?p ?col } } ) do {
      DB.DBA.RDF_QM_GC_SUBTREE ("col");
    }
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> {
    `iri(?:qmvcolsid)` ?p ?o }
  where { graph <http://www.openlinksw.com/schemas/virtrdf#> {
          `iri(?:qmvcolsid)` ?p ?o .
        } };
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> {
    `iri(?:qmvcondsid)` ?p ?o }
  where { graph <http://www.openlinksw.com/schemas/virtrdf#> {
          `iri(?:qmvcondsid)` ?p ?o .
        } };
  if (0 = atablecount)
    qmvatablesid := NULL;
  if (0 = condcount)
    qmvcondsid := NULL;
  columnsformkey := DB.DBA.RDF_QM_CHECK_COLUMNS_FORM_KEY (sqlcols);
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
      `iri(?:qmvid)`
        rdf:type virtrdf:QuadMapValue;
        virtrdf:qmvTableName ?:tablename;
        virtrdf:qmvATables `iri(?:qmvatablesid)`;
        virtrdf:qmvColumns `iri(?:qmvcolsid)`;
        virtrdf:qmvConds `iri(?:qmvcondsid)`;
        virtrdf:qmvFormat `iri(?:fmtid)`;
        virtrdf:qmvFText `iri(?:ftextid)`;
        virtrdf:qmvIriClass `iri(?:iriclassid)`;
        virtrdf:qmvColumnsFormKey ?:columnsformkey .
      `iri(?:qmvatablesid)`
        rdf:type virtrdf:array-of-QuadMapATable .
      `iri(?:qmvcolsid)`
        rdf:type virtrdf:array-of-QuadMapColumn .
      `iri(?:qmvcondsid)`
        rdf:type virtrdf:array-of-string };
  DB.DBA.RDF_QM_STORE_ATABLES (qmvid, qmvatablesid, atables);
  for (colctr := 0; colctr < colcount; colctr := colctr + 1)
    {
      declare sqlcol any;
      declare qtable, alias, colname, inner_id varchar;
      sqlcol := sqlcols [colctr];
      alias := sqlcol[1];
      colname := sqlcol[2];
      inner_id := qmvid || '-col-' || alias || '-' || colname;
      sparql define input:storage ""
      prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
      insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
          `iri(?:qmvcolsid)`
            `iri (bif:sprintf ("%s%d", str (rdf:_), ?:colctr+1))` `iri(?:inner_id)` .
          `iri(?:inner_id)`
            rdf:type virtrdf:QuadMapColumn ;
            virtrdf:qmvcAlias ?:alias ;
            virtrdf:qmvcColumnName ?:colname };
    }
  for (condctr := 0; condctr < condcount; condctr := condctr + 1)
    {
      declare sqlcond varchar;
      sqlcond := conds [condctr];
      sparql define input:storage ""
      prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
      insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
          `iri(?:qmvcondsid)`
            `iri (bif:sprintf ("%s%d", str (rdf:_), ?:condctr+1))` ?:sqlcond };
    }
  return qmvid;
}
;

create procedure DB.DBA.RDF_QM_NORMALIZE_QMV (
  inout qmv any, inout qmvfix any, inout qmvid any,
  in can_be_literal integer, in fldname varchar, inout tablename varchar )
{
  -- dbg_obj_princ ('DB.DBA.RDF_QM_NORMALIZE_QMV (', qmv, ' ..., ..., ', can_be_literal, fldname, ')');
  qmvid := qmvfix := NULL;
  if ((__tag of vector = __tag (qmv)) and (5 = length (qmv)))
    qmvid := DB.DBA.RDF_QM_DEFINE_MAP_VALUE (qmv, fldname, tablename);
  else if (217 = __tag (qmv))
      qmvfix := DB.DBA.RDF_MAKE_IID_OF_QNAME (qmv);
  else if (qmv is not null and not can_be_literal)
    signal ('22023', sprintf ('Quad map declaration can not specify a literal (non-IRI) constant for its %s (tag %d, length %d)',
      fldname, __tag (qmv), length (qmv) ) );
  else if (__tag of vector = __tag (qmv))
    signal ('22023', sprintf ('Quad map declaration contains constant %s of unsupported type (tag %d, length %d)',
      fldname, __tag (qmv), length (qmv) ) );
  else
    qmvfix := qmv;
  -- dbg_obj_princ ('DB.DBA.RDF_QM_NORMALIZE_QMV has found ', fldname, tablename);
}
;

create function DB.DBA.RDF_QM_DEFINE_MAPPING (in storage varchar,
  in qmrawid varchar, in qmid varchar, in qmparentid varchar,
  in qmv_g any, in qmv_s any, in qmv_p any, in qmv_o any,
  in is_real integer, in atables any, in conds any, in opts any ) returns any
{
  declare old_actual_type varchar;
  declare tablename, qmvid_g, qmvid_s, qmvid_p, qmvid_o varchar;
  declare qmvfix_g, qmvfix_s, qmvfix_p, qmvfix_o any;
  declare qm_exclusive, qm_soft_exclusive, qm_empty, qm_is_default, qmusersubmapsid, atablesid, qmcondsid varchar;
  declare qm_order, atablectr, atablecount, condctr, condcount integer;
  -- dbg_obj_princ ('DB.DBA.RDF_QM_DEFINE_MAPPING (', storage, qmrawid, qmid, qmparentid, qmv_g, qmv_s, qmv_p, qmv_o, is_real, atables, conds, opts, ')');
  DB.DBA.RDF_QM_ASSERT_STORAGE_FLAG (storage, 1);
--  DB.DBA.RDF_QM_ASSERT_JSO_TYPE (qmid, NULL);
  old_actual_type := coalesce ((sparql define input:storage ""
      prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
      select ?t where {
        graph <http://www.openlinksw.com/schemas/virtrdf#> {
            `iri(?:qmid)` rdf:type ?t } } ));
  if (old_actual_type is not null)
    {
      declare old_lstiri, old_side_use varchar;
      if (old_actual_type <> 'http://www.openlinksw.com/schemas/virtrdf#QuadMap')
        signal ('22023', 'The RDF QM schema object <' || qmid || '> already exists, type <' || old_actual_type || '>');
      old_lstiri := (sparql define input:storage ""
        select ?lst where { graph <http://www.openlinksw.com/schemas/virtrdf#> {
            `iri(?:storage)` virtrdf:qsUserMaps ?lst } } );
      old_side_use := coalesce ((sparql define input:storage ""
          select ?s where {
            graph <http://www.openlinksw.com/schemas/virtrdf#> {
                ?s ?p `iri(?:qmid)` filter ((?s != iri(?:storage)) && (?s != iri(?:old_lstiri))) } } ) );
      if (old_side_use is not null)
        signal ('22023', 'Can not re-create the RDF Quad Mapping <' || qmid || '> because it is referenced by <' || old_side_use || '>');
      DB.DBA.RDF_QM_DELETE_MAPPING_FROM_STORAGE (storage, NULL, qmid);
      DB.DBA.RDF_QM_GC_SUBTREE (qmid);
    }
  if (qmparentid is not null)
    DB.DBA.RDF_QM_ASSERT_JSO_TYPE (qmparentid, 'http://www.openlinksw.com/schemas/virtrdf#QuadMap');
  DB.DBA.RDF_QM_ASSERT_STORAGE_CONTAINS_MAPPING (storage, qmid, 0);
  tablename := NULL;
  DB.DBA.RDF_QM_NORMALIZE_QMV (qmv_g, qmvfix_g, qmvid_g, 0, 'graph', tablename);
  DB.DBA.RDF_QM_NORMALIZE_QMV (qmv_s, qmvfix_s, qmvid_s, 0, 'subject', tablename);
  DB.DBA.RDF_QM_NORMALIZE_QMV (qmv_p, qmvfix_p, qmvid_p, 0, 'predicate', tablename);
  DB.DBA.RDF_QM_NORMALIZE_QMV (qmv_o, qmvfix_o, qmvid_o, 1, 'object', tablename);
  if (get_keyword_ucase ('EXCLUSIVE', opts))
    qm_exclusive := 'http://www.openlinksw.com/schemas/virtrdf#SPART_QM_EXCLUSIVE';
  else
    qm_exclusive := NULL;
  if (get_keyword_ucase ('OK_FOR_ANY_QUAD', opts))
    qm_is_default := 'http://www.openlinksw.com/schemas/virtrdf#SPART_QM_OK_FOR_ANY_QUAD';
  else
    qm_is_default := NULL;
  if (get_keyword_ucase ('SOFT_EXCLUSIVE', opts))
    qm_soft_exclusive := 'http://www.openlinksw.com/schemas/virtrdf#SPART_QM_SOFT_EXCLUSIVE';
  else
    qm_soft_exclusive := NULL;
  if (not is_real)
    {
      qm_empty := 'http://www.openlinksw.com/schemas/virtrdf#SPART_QM_EMPTY';
    }
  else
    {
      qm_empty := NULL;
      if (tablename is null)
        signal ('22023', 'At least one field of a quad map should be map value, not a constant');
    }
  if ('' = tablename)
    tablename := NULL;
  qm_order := get_keyword_ucase ('ORDER', opts);
  if (not is_real)
    {
      qmusersubmapsid := qmid || '--UserSubMaps';
      atablesid := NULL;
      qmcondsid := NULL;
    }
  else
    {
      qmusersubmapsid := NULL;
      atablesid := qmid || '--ATables';
      qmcondsid := qmid || '--Conds';
    }
  if (qm_is_default is not null)
    {
      if (qm_order is not null)
        signal ('22023', 'ORDER option is not applicable to default quad map');
      if (qmparentid is not null)
        signal ('22023', 'A default quad map can not be a sub-map of other quad map');
    }
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> {
    `iri(?:atablesid)` ?p ?o }
  where { graph <http://www.openlinksw.com/schemas/virtrdf#> {
          `iri(?:atablesid)` ?p ?o .
        } };
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> {
    `iri(?:qmcondsid)` ?p ?o }
  where { graph <http://www.openlinksw.com/schemas/virtrdf#> {
          `iri(?:qmcondsid)` ?p ?o .
        } };
  atablecount := length (atables);
  condcount := length (conds);
  if (0 = atablecount)
    atablesid := NULL;
  if (0 = condcount)
    qmcondsid := NULL;
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
      `iri(?:qmid)`
        rdf:type virtrdf:QuadMap ;
        virtrdf:qmGraphRange-rvrFixedValue ?:qmvfix_g ;
        virtrdf:qmGraphMap `iri(?:qmvid_g)` ;
        virtrdf:qmSubjectRange-rvrFixedValue ?:qmvfix_s ;
        virtrdf:qmSubjectMap `iri(?:qmvid_s)` ;
        virtrdf:qmPredicateRange-rvrFixedValue ?:qmvfix_p ;
        virtrdf:qmPredicateMap `iri(?:qmvid_p)` ;
        virtrdf:qmObjectRange-rvrFixedValue ?:qmvfix_o ;
        virtrdf:qmObjectMap `iri(?:qmvid_o)` ;
        virtrdf:qmTableName ?:tablename ;
        virtrdf:qmATables `iri(?:atablesid)` ;
        virtrdf:qmConds `iri(?:qmcondsid)` ;
        virtrdf:qmUserSubMaps `iri(?:qmusersubmapsid)` ;
        virtrdf:qmMatchingFlags `iri(?:qm_exclusive)` ;
        virtrdf:qmMatchingFlags `iri(?:qm_empty)` ;
        virtrdf:qmMatchingFlags `iri(?:qm_is_default)` ;
        virtrdf:qmMatchingFlags `iri(?:qm_soft_exclusive)` ;
        virtrdf:qmPriorityOrder ?:qm_order .
      `iri(?:atablesid)`
        rdf:type virtrdf:array-of-QuadMapATable .
      `iri(?:qmcondsid)`
        rdf:type virtrdf:array-of-string .
      `iri(?:qmusersubmapsid)`
        rdf:type virtrdf:array-of-QuadMap };
  DB.DBA.RDF_QM_STORE_ATABLES (qmid, atablesid, atables);
  for (condctr := 0; condctr < condcount; condctr := condctr + 1)
    {
      declare sqlcond varchar;
      sqlcond := conds [condctr];
      sparql define input:storage ""
      prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
      insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
          `iri(?:qmcondsid)`
            `iri (bif:sprintf ("%s%d", str (rdf:_), ?:condctr+1))` ?:sqlcond };
    }
  if (qm_is_default is not null)
    DB.DBA.RDF_QM_SET_DEFAULT_MAPPING (storage, qmid);
  else
    DB.DBA.RDF_QM_ADD_MAPPING_TO_STORAGE (storage, qmparentid, qmid, qm_order);
  return vector (vector ('00000', 'Quad map <' || qmid || '> has been created and added to the <' || storage || '>'));
}
;

create function DB.DBA.RDF_QM_ATTACH_MAPPING (in storage varchar, in source varchar, in opts any) returns any
{
  declare graphiri varchar;
  declare qmid, qmgraph varchar;
  declare qm_order, qm_is_default integer;
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  qmid := get_keyword_ucase ('ID', opts, NULL);
  qmgraph := get_keyword_ucase ('GRAPH', opts, NULL);
  DB.DBA.RDF_QM_ASSERT_STORAGE_FLAG (storage, 1);
  DB.DBA.RDF_QM_ASSERT_STORAGE_FLAG (source, 0);
  if (qmid is null)
    {
      qmid := coalesce ((sparql define input:storage ""
          prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
          select ?s where {
            graph ?:graphiri {
                ?s rdf:type virtrdf:QuadMap .
                ?s virtrdf:qmGraphRange-rvrFixedValue `iri(?:qmgraph)` .
                ?s virtrdf:qmMatchingFlags virtrdf:SPART_QM_EMPTY .
              } } ));
      if (qmid is null)
        return vector (vector ('00100', 'Quad map for graph <' || qmgraph || '> is not found'));
    }
  qm_order := coalesce ((sparql define input:storage ""
      select ?o where { graph ?:graphiri {
              `iri(?:qmid)` virtrdf:qmPriorityOrder ?o } } ) );
  if (exists (sparql define input:storage ""
      ask where { graph ?:graphiri {
              `iri(?:qmid)` virtrdf:qmMatchingFlags virtrdf:SPART_QM_OK_FOR_ANY_QUAD } } ) )
    qm_is_default := 1;
  else
    qm_is_default := 0;
  DB.DBA.RDF_QM_ASSERT_STORAGE_CONTAINS_MAPPING (storage, qmid, 0);
  DB.DBA.RDF_QM_ASSERT_STORAGE_CONTAINS_MAPPING (source, qmid, 1);
  DB.DBA.RDF_QM_ASSERT_JSO_TYPE (qmid, 'http://www.openlinksw.com/schemas/virtrdf#QuadMap');
  if (qm_is_default)
    DB.DBA.RDF_QM_SET_DEFAULT_MAPPING (storage, qmid);
  else
    DB.DBA.RDF_QM_ADD_MAPPING_TO_STORAGE (storage, NULL, qmid, NULL /* !!!TBD: place real value instead of constant NULL */);
  return vector (vector ('00000', 'Quad map <' || qmid || '> is added to the storage <' || storage || '>'));
}
;

create procedure DB.DBA.RDF_QM_ADD_MAPPING_TO_STORAGE (in storage varchar, in qmparent varchar, in qmid varchar, in qmorder integer)
{
  declare graphiri, lstiri varchar;
  declare iris_and_orders any;
  declare ctr, qmid_is_printed integer;
  -- dbg_obj_princ ('DB.DBA.RDF_QM_ADD_MAPPING_TO_STORAGE (', storage, qmparent, qmid, qmorder, ')');
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  if (qmparent is not null)
    lstiri := (sparql define input:storage ""
      select ?lst where { graph ?:graphiri {
          `iri(?:qmparent)` virtrdf:qmUserSubMaps ?lst } } );
  else
    lstiri := (sparql define input:storage ""
      select ?lst where { graph ?:graphiri {
          `iri(?:storage)` virtrdf:qsUserMaps ?lst } } );
  -- dbg_obj_princ ('DB.DBA.RDF_QM_ADD_MAPPING_TO_STORAGE: storage=', storage, ', qmparent=', qmparent, ', lstiri=', lstiri);
  if (qmorder is null)
    qmorder := 1999;
  iris_and_orders := (
    select VECTOR_AGG (vector (sub."id", sub."p", sub."ord1"))
    from (
      select sp."id", sp."p", sp."ord1"
      from (
        sparql define input:storage ""
        select ?id ?p
          (bif:coalesce (?ord,
              1000 + bif:aref (
                bif:sprintf_inverse (
                  str(?p),
                  bif:concat (str (rdf:_), "%d"),
                  2),
                0 ) ) ) as ?ord1
        where { graph ?:graphiri {
                `iri(?:lstiri)` ?p ?id .
                filter (! bif:isnull (bif:aref (
                      bif:sprintf_inverse (
                        str(?p),
                        bif:concat (str (rdf:_), "%d"),
                        2),
                      0 ) ) ) .
                optional {?id virtrdf:qmPriorityOrder ?ord} } } ) as sp
      order by 3, 2, 1 ) as sub );
  -- dbg_obj_princ ('DB.DBA.RDF_QM_ADD_MAPPING_TO_STORAGE: found ', iris_and_orders);
  foreach (any itm in iris_and_orders) do
    {
      declare id, p varchar;
      id := itm[0];
      p := itm[1];
      sparql define input:storage ""
      delete from graph <http://www.openlinksw.com/schemas/virtrdf#> {
       `iri(?:lstiri)` `iri(?:p)` `iri(?:id)` };
    }
  ctr := 1;
  qmid_is_printed := 0;
  foreach (any itm in iris_and_orders) do
    {
      declare id varchar;
      declare ord integer;
      id := itm[0];
      ord := itm[2];
      if (ord > qmorder)
        {
          sparql define input:storage ""
          insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
           `iri(?:lstiri)`
             `iri(bif:sprintf("%s%d", str(rdf:_), ?:ctr))`
               `iri(?:qmid)` };
          -- dbg_obj_princ ('DB.DBA.RDF_QM_ADD_MAPPING_TO_STORAGE: qmid is printed: ', ctr);
          ctr := ctr + 1;
          qmid_is_printed := 1;
        }
      sparql define input:storage ""
      insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
       `iri(?:lstiri)`
         `iri(bif:sprintf("%s%d", str(rdf:_), ?:ctr))`
           `iri(?:id)` };
      ctr := ctr + 1;
    }
  if (not qmid_is_printed)
    {
      sparql define input:storage ""
      insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
       `iri(?:lstiri)`
         `iri(bif:sprintf("%s%d", str(rdf:_), ?:ctr))`
           `iri(?:qmid)` };
      -- dbg_obj_princ ('DB.DBA.RDF_QM_ADD_MAPPING_TO_STORAGE: qmid is printed: ', ctr);
      ctr := ctr + 1;
    }
}
;

create procedure DB.DBA.RDF_QM_DELETE_MAPPING_FROM_STORAGE (in storage varchar, in qmparent varchar, in qmid varchar)
{
  declare graphiri, lstiri varchar;
  declare iris_and_orders any;
  declare ctr integer;
  -- dbg_obj_princ ('DB.DBA.RDF_QM_DELETE_MAPPING_FROM_STORAGE (', storage, qmparent, qmid, ')');
  qmid := iri_to_id (qmid, 0, NULL);
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  if (qmparent is not null)
    lstiri := (sparql define input:storage ""
      select ?lst where { graph ?:graphiri {
          `iri(?:qmparent)` virtrdf:qmUserSubMaps ?lst } } );
  else
    lstiri := (sparql define input:storage ""
      select ?lst where { graph ?:graphiri {
          `iri(?:storage)` virtrdf:qsUserMaps ?lst } } );
  -- dbg_obj_princ ('DB.DBA.RDF_QM_DELETE_MAPPING_FROM_STORAGE: storage=', storage, ', qmparent=', qmparent, ', lstiri=', lstiri);
  iris_and_orders := (
    select VECTOR_AGG (vector (sub."id", sub."p", sub."ord1"))
    from (
      select sp."id", sp."p", sp."ord1"
      from (
        sparql define input:storage ""
        select ?id ?p
          (bif:coalesce (?ord,
              1000 + bif:aref (
                bif:sprintf_inverse (
                  str(?p),
                  bif:concat (str (rdf:_), "%d"),
                  2),
                0 ) ) ) as ?ord1
        where { graph ?:graphiri {
                `iri(?:lstiri)` ?p ?id .
                filter (! bif:isnull (bif:aref (
                      bif:sprintf_inverse (
                        str(?p),
                        bif:concat (str (rdf:_), "%d"),
                        2),
                      0 ) ) ) .
                optional {?id virtrdf:qmPriorityOrder ?ord} } } ) as sp
      order by 3, 2, 1 ) as sub );
  -- dbg_obj_princ ('DB.DBA.RDF_QM_DELETE_MAPPING_FROM_STORAGE: found ', iris_and_orders);
  foreach (any itm in iris_and_orders) do
    {
      declare id, p varchar;
      id := itm[0];
      p := itm[1];
      sparql define input:storage ""
      delete from graph <http://www.openlinksw.com/schemas/virtrdf#> {
          `iri(?:lstiri)` `iri(?:p)` `iri(?:id)` . };
    }
  ctr := 1;
  foreach (any itm in iris_and_orders) do
    {
      declare id varchar;
      declare ord integer;
      id := itm[0];
      ord := itm[2];
      if (iri_to_id (id, 0, 0) <> qmid)
        {
          sparql define input:storage ""
          insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
             `iri(?:lstiri)`
               `iri(bif:sprintf("%s%d", str(rdf:_), ?:ctr))`
                 `iri(?:id)` . };
          ctr := ctr + 1;
        }
      else
        {
          -- dbg_obj_princ ('DB.DBA.RDF_QM_DELETE_MAPPING_FROM_STORAGE: skipping ', qmid);
          ;
        }
    }
}
;

create procedure DB.DBA.RDF_QM_SET_DEFAULT_MAPPING (in storage varchar, in qmid varchar)
{
  declare graphiri, old_qmid varchar;
  -- dbg_obj_princ ('DB.DBA.RDF_QM_SET_DEFAULT_MAPPING (', storage, qmid, ')');
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  old_qmid := coalesce ((sparql define input:storage ""
      select ?qm where { graph ?:graphiri {
              `iri(?:storage)` virtrdf:qsDefaultMap ?qm } } ) );
  if (old_qmid is not null)
    {
      if (cast (old_qmid as varchar) = cast (qmid as varchar))
        return;
      signal ('22023', 'Quad map storage <' || storage || '> has set a default quad map <' || old_qmid || '>, drop it before adding <' || qmid || '>');
    }
  sparql define input:storage ""
  insert in graph <http://www.openlinksw.com/schemas/virtrdf#> { `iri(?:storage)` virtrdf:qsDefaultMap `iri(?:qmid)` . };
}
;

-----
-- Procedures for graph grabber

--!AWK PUBLIC
create procedure DB.DBA.RDF_FT_INDEX_GRABBED (inout grabbed any, inout options any)
{
  declare grabbed_list any;
  declare grab_ctr, grab_count integer;
  declare g_iri varchar;
  if (not get_keyword ('refresh_free_text', options, 0))
    return;
  g_iri := get_keyword ('get:group-destination', options);
  -- dbg_obj_princ ('DB.DBA.RDF_FT_INDEX_GRABBED () has g_iri = ', g_iri);
  if (isstring (g_iri) and __rdf_obj_ft_rule_count_in_graph (iri_to_id (g_iri)))
    {
      VT_INC_INDEX_DB_DBA_RDF_OBJ();
      return;
    }
  grabbed_list := dict_to_vector (grabbed);
  grab_count := length (grabbed_list);
  for (grab_ctr := 1; grab_ctr < grab_count; grab_ctr := grab_ctr + 2)
    {
      g_iri := grabbed_list[grab_ctr];
      if (isstring (g_iri) and __rdf_obj_ft_rule_count_in_graph (iri_to_id (g_iri)))
        {
          VT_INC_INDEX_DB_DBA_RDF_OBJ();
          return;
        }
    }
}
;

create function DB.DBA.RDF_GRAB_SINGLE (in val any, inout grabbed any, inout env any) returns integer
{
  declare url, get_method, recov varchar;
  declare dest varchar;
  declare opts any;
  -- dbg_obj_princ ('DB.DBA.RDF_GRAB_SINGLE (', val, ',... , ', env, ')');
  {
  whenever sqlstate '*' goto end_of_sponge;
  if (val is null)
    return 0;
  if (isiri_id (val))
    {
      if (val >= min_bnode_iri_id ())
        return 0;
      val := id_to_iri (val);
    }
  if (217 = __tag (val))
    val := cast (val as varchar);
  call (get_keyword ('resolver', env)) (get_keyword ('base_iri', env), val, url, dest, get_method);
  if (url is not null and not dict_get (grabbed, url, 0))
    {
      declare final_dest, final_gdest varchar;
      final_dest := get_keyword ('get:destination', env, dest);
      final_gdest := get_keyword ('get:group-destination', env, dest);
      opts := vector (
        'get:soft', get_keyword_ucase ('get:soft', env, 'soft'),
        'get:refresh', get_keyword_ucase ('get:refresh', env),
        'get:method', get_method,
        'get:destination', final_dest,
        'get:group-destination', final_gdest
	 );
      dict_put (grabbed, url, 1);
      call (get_keyword ('loader', env))(url, opts);
      commit work;
      dict_put (grabbed, url, final_dest);
      -- dbg_obj_princ ('DB.DBA.RDF_GRAB_SINGLE (', val, ',... , ', env, ') has loaded ', url);
      if (get_keyword ('refresh_free_text', env, 0) and
        (__rdf_obj_ft_rule_count_in_graph (iri_to_id (final_dest)) or
          __rdf_obj_ft_rule_count_in_graph (iri_to_id (final_gdest)) ) )
        {
          VT_INC_INDEX_DB_DBA_RDF_OBJ();
          commit work;
        }
      return 1;
    }
  return 0;
  }
end_of_sponge:
  recov := get_keyword_ucase ('get:error-recovery', env);
  if (recov is not null)
    call (recov) (__SQL_STATE, __SQL_MESSAGE);
  return 0;
}
;

create procedure DB.DBA.RDF_GRAB_SINGLE_ASYNC (in val any, in grabbed any, in env any, in counter_limit integer := 1)
{
  -- dbg_obj_princ ('DB.DBA.RDF_GRAB_SINGLE_ASYNC (', val, ', { dict of size ', dict_size (grabbed), ' }, ', env, counter_limit);
  if (dict_size (grabbed) < counter_limit)
    DB.DBA.RDF_GRAB_SINGLE (val, grabbed, vector_concat (vector ('refresh_free_text', 0), env));
}
;

create function DB.DBA.RDF_GRAB_SEEALSO (in subj varchar, in opt_g varchar, inout env any) returns integer
{
  declare grabbed, aq any;
  declare sa_graphs, sa_preds any;
  declare doc_limit integer;
  aq := async_queue (8);
  grabbed := get_keyword ('grabbed', env);
  doc_limit := get_keyword ('doc_limit', env);
  if (dict_size (grabbed) > doc_limit)
    goto out_of_limit;
  sa_preds := get_keyword ('sa_preds', env);
  sa_graphs := get_keyword ('sa_graphs', env);
  -- dbg_obj_princ ('DB.DBA.RDF_GRAB_SEEALSO (', subj, opt_g, ') in graphs ', sa_graphs, ' with preds ', sa_preds);
  foreach (varchar pred in sa_preds) do
    {
      foreach (varchar graph in sa_graphs) do
        {
          for (sparql select ?val where { graph ?:graph { ?:subj ?:pred ?val . filter (isIRI(?val)) } } ) do
            {
              -- dbg_obj_princ ('found {', graph, subj, pred, val, '}');
              if ("val" like 'http://%')
                {
                  -- dbg_obj_princ ('DB.DBA.RDF_GRAB_SEEALSO () aq_request ', vector ("val", '...', env, doc_limit));
                  --DB.DBA.RDF_GRAB_SINGLE_ASYNC ("val", grabbed, env, doc_limit);
                  aq_request (aq, 'DB.DBA.RDF_GRAB_SINGLE_ASYNC', vector ("val", grabbed, env, doc_limit));
                  if (dict_size (grabbed) > doc_limit)
                    goto out_of_limit;
                }
            }
        }
    }
  if (opt_g is not null)
    {
      foreach (varchar pred in sa_preds) do
        {
          for (sparql select ?val where { graph ?:opt_g { ?:subj ?:pred ?val . filter (isIRI(?val)) } } ) do
            {
              -- dbg_obj_princ ('found {', opt_g, subj, pred, val, '}');
              if ("val" like 'http://%')
                {
                  -- dbg_obj_princ ('DB.DBA.RDF_GRAB_SEEALSO () aq_request ', vector ("val", '...', env, doc_limit));
                  --DB.DBA.RDF_GRAB_SINGLE_ASYNC ("val", grabbed, env, doc_limit);
                  aq_request (aq, 'DB.DBA.RDF_GRAB_SINGLE_ASYNC', vector ("val", grabbed, env, doc_limit));
                  if (dict_size (grabbed) > doc_limit)
                    goto out_of_limit;
                }
            }
        }
    }
  if (bit_and (1, get_keyword ('flags', env, 0)))
    {
      if (subj like 'http://%')
        {
          -- dbg_obj_princ ('DB.DBA.RDF_GRAB_SEEALSO () aq_request ', vector (subj, '...', env, doc_limit));
          --DB.DBA.RDF_GRAB_SINGLE_ASYNC (subj, grabbed, env, doc_limit);
          aq_request (aq, 'DB.DBA.RDF_GRAB_SINGLE_ASYNC', vector (subj, grabbed, env, doc_limit));
        }
    }
out_of_limit:
  commit work;
  aq_wait_all (aq);
  DB.DBA.RDF_FT_INDEX_GRABBED (grabbed, env);
  if (dict_size (grabbed) > doc_limit)
    return 1;
  return 0;
}
;

create procedure
DB.DBA.RDF_GRAB (in app_params any, in seed varchar, in iter varchar, in final varchar, in ret_limit integer, in const_iris any, in sa_graphs any, in sa_preds any, in depth integer, in doc_limit integer, in base_iri varchar, in destination varchar, in group_destination varchar, in resolver varchar, in loader varchar, in refresh_free_text integer, in plain_ret integer, in flags integer)
{
  declare rctr, rcount, colcount, iter_ctr integer;
  declare stat, msg varchar;
  declare grab_params, all_params any;
  declare grabbed, metas, rset, aq any;
  -- dbg_obj_princ ('DB.DBA.RDF_GRAB (..., ', ret_limit, const_iris, depth, doc_limit, base_iri, destination, group_destination, resolver, loader, plain_ret, ')');
  grab_params := vector ('sa_graphs', sa_graphs, 'sa_preds', sa_preds,
    'doc_limit', doc_limit, 'base_iri', base_iri,
    'get:destination', destination,
    'get:group-destination', group_destination,
    'resolver', resolver, 'loader', loader,
    'refresh_free_text', refresh_free_text,
    'flags', flags, 'grabbed', dict_new() );
  all_params := vector_concat (vector (grab_params), app_params);
  aq := async_queue (8);
  grabbed := dict_new ();
  foreach (any val in const_iris) do
    {
      -- dbg_obj_princ ('DB.DBA.RDF_GRAB: const IRI', val);
      if (val is not null)
        {
          -- dbg_obj_princ ('DB.DBA.RDF_GRAB () aq_request ', vector (val, '...', grab_params, doc_limit));
          --DB.DBA.RDF_GRAB_SINGLE_ASYNC (val, grabbed, grab_params, doc_limit);
          aq_request (aq, 'DB.DBA.RDF_GRAB_SINGLE_ASYNC', vector (val, grabbed, grab_params, doc_limit));
        }
    }
  commit work;
  aq_wait_all (aq);
  DB.DBA.RDF_FT_INDEX_GRABBED (grabbed, grab_params);
  if (dict_size (grabbed) >= doc_limit)
    goto final_exec;
  for (iter_ctr := 0; iter_ctr <= depth; iter_ctr := iter_ctr + 1)
    {
      declare old_doc_count integer;
      old_doc_count := dict_size (grabbed);
      stat := '00000';
      exec (case (iter_ctr) when 0 then seed else iter end, stat, msg, all_params, __max (ret_limit, doc_limit, 1000), metas, rset);
      if (stat <> '00000')
        signal (stat, msg);
      rcount := length (rset);
      colcount := length (metas[0]);
      -- dbg_obj_princ ('DB.DBA.RDF_GRAB: rset=', rset);
      for (rctr := 0; rctr < rcount; rctr := rctr + 1)
        {
          declare colctr integer;
          for (colctr := 0; colctr < colcount; colctr := colctr + 1)
            {
              declare val any;
              declare dest varchar;
              val := rset[rctr][colctr];
              -- dbg_obj_princ ('DB.DBA.RDF_GRAB (): dynamic IRI aq_request ', vector (val, '...', grab_params, doc_limit));
              --DB.DBA.RDF_GRAB_SINGLE_ASYNC (val, grabbed, grab_params, doc_limit);
              aq_request (aq, 'DB.DBA.RDF_GRAB_SINGLE_ASYNC', vector (val, grabbed, grab_params, doc_limit));
              if (dict_size (grabbed) >= doc_limit)
                goto final_exec;
            }
        }
      commit work;
      aq_wait_all (aq);
      DB.DBA.RDF_FT_INDEX_GRABBED (grabbed, grab_params);
      if (old_doc_count = dict_size (grabbed))
        goto final_exec;
    }

final_exec:
  stat := '00000';
  exec (final, stat, msg, app_params, ret_limit, metas, rset);
  if (stat <> '00000')
    signal (stat, msg);
  if (plain_ret)
    return rset[0][0];
  rcount := length (rset);
  result_names (rset);
  for (rctr := 0; rctr < rcount; rctr := rctr + 1)
    result (rset[rctr]);
}
;

create function DB.DBA.RDF_GRAB_RESOLVER_DEFAULT (in base varchar, in rel_uri varchar, out abs_uri varchar, out dest_uri varchar, out get_method varchar)
{
  declare rel_lattice_pos, base_lattice_pos integer;
  declare lattice_tail varchar;
  if (217 = __tag (rel_uri))
    rel_uri := cast (rel_uri as varchar);
  if (217 = __tag (base))
    base := cast (base as varchar);
  rel_lattice_pos := strrchr (rel_uri, '#');
  lattice_tail := '';
  if (rel_lattice_pos is not null)
    {
      lattice_tail := subseq (rel_uri, rel_lattice_pos);
      rel_uri := subseq (rel_uri, 0, rel_lattice_pos);
    }
  if ((base is not null) and (base <> ''))
    {
      base_lattice_pos := strrchr (cast (base as varchar), '#');
      if (base_lattice_pos is not null)
        {
          if ('' = lattice_tail)
            lattice_tail := subseq (base, base_lattice_pos);
          base := subseq (base, 0, base_lattice_pos);
        }
    }
  else
    base := '';
  if (base = '')
    abs_uri := rel_uri;
  else
    abs_uri := XML_URI_RESOLVE_LIKE_GET (base, rel_uri);
  dest_uri := abs_uri;
  if (abs_uri like '%/')
    get_method := 'MGET';
  else
    get_method := 'GET';
  -- dbg_obj_princ ('DB.DBA.RDF_GRAB_RESOLVER_DEFAULT (', base, rel_uri, ', ...) sets ', abs_uri, dest_uri, get_method);
}
;



-----
-- Procedures to execute local SPARQL statements (obsolete, now SPARQL can be simply inlined in SQL)

create procedure DB.DBA.SPARQL_EVAL_TO_ARRAY (in query varchar, in dflt_graph varchar, in maxrows integer)
{
  declare state, msg varchar;
  declare metas, rset any;
  if (dflt_graph is not null)
    query := concat ('sparql define input:default-graph-uri <', dflt_graph, '> ', query);
  else
    query := concat ('sparql ', query);
  state := '00000';
  metas := null;
  rset := null;
  exec (query, state, msg, vector(), maxrows, metas, rset);
  -- dbg_obj_princ ('exec metas=', metas);
  if (state <> '00000')
    signal (state, msg);
  return rset;
}
;

create procedure DB.DBA.SPARQL_EVAL (in query varchar, in dflt_graph varchar, in maxrows integer)
{
  declare sqltext, state, msg varchar;
  declare metas, rset any;
  if (dflt_graph is not null)
    query := concat ('sparql define input:default-graph-uri <', dflt_graph, '> ', query);
  else
    query := concat ('sparql ', query);
  state := '00000';
  metas := null;
  rset := null;
  exec (query, state, msg, vector(), maxrows, metas, rset);
  if (state <> '00000')
    signal (state, msg);
  -- dbg_obj_princ ('exec metas=', metas);
  exec_result_names (metas[0]);
  foreach (any row in rset) do
    {
      exec_result (row);
    }
}
;


-----
-- SPARQL protocol client, i.e., procedures to execute remote SPARQL statements.

create procedure DB.DBA.SPARQL_REXEC_INT (
  in res_mode integer,
  in service varchar,
  in query varchar,
  in dflt_graph varchar,
  inout named_graphs any,
  inout req_hdr any,
  in maxrows integer,
  inout metas any,
  inout bnode_dict any
  )
{
  declare req_uri, req_method, req_body, local_req_hdr, ret_body, ret_hdr any;
  declare ret_content_type varchar;
  req_body := string_output();
  http ('query=', req_body);
  http_url (query, 0, req_body);
  if (dflt_graph is not null and dflt_graph <> '')
    {
      http ('&default-graph-uri=', req_body);
      http_url (dflt_graph, 0, req_body);
    }
  foreach (varchar uri in named_graphs) do
    {
      http ('&named-graph-uri=', req_body);
      http_url (uri, 0, req_body);
    }
  if (maxrows is not null)
    http (sprintf ('&maxrows=%d', maxrows), req_body);
  req_body := string_output_string (req_body);
  local_req_hdr := 'Accept: application/sparql-results+xml, text/rdf+n3, text/rdf+ttl, application/turtle, application/x-turtle, application/rdf+xml, application/xml';
  if (length (req_body) + length (service) >= 1900)
    {
      req_method := 'POST';
      req_uri := service;
      local_req_hdr := local_req_hdr || '\r\nContent-Type: application/x-www-form-urlencoded';
    }
  else
    {
      req_method := 'GET';
      req_uri := service || '?' || req_body;
      req_body := '';
    }
  if (length (req_hdr) > 0)
    req_hdr := concat (req_hdr, '\r\n', local_req_hdr );
  else
    req_hdr := local_req_hdr;
  -- dbg_obj_princ ('Request: ', req_method, req_uri);
  -- dbg_obj_princ ('Request: ', req_hdr);
  -- dbg_obj_princ ('Request: ', req_body);
  ret_body := http_get (req_uri, ret_hdr, req_method, req_hdr, req_body);
  -- dbg_obj_princ ('Returned header: ', ret_hdr);
  -- dbg_obj_princ ('Returned body: ', ret_body);
  ret_content_type := http_request_header (ret_hdr, 'Content-Type', null, null);
  if (ret_content_type is null or
    (strstr (ret_content_type, 'application/sparql-results+xml') is null and
      strstr (ret_content_type, 'application/rdf+xml') is null and
      strstr (ret_content_type, 'text/rdf+n3') is null and
      strstr (ret_content_type, 'text/rdf+ttl') is null and
      strstr (ret_content_type, 'application/turtle' ) is null and
      strstr (ret_content_type, 'application/x-turtle' ) is null ) )
    {
      declare ret_begin, ret_html any;
      ret_begin := "LEFT" (ret_body, 1024);
      ret_html := xtree_doc (ret_begin, 2);
      if (xpath_eval ('/html|/xhtml', ret_html) is not null)
        ret_content_type := 'text/html';
      else if (xpath_eval ('[xmlns:rset="http://www.w3.org/2005/sparql-results#"] /rset:sparql', ret_html) is not null
            or xpath_eval ('[xmlns:rset2="http://www.w3.org/2001/sw/DataAccess/rf1/result2"] /rset2:sparql', ret_html) is not null)
        ret_content_type := 'application/sparql-results+xml';
      else if (xpath_eval ('[xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"] /rdf:rdf', ret_html) is not null)
        ret_content_type := 'application/rdf+xml';
      else if (strstr (ret_begin, '<html>') is not null or
        strstr (ret_begin, '<xhtml>') is not null )
        ret_content_type := 'text/html';
      else
        {
          ret_content_type := 'text/plain';
        }
    }
  if (strstr (ret_content_type, 'application/sparql-results+xml') is not null)
    {
      declare ret_xml, var_list, var_metas, ret_row, out_nulls any;
      declare var_ctr, var_count integer;
      declare vect_acc any;
      declare row_inx integer;
       -- dbg_obj_princ ('application/sparql-results+xml ret_body=', ret_body);
      ret_xml := xtree_doc (ret_body, 0);
      var_list := xpath_eval ('[xmlns:rset="http://www.w3.org/2005/sparql-results#"] [xmlns:rset2="http://www.w3.org/2001/sw/DataAccess/rf1/result2"]
                               /rset:sparql/rset:head/rset:variable | /rset2:sparql/rset2:head/rset2:variable', ret_xml, 0);
      if (0 = length (var_list))
        {
	  declare bool_ret any;
          bool_ret := xpath_eval ('[xmlns:rset="http://www.w3.org/2005/sparql-results#"] [xmlns:rset2="http://www.w3.org/2001/sw/DataAccess/rf1/result2"]
                                   /rset:sparql/rset:boolean | /rset2:sparql/rset2:boolean', ret_xml);
	  if (bool_ret is not null)
	    {
	      bool_ret := cast (bool_ret as varchar);
	      if ('true' = bool_ret)
	        bool_ret := 1;
	      else if ('false' = bool_ret)
	        bool_ret := 0;
	      else
                signal ('RDFZZ', sprintf (
                    'DB.DBA.SPARQL_REXEC(''%.300s'', ...) has received invalid boolean value ''%.300s''',
                    service, bool_ret ) );
              metas :=
	        vector (
		  vector (
	            vector ('__ask_retval', 242, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0) ),
		  1 );
              if (0 = res_mode)
	        {
		  declare __ask_retval integer;
		  result_names (__ask_retval);
		  result (bool_ret);
		}
              else if (1 = res_mode)
	        return vector (vector (bool_ret));
	      return;
	    }
          signal ('RDFZZ', sprintf (
            'DB.DBA.SPARQL_REXEC(''%.300s'', ...) has received result with no variables',
	    service ) );
	}
      var_count := length (var_list);
      var_metas := make_array (var_count, 'any');
      out_nulls := make_array (var_count, 'any');
      for (var_ctr := var_count - 1; var_ctr >= 0; var_ctr := var_ctr - 1)
        {
          declare var_name varchar;
          var_name := cast (xpath_eval ('@name', var_list[var_ctr]) as varchar);
          var_list [var_ctr] := var_name;
          var_metas [var_ctr] := vector (var_name, 242, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0);
          out_nulls [var_ctr] := null;
        }
      -- dbg_obj_princ ('var_metas=', var_metas);
      if (0 = res_mode)
        exec_result_names (var_metas);
      else if (1 = res_mode)
        vectorbld_init (vect_acc);
      row_inx := 0;
      for (ret_row := xpath_eval ('[xmlns:rset="http://www.w3.org/2005/sparql-results#"] [xmlns:rset2="http://www.w3.org/2001/sw/DataAccess/rf1/result2"]
                                   /rset:sparql/rset:results/rset:result | /rset2:sparql/rset2:results/rset2:result', ret_xml);
        ret_row is not null;
        ret_row := xpath_eval ('[xmlns:rset="http://www.w3.org/2005/sparql-results#"] [xmlns:rset2="http://www.w3.org/2001/sw/DataAccess/rf1/result2"]
                                following-sibling::rset:result | following-sibling::rset2:result', ret_row) )
        {
          declare out_fields, ret_cols any;
          declare col_ctr, col_count integer;
          out_fields := out_nulls;
          ret_cols := xpath_eval ('[xmlns:rset="http://www.w3.org/2005/sparql-results#"] [xmlns:rset2="http://www.w3.org/2001/sw/DataAccess/rf1/result2"]
                                   rset:binding | rset2:binding', ret_row, 0);
          col_count := length (ret_cols);
          for (col_ctr := col_count - 1; col_ctr >= 0; col_ctr := col_ctr - 1)
            {
              declare ret_col any;
              declare var_name, var_type, var_strval varchar;
              declare var_pos integer;
              ret_col := ret_cols[col_ctr];
              var_name := cast (xpath_eval ('string(@name)', ret_col) as varchar);
              -- dbg_obj_princ ('var_name=', var_name);
              var_pos := position (var_name, var_list) - 1;
              if (var_pos >= 0)
                {
                  var_type := cast (xpath_eval ('local-name(*)', ret_col) as varchar);
                  var_strval := charset_recode (xpath_eval ('string(*)', ret_col), '_WIDE_', 'UTF-8');
                  -- dbg_obj_princ ('var_type=', var_type);
                  if ('uri' = var_type)
                    out_fields [var_pos] := DB.DBA.RDF_MAKE_IID_OF_QNAME (var_strval);
                  else if ('bnode' = var_type)
                    {
                      declare local_iid IRI_ID;
                      if (bnode_dict is null)
                        {
                          bnode_dict := dict_new ();
                          local_iid := iri_id_from_num (sequence_next ('RDF_URL_IID_BLANK'));
                          dict_put (bnode_dict, var_strval, local_iid);
                        }
                      else
                        {
                          local_iid := dict_get (bnode_dict, var_strval, null);
                          if (local_iid is null)
                            {
                              local_iid := iri_id_from_num (sequence_next ('RDF_URL_IID_BLANK'));
                              dict_put (bnode_dict, var_strval, local_iid);
                            }
                        }
                      out_fields [var_pos] := local_iid;
                    }
                  else if ('literal' = var_type)
                    {
                      declare lang, dt varchar;
                      lang := charset_recode (xpath_eval ('*/@xml:lang', ret_col), '_WIDE_', 'UTF-8');
                      dt := charset_recode (xpath_eval ('*/@datatype', ret_col), '_WIDE_', 'UTF-8');
                      out_fields [var_pos] := DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL_STRINGS (
                        var_strval, dt, lang );
                    }
                  else
                    signal ('RDFZZ', sprintf (
                        'DB.DBA.SPARQL_REXEC(''%.300s'', ...) contains unsupported type of bound value ''%.300s''',
                        service, var_type ) );
                }
            }
          if (0 = res_mode)
            exec_result (out_fields);
          else if (1 = res_mode)
            vectorbld_acc (vect_acc, out_fields);
          row_inx := row_inx + 1;
          if (maxrows is not null and maxrows > 0 and row_inx >= maxrows)
            ret_row := xpath_eval ('[xmlns:rset="http://www.w3.org/2005/sparql-results#"] [xmlns:rset2="http://www.w3.org/2001/sw/DataAccess/rf1/result2"]
                                    ../rset:result[position() = last()] | ../rset2:result[position() = last()]', ret_row);
        }
      metas := vector (var_metas, 1);
      if (0 = res_mode)
        {
          return;
        }
      else if (1 = res_mode)
        {
          vectorbld_final (vect_acc);
          return vect_acc;
        }
    }
  if (strstr (ret_content_type, 'application/rdf+xml') is not null)
    {
      declare res_dict any;
      res_dict := DB.DBA.RDF_RDFXML_TO_DICT (ret_body,'http://local.virt/tmp','http://local.virt/tmp');
      metas := vector (vector (vector ('res_dict', 242, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0)), 1);
      if (0 = res_mode)
        {
          result_names (res_dict);
          result (res_dict);
          return;
        }
      else if (1 = res_mode)
        return vector (vector (res_dict));
    }
  if (strstr (ret_content_type, 'text/rdf+n3') is not null or
    strstr (ret_content_type, 'text/rdf+ttl') is not null or
    strstr (ret_content_type, 'application/turtle') is not null or
    strstr (ret_content_type, 'application/x-turtle') is not null )
    {
      declare res_dict any;
      res_dict := DB.DBA.RDF_TTL2HASH (ret_body, '');
      metas := vector (vector (vector ('res_dict', 242, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0)), 1);
      if (0 = res_mode)
        {
          result_names (res_dict);
          result (res_dict);
          return;
        }
      else if (1 = res_mode)
        return vector (vector (res_dict));
    }
  if (strstr (ret_content_type, 'text/plain') is not null)
    {
      signal ('RDFZZ', sprintf (
          'DB.DBA.SPARQL_REXEC(''%.300s'', ...) returned Content-Type ''%.300s'' status ''%.300s''\n%.1000s',
          service, ret_content_type, ret_hdr[0], "LEFT" (ret_body, 1024) ) );
    }
  if (strstr (ret_content_type, 'text/html') is not null)
    {
      signal ('RDFZZ', sprintf (
          'DB.DBA.SPARQL_REXEC(''%.300s'', ...) returned Content-Type ''%.300s'' status ''%.300s''\n%.1000s',
          service, ret_content_type, ret_hdr[0],
	  cast (xtree_doc (ret_body, 2) as varchar) ) );
    }
  signal ('RDFZZ', sprintf (
      'DB.DBA.SPARQL_REXEC(''%.300s'', ...) returned unsupported Content-Type ''%.300s''',
      service, ret_content_type ) );
}
;

create procedure DB.DBA.SPARQL_REXEC (
  in service varchar,
  in query varchar,
  in dflt_graph varchar,
  in named_graphs any,
  in req_hdr any,
  in maxrows integer,
  in bnode_dict any
  )
{
  declare metas any;
  DB.DBA.SPARQL_REXEC_INT (0, service, query, dflt_graph, named_graphs, req_hdr, maxrows, metas, bnode_dict);
}
;

create function DB.DBA.SPARQL_REXEC_TO_ARRAY (
  in service varchar,
  in query varchar,
  in dflt_graph varchar,
  in named_graphs any,
  in req_hdr any,
  in maxrows integer,
  in bnode_dict any
  ) returns any
{
  declare metas any;
  return DB.DBA.SPARQL_REXEC_INT (1, service, query, dflt_graph, named_graphs, req_hdr, maxrows, metas, bnode_dict);
}
;

create procedure DB.DBA.SPARQL_REXEC_WITH_META (
  in service varchar,
  in query varchar,
  in dflt_graph varchar,
  in named_graphs any,
  in req_hdr any,
  in maxrows integer,
  in bnode_dict any,
  out metadata any,
  out resultset any
  )
{
  resultset := DB.DBA.SPARQL_REXEC_INT (1, service, query, dflt_graph, named_graphs, req_hdr, maxrows, metadata, bnode_dict);
  -- dbg_obj_princ ('DB.DBA.SPARQL_REXEC_WITH_META (): metadata = ', metadata, ' resultset = ', resultset);
}
;


-----
-- SPARQL SOAP web service (incomplete, do not try to use in applications!)

create procedure "querySoap"  (in  "Command" varchar
	    , in  "Properties" any
	    , out "Error" any __soap_fault '__XML__'
	    , out "ws_sparql_xsd" any
	   )
	__soap_options ( __soap_type:='__ANY__',
                 "soapAction":='urn:FIXME:querySoap',
                 "RequestNamespace":='urn:http://www.w3.org/2005/08/sparql-protocol-query/#',
                 "ResponseNamespace":='urn:http://www.w3.org/2005/08/sparql-protocol-query/#',
                 "PartName":='return'
	       )
{
   declare stmt, state, msg, mdta, dta, res, ses any;
   stmt := get_keyword ('Statement', "Command");
   ses := string_output ();

   -- dbg_obj_princ ('Statement to be executed by querySoap: ', stmt);
   res := exec (stmt, state, msg, vector (), 0, mdta, dta);

   SPARQL_RESULTS_XML_WRITE_NS (ses);
   SPARQL_RESULTS_XML_WRITE_HEAD (ses, mdta);
   SPARQL_RESULTS_XML_WRITE_RES (ses, mdta, dta);

   -- dbg_obj_princ (mdta);
   http ('</sparql>', ses);

   ses := string_output_string (ses);
   string_to_file ('out.xml', ses, -2);
   res := xml_tree_doc (ses);
   return res;
}
;

create procedure SPARQL_RESULTS_XML_WRITE_NS (inout ses any)
{
  http ('<?xml version="1.0" ?>\n<sparql xmlns="http://www.w3.org/2005/sparql-results#" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.w3.org/2001/sw/DataAccess/rf1/result2.xsd">', ses);
}
;

create procedure SPARQL_RESULTS_XML_WRITE_HEAD (inout ses any, in mdta any)
{
  declare i, col_count integer;

  http ('\n <head>', ses);

  mdta := mdta[0];
  i := 0; col_count := length (mdta);
  while (i < col_count)
    {
      declare _name varchar;
      declare _type, _type_name, nill int;
      _name := mdta[i][0];
      _type := mdta[i][1];
      if (length (mdta[i]) > 4)
        nill := mdta[i][4];
      else
        nill := 0;
      http (sprintf ('\n  <variable name="%s"/>', _name), ses);
      i := i + 1;
    }
--  http (sprintf ('<link href="%s" />', 'FIX_ME'), ses);
  http ('\n </head>', ses);
}
;

create procedure SPARQL_RESULTS_XML_WRITE_RES (inout ses any, in mdta any, inout dta any)
{
  http ('\n <results distinct="false" ordered="true">', ses);

  for (declare ctr integer, ctr := 0; ctr < length (dta); ctr := ctr + 1)
      SPARQL_RESULTS_XML_WRITE_ROW (ses, mdta, dta[ctr]);

  http ('\n </results>', ses);
}
;

create procedure DB.DBA.SPARQL_RESULTS_XML_WRITE_ROW (inout ses any, in mdta any, inout dta any)
{
  -- dbg_obj_princ ('DB.DBA.SPARQL_RESULTS_XML_WRITE_ROW (..., ',mdta, dta, ')');
  http ('\n  <result>', ses);
  mdta := mdta[0];
  for (declare x any, x := 0; x < length (mdta); x := x + 1)
    {
      declare _name varchar;
      declare _val any;
      _name := mdta[x][0];
      _val := dta[x];
      if (_val is null)
        goto end_of_binding;
      if (isstring (_val) and (1 = __box_flags (_val)))
        _val := iri_to_id (_val);
      if (isiri_id (_val))
        {
          if (_val >= min_bnode_iri_id ())
	    {
	      http (sprintf ('\n   <binding name="%s"><bnode>%s</bnode></binding>', _name, id_to_iri (_val)), ses);
	    }
	  else
	    {
              declare res varchar;
              res := id_to_iri (_val);
--              res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = _val));
              if (res is null)
                res := sprintf ('bad://%d', iri_id_num (_val));
              http (sprintf ('\n   <binding name="%s"><uri>', _name), ses);
              http_value (res, 0, ses);
              http ('</uri></binding>', ses);
	    }
	}
      else
        {
	  declare lang, dt varchar;
	  declare is_xml_lit int;
	  declare sql_val any;
	  if (__tag (_val) = 185) -- string output
	    {
              http (sprintf ('\n   <binding name="%s"><literal>', _name), ses);
	      http_value (_val, 0, ses);
              http ('</literal></binding>', ses);
              goto end_of_binding;
	    }
	  lang := DB.DBA.RDF_LANGUAGE_OF_LONG (_val, null);
	  dt := DB.DBA.RDF_DATATYPE_IRI_OF_LONG (_val, null);
	  if (dt = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral')
	    is_xml_lit := 1;
	  else
            is_xml_lit := 0;
	  if (lang is not null)
	    {
	      if (dt is not null)
                http (sprintf ('\n   <binding name="%s"><literal xml:lang="%V" datatype="%V">',
		    _name, cast (lang as varchar), cast (dt as varchar)), ses);
	      else
                http (sprintf ('\n   <binding name="%s"><literal xml:lang="%V">',
		    _name, cast (lang as varchar)), ses);
	    }
	  else
	    {
	      if (dt is not null)
                http (sprintf ('\n   <binding name="%s"><literal datatype="%V">',
		    _name, cast (dt as varchar)), ses);
	      else
                http (sprintf ('\n   <binding name="%s"><literal>',
		    _name), ses);
	    }
	  sql_val := __rdf_sqlval_of_obj (_val, 1);
	  if (isentity (sql_val))
	    is_xml_lit := 1;
	  if (__tag (sql_val) = __tag of varchar) -- UTF-8 value kept in a DV_STRING box
	    sql_val := charset_recode (sql_val, 'UTF-8', '_WIDE_');
	  if (is_xml_lit) http ('<![CDATA[', ses);
	  http_value (sql_val, 0, ses);
	  if (is_xml_lit) http (']]>', ses);
          http ('</literal></binding>', ses);
        }
end_of_binding: ;
    }

  http ('\n  </result>', ses);
}
;

create procedure SPARQL_RESULTS_RDFXML_WRITE_NS (inout ses any)
{
  http ('<rdf:RDF xmlns:res="http://www.w3.org/2005/sparql-results#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
  <rdf:Description rdf:nodeID="rset">
    <rdf:type rdf:resource="http://www.w3.org/2005/sparql-results#ResultSet" />', ses);
}
;

create procedure SPARQL_RESULTS_RDFXML_WRITE_HEAD (inout ses any, in mdta any)
{
  declare i, col_count integer;
  mdta := mdta[0];
  i := 0; col_count := length (mdta);
  while (i < col_count)
    {
      declare _name varchar;
      declare _type, _type_name, nill int;
      _name := mdta[i][0];
      _type := mdta[i][1];
      if (length (mdta[i]) > 4)
        nill := mdta[i][4];
      else
        nill := 0;
      http (sprintf ('\n    <res:resultVariable>%V</res:resultVariable>', _name), ses);
      i := i + 1;
    }
}
;

create procedure SPARQL_RESULTS_RDFXML_WRITE_RES (inout ses any, in mdta any, inout dta any)
{
  for (declare ctr integer, ctr := 0; ctr < length (dta); ctr := ctr + 1)
    {
      http ( sprintf ('\n    <res:solution rdf:nodeID="r%d">', ctr), ses);
      SPARQL_RESULTS_RDFXML_WRITE_ROW (ses, mdta, dta, ctr);
      http ('\n    </res:solution>', ses);
    }
}
;

create procedure SPARQL_RESULTS_RDFXML_WRITE_ROW (inout ses any, in mdta any, inout dta any, in rowno integer)
{
  mdta := mdta[0];
  for (declare x any, x := 0; x < length (mdta); x := x + 1)
    {
      declare _name varchar;
      declare _val any;
      _name := mdta[x][0];
      _val := dta[rowno][x];
      if (_val is null)
        goto end_of_binding;
      if (isstring (_val) and (1 = __box_flags (_val)))
        _val := iri_to_id (_val);
      http (sprintf ('\n      <res:binding rdf:nodeID="r%dc%d"><res:variable>%V</res:variable><res:value', rowno, x, _name), ses);
      if (isiri_id (_val))
        {
          if (_val >= min_bnode_iri_id ())
	    {
	      http (sprintf (' rdf:nodeID="%s"/></res:binding>', id_to_iri (_val)), ses);
	    }
	  else
	    {
              declare res varchar;
              res := id_to_iri (_val);
--              res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = _val));
              if (res is null)
                res := sprintf ('bad://%d', iri_id_num (_val));
              http (sprintf (' rdf:resource="%V"/></res:binding>', res), ses);
	    }
	}
      else
        {
	  declare lang, dt varchar;
	  if (__tag (_val) = 185) -- string output
	    {
              http ('>', ses);
	      http_value (_val, 0, ses);
              http ('</res:value></res:binding>', ses);
              goto end_of_binding;
	    }
	  lang := DB.DBA.RDF_LANGUAGE_OF_LONG (_val, null);
	  dt := DB.DBA.RDF_DATATYPE_IRI_OF_LONG (_val, null);
	  if (lang is not null)
	    {
	      if (dt is not null)
                http (sprintf (' xml:lang="%V" datatype="%V">', cast (lang as varchar), cast (dt as varchar)), ses);
	      else
                http (sprintf (' xml:lang="%V">', cast (lang as varchar)), ses);
	    }
	  else
	    {
	      if (dt is not null)
                http (sprintf (' datatype="%V">', cast (dt as varchar)), ses);
	      else
                http ('>', ses);
	    }
          if (__tag of datetime = rdf_box_data_tag (_val))
            __rdf_long_to_ttl (_val, ses);
          else
	    {
	      _val := __rdf_sqlval_of_obj (_val, 1);
	      if (__tag (_val) = __tag of varchar) -- UTF-8 value kept in a DV_STRING box
		_val := charset_recode (_val, 'UTF-8', '_WIDE_');
	      http_value (_val, 0, ses);
	    }
          http ('</res:value></res:binding>', ses);
        }
end_of_binding: ;
    }
}
;

create procedure SPARQL_RESULTS_TTL_WRITE_NS (inout ses any)
{
  http ('@prefix res: <http://www.w3.org/2005/sparql-results#> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
[] rdf:type res:ResultSet ;', ses);
}
;

create procedure SPARQL_RESULTS_TTL_WRITE_HEAD (inout ses any, in mdta any)
{
  declare i, col_count integer;
  mdta := mdta[0];
  i := 0; col_count := length (mdta);
  while (i < col_count)
    {
      declare _name varchar;
      declare _type, _type_name, nill int;
      _name := mdta[i][0];
      _type := mdta[i][1];
      if (length (mdta[i]) > 4)
        nill := mdta[i][4];
      else
        nill := 0;
      http ('\n  res:resultVariable "', ses);
      http_escape (_name, 11, ses, 0, 1);
      http ('"', ses);
      i := i + 1;
      if (i < col_count)
        http (' ;', ses);
    }
}
;

create procedure SPARQL_RESULTS_TTL_WRITE_RES (inout ses any, in mdta any, inout dta any)
{
  declare ctr, len integer;
  ctr := 0; len := length (dta);
  while (ctr < len)
    {
      http ('\n  res:solution [', ses);
      SPARQL_RESULTS_TTL_WRITE_ROW (ses, mdta, dta, ctr);
      http (' ]', ses);
      ctr := ctr + 1;
      if (ctr < len)
        http (' ;', ses);
    }
}
;

create procedure SPARQL_RESULTS_TTL_WRITE_ROW (inout ses any, in mdta any, inout dta any, in rowno integer)
{
  declare need_semicolon integer;
  mdta := mdta[0];
  need_semicolon := 0;
  for (declare x any, x := 0; x < length (mdta); x := x + 1)
    {
      declare _name varchar;
      declare _val any;
      _name := mdta[x][0];
      _val := dta[rowno][x];
      if (_val is not null)
        {
          if (need_semicolon)
            http (' ;', ses);
          else
            need_semicolon := 1;
          http ('\n      res:binding [ res:variable "', ses);
          http_escape (_name, 11, ses, 0, 1);
          http ('" ; res:value ', ses);
          DB.DBA.RDF_LONG_TO_TTL (_val, ses);
          http (' ]', ses);
        }
    }
}
;

create procedure SPARQL_RESULTS_JAVASCRIPT_HTML_WRITE (inout ses any, inout metas any, inout rset any, in is_js integer := 0, in esc_mode integer := 1)
{
  declare varctr, varcount, resctr, rescount integer;
  varcount := length (metas[0]);
  rescount := length (rset);
  if (is_js)
    {
      http ('document.writeln(''', ses);
      SPARQL_RESULTS_JAVASCRIPT_HTML_WRITE(ses,metas,rset,0,13);
      http (''');', ses);
      return;
   }
  http ('<table class="sparql" border="1">', ses);
  http ('\n  <tr>', ses);
  --http ('\n    <th>Row</th>', ses);
  for (varctr := 0; varctr < varcount; varctr := varctr + 1)
    {
      http('\n    <th>', ses);
      http_escape (metas[0][varctr][0], esc_mode, ses, 0, 1);
      http('</th>', ses);
    }
  http ('\n  </tr>', ses);
  for (resctr := 0; resctr < rescount; resctr := resctr + 1)
    {
      http('\n  <tr>', ses);
      --http('\n    <td>', ses);
      --http(cast((resctr + 1) as varchar), ses);
      --http('</td>', ses);
      for (varctr := 0; varctr < varcount; varctr := varctr + 1)
        {
          declare val any;
          val := rset[resctr][varctr];
          if (val is null)
            {
              http('\n    <td></td>', ses);
              goto end_of_val_print; -- see below
            }
          http('\n    <td>', ses);
          if (isiri_id (val))
            {
              http_escape (id_to_iri (val), esc_mode, ses, 0, 1);
            }
          else if (__tag of varchar = __tag (val))
            {
              http_escape (val, esc_mode, ses, 1, 1);
            }
	  else if (185 = __tag (val)) -- string output
	    {
              http_escape (cast (val as varchar), esc_mode, ses, 1, 1);
	    }
	  else if (__tag of XML = rdf_box_data_tag (val)) -- string output
	    {
              http (DB.DBA.RDF_STRSQLVAL_OF_LONG (val), ses);
	    }
          else
            {
              http_escape (DB.DBA.RDF_STRSQLVAL_OF_LONG (val), esc_mode, ses, 1, 1);
            }
          http ('</td>', ses);
end_of_val_print: ;
        }
      http('\n  </tr>', ses);
    }
  http ('\n</table>', ses);
}
;

create procedure SPARQL_RESULTS_JSON_WRITE (inout ses any, inout metas any, inout rset any)
{
  declare varctr, varcount, resctr, rescount integer;
  varcount := length (metas[0]);
  rescount := length (rset);
  http ('\n{ "head": { "link": [], "vars": [', ses);
  for (varctr := 0; varctr < varcount; varctr := varctr + 1)
    {
      if (varctr > 0)
        http(', "', ses);
      else
        http('"', ses);
      http_escape (metas[0][varctr][0], 11, ses, 0, 1);
      http('"', ses);
    }
  http ('] },\n  "results": { "distinct": false, "ordered": true, "bindings": [', ses);
  for (resctr := 0; resctr < rescount; resctr := resctr + 1)
    {
      declare need_comma integer;
      if (resctr > 0)
        http(',\n    {', ses);
      else
        http('\n    {', ses);
      need_comma := 0;
      for (varctr := 0; varctr < varcount; varctr := varctr + 1)
        {
          declare val any;
          val := rset[resctr][varctr];
          if (val is null)
            goto end_of_val_print; -- see below
          if (need_comma)
            http('\t, "', ses);
          else
            {
              http(' "', ses);
              need_comma := 1;
            }
          http_escape (metas[0][varctr][0], 11, ses, 0, 1);
          http('": { ', ses);
          if (isiri_id (val))
            {
              if (val > min_bnode_iri_id ())
                http (sprintf ('"type": "bnode", "value": "%s', id_to_iri (val)), ses);
              else
                {
                  http ('"type": "uri", "value": "', ses);
                  http_escape (id_to_iri (val), 11, ses, 0, 1);
                }
            }
          else if (__tag of rdf_box = __tag (val))
            {
              declare res varchar;
              declare dat, typ any;
              dat := __rdf_sqlval_of_obj (val, 1);
              typ := rdf_box_type (val);
              if (not isstring (dat))
                {
                  http ('"type": "typed-literal", "datatype": "', ses);
                  if (257 <> typ)
                    res := coalesce ((select RDT_QNAME from DB.DBA.RDF_DATATYPE where RDT_TWOBYTE = typ));
                  else
                    res := cast (__xsd_type (dat) as varchar);
                  http_escape (res, 11, ses, 1, 1);
                  http ('", "value": "', ses);
                  dat := DB.DBA.RDF_STRSQLVAL_OF_SQLVAL (dat);
                }
              else if (257 <> typ)
                {
                  http ('"type": "typed-literal", "datatype": "', ses);
                  res := coalesce ((select RDT_QNAME from DB.DBA.RDF_DATATYPE where RDT_TWOBYTE = typ));
                  http_escape (res, 11, ses, 1, 1);
                  http ('", "value": "', ses);
                }
              else if (257 <> rdf_box_lang (val))
                {
                  http ('"type": "literal", "xml:lang": "', ses);
                  res := coalesce ((select lower (RL_ID) from DB.DBA.RDF_LANGUAGE where RL_TWOBYTE = rdf_box_lang (val)));
                  http_escape (res, 11, ses, 1, 1);
                  http ('", "value": "', ses);
                }
              else
                http ('"type": "literal", "value": "', ses);
              http_escape (dat, 11, ses, 1, 1);
            }
          else if (__tag of varchar = __tag (val))
            {
              http ('"type": "literal", "value": "', ses);
              http_escape (val, 11, ses, 1, 1);
            }
          else if (__tag of varbinary = __tag (val))
            {
              http ('"type": "literal", "value": "', ses);
              http_escape (val, 11, ses, 0, 0);
            }
          else if (185 = __tag (val))
            {
              http ('"type": "literal", "value": "', ses);
              http_escape (cast (val as varchar), 11, ses, 1, 1);
            }
          else
            {
              http ('"type": "typed-literal", "datatype": "', ses);
              http_escape (cast (__xsd_type (val) as varchar), 11, ses, 1, 1);
              http ('", "value": "', ses);
              http_escape (DB.DBA.RDF_STRSQLVAL_OF_LONG (val), 11, ses, 1, 1);
            }
          http ('" }', ses);

end_of_val_print: ;
        }
      http('}', ses);
    }
  http (' ] } }', ses);
}
;

create function DB.DBA.SPARQL_RESULTS_WRITE (inout ses any, inout metas any, inout rset any, in accept varchar, in add_http_headers integer) returns varchar
{
  declare singlefield varchar;
  declare ret_mime varchar;
  if ((1 >= length (rset)) and (1 = length (metas[0])))
    singlefield := metas[0][0][0];
  else
    singlefield := NULL;
  -- dbg_obj_princ ('DB.DBA.SPARQL_RESULTS_WRITE: length(rset) = ', length(rset), ' metas=', metas, ' singlefield=', singlefield);
  if ('__ask_retval' = singlefield)
    {
      if (strstr (accept, 'application/sparql-results+json') is not null or strstr (accept, 'application/json') is not null)
        {
          if (strstr (accept, 'application/sparql-results+json') is not null)
            ret_mime := 'application/sparql-results+json';
          else
            ret_mime := 'application/json';
          http (
            concat (
              '{  "head": { "link": [] }, "boolean": ',
              case (length (rset)) when 0 then 'false' else 'true' end,
              '}'),
            ses );
        }
      else
        {
          ret_mime := 'application/sparql-results+xml';
          SPARQL_RESULTS_XML_WRITE_NS (ses);
          http (
            concat (
              '\n <head></head>\n <boolean>',
              case (length (rset)) when 0 then 'false' else 'true' end,
              '</boolean>\n</sparql>'),
            ses );
        }
      goto body_complete;
    }
  if ((1 = length (rset)) and
    (1 = length (rset[0])) and
    (214 = __tag (rset[0][0])) )
    {
      declare triples any;
      triples := dict_list_keys (rset[0][0], 1);
      if (
        strstr (accept, 'text/rdf+n3') is not null or
        strstr (accept, 'text/rdf+ttl') is not null or
        strstr (accept, 'application/turtle') is not null or
        strstr (accept, 'application/x-turtle') is not null or
        (accept = 'auto') )
        {
          if (strstr (accept, 'text/rdf+n3') is not null)
            ret_mime := 'text/rdf+n3';
          else if (strstr (accept, 'text/rdf+ttl') is not null)
            ret_mime := 'text/rdf+ttl';
          else if (strstr (accept, 'application/turtle') is not null)
            ret_mime := 'application/turtle';
          else if (strstr (accept, 'application/x-turtle') is not null)
            ret_mime := 'application/x-turtle';
          else
            ret_mime := 'text/rdf+n3';
          DB.DBA.RDF_TRIPLES_TO_TTL (triples, ses);
	}
      else if (strstr (accept, 'application/soap+xml') is not null)
	{
	  declare soap_ns, spt_ns varchar;
	  declare soap_ver int;

	  if (strstr (accept, 'application/soap+xml;11') is not null)
	    soap_ver := 11;
	  else
	    soap_ver := 12;
	  soap_ns := DB.DBA.SPARQL_SOAP_NS (soap_ver);
	  spt_ns := DB.DBA.SPARQL_PT_NS ();
	  if (soap_ver = 12)
	    ret_mime := 'application/soap+xml';
	  else
	    ret_mime := 'text/xml';
	  http ('<soapenv:Envelope xmlns:soapenv="'||soap_ns||'"><soapenv:Body><query-result xmlns="'||spt_ns||'">', ses);
          http ('<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" '||
      			'xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#">', ses);
          DB.DBA.RDF_TRIPLES_TO_RDF_XML_TEXT (triples, 0, ses);
	  http ('</rdf:RDF>', ses);
	  http ('</query-result></soapenv:Body></soapenv:Envelope>', ses);
	  goto body_complete;
	}
      else
        {
          ret_mime := 'application/rdf+xml';
          DB.DBA.RDF_TRIPLES_TO_RDF_XML_TEXT (triples, 1, ses);
        }
      goto body_complete;
    }
  if (strstr (accept, 'application/sparql-results+json') is not null or strstr (accept, 'application/json') is not null)
    {
      if (strstr (accept, 'application/sparql-results+json') is not null)
        ret_mime := 'application/sparql-results+json';
      else
        ret_mime := 'application/json';
      if (('callretRDF/XML-0' = singlefield) or ('callretTURTLE-0' = singlefield) or ('callretTTL-0' = singlefield))
        {
          http('"', ses);
          http_escape (cast (rset[0][0] as varchar), 11, ses, 0, 1);
          http('"', ses);
        }
      else
        SPARQL_RESULTS_JSON_WRITE (ses, metas, rset);
      goto body_complete;
    }
  if (strstr (accept, 'text/html') is not null)
    {
      ret_mime := 'text/html';
      SPARQL_RESULTS_JAVASCRIPT_HTML_WRITE(ses, metas, rset, 0);
      goto body_complete;
    }
  if (strstr (accept, 'application/javascript') is not null)
    {
      ret_mime := 'application/javascript';
      SPARQL_RESULTS_JAVASCRIPT_HTML_WRITE(ses, metas, rset, 1);
      goto body_complete;
    }
  if (strstr (accept, 'application/soap+xml') is not null)
    {
      declare soap_ns, spt_ns varchar;
      declare soap_ver int;

      if (strstr (accept, 'application/soap+xml;11') is not null)
        soap_ver := 11;
      else
        soap_ver := 12;
      soap_ns := DB.DBA.SPARQL_SOAP_NS (soap_ver);
      spt_ns := DB.DBA.SPARQL_PT_NS ();
      if (soap_ver = 12)
        ret_mime := 'application/soap+xml';
      else
        ret_mime := 'text/xml';
      http ('<soapenv:Envelope xmlns:soapenv="'||soap_ns||'"><soapenv:Body><query-result xmlns="'||spt_ns||'">', ses);
      SPARQL_RESULTS_XML_WRITE_NS (ses);
      SPARQL_RESULTS_XML_WRITE_HEAD (ses, metas);
      SPARQL_RESULTS_XML_WRITE_RES (ses, metas, rset);
      http ('\n</sparql>', ses);
      http ('</query-result></soapenv:Body></soapenv:Envelope>', ses);
      goto body_complete;
    }
  if (('callretRDF/XML-0' = singlefield) and ('auto' = accept))
    {
      ret_mime := 'application/rdf+xml';
      http (rset[0][0]);
      goto body_complete;
    }
  if ((('callretTURTLE-0' = singlefield) or ('callretTTL-0' = singlefield)) and ('auto' = accept))
    {
      ret_mime := 'text/rdf+n3';
      http (rset[0][0]);
      goto body_complete;
    }
  if (strstr (accept, 'application/sparql-results+xml') is null)
    {
      if (
        strstr (accept, 'text/rdf+n3') is not null or
        strstr (accept, 'text/rdf+ttl') is not null or
        strstr (accept, 'application/turtle') is not null or
        strstr (accept, 'application/x-turtle') is not null or
        (accept = 'auto') )
        {
          if (strstr (accept, 'text/rdf+n3') is not null)
            ret_mime := 'text/rdf+n3';
          else if (strstr (accept, 'text/rdf+ttl') is not null)
            ret_mime := 'text/rdf+ttl';
          else if (strstr (accept, 'application/turtle') is not null)
            ret_mime := 'application/turtle';
          else if (strstr (accept, 'application/x-turtle') is not null)
            ret_mime := 'application/x-turtle';
          else
            ret_mime := 'text/rdf+n3';
          SPARQL_RESULTS_TTL_WRITE_NS (ses);
          SPARQL_RESULTS_TTL_WRITE_HEAD (ses, metas);
          if (length (rset) > 0)
            http (' ;', ses);
          SPARQL_RESULTS_TTL_WRITE_RES (ses, metas, rset);
          http (' .', ses);
          goto body_complete;
        }
      if (strstr (accept, 'application/rdf+xml') is not null)
        {
          ret_mime := 'application/rdf+xml';
          SPARQL_RESULTS_RDFXML_WRITE_NS (ses);
          SPARQL_RESULTS_RDFXML_WRITE_HEAD (ses, metas);
          SPARQL_RESULTS_RDFXML_WRITE_RES (ses, metas, rset);
          http ('\n  </rdf:Description>', ses);
          http ('\n</rdf:RDF>', ses);
          goto body_complete;
        }
    }
  ret_mime := 'application/sparql-results+xml';
  SPARQL_RESULTS_XML_WRITE_NS (ses);
  SPARQL_RESULTS_XML_WRITE_HEAD (ses, metas);
  SPARQL_RESULTS_XML_WRITE_RES (ses, metas, rset);
  http ('\n</sparql>', ses);

body_complete:
  if (add_http_headers)
    http_header ('Content-Type: ' || ret_mime || '; charset=UTF-8\r\n');
  return ret_mime;
}
;

-- CLIENT --
--select -- dbg_obj_princ (soap_client (url=>'http://neo:6666/SPARQL', operation=>'querySoap', target_namespace=>'urn:FIXME', soap_action =>'urn:FIXME:querySoap', parameters=> vector ('Command', soap_box_structure ('Statement' , 'select TEST from DB.DBA.SPARQL_TABLE3'), 'Properties', soap_box_structure ('PropertyList', 'None' )), style=>2));


create procedure WS.WS.SPARQL_VHOST_RESET ()
{
  if (not exists (select 1 from "DB"."DBA"."SYS_USERS" where U_NAME = 'SPARQL'))
    {
      DB.DBA.USER_CREATE ('SPARQL', uuid(), vector ('DISABLED', 1, 'LOGIN_QUALIFIER', 'SPARQL'));
      DB.DBA.EXEC_STMT ('grant SPARQL_SELECT to "SPARQL"', 0);
    }
  DB.DBA.VHOST_REMOVE (lpath=>'/SPARQL');
  DB.DBA.VHOST_REMOVE (lpath=>'/sparql');
  DB.DBA.VHOST_REMOVE (lpath=>'/services/sparql-query');
  DB.DBA.VHOST_DEFINE (lpath=>'/sparql/', ppath => '/!sparql/', is_dav => 1, vsp_user => 'dba', opts => vector('noinherit', 1));
--DB.DBA.EXEC_STMT ('grant execute on DB.."querySoap" to "SPARQL", 0);
--VHOST_DEFINE (lpath=>'/services/sparql-query', ppath=>'/SOAP/', soap_user=>'SPARQL',
--              soap_opts => vector ('ServiceName', 'XMLAnalysis', 'elementFormDefault', 'qualified'));
}
;


-----
-- SPARQL HTTP request handler
create procedure DB.DBA.SPARQL_PROTOCOL_ERROR_REPORT (
  inout path varchar, inout params any, inout lines any,
  in httpcode varchar, in httpstatus varchar,
  in query varchar, in state varchar, in msg varchar, in accept varchar := null)
{
--  declare exit handler for sqlstate '*' { signal (state, msg); };
  if (httpstatus is null)
    {
      declare errtitle varchar;
      declare delim varchar;
      delim := strchr (msg, '\n');
      if (delim is null)
        errtitle := msg;
      else
        errtitle := subseq (msg, 0, delim);
      httpstatus := sprintf ('Error %s %s', state, errtitle);
    }
  if (accept is not null and strstr (accept, 'application/soap+xml') is not null)
    {
      declare err_str any;
      declare soap_ver int;
      if (strstr (accept, 'application/soap+xml;11') is not null)
	{
	  soap_ver := 11;
	  http_header ('Content-Type: text/xml; charset=UTF-8\r\n');
	}
      else
	{
          soap_ver := 12;
	  http_header ('Content-Type: application/soap+xml; charset=UTF-8\r\n');
	}
      http_request_status (sprintf ('HTTP/1.1 500 %s', httpstatus));
      err_str := soap_make_error ('320', state, msg, soap_ver);
      http (err_str);
      return;
    }

  http_request_status (sprintf ('HTTP/1.1 %s %s', httpcode, httpstatus));
  http_header ('Content-Type: text/plain\r\n');
  http (concat (state, ' Error ', msg));
  if (query is not null)
    {
      http ('\n\nSPARQL query:\n');
      http (query);
    }
}
;

create procedure DB.DBA.SPARQL_WSDL11 (in lines any)
{
  declare host any;
  host := http_request_header (lines, 'Host', null, null);
    http (sprintf ('<?xml version="1.0" encoding="utf-8"?>
    <definitions xmlns="http://schemas.xmlsoap.org/wsdl/"
		 xmlns:tns="http://www.w3.org/2005/08/sparql-protocol-query/#"
		 targetNamespace="http://www.w3.org/2005/08/sparql-protocol-query/#">
    <import namespace="http://www.w3.org/2005/08/sparql-protocol-query/#"
    location="http://www.w3.org/TR/sprot11/sparql-protocol-query-11.wsdl"/>
      <service name="SparqlService">
        <port name="SparqlServicePort" binding="tns:QuerySoapBinding">
	  <address location="http://%s/sparql"/>
	</port>
      </service>
    </definitions>', host));
}
;

create procedure DB.DBA.SPARQL_WSDL (in lines any)
{
  declare host any;
  host := http_request_header (lines, 'Host', null, null);
    http (sprintf ('<?xml version="1.0" encoding="utf-8"?>
    <description xmlns="http://www.w3.org/2006/01/wsdl"
		 xmlns:tns="http://www.w3.org/2005/08/sparql-protocol-query/#"
		 targetNamespace="http://www.w3.org/2005/08/sparql-protocol-query/#">
      <include location="http://www.w3.org/TR/rdf-sparql-protocol/sparql-protocol-query.wsdl" />
      <service name="SparqlService" interface="tns:SparqlQuery">
	<endpoint name="SparqlEndpoint" binding="tns:querySoap" address="http://%s/sparql"/>
      </service>
    </description>', host));
}
;

create procedure DB.DBA.SPARQL_SOAP_NS (in ver int)
{
  if (ver = 11)
    return 'http://schemas.xmlsoap.org/soap/envelope/';
  else if (ver = 12)
    return 'http://www.w3.org/2003/05/soap-envelope';
  else
    signal ('42000', 'Un-supported SOAP version');
}
;

create procedure DB.DBA.SPARQL_PT_NS ()
{
  return 'http://www.w3.org/2005/09/sparql-protocol-types/#';
}
;

create procedure WS.WS."/!sparql/" (inout path varchar, inout params any, inout lines any)
{
  declare query, full_query, format, should_sponge, debug, def_qry varchar;
  declare dflt_graphs, named_graphs any;
  declare paramctr, paramcount, maxrows, can_sponge integer;
  declare ses, content any;
  declare def_max, add_http_headers, timeout, sp_ini, soap_ver int;
  declare http_meth, content_type, ini_dflt_graph, get_user varchar;
  declare state, msg varchar;
  declare metas, rset any;
  declare accept, soap_action varchar;

  if (registry_get ('__sparql_endpoint_debug') = '1')
    {
      for (declare i int, i := 0; i < length (params); i := i + 2)
        {
	  if (isstring (params[i+1]))
	    dbg_printf ('%s=%s',params[i],params[i+1]);
	  else if (__tag (params[i+1]) = 185)
	    dbg_printf ('%s=%s',params[i],'<strses>');
	  else
	    dbg_printf ('%s=%s',params[i],'<box>');
	}
    }

  set http_charset='utf-8';
  ses := 0;
  query := null;
  format := '';
  should_sponge := '';
  debug := get_keyword ('debug', params, case (get_keyword ('query', params, '')) when '' then '1' else '' end);
  add_http_headers := 1;
  sp_ini := 0;
  dflt_graphs := vector ();
  named_graphs := vector ();
  maxrows := 1024*1024; -- More than enough for web-interface.
  http_meth := http_request_get ('REQUEST_METHOD');
  ini_dflt_graph := cfg_item_value (virtuoso_ini_path (), 'SPARQL', 'DefaultGraph');
  timeout := cfg_item_value (virtuoso_ini_path (), 'SPARQL', 'MaxQueryExecutionTime');
  if (timeout is null)
    timeout := cfg_item_value (virtuoso_ini_path (), 'SPARQL', 'ExecutionTimeout');
  def_qry := cfg_item_value (virtuoso_ini_path (), 'SPARQL', 'DefaultQuery');
  if (def_qry is null)
    def_qry := 'SELECT * WHERE {?s ?p ?o}';
  -- if timeout specified and it's over 1 second
  if (timeout is not null)
    {
      timeout := atoi (timeout) * 1000;
      if (timeout >= 1000)
	{
	  set TRANSACTION_TIMEOUT=timeout;
        }
    }
  get_user := '';
  soap_ver := 0;
  soap_action := http_request_header (lines, 'SOAPAction', null, null);
  content_type := http_request_header (lines, 'Content-Type', null, '');

  if (content_type = 'application/soap+xml')
    soap_ver := 12;
  else if (soap_action is not null)
    soap_ver := 11;

  content := null;
  can_sponge := coalesce ((select top 1 1
      from DB.DBA.SYS_USERS as sup
        join DB.DBA.SYS_ROLE_GRANTS as g on (sup.U_ID = g.GI_SUPER)
        join DB.DBA.SYS_USERS as sub on (g.GI_SUB = sub.U_ID)
      where sup.U_NAME = 'SPARQL' and sub.U_NAME = 'SPARQL_SPONGE' ), 0);
  declare exit handler for sqlstate '*' {
    DB.DBA.SPARQL_PROTOCOL_ERROR_REPORT (path, params, lines,
      '500', 'SPARQL Request Failed',
      query, __SQL_STATE, __SQL_MESSAGE, format);
     return;
   };

  -- the WSDL
  if (http_path () = '/sparql/services.wsdl')
    {
      http_header ('Content-Type: application/wsdl+xml\r\n');
--      http_header ('Content-Type: text/xml\r\n');
      DB.DBA.SPARQL_WSDL (lines);
      return;
    }
  else if (http_path () = '/sparql/services11.wsdl')
    {
      http_header ('Content-Type: text/xml\r\n');
      DB.DBA.SPARQL_WSDL11 (lines);
      return;
    }

  paramcount := length (params);
  if (((0 = paramcount) or ((2 = paramcount) and ('Content' = params[0]))) and soap_ver = 0)
    {
       declare redir varchar;
       redir := registry_get ('WS.WS.SPARQL_DEFAULT_REDIRECT');
       if (isstring (redir))
         {
            http_request_status ('HTTP/1.1 301 Moved Permanently');
            http_header (sprintf ('Location: %s\r\n', redir));
            return;
         }
http('<html xmlns="http://www.w3.org/1999/xhtml">\n');
http('	<head>\n');
http('		<title>Virtuoso SPARQL Query Form</title>\n');
http('		<style type="text/css">\n');
http('label.n');
http('{ display: inline; margin-top: 10pt; }\n');
http('body { font-family: arial, helvetica, sans-serif; font-size: 9pt; color: #234; }\n');
http('fieldset { border: 2px solid #86b9d9; }\n');
http('legend { font-size: 12pt; color: #86b9d9; }\n');
http('label { font-weight: bold; }\n');
http('h1 { width: 100%; background-color: #86b9d9; font-size: 18pt; font-weight: normal; color: #fff; height: 4ex; text-align: right; vertical-align: middle; padding-right:  8px; }\n');
http('		</style>\n');
http('		<script language="JavaScript">\n');
http('var last_format = 1;\n');
http('function format_select(query_obg)\n');
http('{\n');
http('  var query = query_obg.value; \n');
http('  var format = query_obg.form.format;\n');
http('\n');
http('  if (query.match(/construct/i) && last_format == 1) {\n');
http('    for(var i = format.options.length; i > 0; i--)\n');
http('      format.options[i] = null;');
http('    format.options[1] = new Option(\'N3/Turtle\',\'text/rdf+n3\');\n');
http('    format.options[2] = new Option(\'RDF/XML\',\'application/rdf+xml\');\n');
http('    format.selectedIndex = 1;\n');
http('    last_format = 2;\n');
http('  }\n');
http('\n');
http('  if (!query.match(/construct/i) && last_format == 2) {\n');
http('    for(var i = format.options.length; i > 0; i--)\n');
http('      format.options[i] = null;\n');
http('    format.options[1] = new Option(\'HTML\',\'text/html\');\n');
http('    format.options[2] = new Option(\'XML\',\'application/sparql-results+xml\');\n');
http('    format.options[3] = new Option(\'JSON\',\'application/sparql-results+json\');\n');
http('    format.options[4] = new Option(\'Javascript\',\'application/javascript\');\n');
http('    format.selectedIndex = 1;\n');
http('    last_format = 1;\n');
http('  }\n');
http('}\n');
http('		</script>\n');
http('	</head>\n');
http('	<body>\n');
http('		<div id="header">\n');
http('			<h1>OpenLink Virtuoso SPARQL Query</h1>\n');
http('		</div>\n');
http('		<div id="main">\n');
http('			<p>This query page is designed to help you test OpenLink Virtuoso SPARQL protocol endpoint. <br/>\n');
http('			Consult the <a href="http://virtuoso.openlinksw.com/wiki/main/Main/VOSSparqlProtocol">Virtuoso Wiki page</a> describing the service \n');
http('			or the <a href="http://docs.openlinksw.com/virtuoso/">Online Virtuoso Documentation</a> section <a href="http://docs.openlinksw.com/virtuoso/rdfandsparql.html">RDF Database and SPARQL</a>.</p>\n');
http('			<p>There is also a rich Web based user interface with sample queries. \n');
if (DB.DBA.VAD_CHECK_VERSION('iSPARQL') is null)
  http('			In order to use it you must install the iSPARQL package (isparql_dav.vad).</p>\n');
else
  http('			You can access it at: <a href="/isparql">/isparql</a>.</p>\n');
http('			<form action="" method="GET">\n');
http('			<fieldset>\n');
http('			<legend>Query</legend>\n');
http('			  <label for="default-graph-uri">Default Graph URI</label>\n');
http('			  <br />\n');
http('			  <input type="text" name="default-graph-uri" id="default-graph-uri"\n');
http(sprintf ('				  	value="%s" size="80"/>\n', coalesce (ini_dflt_graph, '') ));
http('			  <br /><br />\n');
if (can_sponge)
  {
    declare s_param varchar;
    s_param := get_keyword ('should-sponge', params, '');
http('<select name="should-sponge" id="should-sponge">');
http('  <option' ||
  case (s_param) when '' then ' selected="selected"' else '' end ||
  ' value="">Use only local data (including data retrieved before), but do not retrieve more</option>\n');
http('  <option' ||
  case (s_param) when 'soft' then ' selected="selected"' else '' end ||
  ' value="soft">Retrieve remote RDF data for all missing source graphs</option>\n');
http('  <option' ||
  case (s_param) when 'grab-all' then ' selected="selected"' else '' end ||
  ' value="grab-all">Retrieve all missing remote RDF data that might be useful</option>\n');
http('  <option' ||
  case (s_param) when 'grab-seealso' then ' selected="selected"' else '' end ||
  ' value="grab-all-seealso">Retrieve all missing remote RDF data that might be useful, including seeAlso references</option>\n');
http('  <option' ||
  case (s_param) when 'grab-everything' then ' selected="selected"' else '' end ||
  ' value="grab-everything">Try to download all referenced resources (this may be very slow and ineffecient)</option>\n');
http('</select>\n');
http('			  <br />\n');
  }
else
  {
declare host_ur varchar;
      host_ur := registry_get ('URIQADefaultHost');

http('			  <i>Security restrictions of this server do not allow you to retrieve remote RDF data.
DBA may wish to grant "SPARQL_SPONGE" privilege to "SPARQL" account to remove the restriction.\n');
http('In order to do this, please perform the following steps:</i>\n');
http('<br />\n');
http('1. Go to the Virtuoso Administration Conductor i.e. \n');
if (not isstring (host_ur))
  {
    http('http://host:port/conductor\n');
  }
else
  {
    http(sprintf('http://%s/conductor\n',host_ur));
  };

http('<br />\n');
http('2. Login as dba user\n');
http('<br />\n');
http('3. Go to System Admin->User Accounts->Roles\n');
http('<br />\n');
http('4. Click the link "Edit" for "SPARQL_SPONGE"\n');
http('<br />\n');
http('5. Select from the list of available user/groups "SPARQL" and click the ">>" button so to add it to the right-positioned list.\n');
http('<br />\n');
http('6. Click the button "Update"\n');
http('<br />\n');
http('7. Access again the sparql endpoint in order to be able to retrieve remote data.\n');
http('<br /><br />\n');
  }
http('			  <label for="query">Query text</label>\n');
http('			  <br />\n');
http('			  <textarea rows="10" cols="60" name="query" id="query" onchange="format_select(this)" onkeyup="format_select(this)">'|| def_qry ||'</textarea>\n');
http('			  <br /><br />\n');
--http('			  <label for="maxrows">Max Rows:</label>\n');
--http('			  <input type="text" name="maxrows" id="maxrows"\n');
--http(sprintf('				  	value="%d"/>',maxrows));
--http('			  <br />\n');
http('			  <label for="format" class="n">Display Results As:</label>\n');
http('			  <select name="format">\n');
http('			    <option value="auto">Auto</option>\n');
http('			    <option value="text/html" selected="selected">HTML</option>\n');
http('			    <option value="application/sparql-results+xml">XML</option>\n');
http('			    <option value="application/sparql-results+json">JSON</option>\n');
http('			    <option value="application/javascript">Javascript</option>\n');
http('			  </select>\n');
http('&nbsp;&nbsp;&nbsp;\n');
http('<input name="debug" type="checkbox"' || case (debug) when '' then '' else ' checked' end || '/>\n');
http('			  <label for="debug" class="n">Rigorous check of the query</label>\n');
http('&nbsp;&nbsp;&nbsp;\n');
http('			  <input type="submit" value="Run Query"/>\n');
http('			  <input type="reset" value="Reset"/>\n');
http('			</fieldset>\n');
http('			</form>\n');
http('		</div>\n');
http('	</body>\n');
http('</html>\n');
       return;
    }
  for (paramctr := 0; paramctr < paramcount; paramctr := paramctr + 2)
    {
      declare pname, pvalue varchar;
      pname := params [paramctr];
      pvalue := params [paramctr+1];
      if ('query' = pname)
        query := pvalue;
      else if ('default-graph-uri' = pname and length (pvalue))
        {
	  if (position (pvalue, dflt_graphs) <= 0)
	    dflt_graphs := vector_concat (dflt_graphs, vector (pvalue));
	}
      else if ('named-graph-uri' = pname and length (pvalue))
        {
	  if (position (pvalue, named_graphs) <= 0)
	    named_graphs := vector_concat (named_graphs, vector (pvalue));
	}
      else if ('maxrows' = pname)
        {
	  maxrows := cast (pvalue as integer);
	}
      else if ('should-sponge' = pname)
        {
          if (can_sponge)
            should_sponge := trim(pvalue);
	}
      else if ('format' = pname or 'output' = pname)
        {
	  format := pvalue;
	}
      else if ('ini' = pname)
        {
	  sp_ini := 1;
	}
      else if (query is null and 'query-uri' = pname and length (pvalue))
	{
	  if (cfg_item_value (virtuoso_ini_path (), 'SPARQL', 'ExternalQuerySource') = '1')
	    {
	      declare uri varchar;
	      declare hf, hdr, charset any;
	      uri := pvalue;
	      if (uri like 'http://%' and uri not like 'http://localdav.virt/%' and uri not like 'http://local.virt/dav/%')
		{
		  query := http_get (uri, hdr);
		  if (hdr[0] not like '% 200%')
		    signal ('22023', concat ('HTTP request failed: ', hdr[0], 'for URI ', uri));
		  charset := http_request_header (hdr, 'Content-Type', 'charset', '');
		  if (charset <> '')
		    {
		      query := charset_recode (query, charset, 'UTF-8');
		    }
		}
	      else
		{
		  query := DB.DBA.XML_URI_GET ('', pvalue);
	        }
	    }
	  else
	    {
	       DB.DBA.SPARQL_PROTOCOL_ERROR_REPORT (path, params, lines,
		    '403', 'Prohibited', query, '22023', 'The external query sources are prohibited.');
	       return;
	    }
	}
      else if ('xslt-uri' = pname and length (pvalue))
	{
	  if (cfg_item_value (virtuoso_ini_path (), 'SPARQL', 'ExternalXsltSource') = '1')
	    {
	      add_http_headers := 0;
	      http_xslt (pvalue);
	    }
	  else
	    {
	       DB.DBA.SPARQL_PROTOCOL_ERROR_REPORT (path, params, lines,
		    '403', 'Prohibited', query, '22023', 'The XSL-T transformation is prohibited');
	       return;
	    }
	}
      else if ('get-login' = pname)
	{
	  get_user := pvalue;
	}
    }

  if (format <> '')
  {
    format := (
      case lower(format)
        when 'json' then 'application/sparql-results+json'
        when 'js' then 'application/javascript'
        when 'html' then 'text/html'
        when 'sparql' then 'application/sparql-results+xml'
        when 'xml' then 'application/sparql-results+xml'
        when 'rdf' then 'application/rdf+xml'
        when 'n3' then 'text/rdf+n3'
        else format
      end);
  }

  def_max := atoi (coalesce (cfg_item_value (virtuoso_ini_path (), 'SPARQL', 'ResultSetMaxRows'), '-1'));
  if (def_max > 0 and def_max < maxrows)
    maxrows := def_max;

  --if (0 = length (dflt_graphs) and length (ini_dflt_graph))
  --  dflt_graphs := vector (ini_dflt_graph);


  -- SOAP 1.2 operation begins
  if (http_meth = 'POST' and soap_ver > 0)
    {
       declare xt, dgs, ngs any;
       declare soap_ns, spt_ns, ns_decl varchar;
       soap_ns := DB.DBA.SPARQL_SOAP_NS (soap_ver);
       spt_ns := DB.DBA.SPARQL_PT_NS ();
       ns_decl := '[ xmlns:soap="'||soap_ns||'" xmlns:sp="'||spt_ns||'" ] ';
       content := http_body_read ();
       if (registry_get ('__sparql_endpoint_debug') = '1')
         dbg_printf ('content=[%s]', string_output_string (content));
       xt := xtree_doc (content);
       query := charset_recode (xpath_eval (ns_decl||'string (/soap:Envelope/soap:Body/sp:query-request/query)', xt), '_WIDE_', 'UTF-8');
       dgs := xpath_eval (ns_decl||'/soap:Envelope/soap:Body/sp:query-request/default-graph-uri', xt, 0);
       ngs := xpath_eval (ns_decl||'/soap:Envelope/soap:Body/sp:query-request/named-graph-uri', xt, 0);
       foreach (any frag in dgs) do
	 {
	   declare pvalue varchar;
	   pvalue := charset_recode (xpath_eval ('string(.)', frag), '_WIDE_', 'UTF-8');
	   if (position (pvalue, dflt_graphs) <= 0)
	     dflt_graphs := vector_concat (dflt_graphs, vector (pvalue));
	 }
       foreach (any frag in ngs) do
	 {
	   declare pvalue varchar;
	   pvalue := charset_recode (xpath_eval ('string(.)', frag), '_WIDE_', 'UTF-8');
	   if (position (pvalue, named_graphs) <= 0)
	     named_graphs := vector_concat (named_graphs, vector (pvalue));
	 }
       format := sprintf('application/soap+xml;%d', soap_ver);
    }

  if (sp_ini)
    {
      SPARQL_INI_PARAMS (metas, rset);
      goto write_results;
    }

  if (query is null)
    {
      if (strstr (content_type, 'application/xml') is not null)
        {
          DB.DBA.SPARQL_PROTOCOL_ERROR_REPORT (path, params, lines,
            '400', 'Bad Request',
	    query, '22023', 'XML notation of SPARQL queries is not supported' );
	  return;
	}
      DB.DBA.SPARQL_PROTOCOL_ERROR_REPORT (path, params, lines,
        '400', 'Bad Request',
        query, '22023', 'The request does not contain text of SPARQL query', format);
      return;
    }

  full_query := query;
  -- dbg_obj_princ ('dflt_graphs = ', dflt_graphs, ', named_graphs = ', named_graphs);
  declare req_hosts varchar;
  declare req_hosts_split any;
  declare hctr integer;
  req_hosts := http_request_header (lines, 'Host', null, null);
  req_hosts := replace (req_hosts, ', ', ',');
  req_hosts_split := split_and_decode (req_hosts, 0, '\0\0,');
  for (hctr := length (req_hosts_split) - 1; hctr >= 0; hctr := hctr - 1)
    {
      for (select top 1 SH_GRAPH_URI, SH_DEFINES from DB.DBA.SYS_SPARQL_HOST
      where req_hosts_split [hctr] like SH_HOST) do
        {
          if (length (dflt_graphs) = 0 and length (SH_GRAPH_URI))
            dflt_graphs := vector (SH_GRAPH_URI);
          if (SH_DEFINES is not null)
            full_query := concat (SH_DEFINES, ' ', full_query);
          goto host_found;
        }
    }
host_found:

  foreach (varchar dg in dflt_graphs) do
    {
      full_query := concat ('define input:default-graph-uri <', dg, '> ', full_query);
      http_header (sprintf ('X-SPARQL-default-graph: %U\r\n', dg));
    }
  foreach (varchar ng in named_graphs) do
    {
      full_query := concat ('define input:named-graph-uri <', ng, '> ', full_query);
      http_header (sprintf ('X-SPARQL-named-graph: %U\r\n', ng));
    }
  if ((should_sponge = 'soft') or (should_sponge = 'replacing'))
    full_query := concat (sprintf('define get:soft "%s" ',should_sponge), full_query);
  else if (should_sponge = 'grab-all')
    full_query := concat ('define input:grab-all "yes" define input:grab-depth 5 define input:grab-limit 100 ', full_query);
  else if (should_sponge = 'grab-all-seealso')
    full_query := concat ('define input:grab-all "yes" define input:grab-depth 5 define input:grab-limit 200 define input:grab-seealso <http://www.w3.org/2000/01/rdf-schema#seeAlso> define input:grab-seealso <http://xmlns.com/foaf/0.1/seeAlso> ', full_query);
  else if (should_sponge = 'grab-everything')
    full_query := concat ('define input:grab-all "yes" define input:grab-intermediate "yes" define input:grab-depth 5 define input:grab-limit 500 define input:grab-seealso <http://www.w3.org/2000/01/rdf-schema#seeAlso> define input:grab-seealso <http://xmlns.com/foaf/0.1/seeAlso> define input:grab-seealso <http://xmlns.com/foaf/0.1/seeAlso> ', full_query);
  full_query := concat ('define output:valmode "LONG" ', full_query);
  if (debug <> '')
    full_query := concat ('define sql:signal-void-variables 1 ', full_query);
  if (get_user <> '')
    full_query := concat ('define get:login "', get_user, '" ', full_query);
  state := '00000';
  metas := null;
  rset := null;
  if (registry_get ('__sparql_endpoint_debug') = '1')
    dbg_printf ('query=[%s]', full_query);
  exec ('isnull (sparql_to_sql_text (?))', state, msg, vector (full_query));
  if (state <> '00000')
    {
      DB.DBA.SPARQL_PROTOCOL_ERROR_REPORT (path, params, lines,
        '400', 'Bad Request',
	full_query, state, msg, format);
      return;
    }

  declare sc_max int;
  declare sc decimal;
  sc_max := atoi (coalesce (cfg_item_value (virtuoso_ini_path (), 'SPARQL', 'MaxQueryCostEstimationTime'), '-1'));
  if (sc_max < 0)
    sc_max := atoi (coalesce (cfg_item_value (virtuoso_ini_path (), 'SPARQL', 'MaxExecutionTime'), '-1'));
  if (sc_max > 0)
    {
      state := '00000';
      sc := exec_score (concat ('sparql ', full_query), state, msg);
      if ((sc/1000) > sc_max)
	{
	  signal ('42000', sprintf ('The estimated execution time %d (sec) exceeds the limit of %d (sec).', sc/1000, sc_max));
	}
    }

  state := '00000';
  metas := null;
  rset := null;
--  http ('<!-- Query:\n' || query || '\n-->\n', 0);
  set_user_id ('SPARQL');
  -- dbg_obj_princ ('full_query = ', full_query);
  commit work;
  exec ( concat ('sparql ', full_query), state, msg, vector(), maxrows, metas, rset);
  commit work;
  -- dbg_obj_princ ('exec metas=', metas);
  if (state <> '00000')
    {
      DB.DBA.SPARQL_PROTOCOL_ERROR_REPORT (path, params, lines,
        '500', 'SPARQL Request Failed',
	full_query, state, msg, format);
      return;
    }
write_results:
  accept := http_request_header (lines, 'Accept', null, '');
  if (format <> '')
    accept := format;
  DB.DBA.SPARQL_RESULTS_WRITE (ses, metas, rset, accept, add_http_headers);
}
;

registry_set ('/!sparql/', 'no_vsp_recompile')
;

-----
-- RDF parallel load


create procedure DB.DBA.TTLP_EV_TRIPLE_W (
  in g_iid IRI_ID, in s_uri varchar, in p_uri varchar,
  in o_uri varchar, in env any )
{
  -- dbg_obj_princ ('DB.DBA.TTLP_EV_TRIPLE_W (', g_iid, s_uri, p_uri, o_uri, env, ')');
  declare log_mode integer;
  log_mode := env[0];
  if (log_mode = 1)
    {
      declare s_iid, p_iid, o_iid IRI_ID;
      whenever sqlstate '40001' goto deadlock_10;
again_10:
      s_iid := iri_to_id (s_uri, 1);
      p_iid := iri_to_id (p_uri, 1);
      o_iid := iri_to_id (o_uri, 1);
      whenever sqlstate '40001' goto deadlock_11;
again_11:
      log_enable (0, 1);
      insert soft DB.DBA.RDF_QUAD (G,S,P,O)
      values (g_iid, s_iid, p_iid, o_iid);
      commit work;
      return;
    }
  if (log_mode = 0)
    {
      whenever sqlstate '40001' goto deadlock_0;
again_0:
      log_enable (0, 1);
      insert soft DB.DBA.RDF_QUAD (G,S,P,O)
      values (g_iid, iri_to_id (s_uri, 1), iri_to_id (p_uri, 1), iri_to_id (o_uri, 1));
      commit work;
      return;
    }
  whenever sqlstate '40001' goto deadlock_2;
again_2:
  log_enable (1, 1);
  insert soft DB.DBA.RDF_QUAD (G,S,P,O)
  values (g_iid, iri_to_id (s_uri, 1), iri_to_id (p_uri, 1), iri_to_id (o_uri, 1));
  commit work;
  return;
deadlock_10:
  rollback work;
  goto again_10;
deadlock_11:
  rollback work;
  goto again_11;
deadlock_0:
  rollback work;
  goto again_0;
deadlock_2:
  rollback work;
  goto again_2;
}
;


create procedure DB.DBA.TTLP_EV_TRIPLE_L_W (
  in g_iid IRI_ID, in s_uri varchar, in p_uri varchar,
  in o_val any, in o_type any, in o_lang any, in env any )
{
  -- dbg_obj_princ ('DB.DBA.TTLP_EV_TRIPLE_L_W (', g_iid, s_uri, p_uri, o_val, o_type, o_lang, env, ')');
  declare log_mode integer;
  declare ro_id_dict any;
  log_mode := env[0];
  ro_id_dict := env[1];
  declare s_iid, p_iid IRI_ID;
  if (isstring (o_type))
    {
      declare parsed any;
      parsed := __xqf_str_parse_to_rdf_box (o_val, o_type, isstring (o_val));
      if (parsed is not null)
        {
          if (__tag of rdf_box = __tag (parsed))
            {
              rdf_box_set_type (parsed,
                DB.DBA.RDF_TWOBYTE_OF_DATATYPE (DB.DBA.RDF_MAKE_IID_OF_QNAME (o_type)));
              -- dbg_obj_princ ('rdf_box_type is set to ', rdf_box_type (parsed));
            }
          o_val := parsed;
        }
    }
  whenever sqlstate '40001' goto deadlock_iid;
again_iid:
  if (log_mode = 0)
    log_enable (0, 1);
  else
    log_enable (1, 1);
  s_iid := iri_to_id (s_uri, 1);
  p_iid := iri_to_id (p_uri, 1);
  if (isstring (o_val) or (__tag of XML = __tag (o_val)))
    {
      whenever sqlstate '40001' goto deadlock_o;
again_o:
      if (isstring (o_type) or isstring (o_lang))
        {
          if (not isstring (o_type))
            o_type := null;
          if (not isstring (o_lang))
            o_lang := null;
          o_val := DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL_FT (o_val,
              iri_to_id (o_type, 1),
              o_lang, g_iid, p_iid, ro_id_dict );
	}
      else
        o_val := DB.DBA.RDF_MAKE_OBJ_OF_SQLVAL_FT (o_val, g_iid, p_iid, ro_id_dict);
    }
  else if (__tag of rdf_box = __tag (o_val))
    {
      whenever sqlstate '40001' goto deadlock_o_box;
again_o_box:
      if (__tag of varchar = rdf_box_data_tag (o_val) and __rdf_obj_ft_rule_check (g_iid, p_iid))
        o_val := DB.DBA.RDF_OBJ_ADD (257, o_val, 257, ro_id_dict);
      else if (0 < rdf_box_needs_digest (o_val))
        o_val := DB.DBA.RDF_OBJ_ADD (257, o_val, 257);
    }
  -- dbg_obj_princ ('final o_val = ', o_val);
  whenever sqlstate '40001' goto deadlock_quad;
again_quad:
  if (log_mode <= 1)
    log_enable (0, 1);
  insert soft DB.DBA.RDF_QUAD (G,S,P,O)
  values (g_iid, s_iid, p_iid, o_val);
  commit work;
  return;
deadlock_iid:
  rollback work;
  goto again_iid;
deadlock_o:
  rollback work;
  goto again_o;
deadlock_o_box:
  rollback work;
  goto again_o_box;
deadlock_quad:
  rollback work;
  goto again_quad;
}
;

create procedure DB.DBA.TTLP_EV_TRIPLE_A (
  inout g_iid IRI_ID, inout s_uri varchar, inout p_uri varchar,
  inout o_uri varchar,
  inout app_env any )
{
  -- dbg_obj_princ ('DB.DBA.TTLP_EV_TRIPLE_A (', g_iid, s_uri, p_uri, o_uri, app_env, ')');
  declare err any;
  app_env[1] := aq_request (
    app_env[0], 'DB.DBA.TTLP_EV_TRIPLE_W',
    vector (g_iid, s_uri, p_uri, o_uri, app_env[2]) );
  if (mod (app_env[1], 100000) = 0)
    {
      declare ro_id_dict any;
      ro_id_dict := app_env[2][1];
      if (ro_id_dict is not null)
        DB.DBA.RDF_OBJ_ADD_KEYWORD_FOR_GRAPH (g_iid, ro_id_dict);
      commit work;
      aq_wait (app_env[0], app_env[1], err, 1);
      aq_wait_all (app_env[0]);
    }
}
;

create procedure DB.DBA.TTLP_EV_TRIPLE_L_A (
  inout g_iid IRI_ID, inout s_uri varchar, inout p_uri varchar,
  inout o_val any, inout o_type varchar, inout o_lang varchar,
  inout app_env any )
{
  -- dbg_obj_princ ('DB.DBA.TTLP_EV_TRIPLE_L_A (', g_iid, s_uri, p_uri, o_val, o_type, o_lang, app_env, ')');
  declare err any;
  if (__tag of XML = __tag (o_val))
    {
      DB.DBA.TTLP_EV_TRIPLE_L_W (g_iid, s_uri, p_uri, o_val, o_type, o_lang, app_env[2]);
      return;
    }
  app_env[1] := aq_request (
    app_env[0], 'DB.DBA.TTLP_EV_TRIPLE_L_W',
    vector (g_iid, s_uri, p_uri, o_val, o_type, o_lang, app_env[2]) );
  if (mod (app_env[1], 100000) = 0)
    {
      declare ro_id_dict any;
      ro_id_dict := app_env[2][1];
      if (ro_id_dict is not null)
        DB.DBA.RDF_OBJ_ADD_KEYWORD_FOR_GRAPH (g_iid, ro_id_dict);
      commit work;
      aq_wait (app_env[0], app_env[1], err, 1);
      aq_wait_all (app_env[0]);
    }
}
;

create procedure DB.DBA.TTLP_EV_COMMIT_A (
  inout graph_iri varchar, inout app_env any )
{
  -- dbg_obj_princ ('DB.DBA.TTLP_EV_COMMIT_A (', graph_iri, app_env, ')');
  DB.DBA.TTLP_EV_COMMIT (graph_iri, app_env[2]);
}
;


create function DB.DBA.TTLP_MT (in strg varchar, in base varchar, in graph varchar := null, in flags integer := 0,
				 in log_mode integer := 2, in threads integer := 3)
{
  declare ro_id_dict, app_env, err any;
  if (126 = __tag (strg))
    strg := cast (strg as varchar);
  if (__rdf_obj_ft_rule_count_in_graph (iri_to_id (graph)))
    ro_id_dict := dict_new (__max (length (strg) / 100, 100000));
  else
    ro_id_dict := null;
  app_env := vector (async_queue (threads), 0, vector (log_mode, ro_id_dict));
  rdf_load_turtle (strg, base, graph, flags,
    vector (
      'DB.DBA.TTLP_EV_NEW_GRAPH',
      'DB.DBA.TTLP_EV_NEW_BLANK',
      '!iri_to_id',
      'DB.DBA.TTLP_EV_TRIPLE_A',
      'DB.DBA.TTLP_EV_TRIPLE_L_A',
      'DB.DBA.TTLP_EV_COMMIT_A' ),
    app_env);
  commit work;
  aq_wait (app_env[0], app_env[1], err, 1);
  aq_wait_all (app_env[0]);
  if (ro_id_dict is not null)
    DB.DBA.RDF_OBJ_ADD_KEYWORD_FOR_GRAPH (iri_to_id (graph), ro_id_dict);
  commit work;
  return graph;
}
;

create function DB.DBA.RDF_LOAD_RDFXML_MT (in strg varchar, in base varchar, in graph varchar,
  in log_mode integer := 2, in threads integer := 3 )
{
  declare ro_id_dict, app_env, err any;
  if (__rdf_obj_ft_rule_count_in_graph (iri_to_id (graph)))
    ro_id_dict := dict_new (__max (length (strg) / 100, 100000));
  else
    ro_id_dict := null;
  app_env := vector (async_queue (threads), 0, vector (log_mode, ro_id_dict));
  rdf_load_rdfxml (strg, 0,
    graph,
    vector (
      'DB.DBA.TTLP_EV_NEW_GRAPH',
      'DB.DBA.TTLP_EV_NEW_BLANK',
      '!iri_to_id',
      'DB.DBA.TTLP_EV_TRIPLE_A',
      'DB.DBA.TTLP_EV_TRIPLE_L_A',
      'DB.DBA.TTLP_EV_COMMIT_A' ),
    app_env,
    base );
  commit work;
  aq_wait (app_env[0], app_env[1], err, 1);
  aq_wait_all (app_env[0]);
  if (ro_id_dict is not null)
    DB.DBA.RDF_OBJ_ADD_KEYWORD_FOR_GRAPH (iri_to_id (graph), ro_id_dict);
  commit work;
  return graph;
}
;


-----
-- Resource sponge

create table DB.DBA.SYS_HTTP_SPONGE (
  HS_LOCAL_IRI varchar not null,
  HS_PARSER varchar not null,
  HS_ORIGIN_URI varchar not null,
  HS_ORIGIN_LOGIN varchar,
  HS_LAST_LOAD datetime,
  HS_LAST_ETAG varchar,
  HS_LAST_READ datetime,
  HS_EXP_IS_TRUE integer,
  HS_EXPIRATION datetime,
  HS_LAST_MODIFIED datetime,
  HS_DOWNLOAD_SIZE integer,
  HS_DOWNLOAD_MSEC_TIME integer,
  HS_READ_COUNT integer,
  HS_SQL_STATE varchar,
  HS_SQL_MESSAGE varchar,
  HS_FROM_IRI varchar,
  HS_QUALITY double precision,
  primary key (HS_LOCAL_IRI, HS_PARSER)
)
create index SYS_HTTP_SPONGE_EXPIRATION on DB.DBA.SYS_HTTP_SPONGE (HS_EXPIRATION desc)
create index SYS_HTTP_SPONGE_FROM_IRI on DB.DBA.SYS_HTTP_SPONGE (HS_FROM_IRI, HS_PARSER)
;

--#IF VER=5
--!AFTER
alter table DB.DBA.SYS_HTTP_SPONGE add HS_FROM_IRI varchar
;
--#ENDIF

create procedure DB.DBA.SYS_HTTP_SPONGE_GET_CACHE_PARAMS
   (
    in explicit_refresh any,
    in old_last_modified any,
    inout ret_hdr any,
    inout new_expiration any,
    out ret_content_type any,
    out ret_etag any,
    out ret_date any,
    out ret_expires any,
    out ret_last_modif any,
    out ret_dt_date any,
    out ret_dt_expires any,
    out ret_dt_last_modified any
   )
{
  declare ret_304_not_modified int;

  ret_304_not_modified := 0;
  if (ret_hdr[0] like 'HTTP%304%')
    {
      ret_304_not_modified := 1;
    }

  ret_content_type := http_request_header (ret_hdr, 'Content-Type', null, null);
  ret_etag := http_request_header (ret_hdr, 'ETag', null, null);
  ret_date := http_request_header (ret_hdr, 'Date', null, null);
  ret_expires := http_request_header (ret_hdr, 'Expires', null, null);
  ret_last_modif := http_request_header (ret_hdr, 'Last-Modified', null, null);
  ret_dt_date := http_string_date (ret_date, NULL, NULL);
  ret_dt_expires := http_string_date (ret_expires, NULL, now());
  ret_dt_last_modified := http_string_date (ret_last_modif, NULL, now());
  if (http_request_header (ret_hdr, 'Pragma', null, null) = 'no-cache' or
    http_request_header (ret_hdr, 'Cache-Control', null, null) like 'no-cache%' )
    ret_dt_expires := now ();
  if (ret_304_not_modified and ret_dt_last_modified is null)
    ret_dt_last_modified := old_last_modified;
  if (ret_dt_date is not null)
    {
      if (ret_dt_expires is not null)
        ret_dt_expires := dateadd ('second', datediff ('second', ret_dt_date, now()), ret_dt_expires);
      if (ret_dt_last_modified is not null)
        ret_dt_last_modified := dateadd ('second', datediff ('second', ret_dt_date, now()), ret_dt_last_modified);
    }
  if (ret_dt_expires is not null and
    (ret_dt_expires < coalesce (ret_dt_date, ret_dt_last_modified, now ())) )
    ret_dt_expires := NULL;
  if (ret_dt_expires is not null)
    new_expiration := ret_dt_expires;
  else
    {
      if (ret_dt_date is not null and ret_dt_last_modified is not null and (ret_dt_date >= ret_dt_last_modified))
        new_expiration := dateadd ('second',
		__min (
		   3600 * 24 * 7,
		   0.7 * datediff ('second', ret_dt_last_modified, ret_dt_date)
		 ),
		now());
    }
  if (ret_304_not_modified)
    {
      if (new_expiration is null and explicit_refresh is not null)
        new_expiration := dateadd ('second', 0.7 * explicit_refresh, now());

      if (ret_dt_expires is null and new_expiration is not null and explicit_refresh is not null)
        new_expiration := __min (new_expiration, dateadd ('second', explicit_refresh, now()));
    }
}
;


--!AFTER_AND_BEFORE DB.DBA.SYS_HTTP_SPONGE HS_FROM_IRI !
create procedure DB.DBA.SYS_HTTP_SPONGE_DEP_URL_NOT_CHNAGED (in local_iri varchar, in parser varchar, in explicit_refresh int)
{

 for select
       HS_LOCAL_IRI as old_local_iri,
       HS_LAST_LOAD as old_last_load,
       HS_READ_COUNT as old_read_count,
       HS_EXP_IS_TRUE as old_exp_is_true,
       HS_EXPIRATION as old_expiration,
       HS_LAST_MODIFIED as old_last_modified
  from DB.DBA.SYS_HTTP_SPONGE where HS_FROM_IRI = local_iri and HS_PARSER = parser
  do
    {
      -- dbg_obj_princ (' old_expiration=', old_expiration, ' old_exp_is_true=', old_exp_is_true, ' old_last_load=', old_last_load);
      -- dbg_obj_princ ('now()=', now(), ' explicit_refresh=', explicit_refresh);
      if (old_expiration is not null)
	{
	  if ((old_expiration >= now()) and (
		explicit_refresh is null or
		old_exp_is_true or
		(dateadd ('second', explicit_refresh, old_last_load) >= now()) ) )
	    {
	      -- dbg_obj_princ ('not expired, return');
	      update DB.DBA.SYS_HTTP_SPONGE
		  set HS_LAST_READ = now(), HS_READ_COUNT = old_read_count + 1
		  where HS_LOCAL_IRI = old_local_iri and HS_LAST_READ < now();
              commit work;
	    }
	  else
	    {
	      return 0;
	    }
	}
      else -- either other loading is in progress or an recorded error
	{
	  if (old_last_load >= now() and old_expiration is null)
	    {
	      -- dbg_obj_princ ('collision in the air, return');
	      return 0; -- Nobody promised to resolve collisions in the air.
	    }
	}
    }
  return 1;
}
;

create procedure DB.DBA.RDF_HTTP_MAKE_HTTP_REQ (in url varchar, in meth varchar, in req varchar)
{
  declare hf any;
  declare str any;

  hf := rfc1808_parse_uri (url);
  str := meth || ' ' || hf[2] || case when hf[4] <> '' then '?' else '' end || hf[4] || ' HTTP/1.1\r\n' ||
  	 'Host: ' || hf[1] || '\r\n' || req;
  str := replace (str, '\r', '\n');
  str := replace (str, '\n\n', '\n');
  return split_and_decode (str, 0, '\0\0\n');
}
;

create function DB.DBA.SYS_HTTP_SPONGE_UP (in local_iri varchar, in get_uri varchar, in parser varchar, in eraser varchar, in options any)
{
  declare new_origin_uri, new_origin_login, new_last_etag varchar;
  declare old_origin_uri, old_origin_login, old_last_etag varchar;
  declare new_last_load, new_expiration datetime;
  declare old_last_load, old_expiration, old_last_modified datetime;
  declare load_begin_msec, load_end_msec, old_exp_is_true,
    old_download_size, old_download_msec_time, old_read_count,
    new_download_size, explicit_refresh integer;
  declare get_method varchar;
  declare ret_hdr, immg, req_hdr_arr any;
  declare req_hdr varchar;
  declare ret_body, ret_content_type, ret_etag, ret_last_modified, ret_date, ret_last_modif, ret_expires varchar;
  declare get_proxy varchar;
  declare ret_dt_date, ret_dt_last_modified, ret_dt_expires datetime;
  declare ret_304_not_modified integer;
  declare parser_rc, max_refresh int;

  -- dbg_obj_princ ('DB.DBA.SYS_HTTP_SPONGE_UP (', local_iri, get_uri, options, ')');
  new_origin_uri := cast (get_keyword_ucase ('get:uri', options, get_uri) as varchar);
  new_origin_login := cast (get_keyword_ucase ('get:login', options) as varchar);
  explicit_refresh := get_keyword_ucase ('get:refresh', options);
  if (explicit_refresh is null)
    {
      max_refresh := cfg_item_value (virtuoso_ini_path (), 'SPARQL', 'MaxCacheExpiration');
      if (max_refresh is not null)
        {
          max_refresh := atoi (max_refresh);
	  if (max_refresh >= 0)
	    explicit_refresh := max_refresh;
	}
    }
  else if (isstring (explicit_refresh))
    explicit_refresh := atoi (explicit_refresh);
  set isolation='serializable';
  whenever not found goto add_new_origin;
  select HS_ORIGIN_URI, HS_ORIGIN_LOGIN, HS_LAST_LOAD, HS_LAST_ETAG,
    HS_EXP_IS_TRUE, HS_EXPIRATION, HS_LAST_MODIFIED,
    HS_DOWNLOAD_SIZE, HS_DOWNLOAD_MSEC_TIME, HS_READ_COUNT
  into old_origin_uri, old_origin_login, old_last_load, old_last_etag,
    old_exp_is_true, old_expiration, old_last_modified,
    old_download_size, old_download_msec_time, old_read_count
  from DB.DBA.SYS_HTTP_SPONGE where HS_LOCAL_IRI = local_iri and HS_PARSER = parser for update;

  if (new_origin_uri <> old_origin_uri)
    signal ('RDFXX',
      sprintf ('Can not get-and-cache RDF graph <%.500s> from <%.500s> because is has been loaded from <%.500s>',
        local_iri, new_origin_uri, old_origin_uri) );

  if (coalesce (new_origin_login, '') <> coalesce (old_origin_login, '') and
    old_expiration is not null )
    signal ('RDFXX',
      sprintf ('Can not get-and-cache RDF graph <%.500s> from <%.500s> using %s because is has been loaded using %s',
        local_iri, new_origin_uri,
        case (isnull (new_origin_login)) when 0 then sprintf ('login "%.100s"', new_origin_login) else 'anonymous access' end,
        case (isnull (old_origin_login)) when 0 then sprintf ('login "%.100s"', old_origin_login) else 'anonymous access' end ) );

  -- dbg_obj_princ (' old_expiration=', old_expiration, ' old_exp_is_true=', old_exp_is_true, ' old_last_load=', old_last_load);
  -- dbg_obj_princ ('now()=', now(), ' explicit_refresh=', explicit_refresh);
  if (old_expiration is not null)
    {
      if ((old_expiration >= now()) and (
          explicit_refresh is null or
          old_exp_is_true or
          (dateadd ('second', explicit_refresh, old_last_load) >= now()) ) )
        {
          -- dbg_obj_princ ('not expired, return');
          update DB.DBA.SYS_HTTP_SPONGE
          set HS_LAST_READ = now(), HS_READ_COUNT = old_read_count + 1
          where HS_LOCAL_IRI = local_iri and HS_LAST_READ < now();
          commit work;
	  -- check here for dependant URLs
	  -- if some is expired or is dynamic, then treat the top page and rest as they changed
	  if (DB.DBA.SYS_HTTP_SPONGE_DEP_URL_NOT_CHNAGED (local_iri, parser, explicit_refresh))
            return local_iri;
	  else
	    old_last_etag := null;
        }
    }
  else -- either other loading is in progress or an recorded error
    {
      if (old_last_load >= now() and old_expiration is null)
        {
          -- dbg_obj_princ ('collision in the air, return');
          return local_iri; -- Nobody promised to resolve collisions in the air.
        }
    }

update_old_origin:
  -- dbg_obj_princ ('starting update old origin...');
  update DB.DBA.SYS_HTTP_SPONGE
  set HS_LAST_LOAD = now(), HS_LAST_ETAG = NULL, HS_LAST_READ = NULL,
    HS_EXP_IS_TRUE = 0, HS_EXPIRATION = NULL, HS_LAST_MODIFIED = NULL,
    HS_DOWNLOAD_SIZE = NULL, HS_DOWNLOAD_MSEC_TIME = NULL,
    HS_READ_COUNT = 0,
    HS_SQL_STATE = NULL, HS_SQL_MESSAGE = NULL
  where
    HS_LOCAL_IRI = local_iri and HS_PARSER = parser;
  commit work;
  goto perform_actual_load;

add_new_origin:
  -- dbg_obj_princ ('adding new origin...');
  old_origin_uri := NULL; old_origin_login := NULL; old_last_load := NULL; old_last_etag := NULL;
  old_expiration := NULL; old_download_size := NULL; old_download_msec_time := NULL;
  old_exp_is_true := 0; old_read_count := 0;
  insert into DB.DBA.SYS_HTTP_SPONGE (HS_LOCAL_IRI, HS_PARSER, HS_ORIGIN_URI, HS_ORIGIN_LOGIN, HS_LAST_LOAD)
  values (local_iri, parser, new_origin_uri, new_origin_login, now());
  commit work;
  goto perform_actual_load;

perform_actual_load:
  new_expiration := NULL;
  new_last_etag := NULL;
  ret_304_not_modified := 0;
  load_begin_msec := msec_time();
  set isolation='committed';
  commit work;
  get_method := cast (get_keyword_ucase ('get:method', options, 'GET') as varchar);
  if (get_method in ('POST', 'GET'))
    {
      req_hdr := NULL;
      get_proxy := get_keyword_ucase ('get:proxy', options);
      --!!!TBD: proper support for POST
      --!!!TBD: proper authentication if get:login / get:password is provided.
      --!!! XXX: if authentication is needed then better to use http_client() instead of http_get
      if ((old_last_etag is not null) and (explicit_refresh is null or (explicit_refresh >= 0)))
        req_hdr := 'If-None-Match: ' || old_last_etag;
      -- content negotiation
      -- Here we tell to the remote party we want rdf in some form, if it supports content negotiation
      -- then it may return rdf instead of html
      req_hdr := req_hdr || case when length (req_hdr) > 0 then '\r\n' else '' end
        || 'User-Agent: OpenLink Virtuoso RDF crawler\r\n'
	|| 'Accept: application/rdf+xml, text/rdf+n3, application/rdf+turtle, application/x-turtle, application/turtle, application/xml, */*';
      -- dbg_obj_princ ('Calling http_get (', new_origin_uri, ',..., ', get_method, req_hdr, NULL, get_proxy, ')');
      --ret_body := http_get (new_origin_uri, ret_hdr, get_method, req_hdr, NULL, get_proxy);
      ret_body := DB.DBA.RDF_HTTP_URL_GET (new_origin_uri, '', ret_hdr, get_method, req_hdr, NULL, get_proxy, 0);
      -- dbg_obj_princ ('http_get returned header: ', ret_hdr);
      if (ret_hdr[0] like 'HTTP%404%')
        signal ('HT404', sprintf ('Resource "%.1000s" not found', new_origin_uri));
      if (ret_hdr[0] like 'HTTP%304%')
        {
          ret_304_not_modified := 1;
          goto resp_received;
        }
      goto resp_received;
    }
--!!!TBD: if (get_method = ('MGET')) { ... }
  call (eraser) (local_iri, new_origin_uri, options);
  signal ('RDFZZ', sprintf (
      'Unable to get data from "%.1000s": This version of Virtuoso does not support OPTION (get:method "%.100s")',
         new_origin_uri, get_method ) );

resp_received:
--- resolve the caching params
   DB.DBA.SYS_HTTP_SPONGE_GET_CACHE_PARAMS (explicit_refresh, old_last_modified, ret_hdr, new_expiration,
       ret_content_type, ret_etag, ret_date, ret_expires, ret_last_modif,
       ret_dt_date, ret_dt_expires, ret_dt_last_modified);

  if (ret_304_not_modified)
    {
      update DB.DBA.SYS_HTTP_SPONGE
      set HS_LAST_LOAD = now(), HS_LAST_ETAG = old_last_etag, HS_LAST_READ = now(),
        HS_EXP_IS_TRUE = case (isnull (ret_dt_expires)) when 1 then 0 else 1 end,
        HS_EXPIRATION = coalesce (ret_dt_expires, new_expiration, now()),
        HS_LAST_MODIFIED = coalesce (old_last_modified, ret_dt_last_modified),
        HS_DOWNLOAD_SIZE = old_download_size,
        HS_DOWNLOAD_MSEC_TIME = old_download_msec_time,
        HS_READ_COUNT = old_read_count + 1,
        HS_SQL_STATE = NULL, HS_SQL_MESSAGE = NULL
      where
        HS_LOCAL_IRI = local_iri;
      commit work;
      return local_iri;
    }
  if (ret_body is null)
    signal ('RDFXX', sprintf ('Unable to retrieve RDF data from "%.500s": %.500s', new_origin_uri, ret_hdr[0]));
  --!!!TBD: proper character set handling in response
  new_download_size := length (ret_body);

  if (__tag (ret_body) = 185)
    ret_body := string_output_string (subseq (ret_body, 0, 10000000));

  {
  whenever sqlstate '*' goto error_during_load;
  parser_rc := 0;
  req_hdr_arr := DB.DBA.RDF_HTTP_MAKE_HTTP_REQ (new_origin_uri, get_method, req_hdr);
  parser_rc := call (parser) (local_iri, new_origin_uri, ret_content_type, ret_hdr, ret_body, options, req_hdr_arr);

  if (parser_rc)
    new_last_etag := ret_etag;
  else
    new_last_etag := null;

  load_end_msec := msec_time();
  if (new_expiration is null)
    new_expiration := dateadd ('second', load_end_msec - load_begin_msec, now()); -- assuming that expiration is at least 1000 times larger than load time.
  if (ret_dt_expires is null and explicit_refresh is not null)
    new_expiration := __min (new_expiration, dateadd ('second', 0.7 * explicit_refresh, now()));
  commit work;
  update DB.DBA.SYS_HTTP_SPONGE
  set HS_LAST_LOAD = now(), HS_LAST_ETAG = new_last_etag, HS_LAST_READ = now(),
    HS_EXP_IS_TRUE = case (isnull (ret_dt_expires)) when 1 then 0 else 1 end,
    HS_EXPIRATION = coalesce (ret_dt_expires, new_expiration, now()),
    HS_LAST_MODIFIED = ret_dt_last_modified,
    HS_DOWNLOAD_SIZE = new_download_size,
    HS_DOWNLOAD_MSEC_TIME = load_end_msec - load_begin_msec,
    HS_READ_COUNT = 1,
    HS_SQL_STATE = NULL, HS_SQL_MESSAGE = NULL
  where
    HS_LOCAL_IRI = local_iri and HS_PARSER = parser;
  commit work;
  return local_iri;
  }

error_during_load:
  rollback work;
  -- dbg_obj_princ ('error during load: ', __SQL_STATE, __SQL_MESSAGE);

  load_end_msec := msec_time();
  if (new_expiration is null)
    new_expiration := dateadd ('second', load_end_msec - load_begin_msec, now());
  if (ret_dt_expires is null and explicit_refresh is not null)
    new_expiration := __min (new_expiration, dateadd ('second', 0.7 * explicit_refresh, now()));

  update DB.DBA.SYS_HTTP_SPONGE
  set HS_SQL_STATE = __SQL_STATE,
    HS_SQL_MESSAGE = __SQL_MESSAGE,
    HS_EXPIRATION = coalesce (ret_dt_expires, new_expiration, now()),
    HS_EXP_IS_TRUE = case (isnull (ret_dt_expires)) when 1 then 0 else 1 end
  where
    HS_LOCAL_IRI = local_iri and HS_PARSER = parser;
  commit work;
  return local_iri;
}
;

-- /* handle local files */

create function DB.DBA.SYS_FILE_SPONGE_UP (in local_iri varchar, in get_uri varchar, in parser varchar, in eraser varchar, in options any)
{
  declare new_origin_uri, str, base_uri, mime_type, dummy, tmp any;
  declare inx int;
  new_origin_uri := cast (get_keyword_ucase ('get:uri', options, get_uri) as varchar);
  inx := 5;
  base_uri := local_iri;
  base_uri := charset_recode (base_uri, 'UTF-8', NULL);
  while (length (base_uri) > inx + 1 and aref (base_uri, inx) = ascii ('/'))
    inx := inx + 1;
  str := file_to_string (concat (http_root(), '/' , subseq (base_uri, inx)));
  dummy := vector ();
  tmp := vector ('OK');
  mime_type := null;
  DB.DBA.RDF_LOAD_HTTP_RESPONSE (local_iri, new_origin_uri, mime_type, tmp, str, options, dummy);
  return local_iri;
}
;
-- /* guess the content type */

create function DB.DBA.RDF_SPONGE_GUESS_CONTENT_TYPE (in origin_uri varchar, in ret_content_type varchar, inout ret_body any) returns varchar
{
  if (ret_content_type is not null)
    {
      if (strstr (ret_content_type, 'application/sparql-results+xml') is not null)
        return 'application/sparql-results+xml';
      if (strstr (ret_content_type, 'application/rdf+xml') is not null)
        return 'application/rdf+xml';
      if (
        strstr (ret_content_type, 'text/rdf+n3') is not null or
        strstr (ret_content_type, 'application/x-turtle') is not null or
        strstr (ret_content_type, 'application/turtle') is not null )
        return 'text/rdf+n3';
    }
  declare ret_begin, ret_html any;
  ret_begin := "LEFT" (ret_body, 1024);
  ret_html := xtree_doc (ret_begin, 2);
  if (xpath_eval ('/html|/xhtml', ret_html) is not null)
    return 'text/html';
  if (xpath_eval ('[xmlns:rset="http://www.w3.org/2005/sparql-results#"] /rset:sparql', ret_html) is not null
    or xpath_eval ('[xmlns:rset2="http://www.w3.org/2001/sw/DataAccess/rf1/result2"] /rset2:sparql', ret_html) is not null)
    return 'application/sparql-results+xml';
  if (xpath_eval ('[xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"] /rdf:rdf', ret_html) is not null)
    return 'application/rdf+xml';
  if (strstr (ret_begin, '<html>') is not null or
    strstr (ret_begin, '<xhtml>') is not null )
    return 'text/html';
  if (ret_content_type is null or
    strstr (ret_content_type, 'text/plain') is not null or
    strstr (ret_content_type, 'application/octet-stream') is not null )
    {
      declare ret_lines any;
      declare ret_lcount, ret_lctr integer;
      ret_lines := split_and_decode (ret_begin, 0, '\0\t\n');
      ret_lcount := length (ret_lines);
      for (ret_lctr := 0; ret_lctr < ret_lcount; ret_lctr := ret_lctr + 1)
        {
          declare l varchar;
          l := rtrim (replace (ret_lines [ret_lctr], '\r', ''));
          -- dbg_obj_princ ('l = ', l);
          if (("LEFT" (l, 7) = '@prefix') or ("LEFT" (l, 5) = '@base') or ("LEFT" (l, 8) = '@keyword'))
            return 'text/rdf+n3';
          if ((("LEFT" (l, 1) = '<') or ("LEFT" (l, 1) = '[')) and ("RIGHT" (origin_uri, 4) in ('.ttl', '.TTL', '.n3', '.N3')))
            return 'text/rdf+n3';
          if (not ((l like '#%') or (l='')))
            return 'text/plain';
        }
    }
  return ret_content_type;
}
;

-- Additional RDF mappers defined elsewhere
create table DB.DBA.SYS_RDF_MAPPERS (
    RM_ID integer identity,		-- an ordered id for execution order
    RM_PATTERN varchar,			-- a LIKE pattern, URL or MIME
    RM_TYPE varchar default 'MIME', 	-- pattern type, MIME or URL
    RM_HOOK varchar,			-- PL hook
    RM_KEY  long varchar,		-- API specific key to use
    RM_DESCRIPTION long varchar,
    RM_ENABLED integer default 1,
    RM_OPTIONS any,
    RM_PID integer identity,		-- permanent id for fk in application tables
    primary key (RM_TYPE, RM_PATTERN))
create index SYS_RDF_MAPPERS_I1 on DB.DBA.SYS_RDF_MAPPERS (RM_ID)
create index SYS_RDF_MAPPERS_I2 on DB.DBA.SYS_RDF_MAPPERS (RM_PID)
;

--#IF VER=5
--!AFTER
alter table DB.DBA.SYS_RDF_MAPPERS add RM_ENABLED integer default 1
;

--!AFTER
alter table DB.DBA.SYS_RDF_MAPPERS add RM_OPTIONS any
;

--!AFTER
alter table DB.DBA.SYS_RDF_MAPPERS add RM_PID integer identity
;

--!AFTER
alter table DB.DBA.SYS_RDF_MAPPERS add RM_PID integer identity
;

--!AFTER
create procedure DB.DBA.SYS_RDF_MAPPERS_UPGRADE ()
{
  declare id int;
  update DB.DBA.SYS_RDF_MAPPERS set RM_PID = RM_ID where RM_PID is null;
  if (row_count() = 0)
    return;
  id := (select max (RM_PID) from DB.DBA.SYS_RDF_MAPPERS) + 1;
  DB.DBA.SET_IDENTITY_COLUMN ('DB.DBA.SYS_RDF_MAPPERS', 'RM_PID', id);
}
;

--!AFTER
DB.DBA.SYS_RDF_MAPPERS_UPGRADE ()
;
--#ENDIF

create procedure DB.DBA.RDF_HTTP_URL_GET (inout url any, in base any, inout hdr any,
	in meth any := 'GET', in req_hdr varchar := null, in cnt any := null, in proxy any := null, in sig int := 1)
{
  declare content varchar;
  declare olduri varchar;
  --declare hdr any;
  declare redirects, is_https int;
  -- dbg_obj_princ ('DB.DBA.RDF_HTTP_URL_GET (', url, base, ')');

  hdr := null;
  redirects := 15;
  url := WS.WS.EXPAND_URL (base, url);
  again:
  olduri := url;
  if (redirects <= 0)
    signal ('22023', 'Too many HTTP redirects', 'RDFXX');

  if (lower (url) like 'https://%' and proxy is not null)
    signal ('22023', 'The HTTPS retrieval is not supported via proxy', 'RDFXX');
  is_https := 0;
  if (lower (url) like 'https://%')
    is_https := 1;

  if (is_https)
    content := http_client_ext (url=>url, headers=>hdr, http_method=>meth, http_headers=>req_hdr, body=>cnt);
  else
    content := http_get (url, hdr, meth, req_hdr, cnt, proxy);
  redirects := redirects - 1;

  if (hdr[0] not like 'HTTP/1._ 200 %')
    {
      if (hdr[0] like 'HTTP/1._ 30_ %')
	{
	  url := http_request_header (hdr, 'Location');
	  if (isstring (url))
	    {
	      url := WS.WS.EXPAND_URL (olduri, url);
	      goto again;
	    }
	}
      if (sig)
        signal ('22023', trim(hdr[0], '\r\n'), 'RDFXX');
      -- dbg_obj_princ ('DB.DBA.RDF_HTTP_URL_GET (', url, base, ') failed to download ', url);
      return NULL;
    }
  -- dbg_obj_princ ('DB.DBA.RDF_HTTP_URL_GET (', url, base, ') downloaded ', url);
  return content;
}
;

-- /* async ping of a web service e.g. PTSW */
create procedure DB.DBA.RDF_SW_PING (in endp varchar, in url varchar)
{
  declare rc any;
  declare err, msg any;
  commit work;
  declare exit handler for sqlstate '*'
  {
    insert into DB.DBA.SYS_SPARQL_SW_LOG (PL_SERVER, PL_URI, PL_RC, PL_MSG)
	values (endp, url, __SQL_STATE, __SQL_MESSAGE);
    commit work;
    return;
  };
  rc := DB.DBA.XMLRPC_CALL (endp, 'weblogUpdates.ping', vector ('', url));
  err := '';
  msg := 'n/a';
  if (isarray (rc))
    {
      declare xt any;
      xt := xml_tree_doc (rc);
      err := cast (xpath_eval ('//flerror/text()', xml_cut(xt), 1) as varchar);
      msg := cast (xpath_eval ('//message/text()', xml_cut(xt), 1) as varchar);
    }
  insert into DB.DBA.SYS_SPARQL_SW_LOG (PL_SERVER, PL_URI, PL_RC, PL_MSG)
    values (endp, url, err, msg);
--  dbg_obj_print ('DB.DBA.RDF_SW_PING end', endp, ' ', url);
  commit work;
  return;
}
;

create procedure DB.DBA.RDF_PROC_COLS (in pname varchar)
{
  set_user_id ('dba', 1);
  return procedure_cols (pname);
}
;

-- /* Load the document in tripple store. returns 1 if the document is an RDF , otherwise if it has links etc. it returns 0 */
create procedure DB.DBA.RDF_LOAD_HTTP_RESPONSE (in graph_iri varchar, in new_origin_uri varchar, inout ret_content_type varchar, inout ret_hdr any, inout ret_body any, inout options any, inout req_hdr_arr any)
{
  declare dest, groupdest varchar;
  declare rc any;
  declare aq, ps any;
  declare xd, xt any;
  declare saved_log_mode integer;
  aq := null;
  ps := cfg_item_value (virtuoso_ini_path (), 'SPARQL', 'PingService');
  if (length (ps))
    {
      aq := async_queue (1);
    }
  --!!!TBD: proper calculation of new_expiration, usingdata from HTTP header of the response
  ret_content_type := DB.DBA.RDF_SPONGE_GUESS_CONTENT_TYPE (new_origin_uri, ret_content_type, ret_body);
  -- dbg_obj_princ ('ret_content_type is ', ret_content_type);
  dest := get_keyword_ucase ('get:destination', options);
  groupdest := get_keyword_ucase ('get:group-destination', options);
  if (strstr (ret_content_type, 'application/sparql-results+xml') is not null)
    signal ('RDFXX', sprintf ('Unable to load RDF graph <%.500s> from <%.500s>: the sparql-results XML answer does not contain triples', graph_iri, new_origin_uri));
  if (strstr (ret_content_type, 'application/rdf+xml') is not null)
    {
      if (dest is null)
        DB.DBA.SPARUL_CLEAR (coalesce (dest, graph_iri), 1);
      -- delete from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (dest);
      whenever sqlstate '*' goto resignal_parse_error;
      log_enable (2, 1);
      xt := xtree_doc (ret_body);
      -- we test for GRDDL inside RDF/XML, if so do it inside mappers, else it will fail because of dv:transformation attr
      if (xpath_eval ('[ xmlns:dv="http://www.w3.org/2003/g/data-view#" ] /*[1]/@dv:transformation', xt) is not null)
	goto load_grddl;
      DB.DBA.RDF_LOAD_RDFXML (ret_body, new_origin_uri, coalesce (dest, graph_iri));
      if (groupdest is not null)
        DB.DBA.RDF_LOAD_RDFXML (ret_body, new_origin_uri, groupdest);
      log_enable (saved_log_mode, 1);
      if (aq is not null)
        aq_request (aq, 'DB.DBA.RDF_SW_PING', vector (ps, new_origin_uri));
      return 1;
    }
  else if (
       strstr (ret_content_type, 'text/rdf+n3') is not null or strstr (ret_content_type, 'text/rdf+ttl') is not null or
       strstr (ret_content_type, 'application/rdf+n3') is not null or strstr (ret_content_type, 'application/rdf+turtle') is not null or
       strstr (ret_content_type, 'application/turtle') is not null or strstr (ret_content_type, 'application/x-turtle') is not null
     )
    {
      whenever sqlstate '*' goto resignal_parse_error;
      log_enable (2, 1);
      if (dest is null)
        DB.DBA.SPARUL_CLEAR (coalesce (dest, graph_iri), 1);
      -- delete from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (dest);
      DB.DBA.TTLP (ret_body, new_origin_uri, coalesce (dest, graph_iri));
      if (groupdest is not null)
        DB.DBA.TTLP (ret_body, new_origin_uri, groupdest);
      log_enable (saved_log_mode, 1);
      if (aq is not null)
        aq_request (aq, 'DB.DBA.RDF_SW_PING', vector (ps, new_origin_uri));
      return 1;
    }

  if (dest is null)
    {
      DB.DBA.SPARUL_CLEAR (graph_iri, 1);
      commit work;
    }
load_grddl:;
  for select RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_OPTIONS from DB.DBA.SYS_RDF_MAPPERS where RM_ENABLED = 1 order by RM_ID do
    {
      declare val_match, pcols, new_opts any;
      declare npars int;

      if (RM_TYPE = 'MIME')
	{
	  val_match := ret_content_type;
	}
      else if (RM_TYPE = 'URL' or RM_TYPE = 'HTTP')
	{
	  val_match := new_origin_uri;
	}
      else
	val_match := null;

      if (registry_get ('__sparql_mappers_debug') = '1')
	dbg_printf ('Trying %s', RM_HOOK);
      if (isstring (val_match) and regexp_match (RM_PATTERN, val_match) is not null)
	{
	  if (__proc_exists (RM_HOOK) is null)
	    goto try_next_mapper;

	  declare exit handler for sqlstate '*'
	    {
	      goto try_next_mapper;
	    };
          pcols := DB.DBA.RDF_PROC_COLS (RM_HOOK);
          npars := 8;
          if (isarray (pcols))
	    npars := length (pcols);
	  --!!!TBD: Carefully check what happens when dest is NULL vs dest is nonNULL, then add support for groupdest.
          if (registry_get ('__sparql_mappers_debug') = '1')
	    dbg_printf ('Match %s', RM_HOOK);
	  new_opts := vector_concat (options, RM_OPTIONS, vector ('content-type', ret_content_type));
	  if (RM_TYPE <> 'HTTP')
	    {
	      if (npars = 7)
	        rc := call (RM_HOOK) (graph_iri, new_origin_uri, dest, ret_body, aq, ps, RM_KEY);
	      else
	        rc := call (RM_HOOK) (graph_iri, new_origin_uri, dest, ret_body, aq, ps, RM_KEY, new_opts);
	    }
          else
	    {
	      if (npars = 7)
	        rc := call (RM_HOOK) (graph_iri, new_origin_uri, dest, ret_body, aq, ps, vector (req_hdr_arr, ret_hdr));
	      else
	        rc := call (RM_HOOK) (graph_iri, new_origin_uri, dest, ret_body, aq, ps, vector (req_hdr_arr, ret_hdr), new_opts);
	    }
          if (registry_get ('__sparql_mappers_debug') = '1')
	    {
	      dbg_printf ('Return [%d] %s', rc, RM_HOOK);
	      if (rc < 0 or rc > 0)
	        dbg_printf ('END of mappings');
	    }
	  if (rc < 0)
	    return 0;
	  else if (rc > 0)
	    return 1;
	}
      try_next_mapper:;
    }

  -- else if not handled with the above cases
  --xd := DAV_EXTRACT_META_AS_RDF_XML (new_origin_uri, ret_body);
  --if (xd is not null)
  --  {
      -- DB.DBA.SPARUL_CLEAR (dest, 1);
  --    DB.DBA.RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
  --    if (groupdest is not null)
  --      DB.DBA.RDF_LOAD_RDFXML (xd, new_origin_uri, groupdest);
  --    return 1;
  --  }
  if (dest is null)
    {
      DB.DBA.SPARUL_CLEAR (graph_iri, 1);
      commit work;
    }
  if (strstr (ret_content_type, 'text/plain') is not null)
    {
      signal ('RDFXX', sprintf (
          'Unable to load RDF graph <%.500s> from <%.500s>: returned Content-Type ''%.300s'' status ''%.300s''\n%.500s',
          graph_iri, new_origin_uri, ret_content_type, ret_hdr[0], "LEFT" (ret_body, 500) ) );
    }
  if (strstr (ret_content_type, 'text/html') is not null)
    {
      signal ('RDFZZ', sprintf (
          'Unable to load RDF graph <%.500s> from <%.500s>: returned Content-Type ''%.300s'' status ''%.300s''\n%.500s',
          graph_iri, new_origin_uri, ret_content_type, ret_hdr[0],
          "LEFT" (cast (xtree_doc (ret_body, 2) as varchar), 500) ) );
    }
  signal ('RDFZZ', sprintf (
      'Unable to load RDF graph <%.500s> from <%.500s>: returned unsupported Content-Type ''%.300s''',
      graph_iri, new_origin_uri, ret_content_type ) );
resignal_parse_error:
  log_enable (saved_log_mode, 1);
  resignal;
}
;

create procedure DB.DBA.RDF_FORGET_HTTP_RESPONSE (in graph_iri varchar, in new_origin_uri varchar, inout options any)
{
  declare dest varchar;
  dest := get_keyword_ucase ('get:destination', options);
  if (dest is null)
    DB.DBA.SPARUL_CLEAR (graph_iri, 1);
}
;

create function DB.DBA.RDF_SPONGE_UP (in graph_iri varchar, in options any)
{
  declare dest, get_soft, local_iri, immg, res_graph_iri varchar;
  -- dbg_obj_princ ('DB.DBA.RDF_SPONGE_UP (', graph_iri, options, ')');
  set_user_id ('dba', 1);
  dest := get_keyword_ucase ('get:destination', options);
  if (dest is not null)
    local_iri := 'destMD5=' || md5(dest) || '&graphMD5=' || md5(graph_iri);
  else
    dest := local_iri := graph_iri;
  -- dbg_obj_princ ('DB.DBA.RDF_SPONGE_UP (', graph_iri, options, ') set local_iri=', local_iri);
  get_soft := get_keyword_ucase ('get:soft', options);
  if ('soft' = get_soft)
    {
      if ((dest = graph_iri) and
        exists (select top 1 1 from DB.DBA.RDF_QUAD table option (index RDF_QUAD)
          where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (graph_iri) ) and
        not exists (select top 1 1 from DB.DBA.SYS_HTTP_SPONGE
          where HS_LOCAL_IRI = local_iri and HS_PARSER = 'DB.DBA.RDF_LOAD_HTTP_RESPONSE' and
	  HS_EXPIRATION is not null))
        {
          -- dbg_obj_princ ('Exists and get:soft=soft, leaving');
          res_graph_iri := local_iri;
          goto graph_is_ready;
        }
    }
  else
    if ('replacing' = get_soft)
      {
        -- dbg_obj_princ ('get:soft=replacing');
        ;
      }
  else
    signal ('RDFZZ', sprintf (
      'This version of Virtuoso supports only "soft" and "replacing" values of "define get:soft ...", not "%.500s"',
      get_soft ) );
  -- if requested iri is immutable, don't try to get it at all
  -- this is to preserve rdf storage in certain cases
  immg := cfg_item_value (virtuoso_ini_path (), 'SPARQL', 'ImmutableGraphs');
  if (immg is not null)
    {
      immg := split_and_decode (immg, 0, '\0\0,');
      foreach (any imm in immg) do
        {
	  imm := trim (imm);
	  if (imm = dest)
            {
              res_graph_iri := dest;
              goto graph_is_ready;
            }
	}
    }
  if (lower (graph_iri) like 'file:%')
    {
      res_graph_iri := DB.DBA.SYS_FILE_SPONGE_UP (local_iri, graph_iri, null, 'DB.DBA.RDF_FORGET_HTTP_RESPONSE', options);
      goto graph_is_ready;
    }
  else if (lower (graph_iri) like 'http:%' or lower (graph_iri) like 'https:%')
    {
      res_graph_iri := DB.DBA.SYS_HTTP_SPONGE_UP (local_iri, graph_iri, 'DB.DBA.RDF_LOAD_HTTP_RESPONSE', 'DB.DBA.RDF_FORGET_HTTP_RESPONSE', options);
      goto graph_is_ready;
    }
  else
    {
      declare sch any;
      sch := rfc1808_parse_uri (graph_iri);
      sch := upper (sch[0]);
      if (__proc_exists ('DB.DBA.SYS_'||sch||'_SPONGE_UP') is not null)
        {
	  res_graph_iri := call ('DB.DBA.SYS_'||sch||'_SPONGE_UP') (local_iri, graph_iri, options);
          goto graph_is_ready;
        }
      else
	{
	  signal ('RDFZZ', sprintf ('This version of Virtuoso Sponger do not support "%s" IRI scheme (IRI "%.1000s")', lower(sch), graph_iri));
	}
    }
graph_is_ready:
  if (__rdf_obj_ft_rule_check (iri_to_id (res_graph_iri), null) and
    get_keyword ('refresh_free_text', options, 0) )
    VT_INC_INDEX_DB_DBA_RDF_OBJ();
  return res_graph_iri;
}
;

create function DB.DBA.RDF_SPONGE_UP_LIST (in sources any)
{
  declare need_reindex integer;
  declare aq any;
  need_reindex := 0;
  aq := async_queue (8);
  foreach (any src in sources) do
    {
      declare res_graph_iri any;
      res_graph_iri := DB.DBA.RDF_SPONGE_UP (src[0], vector_concat (vector ('refresh_free_text', 0), src[1]));
      if (__rdf_obj_ft_rule_check (iri_to_id (res_graph_iri), null) and
        get_keyword ('refresh_free_text', src[1], 0) )
      need_reindex := 1;
    }
  if (need_reindex)
    VT_INC_INDEX_DB_DBA_RDF_OBJ();
  return 1;
}

-----
-- Free text index on DB.DBA.RDF_OBJ

create function DB.DBA.VT_DECODE_KEYWORD_ITM (inout vtdata varchar, inout ofs integer)
{
  declare res integer;
  if ((5 <> vtdata[ofs]) or (0 <> vtdata[ofs+5]))
    signal ('23023', 'Invalid VT_WORD data in DB.DBA.VT_DECODE_KEYWORD_ITM');
  res := (((vtdata[ofs+1] * 256) + vtdata[ofs+2]) * 256 + vtdata[ofs+3]) * 256 + vtdata[ofs+4];
  ofs := ofs + 6;
  return res;
}
;

create procedure DB.DBA.VT_ENCODE_KEYWORD_ITM (in id integer, inout ses any)
{
  declare strg varchar;
  strg := '012345';
  strg[5] := 0;
  strg[4] := bit_and (id, 255); id := bit_shift (id, -8);
  strg[3] := bit_and (id, 255); id := bit_shift (id, -8);
  strg[2] := bit_and (id, 255); id := bit_shift (id, -8);
  strg[1] := bit_and (id, 255); if (id > 255) signal ('22023', 'Abnormally big document id in DB.DBA.VT_ENCODE_KEYWORD_ITM');
  strg[0] := 5;
  http (strg, ses);
}
;

create function DB.DBA.VT_COMPOSE_KEYWORD_INDEX_LINES (
  inout carry_d_id integer, -- Smallest doc id of carry
  inout carry_d_id_2 integer, -- largest doc id of carry
  inout carry_data varchar, -- carry as ready-to-insert varchar data
  in old_d_id integer, -- last read VT_D_ID, NULL when not found
  in old_d_id_2 integer, -- last read VT_D_ID_2, NULL when not found
  in old_data varchar, -- last read VT_DATA, NULL when not found
  inout ro_id_offset integer,	-- offset of first not-yet-used new id
  inout new_ro_ids any )	-- array of all new ids
  returns any -- returns vector of vector (d_id, d_id_2, data) of everything before or at current
{
  declare res_acc, mix_ses any;
  declare old_data_ofs, old_data_len, old_curr_id, mix_id integer;
  declare new_ro_id_idx, new_ro_ids_count, mix_d_id, mix_d_id_2, mix_count integer;
  -- dbg_obj_princ ('DB.DBA.VT_COMPOSE_KEYWORD_INDEX_LINES (', carry_d_id, carry_d_id_2, length (carry_data), ' bytes,', old_d_id, old_d_id_2, length (old_data), ' bytes,', ro_id_offset, length (new_ro_ids), ' items)');
  vectorbld_init (res_acc);
  mix_ses := string_output();
  if (carry_data <> '')
    {
      mix_d_id := carry_d_id;
      mix_d_id_2 := carry_d_id_2;
      http (carry_data, mix_ses);
      mix_count := length (carry_data) / 6;
    }
  else
    {
      mix_d_id := null;
      mix_d_id_2 := null;
      mix_count := 0;
    }
  old_data_ofs := 0;
  if (old_data is null)
    old_curr_id := null;
  else
    old_curr_id := DB.DBA.VT_DECODE_KEYWORD_ITM (old_data, old_data_ofs);
  old_data_len := length (old_data);
  new_ro_ids_count := length (new_ro_ids);
  new_ro_id_idx := ro_id_offset;
  if (new_ro_id_idx < new_ro_ids_count)
    mix_id := new_ro_ids [new_ro_id_idx];
  else
    mix_id := null;
  -- dbg_obj_princ ('DB.DBA.VT_COMPOSE_KEYWORD_INDEX_LINES starts/1: ', mix_d_id, old_curr_id, mix_id);
  mix_d_id := __min_notnull (mix_d_id, old_curr_id, mix_id);
  -- dbg_obj_princ ('DB.DBA.VT_COMPOSE_KEYWORD_INDEX_LINES starts/2: ', mix_d_id);

next_mix:
  if (old_curr_id is null)
    {
      if ((new_ro_id_idx >= new_ro_ids_count) or (new_ro_ids [new_ro_id_idx] > old_d_id_2))
        goto complete;
      mix_id := new_ro_ids [new_ro_id_idx];
      new_ro_id_idx := new_ro_id_idx + 1;
    }
  else
    {
      if ((new_ro_id_idx >= new_ro_ids_count) or (new_ro_ids [new_ro_id_idx] >= old_curr_id))
        {
          if ((new_ro_id_idx < new_ro_ids_count) and (new_ro_ids [new_ro_id_idx] = old_curr_id))
            new_ro_id_idx := new_ro_id_idx + 1;
          mix_id := old_curr_id;
          if (old_data_ofs >= old_data_len)
            old_curr_id := null;
          else
            old_curr_id := DB.DBA.VT_DECODE_KEYWORD_ITM (old_data, old_data_ofs);
        }
      else
        {
          mix_id := new_ro_ids [new_ro_id_idx];
          new_ro_id_idx := new_ro_id_idx + 1;
        }
    }
  if ((mix_count > 180) or ((mix_d_id_2 / 10000) <> (mix_id  / 10000)))
    {
      -- dbg_obj_princ ('DB.DBA._COMPOSE_KEYWORD_INDEX_LINES completed a row from ', mix_d_id, ' to ', mix_d_id_2);
      vectorbld_acc (res_acc, vector (mix_d_id, mix_d_id_2, string_output_string (mix_ses)));
      mix_ses := string_output ();
      mix_d_id := mix_id;
      mix_count := 0;
    }
  DB.DBA.VT_ENCODE_KEYWORD_ITM (mix_id, mix_ses);
  mix_d_id_2 := mix_id;
  mix_count := mix_count + 1;
  goto next_mix;

complete:
  ro_id_offset := new_ro_id_idx;
  if (mix_count > 150)
    {
      -- dbg_obj_princ ('DB.DBA._COMPOSE_KEYWORD_INDEX_LINES completed (last) row from ', mix_d_id, ' to ', mix_d_id_2);
      vectorbld_acc (res_acc, vector (mix_d_id, mix_d_id_2, string_output_string (mix_ses)));
      carry_data := '';
      carry_d_id := carry_d_id_2 := null;
    }
  else
    {
      carry_data := string_output_string (mix_ses);
      carry_d_id := mix_d_id;
      carry_d_id_2 := mix_d_id_2;
    }
  vectorbld_final (res_acc);
  -- dbg_obj_princ ('DB.DBA._COMPOSE_KEYWORD_INDEX_LINES completed, carry ', carry_d_id, carry_d_id_2, length (carry_data), ' bytes, res ', res_acc);
  return res_acc;
}
;

--!AWK PUBLIC
create function DB.DBA.RDF_OBJ_PATCH_CONTAINS_BY_GRAPH (in phrase varchar, in graph_iri varchar)
{
  declare graph_keyword any;
  whenever sqlstate '*' goto err;
  graph_keyword := iri_to_id (graph_iri, 0, 0);
  if (isinteger (graph_keyword))
    goto err;
  graph_keyword := WS.WS.STR_SQL_APOS (cast (graph_keyword as varchar));
  return sprintf ('^%s AND (%s)', graph_keyword, phrase);
err:
  return '^"#nosuch"';
}
;

--!AWK PUBLIC
create function DB.DBA.RDF_OBJ_PATCH_CONTAINS_BY_MANY_GRAPHS (in phrase varchar, in graph_iris any)
{
  declare isfirst, gctr, gcount integer;
  declare ses, graph_keyword any;
  whenever sqlstate '*' goto err;
  gcount := length (graph_iris);
  ses := string_output ();
  isfirst := 1;
  for (gctr := 0; gctr < gcount; gctr := gctr + 1)
    {
      graph_keyword := iri_to_id (graph_iris[gctr], 0, 0);
      if (not isinteger (graph_keyword))
        {
          if (isfirst)
            {
              http ('^', ses);
              isfirst := 0;
            }
          else
            http (' OR ^', ses);
          http (WS.WS.STR_SQL_APOS (cast (graph_keyword as varchar)), ses);
        }
    }
  if (not isfirst)
    return sprintf ('(%s) AND (%s)', string_output_string (ses), phrase);
err:
  return '^"#nosuch"';
}
;

create procedure DB.DBA.RDF_OBJ_ADD_KEYWORD_FOR_GRAPH (in graph_iid IRI_ID, inout ro_id_dict any)
{
  declare ro_id_offset, ro_ids_count integer;
  declare new_ro_ids, vtb any;
  declare gwordump varchar;
  declare n_w, n_ins, n_upd, n_next integer;
  new_ro_ids := dict_list_keys (ro_id_dict, 2);
  ro_ids_count := length (new_ro_ids);
  if (0 = ro_ids_count)
    return;
  gwordump := ' ' || cast (graph_iid as varchar);
  gwordump[0] := length (gwordump) - 1;
  gvector_digit_sort (new_ro_ids, 1, 0, 1);
  vtb := vt_batch (__min (__max (ro_ids_count, 31), 500000));
  commit work;
  whenever sqlstate '40001' goto retry_add;
again:
  for (ro_id_offset := 0; ro_id_offset < ro_ids_count; ro_id_offset := ro_id_offset + 1)
    {
      vt_batch_d_id (vtb, new_ro_ids[ro_id_offset]);
      vt_batch_feed_wordump (vtb, gwordump, 0);
    }
  "DB"."DBA"."VT_BATCH_PROCESS_DB_DBA_RDF_OBJ" (vtb);
  commit work;
  return;
retry_add:
  rollback work;
  goto again;
}
;

create procedure DB.DBA.RDF_OBJ_ADD_KEYWORD_FOR_GRAPH_OLD (in graph_iid IRI_ID, inout ro_id_dict any)
{
  declare start_vt_d_id, aligned_start_vt_d_id, uncommited_ro_id_offset, ro_id_offset, ro_ids_count integer;
  declare old_d_id, old_d_id_2, carry_d_id, carry_d_id_2 integer;
  declare old_data, carry_data varchar;
  declare split_ctr, split_len integer;
  declare dbg_smallest_d_id, dbg_largest_d_id, dbg_prev_d_id, dbg_prev_d_id_2 integer;
  declare split any;
  declare cr cursor for (
    select VT_D_ID, VT_D_ID_2, coalesce (VT_DATA, cast (VT_LONG_DATA as varchar)) from RDF_OBJ_RO_DIGEST_WORDS
    where (VT_WORD = cast (graph_iid as varchar)) and (VT_D_ID >= aligned_start_vt_d_id) and VT_D_ID_2 >= start_vt_d_id for update);
  declare new_ro_ids any;
  -- dbg_obj_princ ('DB.DBA.RDF_OBJ_ADD_KEYWORD_FOR_GRAPH (', graph_iid, ro_id_dict, ')');
  new_ro_ids := dict_list_keys (ro_id_dict, 2);
  ro_ids_count := length (new_ro_ids);
  if (0 = ro_ids_count)
    return;
  gvector_digit_sort (new_ro_ids, 1, 0, 1);
-- debug begin
  dbg_smallest_d_id := new_ro_ids[0];
  dbg_largest_d_id := new_ro_ids[length (new_ro_ids) - 1];
  dbg_prev_d_id := 0;
  dbg_prev_d_id_2 := 0;
-- debug end
  commit work;
  whenever sqlstate '40001' goto retry_add;
  uncommited_ro_id_offset := 0;
again:
  ro_id_offset := uncommited_ro_id_offset;
  start_vt_d_id := new_ro_ids[ro_id_offset];
  aligned_start_vt_d_id := ((start_vt_d_id / 10000) * 10000);
  carry_d_id := 0;
  carry_d_id_2 := 0;
  carry_data := '';
  set isolation = 'serializable';
  whenever not found goto no_more_olds;
  open cr (prefetch 1);

next_split:
  fetch cr into old_d_id, old_d_id_2, old_data;
  split := DB.DBA.VT_COMPOSE_KEYWORD_INDEX_LINES (carry_d_id, carry_d_id_2, carry_data, old_d_id, old_d_id_2, old_data, ro_id_offset, new_ro_ids);
  split_len := length (split);
  split_ctr := 0;
  if ((split_len > 0) and (split[split_len-1][0] = old_d_id))
    {
      if ((old_d_id_2 = split[split_len-1][1]) and (old_data = split[split_len-1][2]))
        { ; }
      else
        update RDF_OBJ_RO_DIGEST_WORDS set VT_D_ID_2 = split[split_len-1][1], VT_DATA = split[split_len-1][2], VT_LONG_DATA = null
      where current of cr;
      split_len := split_len - 1;
    }
  if (split_len > 0)
    {
      delete from RDF_OBJ_RO_DIGEST_WORDS
        where (VT_WORD = cast (graph_iid as varchar)) and (VT_D_ID >= split[0][0]) and (VT_D_ID_2 <= split[split_len-1][1]);
    }
  for (split_ctr := 0; split_ctr < split_len; split_ctr := split_ctr+1)
    {
      insert replacing RDF_OBJ_RO_DIGEST_WORDS (VT_WORD, VT_D_ID, VT_D_ID_2, VT_DATA)
      values (cast (graph_iid as varchar), split[split_ctr][0], split[split_ctr][1], split[split_ctr][2]);
    }
  if (carry_data = '')
    {
      commit work;
      uncommited_ro_id_offset := ro_id_offset;
      if (ro_id_offset >= ro_ids_count)
        {
          start_vt_d_id := 1024 * 65536 * 65536 * 65536; -- well, a big number
          goto no_more_olds;
        }
      start_vt_d_id := new_ro_ids[uncommited_ro_id_offset];
      aligned_start_vt_d_id := ((start_vt_d_id / 10000) * 10000);
      close cr;
      open cr (prefetch 1);
    }
  goto next_split;

no_more_olds:
  split := DB.DBA.VT_COMPOSE_KEYWORD_INDEX_LINES (carry_d_id, carry_d_id_2, carry_data, null, null, null, ro_id_offset, new_ro_ids);
  split_len := length (split);
  split_ctr := 0;
  if (split_len > 0)
    {
      delete from RDF_OBJ_RO_DIGEST_WORDS
        where (VT_WORD = cast (graph_iid as varchar)) and (VT_D_ID >= split[0][0]) and (VT_D_ID_2 <= split[split_len-1][1]);
    }
  for (split_ctr := 0; split_ctr < split_len; split_ctr := split_ctr+1)
    {
      insert replacing RDF_OBJ_RO_DIGEST_WORDS (VT_WORD, VT_D_ID, VT_D_ID_2, VT_DATA)
      values (cast (graph_iid as varchar), split[split_ctr][0], split[split_ctr][1], split[split_ctr][2]);
    }
  if (length (carry_data)  <> 0)
    {
      insert replacing RDF_OBJ_RO_DIGEST_WORDS (VT_WORD, VT_D_ID, VT_D_ID_2, VT_DATA)
      values (cast (graph_iid as varchar), carry_d_id, carry_d_id_2, carry_data);
    }
  commit work;
-- debug begin
--  for (
--    select VT_WORD, VT_D_ID, VT_D_ID_2, coalesce (VT_DATA, cast (VT_LONG_DATA as varchar)) as vtd from RDF_OBJ_RO_DIGEST_WORDS
--    where (VT_WORD = cast (graph_iid as varchar))
--      and (VT_D_ID >= ((dbg_smallest_d_id / 10000) * 10000))
--      and (VT_D_ID_2 >= (((dbg_largest_d_id + 9999) / 10000) * 10000)) ) do
--    {
--      if (VT_D_ID > VT_D_ID_2)
--        {
--          -- dbg_obj_princ ('FT BUG: misordered bounds: ', VT_WORD, VT_D_ID, VT_D_ID_2);
          -- raw_exit ();
--          ;
--        }
--      if (VT_D_ID <= dbg_prev_d_id_2)
--        {
--          -- dbg_obj_princ ('FT BUG: overlapping ranges: ', VT_WORD, VT_D_ID, VT_D_ID_2, '; prev is ', dbg_prev_d_id, dbg_prev_d_id_2);
           -- raw_exit ();
--          ;
--        }
--    }

  return;
retry_add:
  close cr;
  rollback work;
  goto again;
}
;

create function DB.DBA.RDF_OBJ_FT_RULE_ADD (in rule_g varchar, in rule_p varchar, in reason varchar) returns integer
{
  declare rule_g_iid, rule_p_iid IRI_ID;
  declare ro_id_dict any;
  if (rule_g is null)
    rule_g := '';
  if (rule_p is null)
    rule_p := '';
  rule_g_iid := case (rule_g) when '' then null else iri_to_id (rule_g, 1) end;
  rule_p_iid := case (rule_p) when '' then null else iri_to_id (rule_p, 1) end;
  if (reason is null)
    signal ('RDFXX', 'DB.DBA.RDF_OBJ_FT_RULE_ADD() expects string as argument 3');
  if (exists (
      select top 1 1 from DB.DBA.RDF_OBJ_FT_RULES
      where ROFR_G = rule_g and ROFR_P = rule_p and ROFR_REASON = reason))
    return 0;
  if (not exists (
      select top 1 1 from DB.DBA.RDF_OBJ_FT_RULES
      where (ROFR_G = rule_g or ROFR_G = '') and (ROFR_P = rule_p or ROFR_P = '') ) )
    {
      -- dbg_obj_princ ('DB.DBA.RDF_OBJ_FT_RULE_ADD: need scan');
      commit work;
      exec ('checkpoint');
      __atomic (1);
      declare exit handler for sqlstate '*' {
        __atomic (0);
        signal (__SQL_STATE, __SQL_MESSAGE); };
      if ((rule_g <> '') and (rule_p <> ''))
        {
          ro_id_dict := dict_new (100000);
          for (select O as obj from DB.DBA.RDF_QUAD where G=rule_g_iid and P=rule_p_iid and not isiri_id (O)) do
            {
              if (isstring (obj))
                {
                  DB.DBA.RDF_OBJ_ADD (257, obj, 257, ro_id_dict);
                  commit work;
                }
              else
                {
                  declare id integer;
                  id := rdf_box_ro_id (obj);
                  if (0 <> id)
                    {
                      update DB.DBA.RDF_OBJ set RO_DIGEST = obj where RO_ID = id and RO_DIGEST is null;
                      dict_put (ro_id_dict, id, 1);
                    }
                  commit work;
                }
              if (dict_size (ro_id_dict) > 100000)
                DB.DBA.RDF_OBJ_ADD_KEYWORD_FOR_GRAPH (iri_to_id (rule_g), ro_id_dict);
            }
          DB.DBA.RDF_OBJ_ADD_KEYWORD_FOR_GRAPH (iri_to_id (rule_g), ro_id_dict);
        }
      else if (rule_g <> '')
        {
          ro_id_dict := dict_new (100000);
          for (select O as obj from DB.DBA.RDF_QUAD where G=rule_g_iid and not isiri_id (O)) do
            {
              if (isstring (obj))
                {
                  DB.DBA.RDF_OBJ_ADD (257, obj, 257, ro_id_dict);
                  commit work;
                }
              else
                {
                  declare id integer;
                  id := rdf_box_ro_id (obj);
                  if (0 <> id)
                    {
                      update DB.DBA.RDF_OBJ set RO_DIGEST = obj where RO_ID = id and RO_DIGEST is null;
                      dict_put (ro_id_dict, id, 1);
                    }
                  commit work;
                }
              if (dict_size (ro_id_dict) > 100000)
                DB.DBA.RDF_OBJ_ADD_KEYWORD_FOR_GRAPH (iri_to_id (rule_g), ro_id_dict);
            }
          DB.DBA.RDF_OBJ_ADD_KEYWORD_FOR_GRAPH (iri_to_id (rule_g), ro_id_dict);
        }
      else
        {
          declare old_g IRI_ID;
          ro_id_dict := dict_new (100000);
          old_g := #i0;
          for (select O as obj, G as curr_g from DB.DBA.RDF_QUAD where ((rule_p = '') or equ (P,rule_p_iid)) and not isiri_id (O) order by G) do
            {
              if (isstring (obj))
                {
                  if (curr_g <> old_g)
                    {
                      if (old_g <> #i0)
                        DB.DBA.RDF_OBJ_ADD_KEYWORD_FOR_GRAPH (old_g, ro_id_dict);
                      ro_id_dict := dict_new (100000);
                      old_g := curr_g;
                    }
                  DB.DBA.RDF_OBJ_ADD (257, obj, 257, ro_id_dict);
                  commit work;
                  if (dict_size (ro_id_dict) > 100000)
                    DB.DBA.RDF_OBJ_ADD_KEYWORD_FOR_GRAPH (curr_g, ro_id_dict);
                }
              else
                {
                  declare id integer;
                  id := rdf_box_ro_id (obj);
                  if (0 <> id)
                    {
                      if (curr_g <> old_g)
                        {
                          if (old_g <> #i0)
                            DB.DBA.RDF_OBJ_ADD_KEYWORD_FOR_GRAPH (old_g, ro_id_dict);
                          ro_id_dict := dict_new (100000);
                          old_g := curr_g;
                        }
                      update DB.DBA.RDF_OBJ set RO_DIGEST = obj where RO_ID = id and RO_DIGEST is null;
                      dict_put (ro_id_dict, id, 1);
                      commit work;
                      if (dict_size (ro_id_dict) > 100000)
                        DB.DBA.RDF_OBJ_ADD_KEYWORD_FOR_GRAPH (curr_g, ro_id_dict);
                    }
                }
            }
          DB.DBA.RDF_OBJ_ADD_KEYWORD_FOR_GRAPH (old_g, ro_id_dict);
          commit work;
    }
  __atomic (0);
  exec ('checkpoint');
    }
  insert into DB.DBA.RDF_OBJ_FT_RULES (ROFR_G, ROFR_P, ROFR_REASON) values (rule_g, rule_p, reason);
  commit work;
  __rdf_obj_ft_rule_add (rule_g_iid, rule_p_iid, reason);
  return 1;
}
;

create function DB.DBA.RDF_OBJ_FT_RULE_DEL (in rule_g varchar, in rule_p varchar, in reason varchar) returns integer
{
  declare rule_g_iid, rule_p_iid IRI_ID;
  if (rule_g is null)
    rule_g := '';
  if (rule_p is null)
    rule_p := '';
  rule_g_iid := case (rule_g) when '' then null else iri_to_id (rule_g, 1) end;
  rule_p_iid := case (rule_p) when '' then null else iri_to_id (rule_p, 1) end;
  if (reason is null)
    signal ('RDFXX', 'DB.DBA.RDF_OBJ_FT_RULE_DEL() expects string as argument 3');
  if (not exists (
      select top 1 1 from DB.DBA.RDF_OBJ_FT_RULES
      where ROFR_G = rule_g and ROFR_P = rule_p and ROFR_REASON = reason))
    return 0;
  delete from DB.DBA.RDF_OBJ_FT_RULES where ROFR_G = rule_g and ROFR_P = rule_p and ROFR_REASON = reason;
  commit work;
  __rdf_obj_ft_rule_del (rule_g_iid, rule_p_iid, reason);
  return 1;
}
;

create procedure DB.DBA.RDF_OBJ_FT_RECOVER ()
{
  declare stat, msg, STRG varchar;
  declare metas, rset any;
  result_names (STRG);
  exec ('
    select ROFR_G, ROFR_P, MAX (ROFR_REASON), COUNT (1), MIN (ROFR_REASON)
    from DB.DBA.RDF_OBJ_FT_RULES
    group by ROFR_G, ROFR_P
    order by (1024 * length (ROFR_G) + 1024 * length (ROFR_P))',
    stat, msg, vector (), 100000, metas, rset);
  foreach (any ftrule in rset) do
    {
      result (sprintf ('Temporary drop of rule "%s" for graph <%s> predicate <%s>...', ftrule[2], ftrule[0], ftrule[1]));
      { whenever sqlstate '*' goto add_back;
        DB.DBA.RDF_OBJ_FT_RULE_DEL (ftrule[0], ftrule[1], ftrule[2]);
        result ('... done'); }
add_back:
      result (sprintf ('Restoring rule "%s" for graph <%s> predicate <%s>...', ftrule[2], ftrule[0], ftrule[1]));
      { whenever sqlstate '*' goto restored;
        DB.DBA.RDF_OBJ_FT_RULE_ADD (ftrule[0], ftrule[1], ftrule[2]);
        result ('... done'); }
restored:
      if (ftrule[3] > 1)
        result (sprintf ('No need to re-apply additional %d rules for this graph and predicate, e.g., rule "%s"', ftrule[4]));
    }
  result ('Now starting incremental update of free-text index...');
  VT_INC_INDEX_DB_DBA_RDF_OBJ();
  result ('... done');
}
;

-----
-- Loading default set of quad map metadata.

create procedure DB.DBA.SPARQL_RELOAD_QM_GRAPH ()
{
  if (not exists (sparql define input:storage "" ask where {
          graph <http://www.openlinksw.com/schemas/virtrdf#> {
              <http://www.openlinksw.com/sparql/virtrdf-data-formats.ttl>
                virtrdf:version '2008-05-21 0001'
            } } ) )
    {
      declare txt1, txt2 varchar;
      declare jso_sys_g_iid IRI_ID;
      declare dict1, lst1, dict2, lst2, sum_lst any;
      txt1 := cast ( DB.DBA.XML_URI_GET (
          'http://www.openlinksw.com/sparql/virtrdf-data-formats.ttl', '' ) as varchar );
      txt2 := '
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix owl: <http://www.w3.org/2002/07/owl#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
@prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#> .
@prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#> .

virtrdf:DefaultQuadStorage
  rdf:type virtrdf:QuadStorage ;
  virtrdf:qsUserMaps virtrdf:DefaultQuadStorage-UserMaps ;
  virtrdf:qsDefaultMap virtrdf:DefaultQuadMap ;
  virtrdf:qsMatchingFlags virtrdf:SPART_QS_NO_IMPLICIT_USER_QM .
virtrdf:DefaultQuadStorage-UserMaps
  rdf:type virtrdf:array-of-QuadMap .
      ';
      jso_sys_g_iid := DB.DBA.RDF_MAKE_IID_OF_QNAME (JSO_SYS_GRAPH ());
      dict1 := DB.DBA.RDF_TTL2HASH (txt1, '');
      dict2 := DB.DBA.RDF_TTL2HASH (txt2, '');
      lst1 := dict_list_keys (dict1, 1);
      lst2 := dict_list_keys (dict2, 1);
      sum_lst := vector_concat (lst1, lst2);
      foreach (any triple in sum_lst) do
        {
          if ((triple[1] = iri_to_id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#type')) and
            isiri_id (triple[2]) and (triple[2] = iri_to_id ('http://www.openlinksw.com/schemas/virtrdf#QuadMapFormat')))
            {
              -- dbg_obj_princ ('will delete whole ', id_to_iri (triple[0]));
              delete from DB.DBA.RDF_QUAD table option (index RDF_QUAD) where G = jso_sys_g_iid and S = triple[0];
            }
          else
            delete from DB.DBA.RDF_QUAD table option (index RDF_QUAD) where G = jso_sys_g_iid and S = triple[0] and P = triple[1];
        }
      DB.DBA.RDF_INSERT_TRIPLES (jso_sys_g_iid, sum_lst);
      commit work;
    }
  DB.DBA.JSO_LOAD_AND_PIN_SYS_GRAPH ();
  sequence_set ('RDF_URL_IID_NAMED', 1010000, 1);
  sequence_set ('RDF_URL_IID_BLANK', iri_id_num (min_bnode_iri_id ()) + 10000, 1);
  sequence_set ('RDF_URL_IID_NAMED_BLANK', iri_id_num (min_named_bnode_iri_id ()) + 10000, 1);
  sequence_set ('RDF_PREF_SEQ', 101, 1);
  sequence_set ('RDF_RO_ID', 1001, 1);
}
;

create procedure DB.DBA.RDF_CREATE_SPARQL_ROLES ()
{
  declare state, msg varchar;
  declare cmds any;
  cmds := vector (
    'create role SPARQL_SELECT',
    'create role SPARQL_SPONGE',
    'create role SPARQL_UPDATE',
    'grant SPARQL_SELECT to SPARQL_UPDATE',
    'grant SPARQL_SELECT to SPARQL_SPONGE',
    'grant SPARQL_SPONGE to SPARQL_UPDATE',
    'grant select on DB.DBA.RDF_QUAD to SPARQL_SELECT',
    'grant all on DB.DBA.RDF_QUAD to SPARQL_UPDATE',
    'grant select on DB.DBA.RDF_URL to SPARQL_SELECT',
    'grant all on DB.DBA.RDF_URL to SPARQL_UPDATE',
    'grant select on DB.DBA.RDF_PREFIX to SPARQL_SELECT',
    'grant all on DB.DBA.RDF_PREFIX to SPARQL_UPDATE',
    'grant select on DB.DBA.RDF_IRI to SPARQL_SELECT',
    'grant all on DB.DBA.RDF_IRI to SPARQL_UPDATE',
    'grant select on DB.DBA.RDF_OBJ to SPARQL_SELECT',
    'grant all on DB.DBA.RDF_OBJ to SPARQL_UPDATE',
    'grant select on DB.DBA.RDF_DATATYPE to SPARQL_SELECT',
    'grant all on DB.DBA.RDF_DATATYPE to SPARQL_UPDATE',
    'grant select on DB.DBA.RDF_LANGUAGE to SPARQL_SELECT',
    'grant all on DB.DBA.RDF_LANGUAGE to SPARQL_UPDATE',
    'grant select on DB.DBA.SYS_SPARQL_HOST to SPARQL_SELECT',
    'grant all on DB.DBA.SYS_SPARQL_HOST to SPARQL_UPDATE',
    'grant execute on DB.DBA.RDF_GLOBAL_RESET to SPARQL_UPDATE',
    'grant execute on DB.DBA.RDF_MAKE_IID_OF_QNAME to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_MAKE_IID_OF_QNAME_SAFE to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_MAKE_IID_OF_LONG to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_QNAME_OF_IID to SPARQL_SELECT', -- DEPRECATED
    'grant execute on DB.DBA.RDF_MAKE_GRAPH_IIDS_OF_QNAMES to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_TWOBYTE_OF_DATATYPE to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_TWOBYTE_OF_LANGUAGE to SPARQL_SELECT',
    'grant execute on DB.DBA.RQ_LONG_OF_O to SPARQL_SELECT', -- DEPRECATED
    'grant execute on DB.DBA.RQ_SQLVAL_OF_O to SPARQL_SELECT', -- DEPRECATED
    'grant execute on DB.DBA.RDF_BOOL_OF_O to SPARQL_SELECT',
    'grant execute on DB.DBA.RQ_IID_OF_O to SPARQL_SELECT', -- DEPRECATED
    'grant execute on DB.DBA.RQ_O_IS_LIT to SPARQL_SELECT', -- DEPRECATED
    'grant execute on DB.DBA.RDF_OBJ_ADD to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_OBJ_FIND_EXISTING to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_MAKE_OBJ_OF_SQLVAL to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_MAKE_OBJ_OF_SQLVAL_FT to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL_FT to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL_STRINGS to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_LONG_OF_OBJ to SPARQL_SELECT', -- DEPRECATED
    'grant execute on DB.DBA.RDF_DATATYPE_OF_OBJ to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_LANGUAGE_OF_OBJ to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_SQLVAL_OF_OBJ to SPARQL_SELECT', -- DEPRECATED
    'grant execute on DB.DBA.RDF_BOOL_OF_OBJ to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_QNAME_OF_OBJ to SPARQL_SELECT', -- DEPRECATED
    'grant execute on DB.DBA.RDF_STRSQLVAL_OF_OBJ to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_OBJ_OF_LONG to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_OBJ_OF_SQLVAL to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_MAKE_LONG_OF_SQLVAL to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL_STRINGS to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_SQLVAL_OF_LONG to SPARQL_SELECT', -- DEPRECATED
    'grant execute on DB.DBA.RDF_BOOL_OF_LONG to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_DATATYPE_OF_LONG to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_DATATYPE_IRI_OF_LONG to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_LANGUAGE_OF_LONG to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_STRSQLVAL_OF_LONG to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_LONG_OF_SQLVAL to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_QUAD_URI to SPARQL_UPDATE',
    'grant execute on DB.DBA.RDF_QUAD_URI_L to SPARQL_UPDATE',
    'grant execute on DB.DBA.RDF_QUAD_URI_L_TYPED to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP_EV_NEW_GRAPH to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP_EV_NEW_BLANK to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP_EV_GET_IID to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP_EV_TRIPLE to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP_EV_TRIPLE_L to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP to SPARQL_UPDATE',
    'grant execute on DB.DBA.RDF_TTL2HASH_EXEC_NEW_GRAPH to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_TTL2HASH_EXEC_NEW_BLANK to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_TTL2HASH_EXEC_GET_IID to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_TTL2HASH_EXEC_TRIPLE to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_TTL2HASH_EXEC_TRIPLE_L to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_TTL2HASH to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_LOAD_RDFXML to SPARQL_UPDATE',
    'grant execute on DB.DBA.RDF_RDFXML_TO_DICT to SPARQL_UPDATE',
    'grant execute on DB.DBA.RDF_LONG_TO_TTL to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_TRIPLES_TO_TTL to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_GRAPH_TO_TTL to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_TRIPLES_TO_RDF_XML_TEXT to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_RESULT_SET_AS_TTL_INIT to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_RESULT_SET_AS_TTL_ACC to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_RESULT_SET_AS_TTL_FIN to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_RESULT_SET_AS_RDF_XML_INIT to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_RESULT_SET_AS_RDF_XML_ACC to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_RESULT_SET_AS_RDF_XML_FIN to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_TTL to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_RDF_XML to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_INSERT_TRIPLES to SPARQL_UPDATE',
    'grant execute on DB.DBA.RDF_DELETE_TRIPLES to SPARQL_UPDATE',
    'grant execute on DB.DBA.RDF_MODIFY_TRIPLES to SPARQL_UPDATE',
    'grant execute on DB.DBA.SPARQL_INSERT_DICT_CONTENT to SPARQL_UPDATE',
    'grant execute on DB.DBA.SPARQL_DELETE_DICT_CONTENT to SPARQL_UPDATE',
    'grant execute on DB.DBA.SPARQL_MODIFY_BY_DICT_CONTENTS to SPARQL_UPDATE',
    'grant execute on DB.DBA.SPARUL_CLEAR to SPARQL_UPDATE',
    'grant execute on DB.DBA.SPARUL_LOAD to SPARQL_UPDATE',
    'grant execute on DB.DBA.SPARUL_RUN to SPARQL_UPDATE',
    'grant execute on DB.DBA.SPARQL_DESC_AGG_INIT to SPARQL_SELECT',
    'grant execute on DB.DBA.SPARQL_DESC_AGG_ACC to SPARQL_SELECT',
    'grant execute on DB.DBA.SPARQL_DESC_AGG_FIN to SPARQL_SELECT',
    'grant execute on DB.DBA.SPARQL_DESC_DICT to SPARQL_SELECT',
    'grant execute on DB.DBA.SPARQL_CONSTRUCT_INIT to SPARQL_SELECT',
    'grant execute on DB.DBA.SPARQL_CONSTRUCT_ACC to SPARQL_SELECT',
    'grant execute on DB.DBA.SPARQL_CONSTRUCT_FIN to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_TYPEMIN_OF_OBJ to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_TYPEMAX_OF_OBJ to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_IID_CMP to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_OBJ_CMP to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_LONG_CMP to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_GRAB_SINGLE to SPARQL_SPONGE',
    'grant execute on DB.DBA.RDF_GRAB_SINGLE_ASYNC to SPARQL_SPONGE',
    'grant execute on DB.DBA.RDF_GRAB_SEEALSO to SPARQL_SPONGE',
    'grant execute on DB.DBA.RDF_GRAB to SPARQL_SPONGE',
    'grant execute on DB.DBA.SPARQL_EVAL_TO_ARRAY to SPARQL_SELECT',
    'grant execute on DB.DBA.SPARQL_EVAL to SPARQL_SELECT',
    'grant execute on DB.DBA.SPARQL_REXEC to SPARQL_SELECT',
    'grant execute on DB.DBA.SPARQL_REXEC_TO_ARRAY to SPARQL_SELECT',
    'grant execute on DB.DBA.SPARQL_REXEC_WITH_META to SPARQL_SELECT',
    'grant execute on WS.WS."/!sparql/" to "SPARQL"',
    'grant execute on DB.DBA.TTLP_MT to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP_EV_TRIPLE_W to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP_EV_TRIPLE_L_W to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP_EV_TRIPLE_A to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP_EV_TRIPLE_L_A to SPARQL_UPDATE',
    'grant execute on DB.DBA.RDF_LOAD_RDFXML_MT to SPARQL_UPDATE',
    'grant execute on DB.DBA.RDF_LOAD_HTTP_RESPONSE to SPARQL_UPDATE',
    'grant execute on DB.DBA.RDF_FORGET_HTTP_RESPONSE to SPARQL_UPDATE',
    'grant execute on DB.DBA.RDF_SPONGE_UP to SPARQL_SPONGE',
    'grant execute on DB.DBA.RDF_SPONGE_UP_LIST to SPARQL_SPONGE',
    'grant execute on DB.DBA.TTLP_EV_COMMIT to SPARQL_UPDATE',
    'grant execute on DB.DBA.RDF_PROC_COLS to "SPARQL"' );
  foreach (varchar cmd in cmds) do
    {
      exec (cmd, state, msg);
    }
}
;

create procedure DB.DBA.RDF_QUAD_AUDIT ()
{
  declare stat, msg varchar;
  declare err_dict any;
  result_names (stat, msg);
  if (exists (select top 1 1 from DB.DBA.SYS_COLS
    where "TABLE" = fix_identifier_case ('DB.DBA.RDF_OBJ_RO_DIGEST_WORDS')
    and "COLUMN" = fix_identifier_case ('VT_WORD') )
    and exists (select top 1 1 from DB.DBA.SYS_COLS
    where "TABLE" = fix_identifier_case ('DB.DBA.RDF_OBJ')
    and "COLUMN" = fix_identifier_case ('RO_DIGEST')
    and COL_DTP = 242 ) )
    goto check_new_style;
  err_dict := dict_new ();
  if (isstring (registry_get ('DB.DBA.RDF_QUAD_FT_UPGRADE')))
    {
      result ('ERRol', 'old layout but isstring (registry_get (''DB.DBA.RDF_QUAD_FT_UPGRADE''))');
      return;
    }
  for (select O as o_old from DB.DBA.RDF_QUAD where isstring (O)) do
    {
      declare o_old_len integer;
      declare o_long any;
      declare o_strval varchar;
      declare val_len, o_id integeR;
      declare o_dt, o_lang integeR;
      o_old_len := length (o_old);
      if (dict_size (err_dict) > 10000)
        {
          result ('ERRxx', 'Too many errors, bye');
          return;
        }
      if (dict_get (err_dict, o_old, 0))
        goto known_bug;
      if (o_old_len = 29)
        {
          if (o_old [22] <> 0)
            { result ('ERRol', sprintf ('ill literal |%U| (escaped like URL)', o_old)); dict_put (err_dict, o_old, 1); }
          else
            {
              o_long := jso_parse_digest (o_old);
              o_strval := (select case (isnull (RO_LONG)) when 0 then blob_to_string (RO_LONG) else RO_VAL end from DB.DBA.RDF_OBJ where RO_ID = o_long[3]);
              if (o_strval is null)
                { result ('ERRol', sprintf ('Non-existing RO_ID %d in literal |%U| (escaped like URL)', o_long[3], o_old)); dict_put (err_dict, o_old, 1); }
              else if ("LEFT" (o_strval, 20) <> o_long[1])
                { result ('ERRol', sprintf ('Full value of RO_ID %d starts with |%U|, does not match to literal |%U| (escaped like URL)', o_long[3], "LEFT" (o_strval, 20), o_old)); dict_put (err_dict, o_old, 1); }
              o_dt := o_long[0];
              o_lang := o_long[2];
            }
        }
      else if (o_old_len < 5)
        { result ('ERRot', sprintf ('ill literal |%U| (escaped like URL)', o_old)); dict_put (err_dict, o_old, 1); }
      else if (o_old_len < 29)
        {
          val_len := length (o_old) - 5;
          o_dt := o_old[0] + o_old[1]*256;
          o_lang := o_old[val_len+3] + o_old[val_len+4]*256;
          if ((o_old [val_len+2] <> 0) or 0 = o_old[0] or 0 = o_old[1] or 0 = o_old[val_len+3] or 0 = o_old[val_len+4])
            { result ('ERRos', sprintf ('ill short literal |%U| (escaped like URL)', o_old)); dict_put (err_dict, o_old, 1); }
        }
      else
        { result ('ERRoh', sprintf ('Too long literal |%U| (truncated, escaped like URL)', "LEFT" (o_old, 100))); dict_put (err_dict, o_old, 1); }
known_bug: ;
    }
  return;

check_new_style:
  if (not isstring (registry_get ('DB.DBA.RDF_QUAD_FT_UPGRADE')))
    result ('ERRft', 'new layout but not isstring (registry_get (''DB.DBA.RDF_QUAD_FT_UPGRADE''))');
}
;

create procedure DB.DBA.RDF_QUAD_FT_UPGRADE ()
{
  declare stat, msg varchar;
  if (244 = coalesce ((select COL_DTP from SYS_COLS where "TABLE" = 'DB.DBA.RDF_QUAD' and "COLUMN"='G'), 0))
    {
      __set_64bit_min_bnode_iri_id();
      sequence_set ('RDF_URL_IID_BLANK', iri_id_num (min_bnode_iri_id ()), 1);
    }
  if (coalesce (cfg_item_value (virtuoso_ini_path (), 'SPARQL', 'RecoveryMode'), '0') > '0')
    {
      log_message ('Switching to RecoveryMode as set in [SPARQL] section of the configuration.');
      log_message ('For safety, the use of SPARQL_UPDATE role is restricted.');
      exec ('revoke "SPARQL_UPDATE" from "SPARQL"', stat, msg);
      return;
    }
  if (not isstring (registry_get ('DB.DBA.RDF_QUAD_FT_UPGRADE-tridgell32-2')))
    {
      __atomic (1);
      {
      set isolation='uncommitted';
        declare exit handler for sqlstate '*'
          {
            log_message ('Error during upgrade of RDF_OBJ:');
            log_message (__SQL_STATE || ': ' || "LEFT" (__SQL_MESSAGE, 1000));
            goto describe_recovery;
          };
        declare rolong_cur cursor for select RO_VAL, RO_LONG from DB.DBA.RDF_OBJ where RO_LONG is not null and length (RO_VAL) = 6 for update;
        whenever not found goto rolong_cur_end;
        open rolong_cur;
        while (1)
          {
            declare rl any;
            declare old_rv, new_rv varchar;
            fetch rolong_cur into old_rv, rl;
            new_rv := tridgell32 (blob_to_string (rl));
            if (new_rv <> old_rv)
            update DB.DBA.RDF_OBJ set RO_VAL = new_rv where current of rolong_cur;
          }
rolong_cur_end: ;
        registry_set ('DB.DBA.RDF_QUAD_FT_UPGRADE-tridgell32-2', '1');
      }
      __atomic (0);
      exec ('checkpoint');
    }
tridgell_ok:
  exec ('create index RO_DIGEST on DB.DBA.RDF_OBJ (RO_DIGEST)', stat, msg);
  if (exists (select top 1 1 from DB.DBA.SYS_COLS
    where "TABLE" = fix_identifier_case ('DB.DBA.RDF_OBJ_RO_DIGEST_WORDS')
    and "COLUMN" = fix_identifier_case ('VT_WORD') )
    and exists (select top 1 1 from DB.DBA.SYS_COLS
    where "TABLE" = fix_identifier_case ('DB.DBA.RDF_OBJ')
    and "COLUMN" = fix_identifier_case ('RO_DIGEST')
    and COL_DTP = 242 ) )
    goto final_qm_reload;
  exec ('DB.DBA.vt_create_text_index (
    fix_identifier_case (''DB.DBA.RDF_OBJ''),
    fix_identifier_case (''RO_DIGEST''),
    fix_identifier_case (''RO_ID''),
    0, 0, vector (), 1, ''*ini*'', ''UTF-8-QR'')', stat, msg);
  exec ('DB.DBA.vt_batch_update (fix_identifier_case (''DB.DBA.RDF_OBJ''), ''ON'', 1)', stat, msg);
  if (isstring (registry_get ('DB.DBA.RDF_QUAD_FT_UPGRADE')))
    goto final_qm_reload;
  __atomic (1);
  {
  declare exit handler for sqlstate '*'
    {
      log_message ('Error during upgrade of free-text index of RDF_QUAD:');
      log_message (__SQL_STATE || ': ' || "LEFT" (__SQL_MESSAGE, 1000));
      goto describe_recovery;
    };
--  checkpoint;
  log_enable (0);
  if (exists (select top 1 1 from DB.DBA.RDF_QUAD))
    log_message ('Upgrading RDF indices.  Can be up to an hour per GB of RDF data.');
  registry_set ('DB.DBA.RDF_QUAD_FT_UPGRADE', '1');
  if (exists (select top 1 1 from DB.DBA.SYS_COLS
    where "TABLE" = fix_identifier_case ('DB.DBA.RDF_OBJ')
    and "COLUMN" = fix_identifier_case ('RO_DIGEST')
    and COL_DTP = __tag of varchar ))
    {
      exec ('drop index RO_DIGEST', stat, msg);
      exec ('alter table DB.DBA.RDF_OBJ drop RO_DIGEST', stat, msg);
      exec ('alter table DB.DBA.RDF_OBJ add RO_DIGEST any', stat, msg);
      exec ('create index RO_DIGEST on DB.DBA.RDF_OBJ (RO_DIGEST)', stat, msg);
      commit work;
    }
  set isolation='uncommitted';
  {
    declare longtyped_cur cursor for select G,S,P,O
    from DB.DBA.RDF_QUAD
    where isstring (O) and length (O) = 29;
    declare g_old, s_old, p_old any;
    declare o_old varchar;
    declare val_len, o_id integeR;
    declare o_new any;
    whenever not found goto longtyped_cur_end;
    open longtyped_cur;
    while (1)
      {
        declare o_long any;
        declare o_strval varchar;
        fetch longtyped_cur into g_old, s_old, p_old, o_old;
        -- dbg_obj_princ ('o_old (longtyped) = ', o_old);
        if (o_old [22] <> 0)
          {
            log_message ('The function DB.DBA.RDF_QUAD_FT_UPGRADE() has found ill formed object literal in DB.DBA.RDF_QUAD');
            log_message ('This means that this version of Virtuoso server can not process RDF data stored in the database.');
            log_message ('To fix the problem, remove the transaction log and start previous version of Virtuoso.');
            log_message (sprintf ('The example of ill literal is |%U|, if escaped like URL', o_old));
            goto describe_recovery;
          }
        o_long := jso_parse_digest (o_old);
        o_strval := (select case (isnull (RO_LONG)) when 0 then blob_to_string (RO_LONG) else RO_VAL end from DB.DBA.RDF_OBJ where RO_ID = o_long[3]);
        o_new := DB.DBA.RDF_OBJ_ADD (o_long[0], o_strval, o_long[2]);
        insert soft DB.DBA.RDF_QUAD (G,S,P,O) values (g_old, s_old, p_old, o_new);
      }
longtyped_cur_end: ;
  }
  delete from DB.DBA.RDF_QUAD where isstring (O) and length (O) = 29;
--  checkpoint;
  {
    declare shortobj_cur cursor for select G,S,P,O from DB.DBA.RDF_QUAD where isstring (O) and length (O) < 29;
    declare g_old, s_old, p_old any;
    declare o_old varchar;
    declare val_len, o_id integeR;
    declare o_new any;
    whenever not found goto shortobj_cur_end;
    open shortobj_cur;
    while (1)
      {
        declare o_dt, o_lang integeR;
        fetch shortobj_cur into g_old, s_old, p_old, o_old;
        val_len := length (o_old) - 5;
        if (o_old [val_len+2] <> 0)
          {
            log_message ('The function DB.DBA.RDF_QUAD_FT_UPGRADE() has found ill formed object literal in DB.DBA.RDF_QUAD');
            log_message ('This means that this version of Virtuoso server can not process RDF data stored in the database.');
            log_message ('To fix the problem, remove the transaction log and start previous version of Virtuoso.');
            log_message (sprintf ('The example of ill literal is |%U|, if escaped like URL', o_old));
            goto describe_recovery;
          }
        o_dt := o_old[0] + o_old[1]*256;
        o_lang := o_old[val_len+3] + o_old[val_len+4]*256;
        o_new := DB.DBA.RDF_OBJ_ADD (o_dt, subseq (o_old, 2, val_len+2), o_lang);
        if (isstring (o_new))
          insert soft DB.DBA.RDF_QUAD (G,S,P,O) values (g_old, s_old, p_old, o_new || '012345678901234567890123456789');
        else
          insert soft DB.DBA.RDF_QUAD (G,S,P,O) values (g_old, s_old, p_old, o_new);
        commit work;
      }
shortobj_cur_end: ;
  }
  delete from DB.DBA.RDF_QUAD where isstring (O) and length (O) < 29;
--  checkpoint;
  {
    declare tmpval_cur cursor for select G,S,P,O
    from DB.DBA.RDF_QUAD
    where isstring (O) and length (O) > 29;
    declare g_old, s_old, p_old any;
    declare o_old varchar;
    whenever not found goto tmpval_cur_end;
    open tmpval_cur;
    while (1)
      {
        fetch tmpval_cur into g_old, s_old, p_old, o_old;
        -- dbg_obj_princ ('o_old (tmp) = ', o_old);
        insert soft DB.DBA.RDF_QUAD (G,S,P,O) values (g_old, s_old, p_old, subseq (o_old, 0, length (o_old) - 30));
      }
tmpval_cur_end: ;
  }
  delete from DB.DBA.RDF_QUAD where isstring (O) and length (O) > 29;
--  checkpoint;
  commit work;
  log_enable (1);
  }
  __atomic (0);
  exec ('checkpoint');

final_qm_reload:
  DB.DBA.SPARQL_RELOAD_QM_GRAPH ();
  return;

describe_recovery:
  log_message ('Remove the transaction log and start previous version of Virtuoso.');
  log_message ('You may use the database with new version of Virtuoso server for');
  log_message ('diagnostics and error recovery; to make it possible, add parameter');
  log_message ('"RecoveryMode=1" to the [SPARQL] section of ' || virtuoso_ini_path ());
  log_message ('and restart the server; remove the parameter and restart as soon as possible');
  log_message ('This error is critical. The server will now exit. Sorry.');
  -- __atomic (0);
  raw_exit ();
}
;

--!AFTER __PROCEDURE__ DB.DBA.XML_URI_GET !
DB.DBA.RDF_QUAD_FT_UPGRADE ()
;

--!AFTER __PROCEDURE__ DB.DBA.USER_CREATE !
DB.DBA.RDF_CREATE_SPARQL_ROLES ()
;

-- loading subclass inference ctxs


create procedure rdfs_pn (in is_class int)
{
  return case when is_class = 1 then iri_to_id ('http://www.w3.org/2000/01/rdf-schema#subClassOf', 1)
  else  iri_to_id ('http://www.w3.org/2000/01/rdf-schema#subPropertyOf', 1) end;
}
;


create procedure rdf_owl_sas_p (in gr iri_id, in name varchar, in super_c iri_id, in c iri_i, in visited any, inout supers any, in pos int)
{
  for select o from rdf_quad where g = gr and p = rdf_sas_iri () and s = c do
    {
      rdfs_closure_1 (gr, name, super_c, o, 0, visited, supers, pos);
    }
  for select s from rdf_quad where g = gr and p = rdf_sas_iri () and o = c do
    {
      rdfs_closure_1 (gr, name, super_c, s, 0, visited, supers, pos);
    }
}
;

create procedure rdfs_closure_1
(in gr iri_id, in name varchar, in super_c iri_id, in c iri_i, in is_class int, in visited any, inout supers any, in pos int)
{
  declare i int;
  if (dict_get (visited, c))
    return;
  dict_put (visited, c, 1);
  if (pos >= length (supers))
    supers := vector_concat (supers, make_array (100, 'any'));
  supers [pos] := c;
  for (i := 0; i <= pos; i := i + 1)
    {
      --dbg_printf ('registered: super=[%s] sub=[%s]', id_to_iri (supers[i]), id_to_iri (c));
      rdf_inf_super (name, supers[i], c, is_class, 1);
    }
  for select s from rdf_quad where g = gr and p =  rdf_owl_iri (is_class) and o = c do
    {
      rdfs_closure_1 (gr, name, super_c, s, is_class, visited, supers, pos + 1);
      if (not is_class)
	rdf_owl_sas_p (gr, name, super_c, s, visited, supers, pos + 1);
    }
  supers[pos] := 0;
}
;


create procedure rdfs_load_schema (in name varchar, in gn varchar)
{
  declare gr iri_id;
  declare visited any;
  declare supers any;
  gr := iri_to_id (gn, 0, 0);
  if (isinteger (gr))
    return;
  supers := make_array (100, 'any');
  for select a.o as o from rdf_quad a where a.g = gr and a.p = rdf_owl_iri (1)
    and not exists (select 1 from rdf_quad b where b.g = a.g and b.p = a.p and a.o = b.s)
    do
    {
      rdfs_closure_1 (gr, name, o, o, 1, dict_new (), supers, 0);
    }
  supers := make_array (100, 'any');
  for select a.o as o from rdf_quad a where a.g = gr and a.p = rdf_owl_iri (0)
    and not exists (select 1 from rdf_quad b where b.g = a.g and b.p = a.p and a.o = b.s)
    do
    {
      rdfs_closure_1 (gr, name, o, o, 0, dict_new (), supers, 0);
    }
}
;

create table DB.DBA.SYS_RDF_SCHEMA (RS_NAME VARCHAR , RS_URI VARCHAR, RS_G IRI_ID,
	PRIMARY KEY (RS_NAME, RS_URI))
;


select  count (*) from sys_rdf_schema where 0 = rdfs_load_schema (rs_name, rs_uri)
;


create procedure rdfs_rule_set (in name varchar, in gn varchar, in remove int := 0)
{
  if (remove)
    delete from sys_rdf_schema where rs_name = name and rs_uri = gn;
  else
    insert replacing sys_rdf_schema (rs_name, rs_uri) values (name, gn);

  rdf_inf_clear (name);
  rdfs_load_schema (name, gn);
  log_text ('db.dba.rdfs_load_schema (?, ?)', name, gn);
}
;

create function DB.DBA.RDF_IID_OF_QNAME (in qname varchar) returns IRI_ID
{
  whenever sqlstate '*' goto retnull;
  return iri_to_id (qname, 0, null);
  retnull:
  return null;
}
;

-- WS handlers for .rq files (application/sparql-query)
create procedure
WS.WS.__http_handler_rq (in content any, in params any, in lines any, inout ipath_ostat any)
{
  return DB.DBA.http_rq_file_handler(content, params, lines, ipath_ostat);
}
;

create procedure
WS.WS.__http_handler_head_rq (in content any, in params any, in lines any, inout ipath_ostat any)
{
  return DB.DBA.http_rq_file_handler(content, params, lines, ipath_ostat);
}
;

create procedure
DB.DBA.http_rq_file_handler (in content any, in params any, in lines any, inout ipath_ostat any)
{
  declare accept varchar;
  declare _format varchar;

  accept := http_request_header (lines, 'Accept', null, '');

  _format := get_keyword('format', params, '');
  if (_format <> '')
    {
      _format := (
      case lower(_format)
      when 'json' then 'application/sparql-results+json'
      when 'js' then 'application/javascript'
      when 'html' then 'text/html'
      when 'sparql' then 'application/sparql-results+xml'
      when 'xml' then 'application/sparql-results+xml'
      when 'rdf' then 'application/rdf+xml'
      when 'n3' then 'text/rdf+n3'
      else _format
      end);
    }

  if (_format <> '' or
      strcasestr (accept, 'application/sparql-results+json') is not null or
      strcasestr (accept, 'application/json') is not null or
      strcasestr (accept, 'application/sparql-results+xml') is not null or
      strcasestr (accept, 'text/rdf+n3') is not null or
      strcasestr (accept, 'application/rdf+xml') is not null or
      strcasestr (accept, 'application/javascript') is not null or
      strcasestr (accept, 'application/soap+xml') is not null or
      strcasestr (accept, 'application/rdf+turtle') is not null
     )
    {
      http_request_status ('HTTP/1.1 303 See Other');
      http_header (sprintf('Location: /sparql?query=%U&format=%U\r\n', content, accept));
      return '';
    }
  if (strcasestr (accept, 'application/sparql-query') is not null)
     http_header ('Content-Type: application/sparql-query\r\n');
  else
     http_header ('Content-Type: text/plain\r\n');
  http (content);
  return '';
}
;

create procedure SPARQL_INI_PARAMS (inout metas any, inout dta any)
{
  declare item_cnt int;
  declare items any;
  declare item_name, item_value varchar;
  declare res_dict any;
  declare tmp any;

  item_cnt := cfg_item_count (virtuoso_ini_path (), 'SPARQL');
  tmp := string_output ();

  for (declare i int, i := 0; i < item_cnt; i := i + 1)
    {
      item_name := cfg_item_name (virtuoso_ini_path (), 'SPARQL', i);
      item_value := cfg_item_value (virtuoso_ini_path (), 'SPARQL', item_name);
      http (sprintf ('<http://www.openlinksw.com/schemas/virtini#SPARQL> <http://www.openlinksw.com/schemas/virtini#%U> "%s" .\r\n',
	    item_name, item_value), tmp);
    }
  tmp := string_output_string (tmp);
  res_dict := DB.DBA.RDF_TTL2HASH (tmp, '');
  metas := vector (vector (vector ('res_dict', 242, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0)), 1);
  dta := vector (vector (res_dict));
}
;
