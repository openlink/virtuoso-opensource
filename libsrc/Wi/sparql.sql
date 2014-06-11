--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2014 OpenLink Software
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

create table DB.DBA.RDF_QUAD (
  G IRI_ID_8,
  S IRI_ID_8,
  P IRI_ID_8,
  O any,
  primary key (P, S, O, G) column
  )
alter index RDF_QUAD on DB.DBA.RDF_QUAD partition (S int (0hexffff00))

create distinct no primary key ref column index RDF_QUAD_SP on DB.DBA.RDF_QUAD (S, P) partition (S int (0hexffff00))
create column index RDF_QUAD_POGS on DB.DBA.RDF_QUAD (P, O, S, G) partition (O varchar (-1, 0hexffff))
create distinct no primary key ref column index RDF_QUAD_GS on DB.DBA.RDF_QUAD (G, S) partition (S int (0hexffff00))
create distinct no primary key ref column index RDF_QUAD_OP on DB.DBA.RDF_QUAD (O, P) partition (O varchar (-1, 0hexffff))
;

create table DB.DBA.RDF_QUAD_RECOV_TMP (
  G1 IRI_ID_8,  S1 IRI_ID_8,  P1 IRI_ID_8,  O1 any,  primary key (P1, S1, O1, G1) column)
alter index RDF_QUAD_RECOV_TMP on DB.DBA.RDF_QUAD_RECOV_TMP partition (S1 int (0hexffff00))
create column index RDF_QUAD_RECOV_TMP_POGS on DB.DBA.RDF_QUAD_RECOV_TMP (P1, O1, G1, S1) partition (O1 varchar (-1, 0hexffff))
create distinct no primary key ref column index RDF_QUAD_RECOV_TMP_OP on DB.DBA.RDF_QUAD_RECOV_TMP (O1, P1) partition (O1 varchar (-1, 0hexffff))
;

create function DB.DBA.RDF_MAKE_IID_OF_QNAME_SAFE (in qname any) returns IRI_ID
{
  return iri_to_id_nosignal (qname);
}
;

create function DB.DBA.RDF_MAKE_IID_OF_QNAME_COMP (in qname any) returns IRI_ID
{
  return iri_to_id_nosignal (qname, 0);
}
;

create function DB.DBA.RDF_QNAME_OF_IID (in iid IRI_ID) returns varchar -- DEPRECATED
{
  return id_to_iri_nosignal (iid);
}
;

DB.DBA.RDF_MAKE_IID_OF_QNAME_SAFE (null)
;

DB.DBA.RDF_MAKE_IID_OF_QNAME_COMP (null)
;

DB.DBA.RDF_QNAME_OF_IID (null)
;

--create trigger DB.DBA.RDF_QUAD_O_AUDIT before insert on DB.DBA.RDF_QUAD
--{
--  if (not rdf_box_is_storeable (O))
--    signal ('RDFXX', 'non-storeable O');
--}
--;

create table DB.DBA.RDF_OBJ (
  RO_ID bigint primary key,
  RO_VAL varchar not null,
  RO_LONG long varchar,
  RO_FLAGS smallint not null default 0,
  RO_DT_AND_LANG integer not null default 16843009 compress any
)
alter index RDF_OBJ on RDF_OBJ partition (RO_ID int (0hexffff00))

create index RO_VAL on DB.DBA.RDF_OBJ (RO_VAL, RO_DT_AND_LANG)
 partition (RO_VAL varchar (-4, 0hexffff))
;


create table DB.DBA.RO_START (RS_START varchar, RS_DT_AND_LANG int, RS_RO_ID any,
  primary key (RS_START, RS_DT_AND_LANG, RS_RO_ID))
alter index RO_START on DB.DBA.RO_START partition (RS_RO_ID varchar (-1, 0hexffff))
;


--create table DB.DBA.RDF_FT (
--  RF_ID bigint primary key,
--  RF_O any)
--alter index RDF_FT on RDF_FT partition (RF_ID int (0hexffff00))
--create index RF_O on RDF_FT (RF_O) partition (RF_O varchar  (-1, 0hexffff))
--;

create table DB.DBA.RDF_DATATYPE (
  RDT_IID IRI_ID_8 not null primary key,
  RDT_TWOBYTE integer not null unique,
  RDT_QNAME varchar not null unique )
alter index RDF_DATATYPE on RDF_DATATYPE partition cluster replicated
alter index DB_DBA_RDF_DATATYPE_UNQC_RDT_TWOBYTE   on RDF_DATATYPE partition cluster replicated
alter index DB_DBA_RDF_DATATYPE_UNQC_RDT_QNAME on RDF_DATATYPE partition cluster replicated
;

create table DB.DBA.RDF_LANGUAGE (
  RL_ID varchar not null primary key,
  RL_TWOBYTE integer not null unique )
alter index RDF_LANGUAGE on RDF_LANGUAGE  partition cluster replicated
alter index DB_DBA_RDF_LANGUAGE_UNQC_RL_TWOBYTE on RDF_LANGUAGE  partition cluster replicated
;

create table DB.DBA.SYS_SPARQL_HOST (
  SH_HOST	varchar not null primary key,
  SH_GRAPH_URI	varchar,
  SH_USER_URI	varchar,
  SH_BASE_URI	varchar,
  SH_DEFINES	long varchar
)
;

alter table DB.DBA.SYS_SPARQL_HOST add SH_BASE_URI varchar
;

create table DB.DBA.RDF_OBJ_FT_RULES (
  ROFR_G varchar not null,
  ROFR_P varchar not null,
  ROFR_REASON varchar not null,
  primary key (ROFR_G, ROFR_P, ROFR_REASON) )
alter index RDF_OBJ_FT_RULES on RDF_OBJ_FT_RULES partition cluster replicated
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
alter index SYS_XML_PERSISTENT_NS_DECL on SYS_XML_PERSISTENT_NS_DECL partition cluster replicated
;

create table DB.DBA.RDF_EXPLICITLY_CREATED_GRAPH
(
  REC_GRAPH_IID IRI_ID not null primary key
)
alter index RDF_EXPLICITLY_CREATED_GRAPH on RDF_EXPLICITLY_CREATED_GRAPH partition cluster replicated
;

create table RDF_GEO (X real no compress, Y real no compress,X2 real no compress, Y2 real no compress, ID bigint no compress, primary key (X, Y, X2, Y2, ID))
alter index RDF_GEO on RDF_GEO partition (ID int (0hexffff00))
;

create table DB.DBA.RDF_LABEL (RL_O any primary key, RL_RO_ID bigint, RL_TEXT varchar, RL_LANG int)
alter index RDF_LABEL on RDF_LABEL partition (RL_O varchar (-1, 0hexffff))
create index RDF_LABEL_TEXT on RDF_LABEL (RL_TEXT, RL_O) partition (RL_TEXT varchar (6, 0hexffff))
;

create table DB.DBA.RDF_QUAD_DELETE_QUEUE (
  EVENT_ID bigint not null,
  RULE_ID bigint not null,
  QG IRI_ID not null,
  QS IRI_ID not null,
  QP IRI_ID not null,
  QO any not null,
  primary key (EVENT_ID, RULE_ID,  QG, QS, QP, QO)
)
;

create table DB.DBA.SYS_IDONLY_EMPTY
(
  ID integer not null primary key
)
;

create table DB.DBA.SYS_IDONLY_ONE
(
  ID integer not null primary key
)
;

insert soft DB.DBA.SYS_IDONLY_ONE (ID) values (0)
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

create procedure RDF_QUAD_FT_INIT ()
{
  if (not exists (select 1 from SYS_VT_INDEX where VI_COL = 'o'))
    {
      insert soft SYS_VT_INDEX (VI_TABLE, VI_INDEX, VI_COL, VI_ID_COL, VI_INDEX_TABLE, VI_ID_IS_PK, VI_OPTIONS)
	values ('DB.DBA.RDF_QUAD', 'RDF_QUAD_OP', 'O', 'O', 'DB.DBA.RDF_GEO', 1, 'GR');
      insert soft SYS_VT_INDEX (VI_TABLE, VI_INDEX, VI_COL, VI_ID_COL, VI_INDEX_TABLE, VI_ID_IS_PK, VI_OPTIONS)
	values ('DB.DBA.RDF_QUAD', 'RDF_QUAD_OP', 'o', 'O', 'DB.DBA.RDF_OBJ_RO_FLAGS_WORDS', 1, null);
      __ddl_changed ('DB.DBA.RDF_QUAD');
    }
}
;

create procedure DB.DBA.RDF_OBJ_RO_FLAGS_INDEX_HOOK (inout vtb any, inout d_id any)
{
  if (cl_current_slice () = 0hexffff)
{
  for (select RO_LONG, RO_VAL, RO_FLAGS
	 from DB.DBA.RDF_OBJ  where RO_ID=d_id and bit_and (RO_FLAGS, 1)) do
    {
      if (bit_and (RO_FLAGS, 2))
        vt_batch_feed (vtb, xml_tree_doc (__xml_deserialize_packed (RO_LONG)), 0);
      else
        vt_batch_feed (vtb, coalesce (RO_LONG, RO_VAL), 0);
    }
 }
  else
    {
  for (select RO_LONG, RO_VAL, RO_FLAGS
	 from DB.DBA.RDF_OBJ table option (no cluster) where RO_ID=d_id and bit_and (RO_FLAGS, 1)) do
    {
      if (bit_and (RO_FLAGS, 2))
        vt_batch_feed (vtb, xml_tree_doc (__xml_deserialize_packed (RO_LONG)), 0);
      else
        vt_batch_feed (vtb, coalesce (RO_LONG, RO_VAL), 0);
    }
    }
  return 1;
}
;

create procedure DB.DBA.RDF_OBJ_RO_FLAGS_UNINDEX_HOOK (inout vtb any, inout d_id any)
{
  if (cl_current_slice () = 0hexffff)
    {
  for (select RO_LONG, RO_VAL, RO_FLAGS
	 from DB.DBA.RDF_OBJ  where RO_ID=d_id and bit_and (RO_FLAGS, 1)) do
    {
      if (bit_and (RO_FLAGS, 2))
        vt_batch_feed (vtb, xml_tree_doc (__xml_deserialize_packed (RO_LONG)), 1);
      else
        vt_batch_feed (vtb, coalesce (RO_LONG, RO_VAL), 1);
    }
    }
  else
    {
  for (select RO_LONG, RO_VAL, RO_FLAGS
	 from DB.DBA.RDF_OBJ table option (no cluster) where RO_ID=d_id and bit_and (RO_FLAGS, 1)) do
    {
      if (bit_and (RO_FLAGS, 2))
        vt_batch_feed (vtb, xml_tree_doc (__xml_deserialize_packed (RO_LONG)), 1);
      else
        vt_batch_feed (vtb, coalesce (RO_LONG, RO_VAL), 1);
    }
    }
  return 1;
}
;

create procedure sparql_exec_quiet (in expn varchar)
{
  declare sta, msg varchar;
  exec (expn, sta, msg);
}
;

sparql_exec_quiet ('DB.DBA.vt_create_text_index (
      fix_identifier_case (''DB.DBA.RDF_OBJ''),
      fix_identifier_case (''RO_FLAGS''),
      fix_identifier_case (''RO_ID''),
      0, 0, vector (), 1, ''*ini*'', ''UTF-8-QR'')')
;

sparql_exec_quiet ('DB.DBA.vt_batch_update (fix_identifier_case (''DB.DBA.RDF_OBJ''), ''ON'', 1)')
;

--sparql_exec_quiet ('alter index VTLOG_DB_DBA_RDF_OBJ on VTLOG_DB_DBA_RDF_OBJ partition (VTLOG_RO_ID int (0hexffff00))')
--;

--!AWK PUBLIC
create function DB.DBA.XML_SET_NS_DECL (in prefix varchar, in url varchar, in persist integer := 1) returns integer
{
  declare res integer;
  res := __xml_set_ns_decl (prefix, url, persist);
  if (bit_and (res, 2))
    {
      declare exit handler for sqlstate '*' { __xml_remove_ns_by_prefix (prefix, persist); resignal; };
      if (exists (select 1 from DB.DBA.SYS_XML_PERSISTENT_NS_DECL where NS_PREFIX = prefix and NS_URL = url))
	return;
      delete from DB.DBA.SYS_XML_PERSISTENT_NS_DECL where NS_PREFIX = prefix;
      insert into DB.DBA.SYS_XML_PERSISTENT_NS_DECL (NS_PREFIX, NS_URL) values (prefix, url);
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
      whenever sqlstate '*' goto again;
again:
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
      whenever sqlstate '*' goto again;
again:
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
  DB.DBA.XML_SET_NS_DECL (	'bif'		, 'bif:'	, 2);
  DB.DBA.XML_SET_NS_DECL (	'dawgt'		, 'http://www.w3.org/2001/sw/DataAccess/tests/test-dawg#'	, 2);
  DB.DBA.XML_SET_NS_DECL (	'dbpedia'	, 'http://dbpedia.org/resource/'				, 2);
  DB.DBA.XML_SET_NS_DECL (	'dbpprop'	, 'http://dbpedia.org/property/'				, 2);
  DB.DBA.XML_SET_NS_DECL (	'dc'		, 'http://purl.org/dc/elements/1.1/'				, 2);
  DB.DBA.XML_SET_NS_DECL (	'go'		, 'http://purl.org/obo/owl/GO#'					, 2);
  DB.DBA.XML_SET_NS_DECL (	'geo'		, 'http://www.w3.org/2003/01/geo/wgs84_pos#'			, 2);
  DB.DBA.XML_SET_NS_DECL (	'fn'		, 'http://www.w3.org/2005/xpath-functions/#'			, 2);
  DB.DBA.XML_SET_NS_DECL (	'foaf'		, 'http://xmlns.com/foaf/0.1/'					, 2);
  DB.DBA.XML_SET_NS_DECL (	'obo'		, 'http://www.geneontology.org/formats/oboInOwl#'		, 2);
  DB.DBA.XML_SET_NS_DECL (	'ogc'		, 'http://www.opengis.net/'					, 2);
  DB.DBA.XML_SET_NS_DECL (	'ogcgml'	, 'http://www.opengis.net/ont/gml#'				, 2);
  DB.DBA.XML_SET_NS_DECL (	'ogcgs'		, 'http://www.opengis.net/ont/geosparql#'			, 2);
  DB.DBA.XML_SET_NS_DECL (	'ogcgsf'	, 'http://www.opengis.net/def/function/geosparql/'		, 2);
  DB.DBA.XML_SET_NS_DECL (	'ogcgsr'	, 'http://www.opengis.net/def/rule/geosparql/'			, 2);
  DB.DBA.XML_SET_NS_DECL (	'ogcsf'		, 'http://www.opengis.net/ont/sf#'				, 2);
  DB.DBA.XML_SET_NS_DECL (	'owl'		, 'http://www.w3.org/2002/07/owl#'				, 2);
  DB.DBA.XML_SET_NS_DECL (	'mesh'		, 'http://purl.org/commons/record/mesh/'			, 2);
  DB.DBA.XML_SET_NS_DECL (	'math'		, 'http://www.w3.org/2000/10/swap/math#'			, 2);
  DB.DBA.XML_SET_NS_DECL (	'mf'		, 'http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#'	, 2);
  DB.DBA.XML_SET_NS_DECL (	'nci'		, 'http://ncicb.nci.nih.gov/xml/owl/EVS/Thesaurus.owl#'		, 2);
  DB.DBA.XML_SET_NS_DECL (	'product'	, 'http://www.buy.com/rss/module/productV2/'			, 2);
  DB.DBA.XML_SET_NS_DECL (	'protseq'	, 'http://purl.org/science/protein/bysequence/'			, 2);
  DB.DBA.XML_SET_NS_DECL (	'rdf'		, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'			, 2);
  DB.DBA.XML_SET_NS_DECL (	'rdfa'		, 'http://www.w3.org/ns/rdfa#'					, 2);
  DB.DBA.XML_SET_NS_DECL (	'rdfdf'		, 'http://www.openlinksw.com/virtrdf-data-formats#'		, 2);
  DB.DBA.XML_SET_NS_DECL (	'rdfs'		, 'http://www.w3.org/2000/01/rdf-schema#'			, 2);
  DB.DBA.XML_SET_NS_DECL (	'sc'		, 'http://purl.org/science/owl/sciencecommons/'			, 2);
  DB.DBA.XML_SET_NS_DECL (	'sd'		, 'http://www.w3.org/ns/sparql-service-description#'		, 2);
  DB.DBA.XML_SET_NS_DECL (	'sioc'		, 'http://rdfs.org/sioc/ns#'					, 2);
  DB.DBA.XML_SET_NS_DECL (	'skos'		, 'http://www.w3.org/2004/02/skos/core#'			, 2);
  DB.DBA.XML_SET_NS_DECL (	'sql'		, 'sql:'							, 2);
  DB.DBA.XML_SET_NS_DECL (	'vcard'		, 'http://www.w3.org/2001/vcard-rdf/3.0#'			, 2);
  DB.DBA.XML_SET_NS_DECL (	'vcard2006'	, 'http://www.w3.org/2006/vcard/ns#'				, 2);
  DB.DBA.XML_SET_NS_DECL (	'virtrdf'	, 'http://www.openlinksw.com/schemas/virtrdf#'			, 2);
  DB.DBA.XML_SET_NS_DECL (	'virtcxml'	, 'http://www.openlinksw.com/schemas/virtcxml#'			, 2);
  DB.DBA.XML_SET_NS_DECL (	'void'		, 'http://rdfs.org/ns/void#'					, 2);
  DB.DBA.XML_SET_NS_DECL (	'xf'		, 'http://www.w3.org/2004/07/xpath-functions'			, 2);
  DB.DBA.XML_SET_NS_DECL (	'xml'		, 'http://www.w3.org/XML/1998/namespace'			, 2);
  DB.DBA.XML_SET_NS_DECL (	'xsd'		, 'http://www.w3.org/2001/XMLSchema#'				, 2);
  DB.DBA.XML_SET_NS_DECL (	'xsl10'		, 'http://www.w3.org/XSL/Transform/1.0'				, 2);
  DB.DBA.XML_SET_NS_DECL (	'xsl1999'	, 'http://www.w3.org/1999/XSL/Transform'			, 2);
  DB.DBA.XML_SET_NS_DECL (	'xslwd'		, 'http://www.w3.org/TR/WD-xsl'					, 2);
  DB.DBA.XML_SET_NS_DECL (	'yago'		, 'http://dbpedia.org/class/yago/'				, 2);
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
      rule_g_iid := case (rule_g) when '' then null else iri_to_id (rule_g) end;
      rule_p_iid := case (rule_p) when '' then null else iri_to_id (rule_p) end;
      -- dbg_obj_princ ('__rdf_obj_ft_rule_add (', rule_g_iid, rule_p_iid, reason, ')');
      __rdf_obj_ft_rule_add (rule_g_iid, rule_p_iid, reason);
    }
}
;

DB.DBA.RDF_LOAD_ALL_FT_RULES ()
;

create procedure DB.DBA.RDF_REPL_START (in quiet integer := 0)
{
  if (repl_this_server () is null)
    return;
  if (isstring (registry_get ('DB.DBA.RDF_REPL')))
    {
      if (quiet)
        return;
      signal ('RDF99', 'RDF replication is already enabled');
    }
  for (select RGGM_MEMBER_IID from DB.DBA.RDF_GRAPH_GROUP_MEMBER
  where RGGM_GROUP_IID = iri_to_id (UNAME'http://www.openlinksw.com/schemas/virtrdf#rdf_repl_graph_group')
    and not __rgs_ack_cbk (RGGM_MEMBER_IID, __rdf_repl_uid(), 1) ) do
    {
      signal ('RDF99', 'RDF replication can not be enabled because it will violate security rules for read access to graph <' || id_to_iri(RGGM_MEMBER_IID) || '> by __rdf_repl account');
    }
  repl_publish ('__rdf_repl', '__rdf_repl.log');
  repl_text ('__rdf_repl', '__rdf_repl_flush_queue()');
  DB.DBA.RDF_GRAPH_GROUP_CREATE (UNAME'http://www.openlinksw.com/schemas/virtrdf#rdf_repl_graph_group', 1);
  DB.DBA.CL_EXEC ('registry_set (?,?)', vector ('DB.DBA.RDF_REPL', cast (now() as varchar)));
  exec ('checkpoint');
}
;

create procedure DB.DBA.RDF_REPL_STOP (in quiet integer := 0)
{
  if (not isstring (registry_get ('DB.DBA.RDF_REPL')))
    {
      if (quiet)
        return;
      signal ('RDF99', 'RDF replication is not enabled');
    }
  repl_unpublish ('__rdf_repl');
  DB.DBA.CL_EXEC ('registry_remove (?)', vector ('DB.DBA.RDF_REPL'));
}
;

create procedure DB.DBA.RDF_REPL_GRAPH_INS (in memb_iri varchar)
{
  declare memb_iid IRI_ID;
  memb_iid := iri_to_id (memb_iri);
  memb_iri := id_to_iri (memb_iid);
  DB.DBA.RDF_GRAPH_GROUP_INS (UNAME'http://www.openlinksw.com/schemas/virtrdf#rdf_repl_graph_group', memb_iri);
}
;

create procedure DB.DBA.RDF_REPL_GRAPH_DEL (in memb_iri varchar)
{
  declare memb_iid IRI_ID;
  DB.DBA.RDF_GRAPH_GROUP_DEL (UNAME'http://www.openlinksw.com/schemas/virtrdf#rdf_repl_graph_group', memb_iri);
}
;

create procedure DB.DBA.RDF_REPL_SYNC (in publisher varchar, in u varchar, in pwd varchar)
{
  declare lvl, stat integer;
  if (repl_this_server () is null)
    return;
  commit work;
retr:

  repl_sync (publisher, '__rdf_repl', u, pwd);
again:
  repl_status (publisher, '__rdf_repl', lvl, stat);
  if (0 = stat)
    {
      __rdf_repl_flush_queue();
      return;
    }
  if (1 = stat)
    {
      delay (0.1);
      goto again;
    }
  if (2 = stat)
    {
      __rdf_repl_flush_queue();
      return;
    }
  goto retr;
}
;


create procedure DB.DBA.RDF_REPL_INSERT_TRIPLES (in graph_iri varchar, inout triples any)
{
  declare ctr integer;
  for (ctr := length (triples) - 1; ctr >= 0; ctr := ctr - 1)
    {
      declare s_iri, p_iri, o_val, o_type, o_lang any;
      s_iri := iri_canonicalize (triples[ctr][0]);
      p_iri := iri_canonicalize (triples[ctr][1]);
      o_val := triples[ctr][2];
      if (isiri_id (o_val))
        __rdf_repl_quad (84, graph_iri, s_iri, p_iri, iri_canonicalize (o_val));
      else if (__tag of rdf_box <> __tag (o_val))
        __rdf_repl_quad (80, graph_iri, s_iri, p_iri, o_val);
      else
        {
          declare dt_twobyte, lang_twobyte integer;
          dt_twobyte := rdf_box_type (o_val);
          lang_twobyte := rdf_box_lang (o_val);
          if (257 <> dt_twobyte)
            __rdf_repl_quad (81, graph_iri, s_iri, p_iri, rdf_box_data (o_val), (select RDT_QNAME from DB.DBA.RDF_DATATYPE where RDT_TWOBYTE = dt_twobyte), NULL);
          else if (257 <> lang_twobyte)
            __rdf_repl_quad (82, graph_iri, s_iri, p_iri, rdf_box_data (o_val), NULL, (select RL_ID from DB.DBA.RDF_LANGUAGE where RL_TWOBYTE = lang_twobyte));
          else
            __rdf_repl_quad (80, graph_iri, s_iri, p_iri, rdf_box_data (o_val));
        }
    }
}
;

create procedure DB.DBA.RDF_REPL_DELETE_TRIPLES (in graph_iri varchar, inout triples any)
{
  declare ctr integer;
  for (ctr := length (triples) - 1; ctr >= 0; ctr := ctr - 1)
    {
      declare s_iri, p_iri, o_val, o_type, o_lang any;
      s_iri := iri_canonicalize (triples[ctr][0]);
      p_iri := iri_canonicalize (triples[ctr][1]);
      o_val := triples[ctr][2];
      if (isiri_id (o_val))
        __rdf_repl_quad (164, graph_iri, s_iri, p_iri, iri_canonicalize (o_val));
      else if (__tag of rdf_box <> __tag (o_val))
        __rdf_repl_quad (160, graph_iri, s_iri, p_iri, o_val);
      else
        {
          declare dt_twobyte, lang_twobyte integer;
          dt_twobyte := rdf_box_type (o_val);
          lang_twobyte := rdf_box_lang (o_val);
          if (257 <> dt_twobyte)
            __rdf_repl_quad (161, graph_iri, s_iri, p_iri, rdf_box_data (o_val), (select RDT_QNAME from DB.DBA.RDF_DATATYPE where RDT_TWOBYTE = dt_twobyte), NULL);
          else if (257 <> lang_twobyte)
            __rdf_repl_quad (162, graph_iri, s_iri, p_iri, rdf_box_data (o_val), NULL, (select RL_ID from DB.DBA.RDF_LANGUAGE where RL_TWOBYTE = lang_twobyte));
          else
            __rdf_repl_quad (160, graph_iri, s_iri, p_iri, rdf_box_data (o_val));
        }
    }
}
;

--!AFTER
create procedure DB.DBA.RDF_GLOBAL_RESET (in hard integer := 0)
{
  if (isstring (registry_get ('DB.DBA.RDF_REPL')))
    {
      signal ('42RDF', 'Can not make DB.DBA.RDF_GLOBAL_RESET while an RDF replication is enabled');
    }
--  checkpoint;
  __atomic (1);
  iri_id_cache_flush ();
  __rdf_obj_ft_rule_zap_all ();
  dict_zap (__rdf_graph_group_dict(), 2);
  dict_zap (__rdf_graph_group_of_privates_dict(), 2);
  dict_zap (__rdf_graph_default_perms_of_user_dict(0), 2);
  dict_zap (__rdf_graph_default_perms_of_user_dict(1), 2);
  dict_zap (__rdf_graph_public_perms_dict(), 2);
  for select RS_NAME from DB.DBA.SYS_RDF_SCHEMA do
    rdf_inf_clear (RS_NAME);
  delete from sys_rdf_schema;
  delete from DB.DBA.RDF_QUAD;
  delete from DB.DBA.RDF_OBJ_FT_RULES;
  delete from DB.DBA.RDF_GRAPH_GROUP;
  for (select __id2i(t.RGU_GRAPH_IID) as graph_iri from (select distinct RGU_GRAPH_IID from DB.DBA.RDF_GRAPH_USER) as t) do
    {
      if (graph_iri is not null)
        {
          jso_mark_affected (graph_iri);
          log_text ('jso_mark_affected (?)', graph_iri);
          jso_mark_affected (iri_canonicalize (graph_iri));
          log_text ('jso_mark_affected (?)', iri_canonicalize (graph_iri));
          log_text ('jso_mark_affected (iri_canonicalize (?))', graph_iri);
        }
    }
  for (select __id2i(t.RGGM_GROUP_IID) as group_iri from (select distinct RGGM_GROUP_IID from DB.DBA.RDF_GRAPH_GROUP_MEMBER) as t) do
    {
      if (group_iri is not null)
	{
	  jso_mark_affected (group_iri);
	  log_text ('jso_mark_affected (?)', group_iri);
	}
    }
  for (select __id2i(RGGM_MEMBER_IID) as memb_iri from DB.DBA.RDF_GRAPH_GROUP_MEMBER where RGGM_GROUP_IID = __i2id ('http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs')) do
    {
      if (memb_iri is not null)
	{
	  jso_mark_affected (memb_iri);
	  log_text ('jso_mark_affected (?)', memb_iri);
	}
    }
  for (sparql define input:storage "" select distinct str (?qms) as ?qms_iri from virtrdf: where { ?qms a virtrdf:QuadStorage } ) do
    {
      if ("qms_iri" is not null)
	{
	  jso_mark_affected ("qms_iri");
	  log_text ('jso_mark_affected (?)', "qms_iri");
	}
    }
  jso_mark_affected ('http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs');
  log_text ('jso_mark_affected (?)', 'http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs');
  jso_mark_affected ('http://www.openlinksw.com/schemas/virtrdf#DefaultQuadStorage');
  log_text ('jso_mark_affected (?)', 'http://www.openlinksw.com/schemas/virtrdf#DefaultQuadStorage');
  jso_mark_affected ('http://www.openlinksw.com/schemas/virtrdf#DefaultQuadMap');
  log_text ('jso_mark_affected (?)', 'http://www.openlinksw.com/schemas/virtrdf#DefaultQuadMap');
  delete from DB.DBA.RDF_GRAPH_GROUP_MEMBER;
  delete from DB.DBA.RDF_GRAPH_USER;
  delete from DB.DBA.RDF_LABEL;
  delete from DB.DBA.RDF_GEO;
  commit work;
  if (hard)
    {
      --delete from DB.DBA.RDF_URL;
      delete from DB.DBA.RDF_IRI;
      delete from DB.DBA.RDF_PREFIX;
      delete from DB.DBA.RDF_OBJ;
      delete from DB.DBA.RO_START;
      delete from DB.DBA.RDF_DATATYPE;
      delete from DB.DBA.RDF_LANGUAGE;
      --__rdf_twobyte_cache_zap();
      --log_text ('__rdf_twobyte_cache_zap()');
      delete from DB.DBA.VTLOG_DB_DBA_RDF_OBJ;
      delete from DB.DBA.RDF_OBJ_RO_FLAGS_WORDS;
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

virtrdf:DefaultServiceStorage
  rdf:type virtrdf:QuadStorage ;
  virtrdf:qsUserMaps virtrdf:DefaultServiceStorage-UserMaps ;
  virtrdf:qsDefaultMap virtrdf:DefaultServiceMap ;
  virtrdf:qsMatchingFlags virtrdf:SPART_QS_NO_IMPLICIT_USER_QM .
virtrdf:DefaultServiceStorage-UserMaps
  rdf:type virtrdf:array-of-QuadMap .

virtrdf:SyncToQuads
  rdf:type virtrdf:QuadStorage ;
  virtrdf:qsUserMaps virtrdf:SyncToQuads-UserMaps .
virtrdf:SyncToQuads-UserMaps
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


-----
-- Handling of IRI IDs

create function DB.DBA.RDF_MAKE_IID_OF_QNAME (in qname varchar) returns IRI_ID
{
  return iri_to_id (qname);
}
;


create function DB.DBA.RDF_MAKE_IID_OF_LONG (in qname any) returns IRI_ID -- DEPRECATED
{
  if (isiri_id (qname))
    return qname;
  if (not isstring (qname))
    {
      if (__tag of rdf_box = __tag (qname) and rdf_box_is_complete (qname))
        qname := rdf_box_data (qname, 1);
      else
        qname := __rdf_strsqlval (qname);
    }
  return iri_to_id_nosignal (qname);
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

create function DB.DBA.RDF_TWOBYTE_OF_DATATYPE (in iid any) returns integer
{
  declare res integer;
  declare qname varchar;
  if (iid is null)
    return 257;
  if (not isiri_id (iid))
    {
      declare new_iid IRI_ID;
      new_iid := iri_to_id (iid);
      if (new_iid is NULL or new_iid >= min_bnode_iri_id ())
        signal ('RDFXX', 'Invalid datatype IRI_ID passes as an argument to DB.DBA.RDF_TWOBYTE_OF_DATATYPE()');
      iid := new_iid;
    }
  qname := id_to_iri (iid);
  res := rdf_cache_id ('t', qname);
  if (res)
    return res;
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
    {
      if (res = 0hex7F00)
        {
          sequence_set ('RDF_DATATYPE_TWOBYTE', 0hex7F00, 0);
          res := 0hex7F01;
          qname := 'http://www.openlinksw.com/schemas/virtrdf#Unsaved';
          iid := iri_to_id (qname);
          insert soft DB.DBA.RDF_DATATYPE
            (RDT_IID, RDT_TWOBYTE, RDT_QNAME)
          values (iid, res, qname);
          goto cache_and_log;
        }
      res := sequence_next ('RDF_DATATYPE_TWOBYTE');
    }
  insert into DB.DBA.RDF_DATATYPE
    (RDT_IID, RDT_TWOBYTE, RDT_QNAME)
  values (iid, res, qname);
cache_and_log:
  rdf_cache_id ('t', qname, res);
  log_text ('rdf_cache_id (\'t\', ?, ?)', qname, res);  --'
  return res;
}
;

create function DB.DBA.RDF_PRESET_TWOBYTES_OF_DATATYPES ()
{
  declare xsd_lnames any;
  xsd_lnames := vector (
    'ENTITY',
    'ENTITIES',
    'ID',
    'IDREF',
    'IDREFS',
    'NCName',
    'Name',
    'NMTOKEN',
    'NMTOKENS',
    'NOTATION',
    'QName',
    'any',
    'anyAtomicType',
    'anySimpleType',
    'anyType',
    'anyURI',
    'base64Binary',
    'boolean',
    'byte',
    'date',
    'dateTime',
    'dateTimeStamp',
    'dayTimeDuration',
    'decimal',
    'double',
    'duration',
    'float',
    'gDay',
    'gMonth',
    'gMonthDay',
    'gYear',
    'gYearMonth',
    'hexBinary',
    'int',
    'integer',
    'language',
    'long',
    'negativeInteger',
    'nonNegativeInteger',
    'nonPositiveInteger',
    'normalizedString',
    'positiveInteger',
    'short',
    'string',
    'time',
    'token',
    'unsignedByte',
    'unsignedInt',
    'unsignedLong',
    'unsignedShort',
    'yearMonthDuration' );
  foreach (varchar n in xsd_lnames) do
    {
      __dbf_set ('rb_type__xsd:' || n, DB.DBA.RDF_TWOBYTE_OF_DATATYPE (iri_to_id ('http://www.w3.org/2001/XMLSchema#' || n)));
    }
  commit work;
}
;

DB.DBA.RDF_PRESET_TWOBYTES_OF_DATATYPES ()
;

create function DB.DBA.RDF_TWOBYTE_OF_LANGUAGE (in id varchar) returns integer
{
  declare res integer;
  if (id is null)
    return 257;
  id := lower (id);
  res := rdf_cache_id ('l', id);
  if (res)
    return res;
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
    {
      if (res = 0hex7F00)
        {
          sequence_set ('RDF_LANGUAGE_TWOBYTE', 0hex7F00, 0);
          res := 0hex7F01;
          id := 'x-unsaved';
          insert soft DB.DBA.RDF_LANGUAGE (RL_ID, RL_TWOBYTE) values (id, res);
          goto cache_and_log;
        }
      res := sequence_next ('RDF_LANGUAGE_TWOBYTE');
    }
  insert into DB.DBA.RDF_LANGUAGE (RL_ID, RL_TWOBYTE) values (id, res);
cache_and_log:
  rdf_cache_id ('l', id, res);
  log_text ('rdf_cache_id (\'l\', ?, ?)', id, res); --'
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
      signal ('RDFXX', signal ('RDFXX', sprintf ('Unknown datatype in DB.DBA.RQ_BOOL_OF_O, bad type id %d, string value "%s"',
    twobyte, cast (rdf_box_data (o_col) as varchar) ) );
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



create procedure RDF_G_INS (in id int, in g any)
{
  geo_insert ('DB.DBA.RDF_GEO', g, id);
}
;

create procedure cl_rdf_geo_insert (in id int, inout g any)
{
  declare daq any;
  daq := daq (1);
  daq_call (daq, 'DB.DBA.RDF_OBJ', 'RDF_OBJ', 'DB.DBA.RDF_G_INS', vector (id, g), 1);
  daq_results (daq);
}
;

create function rdf_geo_add (in v any)
{
  declare id, h, ser, g any;
  if (rdf_box_ro_id (v))
    return v;
 g := rdf_box_data (v);
  if (not isgeometry (g))
    signal ('22023', 'RDFXX', 'Must be geometry box if to be stored as geo object');
  ser := serialize (g);
  if (length (ser) > 50)
    h := mdigest5 (ser);
  else
    {
      h := ser;
      ser := null;
    }
  set isolation = 'committed';
  id := (select ro_id, ro_val, ro_long from rdf_obj where ro_val = h and ro_dt_and_lang = 0hex1000101 and case when ro_long is not null then equ (blob_to_string (ro_long),  ser) else 1 end );
  if (id is not null)
    {
      rdf_box_set_ro_id (v, id);
      return v;
    }
  set isolation = 'serializable';
  id := (select ro_id, ro_val, ro_long from rdf_obj where ro_val = h and ro_dt_and_lang = 0hex1000101 and case when ro_long is not null then equ (blob_to_string (ro_long),  ser) else 1 end for update);
  if (id is not null)
    {
      rdf_box_set_ro_id (v, id);
      return v;
    }
 id := sequence_next ('RDF_RO_ID');
  set triggers off;
  -- dbg_obj_princ ('zero RO_FLAGS in sparql.sql:997 ', ro_val, ro_long);
  insert into rdf_obj (ro_id, ro_val, ro_long, ro_dt_and_lang)
    values (id, h, ser, 0hex1000101);
  if (1 = sys_stat ('cl_run_local_only'))
    geo_insert ('DB.DBA.RDF_GEO', g, id);
  else
    cl_rdf_geo_insert (id, g);
  rdf_box_set_ro_id (v, id);
  return v;
}
;

create function rdf_geo_set_id (inout v any)
{
  declare id, h, ser, g any;
  if (rdf_box_ro_id (v))
    return v;
  g := rdf_box_data (v);
  if (not isgeometry (g))
    signal ('22023', 'RDFXX', 'Must be geometry box if to be stored as geo object');
  ser := serialize (g);
  if (length (ser) > 50)
    h := mdigest5 (ser);
  else
    {
      h := ser;
      ser := null;
    }
  set isolation = 'committed';
  id := (select RO_ID from RDF_OBJ where RO_VAL = h and RO_DT_AND_LANG = 0hex1000101
  	and case when RO_LONG is not null then equ (blob_to_string (RO_LONG),  ser) else 1 end );
  if (id is not null)
    {
      rdf_box_set_ro_id (v, id);
      return v;
    }
  return null;
}
;

create function DB.DBA.RDF_OBJ_ADD (in dt_twobyte integeR, in v varchar, in lang_twobyte integeR, in ro_id_dict any := 0) returns varchar
{
  declare llong, id, need_digest integer;
  declare digest any;
  declare old_flags, dt_and_lang integer;
  -- dbg_obj_princ ('DB.DBA.RDF_OBJ_ADD (', dt_twobyte, v, lang_twobyte, case (isnull (ro_id_dict)) when 1 then '/*no_ft*/' else '/*want_ft*/' end,')');
  if (isinteger (ro_id_dict))
    {
      if (__rdf_obj_ft_rule_check (null, null))
        ro_id_dict := dict_new ();
      else
        ro_id_dict := null;
    }
  if (126 = __tag (v))
    v := blob_to_string (v);
  if (isstring (rdf_box_data (v)))
    need_digest := rdf_box_needs_digest (v, ro_id_dict);
  else if (__tag of XML = __tag (v))
    need_digest := 1;
  if (__tag of rdf_box = __tag (v))
    {
      if (256 = rdf_box_type (v))
	return rdf_geo_add (v);
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
  dt_and_lang := bit_or (bit_shift (dt_twobyte, 16), lang_twobyte);
  if (not isstring (v))
    {
      declare sum64 varchar;
      if (__tag of XML <> __tag (v))
        signal ('RDFXX', sprintf ('Bad call: DB.DBA.RDF_OBJ_ADD (%d, %s, %d)',
          dt_twobyte, "LEFT" (cast (v as varchar), 100), lang_twobyte) );
      sum64 := xtree_sum64 (v);
      whenever not found goto serializable_xtree;
      set isolation='committed';
      select RO_ID, RO_FLAGS into id, old_flags
      from DB.DBA.RDF_OBJ table option (index RO_VAL)
      where RO_VAL = sum64
      and RO_DT_AND_LANG = dt_and_lang
      and bit_and (RO_FLAGS, 2);
      --!TBD ... and paranoid check

      goto found_xtree;
serializable_xtree:
      whenever not found goto new_xtree;
      set isolation='serializable';
      declare id_cr cursor for
        select RO_ID, RO_FLAGS from DB.DBA.RDF_OBJ table option (index RO_VAL) where RO_VAL = sum64
        and RO_DT_AND_LANG = dt_and_lang
        and bit_and (RO_FLAGS, 2);
      --!TBD ... and paranoid check
      open id_cr (exclusive);
      fetch id_cr into id, old_flags;
found_xtree:
      digest := rdf_box (v, dt_twobyte, lang_twobyte, id, 1);
      if (ro_id_dict is not null)
        {
          if (not (bit_and (old_flags, 1)))
	    {
	      update DB.DBA.RDF_OBJ set RO_FLAGS = bit_or (RO_FLAGS, 1) where RO_ID = id;
	      --insert soft rdf_ft (rf_id, rf_o) values (id, digest);
	    }
          dict_put (ro_id_dict, id, 1);
        }
      if (not (rdf_box_is_storeable (digest)))
        signal ('RDFX2', 'DB.DBA.RDF_OBJ_ADD() tries to return bad digest');
      return digest;
      -- goto recheck;
new_xtree:
      id := sequence_next ('RDF_RO_ID');
      digest := rdf_box (v, dt_twobyte, lang_twobyte, id, 1);
      -- if (ro_id_dict is null)
      --   {
      --     dbg_obj_princ ('zero RO_FLAGS in sparql.sql:1124');
      --     ;
      --   }
      insert into DB.DBA.RDF_OBJ (RO_ID, RO_VAL, RO_LONG, RO_FLAGS, RO_DT_AND_LANG) values
        (id, sum64, __xml_serialize_packed (v), case (isnull (ro_id_dict)) when 0 then 3 else 2 end, dt_and_lang);
      --if (ro_id_dict is not null)
	--insert soft rdf_ft (rf_id, rf_o) values (id, digest);
      if (ro_id_dict is not null)
        dict_put (ro_id_dict, id, 1);
      if (not (rdf_box_is_storeable (digest)))
        signal ('RDFX3', 'DB.DBA.RDF_OBJ_ADD() tries to return bad digest');
      return digest;
      -- old_digest := null;
      -- goto recheck;
    }
  if ((dt_twobyte = 257) and (lang_twobyte = 257) and (length (v) <= -1))
    {
      if (1 >= need_digest)
        return v;
      whenever not found goto serializable_veryshort;
      set isolation='committed';
      select RO_ID into id
      from DB.DBA.RDF_OBJ table option (index RO_VAL)
      where RO_VAL = v and RO_DT_AND_LANG = dt_and_lang and not (bit_and (RO_FLAGS, 2));
      goto found_veryshort;
serializable_veryshort:
      whenever not found goto new_veryshort;
      set isolation='serializable';
      declare id_cr cursor for select RO_ID
      from DB.DBA.RDF_OBJ table option (index RO_VAL)
      where RO_VAL = v and RO_DT_AND_LANG = dt_and_lang and not (bit_and (RO_FLAGS, 2));
      open id_cr (exclusive);
      fetch id_cr into id;
found_veryshort:
      if (ro_id_dict is not null)
	{
	  dict_put (ro_id_dict, id, 1);
	  --insert soft rdf_ft (rf_id, rf_o) values (id, v);
	}
      if (not (rdf_box_is_storeable (v)))
        signal ('RDFX4', 'DB.DBA.RDF_OBJ_ADD() tries to return bad digest');
      return v;
new_veryshort:
      id := sequence_next ('RDF_RO_ID');
      insert into DB.DBA.RDF_OBJ (RO_ID, RO_VAL, RO_FLAGS, RO_DT_AND_LANG) values (id, v, 1, dt_and_lang);
      if (ro_id_dict is not null)
	{
	  dict_put (ro_id_dict, id, 1);
	}
      insert into DB.DBA.RO_START (RS_START, RS_DT_AND_LANG, RS_RO_ID)
        values (subseq (v, 0, case when length (v) > 10 then 10 else length (v) end), dt_and_lang, rdf_box (0, 257, 257, id, 0));
      if (not (rdf_box_is_storeable (v)))
        signal ('RDFX5', 'DB.DBA.RDF_OBJ_ADD() tries to return bad digest');
      return v;
    }
  llong := 50;
  if (length (v) > llong)
    {
      declare chksm varchar;
      chksm := mdigest5 (v, 1);
      whenever not found goto serializable_long;
      set isolation='committed';
      select RO_ID, RO_FLAGS into id, old_flags
      from DB.DBA.RDF_OBJ table option (index RO_VAL)
      where RO_VAL = chksm
      and RO_DT_AND_LANG = dt_and_lang
      and not (bit_and (RO_FLAGS, 2))
      and blob_to_string (RO_LONG) = v;
      goto found_long;
serializable_long:
      whenever not found goto new_long;
      set isolation='serializable';
      declare id_cr cursor for
        select RO_ID, RO_FLAGS from DB.DBA.RDF_OBJ
      table option (index RO_VAL) where RO_VAL = chksm
      and RO_DT_AND_LANG = dt_and_lang
      and not (bit_and (RO_FLAGS, 2))
      and blob_to_string (RO_LONG) = v;
      open id_cr (exclusive);
      fetch id_cr into id, old_flags;
found_long:
      digest := rdf_box (v, dt_twobyte, lang_twobyte, id, 1);
      if ((not (bit_and (old_flags, 1))) and (1 < need_digest))
        update DB.DBA.RDF_OBJ set RO_FLAGS = bit_or (RO_FLAGS, 1) where RO_ID = id;
      if (ro_id_dict is not null)
	{
	  dict_put (ro_id_dict, id, 1);
	}
      if (not (rdf_box_is_storeable (digest)))
        signal ('RDFX6', 'DB.DBA.RDF_OBJ_ADD() tries to return bad digest');
      return digest;
new_long:
      id := sequence_next ('RDF_RO_ID');
      digest := rdf_box (v, dt_twobyte, lang_twobyte, id, 1);
      if (1 < need_digest)
        insert into DB.DBA.RDF_OBJ (RO_ID, RO_VAL, RO_LONG, RO_FLAGS, RO_DT_AND_LANG)
        values (id, chksm, v, 1, dt_and_lang);
      else
        {
          set triggers off;
          -- dbg_obj_princ ('zero RO_FLAGS in sparql.sql:1225 ', chksm, v);
          insert into DB.DBA.RDF_OBJ (RO_ID, RO_VAL, RO_LONG, RO_DT_AND_LANG)
          values (id, chksm, v, dt_and_lang);
          set triggers on;
        }
      if (ro_id_dict is not null)
	{
	  dict_put (ro_id_dict, id, 1);
	}
      insert into DB.DBA.RO_START (RS_START, RS_DT_AND_LANG, RS_RO_ID)
        -- no need in values (subseq (v, 0, case when length (v) > 10 then 10 else length (v), RO_DT_AND_LANG, rdf_box (0, 257, 257, id, 0));
        values (subseq (v, 0, 10), dt_and_lang, rdf_box (0, 257, 257, id, 0));
      if (not (rdf_box_is_storeable (digest)))
        signal ('RDFX7', 'DB.DBA.RDF_OBJ_ADD() tries to return bad digest');
      return digest;
    }
  else
    {
      whenever not found goto serializable_short;
      set isolation='committed';
      select RO_ID, RO_FLAGS into id, old_flags
      from DB.DBA.RDF_OBJ table option (index RO_VAL)
      where RO_VAL = v
      and RO_DT_AND_LANG = dt_and_lang;
      goto found_short;
serializable_short:
      whenever not found goto new_short;
      set isolation='serializable';
      declare id_cr cursor for select RO_ID, RO_FLAGS
      from DB.DBA.RDF_OBJ table option (index RO_VAL)
      where RO_VAL = v
      and RO_DT_AND_LANG = dt_and_lang;
      open id_cr (exclusive);
      fetch id_cr into id, old_flags;
found_short:
      digest := rdf_box (v, dt_twobyte, lang_twobyte, id, 1);
      if ((not (bit_and (old_flags, 1))) and (1 < need_digest))
        update DB.DBA.RDF_OBJ set RO_FLAGS = bit_or (RO_FLAGS, 1) where RO_ID = id;
      if (ro_id_dict is not null)
	{
	  dict_put (ro_id_dict, id, 1);
	}
      if (not (rdf_box_is_storeable (digest)))
        signal ('RDFX8', 'DB.DBA.RDF_OBJ_ADD() tries to return bad digest');
      return digest;
new_short:
      id := sequence_next ('RDF_RO_ID');
      digest := rdf_box (v, dt_twobyte, lang_twobyte, id, 1);
      if (1 < need_digest)
        insert into DB.DBA.RDF_OBJ (RO_ID, RO_VAL, RO_FLAGS, RO_DT_AND_LANG)
        values (id, v, 1, dt_and_lang);
      else
        {
          -- dbg_obj_princ ('zero RO_FLAGS in sparql.sql:1271 ', v);
          set triggers off;
          insert into DB.DBA.RDF_OBJ (RO_ID, RO_VAL, RO_FLAGS, RO_DT_AND_LANG)
          values (id, v, 0, dt_and_lang);
          set triggers on;
        }
      insert into DB.DBA.RO_START (RS_START, RS_DT_AND_LANG, RS_RO_ID)
        values (subseq (v, 0, case when length (v) > 10 then 10 else length (v) end), dt_and_lang, rdf_box (0, 257, 257, id, 0));
      if (ro_id_dict is not null)
	{
	  dict_put (ro_id_dict, id, 1);
	}
      if (not (rdf_box_is_storeable (digest)))
        signal ('RDFX9', 'DB.DBA.RDF_OBJ_ADD() tries to return bad digest');
      return digest;
    }
recheck:
  -- dbg_obj_princ ('recheck: id=', id, ', old_digest=', old_digest, ', need_digest=', need_digest, ', digest=', digest);
  signal ('FUNNY', 'Debug code of DB.DBA.RDF_OBJ_ADD() is reached. This can not happen (I believe). Please report this error.');
}
;

create function DB.DBA.RDF_FIND_RO_DIGEST (in dt_twobyte integeR, in v varchar, in lang_twobyte integeR) returns varchar
{
  declare llong, dt_and_lang int;
  declare dt_s, lang_s, chksm, sum64 varchar;
  declare digest, old_digest any;
  if (126 = __tag (v))
    v := blob_to_string (v);
  dt_and_lang := bit_or (bit_shift (dt_twobyte, 16), lang_twobyte);
  if (not (isstring (v)))
    {
      if (__tag of XML <> __tag (v))
        return v;
      sum64 := xtree_sum64 (v);
      return (select rdf_box (v, dt_twobyte, lang_twobyte, RO_ID, 1)
        from DB.DBA.RDF_OBJ table option (index RO_VAL)
        where RO_VAL = sum64
        and RO_DT_AND_LANG = dt_and_lang
        and bit_and (RO_FLAGS, 2)
        --!TBD ... and paranoid check
        );
    }
  if ((dt_twobyte = 257) and (lang_twobyte = 257) and (length (v) <= 20))
    return v;
  llong := 50;
  if (length (v) > llong)
    {
      chksm := mdigest5 (v, 1);
      return (select rdf_box (v, dt_twobyte, lang_twobyte, RO_ID, 1)
        from DB.DBA.RDF_OBJ table option (index RO_VAL)
        where RO_VAL = chksm
        and RO_DT_AND_LANG = dt_and_lang
        and not (bit_and (RO_FLAGS, 2))
        and blob_to_string (RO_LONG) = v );
    }
  else
    {
      return (select rdf_box (v, dt_twobyte, lang_twobyte, RO_ID, 1)
        from DB.DBA.RDF_OBJ table option (index RO_VAL)
        where RO_VAL = v
        and RO_DT_AND_LANG = dt_and_lang
        and not (bit_and (RO_FLAGS, 2)) );
    }
}
;

create function DB.DBA.RDF_MAKE_OBJ_OF_SQLVAL (in v any) returns any array
{
  declare t int;
  t := __tag (v);
  if (not (t in (126, __tag of varchar, 217, __tag of nvarchar, __tag of XML, __tag of rdf_box)))
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
  -- dbg_obj_princ ('DB.DBA.RDF_MAKE_OBJ_OF_SQLVAL_FT (', v, g_iid, p_iid, ro_id_dict, ')');
  t := __tag (v);
  if (not (t in (126, __tag of varchar, 217, __tag of nvarchar, __tag of XML, __tag of rdf_box)))
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

create function DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL (in v any, in dt_iid IRI_ID, in lang varchar) returns any array
{
  declare t, dt_twobyte, lang_twobyte int;
  -- dbg_obj_princ ('DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL (', v, dt_iid, lang, ')');
retry_unrdf:
  t := __tag (v);
  if (not (t in (126, __tag of varchar, 217, __tag of nvarchar, __tag of XML)))
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
  -- dbg_obj_princ ('DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL (', v, dt_iid, lang, ') calls DB.DBA.RDF_OBJ_ADD (', dt_twobyte, v, lang_twobyte, ')');
  return DB.DBA.RDF_OBJ_ADD (dt_twobyte, v, lang_twobyte);
}
;

create function DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL_FT (in v any, in dt_iid IRI_ID, in lang varchar, in g_iid IRI_ID, in p_iid IRI_ID, in ro_id_dict any := null) returns any array
{
  declare t, dt_twobyte, lang_twobyte int;
  -- dbg_obj_princ ('DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL_FT (', v, dt_iid, lang, g_iid, p_iid, ro_id_dict, ')');
retry_unrdf:
  t := __tag (v);
  if (not (t in (126, __tag of varchar, 217, __tag of nvarchar, __tag of XML)))
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
  in o_val any, in o_type varchar, in o_lang varchar ) returns any array
{
  -- dbg_obj_princ ('DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL_STRINGS (', o_val, o_type, o_lang, ')');
  if (__tag (o_type) in (__tag of varchar, 217))
    {
      declare parsed any;
      parsed := __xqf_str_parse_to_rdf_box (o_val, o_type, isstring (o_val));
      if (parsed is not null)
        {
          if (__tag of XML = __tag (parsed))
            {
              return DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL (
                parsed, iri_to_id (o_type), null );
            }
          if (__tag of rdf_box = __tag (parsed))
            {
              if (256 = rdf_box_type (parsed))
                db..rdf_geo_add (parsed);
              else
                rdf_box_set_type (parsed,
                  DB.DBA.RDF_TWOBYTE_OF_DATATYPE (iri_to_id (o_type)));
              parsed := DB.DBA.RDF_OBJ_ADD (257, parsed, 257, null);
            }
          return parsed;
        }
      return DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL (
        o_val,
        iri_to_id (o_type),
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

create function DB.DBA.RDF_DATATYPE_OF_OBJ (in shortobj any, in dflt varchar := UNAME'http://www.w3.org/2001/XMLSchema#string') returns any
{
  declare twobyte integer;
  declare res any;
  if (__tag of rdf_box <> __tag (shortobj))
    {
      if (isiri_id (shortobj))
        return null;
      if (isstring (shortobj) and bit_and (__box_flags (shortobj), 1))
        return null;
      -- dbg_obj_princ ('DB.DBA.RDF_DATATYPE_OF_OBJ (', shortobj, ') will return ', __xsd_type (shortobj, dflt), ' for non-rdfbox');
      return __xsd_type (shortobj, dflt);
    }
  twobyte := rdf_box_type (shortobj);
  -- dbg_obj_princ ('DB.DBA.RDF_DATATYPE_OF_OBJ (', shortobj, ') found twobyte ', twobyte);
  if (257 = twobyte)
    return case (rdf_box_lang (shortobj)) when 257 then __uname (dflt) else null end;
  whenever not found goto badtype;
  select __uname (RDT_QNAME) into res from DB.DBA.RDF_DATATYPE where RDT_TWOBYTE = twobyte;
  return res;

badtype:
  signal ('RDFXX', sprintf ('Unknown datatype in DB.DBA.RQ_DATATYPE_OF_OBJ, bad type id %d, string value "%s"',
    twobyte, cast (rdf_box_data (shortobj) as varchar) ) );
}
;

create function DB.DBA.RDF_LANGUAGE_OF_OBJ (in shortobj any array, in dflt varchar := '') returns any
{
  vectored;
  declare twobyte integer;
  declare res varchar;
  if (__tag of rdf_box <> __tag (shortobj))
    {
      if (isiri_id (shortobj))
        return null;
      if (isstring (shortobj) and bit_and (__box_flags (shortobj), 1))
        return null;
      -- dbg_obj_princ ('DB.DBA.RDF_LANGUAGE_OF_OBJ (', shortobj, ') got a non-rdfbox');
      return dflt;
    }
  twobyte := rdf_box_lang (shortobj);
  -- dbg_obj_princ ('DB.DBA.RDF_LANGUAGE_OF_OBJ (', shortobj, ') found twobyte ', twobyte);
  if (257 = twobyte)
    return dflt;
  return coalesce ((select lower (RL_ID)  from DB.DBA.RDF_LANGUAGE where RL_TWOBYTE = twobyte), 
     signal ('RDFXX', sprintf ('Unknown language in DB.DBA.RDF_LANGUAGE_OF_OBJ, bad string "%s"', cast (shortobj as varchar))));
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

create function DB.DBA.RDF_STRSQLVAL_OF_OBJ (in shortobj any) -- DEPRECATED
{
  return __rdf_strsqlval (shortobj, 0);
}
;

create function DB.DBA.RDF_OBJ_OF_LONG (in longobj any) returns any
{
  declare t int;
  t := __tag (longobj);
  if (__tag of rdf_box <> t)
    {
      if (not (t in (__tag of varchar, 126, 217, __tag of nvarchar, 133, 226)))
        return longobj;
      if (t = 133)
	{
	  longobj := cast (longobj as nvarchar);
	  t := __tag (longobj);
	}
      if (__tag of nvarchar = t or t = 226)
        longobj := charset_recode (longobj, '_WIDE_', 'UTF-8');
      else if (t in (126, 217))
        longobj := cast (longobj as varchar);
      else if (bit_and (1, __box_flags (longobj)))
        return iri_to_id (longobj);
      return DB.DBA.RDF_OBJ_ADD (257, longobj, 257);
    }
  if (0 = rdf_box_needs_digest (longobj))
    return longobj;
  return DB.DBA.RDF_OBJ_ADD (257, longobj, 257);
}
;

create function DB.DBA.RDF_OBJ_OF_SQLVAL (in v any) returns any array
{
  declare t int;
  t := __tag (v);
  if (not (t in (__tag of varchar, 126, 217, __tag of nvarchar)))
    {
      if (__tag of rdf_box = __tag(v) and 0 = rdf_box_ro_id (v))
        return DB.DBA.RDF_OBJ_ADD (257, v, 257);
      return v;
    }
  if (__tag of nvarchar = t)
    v := charset_recode (v, '_WIDE_', 'UTF-8');
  else if (t in (126, 217))
    v := cast (v as varchar);
  else if (bit_and (1, __box_flags (v)))
    return iri_to_id (v);
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
  if (not (t in (126, __tag of varchar, 217, __tag of nvarchar, __tag of XML)))
    return v;
  if (__tag of nvarchar = t)
    v := charset_recode (v, '_WIDE_', 'UTF-8');
  else if (217 = t or 126 = t)
    v := cast (v as varchar);
  else if (bit_and (1, __box_flags (v)))
    return iri_to_id (v);
  res := rdf_box (v, 257, 257, 0, 1);
  return res;
}
;


create function DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL (in v any, in dt_iid IRI_ID, in lang varchar) returns any
{
  declare t, dt_twobyte, lang_twobyte int;
  declare res any;
  t := __tag (v);
--  if (not (t in (__tag of varchar, 217, __tag of nvarchar, __tag of XML)))
--    signal ('RDFXX', 'DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL() accepts only string representations of typed values');
  if (__tag of nvarchar = t)
    v := charset_recode (v, '_WIDE_', 'UTF-8');
  else if (217 = t)
    v := cast (v as varchar);
  else if (__tag of varchar = t and 1 = __box_flags (v) and dt_iid is null and lang is null)
    return iri_to_id (v);
  if (__tag of varchar <> __tag (v))
    {
      declare xsdt IRI_ID;
      if (lang is not null)
        {
          if (is_rdf_box (v) and rdf_box_type (v) = 257)
            {
              v := rdf_box_data (v, 1);
              if (__tag of varchar <> __tag (v))
                signal ('RDFXX', 'Language is set and the argument is invalid RDF box in DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL()');
            }
          else
            signal ('RDFXX', 'Language is specified for typed literal in DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL()');
          if (dt_iid is not null)
            signal ('RDFXX', 'Both language and type are specified in call of DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL()');
        }
      else
        {
          if (is_rdf_box (v))
            v := rdf_box_data (v, 1);
          xsdt := cast (__xsd_type (v, UNAME'http://www.w3.org/2001/XMLSchema#string', NULL) as varchar);
          if (dt_iid = case (isiri_id (dt_iid)) when 1 then iri_to_id (xsdt) else xsdt end)
            return v;
          -- dbg_obj_princ ('no opt -- ', dt_iid, case (isiri_id (dt_iid)) when 1 then iri_to_id (xsdt) else xsdt end);
        }
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
          if (__tag of XML = __tag (parsed))
	    parsed := rdf_box (parsed, 257, 257, 0, 1);
          if (__tag of rdf_box = __tag (parsed))
            rdf_box_set_type (parsed,
              DB.DBA.RDF_TWOBYTE_OF_DATATYPE (iri_to_id (o_type)));
          return parsed;
        }
      return DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL (
        o_val,
        iri_to_id (o_type),
        null );
    }
  if (__tag (o_lang) in (__tag of varchar, 217))
    return DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL (o_val, NULL, o_lang);
  return DB.DBA.RDF_MAKE_LONG_OF_SQLVAL (o_val);
}
;

create function DB.DBA.RDF_QNAME_OF_LONG_SAFE (in longobj any) returns varchar -- DEPRECATED
{
  return id_to_iri_nosignal (longobj);
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
  signal ('RDFXX', sprintf ('Unknown datatype in DB.DBA.RDF_BOOL_OF_LONG (code %d)', rdf_box_type (longobj)));
}
;

create function DB.DBA.RDF_DATATYPE_OF_LONG (in longobj any, in dflt any := UNAME'http://www.w3.org/2001/XMLSchema#string') returns any
{
  if (__tag of rdf_box = __tag (longobj))
    {
      declare twobyte integer;
      declare res IRI_ID;
      twobyte := rdf_box_type (longobj);
      if (257 = twobyte)
        return case (rdf_box_lang (longobj)) when 257 then __uname (dflt) else null end;
      whenever not found goto badtype;
      select __uname (RDT_QNAME) into res from DB.DBA.RDF_DATATYPE where RDT_TWOBYTE = twobyte;
      return res;

badtype:
  signal ('RDFXX', sprintf ('Unknown datatype in DB.DBA.RDF_DATATYPE_OF_LONG, bad id %d', twobyte));
    }
  if (isiri_id (longobj))
    return NULL;
  return __xsd_type (longobj, dflt);
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

create function DB.DBA.RDF_STRSQLVAL_OF_LONG (in longobj any) -- DEPRECATED
{
  return __rdf_strsqlval (longobj, 0);
}
;

create function DB.DBA.RDF_WIDESTRSQLVAL_OF_LONG (in longobj any)
{
  declare t, len integer;
  if (__tag of rdf_box = __tag (longobj))
    {
      if (rdf_box_is_complete (longobj))
        {
          if (__tag of varchar = rdf_box_data_tag (longobj))
            return charset_recode (rdf_box_data (longobj), 'UTF-8', '_WIDE_');
          if (__tag of datetime = rdf_box_data_tag (longobj))
            {
              declare vc varchar;
              vc := cast (rdf_box_data (longobj) as varchar); --!!!TBD: replace with proper serialization
              return cast (replace (vc, ' ', 'T') as nvarchar);
            }
          if (__tag of XML = rdf_box_data_tag (longobj))
            {
              return charset_recode (serialize_to_UTF8_xml (rdf_box_data (longobj)), 'UTF-8', '_WIDE_');
            }
          return cast (rdf_box_data (longobj) as nvarchar);
        }
      declare id integer;
      declare v2 any;
      id := rdf_box_ro_id (longobj);
      if (__tag of XML = rdf_box_data_tag (longobj))
        {
          v2 := (select xml_tree_doc (__xml_deserialize_packed (RO_LONG)) from DB.DBA.RDF_OBJ where RO_ID = id);
          rdf_box_set_data (longobj, v2, 1);
          return charset_recode (serialize_to_UTF8_xml (v2), 'UTF-8', '_WIDE_');
        }
      else
        v2 := (select case (isnull (RO_LONG)) when 0 then blob_to_string (RO_LONG) else RO_VAL end from DB.DBA.RDF_OBJ where RO_ID = id);
      if (v2 is null)
        signal ('RDFXX', sprintf ('Integrity violation in DB.DBA.RDF_WIDESTRSQLVAL_OF_LONG, bad id %d', id));
      rdf_box_set_data (longobj, v2, 1);
      return charset_recode (v2, 'UTF-8', '_WIDE_');
    }
  if (isiri_id (longobj))
    {
      declare res varchar;
      res := id_to_iri (longobj);
--      res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = longobj));
      if (res is null)
        signal ('RDFXX', 'Wrong iid in DB.DBA.RDF_WIDESTRSQLVAL_OF_LONG()');
      return charset_recode (res, 'UTF-8', '_WIDE_');
    }
  if (__tag of datetime = __tag (longobj))
    {
      declare vc varchar;
      vc := cast (longobj as varchar); --!!!TBD: replace with proper serialization
      return cast (replace (vc, ' ', 'T') as nvarchar);
    }
  if (__tag of nvarchar = __tag (longobj))
    return longobj;
  if (__tag of XML = __tag (longobj))
    {
      return charset_recode (serialize_to_UTF8_xml (longobj), 'UTF-8', '_WIDE_');
    }
  return cast (longobj as nvarchar);
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
      declare res IRI_ID;
      twobyte := rdf_box_type (v);
      if (257 = twobyte)
        return case (rdf_box_lang (v)) when 257 then __uname (strg_datatype) else null end;
      whenever not found goto badtype;
      select __uname (RDT_QNAME) into res from DB.DBA.RDF_DATATYPE where RDT_TWOBYTE = twobyte;
      return res;

badtype:
  signal ('RDFXX', sprintf ('Unknown datatype in DB.DBA.RDF_DATATYPE_OF_SQLVAL, bad id %d', twobyte));
    }
  return __uname (__xsd_type (v, strg_datatype, default_res));
}
;

-- /* keep the input parameter as varchar in order to make jdbc happy and receive 182 instead of 242 on which it breaks the utf8 support */
create function DB.DBA.RDF_LONG_OF_SQLVAL (in v varchar) returns any
{
  declare t int;
  t := __tag (v);
  if (not (t in (126, __tag of varchar, 217, __tag of nvarchar)))
    return v;
  if (__tag of nvarchar = t)
    v := charset_recode (v, '_WIDE_', 'UTF-8');
  else if (t in (126, 217))
    v := cast (v as varchar);
  else if ((t = __tag of varchar) and (1 = __box_flags (v)))
    return iri_to_id (v);
--  if ((t = __tag of varchar) and (v like 'http://%'))
--    {
--     -- dbg_obj_princ ('DB.DBA.RDF_LONG_OF_SQLVAL (', v, '): no box flag, suspicious value');
--      ;
--    }
  return rdf_box (v, 257, 257, 0, 1);
}
;

-----
-- Conversions for SQL values

--!AWK PUBLIC
create function DB.DBA.RDF_STRSQLVAL_OF_SQLVAL (in sqlval any) -- DEPRECATED
{
  declare t, len integer;
  if (__tag of rdf_box = __tag (sqlval))
    sqlval := __ro2sq (sqlval, 1);
  if (isiri_id (sqlval))
    {
      declare res varchar;
      res := id_to_iri (sqlval);
--      res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = sqlval));
      if (res is null)
        signal ('RDFXX', 'Wrong iid in DB.DBA.RDF_STRSQLVAL_OF_SQLVAL()');
      __box_flags_set (res, 2);
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
  if (__tag of rdf_box = __tag (v))
    {
      declare twobyte integer;
      declare res varchar;
      twobyte := rdf_box_lang (v);
      whenever not found goto badtype;
      select RL_ID into res from DB.DBA.RDF_LANGUAGE where RL_TWOBYTE = twobyte;
      return res;

badtype:
  signal ('RDFXX', sprintf ('Unknown language in DB.DBA.RDF_LANGUAGE_OF_SQLVAL, bad id %d', twobyte));
    }
  return case (isiri_id (v)) when 0 then dflt else null end;
--  t := __tag (v);
--  if (not (t in (__tag of varchar, 217, __tag of nvarchar)))
--    return NULL;
--  return NULL; -- !!!TBD: uncomment this and make a support for UTF8 'language name' codepoint plane
}
;

--!AWK PUBLIC
create function DB.DBA.RDF_IS_BLANK_REF (in v any) returns any
{
  if ((__tag (v) = 217) or ((__tag (v) = __tag of varchar) and bit_and (1, __box_flags (v))))
    {
      if ("LEFT" (v, 9) <> 'nodeID://')
        return 0;
      return 1;
    }
  if (__tag (v) = 243)
    {
      if (v < min_bnode_iri_id ())
        return 0;
      return 1;
    }
  return 0;
}
;

--!AWK PUBLIC
create function DB.DBA.RDF_IS_URI_REF (in v any) returns any
{
  if ((__tag (v) = 217) or ((__tag (v) = __tag of varchar) and bit_and (1, __box_flags (v))))
    {
      if ("LEFT" (v, 9) <> 'nodeID://')
        return 1;
      return 0;
    }
  if (__tag (v) = 243)
    {
      if (v < min_bnode_iri_id ())
        return 1;
      return 0;
    }
  return 0;
}
;

--!AWK PUBLIC
create function DB.DBA.RDF_IS_REF (in v any) returns any
{
  if (__tag (v) in (217, 243))
    return 1;
  if ((__tag of varchar = __tag (v)) and bit_and (1, __box_flags (v)))
    return 1;
  return 0;
}
;

--!AWK PUBLIC
create function DB.DBA.RDF_IS_LITERAL (in v any) returns any
{
  if (__tag (v) in (217, 243))
    return 0;
  if ((__tag of varchar = __tag (v)) and bit_and (1, __box_flags (v)))
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
-- SPARQL 1.1 built-in functions, implemented as stored procedures

create function DB.DBA.rdf_strdt_impl (in str varchar, in dt_iri any)
{
  declare dt_iid IRI_ID;
  declare parsed any;
  dt_iid := __i2id (dt_iri);
  if (dt_iid is null)
    signal ('22007', 'Function rdf_strdt_impl needs a valid datatype IRI as its second argument');
  if (__tag of IRI_ID = __tag (dt_iri))
    dt_iri := __id2i (dt_iri);
  parsed := __xqf_str_parse_to_rdf_box (str, dt_iri, isstring (str));
  if (parsed is not null)
    {
      if (__tag of rdf_box = __tag (parsed))
        rdf_box_set_type (parsed,
          DB.DBA.RDF_TWOBYTE_OF_DATATYPE (dt_iid));
      return parsed;
    }
  return DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL (str, dt_iid, null);
}
;

create function DB.DBA.rdf_strlang_impl (in str varchar, in lang any)
{
  declare t integer;
  lang := cast (lang as varchar);
  if ((lang is null) or (regexp_match ('^(([a-z][a-z](-[A-Z][A-Z])?)|(x-[A-Za-z0-9]+))\044', lang) is null))
    signal ('22007', 'Function rdf_strlang_impl needs a valid language ID as its second argument');
  if (is_rdf_box (str))
    str := rdf_box_data (str, 1);
  t := __tag (str);
  if (__tag of nvarchar = t)
    str := charset_recode (str, '_WIDE_', 'UTF-8');
  else if (__tag of varchar <> t)
    {
      if (str is null)
        signal ('22007', 'Function rdf_strlang_impl needs a bound value as its first argument, not a NULL');
      str := cast (str as varchar);
    }
  return rdf_box (str, 257, DB.DBA.RDF_TWOBYTE_OF_LANGUAGE (lang), 0, 1);
}
;

--!AWK PUBLIC
create function DB.DBA.rdf_replace_impl (in src varchar, in needle varchar, in rpl varchar, in opts varchar := '')
{
  declare src_tag, needle_tag, rpl_tag integer;
  declare res varchar;
  src_tag := __tag (src);
  needle_tag := __tag (needle);
  rpl_tag := __tag (rpl);
  if (__tag of rdf_box = src_tag)
    {
      src := rdf_box_data (src);
      src_tag := __tag (src);
    }
  if (__tag of rdf_box = needle_tag)
    {
      needle := rdf_box_data (needle);
      needle_tag := __tag (needle);
    }
  if (__tag of rdf_box = rpl_tag)
    {
      rpl := rdf_box_data (rpl);
      rpl_tag := __tag (rpl);
    }
  if (__tag of nvarchar = src_tag)
    src := charset_recode (src, '_WIDE_', 'UTF-8');
  else if (__tag of varchar <> src_tag)
    src := cast (src as varchar);
  if (__tag of nvarchar = needle_tag)
    needle := charset_recode (needle, '_WIDE_', 'UTF-8');
  else if (__tag of varchar <> needle_tag)
    needle := cast (needle as varchar);
  if (__tag of nvarchar = rpl_tag)
    rpl := charset_recode (rpl, '_WIDE_', 'UTF-8');
  else if (__tag of varchar <> rpl_tag)
    rpl := cast (rpl as varchar);
  if (__tag of varchar <> __tag (opts))
    opts := cast (opts as varchar);
  if (opts is null)
    opts := '';
  if (src is null or needle is null or rpl is null)
    return null;
  if ('' = needle)
    return src;
  if (regexp_match ('^[^()|+?.:^\044\\\\\\[\\]-]+\044', needle, 0, 'u') is not null and strchr (rpl, '\044') is null and strchr (rpl, 92) is null)
    {
      if ('' = opts)
        {
          res := replace (src, needle, rpl);
          __box_flags_set (res, 2);
          return res;
        }
      if (opts in ('i', 'I'))
        {
          declare src_lc varchar;
          declare hit, needle_len integer;
          declare ses any;
          src_lc := lcase (src);
          needle := lcase (needle);
          hit := strstr (src_lc, needle);
          if (hit is null)
            {
              res := src;
              __box_flags_set (res, 2);
              return res;
            }
          ses := string_output();
          needle_len := length (needle);
          while (hit is not null)
            {
              http (subseq (src, 0, hit), ses);
              http (rpl, ses);
              src := subseq (src, hit + needle_len);
              src_lc := subseq (src_lc, hit + needle_len);
              hit := strstr (src_lc, needle);
            }
          http (src, ses);
          res := string_output_string (ses);
          __box_flags_set (res, 2);
          return res;
        }
    }
  if (strchr (opts, 'u') is null and strchr (opts, 'U') is null)
    opts := opts || 'u';
  res := regexp_xfn_replace (src, needle, rpl, 0, null, opts);
  __box_flags_set (res, 2);
  return res;
}
;

--!AWK PUBLIC
create function DB.DBA.regexp_xfn_replace (in src varchar, in needle varchar, in tmpl varchar, in search_begin_pos integer, in hit_max_count integer, in opts varchar)
{
  declare hit_list any;
  if (0 = length (src))
    return '';
  if (regexp_parse (needle, '', 0, opts) is not null)
    signal ('22023', 'The regex-based XPATH/XQuery/SPARQL replace() function can not search for a pattern that can be found even in an empty string');
  hit_list := regexp_parse_list (needle, src, search_begin_pos, opts, coalesce (hit_max_count, 2097152));
  return regexp_replace_hits_with_template (src, tmpl, hit_list, 1);
}
;

create function DB.DBA.rdf_uuid_impl ()
{
  return iri_to_id ('urn:uuid:' || uuid());
}
;

--!AWK PUBLIC
create function DB.DBA.rdf_timezone_impl (in dt datetime)
{
  declare minutes integer;
  declare sign, str varchar;
  minutes := timezone (dt);
  if (minutes is null)
    signal ('22007', 'Function rdf_timezone_impl needs a datetime with some timezone set as its argument');
  if (minutes < 0)
    {
      sign := '-';
      minutes := -minutes;
    }
  else
    sign := '';
  if (mod (minutes, 60))
    str := sprintf ('%sPT%dH%dM', sign, minutes / 60, mod (minutes, 60));
  else if (minutes = 0)
    str := 'PT0S';
  else
    str := sprintf ('%sPT%dH', sign, minutes / 60);
  return DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL (str, __i2id (UNAME'http://www.w3.org/2001/XMLSchema#dayTimeDuration'), null);
}
;

--!AWK PUBLIC
create function DB.DBA.rdf_tz_impl (in dt datetime)
{
  declare minutes integer;
  declare sign varchar;
  minutes := timezone (dt);
  if (minutes is null)
    return '';
  if (minutes = 0)
    return 'Z';
  if (minutes < 0)
    {
      sign := '-';
      minutes := -minutes;
    }
  else
    sign := '';
  return sprintf ('%s%02d:%02d', sign, minutes / 60, mod (minutes, 60));
}
;


-----
-- Data loading

create procedure DB.DBA.RDF_QUAD_URI (in g_uri varchar, in s_uri varchar, in p_uri varchar, in o_uri varchar)
{
  declare g_iid IRI_ID;
  g_iid := iri_to_id (g_uri);
  if (__rdf_graph_is_in_enabled_repl (g_iid))
    __rdf_repl_quad (84, iri_canonicalize (g_uri), iri_canonicalize (s_uri), iri_canonicalize (p_uri), iri_canonicalize (o_uri));
  insert soft DB.DBA.RDF_QUAD (G,S,P,O)
  values (
    g_iid,
    iri_to_id (s_uri),
    iri_to_id (p_uri),
    iri_to_id (o_uri) );
}
;

create procedure DB.DBA.RDF_QUAD_URI_L (in g_uri varchar, in s_uri varchar, in p_uri varchar, in o_lit any, in ro_id_dict any := null)
{
  declare g_iid, s_iid, p_iid IRI_ID;
  declare o_obj any;
  g_iid := iri_to_id (g_uri);
  s_iid := iri_to_id (s_uri);
  p_iid := iri_to_id (p_uri);
  o_obj := DB.DBA.RDF_MAKE_OBJ_OF_SQLVAL_FT (o_lit, g_iid, p_iid, ro_id_dict);
  if (__rdf_graph_is_in_enabled_repl (g_iid))
    {
      declare triples any;
      triples := vector (vector (s_iid, p_iid, o_obj));
      DB.DBA.RDF_REPL_INSERT_TRIPLES (id_to_iri (g_iid), triples);
    }
  insert soft DB.DBA.RDF_QUAD (G,S,P,O) values (g_iid, s_iid, p_iid, o_obj);
}
;

create procedure DB.DBA.RDF_QUAD_URI_L_TYPED (in g_uri varchar, in s_uri varchar, in p_uri varchar, in o_lit any, in dt any, in lang varchar, in ro_id_dict any := null)
{
  declare g_iid, s_iid, p_iid IRI_ID;
  declare o_obj any;
  g_iid := iri_to_id (g_uri);
  s_iid := iri_to_id (s_uri);
  p_iid := iri_to_id (p_uri);
  if (dt is null and lang is null)
    o_obj := DB.DBA.RDF_MAKE_OBJ_OF_SQLVAL_FT (o_lit, g_iid, p_iid, ro_id_dict);
  else
    o_obj := DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL_FT (o_lit, iri_to_id (dt), lang, g_iid, p_iid, ro_id_dict);
  if (__rdf_graph_is_in_enabled_repl (g_iid))
    {
      declare triples any;
      triples := vector (vector (s_iid, p_iid, o_obj));
      DB.DBA.RDF_REPL_INSERT_TRIPLES (id_to_iri (g_iid), triples);
    }
  insert soft DB.DBA.RDF_QUAD (G,S,P,O) values (g_iid, s_iid, p_iid, o_obj);
}
;

create procedure DB.DBA.RDF_QUAD_L_RDB2RDF (in g_iid varchar, in s_iid varchar, in p_iid varchar, inout o_val any, inout old_g_iid any, inout ro_id_dict any)
{
  declare t int;
  if (__rdf_graph_is_in_enabled_repl (g_iid))
    {
      declare triples any;
      triples := vector (vector (s_iid, p_iid, o_val));
      DB.DBA.RDF_REPL_INSERT_TRIPLES (id_to_iri (g_iid), triples);
    }
  t := __tag (o_val);
  if (__tag of rdf_box <> t)
    {
      if (not (t in (__tag of varchar, 126, 133, 217, __tag of nvarchar, 226)))
        {
          goto o_val_done;
        }
      if (t = 133)
	{
	  o_val := cast (o_val as nvarchar);
	  t := __tag (o_val);
	}
      if (__tag of nvarchar = t or t = 226)
        o_val := charset_recode (o_val, '_WIDE_', 'UTF-8');
      else if (t in (126, 217))
        o_val := cast (o_val as varchar);
      else if (bit_and (1, __box_flags (o_val)))
        {
          o_val := iri_to_id (o_val);
          goto o_val_done;
        }
    }
  if (__rdf_obj_ft_rule_check (g_iid, p_iid))
    {
      if (old_g_iid <> g_iid)
        {
          if (dict_size (ro_id_dict))
            DB.DBA.RDF_OBJ_ADD_KEYWORD_FOR_GRAPH (old_g_iid, ro_id_dict);
          old_g_iid := g_iid;
        }
      if (ro_id_dict is null)
        ro_id_dict := dict_new ();
      o_val := DB.DBA.RDF_OBJ_ADD (257, o_val, 257, ro_id_dict);
    }
  else
    o_val := DB.DBA.RDF_OBJ_ADD (257, o_val, 257);

o_val_done:
  if (o_val is null or s_iid is null) 
    {
      -- cannot have null values
      return;
    }
  insert soft DB.DBA.RDF_QUAD (G,S,P,O) values (g_iid, s_iid, p_iid, o_val);
}
;

create procedure DB.DBA.TTLP_EV_NEW_GRAPH (inout g varchar, inout g_iid IRI_ID, inout app_env any) {
  -- dbg_obj_princ ('DB.DBA.TTLP_EV_NEW_GRAPH(', g, g_iid, app_env, ')');
  if (__rdf_obj_ft_rule_count_in_graph (g_iid))
    app_env[1] := dict_new (app_env[2]);
  else
    app_env[1] := null;
  if (__rdf_graph_is_in_enabled_repl (g_iid))
    app_env[3] := g;
  else
    app_env[3] := null;
}
;

create procedure DB.DBA.TTLP_EV_NEW_BLANK (inout g_iid IRI_ID, inout app_env any, inout res IRI_ID) {
  res := iri_id_from_num (sequence_next ('RDF_URL_IID_BLANK'));
  -- dbg_obj_princ ('DB.DBA.TTLP_EV_NEW_BLANK (', g_iid, app_env, ') returns ', res);
}
;

create procedure DB.DBA.TTLP_EV_GET_IID (inout uri varchar, inout g_iid IRI_ID, inout app_env any, inout res IRI_ID) {
  -- dbg_obj_princ ('DB.DBA.TTLP_EV_GET_IID (', uri, g_iid, app_env, ')');
  res := iri_to_id (uri);
  -- dbg_obj_princ ('DB.DBA.TTLP_EV_GET_IID (', uri, g_iid, app_env, ') returns ', res);
}
;

create procedure DB.DBA.TTLP_EV_TRIPLE (
  inout g_iid IRI_ID, inout s_uri varchar, inout p_uri varchar,
  inout o_uri varchar,
  inout app_env any )
{
  -- dbg_obj_princ ('DB.DBA.TTLP_EV_TRIPLE (', g_iid, s_uri, p_uri, o_uri, ');');
  if (app_env[3] is not null)
    __rdf_repl_quad (84, app_env[3], iri_canonicalize (s_uri), iri_canonicalize (p_uri), iri_canonicalize (o_uri));
  insert soft DB.DBA.RDF_QUAD (G,S,P,O) values (g_iid, iri_to_id (s_uri), iri_to_id (p_uri), iri_to_id (o_uri));
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
  if (app_env[3] is not null)
    {
      if (isstring (o_type))
        __rdf_repl_quad (81, app_env[3], iri_canonicalize (s_uri), iri_canonicalize (p_uri), o_val, iri_canonicalize (o_type), NULL);
      else if (isstring (o_lang))
        __rdf_repl_quad (82, app_env[3], iri_canonicalize (s_uri), iri_canonicalize (p_uri), o_val, null, o_lang);
      else
        __rdf_repl_quad (80, app_env[3], iri_canonicalize (s_uri), iri_canonicalize (p_uri), o_val);
    }
  log_mode := app_env[0];
  ro_id_dict := app_env[1];
  p_iid := iri_to_id (p_uri);
  if (isstring (o_type))
    {
      declare parsed any;
      parsed := __xqf_str_parse_to_rdf_box (o_val, o_type, isstring (o_val));
      if (parsed is not null)
        {
          if (__tag of XML = __tag (parsed))
            {
              insert soft DB.DBA.RDF_QUAD (G,S,P,O)
              values (g_iid, iri_to_id (s_uri), p_iid,
                DB.DBA.RDF_MAKE_OBJ_OF_SQLVAL_FT (
                  parsed, g_iid, p_iid, ro_id_dict ) );
              return;
            }
          if (__tag of rdf_box = __tag (parsed))
	    {
	      if (256 = rdf_box_type (parsed))
		db..rdf_geo_add (parsed);
	      else
		rdf_box_set_type (parsed,
				  DB.DBA.RDF_TWOBYTE_OF_DATATYPE (iri_to_id (o_type)));
	      parsed := DB.DBA.RDF_OBJ_ADD (257, parsed, 257, ro_id_dict);
	    }
          insert soft DB.DBA.RDF_QUAD (G,S,P,O)
          values (g_iid, iri_to_id (s_uri), p_iid, parsed);
          return;
        }
      insert soft DB.DBA.RDF_QUAD (G,S,P,O)
      values (g_iid, iri_to_id (s_uri), p_iid,
        DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL_FT (
          o_val,
          iri_to_id (o_type),
          case (isstring (o_lang)) when 0 then null else o_lang end,
          g_iid, p_iid, ro_id_dict ) );
      return;
    }
  if (isstring (o_lang))
    {
      insert soft DB.DBA.RDF_QUAD (G,S,P,O)
      values (g_iid, iri_to_id (s_uri), p_iid,
        DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL_FT (o_val, NULL, o_lang, g_iid, p_iid, ro_id_dict) );
      return;
    }
  if (isstring (o_val) or (__tag of XML = __tag (o_val)))
    {
      insert soft DB.DBA.RDF_QUAD (G,S,P,O)
      values (g_iid, iri_to_id (s_uri), p_iid,
        DB.DBA.RDF_MAKE_OBJ_OF_SQLVAL_FT (o_val, g_iid, p_iid, ro_id_dict) );
    }
  else
    {
      insert soft DB.DBA.RDF_QUAD (G,S,P,O)
      values (g_iid, iri_to_id (s_uri), p_iid,
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

create procedure DB.DBA.TTLP_EV_REPORT_DEFAULT (
  inout msg_no integer, inout msg_type varchar,
  inout src varchar, inout base varchar, inout graph varchar,
  inout line_no integer, inout triple_no integer,
  inout sstate varchar, inout smore varchar, inout descr varchar,
  inout env any )
{
  -- dbg_obj_princ ('DB.DBA.TTLP_EV_REPORT_DEFAULT (', msg_no, msg_type, src, base, graph, line_no, triple_no, sstate, smore, descr, env, ')');
  ;
}
;

create procedure DB.DBA.TTLP_EV_TRIPLE_XLAT (
  inout g_iid IRI_ID, inout s_uri varchar, inout p_uri varchar,
  inout o_uri varchar,
  inout app_env any )
{
  declare xlat_cbk, s_xlat, o_xlat varchar;
  declare xlat_env any;
  -- dbg_obj_princ ('DB.DBA.TTLP_EV_TRIPLE_XLAT (', g_iid, s_uri, p_uri, o_uri, ');');
  xlat_cbk := app_env[4];
  xlat_env := app_env[5];
  s_xlat := call(xlat_cbk)(s_uri, xlat_env);
  o_xlat := call(xlat_cbk)(o_uri, xlat_env);
  DB.DBA.TTLP_EV_TRIPLE (g_iid, s_xlat, p_uri, o_xlat, app_env);
}
;

create procedure DB.DBA.TTLP_EV_TRIPLE_L_XLAT (
  inout g_iid IRI_ID, inout s_uri varchar, inout p_uri varchar,
  inout o_val any, inout o_type varchar, inout o_lang varchar,
  inout app_env any )
{
  declare xlat_cbk, s_xlat varchar;
  declare xlat_env any;
  -- dbg_obj_princ ('DB.DBA.TTLP_EV_TRIPLE_L_XLAT (', g_iid, s_uri, p_uri, o_val, o_type, o_lang, app_env, ');');
  xlat_cbk := app_env[4];
  xlat_env := app_env[5];
  s_xlat := call(xlat_cbk)(s_uri, xlat_env);
  DB.DBA.TTLP_EV_TRIPLE_L (g_iid, s_xlat, p_uri, o_val, o_type, o_lang, app_env);
}
;

--!AWK PUBLIC
create procedure DB.DBA.TTLP_XLAT_CONCAT (
  inout iri varchar, inout env any )
{
  if (__tag (iri) <> __tag of varchar)
    return iri;
  if (iri like 'http://%')
    return concat (env, subseq (iri, 7));
  return iri;
}
;

create procedure DB.DBA.TTLP (in strg varchar, in base varchar, in graph varchar := null, in flags integer := 0,
	in log_enable int := null, in transactional int := 0)
{
  declare app_env any;
  declare old_log_mode int;
  declare ret any;
  if (graph = '')
    signal ('22023', 'Empty string is not a valid graph IRI in DB.DBA.TTLP()');
  else if (graph is null)
    {
      graph := base;
      if ((graph is null) or (graph = ''))
        signal ('22023', 'DB.DBA.TTLP() requires a valid IRI as a base argument if graph is not specified');
    }
  old_log_mode := null;
  if (transactional = 0)
    {
      if (log_enable = 0 or log_enable = 1)
        log_enable := log_enable + 2;
    }
  if (log_enable is not null)
    {
      old_log_mode := log_enable (log_enable, 1);
    }
  if (1 <> sys_stat ('cl_run_local_only'))
    {
      DB.DBA.TTLP_CL (strg, 0, base, graph, flags);
      return;
    }
  if (1 = sys_stat ('enable_vec') and not is_atomic ())
    {
      DB.DBA.TTLP_V (strg, base, graph, flags, 3, log_enable => log_enable, transactional => transactional);
      return;
    }
  if (126 = __tag (strg))
    strg := cast (strg as varchar);
  app_env := vector (flags, null, __max (length (strg) / 100, 100000), null);
  ret := rdf_load_turtle (strg, base, graph, flags,
    vector (
      'DB.DBA.TTLP_EV_NEW_GRAPH',
      'DB.DBA.TTLP_EV_NEW_BLANK',
      'DB.DBA.TTLP_EV_GET_IID',
      'DB.DBA.TTLP_EV_TRIPLE',
      'DB.DBA.TTLP_EV_TRIPLE_L',
      'DB.DBA.TTLP_EV_COMMIT',
      'DB.DBA.TTLP_EV_REPORT_DEFAULT' ),
    app_env);
  if (__rdf_graph_is_in_enabled_repl (iri_to_id (graph)))
    repl_text ('__rdf_repl', '__rdf_repl_flush_queue ()');
  return ret;
}
;

create procedure DB.DBA.TTLP_WITH_IRI_TRANSLATION (in strg varchar, in base varchar, in graph varchar, in flags integer,
	in log_enable integer, in transactional integer,
        in iri_xlate_cbk varchar, in iri_xlate_env any )
{
  declare app_env any;
  declare old_log_mode int;
  if (graph = '')
    signal ('22023', 'Empty string is not a valid graph IRI in DB.DBA.TTLP()');
  else if (graph is null)
    {
      graph := base;
      if ((graph is null) or (graph = ''))
        signal ('22023', 'DB.DBA.TTLP() requires a valid IRI as a base argument if graph is not specified');
    }
  old_log_mode := null;
  if (transactional = 0)
    {
      if (log_enable = 0 or log_enable = 1)
        log_enable := log_enable + 2;
    }
  if (log_enable is not null)
    {
      old_log_mode := log_enable (log_enable, 1);
    }
  if (1 <> sys_stat ('cl_run_local_only'))
    {
      DB.DBA.TTLP_CL (strg, 0, base, graph, flags);
      return;
    }
  if (126 = __tag (strg))
    strg := cast (strg as varchar);
  app_env := vector (flags, null, __max (length (strg) / 100, 100000), null, iri_xlate_cbk, iri_xlate_env);
  return rdf_load_turtle (strg, base, graph, flags,
    vector (
      'DB.DBA.TTLP_EV_NEW_GRAPH',
      'DB.DBA.TTLP_EV_NEW_BLANK',
      'DB.DBA.TTLP_EV_GET_IID',
      'DB.DBA.TTLP_EV_TRIPLE_XLAT',
      'DB.DBA.TTLP_EV_TRIPLE_L_XLAT',
      'DB.DBA.TTLP_EV_COMMIT',
      'DB.DBA.TTLP_EV_REPORT_DEFAULT' ),
    app_env);
}
;

create procedure DB.DBA.TTLP_VALIDATE (in strg varchar, in base varchar, in graph varchar := null, in flags integer := 0, in report_cbk varchar := '')
{
  declare app_env any;
  declare old_log_mode int;
  if (126 = __tag (strg))
    strg := cast (strg as varchar);
  return rdf_load_turtle (strg, base, graph, flags,
    vector ('', '', '', '', '', '', report_cbk),
    app_env);
}
;

create procedure DB.DBA.TTLP_VALIDATE_LOCAL_FILE (in strg varchar, in base varchar, in graph varchar := null, in flags integer := 0, in report_cbk varchar := '')
{
  declare app_env any;
  declare old_log_mode int;
  if (126 = __tag (strg))
    strg := cast (strg as varchar);
  return rdf_load_turtle_local_file (strg, base, graph, flags,
    vector ('', '', '', '', '', '', report_cbk),
    app_env);
}
;

create procedure DB.DBA.RDF_VALIDATE_RDFXML (in strg varchar, in base varchar, in graph varchar)
{
  declare app_env any;
  declare old_log_mode int;
  if (graph = '')
    signal ('22023', 'Empty string is not a valid graph IRI in DB.DBA.RDF_VALIDATE_RDFXML()');
  else if (graph is null)
    {
      graph := base;
      if ((graph is null) or (graph = ''))
        signal ('22023', 'DB.DBA.RDF_VALIDATE_RDFXML() requires a valid IRI as a base argument if graph is not specified');
    }
  rdf_load_rdfxml (strg, 0, graph, vector ( '', '', '', '', '', '', '' ), app_env, base );
  return graph;
}
;

create procedure DB.DBA.RDF_TTL2HASH_EXEC_NEW_GRAPH (inout g varchar, inout g_iid IRI_ID, inout app_env any) {
  -- dbg_obj_princ ('DB.DBA.RDF_TTL2HASH_EXEC_NEW_GRAPH(', g, g_iid, app_env, ')');
  ;
}
;

create procedure DB.DBA.RDF_TTL2HASH_EXEC_NEW_BLANK (inout g_iid IRI_ID, inout app_env any, inout res IRI_ID) {
  res := iri_id_from_num (sequence_next ('RDF_URL_IID_BLANK'));
  -- dbg_obj_princ ('DB.DBA.RDF_TTL2HASH_EXEC_NEW_BLANK (', g_iid, app_env, ') returns ', res);
}
;

create procedure DB.DBA.RDF_TTL2HASH_EXEC_GET_IID (inout uri varchar, inout g_iid IRI_ID, inout app_env any, inout res IRI_ID) {
  -- dbg_obj_princ ('DB.DBA.RDF_TTL2HASH_EXEC_GET_IID (', uri, g_iid, app_env, ')');
  res := iri_to_id (uri);
  -- dbg_obj_princ ('DB.DBA.RDF_TTL2HASH_EXEC_GET_IID (', uri, g_iid, app_env, ') returns ', res);
}
;

create procedure DB.DBA.RDF_TTL2HASH_EXEC_TRIPLE (
  inout g_iid IRI_ID, inout s_uri varchar, inout p_uri varchar,
  inout o_uri varchar,
  inout app_env any )
{
  dict_put (app_env,
    vector (iri_to_id (s_uri), iri_to_id (p_uri), iri_to_id (o_uri)),
    0 );
}
;

create procedure DB.DBA.RDF_TTL2HASH_EXEC_TRIPLE_L (
  inout g_iid IRI_ID, inout s_uri varchar, inout p_uri varchar,
  inout o_val any, inout o_type varchar, inout o_lang varchar,
  inout app_env any )
{
  dict_put (app_env,
    vector (
      iri_to_id (s_uri),
      iri_to_id (p_uri),
      DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL_STRINGS (o_val,
        case when (isstring (o_type) or isuname (o_type)) then o_type else null end,
        case when (isstring (o_lang) or isuname (o_lang)) then o_lang else null end) ),
    0 );
}
;

create procedure DB.DBA.RDF_TTL2HASH_EXEC_TRIPLE_XLAT (
  inout g_iid IRI_ID, inout s_uri varchar, inout p_uri varchar,
  inout o_uri varchar,
  inout app_env any )
{

  declare xlat_cbk, s_xlat, o_xlat varchar;
  declare xlat_env, dict any;
  -- dbg_obj_princ (current_proc_name (), ' (', g_iid, s_uri, p_uri, o_uri, ');');
  dict := app_env[0];
  xlat_cbk := app_env[1];
  xlat_env := app_env[2];
  if (__proc_params_num (xlat_cbk) = 2)
    {
      s_xlat := call(xlat_cbk)(s_uri, xlat_env);
      o_xlat := call(xlat_cbk)(o_uri, xlat_env);
    }
  else
    {
      s_xlat := call(xlat_cbk)(s_uri, p_uri, 's', xlat_env);
      o_xlat := call(xlat_cbk)(o_uri, p_uri, 'o', xlat_env);
    }

  dict_put (dict, vector (iri_to_id (s_xlat), iri_to_id (p_uri), iri_to_id (o_xlat)), 0);
}
;

create procedure DB.DBA.RDF_TTL2HASH_EXEC_TRIPLE_L_XLAT (
  inout g_iid IRI_ID, inout s_uri varchar, inout p_uri varchar,
  inout o_val any, inout o_type varchar, inout o_lang varchar,
  inout app_env any )
{
  declare xlat_cbk, s_xlat, o_xlat varchar;
  declare xlat_env, dict any;
  -- dbg_obj_princ (current_proc_name (),' (', g_iid, s_uri, p_uri, o_uri, ');');
  dict := app_env[0];
  xlat_cbk := app_env[1];
  xlat_env := app_env[2];
  if (__proc_params_num (xlat_cbk) = 2)
    s_xlat := call(xlat_cbk)(s_uri, xlat_env);
  else
    s_xlat := call(xlat_cbk)(s_uri, p_uri, 's', xlat_env);
  dict_put (dict,
    vector (
      iri_to_id (s_xlat),
      iri_to_id (p_uri),
      DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL_STRINGS (o_val,
        case when (isstring (o_type) or __tag (o_type) = 217) then o_type else null end,
        case when (isstring (o_lang) or __tag (o_lang) = 217) then o_lang else null end) ),
    0);
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
      '',
      'DB.DBA.TTLP_EV_REPORT_DEFAULT' ),
    res);
  return res;
}
;

create function DB.DBA.RDF_TTL_LOAD_DICT (in strg varchar, in base varchar, in graph varchar, in dict any, in flags integer := 0) returns any
{
  if (__tag (dict) <> 214)
    signal ('22023', 'RDFXX', 'The dict argument must be of type dictionary');
  if (126 = __tag (strg))
    strg := cast (strg as varchar);
  rdf_load_turtle (strg, base, graph, flags,
    vector (
      'DB.DBA.RDF_TTL2HASH_EXEC_NEW_GRAPH',
      'DB.DBA.RDF_TTL2HASH_EXEC_NEW_BLANK',
      'DB.DBA.RDF_TTL2HASH_EXEC_GET_IID',
      'DB.DBA.RDF_TTL2HASH_EXEC_TRIPLE',
      'DB.DBA.RDF_TTL2HASH_EXEC_TRIPLE_L',
      '',
      'DB.DBA.TTLP_EV_REPORT_DEFAULT' ),
    dict);
  return;
}
;

create procedure DB.DBA.RDF_TTL2SQLHASH_EXEC_GET_IID (inout uri varchar, inout g_iid IRI_ID, inout app_env any, inout res IRI_ID) {
  -- dbg_obj_princ ('DB.DBA.RDF_TTL2SQLHASH_EXEC_GET_IID (', uri, g_iid, app_env, ')');
  res := __bft (uri, 1);
  -- dbg_obj_princ ('DB.DBA.RDF_TTL2SQLHASH_EXEC_GET_IID (', uri, g_iid, app_env, ') returns ', res);
}
;

create procedure DB.DBA.RDF_TTL2SQLHASH_EXEC_TRIPLE (
  inout g_iid IRI_ID, inout s_uri varchar, inout p_uri varchar,
  inout o_uri varchar,
  inout app_env any )
{
  dict_put (app_env,
    vector (
      __bft (s_uri, 1),
      __bft (p_uri, 1),
      __bft (o_uri, 1) ),
    0 );
}
;

create procedure DB.DBA.RDF_TTL2SQLHASH_EXEC_TRIPLE_L (
  inout g_iid IRI_ID, inout s_uri varchar, inout p_uri varchar,
  inout o_val any, inout o_type varchar, inout o_lang varchar,
  inout app_env any )
{
  dict_put (app_env,
    vector (
      __bft (s_uri, 1),
      __bft (p_uri, 1),
      DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL_STRINGS (o_val,
        case when (isstring (o_type) or isuname (o_type)) then o_type else null end,
        case when (isstring (o_lang) or isuname (o_lang)) then o_lang else null end) ),
    0 );
}
;

create function DB.DBA.RDF_TTL2SQLHASH (in strg varchar, in base varchar, in graph varchar := null, in flags integer := 0) returns any
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
      'DB.DBA.RDF_TTL2SQLHASH_EXEC_GET_IID',
      'DB.DBA.RDF_TTL2SQLHASH_EXEC_TRIPLE',
      'DB.DBA.RDF_TTL2SQLHASH_EXEC_TRIPLE_L',
      '',
      'DB.DBA.TTLP_EV_REPORT_DEFAULT' ),
    res);
  return res;
}
;

create procedure DB.DBA.RDF_LOAD_RDFXML_IMPL (inout strg varchar, in base varchar, in graph varchar,
  in parse_mode integer, in log_enable int := null, in transactional int := 0)
{
  declare app_env any;
  declare old_log_mode int;
  if (graph = '')
    signal ('22023', 'Empty string is not a valid graph IRI in DB.DBA.RDF_LOAD_RDFXML() and the like');
  else if (graph is null)
    {
      graph := base;
      if ((graph is null) or (graph = ''))
        signal ('22023', 'DB.DBA.RDF_LOAD_RDFXML() and similar functions require a valid IRI as a base argument if graph is not specified');
    }
  old_log_mode := null;
  if (transactional = 0)
    {
      if (log_enable = 0 or log_enable = 1)
        log_enable := log_enable + 2;
    }
  if (log_enable is not null)
    {
      old_log_mode := log_enable (log_enable, 1);
    }
  if (1 <> sys_stat ('cl_run_local_only'))
    return DB.DBA.RDF_LOAD_RDFXML_CL (strg, base, graph, parse_mode);
  if (not is_atomic ())
    return db.dba.rdf_load_rdfxml_v (strg, base, graph, transactional => transactional, log_mode => log_enable, parse_mode => parse_mode);
  app_env := vector (
    null,
    null,
    __max (length (strg) / 100, 100000),
    null );
  rdf_load_rdfxml (strg, parse_mode,
    graph,
    vector (
      'DB.DBA.TTLP_EV_NEW_GRAPH',
      'DB.DBA.TTLP_EV_NEW_BLANK',
      'DB.DBA.TTLP_EV_GET_IID',
      'DB.DBA.TTLP_EV_TRIPLE',
      'DB.DBA.TTLP_EV_TRIPLE_L',
      'DB.DBA.TTLP_EV_COMMIT',
      'DB.DBA.TTLP_EV_REPORT_DEFAULT' ),
    app_env,
    base );
  if (__rdf_graph_is_in_enabled_repl (iri_to_id (graph)))
    repl_text ('__rdf_repl', '__rdf_repl_flush_queue ()');
  return graph;
}
;

create procedure DB.DBA.RDF_LOAD_RDFXML (in strg varchar, in base varchar, in graph varchar := null,
  in xml_parse_mode integer := 0, in log_enable int := null, in transactional int := 0 )
{
  return DB.DBA.RDF_LOAD_RDFXML_IMPL (strg, base, graph, bit_shift (xml_parse_mode, 8), log_enable, transactional);
}
;


create procedure DB.DBA.RDF_RDFXML_TO_DICT (in strg varchar, in base varchar, in graph varchar := null)
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
      '',
      'DB.DBA.TTLP_EV_REPORT_DEFAULT' ),
    res,
    base );
  return res;
}
;

create procedure DB.DBA.RDF_RDFXML_LOAD_DICT (in strg varchar, in base varchar, in graph varchar, inout dict any, in flag int := 0, in xml_parse_mode int := 0)
{
  if (__tag (dict) <> 214)
    signal ('22023', 'RDFXX', 'The dict argument must be of type dictionary');
  if (flag = 0)
    xml_parse_mode := 0;
  rdf_load_rdfxml (strg, bit_or (flag, bit_shift (xml_parse_mode, 8)), -- 0 rdfxml, 2 rdfa
    graph,
    vector (
      'DB.DBA.RDF_TTL2HASH_EXEC_NEW_GRAPH',
      'DB.DBA.RDF_TTL2HASH_EXEC_NEW_BLANK',
      'DB.DBA.RDF_TTL2HASH_EXEC_GET_IID',
      'DB.DBA.RDF_TTL2HASH_EXEC_TRIPLE',
      'DB.DBA.RDF_TTL2HASH_EXEC_TRIPLE_L',
      '',
      'DB.DBA.TTLP_EV_REPORT_DEFAULT' ),
    dict,
    base );
}
;

create procedure DB.DBA.RDFA_LOAD_DICT (in strg varchar, in base varchar, in graph varchar, inout dict any, in xml_parse_mode int := 0)
{
  declare app_env any;
  if (__tag (dict) <> 214)
    signal ('22023', 'RDFXX', 'The dict argument must be of type dictionary');
  rdf_load_rdfxml (strg, bit_or (2, bit_shift (xml_parse_mode, 8)), -- 0 rdfxml, 2 rdfa
    graph,
    vector (
      'DB.DBA.RDF_TTL2HASH_EXEC_NEW_GRAPH',
      'DB.DBA.RDF_TTL2HASH_EXEC_NEW_BLANK',
      'DB.DBA.RDF_TTL2HASH_EXEC_GET_IID',
      'DB.DBA.RDF_TTL2HASH_EXEC_TRIPLE',
      'DB.DBA.RDF_TTL2HASH_EXEC_TRIPLE_L',
      '',
      'DB.DBA.TTLP_EV_REPORT_DEFAULT'),
    dict,
    base );
}
;


create procedure DB.DBA.RDFA_LOAD_DICT_XLAT (in strg varchar, in base varchar, in graph varchar, inout dict any, in xml_parse_mode int := 0, in iri_xlate_cbk varchar, in iri_xlate_env any)
{
  declare app_env any;
  if (__tag (dict) <> 214)
    signal ('22023', 'RDFXX', 'The dict argument must be of type dictionary');
  rdf_load_rdfxml (strg, bit_or (2, bit_shift (xml_parse_mode, 8)), -- 0 rdfxml, 2 rdfa
    graph,
    vector (
      'DB.DBA.RDF_TTL2HASH_EXEC_NEW_GRAPH',
      'DB.DBA.RDF_TTL2HASH_EXEC_NEW_BLANK',
      'DB.DBA.RDF_TTL2HASH_EXEC_GET_IID',
      'DB.DBA.RDF_TTL2HASH_EXEC_TRIPLE_XLAT',
      'DB.DBA.RDF_TTL2HASH_EXEC_TRIPLE_L_XLAT',
      '',
      'DB.DBA.TTLP_EV_REPORT_DEFAULT' ),
    vector (dict, iri_xlate_cbk, iri_xlate_env),
    base );
}
;



create procedure DB.DBA.RDF_RDFA11_FETCH_PROFILES (in profile_iris any, inout prefixes any, inout terms any, inout vocab any)
{
  declare agg any;
  -- dbg_obj_princ ('DB.DBA.RDF_RDFA11_FETCH_PROFILES (', profile_iris, ')');
  foreach (varchar profile_iri in profile_iris) do
    {
      if (not exists (sparql define input:storage "" ask where { graph `iri(?:profile_iri)` { ?s ?p ?o }}))
        DB.DBA.SPARUL_LOAD (profile_iri, profile_iri, 0, NULL, 0);
    }
  vectorbld_init (agg);
  foreach (varchar profile_iri in profile_iris) do
    {
      for (sparql define input:storage "" prefix rdfa: <http://www.w3.org/ns/rdfa#>
        select ?p, ?u
        where {
            graph `iri(?:profile_iri)` {
                ?s rdfa:prefix ?p ; rdfa:uri ?u .
                optional { ?s rdfa:uri ?u2 . filter (?u != ?u2). }
                filter (isliteral (?p))
                filter (isliteral (?u))
                filter (?u != '')
                filter (!bound (?u2)) } }
        ) do { vectorbld_acc (agg, "p", "u"); }
    }
  vectorbld_final (agg);
  prefixes := agg;
  vectorbld_init (agg);
  foreach (varchar profile_iri in profile_iris) do
    {
      for (sparql define input:storage "" prefix rdfa: <http://www.w3.org/ns/rdfa#>
        select ?t, ?u
        where {
            graph `iri(?:profile_iri)` {
                ?s rdfa:term ?t ; rdfa:uri ?u .
                optional { ?s rdfa:uri ?u2 . filter (?u != ?u2). }
                optional { ?s rdfa:term ?t2 . filter (?t != ?t2). }
                filter (isliteral (?t))
                filter (isliteral (?u))
                filter (?t != '')
                filter (?u != '')
                filter (!bound (?t2))
                filter (!bound (?u2)) } }
        order by ?t
        ) do { vectorbld_acc (agg, "t", "u"); }
    }
  vectorbld_final (agg);
  if (1 < length (profile_iris))
    gvector_sort (agg, 2, 0, 1);
  terms := agg;
  vocab := null;
  foreach (varchar profile_iri in profile_iris) do
    {
      vocab := (sparql define input:storage "" prefix rdfa: <http://www.w3.org/ns/rdfa#>
        select (max(str(?v)))
        where {
            graph `iri(?:profile_iri)` {
                ?s rdfa:vocabulary ?v } } );
      if (isstring (vocab))
        goto vocab_is_set;
    }
vocab_is_set: ;
  -- dbg_obj_princ ('DB.DBA.RDF_RDFA11_FETCH_PROFILES (', profile_iris, ' returned ', prefixes, terms, vocab);
}
;


create procedure DB.DBA.RDF_LOAD_RDFA (in strg varchar, in base varchar, in graph varchar := null,
  in xml_parse_mode integer := 0, in log_enable int := null, in transactional int := 0 )
{
  return DB.DBA.RDF_LOAD_RDFXML_IMPL (strg, base, graph, bit_or (2, bit_shift (xml_parse_mode, 8)), log_enable, transactional);
}
;

create procedure DB.DBA.RDF_LOAD_RDFA_WITH_IRI_TRANSLATION (in strg varchar, in base varchar, in graph varchar, in xml_parse_mode integer,
  in iri_xlate_cbk varchar, in iri_xlate_env any)
{
  declare app_env any;
  if (graph = '')
    signal ('22023', 'Empty string is not a valid graph IRI in DB.DBA.RDF_LOAD_RDFA_WITH_IRI_TRANSLATION ()');
  else if (graph is null)
    {
      graph := base;
      if ((graph is null) or (graph = ''))
        signal ('22023', 'DB.DBA.RDF_LOAD_RDFA_WITH_IRI_TRANSLATION () requires a valid IRI as a base argument if graph is not specified');
    }
  if (1 <> sys_stat ('cl_run_local_only'))
    return DB.DBA.RDF_LOAD_RDFA_WITH_IRI_TRANSLATION_CL (strg, base, graph, xml_parse_mode, iri_xlate_cbk, iri_xlate_env);
  app_env := vector (
    null,
    null,
    __max (length (strg) / 100, 100000),
    null,
    iri_xlate_cbk,
    iri_xlate_env );
  rdf_load_rdfxml (strg, bit_or (2, bit_shift (xml_parse_mode, 8)),
    graph,
    vector (
      'DB.DBA.TTLP_EV_NEW_GRAPH',
      'DB.DBA.TTLP_EV_NEW_BLANK',
      'DB.DBA.TTLP_EV_GET_IID',
      'DB.DBA.TTLP_EV_TRIPLE_XLAT',
      'DB.DBA.TTLP_EV_TRIPLE_L_XLAT',
      'DB.DBA.TTLP_EV_COMMIT',
      'DB.DBA.TTLP_EV_REPORT_DEFAULT' ),
    app_env,
    base );
  if (__rdf_graph_is_in_enabled_repl (iri_to_id (graph)))
    repl_text ('__rdf_repl', '__rdf_repl_flush_queue ()');
  return graph;
}
;

create procedure DB.DBA.RDF_RDFA_TO_DICT (in strg varchar, in base varchar, in graph varchar := null)
{
  declare res any;
  res := dict_new (length (strg) / 100);
  rdf_load_rdfxml (strg, 2,
    graph,
    vector (
      'DB.DBA.RDF_TTL2HASH_EXEC_NEW_GRAPH',
      'DB.DBA.RDF_TTL2HASH_EXEC_NEW_BLANK',
      'DB.DBA.RDF_TTL2HASH_EXEC_GET_IID',
      'DB.DBA.RDF_TTL2HASH_EXEC_TRIPLE',
      'DB.DBA.RDF_TTL2HASH_EXEC_TRIPLE_L',
      '',
      'DB.DBA.TTLP_EV_REPORT_DEFAULT' ),
    res,
    base );
  return res;
}
;

create procedure DB.DBA.RDF_LOAD_XHTML_MICRODATA (in strg varchar, in base varchar, in graph varchar := null,
  in xml_parse_mode integer := 1, in log_enable int := null, in transactional int := 0 )
{
  return DB.DBA.RDF_LOAD_RDFXML_IMPL (strg, base, graph, bit_or (4, bit_shift (xml_parse_mode, 8)), log_enable, transactional);
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
create procedure DB.DBA.RDF_CONVERT_RDFXML_TO_TTL_EV_NEW_BLANK (inout g_iid IRI_ID, inout app_env any, inout res IRI_ID)
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
      '',
      'DB.DBA.RDF_CONVERT_RDFXML_TO_TTL_EV_NEW_BLANK',
      'DB.DBA.TTLP_EV_GET_IID',
      'DB.DBA.RDF_CONVERT_RDFXML_TO_TTL_EV_TRIPLE',
      'DB.DBA.RDF_CONVERT_RDFXML_TO_TTL_EV_TRIPLE_L',
      '',
      'DB.DBA.TTLP_EV_REPORT_DEFAULT' ),
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
      if (rdf_box_data_tag (obj) in (__tag of varchar, __tag of long varchar, __tag of nvarchar, __tag of long nvarchar, 185))
        http_escape (__rdf_sqlval_of_obj (obj, 1), 11, ses, 1, 1);
      else if (__tag of datetime = rdf_box_data_tag (obj))
        __rdf_long_to_ttl (obj, ses);
      else if (__tag of XML = rdf_box_data_tag (obj))
        http_escape (serialize_to_UTF8_xml (__rdf_sqlval_of_obj (obj, 1)), 11, ses, 1, 1);
      else if (__tag of varbinary = rdf_box_data_tag (obj))
        {
          http ('"', ses);
          http_escape (__rdf_sqlval_of_obj (obj, 1), 11, ses, 0, 0);
          http ('" ', ses);
        }
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
  else if (__tag (obj) in (__tag of long varchar, __tag of nvarchar, __tag of long nvarchar, 185))
    {
      http ('"', ses);
      http_escape (obj, 11, ses, 1, 1);
      http ('" ', ses);
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
      http_escape (__rdf_strsqlval (obj), 11, ses, 1, 1);
      http ('"^^<', ses);
      http_escape (cast (__xsd_type (obj) as varchar), 12, ses, 1, 1);
      http ('> ', ses);
    }
}
;


create procedure DB.DBA.RDF_TRIPLES_TO_VERBOSE_TTL (inout triples any, inout ses any)
{
  declare tcount, tctr integer;
  declare prev_s, prev_p IRI_ID;
  declare res varchar;
  declare string_subjs_found, string_preds_found integer;
  string_subjs_found := 0;
  string_preds_found := 0;
  tcount := length (triples);
  -- dbg_obj_princ ('DB.DBA.RDF_TRIPLES_TO_VERBOSE_TTL:'); for (tctr := 0; tctr < tcount; tctr := tctr + 1) -- dbg_obj_princ (triples[tctr]);
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
  DB.DBA.RDF_TRIPLES_BATCH_COMPLETE (triples);
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

create function DB.DBA.RDF_TRIPLES_TO_TTL_ENV (in tcount integer, in env_flags integer, in col_metas any, inout ses any)
{
  return vector (dict_new (__min (tcount, 16000)), 0, '', '', '', 0, 0, env_flags, col_metas, ses);
}
;

create procedure DB.DBA.RDF_TRIPLES_TO_TTL (inout triples any, inout ses any)
{
  declare env any;
  declare tcount, tctr integer;
  tcount := length (triples);
  -- dbg_obj_princ ('DB.DBA.RDF_TRIPLES_TO_TTL:'); for (tctr := 0; tctr < tcount; tctr := tctr + 1) -- dbg_obj_princ (triples[tctr]);
  if (0 = tcount)
    {
      http ('# Empty TURTLE\n', ses);
      return;
    }
  env := DB.DBA.RDF_TRIPLES_TO_TTL_ENV (tcount, 0, 0, ses);
  { whenever sqlstate '*' goto end_pred_sort;
    rowvector_subj_sort (triples, 1, 1);
end_pred_sort: ;
  }
  { whenever sqlstate '*' goto end_subj_sort;
    rowvector_subj_sort (triples, 0, 1);
end_subj_sort: ;
  }
  DB.DBA.RDF_TRIPLES_BATCH_COMPLETE (triples);
  for (tctr := 0; tctr < tcount; tctr := tctr + 1)
    {
      http_ttl_triple (env, triples[tctr][0], triples[tctr][1], triples[tctr][2], ses);
    }
  http (' .', ses);
}
;

create procedure DB.DBA.RDF_TRIPLES_TO_TRIG (inout triples any, inout ses any)
{
  declare env any;
  declare tcount, tctr, first_dflt_g_idx integer;
  declare prev_g_iri varchar;
  declare first_g_idx integer;
  tcount := length (triples);
  if (0 = tcount)
    {
      http ('# Empty TriG\n', ses);
      return;
    }
  env := DB.DBA.RDF_TRIPLES_TO_TTL_ENV (tcount, 0, 0, ses);
  { whenever sqlstate '*' goto end_pred_sort;
    rowvector_subj_sort (triples, 1, 1);
end_pred_sort: ;
  }
  { whenever sqlstate '*' goto end_subj_sort;
    rowvector_subj_sort (triples, 0, 1);
end_subj_sort: ;
  }
  rowvector_graph_sort (triples, 3, 1);
  -- dbg_obj_princ ('DB.DBA.RDF_TRIPLES_TO_TRIG after sort:'); for (tctr := 0; tctr < tcount; tctr := tctr + 1) -- dbg_obj_princ (triples[tctr]);
  DB.DBA.RDF_TRIPLES_BATCH_COMPLETE (triples);
  for (tctr := 0; (tctr < tcount) and aref_or_default (triples, tctr, 3, null) is null; tctr := tctr + 1)
    {
      http_ttl_prefixes (env, triples[tctr][0], triples[tctr][1], triples[tctr][2], ses);
    }
  first_g_idx := tctr;
  for (tctr := first_g_idx; tctr < tcount; tctr := tctr + 1)
    {
      http_ttl_prefixes (env, triples[tctr][0], triples[tctr][1], triples[tctr][2], ses);
    }
  if (0 < first_g_idx)
    {
      http ('{\n', ses);
      for (tctr := 0; tctr < first_g_idx; tctr := tctr + 1)
        {
          http_ttl_triple (env, triples[tctr][0], triples[tctr][1], triples[tctr][2], ses);
        }
      http (' .\n}\n', ses);
    }
  prev_g_iri := '';
  for (tctr := first_g_idx; tctr < tcount; tctr := tctr + 1)
    {
      declare g_iri varchar;
      g_iri := id_to_iri_nosignal (triples[tctr][3]);
      if (g_iri is not null)
        {
          if (g_iri <> prev_g_iri)
            {
              if (prev_g_iri <> '')
                http (' .\n}\n', ses);
              env[1] := 0;
              http ('<', ses);
              http_escape (g_iri, 12, ses, 1, 1);
              http ('> = {\n', ses);
              prev_g_iri := g_iri;
            }
          http_ttl_triple (env, triples[tctr][0], triples[tctr][1], triples[tctr][2], ses);
        }
    }
  if (prev_g_iri <> '')
    http (' .\n}\n', ses);
}
;

create procedure DB.DBA.RDF_TRIPLES_TO_NT (inout triples any, inout ses any)
{
  declare env any;
  declare tcount, tctr integer;
  tcount := length (triples);
  -- dbg_obj_princ ('DB.DBA.RDF_TRIPLES_TO_TTL:'); for (tctr := 0; tctr < tcount; tctr := tctr + 1) -- dbg_obj_princ (triples[tctr]);
  if (0 = tcount)
    {
      http ('# Empty NT\n', ses);
      return;
    }
  env := vector (0, 0, 0);
  DB.DBA.RDF_TRIPLES_BATCH_COMPLETE (triples);
  for (tctr := 0; tctr < tcount; tctr := tctr + 1)
    {
      http_nt_triple (env, triples[tctr][0], triples[tctr][1], triples[tctr][2], ses);
    }
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
  for (select S as subj, P as pred, O as obj from DB.DBA.RDF_QUAD where G = iri_to_id (graph_iri)) do
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
  declare ns_dict, env any;
  declare tcount, tctr integer;
  tcount := length (triples);
  DB.DBA.RDF_TRIPLES_BATCH_COMPLETE (triples);
  { whenever sqlstate '*' goto end_pred_sort;
    rowvector_subj_sort (triples, 1, 1);
end_pred_sort: ;
  }
  ns_dict := dict_new (case (print_top_level) when 0 then 10 else __min (tcount, 16000) end);
  dict_put (ns_dict, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#', 'rdf');
  dict_put (ns_dict, 'http://www.w3.org/2000/01/rdf-schema#', 'rdfs');
  env := vector (ns_dict, 0, 0, '', '', 0, 0, 0, 0, 0);
  if (print_top_level)
    {
       http ('<?xml version="1.0" encoding="utf-8" ?>\n<rdf:RDF\n\txmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"\n\txmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"', ses);
       for (tctr := 0; tctr < tcount; tctr := tctr + 1)
         {
           http_rdfxml_p_ns (env, triples[tctr][1], ses);
         }
       http (' >', ses);
    }
  { whenever sqlstate '*' goto end_subj_sort;
    rowvector_subj_sort (triples, 0, 1);
end_subj_sort: ;
  }
  for (tctr := 0; tctr < tcount; tctr := tctr + 1)
    {
      http_rdfxml_triple (env, triples[tctr][0], triples[tctr][1], triples[tctr][2], ses);
    }
  if (isstring (env[2]))
    http ('\n  </rdf:Description>', ses);
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

create procedure DB.DBA.RDF_TRIPLES_TO_TALIS_JSON (inout triples any, inout ses any)
{
  declare env any;
  declare tcount, tctr, status integer;
  tcount := length (triples);
  -- dbg_obj_princ ('DB.DBA.RDF_TRIPLES_TO_TALIS_JSON:'); for (tctr := 0; tctr < tcount; tctr := tctr + 1) -- dbg_obj_princ (triples[tctr]);
  if (0 = tcount)
    {
      http ('{ }\n', ses);
      return;
    }
  env := vector (0, 0, 0, null);
-- No error handlers here because failed sorting by predicate or subject would result in poorly structured output.
  rowvector_subj_sort (triples, 1, 1);
  rowvector_subj_sort (triples, 0, 1);
  DB.DBA.RDF_TRIPLES_BATCH_COMPLETE (triples);
  http ('{\n  ', ses);
  status := 0;
  for (tctr := 0; tctr < tcount; tctr := tctr + 1)
    {
      if (http_talis_json_triple (env, triples[tctr][0], triples[tctr][1], triples[tctr][2], ses))
        status := 1;
    }
  if (status)
    http (' ] }\n', ses);
  http ('}\n', ses);
}
;

create procedure DB.DBA.RDF_TRIPLES_TO_JSON_LD (inout triples any, inout ses any)
{
  declare env any;
  declare tcount, tctr, status integer;
  tcount := length (triples);
  -- dbg_obj_princ ('DB.DBA.RDF_TRIPLES_TO_JSON_LD:'); for (tctr := 0; tctr < tcount; tctr := tctr + 1) -- dbg_obj_princ (triples[tctr]);
  if (0 = tcount)
    {
      http ('{ }\n', ses);
      return;
    }
  env := vector (0, 0, 0, null);
-- No error handlers here because failed sorting by predicate or subject would result in poorly structured output.
  rowvector_subj_sort (triples, 1, 1);
  rowvector_subj_sort (triples, 0, 1);
  DB.DBA.RDF_TRIPLES_BATCH_COMPLETE (triples);
  http ('{ "@graph": [\n    ', ses);
  status := 0;
  for (tctr := 0; tctr < tcount; tctr := tctr + 1)
    {
      if (http_ld_json_triple (env, triples[tctr][0], triples[tctr][1], triples[tctr][2], ses))
        status := 1;
    }
  if (status)
    http (' ] }\n', ses);
  http ('] }\n', ses);
}
;

create procedure DB.DBA.RDF_TRIPLES_TO_JSON (inout triples any, inout ses any)
{
  declare tcount, tctr, env integer;
  tcount := length (triples);
  http ('\n{ "head": { "link": [], "vars": [ "s", "p", "o" ] },\n  "results": { "distinct": false, "ordered": true, "bindings": [', ses);
  tcount := length (triples);
  env := vector (0, 0, vector ('s', 'p', 'o'), null);
  DB.DBA.RDF_TRIPLES_BATCH_COMPLETE (triples);
  for (tctr := 0; tctr < tcount; tctr := tctr + 1)
    {
      declare triple any;
      if (tctr > 0)
        http(',', ses);
      triple := aref_set_0 (triples, tctr);
      sparql_rset_json_write_row (ses, env, triple);
      aset_zap_arg (triples, tctr, triple);
    }
  http (' ] } }', ses);
}
;

create procedure DB.DBA.RDF_TRIPLES_TO_CSV (inout triples any, inout ses any)
{
  declare env any;
  declare tcount, tctr, status integer;
  http ('"subject","predicate","object"\n', ses);
  tcount := length (triples);
  -- dbg_obj_princ ('DB.DBA.RDF_TRIPLES_TO_CSV:'); for (tctr := 0; tctr < tcount; tctr := tctr + 1) -- dbg_obj_princ (triples[tctr]);
  { whenever sqlstate '*' goto p_done; rowvector_subj_sort (triples, 1, 1); p_done: ; }
  { whenever sqlstate '*' goto s_done; rowvector_subj_sort (triples, 0, 1); s_done: ; }
  DB.DBA.RDF_TRIPLES_BATCH_COMPLETE (triples);
  for (tctr := 0; tctr < tcount; tctr := tctr + 1)
    {
      DB.DBA.SPARQL_RESULTS_CSV_WRITE_VALUE (ses, triples[tctr][0]);
      http (',', ses);
      DB.DBA.SPARQL_RESULTS_CSV_WRITE_VALUE (ses, triples[tctr][1]);
      http (',', ses);
      DB.DBA.SPARQL_RESULTS_CSV_WRITE_VALUE (ses, triples[tctr][2]);
      http ('\n', ses);
    }
}
;

create procedure DB.DBA.RDF_TRIPLES_TO_TSV (inout triples any, inout ses any)
{
  declare env any;
  declare tcount, tctr, status integer;
  http ('"subject","predicate","object"\n', ses);
  tcount := length (triples);
  -- dbg_obj_princ ('DB.DBA.RDF_TRIPLES_TO_TSV:'); for (tctr := 0; tctr < tcount; tctr := tctr + 1) -- dbg_obj_princ (triples[tctr]);
  { whenever sqlstate '*' goto p_done; rowvector_subj_sort (triples, 1, 1); p_done: ; }
  { whenever sqlstate '*' goto s_done; rowvector_subj_sort (triples, 0, 1); s_done: ; }
  DB.DBA.RDF_TRIPLES_BATCH_COMPLETE (triples);
  for (tctr := 0; tctr < tcount; tctr := tctr + 1)
    {
      DB.DBA.SPARQL_RESULTS_CSV_WRITE_VALUE (ses, triples[tctr][0]);
      http ('\t', ses);
      DB.DBA.SPARQL_RESULTS_CSV_WRITE_VALUE (ses, triples[tctr][1]);
      http ('\t', ses);
      DB.DBA.SPARQL_RESULTS_CSV_WRITE_VALUE (ses, triples[tctr][2]);
      http ('\n', ses);
    }
}
;

create procedure DB.DBA.RDF_TRIPLES_TO_RDFA_XHTML (inout triples any, inout ses any)
{
  declare env, prev_subj, subj_text, pred_text, nsdict, nslist any;
  declare ctr, len, tcount, tctr, status integer;
  tcount := length (triples);
  -- dbg_obj_princ ('DB.DBA.RDF_TRIPLES_TO_RDFA_XHTML:'); for (tctr := 0; tctr < tcount; tctr := tctr + 1) -- dbg_obj_princ (triples[tctr]);
  http ('<?xml version="1.0" encoding="UTF-8"?>\n
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.0//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-1.dtd">\n', ses);
  if (0 = tcount)
    {
      http ('<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>Empty RDFa+XHTML document</title></head><body>
<p>This document is empty and basically useless. It is generated by a web service that can make some statements in XHTML+RDFa format.
This time the service made zero such statements, sorry.</p></body></html>', ses);
      return;
    }
  nsdict := dict_new (10 + cast (sqrt(tcount) as integer));
  dict_put (nsdict, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#', 'rdf');
  dict_put (nsdict, 'http://www.w3.org/2001/XMLSchema#', 'xsdh');
  DB.DBA.RDF_TRIPLES_BATCH_COMPLETE (triples);
  for (tctr := 0; (tctr < tcount) and (1000 > dict_size (nsdict)); tctr := tctr + 1)
    {
      sparql_iri_split_rdfa_qname (triples[tctr][0], nsdict, 1);
      sparql_iri_split_rdfa_qname (triples[tctr][1], nsdict, 1);
      sparql_iri_split_rdfa_qname (triples[tctr][2], nsdict, 1);
    }
  http ('<html xmlns="http://www.w3.org/1999/xhtml"', ses);
  nslist := dict_to_vector (nsdict, 0);
  len := length (nslist);
  for (ctr := len - 2; ctr >= 0; ctr := ctr-2)
    {
      http (sprintf ('\n  xmlns:%s="', nslist[ctr+1]), ses);
      http_escape (nslist[ctr], 3, ses, 1, 1);
      http ('"', ses);
    }
  http ('>\n<head><title>RDFa+XHTML document</title></head><body>\n', ses);
  http (sprintf ('<p>This HTML document contains %d embedded RDF statements represented using (X)HTML+RDFa notation.</p>',
    tcount), ses);
  http ('<p>The embedded RDF content will be recognized by any processor of (X)HTML+RDFa.</p>', ses);
  http ('\n<table border="1">\n<thead><tr><th>Namespace Prefix</th><th>Namespace URI</th></tr></thead><tbody>', ses);
  for (ctr := len - 2; ctr >= 0; ctr := ctr-2)
    {
      http (sprintf ('\n<tr><td>xmlns:%s</td><td>', nslist[ctr+1]), ses);
      http_escape (nslist[ctr], 3, ses, 1, 1);
      http ('</td></tr>', ses);
    }
  http ('\n</tbody></table>', ses);
  http ('\n<table border="1">\n<thead><tr><th>Subject</th><th>Predicate</th><th>Object</th></tr></thead>', ses);
  env := vector (0, 0, 0, null);
  rowvector_subj_sort (triples, 1, 1);
  rowvector_subj_sort (triples, 0, 1);
  prev_subj := null;
  for (tctr := 0; tctr < tcount; tctr := tctr + 1)
    {
      declare subj, pred, obj, split, obj_iri_split any;
      declare pred_tagname varchar;
      declare res varchar;
      subj := triples[tctr][0];
      pred := triples[tctr][1];
      obj := triples[tctr][2];
      -- dbg_obj_princ ('DB.DBA.RDF_TRIPLES_TO_RDFA_XHTML: subj:', subj, __tag(subj), __box_flags (subj));
      -- dbg_obj_princ ('DB.DBA.RDF_TRIPLES_TO_RDFA_XHTML: pred:', pred, __tag(pred), __box_flags (pred));
      -- dbg_obj_princ ('DB.DBA.RDF_TRIPLES_TO_RDFA_XHTML: obj:', obj, __tag(obj), __box_flags (obj));
      if (prev_subj is null or (subj <> prev_subj))
        {
          if (prev_subj is not null)
            http ('\n</tbody>', ses);
          http ('\n<tbody about="[', ses);
          split := sparql_iri_split_rdfa_qname (subj, nsdict, 2);
          -- dbg_obj_princ ('Split of ', subj, ' is ', split);
          if ('' = split[1])
            {
              subj_text := split[2];
              http_escape (subj_text, 3, ses, 1, 1);
              http (']">', ses);
            }
          else if (isstring (split[0]))
            {
              subj_text := concat (split[0], ':', split[2]);
              http_escape (subj_text, 3, ses, 1, 1);
              http (']">', ses);
            }
          else
            {
              subj_text := id_to_iri (subj);
              http_escape (concat ('s:', split[2]), 3, ses, 1, 1);
              http (']" xmlns:s="', ses);
              http_escape (split[1], 3, ses, 1, 1);
              http ('">', ses);
            }
          subj_text := sprintf ('\n<tr><td>%V</td><td>', subj_text);
          prev_subj := subj;
        }
      http (subj_text, ses);
      split := sparql_iri_split_rdfa_qname (pred, nsdict, 2);
      if ('' = split[1])
        {
          http_value (split[2], 0, ses);
        }
      else if (isstring (split[0]))
        {
          http_value (concat (split[0], ':', split[2]), 0, ses);
        }
      else
        {
          http_value (id_to_iri (pred), 0, ses);
        }
      obj_iri_split := sparql_iri_split_rdfa_qname (obj, nsdict, 2);
      http (case (isvector (obj_iri_split)) when 0 then '</td><td property="' else '</td><td rel="' end, ses);
      if ('' = split[1])
        {
          pred_text := split[2];
          http_escape (pred_text, 3, ses, 1, 1);
          http ('"', ses);
        }
      else if (isstring (split[0]))
        {
          pred_text := concat (split[0], ':', split[2]);
          http_escape (pred_text, 3, ses, 1, 1);
          http ('"', ses);
        }
      else
        {
          pred_text := id_to_iri (pred);
          http_escape (concat ('p:', split[2]), 3, ses, 1, 1);
          http ('" xmlns:p="', ses);
          http_escape (split[1], 3, ses, 1, 1);
          http ('"', ses);
        }
      if (obj is null)
        signal ('RDFXX', 'DB.DBA.TRIPLES_TO_RDFA_XHTML: object is NULL');
      if (isvector (obj_iri_split))
        {
          http (' resource="', ses);
          if (isstring (obj_iri_split[0]))
            {
              http ('[', ses);
              http_escape (concat (obj_iri_split[0], ':', obj_iri_split[2]), 3, ses, 1, 1);
              http (']" >', ses);
              http_value (concat (obj_iri_split[0], ':', obj_iri_split[2]), 0, ses);
              http ('</td></tr>', ses);
            }
          else
            {
              http_escape (concat (obj_iri_split[1], ':', obj_iri_split[2]), 3, ses, 1, 1);
              http ('" >', ses);
              http_value (concat (obj_iri_split[1], ':', obj_iri_split[2]), 0, ses);
              http ('</td></tr>', ses);
            }
        }
      else
        {
          declare sqlval any;
          declare dt, lang, strval any;
          dt := 0; lang := 0;
          if (__tag of rdf_box = __tag (obj))
            {
              if (257 <> rdf_box_type (obj))
                dt := coalesce ((select __bft (RDT_QNAME, 1) from DB.DBA.RDF_DATATYPE where RDT_TWOBYTE = rdf_box_type (obj)));
              else if (257 <> rdf_box_lang (obj))
                lang := coalesce ((select lower (RL_ID) from DB.DBA.RDF_LANGUAGE where RL_TWOBYTE = rdf_box_lang (obj)));
              sqlval := __rdf_sqlval_of_obj (obj, 1);
              if (__tag of datetime = __tag (sqlval))
                {
                  if (257 = rdf_box_type (obj))
                    dt := __xsd_type (sqlval);
                }
            }
          else if (__tag (obj) not in (__tag of varchar, __tag of varbinary))
            {
              sqlval := obj;
              dt := __xsd_type (sqlval);
            }
          else
            sqlval := obj;
          if (not (isinteger (dt)))
            {
              http (' datatype="', ses);
              split := sparql_iri_split_rdfa_qname (dt, nsdict, 2);
              if ('' = split[1])
                {
                  http_escape (split[2], 3, ses, 1, 1);
                  http ('"', ses);
                }
              else if (isstring (split[0]))
                {
                  http_escape (concat (split[0], ':', split[2]), 3, ses, 1, 1);
                  http ('"', ses);
                }
              else
                {
                  http_escape (concat ('dt:', split[2]), 3, ses, 1, 1);
                  http ('" xmlns:dt="', ses);
                  http_escape (split[1], 3, ses, 1, 1);
                  http ('"', ses);
                }
            }
          if (isstring (lang))
            {
              http (' xml:lang="', ses);
              http_escape (lang, 3, ses, 1, 1);
              http ('"', ses);
            }
          http ('>', ses);
          if (__tag of datetime = __tag(sqlval))
            __rdf_long_to_ttl (sqlval, ses);
          else if (__tag (sqlval) in (__tag of varbinary, __tag of XML))
            http_value (sqlval, 0, ses);
          else if (__tag of varchar = __tag (sqlval))
            http_value (charset_recode (sqlval, 'UTF-8', '_WIDE_'), 0, ses);
          else
            {
              sqlval := __rdf_strsqlval (obj);
              if (__tag of varchar = __tag (sqlval))
                sqlval := charset_recode (sqlval, 'UTF-8', '_WIDE_');
              http_value (sqlval, 0, ses);
            }
          http ('</td></tr>', ses);
        }
    }
  if (prev_subj is not null)
    http ('\n</tbody>', ses);
  http ('\n</table></body></html>\n', ses);
}
;

create function DB.DBA.RDF_ENDPOINT_DESCRIBE_LINK_FMT (in ul_or_tr varchar)
{
  declare lpath varchar;
  lpath := virtuoso_ini_item_value ('URIQA','DefaultHost');
  if (lpath is null)
    lpath := '/sparql';
  else
    lpath := 'http://' || lpath || '/sparql';
  whenever sqlstate 'HT013' goto no_http_context;
  lpath := http_path ();
no_http_context:
  return ' <a href=" ' || lpath || '?query=describe+%%3C%U%%3E&amp;format=text%%2Fx-html%%2B' || ul_or_tr || '">describe</a> ';
}
;

create function DB.DBA.RDF_PIVOT_DESCRIBE_LINK (in iri varchar)
{
  return sprintf ('; <a href="/describe/?url=%U&sid=1&amp;urilookup=1">facets</a> ', iri);
}
;

create procedure DB.DBA.RDF_TRIPLES_TO_HTML_UL (inout triples any, inout ses any)
{
  declare env, prev_subj, prev_pred any array;
  declare can_pivot, ctr, len, tcount, tctr, status, obj_needs_br integer;
  declare endpoint_fmt, subj_iri, pred_iri varchar;
  tcount := length (triples);
  -- dbg_obj_princ ('DB.DBA.RDF_TRIPLES_TO_HTML_UL:'); for (tctr := 0; tctr < tcount; tctr := tctr + 1) -- dbg_obj_princ (triples[tctr]);
  http ('<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.0//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-1.dtd">\n', ses);
  if (0 = tcount)
    {
      http ('<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>Empty HTML RDFa and Microdata document</title>
<meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
</head><body>
<p>This document is empty and basically useless. It is generated by a web service that can make some statements in HTML Microdata format.
This time the service made zero such statements, sorry.</p></body></html>', ses);
      return;
    }
  endpoint_fmt := DB.DBA.RDF_ENDPOINT_DESCRIBE_LINK_FMT ('ul');
  can_pivot := case (isnull (DB.DBA.VAD_CHECK_VERSION ('PivotViewer'))) when 0 then 1 else 0 end;
  DB.DBA.RDF_TRIPLES_BATCH_COMPLETE (triples);
  http ('<html xmlns="http://www.w3.org/1999/xhtml"', ses);
  http ('>\n<head><title>HTML RDFa and Microdata document</title>
<meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
</head>\n<body>\n<ul>\n', ses);
  env := vector (0, 0, 0, null);
  rowvector_subj_sort (triples, 1, 1);
  rowvector_subj_sort (triples, 0, 1);
  prev_subj := prev_pred := null;
  obj_needs_br := 0;
  for (tctr := 0; tctr < tcount; tctr := tctr + 1)
    {
      declare subj, pred, obj, split, obj_iri_split any array;
      declare pred_tagname varchar;
      declare res varchar;
      subj := triples[tctr][0];
      pred := triples[tctr][1];
      obj := triples[tctr][2];
      -- dbg_obj_princ ('DB.DBA.RDF_TRIPLES_TO_HTML_UL: subj:', subj, __tag(subj), __box_flags (subj));
      -- dbg_obj_princ ('DB.DBA.RDF_TRIPLES_TO_HTML_UL: pred:', pred, __tag(pred), __box_flags (pred));
      -- dbg_obj_princ ('DB.DBA.RDF_TRIPLES_TO_HTML_UL: obj:', obj, __tag(obj), __box_flags (obj));
      if (prev_subj is null or (subj <> prev_subj))
        {
          if (prev_subj is not null)
            http ('\n          </ul></li>\n      </ul></li>', ses);
          subj_iri := id_to_iri (subj);
          http ('\n  <li about="', ses);
          http_escape (subj_iri, 3, ses, 1, 1);
          http ('" itemscope="" itemid="', ses);
          http_escape (subj_iri, 3, ses, 1, 1);
          http ('"><a href="', ses);
          http_escape (subj_iri, 3, ses, 1, 1);
          http ('">', ses);
          http_escape (subj_iri, 1, ses, 1, 1);
          http ('</a> (', ses);
          http (sprintf (endpoint_fmt, subj_iri), ses);
          if (can_pivot)
            http (DB.DBA.RDF_PIVOT_DESCRIBE_LINK (subj_iri), ses);
          http (')\n    <ul>', ses);
          prev_subj := subj;
          prev_pred := null;
        }
      if (prev_pred is null or (pred <> prev_pred))
        {
          if (prev_pred is not null)
            http ('\n        </ul></li>', ses);
          pred_iri := id_to_iri (pred);
          http ('\n      <li><a href="', ses);
          http_escape (pred_iri, 3, ses, 1, 1);
          http ('">', ses);
          http_escape (pred_iri, 1, ses, 1, 1);
          http ('</a> (', ses);
          http (sprintf (endpoint_fmt, pred_iri), ses);
          if (can_pivot)
            http (DB.DBA.RDF_PIVOT_DESCRIBE_LINK (pred_iri), ses);
          http (')\n        <ul>', ses);
          prev_pred := pred;
          obj_needs_br := 0;
        }
      if (obj is null)
        signal ('RDFXX', 'DB.DBA.TRIPLES_TO_HTML_UL: object is NULL');
      if (obj_needs_br)
        http ('\n', ses);
      else
        obj_needs_br := 1;
      if (isiri_id (obj))
        {
          declare obj_iri varchar;
          obj_iri := id_to_iri (obj);
          http ('\n          <li><a rel="', ses);
          http_escape (pred_iri, 3, ses, 1, 1);
          http ('" resource="', ses);
          http_escape (obj_iri, 3, ses, 1, 1);
          http ('" itemprop="', ses);
          http_escape (pred_iri, 3, ses, 1, 1);
          http ('" href="', ses);
          http_escape (obj_iri, 3, ses, 1, 1);
          http ('">', ses);
          http_escape (obj_iri, 1, ses, 1, 1);
          http ('</a> (', ses);
          http (sprintf (endpoint_fmt, obj_iri), ses);
          if (can_pivot)
            http (DB.DBA.RDF_PIVOT_DESCRIBE_LINK (obj_iri), ses);
          http (')</li>', ses);
        }
      else
        {
          declare sqlval any;
          declare dt, lang, strval any;
          http ('\n          <li property="', ses);
          http_escape (pred_iri, 3, ses, 1, 1);
          http ('" itemprop="', ses);
          http_escape (pred_iri, 3, ses, 1, 1);
          dt := 0; lang := 0;
          if (__tag of rdf_box = __tag (obj))
            {
              if (257 <> rdf_box_lang (obj))
                lang := coalesce ((select lower (RL_ID) from DB.DBA.RDF_LANGUAGE where RL_TWOBYTE = rdf_box_lang (obj)));
              else if (257 <> rdf_box_type (obj))
                dt := coalesce ((select __bft (RDT_QNAME, 1) from DB.DBA.RDF_DATATYPE where RDT_TWOBYTE = rdf_box_type (obj)));
              sqlval := __rdf_sqlval_of_obj (obj, 1);
              if (__tag of datetime = __tag (sqlval))
                {
                  if (257 = rdf_box_type (obj))
                    dt := __xsd_type (sqlval);
                }
            }
          else if (__tag (obj) not in (__tag of varchar, __tag of varbinary))
            {
              sqlval := obj;
              dt := __xsd_type (sqlval);
            }
          else
            sqlval := obj;
          if (not (isinteger (dt)))
            {
              http ('" datatype="', ses);
              http_escape (dt, 3, ses, 1, 1);
            }
          if (isstring (lang))
            {
              http ('" xml:lang="', ses);
              http_escape (lang, 3, ses, 1, 1);
            }
          http ('">', ses);
          if (__tag of datetime = __tag(sqlval))
            __rdf_long_to_ttl (sqlval, ses);
          else if (__tag (sqlval) in (__tag of varbinary, __tag of XML))
            http_value (sqlval, 0, ses);
          else if (__tag of varchar = __tag (sqlval))
            http_value (charset_recode (sqlval, 'UTF-8', '_WIDE_'), 0, ses);
          else
            {
              sqlval := __rdf_strsqlval (obj);
              if (__tag of varchar = __tag (sqlval))
                sqlval := charset_recode (sqlval, 'UTF-8', '_WIDE_');
              http_value (sqlval, 0, ses);
            }
          http ('</li>', ses);
        }
    }
  if (prev_subj is not null)
    http ('\n        </ul></li></ul></li></ul>', ses);
  http ('\n</body></html>\n', ses);
}
;


create procedure DB.DBA.RDF_TRIPLES_TO_HTML_TR (inout triples any, inout ses any)
{
  declare env, prev_subj, prev_pred any;
  declare can_pivot, ctr, len, tcount, tctr, status integer;
  declare endpoint_fmt, subj_iri, pred_iri, subj_recod, pred_recod, subj_trtd, pred_tdtd varchar;
  tcount := length (triples);
  -- dbg_obj_princ ('DB.DBA.RDF_TRIPLES_TO_HTML_TR:'); for (tctr := 0; tctr < tcount; tctr := tctr + 1) -- dbg_obj_princ (triples[tctr]);
  -- http ('<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE html>\n', ses);
  if (0 = tcount)
    {
      http ('<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>Empty HTML RDFa and Microdata document</title></head><body>
<p>This document is empty and basically useless. It is generated by a web service that can make some statements in HTML Microdata format.
This time the service made zero such statements, sorry.</p></body></html>', ses);
      return;
    }
  endpoint_fmt := DB.DBA.RDF_ENDPOINT_DESCRIBE_LINK_FMT ('tr');
  can_pivot := case (isnull (DB.DBA.VAD_CHECK_VERSION ('PivotViewer'))) when 0 then 1 else 0 end;
  DB.DBA.RDF_TRIPLES_BATCH_COMPLETE (triples);
  http ('<html xmlns="http://www.w3.org/1999/xhtml"', ses);
  http ('>\n<head><title>HTML RDFa and Microdata document</title>
<meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
</head>\n<body>\n<table>\n', ses);
  env := vector (0, 0, 0, null);
  rowvector_subj_sort (triples, 1, 1);
  rowvector_subj_sort (triples, 0, 1);
  prev_subj := prev_pred := null;
  for (tctr := 0; tctr < tcount; tctr := tctr + 1)
    {
      declare subj, pred, obj, split, obj_iri_split any;
      declare pred_tagname varchar;
      declare res varchar;
      subj := triples[tctr][0];
      pred := triples[tctr][1];
      obj := triples[tctr][2];
      -- dbg_obj_princ ('DB.DBA.RDF_TRIPLES_TO_HTML_TR: subj:', subj, __tag(subj), __box_flags (subj));
      -- dbg_obj_princ ('DB.DBA.RDF_TRIPLES_TO_HTML_TR: pred:', pred, __tag(pred), __box_flags (pred));
      -- dbg_obj_princ ('DB.DBA.RDF_TRIPLES_TO_HTML_TR: obj:', obj, __tag(obj), __box_flags (obj));
      if (prev_subj is null or (subj <> prev_subj))
        {
          declare trtd_ses any;
          subj_iri := id_to_iri (subj);
          --subj_recod := replace (subj_iri, '"', '%22');
          --subj_trtd := sprintf ('\n<tr itemscope="itemscope" about="%s" itemid="%s">\n  <td><a href="%s">%V</a> (' || endpoint_fmt || '%s)</td>',
          --  subj_recod, subj_recod, subj_recod, subj_iri, subj_iri,
          --  case when (can_pivot) then DB.DBA.RDF_PIVOT_DESCRIBE_LINK (id_to_iri (subj)) else '' end );
          trtd_ses := string_output ();
          http ('\n<tr itemscope="itemscope" about="', trtd_ses);
          http_escape (subj_iri, 3, trtd_ses, 1, 1);
          http ('" itemid="', trtd_ses);
          http_escape (subj_iri, 3, trtd_ses, 1, 1);
          http ('">\n  <td><a href="', trtd_ses);
          http_escape (subj_iri, 3, trtd_ses, 1, 1);
          http (sprintf ('">%V</a> (' || endpoint_fmt || '%s)</td>', subj_iri, subj_iri,
              case when (can_pivot) then DB.DBA.RDF_PIVOT_DESCRIBE_LINK (id_to_iri (subj)) else '' end ),
            trtd_ses );
          subj_trtd := string_output_string (trtd_ses);
          prev_subj := subj;
        }
      if (prev_pred is null or (pred <> prev_pred))
        {
          declare tdtd_ses any;
          pred_iri := id_to_iri (pred);
          --pred_recod := replace (pred_iri, '"', '%22');
          --pred_tdtd := sprintf ('\n  <td><a href="%s">%s</a> (' || endpoint_fmt || '%s)\n  </td><td',
          --  pred_recod, pred_recod, pred_iri,
          --  case when (can_pivot) then DB.DBA.RDF_PIVOT_DESCRIBE_LINK (id_to_iri (pred)) else '' end );
          tdtd_ses := string_output ();
          http ('\n  <td><a href="', tdtd_ses);
          http_escape (pred_iri, 3, tdtd_ses, 1, 1);
          http ('">', tdtd_ses);
          http_escape (pred_iri, 1, tdtd_ses, 1, 1);
          http (sprintf ('</a> (' || endpoint_fmt || '%s)\n  </td><td', pred_iri,
              case when (can_pivot) then DB.DBA.RDF_PIVOT_DESCRIBE_LINK (id_to_iri (pred)) else '' end ),
            tdtd_ses );
          pred_tdtd := string_output_string (tdtd_ses);
          prev_pred := pred;
        }
      if (obj is null)
        signal ('RDFXX', 'DB.DBA.TRIPLES_TO_HTML_TR: object is NULL');
      http (subj_trtd, ses);
      http (pred_tdtd, ses);
      if (isiri_id (obj))
        {
          declare obj_iri varchar;
          obj_iri := id_to_iri (obj);
          http ('><a rel="', ses);
          http_escape (pred_iri, 3, ses, 1, 1);
          http ('" resource="', ses);
          http_escape (obj_iri, 3, ses, 1, 1);
          http ('" itemprop="', ses);
          http_escape (pred_iri, 3, ses, 1, 1);
          http ('" href="', ses);
          http_escape (obj_iri, 3, ses, 1, 1);
          http (sprintf ('">%V</a> (' || endpoint_fmt, obj_iri, obj_iri), ses);
          if (can_pivot)
            http (DB.DBA.RDF_PIVOT_DESCRIBE_LINK (obj_iri), ses);
          http (')</td></tr>', ses);
        }
      else
        {
          declare sqlval any;
          declare dt, lang, strval any;
          http (' property="', ses);
          http_escape (pred_iri, 3, ses, 1, 1);
          http ('" itemprop="', ses);
          http_escape (pred_iri, 3, ses, 1, 1);
          dt := 0; lang := 0;
          if (__tag of rdf_box = __tag (obj))
            {
              if (257 <> rdf_box_lang (obj))
                lang := coalesce ((select lower (RL_ID) from DB.DBA.RDF_LANGUAGE where RL_TWOBYTE = rdf_box_lang (obj)));
              else if (257 <> rdf_box_type (obj))
                dt := coalesce ((select __bft (RDT_QNAME, 1) from DB.DBA.RDF_DATATYPE where RDT_TWOBYTE = rdf_box_type (obj)));
              sqlval := __rdf_sqlval_of_obj (obj, 1);
              if (__tag of datetime = __tag (sqlval))
                {
                  if (257 = rdf_box_type (obj))
                    dt := __xsd_type (sqlval);
                }
            }
          else if (__tag (obj) not in (__tag of varchar, __tag of varbinary))
            {
              sqlval := obj;
              dt := __xsd_type (sqlval);
            }
          else
            sqlval := obj;
          if (not (isinteger (dt)))
            {
              http ('" datatype="', ses);
              http_escape (dt, 3, ses, 1, 1);
            }
          if (isstring (lang))
            {
              http ('" xml:lang="', ses);
              http_escape (lang, 3, ses, 1, 1);
            }
          http ('">', ses);
          if (__tag of datetime = __tag(sqlval))
            __rdf_long_to_ttl (sqlval, ses);
          else if (__tag (sqlval) in (__tag of varbinary, __tag of XML))
            http_value (sqlval, 0, ses);
          else if (__tag of varchar = __tag (sqlval))
            http_value (charset_recode (sqlval, 'UTF-8', '_WIDE_'), 0, ses);
          else
            {
              sqlval := __rdf_strsqlval (obj);
              if (__tag of varchar = __tag (sqlval))
                sqlval := charset_recode (sqlval, 'UTF-8', '_WIDE_');
              http_value (sqlval, 0, ses);
            }
          http ('</td></tr>', ses);
        }
    }
  http ('\n</table></body></html>\n', ses);
}
;


create procedure DB.DBA.RDF_TRIPLES_TO_HTML_MICRODATA (inout triples any, inout ses any)
{
  declare env, prev_subj, prev_pred, nsdict, nslist any;
  declare ctr, len, tcount, tctr, status, obj_needs_br integer;
  tcount := length (triples);
  -- dbg_obj_princ ('DB.DBA.RDF_TRIPLES_TO_HTML_MICRODATA:'); for (tctr := 0; tctr < tcount; tctr := tctr + 1) -- dbg_obj_princ (triples[tctr]);
  -- http ('<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE html>\n', ses);
  if (0 = tcount)
    {
      http ('<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>Empty HTML Microdata document</title></head><body>
<p>This document is empty and basically useless. It is generated by a web service that can make some statements in HTML Microdata format.
This time the service made zero such statements, sorry.</p></body></html>', ses);
      return;
    }
  nsdict := dict_new (10 + cast (sqrt(tcount) as integer));
  dict_put (nsdict, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#', 'rdf');
  dict_put (nsdict, 'http://www.w3.org/2001/XMLSchema#', 'xsdh');
  DB.DBA.RDF_TRIPLES_BATCH_COMPLETE (triples);
  for (tctr := 0; (tctr < tcount) and (1000 > dict_size (nsdict)); tctr := tctr + 1)
    {
      sparql_iri_split_rdfa_qname (triples[tctr][0], nsdict, 1);
      sparql_iri_split_rdfa_qname (triples[tctr][1], nsdict, 1);
      sparql_iri_split_rdfa_qname (triples[tctr][2], nsdict, 1);
    }
  http ('<html xmlns="http://www.w3.org/1999/xhtml"', ses);
  http ('>\n<head><title>HTML Microdata document</title></head><body>\n', ses);
  http (sprintf ('<p>This HTML5 document contains %d embedded RDF statements represented using HTML+Microdata notation.</p>',
    tcount), ses);
  http ('<p>The embedded RDF content will be recognized by any processor of HTML5 Microdata.</p>', ses);
  http ('\n<table><tr><th>Prefix</th><th>Namespace IRI</th></tr>', ses);
  nslist := dict_to_vector (nsdict, 0);
  len := length (nslist);
  for (ctr := len - 2; ctr >= 0; ctr := ctr-2)
    {
      http (sprintf ('\n<tr><td>%V</td><td>%V</td></tr>', nslist[ctr+1], nslist[ctr]), ses);
    }
  http ('</table>', ses);
  env := vector (0, 0, 0, null);
  rowvector_subj_sort (triples, 1, 1);
  rowvector_subj_sort (triples, 0, 1);
  prev_subj := prev_pred := null;
  obj_needs_br := 0;
  for (tctr := 0; tctr < tcount; tctr := tctr + 1)
    {
      declare subj, pred, obj, split, obj_iri_split any;
      declare pred_tagname varchar;
      declare res varchar;
      subj := triples[tctr][0];
      pred := triples[tctr][1];
      obj := triples[tctr][2];
      if (isstring (subj))
	subj := iri_to_id (subj);
      if (isstring (pred))
	pred := iri_to_id (pred);
      if (isstring (obj) and __box_flags (obj) = 1)
	obj := iri_to_id (obj);
      -- dbg_obj_princ ('DB.DBA.RDF_TRIPLES_TO_HTML_MICRODATA: subj:', subj, __tag(subj), __box_flags (subj));
      -- dbg_obj_princ ('DB.DBA.RDF_TRIPLES_TO_HTML_MICRODATA: pred:', pred, __tag(pred), __box_flags (pred));
      -- dbg_obj_princ ('DB.DBA.RDF_TRIPLES_TO_HTML_MICRODATA: obj:', obj, __tag(obj), __box_flags (obj));
      if (prev_subj is null or (subj <> prev_subj))
        {
          if (prev_subj is not null)
            http ('\n</dd></dl>', ses);
          http (sprintf ('\n<dl itemscope itemid="%s">', replace (id_to_iri (subj), '"', '%22')), ses);
          split := sparql_iri_split_rdfa_qname (subj, nsdict, 2);
          -- dbg_obj_princ ('Split of ', subj, ' is ', split);
          if ('' = split[1])
            http (sprintf ('\n<dt>Subject Item</dt><dd>%V</dd>', split[2]), ses);
          else if (isstring (split[0]))
            http (sprintf ('\n<dt>Subject Item</dt><dd>%V:%V</dd>', split[0], split[2]), ses);
          else
            http (sprintf ('\n<dt>Subject Item</dt><dd>%V%V</dd>', split[1], split[2]), ses);
          prev_subj := subj;
          prev_pred := null;
        }
      if (prev_pred is null or (pred <> prev_pred))
        {
          if (prev_pred is not null)
            http ('\n</dd>', ses);
          split := sparql_iri_split_rdfa_qname (pred, nsdict, 2);
          -- dbg_obj_princ ('Split of ', pred, ' is ', split);
          if ('' = split[1])
            http (sprintf ('\n<dt>%V</dt><dd>', split[2]), ses);
          else if (isstring (split[0]))
            http (sprintf ('\n<dt>%V:%V</dt><dd>', split[0], split[2]), ses);
          else
            http (sprintf ('\n<dt>%V%V</dt><dd>', split[1], split[2]), ses);
          prev_pred := pred;
          obj_needs_br := 0;
        }
      if (obj is null)
        signal ('RDFXX', 'DB.DBA.TRIPLES_TO_HTML_MICRODATA: object is NULL');
      if (obj_needs_br)
        http ('\n', ses);
      else
        obj_needs_br := 1;
      obj_iri_split := sparql_iri_split_rdfa_qname (obj, nsdict, 2);
      if (isvector (obj_iri_split))
        {
          http (sprintf ('\n<a itemprop="%s" href="%s">', replace (id_to_iri (pred), '"', '%22'), replace (id_to_iri (obj), '"', '%22')), ses);
          if ('' = obj_iri_split[1])
            http (sprintf ('%V</a>', obj_iri_split[2]), ses);
          else if (isstring (obj_iri_split[0]))
            http (sprintf ('%V:%V</a>', obj_iri_split[0], obj_iri_split[2]), ses);
          else
            http (sprintf ('%V%V</a>', obj_iri_split[1], obj_iri_split[2]), ses);
        }
      else
        {
          declare sqlval any;
          declare dt, lang, strval any;
          http (sprintf ('\n<span itemprop="%s"', replace (id_to_iri (pred), '"', '%22')), ses);
          dt := 0; lang := 0;
          if (__tag of rdf_box = __tag (obj))
            {
              if (257 <> rdf_box_lang (obj))
                lang := coalesce ((select lower (RL_ID) from DB.DBA.RDF_LANGUAGE where RL_TWOBYTE = rdf_box_lang (obj)));
--DT          else if (257 <> rdf_box_type (obj))
--DT            dt := coalesce ((select __bft (RDT_QNAME, 1) from DB.DBA.RDF_DATATYPE where RDT_TWOBYTE = rdf_box_type (obj)));
              sqlval := __rdf_sqlval_of_obj (obj, 1);
--DT          if (__tag of datetime = __tag (sqlval))
--DT            {
--DT              if (257 = rdf_box_type (obj))
--DT                dt := __xsd_type (sqlval);
--DT            }
            }
          else if (__tag (obj) not in (__tag of varchar, __tag of varbinary))
            {
              sqlval := obj;
--DT          dt := __xsd_type (sqlval);
            }
          else
            sqlval := obj;
--DT      if (not (isinteger (dt)))
--DT        {
--DT          http (' datatype="', ses);
--DT          split := sparql_iri_split_rdfa_qname (dt, nsdict, 2);
--DT          if ('' = split[1])
--DT            {
--DT              http_escape (split[2], 3, ses, 1, 1);
--DT              http ('"', ses);
--DT            }
--DT          else if (isstring (split[0]))
--DT            {
--DT              http_escape (concat (split[0], ':', split[2]), 3, ses, 1, 1);
--DT              http ('"', ses);
--DT            }
--DT          else
--DT            {
--DT              http_escape (concat ('dt:', split[2]), 3, ses, 1, 1);
--DT              http ('" xmlns:dt="', ses);
--DT              http_escape (split[1], 3, ses, 1, 1);
--DT              http ('"', ses);
--DT            }
--DT        }
          if (isstring (lang))
            {
              http (' xml:lang="', ses);
              http_escape (lang, 3, ses, 1, 1);
              http ('"', ses);
            }
          http ('>', ses);
          if (__tag of datetime = __tag(sqlval))
            __rdf_long_to_ttl (sqlval, ses);
          else if (__tag (sqlval) in (__tag of varbinary, __tag of XML))
            http_value (sqlval, 0, ses);
          else if (__tag of varchar = __tag (sqlval))
            http_value (charset_recode (sqlval, 'UTF-8', '_WIDE_'), 0, ses);
          else
            {
              sqlval := __rdf_strsqlval (obj);
              if (__tag of varchar = __tag (sqlval))
                sqlval := charset_recode (sqlval, 'UTF-8', '_WIDE_');
              http_value (sqlval, 0, ses);
            }
          http ('</span>', ses);
        }
    }
  if (prev_subj is not null)
    http ('\n</dd></dl>', ses);
  http ('\n</body></html>\n', ses);
}
;

create procedure DB.DBA.RDF_TRIPLES_TO_HTML_NICE_MICRODATA (inout triples any, inout ses any)
{
  declare env, prev_subj, prev_pred, nsdict, nslist any;
  declare subj_text, s_itemid, p_itemprop, nice_host, describe_path, about_path varchar;
  declare ctr, len, tcount, tctr, status, obj_needs_br integer;
  tcount := length (triples);
  -- dbg_obj_princ ('DB.DBA.RDF_TRIPLES_TO_HTML_NICE_MICRODATA:'); for (tctr := 0; tctr < tcount; tctr := tctr + 1) -- dbg_obj_princ (triples[tctr]);
  -- http ('<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE html>\n', ses);
  if (0 = tcount)
    {
      http ('<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>Empty HTML Microdata document</title></head><body>
<p>This document is empty and basically useless. It is generated by a web service that can make some statements in HTML Microdata format.
This time the service made zero such statements, sorry.</p></body></html>', ses);
      return;
    }
  nice_host := registry_get ('URIQADefaultHost');
  describe_path := about_path := null;
  if (isstring (nice_host))
    {
      if (exists (select 1 from VAD.DBA.VAD_REGISTRY where R_KEY like '/VAD/fct/%/resources/dav/%'))
        describe_path := 'http://' || nice_host || '/describe/?url=';
      if (exists (select 1 from VAD.DBA.VAD_REGISTRY where R_KEY like '/VAD/cartridges/%/resources/dav/%'))
        about_path := 'http://' || nice_host || '/about/html/';
    }
  nsdict := dict_new (10 + cast (sqrt(tcount) as integer));
  dict_put (nsdict, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#', 'rdf');
  dict_put (nsdict, 'http://www.w3.org/2001/XMLSchema#', 'xsdh');
  DB.DBA.RDF_TRIPLES_BATCH_COMPLETE (triples);
  for (tctr := 0; (tctr < tcount) and (1000 > dict_size (nsdict)); tctr := tctr + 1)
    {
      sparql_iri_split_rdfa_qname (triples[tctr][0], nsdict, 1);
      sparql_iri_split_rdfa_qname (triples[tctr][1], nsdict, 1);
      sparql_iri_split_rdfa_qname (triples[tctr][2], nsdict, 1);
    }
  http ('<html xmlns="http://www.w3.org/1999/xhtml"', ses);
  http ('>\n<head><title>HTML Based Entity Description (with embedded Microdata)</title></head><body>\n', ses);
  http (sprintf ('<p>This HTML5 document contains %d embedded RDF statements represented using HTML+Microdata notation.</p>',
    tcount), ses);
  http ('<p>The embedded RDF content will be recognized by any processor of HTML5 Microdata.</p>', ses);

  -- http ('\n<table><tr><th>Prefix</th><th>Namespace IRI</th></tr>', ses);
  -- nslist := dict_to_vector (nsdict, 0);
  -- len := length (nslist);
  -- for (ctr := len - 2; ctr >= 0; ctr := ctr-2)
  --   {
  --     http (sprintf ('\n<tr><td>%V</td><td>%V</td></tr>', nslist[ctr+1], nslist[ctr]), ses);
  --   }
  -- http ('</table>', ses);
  env := vector (0, 0, 0, null);
  rowvector_subj_sort (triples, 1, 1);
  rowvector_subj_sort (triples, 0, 1);
  prev_subj := prev_pred := null;
  obj_needs_br := 0;
  http ('\n<table border=1><tr><th>Subject</th><th>Predicate</th><th>Object</th></tr>', ses);
  for (tctr := 0; tctr < tcount; tctr := tctr + 1)
    {
      declare subj, pred, obj, split, o_split any;
      declare pred_tagname varchar;
      declare res varchar;
      subj := triples[tctr][0];
      pred := triples[tctr][1];
      obj := triples[tctr][2];
      if (isstring (subj))
        subj := iri_to_id (subj);
      if (isstring (pred))
        pred := iri_to_id (pred);
      if (isstring (obj) and __box_flags (obj) = 1)
        obj := iri_to_id (obj);
      -- dbg_obj_princ ('DB.DBA.RDF_TRIPLES_TO_HTML_NICE_MICRODATA: subj:', subj, __tag(subj), __box_flags (subj));
      -- dbg_obj_princ ('DB.DBA.RDF_TRIPLES_TO_HTML_NICE_MICRODATA: pred:', pred, __tag(pred), __box_flags (pred));
      -- dbg_obj_princ ('DB.DBA.RDF_TRIPLES_TO_HTML_NICE_MICRODATA: obj:', obj, __tag(obj), __box_flags (obj));
      if (prev_subj is null or (subj <> prev_subj))
        {
          if (prev_subj is not null)
            http ('\n</td></tr>', ses);
          split := sparql_iri_split_rdfa_qname (subj, nsdict, 2);
          s_itemid := replace (id_to_iri (subj), '"', '%22');
          -- dbg_obj_princ ('Split of ', subj, ' is ', split);
          if (about_path is null)
            {
              if ('' = split[1])		subj_text := sprintf ('\n<td><a href="%s">%V</a></td>'		, s_itemid, split[2]);
              else if (isstring (split[0]))	subj_text := sprintf ('\n<td><a href="%s">%V:%V</a></td>'	, s_itemid, split[0], split[2]);
              else				subj_text := sprintf ('\n<td><a href="%s">%V%V</a></td>'	, s_itemid, split[1], split[2]);
            }
          else
            {
              if ('' = split[1])		subj_text := sprintf ('\n<td><a href="%s">%V</a>    (<a href="%s%s">/about</a>)</td>'	, s_itemid, split[2]		, about_path, s_itemid);
              else if (isstring (split[0]))	subj_text := sprintf ('\n<td><a href="%s">%V:%V</a> (<a href="%s%s">/about</a>)</td>'	, s_itemid, split[0], split[2]	, about_path, s_itemid);
              else				subj_text := sprintf ('\n<td><a href="%s">%V%V</a>  (<a href="%s%s">/about</a>)</td>'	, s_itemid, split[1], split[2]	, about_path, s_itemid);
            }
          prev_subj := subj;
          prev_pred := null;
        }
      if (prev_pred is null or (pred <> prev_pred))
        {
          if (prev_pred is not null)
            http ('\n</td></tr>', ses);
          http ('\n<tr>', ses);
          http (subj_text, ses);
          split := sparql_iri_split_rdfa_qname (pred, nsdict, 2);
          p_itemprop := replace (id_to_iri (pred), '"', '%22');
          -- dbg_obj_princ ('Split of ', pred, ' is ', split);
          if ('' = split[1])		http (sprintf ('\n<td><a href="%s">%V</a>'	, p_itemprop, split[2])			, ses);
          else if (isstring (split[0]))	http (sprintf ('\n<td><a href="%s">%V:%V</a>'	, p_itemprop, split[0], split[2])	, ses);
          else				http (sprintf ('\n<td><a href="%s">%V%V</a>'	, p_itemprop, split[1], split[2])	, ses);
          if (describe_path is not null)
            http (sprintf (' (<a href="%s%U">/describe</a>)</td>'	, describe_path, id_to_iri (pred)), ses);
          http (sprintf ('</td>\n<td itemscope itemid="%s">', s_itemid), ses);
          prev_pred := pred;
          obj_needs_br := 0;
        }
      if (obj is null)
        signal ('RDFXX', 'DB.DBA.TRIPLES_TO_HTML_NICE_MICRODATA: object is NULL');
      if (obj_needs_br)
        http (' ,', ses);
      else
        obj_needs_br := 1;
      o_split := sparql_iri_split_rdfa_qname (obj, nsdict, 2);
      if (isvector (o_split))
        {
          declare o_href varchar;
          o_href := replace (id_to_iri (obj), '"', '%22');
          if ('' = o_split[1])			http (sprintf ('\n<a itemprop="%V" href="%s">%V</a>'	, p_itemprop, o_href, o_split[2])		, ses);
          else if (isstring (o_split[0]))	http (sprintf ('\n<a itemprop="%V" href="%s">%V:%V</a>'	, p_itemprop, o_href, o_split[0], o_split[2])	, ses);
          else					http (sprintf ('\n<a itemprop="%V" href="%s">%V%V</a>'	, p_itemprop, o_href, o_split[1], o_split[2])	, ses);
          if (about_path is not null)
            http (sprintf ('\n(<a href="%s%s">/about</a>)', about_path, o_href), ses);
        }
      else
        {
          declare sqlval any;
          declare dt, lang, strval any;
          http (sprintf ('\n<span itemprop="%s"', replace (id_to_iri (pred), '"', '%22')), ses);
          dt := 0; lang := 0;
          if (__tag of rdf_box = __tag (obj))
            {
              if (257 <> rdf_box_lang (obj))
                lang := coalesce ((select lower (RL_ID) from DB.DBA.RDF_LANGUAGE where RL_TWOBYTE = rdf_box_lang (obj)));
--DT          else if (257 <> rdf_box_type (obj))
--DT            dt := coalesce ((select __bft (RDT_QNAME, 1) from DB.DBA.RDF_DATATYPE where RDT_TWOBYTE = rdf_box_type (obj)));
              sqlval := __rdf_sqlval_of_obj (obj, 1);
--DT          if (__tag of datetime = __tag (sqlval))
--DT            {
--DT              if (257 = rdf_box_type (obj))
--DT                dt := __xsd_type (sqlval);
--DT            }
            }
          else if (__tag (obj) not in (__tag of varchar, __tag of varbinary))
            {
              sqlval := obj;
--DT          dt := __xsd_type (sqlval);
            }
          else
            sqlval := obj;
--DT      if (not (isinteger (dt)))
--DT        {
--DT          http (' datatype="', ses);
--DT          split := sparql_iri_split_rdfa_qname (dt, nsdict, 2);
--DT          if ('' = split[1])
--DT            {
--DT              http_escape (split[2], 3, ses, 1, 1);
--DT              http ('"', ses);
--DT            }
--DT          else if (isstring (split[0]))
--DT            {
--DT              http_escape (concat (split[0], ':', split[2]), 3, ses, 1, 1);
--DT              http ('"', ses);
--DT            }
--DT          else
--DT            {
--DT              http_escape (concat ('dt:', split[2]), 3, ses, 1, 1);
--DT              http ('" xmlns:dt="', ses);
--DT              http_escape (split[1], 3, ses, 1, 1);
--DT              http ('"', ses);
--DT            }
--DT        }
          if (isstring (lang))
            {
              http (' xml:lang="', ses);
              http_escape (lang, 3, ses, 1, 1);
              http ('"', ses);
            }
          http ('>', ses);
          if (__tag of datetime = __tag(sqlval))
            __rdf_long_to_ttl (sqlval, ses);
          else if (__tag (sqlval) in (__tag of varbinary, __tag of XML))
            http_value (sqlval, 0, ses);
          else if (__tag of varchar = __tag (sqlval))
            http_value (charset_recode (sqlval, 'UTF-8', '_WIDE_'), 0, ses);
          else
            {
              sqlval := __rdf_strsqlval (obj);
              if (__tag of varchar = __tag (sqlval))
                sqlval := charset_recode (sqlval, 'UTF-8', '_WIDE_');
              http_value (sqlval, 0, ses);
            }
          http ('</span>', ses);
        }
    }
  if (prev_subj is not null)
    http ('\n</td></tr></table>', ses);
  http ('\n</body></html>\n', ses);
}
;

create procedure DB.DBA.RDF_TRIPLES_TO_JSON_MICRODATA (inout triples any, inout ses any)
{
  declare env, prev_subj, prev_pred any;
  declare ctr, len, tcount, tctr, status, obj_needs_comma integer;
  tcount := length (triples);
  -- dbg_obj_princ ('DB.DBA.RDF_TRIPLES_TO_JSON_MICRODATA:'); for (tctr := 0; tctr < tcount; tctr := tctr + 1) -- dbg_obj_princ (triples[tctr]);
  http ('{ "items" : [', ses);
  env := vector (0, 0, 0, null);
  rowvector_subj_sort (triples, 1, 1);
  rowvector_subj_sort (triples, 0, 1);
  DB.DBA.RDF_TRIPLES_BATCH_COMPLETE (triples);
  prev_subj := prev_pred := null;
  obj_needs_comma := 0;
  for (tctr := 0; tctr < tcount; tctr := tctr + 1)
    {
      declare subj, pred, obj, split, obj_iri_split any;
      declare pred_tagname varchar;
      declare res varchar;
      subj := triples[tctr][0];
      pred := triples[tctr][1];
      obj := triples[tctr][2];
      -- dbg_obj_princ ('DB.DBA.RDF_TRIPLES_TO_JSON_MICRODATA: subj:', subj, __tag(subj), __box_flags (subj));
      -- dbg_obj_princ ('DB.DBA.RDF_TRIPLES_TO_JSON_MICRODATA: pred:', pred, __tag(pred), __box_flags (pred));
      -- dbg_obj_princ ('DB.DBA.RDF_TRIPLES_TO_JSON_MICRODATA: obj:', obj, __tag(obj), __box_flags (obj));
      if (prev_subj is null or (subj <> prev_subj))
        {
          declare subj_iri varchar;
          if (prev_subj is not null)
            http (' ] } },\n', ses);
	  if (isstring (subj))
	    subj_iri := subj;
	  else
          subj_iri := id_to_iri (subj);
          if (starts_with (subj_iri, 'nodeID://'))
            subj_iri := '_:' || subseq (subj_iri, 9);
          http ('\n    { "id" : "', ses); http_escape (subj_iri, 14, ses, 1, 1); http ('"\n      "properties" : {', ses);
          prev_subj := subj;
          prev_pred := null;
        }
      if (prev_pred is null or (pred <> prev_pred))
        {
          if (prev_pred is not null)
            http (' ] ,', ses);
          http ('\n        "', ses); http_escape (case when isstring (pred) then pred else id_to_iri (pred) end, 14, ses, 1, 1); http ('" : [ ', ses);
          prev_pred := pred;
          obj_needs_comma := 0;
        }
      if (obj is null)
        signal ('RDFXX', 'DB.DBA.TRIPLES_TO_JSON_MICRODATA: object is NULL');
      if (obj_needs_comma)
        http (',\n          ', ses);
      else
        obj_needs_comma := 1;
      if (isiri_id (obj))
        {
          declare obj_iri varchar;
          obj_iri := id_to_iri (obj);
          if (starts_with (obj_iri, 'nodeID://'))
            obj_iri := '_:' || subseq (obj_iri, 9);
          http ('{ "id" : "', ses); http_escape (obj_iri, 14, ses, 1, 1); http ('" }', ses);
        }
      else
        {
          declare sqlval any;
          declare dt, lang, strval any;
          dt := 0; lang := 0;
          if (__tag of rdf_box = __tag (obj))
            {
              if (257 <> rdf_box_lang (obj))
                lang := coalesce ((select lower (RL_ID) from DB.DBA.RDF_LANGUAGE where RL_TWOBYTE = rdf_box_lang (obj)));
--DT          else if (257 <> rdf_box_type (obj))
--DT            dt := coalesce ((select __bft (RDT_QNAME, 1) from DB.DBA.RDF_DATATYPE where RDT_TWOBYTE = rdf_box_type (obj)));
              sqlval := __rdf_sqlval_of_obj (obj, 1);
--DT          if (__tag of datetime = __tag (sqlval))
--DT            {
--DT              if (257 = rdf_box_type (obj))
--DT                dt := __xsd_type (sqlval);
--DT            }
            }
          else if (__tag (obj) not in (__tag of varchar, __tag of varbinary))
            {
              sqlval := obj;
--DT          dt := __xsd_type (sqlval);
            }
          else
            sqlval := obj;
--DT      if (not (isinteger (dt)))
--DT        {
--DT          http (' datatype="', ses);
--DT          split := sparql_iri_split_rdfa_qname (dt, nsdict, 2);
--DT          if ('' = split[1])
--DT            {
--DT              http_escape (split[2], 3, ses, 1, 1);
--DT              http ('"', ses);
--DT            }
--DT          else if (isstring (split[0]))
--DT            {
--DT              http_escape (concat (split[0], ':', split[2]), 3, ses, 1, 1);
--DT              http ('"', ses);
--DT            }
--DT          else
--DT            {
--DT              http_escape (concat ('dt:', split[2]), 3, ses, 1, 1);
--DT              http ('" xmlns:dt="', ses);
--DT              http_escape (split[1], 3, ses, 1, 1);
--DT              http ('"', ses);
--DT            }
--DT        }
--DT      if (isstring (lang))
--DT        {
--DT          http (' xml:lang="', ses);
--DT          http_escape (lang, 3, ses, 1, 1);
--DT          http ('"', ses);
--DT        }
--DT      http ('>', ses);
          if (__tag (sqlval) in (__tag of integer, __tag of real, __tag of double precision, __tag of decimal))
            http_value (sqlval, 0, ses);
          else if (__tag (sqlval) in (__tag of varbinary, __tag of XML))
            {
              declare tmpses any;
              tmpses := string_output();
              http_value (sqlval, 0, tmpses);
              http ('"', ses); http_escape (string_output_string (tmpses), 14, ses, 1, 1); http ('"', ses);
            }
          else if (__tag of varchar = __tag (sqlval))
            {
              http ('"', ses); http_escape (sqlval, 14, ses, 1, 1); http ('"', ses);
            }
          else
            {
              sqlval := __rdf_strsqlval (obj);
              http ('"', ses); http_escape (sqlval, 14, ses, 1, 1); http ('"', ses);
            }
        }
    }
  if (prev_subj is not null)
    http ('] } }', ses);
  http (' }\n', ses);
}
;

-- /* OData ATOM format */
create function DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_ATOM_XML (inout triples_dict any) returns long varchar
{
  declare triples, ses any;
  ses := string_output ();
  if (214 <> __tag (triples_dict))
    {
      triples := vector ();
    }
  else
    triples := dict_list_keys (triples_dict, 1);
  DB.DBA.RDF_TRIPLES_TO_ATOM_XML_TEXT (triples, 1, ses);
  return ses;
}
;

create procedure DB.DBA.ODATA_EDM_TYPE (in obj any)
{
  if (__tag of int = __tag (obj))
    return 'Int32';
  else if (__tag of smallint  = __tag (obj))
    return 'Int16';
  else if (__tag of bigint = __tag (obj))
    return 'Int64';
  else if (__tag of numeric = __tag (obj))
    return 'Decimal';
  else if (__tag of double precision = __tag (obj))
    return 'Double';
  else if (__tag of real = __tag (obj))
    return 'Double';
  else if (__tag of datetime = __tag (obj))
    return 'DateTime';
  else if (__tag of date = __tag (obj))
    return 'Date';
  else if (__tag of time = __tag (obj))
    return 'Time';
  else if (__tag of varbinary = __tag (obj))
    return 'Binary';
  return null;
}
;

create function DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_ODATA_JSON (inout triples_dict any) returns long varchar
{
  declare triples, ses any;
  ses := string_output ();
  if (214 <> __tag (triples_dict))
    {
      triples := vector ();
    }
  else
    triples := dict_list_keys (triples_dict, 1);
  DB.DBA.RDF_TRIPLES_TO_ODATA_JSON (triples, ses);
  return ses;
}
;

create procedure DB.DBA.RDF_TRIPLES_TO_ODATA_JSON (inout triples any, inout ses any)
{
  declare tcount, tctr, ns_ctr integer;
  declare dict, entries any;
  declare subj, pred, obj any;
  declare entry_dict, ns_dict, ns_arr any;
  declare pred_tagname varchar;
  declare p_ns_uri, p_ns_pref varchar;

  dict := dict_new ();
  ns_dict := dict_new ();
  ns_ctr := 0;
  tcount := length (triples);
  DB.DBA.RDF_TRIPLES_BATCH_COMPLETE (triples);
  http ('{ "d" : { \n  "results": [ \n', ses);
  for (tctr := 0; tctr < tcount; tctr := tctr + 1)
    {
      subj := triples[tctr][0];
      pred := triples[tctr][1];
      obj := triples[tctr][2];
      entry_dict := dict_get (dict, subj);
      if (entry_dict is null)
	{
	  entry_dict := dict_new ();
	  dict_put (dict, subj, entry_dict);
	}
      dict_put (entry_dict, vector (pred, obj), 1);
    }
  entries := dict_list_keys (dict, 0);
  tcount := length (entries);
  for (tctr := 0; tctr < tcount; tctr := tctr + 1)
    {
      declare meta any;
      declare has_meta, mcount int;
      declare title, content varchar;

      has_meta := 0; title := null; content := null;
      subj := entries[tctr];
      entry_dict := dict_get (dict, subj);
      meta := dict_list_keys (entry_dict, 1);

      if (isiri_id (subj)) subj := id_to_iri (subj);
      http ('    { ', ses);
      http (sprintf ('"__metadata": { "uri": "%s" }, \n', subj), ses);
      for (declare i, l int, i := 0, l := length (meta); i < l; i := i + 1)
        {
	  pred := meta[i][0];
	  obj := meta[i][1];
	  if (isiri_id (pred)) pred := id_to_iri (pred);
	  if (isiri_id (obj) or (isstring (obj) and __box_flags (obj) = 1))
	    {
	      -- links
	      if (isiri_id (obj)) obj := id_to_iri (obj);
	      http (sprintf ('      "%s": { "__deferred": { "uri": "%s" } }', pred, obj), ses);
	    }
	  else
	    {
	      -- data
	      declare tmp any;
	      http (sprintf ('      "%s": ', pred), ses);
	      if (__tag of rdf_box = __tag (obj))
		{
		  tmp := __rdf_strsqlval (obj);
		  if (__tag of varchar = __tag (tmp))
		    tmp := charset_recode (tmp, 'UTF-8', '_WIDE_');
		}
	      else
		{
		  tmp := obj;
		}
	      http ('"', ses);
	      http_value (tmp, 0, ses);
	      http ('"', ses);
	    }
	  if (i < l - 1)
  	    http (', \n', ses);
	}
      http ('\n     } ', ses);
      if (tctr < tcount - 1)
	http (', ', ses);
    }
  http (sprintf ('\n ], "__count": "%d"\n } }', tcount), ses);
}
;

create procedure DB.DBA.RDF_TRIPLES_TO_ATOM_XML_TEXT (inout triples any, in print_top_level integer, inout ses any)
{
  declare tcount, tctr, ns_ctr integer;
  declare dict, entries any;
  declare subj, pred, obj any;
  declare entry_dict, ns_dict, ns_arr any;
  declare pred_tagname varchar;
  declare p_ns_uri, p_ns_pref, lang, range varchar;
  declare pct integer;
  declare twobyte integer;

  dict := dict_new ();
  ns_dict := dict_new ();
  ns_ctr := 0; pct := 0;
  tcount := length (triples);
  DB.DBA.RDF_TRIPLES_BATCH_COMPLETE (triples);
  if (print_top_level)
    {
       http ('<?xml version="1.0" encoding="utf-8" ?>\n<feed \n\t xmlns="http://www.w3.org/2005/Atom" \n'||
      			'\t xmlns:d="http://schemas.microsoft.com/ado/2007/08/dataservices" \n'||
			'\t xmlns:m="http://schemas.microsoft.com/ado/2007/08/dataservices/metadata" \n', ses);
    }
  for (tctr := 0; tctr < tcount; tctr := tctr + 1)
    {
      subj := triples[tctr][0];
      pred := triples[tctr][1];
      obj := triples[tctr][2];
      entry_dict := dict_get (dict, subj);
      if (entry_dict is null)
	{
	  entry_dict := dict_new ();
	  dict_put (dict, subj, entry_dict);
	}
      dict_put (entry_dict, vector (pred, obj), 1);

      if (isiri_id (obj) or (isstring (obj) and __box_flags (obj) = 1))
	goto next;
      if (isiri_id (pred)) pred := id_to_iri (pred);

      p_ns_uri := iri_split (pred, pred_tagname);
      if (length (p_ns_uri) > 0 and dict_get (ns_dict, p_ns_uri) is null)
	{
	  p_ns_pref := __xml_get_ns_prefix (p_ns_uri, 3);
	  if (p_ns_pref is null)
	    {
	      p_ns_pref := sprintf ('ns%dpred', ns_ctr);
	      ns_ctr := ns_ctr + 1;
	    }
	  dict_put (ns_dict, p_ns_uri, p_ns_pref);
	}
      next:;
    }
  ns_arr := dict_to_vector (ns_dict, 0);
  for (declare i int, i := 0; i < length (ns_arr); i := i + 2)
    {
      http (sprintf ('\t xmlns:%s="%s"\n', ns_arr[i+1], ns_arr[i]), ses);
    }
  http ('>\n', ses);
  if (is_http_ctx ())
    {
      declare q, u, h, id varchar;
      declare lines any;
      q := http_request_get ('QUERY_STRING');
      if (length (q))
	q := '?' || q;
      else
        q := '';
      u := http_request_get ('REQUEST_URI');
      h := WS.WS.PARSE_URI (http_requested_url () || q);
      h [2] := u; h [4] := '';
      id := WS.WS.VFS_URI_COMPOSE (h);
      http (sprintf ('\t<id>%V</id>\n', id), ses);
      lines := http_request_header ();
      range := http_request_header_full (lines, 'Accept-Language', 'en');
    }
  else
    {
      http ('\t<id/>\n', ses);
      range := 'en, */*;0.1';
    }
  http (sprintf ('\t<updated>%s</updated>\n', date_iso8601 (dt_set_tz (now (), 0))), ses);
  http ('\t<author><name /></author>\n', ses);
  http (sprintf ('\t<title type="text">OData Service and Descriptor Document</title>\n'), ses);
  entries := dict_list_keys (dict, 0);
  tcount := length (entries);
  for (tctr := 0; tctr < tcount; tctr := tctr + 1)
    {
      declare meta any;
      declare has_meta int;
      declare title, content varchar;

      pct := 0;
      has_meta := 0; title := null; content := null;
      subj := entries[tctr];
      entry_dict := dict_get (dict, subj);
      meta := dict_list_keys (entry_dict, 1);
      http ('\t<entry>\n', ses);
      if (isiri_id (subj)) subj := id_to_iri (subj);
      http (sprintf ('\t\t<id>%s</id>\n', subj), ses);
      --http (sprintf ('\t\t<link rel="self" href="%s"/>\n', subj), ses);
      for (declare i, l int, i := 0, l := length (meta); i < l; i := i + 1)
        {
	  pred := meta[i][0];
	  obj := meta[i][1];
	  if (isiri_id (obj) or (isstring (obj) and __box_flags (obj) = 1))
	    {
	      if (isiri_id (obj)) obj := id_to_iri (obj);
	      if (isiri_id (pred)) pred := id_to_iri (pred);
              --p_ns_uri := iri_split (pred, pred_tagname);
	      --if (length (p_ns_uri) > 0)
	      --{
              --  p_ns_pref := dict_get (ns_dict, p_ns_uri);
	      --  pred_tagname := p_ns_pref || ':' || pred_tagname;
              --}
	      http (sprintf ('\t\t<link rel="%s" href="%s"/>\n', pred, obj), ses);
	    }
	  else
	    {
	      if (title is null and
		(
		 pred = iri_to_id ('http://purl.org/dc/terms/title') or
	      	 pred = iri_to_id ('http://www.w3.org/2000/01/rdf-schema#label'))
		)
		{
		   declare rc int;
		   lang := 'en';
		   if (__tag of rdf_box = __tag (obj))
		     {
		       twobyte := rdf_box_lang (obj);
		       if (twobyte <> 257)
		         {
			   lang := coalesce ((select lower (RL_ID) from DB.DBA.RDF_LANGUAGE where RL_TWOBYTE = twobyte), lang);
			 }
		     }
		   rc := langmatches_pct_http (lang, range);
		   if (pct < rc)
		     {
		       title := __rdf_strsqlval (obj);
		       pct := rc;
		     }
		}
	      has_meta := 1;
	    }
	}
      if (title is not null)
	http (sprintf ('\t\t<title>%s</title>\n', title), ses);
      http (sprintf ('\t\t<updated>%s</updated>\n', date_iso8601 (dt_set_tz (now (), 0))), ses);
      http ('\t\t<author><name /></author>\n', ses);
      if (has_meta)
	http ('\t\t<content type="application/xml">\n\t\t\t<m:properties>\n', ses);
      for (declare i, l int, i := 0, l := length (meta); i < l; i := i + 1)
        {
	  pred := meta[i][0];
	  obj := meta[i][1];
	  if (isiri_id (pred)) pred := id_to_iri (pred);
	  if (not (isiri_id (obj) or (isstring (obj) and __box_flags (obj) = 1)))
	    {

              p_ns_uri := iri_split (pred, pred_tagname);
	      if (length (p_ns_uri) = 0)
		{
		  http ('<', ses); http (pred_tagname, ses);
		}
	      else
		{
		  p_ns_pref := dict_get (ns_dict, p_ns_uri);
		  pred_tagname := p_ns_pref || ':' || pred_tagname;
		  http ('\t\t\t\t<', ses); http (pred_tagname, ses);
		  if (__tag of rdf_box = __tag (obj))
		    {
		      declare tmp any;
		      tmp := __rdf_strsqlval (obj);
		       twobyte := rdf_box_lang (obj);
		       if (twobyte <> 257)
			 {
			   lang := coalesce ((select lower (RL_ID) from DB.DBA.RDF_LANGUAGE where RL_TWOBYTE = twobyte), lang);
			   http (sprintf (' xml:lang="%s"', lang), ses);
			 }
		      http ('>', ses);
		      if (__tag of varchar = __tag (tmp))
			tmp := charset_recode (tmp, 'UTF-8', '_WIDE_');
		      http_value (tmp, 0, ses);
		    }
		  else
		    {
		      declare tp varchar;
		      tp := ODATA_EDM_TYPE (obj);
		      if (tp is not null)
                        http (sprintf (' m:type="Edm.%s"', tp), ses);
		      http ('>', ses);
		      if (__tag of varbinary = __tag (obj))
			obj := encode_base64 (cast (obj as varchar));
		      http_value (obj, 0, ses);
		    }
		  http ('</', ses); http (pred_tagname, ses); http ('>\n', ses);
		}
	    }
	}
      if (has_meta)
	http ('\t\t\t</m:properties>\n\t\t</content>\n', ses);
      http ('\t</entry>\n', ses);
    }
  if (print_top_level)
    {
      http ('</feed>', ses);
    }
}
;



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
order
;


create procedure DB.DBA.RDF_FORMAT_RESULT_SET_AS_NT_INIT (inout _env any)
{
  _env := vector (0, 0, string_output());
  http ('@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rs: <http://www.w3.org/2005/sparql-results#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
_:_ <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2005/sparql-results#results> .\n', _env[2]);
}
;

create procedure DB.DBA.RDF_FORMAT_RESULT_SET_AS_NT_ACC (inout _env any, inout colvalues any, inout colnames any)
{
  declare col_ctr, col_count integer;
  declare rowid varchar;
  declare blank_ids any;
  if (__tag of vector <> __tag(_env))
    DB.DBA.RDF_FORMAT_RESULT_SET_AS_NT_INIT (_env);
  if (isinteger (_env[1]))
    {
      declare col_buf any;
      col_count := length (colnames);
      if (185 <> __tag(_env))
        DB.DBA.RDF_FORMAT_RESULT_SET_AS_NT_INIT (_env);
      col_buf := make_array (col_count * 7, 'any');
      for (col_ctr := 0; col_ctr < col_count; col_ctr := col_ctr + 1)
        col_buf [col_ctr * 7] := colnames[col_ctr];
      _env[1] := col_buf;
    }
  sparql_rset_nt_write_row (0, _env, colvalues);
}
;

create function DB.DBA.RDF_FORMAT_RESULT_SET_AS_NT_FIN (inout _env any) returns long varchar
{
  if (__tag of vector <> __tag(_env))
    DB.DBA.RDF_FORMAT_RESULT_SET_AS_NT_INIT (_env);
  return string_output_string (_env[2]);
}
;

create aggregate DB.DBA.RDF_FORMAT_RESULT_SET_AS_NT (in colvalues any, in colnames any) returns long varchar
from DB.DBA.RDF_FORMAT_RESULT_SET_AS_NT_INIT, DB.DBA.RDF_FORMAT_RESULT_SET_AS_NT_ACC, DB.DBA.RDF_FORMAT_RESULT_SET_AS_NT_FIN
order
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
  -- dbg_obj_princ ('DB.DBA.RDF_FORMAT_RESULT_SET_AS_RDF_XML_ACC (..., ', colvalues, colnames, ')');
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
	      http (sprintf (' rdf:nodeID="b%d"/></rs:binding>', iri_id_num (_val)), _env);
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
	  http_value (__rdf_strsqlval (_val), 0, _env);
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
order
;

create procedure DB.DBA.RDF_FORMAT_RESULT_SET_AS_JSON_INIT (inout _env any)
{
  _env := 0;
}
;

create procedure DB.DBA.RDF_FORMAT_RESULT_SET_AS_JSON_ACC (inout _env any, inout colvalues any, inout colnames any)
{
  declare sol_id varchar;
  declare col_ctr, col_count, need_comma integer;
  declare blank_ids any;
  col_count := length (colnames);
  if (185 <> __tag(_env))
    {
      _env := string_output ();
      http ('\n{ "head": { "link": [], "vars": [', _env);
      for (col_ctr := 0; col_ctr < col_count; col_ctr := col_ctr + 1)
        {
          if (col_ctr > 0)
            http(', "', _env);
          else
            http('"', _env);
          http_escape (colnames[col_ctr], 11, _env, 0, 1);
          http('"', _env);
        }
      http ('] },\n  "results": { "distinct": false, "ordered": true, "bindings": [\n    {', _env);
    }
  else
    http(',\n    {', _env);
  need_comma := 0;
  for (col_ctr := 0; col_ctr < col_count; col_ctr := col_ctr + 1)
    {
      declare val any;
      val := colvalues[col_ctr];
      if (val is null)
        goto end_of_val_print; -- see below
      if (need_comma)
        http('\t,', _env);
      else
        need_comma := 1;
      DB.DBA.SPARQL_RESULTS_JSON_WRITE_BINDING (_env, colnames[col_ctr], val);
end_of_val_print: ;
    }
  http('}', _env);
}
;

create function DB.DBA.RDF_FORMAT_RESULT_SET_AS_JSON_FIN (inout _env any) returns long varchar
{
  if (185 <> __tag(_env))
    {
      _env := string_output ();
      http ('\n{ "head": { "link": [], "vars": [] },\n  "results": { "distinct": false, "ordered": true, "bindings": [', _env);
    }
  http (' ] } }', _env);
  return string_output_string (_env);
}
;

create aggregate DB.DBA.RDF_FORMAT_RESULT_SET_AS_JSON (in colvalues any, in colnames any) returns long varchar
from DB.DBA.RDF_FORMAT_RESULT_SET_AS_JSON_INIT, DB.DBA.RDF_FORMAT_RESULT_SET_AS_JSON_ACC, DB.DBA.RDF_FORMAT_RESULT_SET_AS_JSON_FIN
order
;



create procedure DB.DBA.RDF_FORMAT_RESULT_SET_AS_CSV_INIT (inout _env any)
{
  _env := 0;
}
;

create procedure DB.DBA.SPARQL_RESULTS_CSV_WRITE_VALUE (inout _env any, in val any)
{
  declare t integer;
  t := __tag (val);
  if (t = __tag of rdf_box)
    {
      val := rdf_box_data (val);
      t := __tag (val);
    }
  if (t in (__tag of integer, __tag of numeric, __tag of double precision, __tag of float, __tag of date, __tag of time, __tag of datetime))
    {
      http_value (val, 0, _env);
      return;
    }
  if (t = __tag of IRI_ID)
    val := id_to_iri (val);
  http ('"', _env);
  http (replace (cast (val as varchar), '"', '""'), _env);
  http ('"', _env);
}
;

create procedure DB.DBA.RDF_FORMAT_RESULT_SET_AS_CSV_ACC (inout _env any, inout colvalues any, inout colnames any)
{
  declare sol_id varchar;
  declare col_ctr, col_count integer;
  declare blank_ids any;
  col_count := length (colnames);
  if (185 <> __tag(_env))
    {
      _env := string_output ();
      for (col_ctr := 0; col_ctr < col_count; col_ctr := col_ctr + 1)
        {
          if (col_ctr > 0)
            http(',', _env);
          DB.DBA.SPARQL_RESULTS_CSV_WRITE_VALUE (_env, colnames[col_ctr]);
        }
      http ('\n', _env);
    }
  for (col_ctr := 0; col_ctr < col_count; col_ctr := col_ctr + 1)
    {
      declare val any;
      val := colvalues[col_ctr];
      if (col_ctr > 0)
        http(',', _env);
      if (val is not null)
        DB.DBA.SPARQL_RESULTS_CSV_WRITE_VALUE (_env, val);
    }
  http('\n', _env);
}
;

create function DB.DBA.RDF_FORMAT_RESULT_SET_AS_CSV_FIN (inout _env any) returns long varchar
{
  if (185 <> __tag(_env))
    return '';
  return string_output_string (_env);
}
;

create aggregate DB.DBA.RDF_FORMAT_RESULT_SET_AS_CSV (in colvalues any, in colnames any) returns long varchar
from DB.DBA.RDF_FORMAT_RESULT_SET_AS_CSV_INIT, DB.DBA.RDF_FORMAT_RESULT_SET_AS_CSV_ACC, DB.DBA.RDF_FORMAT_RESULT_SET_AS_CSV_FIN
order
;

create procedure DB.DBA.RDF_FORMAT_RESULT_SET_AS_TSV_ACC (inout _env any, inout colvalues any, inout colnames any)
{
  declare sol_id varchar;
  declare col_ctr, col_count integer;
  declare blank_ids any;
  col_count := length (colnames);
  if (185 <> __tag(_env))
    {
      _env := string_output ();
      for (col_ctr := 0; col_ctr < col_count; col_ctr := col_ctr + 1)
        {
          if (col_ctr > 0)
            http('\t', _env);
          DB.DBA.SPARQL_RESULTS_CSV_WRITE_VALUE (_env, colnames[col_ctr]);
        }
      http ('\n', _env);
    }
  for (col_ctr := 0; col_ctr < col_count; col_ctr := col_ctr + 1)
    {
      declare val any;
      val := colvalues[col_ctr];
      if (col_ctr > 0)
        http('\t', _env);
      if (val is not null)
        DB.DBA.SPARQL_RESULTS_CSV_WRITE_VALUE (_env, val);
    }
  http('\n', _env);
}
;

create aggregate DB.DBA.RDF_FORMAT_RESULT_SET_AS_TSV (in colvalues any, in colnames any) returns long varchar
from DB.DBA.RDF_FORMAT_RESULT_SET_AS_CSV_INIT, DB.DBA.RDF_FORMAT_RESULT_SET_AS_TSV_ACC, DB.DBA.RDF_FORMAT_RESULT_SET_AS_CSV_FIN
order
;

create procedure DB.DBA.RDF_FORMAT_RESULT_SET_AS_CXML_INIT (inout _env any)
{
  _env := 0;
}
;

create procedure DB.DBA.RDF_FORMAT_RESULT_SET_AS_CXML_ACC (inout _env any, inout colvalues any, inout colnames any)
{
  declare agg, colvalues_copy any;
  colvalues_copy := colvalues;
  if (isinteger (_env))
    {
      vectorbld_init (agg);
      _env := vector (0, colnames);
    }
  else
    {
      agg := aref_set_0 (_env, 0);
    }
  vectorbld_acc (agg, colvalues_copy);
  aset_zap_arg (_env, 0, agg);
}
;

create function DB.DBA.RDF_FORMAT_RESULT_SET_AS_CXML_FIN (inout _env any) returns long varchar
{
  declare ses, metas, rset any;
  declare accept varchar;
  declare add_http_headers integer;
  ses := string_output ();
  if (isinteger (_env))
    {
      metas := vector (vector (vector ('s')), 1);
      rset := vector ();
      DB.DBA.SPARQL_RESULTS_CXML_WRITE (ses, metas, rset, accept, add_http_headers);
    }
  else
    {
      declare cols any;
      declare colctr, colcount integer;
      rset := aref_set_0 (_env, 0);
      vectorbld_final (rset);
      cols := aref_set_0 (_env, 1);
      colcount := length (cols);
      for (colctr := 0; colctr < colcount; colctr := colctr + 1) cols[colctr] := vector (cols[colctr]);
      metas := vector (cols, vector ());
      DB.DBA.SPARQL_RESULTS_CXML_WRITE (ses, metas, rset, accept, add_http_headers);
    }
  return string_output_string (ses);
}
;

create aggregate DB.DBA.RDF_FORMAT_RESULT_SET_AS_CXML (in colvalues any, in colnames any) returns long varchar
from DB.DBA.RDF_FORMAT_RESULT_SET_AS_CXML_INIT, DB.DBA.RDF_FORMAT_RESULT_SET_AS_CXML_ACC, DB.DBA.RDF_FORMAT_RESULT_SET_AS_CXML_FIN
order
;

create procedure DB.DBA.RDF_FORMAT_RESULT_SET_AS_BINDINGS_INIT (inout _env any)
{
  _env := vector (0, 0, string_output());
}
;

create procedure DB.DBA.RDF_FORMAT_RESULT_SET_AS_BINDINGS_ACC (inout _env any, inout colvalues any, inout colnames any)
{
  declare col_ctr, col_count integer;
  declare ses any;
  declare rowid varchar;
  declare blank_ids any;
  if (__tag of vector <> __tag(_env))
    DB.DBA.RDF_FORMAT_RESULT_SET_AS_BINDINGS_INIT (_env);
  if (isinteger (_env[1]))
    {
      if (185 <> __tag(_env))
        DB.DBA.RDF_FORMAT_RESULT_SET_AS_BINDINGS_INIT (_env);
      _env[1] := colnames;
      ses := aref_set_0 (_env, 2);
      http ('BINDINGS', ses);
      foreach (varchar colname in colnames) do { http (' ?' || colname, ses); }
      http (' {', ses);
    }
  else
    ses := aref_set_0 (_env, 2);
  http ('\n  (', ses);
  foreach (any val in colvalues) do
    {
      if (val is null)
        http ('\tUNDEF', ses);
      else
        {
          http ('\t', ses);
          http_nt_object (val, ses);
        }
    }
  http ('\t)', ses);
  aset_zap_arg (_env, 2, ses);
}
;

create function DB.DBA.RDF_FORMAT_RESULT_SET_AS_BINDINGS_FIN (inout _env any) returns long varchar
{
  declare ses any;
  if (__tag of vector <> __tag(_env))
    DB.DBA.RDF_FORMAT_RESULT_SET_AS_BINDINGS_INIT (_env);
  if (isinteger (_env[1]))
    return 'BINDINGS ?EmptyResultSetStub { }';
  ses := aref_set_0 (_env, 2);
  if (not isinteger (_env[1]))
    http ('\n}', ses);
  return string_output_string (ses);
}
;

create aggregate DB.DBA.RDF_FORMAT_RESULT_SET_AS_BINDINGS (in colvalues any, in colnames any) returns long varchar
from DB.DBA.RDF_FORMAT_RESULT_SET_AS_BINDINGS_INIT, DB.DBA.RDF_FORMAT_RESULT_SET_AS_BINDINGS_ACC, DB.DBA.RDF_FORMAT_RESULT_SET_AS_BINDINGS_FIN
order
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

create function DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_NICE_TTL (inout triples_dict any) returns long varchar
{
  declare triples, ses any;
  if (2666 < dict_size (triples_dict)) -- The "nice" algorithm is too slow to be applied to large outputs. There's also a limit for 8000 namespace prefixes.
    return DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_TTL (triples_dict);
  ses := string_output ();
  if (214 <> __tag (triples_dict))
    triples := vector ();
  else
    triples := dict_list_keys (triples_dict, 1);
  DB.DBA.RDF_TRIPLES_TO_NICE_TTL (triples, ses);
  return ses;
}
;

create procedure DB.DBA.RDF_TRIPLES_TO_NICE_TTL (inout triples any, inout ses any)
{
  declare tcount integer;
  tcount := length (triples);
  if (0 = tcount)
    {
      http ('# Empty Turtle\n', ses);
      return;
    }
  if (2666 < tcount) -- The "nice" algorithm is too slow to be applied to large outputs. There's also a limit for 8000 namespace prefixes.
    {
      DB.DBA.RDF_TRIPLES_TO_TTL (triples, ses);
      return;
    }
  DB.DBA.RDF_TRIPLES_TO_NICE_TTL_IMPL (triples, 0, ses);
}
;

create procedure DB.DBA.RDF_TRIPLES_TO_NICE_TTL_IMPL (inout triples any, in env_flags integer, inout ses any)
{
  declare env, printed_triples_mask any;
  declare rdf_first_iid, rdf_rest_iid, rdf_nil_iid IRI_ID;
  declare bnode_usage_dict any;
-- Keys of bnode_usage_dict are IRI_IDs of all blank nodes of the \c triples,
-- values are vectors of five items
-- #0: NULL if key bnode is not used as object OR IRI_ID of single subject such that the key bnode is object OR an empty string UNAME if the key bnode is used as object many times or makes a loop made of anonymous bnodes.
-- #1: NULL if key bnode does not have rdf:first property OR an integer index of that rdf:first triple in \c triples OR an empty string UNAME if the key bnode has many values of rdf:first or non-list predicates.
-- #2: NULL if key bnode does not have rdf:rest property OR an integer index of that rdf:rest triple in \c triples OR an empty string UNAME if the key bnode has many values of rdf:rest or non-list predicates.
-- #3: NULL if not in the list or not yet checked OR an integer that indicates the length of proper tail of the list OR an empty string UNAME if the list is ended up with cycle or something weird.
-- #4: Index of first triple where the bnode appears as a subject, NULL if there are no such.
  declare tail_to_head_dict any;
-- Keys of tail_to_head_dict are last bnodes of lists, values are first bnodes of (valid parts of) lists OR empty string UNAME for last bnodes that were later proven to be inappropriate.
  declare all_bnodes any;
  declare tcount, tctr, bnode_ctr integer;
  declare tail_bnode, head_bnode IRI_ID;
  declare prefixes_are_printed integer;
  declare prev_s, prev_p varchar;
  tcount := length (triples);
  rowvector_obj_sort (triples, 2, 1);
  rowvector_subj_sort (triples, 1, 1);
  rowvector_subj_sort (triples, 0, 1);
  env := DB.DBA.RDF_TRIPLES_TO_TTL_ENV (tcount, env_flags, 0, ses);
  rdf_first_iid	:= iri_to_id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#first');
  rdf_rest_iid	:= iri_to_id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#rest');
  rdf_nil_iid	:= iri_to_id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#nil');
  printed_triples_mask := space (tcount);
-- First of all we gather info into bnode_usage_dict, except items #3 of values
  bnode_usage_dict := dict_new (13 + (tcount / 100));
  tail_to_head_dict := dict_new (13 + (tcount / 1000));
  for (tctr := 0; tctr < tcount; tctr := tctr + 1)
    {
      declare s_iid, o_iid IRI_ID;
      -- dbg_obj_princ ('Gathering ', tctr, '/', tcount, triples[tctr][0], triples[tctr][1], triples[tctr][2]);
      if (triples[tctr][0] is null or triples[tctr][1] is null or triples[tctr][2] is null)
        {
          printed_triples_mask[tctr] := ascii ('N');
          goto triple_skipped;
        }
      s_iid := iri_to_id_nosignal (triples[tctr][0]);
      o_iid := iri_to_id_nosignal (triples[tctr][2]);
      if (is_bnode_iri_id (s_iid))
        {
          declare p_iid IRI_ID;
          declare u any;
          p_iid := iri_to_id_nosignal (triples[tctr][1]);
          u := dict_get (bnode_usage_dict, s_iid, null);
          if (u is null)
            u := vector (null, null, null, null, tctr);
          else if (u[4] is null)
            u[4] := tctr;
          if (rdf_first_iid = p_iid)
            {
              if (u[1] is null)
                {
                  u[1] := tctr;
                  goto s_iid_done;
                }
              else
                goto bad_for_list;
            }
          else if (rdf_rest_iid = p_iid)
            {
              if (u[2] is not null)
                goto bad_for_list;
              else if (rdf_nil_iid = o_iid)
                {
                  dict_put (tail_to_head_dict, s_iid, s_iid);
                  u[2] := tctr;
                  goto s_iid_done;
                }
              else if (is_bnode_iri_id (o_iid))
                {
                  u[2] := tctr;
                  goto s_iid_done;
                }
              else
                goto bad_for_list;
            }
bad_for_list:
          u[1] := UNAME'';
          u[2] := UNAME'';
          if (dict_get (tail_to_head_dict, s_iid, null) is not null)
            dict_put (tail_to_head_dict, s_iid, UNAME'');
s_iid_done:
          dict_put (bnode_usage_dict, s_iid, u);
        }
      if (is_bnode_iri_id (o_iid))
        {
          declare u any;
          u := dict_get (bnode_usage_dict, o_iid, null);
          if (u is null)
            dict_put (bnode_usage_dict, o_iid, vector (s_iid, null, null, null, null));
          else
            {
              if (u[0] is null)
                u[0] := s_iid;
              else
                u[0] := UNAME'';
              dict_put (bnode_usage_dict, o_iid, u);
            }
        }
triple_skipped: ;
    }
-- Now it's possible to check for loops of anonymous cycles
  all_bnodes := dict_list_keys (bnode_usage_dict, 0);
  gvector_sort (all_bnodes, 1, 0, 1);
  foreach (IRI_ID bn_iid in all_bnodes) do
    {
      declare top_bn_iid IRI_ID;
      top_bn_iid := bn_iid;
      while (is_bnode_iri_id (top_bn_iid))
        {
          declare u any;
          u := dict_get (bnode_usage_dict, top_bn_iid, null);
          if (u[0] = bn_iid)
            {
              u := dict_get (bnode_usage_dict, bn_iid, null);
              u[0] := UNAME'';
              dict_put (bnode_usage_dict, bn_iid, u);
              goto bn_iid_done;
            }
          top_bn_iid := u[0];
        }
bn_iid_done: ;
    }
-- Now it is possible to check list nodes
  dict_iter_rewind (tail_to_head_dict);
  while (dict_iter_next (tail_to_head_dict, tail_bnode, head_bnode))
    {
      declare last_good_head_bnode IRI_ID;
      declare len_ctr integer;
      len_ctr := 0;
      last_good_head_bnode := head_bnode;
      -- dbg_obj_princ ('Loop from ', tail_bnode, ' to ', head_bnode);
      while (is_bnode_iri_id (head_bnode))
        {
          declare u any;
          u := dict_get (bnode_usage_dict, head_bnode, null);
          -- dbg_obj_princ (head_bnode, ' has ', u);
          if (isinteger (u[1]) and isinteger (u[2]) and u[3] is null and (u[0] is null or isiri_id (u[0])))
            {
              -- dbg_obj_princ ('Reached ', last_good_head_bnode);
              last_good_head_bnode := head_bnode;
              u[3] := len_ctr;
              len_ctr := len_ctr + 1;
              dict_put (bnode_usage_dict, head_bnode, u);
              head_bnode := u[0];
            }
          else
            {
              u[3] := UNAME'';
              dict_put (bnode_usage_dict, head_bnode, u);
              head_bnode := null;
            }
        }
    }
  DB.DBA.RDF_TRIPLES_BATCH_COMPLETE (triples);
-- Start the actual serialization
  prefixes_are_printed := 0;
  for (tctr := 0; tctr < tcount; tctr := tctr + 1)
    prefixes_are_printed := prefixes_are_printed + http_ttl_prefixes (env, triples[tctr][0], triples[tctr][1], triples[tctr][2], ses);
  if (prefixes_are_printed)
    http ('\n', ses);
  prev_s := '';
  prev_p := '';
  -- dbg_obj_princ ('printed_triples_mask="', printed_triples_mask, '"');
  for (tctr := 0; tctr < tcount; tctr := tctr + 1)
    {
      declare s_iid, o_iid IRI_ID;
      declare s, p, o any;
      if (ascii (' ') <> printed_triples_mask[tctr])
        goto done_triple;
      -- dbg_obj_princ ('Printing ', tctr, '/', tcount, triples[tctr][0], triples[tctr][1], triples[tctr][2]);
      s := triples[tctr][0];
      p := triples[tctr][1];
      o := triples[tctr][2];
      s_iid := iri_to_id_nosignal (s);
      o_iid := iri_to_id_nosignal (o);
      if (is_bnode_iri_id (s_iid))
        {
          declare u any;
          u := dict_get (bnode_usage_dict, s_iid, null);
          if (isiri_id (u[0]))
            goto done_triple;
        }
      if (s <> prev_s)
        {
          if (prev_s <> '')
            http (' .\n', ses);
          http_ttl_value (env, s, 0, ses);
          http ('\n\t', ses);
          prev_s := s;
          prev_p := '';
        }
      if (p <> prev_p)
        {
          if (prev_p <> '')
            http (' ;\n\t', ses);
          http_ttl_value (env, p, 1, ses);
          http ('\t', ses);
          prev_p := p;
        }
      else
        http (' , ', ses);
      printed_triples_mask[tctr] := ascii ('p');
      if (is_bnode_iri_id (o_iid))
        DB.DBA.RDF_TRIPLE_OBJ_BNODE_TO_NICE_TTL (triples, printed_triples_mask, o_iid, env, bnode_usage_dict, 2, ses);
      else
        http_ttl_value (env, o, 2, ses);
      -- dbg_obj_princ ('printed_triples_mask="', printed_triples_mask, '"');
done_triple: ;
    }
done_data:
  if (prev_s is not null)
    http (' .\n', ses);
  else
    http ('# Empty Turtle (no valid data to print)\n', ses);
}
;

create procedure DB.DBA.RDF_TRIPLE_OBJ_BNODE_TO_NICE_TTL (inout triples any, inout printed_triples_mask any, in s_bnode_iid IRI_ID, inout env any, inout bnode_usage_dict any, in depth integer, inout ses any)
{
  declare u, subj, prev_p any;
  declare tctr, tcount integer;
  u := dict_get (bnode_usage_dict, s_bnode_iid, null);
  if (u[0] is not null and not isiri_id (u[0]))
    {
      -- dbg_obj_princ ('Printing plain bnode ', s_bnode_iid, ' u=', u);
      http_ttl_value (env, s_bnode_iid, 2, ses);
      return;
    }
  if (isinteger (u[3]))
    {
      -- dbg_obj_princ ('Printing list from ', s_bnode_iid, ' u=', u);
      http ('(', ses);
      while (is_bnode_iri_id (s_bnode_iid))
        {
          declare itm any;
          declare itm_iid IRI_ID;
          itm := triples[u[1]][2];
          itm_iid := iri_to_id_nosignal (itm);
          if (ascii (' ') <> printed_triples_mask[u[1]]) signal ('OBLOM', 'Corrupted CAR in list');
          if (ascii (' ') <> printed_triples_mask[u[2]]) signal ('OBLOM', 'Corrupted CDR in list');
          printed_triples_mask[u[1]] := ascii ('A');
          http (' ', ses);
          if (is_bnode_iri_id (itm_iid))
            DB.DBA.RDF_TRIPLE_OBJ_BNODE_TO_NICE_TTL (triples, printed_triples_mask, itm_iid, env, bnode_usage_dict, depth + 1, ses);
          else
            http_ttl_value (env, itm, 2, ses);
          printed_triples_mask[u[2]] := ascii ('D');
          s_bnode_iid := iri_to_id_nosignal (triples[u[2]][2]);
          u := dict_get (bnode_usage_dict, s_bnode_iid, null);
          -- dbg_obj_princ ('next node ', s_bnode_iid, ' u=', u);
        }
      http (' )', ses);
      return;
    }
  tctr := u[4];
  if (tctr is null)
    {
      -- dbg_obj_princ ('Printing empty bnode ', s_bnode_iid, ' u=', u);
      http ('[ ]', ses);
      return;
    }
  tcount := length (triples);
  subj := triples[tctr][0];
  prev_p := '';
  http ('[\t', ses);
  -- dbg_obj_princ ('Printing bnode triples for ', s_bnode_iid, ' starting from ', tctr, '/', tcount, ' u=', u);
  while (1=1)
    {
      declare o_iid IRI_ID;
      declare p, o any;
      if (ascii (' ') <> printed_triples_mask[tctr])
        goto done_triple;
      p := triples[tctr][1];
      o := triples[tctr][2];
      o_iid := iri_to_id_nosignal (o);
      if (p <> prev_p)
        {
          if (prev_p <> '')
            http (' ;\n' || repeat ('\t', depth+2), ses);
          http_ttl_value (env, p, 2, ses);
          http ('\t', ses);
          prev_p := p;
        }
      else
        http (' , ', ses);
      printed_triples_mask[tctr] := ascii ('[');
      if (is_bnode_iri_id (o_iid))
        DB.DBA.RDF_TRIPLE_OBJ_BNODE_TO_NICE_TTL (triples, printed_triples_mask, o_iid, env, bnode_usage_dict, depth + 2, ses);
      else
        http_ttl_value (env, o, 2, ses);
done_triple:
      tctr := tctr + 1;
      if (not ((tctr < tcount) and (triples[tctr][0] = subj)))
        {
          http (' ]', ses);
          return;
        }
    }
}
;



create function DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_TRIG (inout triples_dict any) returns long varchar
{
  declare triples, ses any;
  ses := string_output ();
  if (214 <> __tag (triples_dict))
    {
      triples := vector ();
    }
  else
    triples := dict_list_keys (triples_dict, 1);
  DB.DBA.RDF_TRIPLES_TO_TRIG (triples, ses);
  return ses;
}
;

create function DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_NT (inout triples_dict any) returns long varchar
{
  declare triples, ses any;
  ses := string_output ();
  if (214 <> __tag (triples_dict))
    {
      triples := vector ();
    }
  else
    triples := dict_list_keys (triples_dict, 1);
  DB.DBA.RDF_TRIPLES_TO_NT (triples, ses);
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

create function DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_TALIS_JSON (inout triples_dict any) returns long varchar
{
  declare triples, ses any;
  ses := string_output ();
  if (214 <> __tag (triples_dict))
    {
      triples := vector ();
    }
  else
    triples := dict_list_keys (triples_dict, 1);
  DB.DBA.RDF_TRIPLES_TO_TALIS_JSON (triples, ses);
  return ses;
}
;

create function DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_JSON_LD (inout triples_dict any) returns long varchar
{
  declare triples, ses any;
  ses := string_output ();
  if (214 <> __tag (triples_dict))
    {
      triples := vector ();
    }
  else
    triples := dict_list_keys (triples_dict, 1);
  DB.DBA.RDF_TRIPLES_TO_JSON_LD (triples, ses);
  return ses;
}
;

create function DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_HTML_UL (inout triples_dict any) returns long varchar
{
  declare triples, ses any;
  ses := string_output ();
  if (214 <> __tag (triples_dict))
    {
      triples := vector ();
    }
  else
    triples := dict_list_keys (triples_dict, 1);
  DB.DBA.RDF_TRIPLES_TO_HTML_UL (triples, ses);
  return ses;
}
;

create function DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_HTML_TR (inout triples_dict any) returns long varchar
{
  declare triples, ses any;
  ses := string_output ();
  if (214 <> __tag (triples_dict))
    {
      triples := vector ();
    }
  else
    triples := dict_list_keys (triples_dict, 1);
  DB.DBA.RDF_TRIPLES_TO_HTML_TR (triples, ses);
  return ses;
}
;

create function DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_HTML_MICRODATA (inout triples_dict any) returns long varchar
{
  declare triples, ses any;
  ses := string_output ();
  if (214 <> __tag (triples_dict))
    {
      triples := vector ();
    }
  else
    triples := dict_list_keys (triples_dict, 1);
  DB.DBA.RDF_TRIPLES_TO_HTML_MICRODATA (triples, ses);
  return ses;
}
;

create function DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_HTML_NICE_MICRODATA (inout triples_dict any) returns long varchar
{
  declare triples, ses any;
  ses := string_output ();
  if (214 <> __tag (triples_dict))
    {
      triples := vector ();
    }
  else
    triples := dict_list_keys (triples_dict, 1);
  DB.DBA.RDF_TRIPLES_TO_HTML_NICE_MICRODATA (triples, ses);
  return ses;
}
;

create function DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_HTML_NICE_TTL (inout triples_dict any) returns long varchar
{
  declare triples, ses any;
  ses := string_output ();
  if (214 <> __tag (triples_dict))
    triples := vector ();
  else
    triples := dict_list_keys (triples_dict, 1);
  DB.DBA.RDF_TRIPLES_TO_HTML_NICE_TTL (triples, ses);
  return ses;
}
;

create procedure DB.DBA.RDF_TRIPLES_TO_HTML_NICE_TTL (inout triples any, inout ses any)
{
  declare tcount integer;
  tcount := length (triples);
  if (0 = tcount)
    {
      http ('# Empty Turtle\n', ses);
      return;
    }
  rowvector_obj_sort (triples, 2, 1);
  rowvector_subj_sort (triples, 1, 1);
  rowvector_subj_sort (triples, 0, 1);
  if (2666 < tcount) -- The "nice" algorithm is too slow to be applied to large outputs. There's also a limit for 8000 namespace prefixes.
    {
      http (sprintf ('# The result consists of %d triples so it is too long to be pretty-printed. The dump below contains that triples without any decoration', tcount), ses);
      http ('<xmp>', ses);
      DB.DBA.RDF_TRIPLES_TO_TTL (triples, ses);
      http ('</xmp>', ses);
      return;
    }
  http ('<pre>', ses);
  DB.DBA.RDF_TRIPLES_TO_NICE_TTL_IMPL (triples, 257, ses);
  http ('</pre>', ses);
}
;

create function DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_JSON_MICRODATA (inout triples_dict any) returns long varchar
{
  declare triples, ses any;
  ses := string_output ();
  if (214 <> __tag (triples_dict))
    {
      triples := vector ();
    }
  else
    triples := dict_list_keys (triples_dict, 1);
  DB.DBA.RDF_TRIPLES_TO_JSON_MICRODATA (triples, ses);
  return ses;
}
;

create function DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_CSV (inout triples_dict any) returns long varchar
{
  declare triples, ses any;
  ses := string_output ();
  if (214 <> __tag (triples_dict))
    {
      triples := vector ();
    }
  else
    triples := dict_list_keys (triples_dict, 1);
  DB.DBA.RDF_TRIPLES_TO_CSV (triples, ses);
  return ses;
}
;

create function DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_TSV (inout triples_dict any) returns long varchar
{
  declare triples, ses any;
  ses := string_output ();
  if (214 <> __tag (triples_dict))
    {
      triples := vector ();
    }
  else
    triples := dict_list_keys (triples_dict, 1);
  DB.DBA.RDF_TRIPLES_TO_TSV (triples, ses);
  return ses;
}
;

create function DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_RDFA_XHTML (inout triples_dict any) returns long varchar
{
  declare triples, ses any;
  ses := string_output ();
  if (214 <> __tag (triples_dict))
    {
      triples := vector ();
    }
  else
    triples := dict_list_keys (triples_dict, 1);
  DB.DBA.RDF_TRIPLES_TO_RDFA_XHTML (triples, ses);
  return ses;
}
;

create function DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_CXML (inout triples_dict any) returns long varchar
{
  declare triples, ses any;
  declare accept varchar;
  declare add_http_headers integer;
  add_http_headers := 0;
  ses := string_output ();
  if (214 <> __tag (triples_dict))
    {
      triples := vector ();
    }
  else
    triples := dict_list_keys (triples_dict, 1);
  DB.DBA.RDF_TRIPLES_TO_CXML (triples, ses, accept, add_http_headers, 0);
  return ses;
}
;

create function DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_CXML_QRCODE (inout triples_dict any) returns long varchar
{
  declare triples, ses any;
  declare accept varchar;
  declare add_http_headers integer;
  add_http_headers := 0;
  ses := string_output ();
  if (214 <> __tag (triples_dict))
    {
      triples := vector ();
    }
  else
    triples := dict_list_keys (triples_dict, 1);
  DB.DBA.RDF_TRIPLES_TO_CXML (triples, ses, accept, add_http_headers, 1);
  return ses;
}
;

--!AWK PUBLIC
create procedure DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_XML_INIT (inout _env any)
{
  _env := 0;
}
;

--!AWK PUBLIC
create procedure DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_XML_ACC (inout _env any, in one any array)
{
  _env := 1;
}
;

--!AWK PUBLIC
create function DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_XML_FIN (inout _env any) returns long varchar
{
  declare ses any;
  declare ans varchar;
  ses := string_output ();
  if (isinteger (_env) and _env)
    ans := 'true';
  else
    ans := 'false';
  http ('<sparql xmlns="http://www.w3.org/2005/sparql-results#" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.w3.org/2001/sw/DataAccess/rf1/result2.xsd">
 <head></head>
 <boolean>' || ans || '</boolean>
</sparql>', ses);
  return ses;
}
;

create aggregate DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_XML (in one any array) returns long varchar
from DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_XML_INIT, DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_XML_ACC, DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_XML_FIN
;

--!AWK PUBLIC
create procedure DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_RDF_XML_INIT (inout _env any)
{
  _env := 0;
}
;

--!AWK PUBLIC
create procedure DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_RDF_XML_ACC (inout _env any, in one any array)
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
   <rs:boolean rdf:datatype="http://www.w3.org/2001/XMLSchema#boolean">' || ans || '</rs:boolean></rs:results></rdf:RDF>', ses);
  return ses;
}
;

create aggregate DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_RDF_XML (in one any array) returns long varchar
from DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_RDF_XML_INIT, DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_RDF_XML_ACC, DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_RDF_XML_FIN
;

--!AWK PUBLIC
create procedure DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_TTL_INIT (inout _env any)
{
  _env := 0;
}
;

--!AWK PUBLIC
create procedure DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_TTL_ACC (inout _env any, in one any array)
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
  http (sprintf ('[] rdf:type rs:results ; rs:boolean %s .', ans), ses);
  return ses;
}
;

create aggregate DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_TTL (in one any array) returns long varchar
from DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_TTL_INIT, DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_TTL_ACC, DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_TTL_FIN
;

--!AWK PUBLIC
create function DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_NT_FIN (inout _env any) returns long varchar
{
  declare ses any;
  declare ans varchar;
  ses := string_output ();
  if (isinteger (_env) and _env)
    ans := 'true';
  else
    ans := 'false';
  http (sprintf ('_:_ <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2005/sparql-results#results> .\n_:_ <http://www.w3.org/2005/sparql-results#boolean> "%s"^^<http://www.w3.org/2001/XMLSchema#boolean> .\n', ans), ses);
  return ses;
}
;

create aggregate DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_NT (in one any array) returns long varchar
from DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_TTL_INIT,	-- Not DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_NT_INIT
 DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_TTL_ACC,	-- Not DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_NT_ACC
 DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_NT_FIN
;


create aggregate DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_TTL (in one any array) returns long varchar
from DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_TTL_INIT, DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_TTL_ACC, DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_TTL_FIN
;

--!AWK PUBLIC
create function DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_CSV_FIN (inout _env any) returns long varchar
{
  declare ans varchar;
  if (isinteger (_env) and _env)
    return '"bool"\n1\n';
  else
    return '"bool"\n0\n';
}
;

create aggregate DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_CSV (in one any array) returns long varchar
from DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_TTL_INIT,	-- Not DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_CSV_INIT
 DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_TTL_ACC,	-- Not DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_CSV_ACC
 DB.DBA.RDF_FORMAT_BOOL_RESULT_AS_CSV_FIN
;

-----
-- Insert, delete, modify operations for lists of triples

-- By default, SPARQL 1.0 codegen makes calls of SPARQL_INSERT_DICT_CONTENT() / SPARQL_DELETE_DICT_CONTENT() / SPARQL_MODIFY_BY_DICT_CONTENTS()
-- with SPARQL_CONSTRUCT as an aggregate that makes dictionary of triples
-- SPARQL 1.1 codegen can also make calls of SPARQL_INSERT_QUAD_DICT_CONTENT() / SPARQL_DELETE_QUAD_DICT_CONTENT() / SPARQL_MODIFY_BY_QUAD_DICT_CONTENTS()
-- with SPARQL_CONSTRUCT as an aggregate that makes dictionary of triples or quads.
-- The optimizer can tweak these calls for optimization: instead of plain constant for default graph IRI,
-- a call of SPARQL_INSERT_CTOR / SPARQL_DELETE_CTOR / SPARQL_MODIFY_CTOR can be placed.
-- Thus some triples will be inserted/deleted witout being accumulated in dictionary for the whole time of the selection process.
-- Accomulators SPARQL_INSERT_CTOR_ACC / SPARQL_DELETE_CTOR_ACC / SPARQL_MODIFY_CTOR_ACC are based on a common
-- SPARQL_INS_OR_DEL_CTOR_IMPL that calls either RDF_INSERT_TRIPLES / RDF_INSERT_QUADS or RDF_DELETE_TRIPLES_AGG / RDF_DELETE_QUADS, depending on the requested operation code.
-- A common finalizer SPARQL_INS_OR_DEL_OR_MODIFY_CTOR_FIN calls RDF_INSERT_TRIPLES / RDF_INSERT_QUADS or RDF_DELETE_TRIPLES /* without _AGG suffix*/  / RDF_DELETE_QUADS.


create procedure DB.DBA.RDF_INSERT_TRIPLES_CL (inout graph_iri any, inout triples any, in log_mode integer := null)
{
  declare is_text, ctr, old_log_enable, l integer;
  declare ro_id_dict, dp any;
  if ('1' = registry_get ('cl_rdf_text_index'))
    is_text := 1;
  if (not isiri_id (graph_iri))
    graph_iri := iri_to_id (graph_iri);
  if (__rdf_graph_is_in_enabled_repl (graph_iri))
    DB.DBA.RDF_REPL_INSERT_TRIPLES (id_to_iri (graph_iri), triples);
  connection_set ('g_iid', graph_iri);
  ro_id_dict := null;
  --ro_id_dict := dict_new ();
  --connection_set ('g_dict', ro_id_dict);
  dp := dpipe (0, 'IRI_TO_ID_1', 'IRI_TO_ID_1', 'IRI_TO_ID_1', 'MAKE_RO_1', 'IRI_TO_ID_1');
  dpipe_set_rdf_load (dp);
  l := length (triples);
  for (ctr := 0; ctr < l; ctr := ctr + 1)
    {
      declare r, o_val any;
      r := triples[ctr];
      o_val := r[2];
      if (__tag (o_val) in (__tag of varchar, __tag of XML))
        {
          if (is_text)
            {
              -- make first first non default type because if all is default it will make no box
              declare o_val_2 any;
              o_val_2 := rdf_box (o_val, 300, 257, 0, 1);
              rdf_box_set_is_text (o_val_2, 1);
              rdf_box_set_type (o_val_2, 257);
              -- dbg_obj_princ ('DB.DBA.RDF_INSERT_TRIPLES_CL inserts text1 ', r[0], r[1], null, o_val_2, null);
              dpipe_input (dp, r[0], r[1], null, o_val_2, null);
            }
          else
            {
              -- dbg_obj_princ ('DB.DBA.RDF_INSERT_TRIPLES_CL inserts text0 ', r[0], r[1], null, o_val, null);
              -- dbg_obj_princ ('zero is_text in sparql.sql:6618 ', o_val);
              dpipe_input (dp, r[0], r[1], null, o_val, null);
            }
        }
      else
        {
          -- dbg_obj_princ ('DB.DBA.RDF_INSERT_TRIPLES_CL inserts ', r[0], r[1], null, o_val);
          -- dbg_obj_princ ('unknown is_text in sparql.sql:6626 ', o_val);
          dpipe_input (dp, r[0], r[1], null, o_val, null);
        }
      if (mod (ctr + 1, 40000) = 0 and l > 60000)
	{
	  dpipe_next (dp, 0);
	  dpipe_next (dp, 1);
	  dpipe_reuse (dp);
	}
    }
  dpipe_next (dp, 0);
  dpipe_next (dp, 1);
  if (ro_id_dict is not null)
    DB.DBA.RDF_OBJ_ADD_KEYWORD_FOR_GRAPH (graph_iri, ro_id_dict);
}
;

/* insert */
create procedure DB.DBA.RDF_INSERT_TRIPLES (in graph_iid any, inout triples any, in log_mode integer := null)
{
  declare ctr, old_log_enable integer;
  declare ro_id_dict any;
  if (0 = sys_stat ('cl_run_local_only'))
    return RDF_INSERT_TRIPLES_CL (graph_iid, triples, log_mode);
  if (not isiri_id (graph_iid))
    graph_iid := iri_to_id (graph_iid);
  if (__rdf_graph_is_in_enabled_repl (graph_iid))
    DB.DBA.RDF_REPL_INSERT_TRIPLES (id_to_iri (graph_iid), triples);
  old_log_enable := log_enable (log_mode, 1);
  declare exit handler for sqlstate '*' { log_enable (old_log_enable, 1); resignal; };
  if (0 = bit_and (old_log_enable, 2))
    {
      declare dp any;
      dp := rl_local_dpipe ();
      connection_set ('g_iid', graph_iid);
      for (ctr := length (triples) - 1; ctr >= 0; ctr := ctr - 1)
	{
	  declare s_iid, p_iid, obj, o_type, o_lang any;
	s_iid := triples[ctr][0];
	p_iid := triples[ctr][1];
	obj :=   triples[ctr][2];
	  if (isiri_id (obj))
	    dpipe_input (dp, s_iid, p_iid, obj, null);
	  else
            {
              __rdf_obj_set_is_text_if_ft_rule_check (obj, graph_iid, p_iid, null);
	    dpipe_input (dp, s_iid, p_iid, null, obj);
	}
        }
      rl_flush (dp, graph_iid);
      return;
    }
  if (not is_atomic ())
    {
      declare app_env any;
      -- dbg_obj_princ ('DB.DBA.RDF_INSERT_TRIPLES, not atomic');
      app_env := vector (async_queue (0, 1), rl_local_dpipe (), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
      connection_set ('g_iid', graph_iid);
      for (ctr := length (triples) - 1; ctr >= 0; ctr := ctr - 1)
         {
	   declare s_iid, p_iid, obj, o_type, o_lang any;
	   s_iid := triples[ctr][0];
	   p_iid := triples[ctr][1];
	   obj :=   triples[ctr][2];
	   if (isiri_id (obj))
	     dpipe_input (app_env[1], s_iid, p_iid, obj, null);
	   else
             {
               __rdf_obj_set_is_text_if_ft_rule_check (obj, graph_iid, p_iid, null);
	     dpipe_input (app_env[1], s_iid, p_iid, null, obj);
             }
	   if (dpipe_count (app_env[1]) > dc_batch_sz ())
             rl_send (app_env, graph_iid);
         }
      rl_send (app_env, graph_iid);
      commit work;
      aq_wait_all (app_env[0]);
      connection_set ('g_dict', null);
      log_enable (old_log_enable, 1);
      return;
    }
  ro_id_dict := null;
  for (ctr := length (triples) - 1; ctr >= 0; ctr := ctr - 1)
    {
      declare p_iid, o_orig, o_final any;
      declare need_digest integer;
      p_iid := triples[ctr][1];
      o_final := o_orig := triples[ctr][2];
      if (isiri_id (o_final))
        goto do_insert;
      if (ro_id_dict is null and __rdf_obj_ft_rule_check (graph_iid, p_iid))
        ro_id_dict := dict_new ();
      -- dbg_obj_princ ('DB.DBA.RDF_INSERT_TRIPLES got ', graph_iid, triples[ctr][0], p_iid, o_final);
      need_digest := rdf_box_needs_digest (o_final, ro_id_dict);
      if (1 < need_digest)
        {
          o_final := DB.DBA.RDF_MAKE_OBJ_OF_SQLVAL_FT (o_final, graph_iid, p_iid, ro_id_dict);
          --if (not rdf_box_is_storeable (o_final))
          --  {
          --    -- dbg_obj_princ ('OBLOM', 'Bad O after DB.DBA.MAKE_OBJ_OF_SQLVAL_FT', o_orig, '=>', o_final);
          --    signal ('OBLOM', 'Bad O after MAKE_OBJ_OF_SQLVAL_FT');
          --  }
        }
      else
        {
          o_final := DB.DBA.RDF_OBJ_ADD (257, o_final, 257);
          --if (not rdf_box_is_storeable (o_final))
          --  {
          --    -- dbg_obj_princ ('OBLOM', 'Bad O after DB.DBA.RDF_OBJ_ADD', o_orig, '=>', o_final);
          --    signal ('OBLOM', 'Bad O after DB.DBA.RDF_OBJ_ADD');
          --  }
        }
do_insert:
      -- dbg_obj_princ ('DB.DBA.RDF_INSERT_TRIPLES inserts ', graph_iid, triples[ctr][0], p_iid, o_final);
      insert soft DB.DBA.RDF_QUAD (G,S,P,O)
      values (graph_iid, triples[ctr][0], p_iid, o_final);
    }
  if (ro_id_dict is not null)
    DB.DBA.RDF_OBJ_ADD_KEYWORD_FOR_GRAPH (graph_iid, ro_id_dict);
  log_enable (old_log_enable, 1);
}
;

create procedure DB.DBA.RDF_DELETE_TRIPLES (in graph_iri any, in triples any, in log_mode integer := null)
{
  declare ctr, old_log_enable, l integer;
  if (not isiri_id (graph_iri))
    graph_iri := iri_to_id (graph_iri);
  if (__rdf_graph_is_in_enabled_repl (graph_iri))
    DB.DBA.RDF_REPL_DELETE_TRIPLES (id_to_iri (graph_iri), triples);
  old_log_enable := log_enable (log_mode, 1);
  declare exit handler for sqlstate '*' { log_enable (old_log_enable, 1); resignal; };
  if (1 = sys_stat ('enable_vec'))
    {
      declare gv, sv, pv, ov any;
      l := length (triples);
      gv := make_array (l, 'any');
      sv := make_array (l, 'any');
      pv := make_array (l, 'any');
      ov := make_array (l, 'any');
      for (ctr := 0; ctr < l; ctr := ctr + 1)
        {
          declare r any;
          r := triples[ctr];
	  gv[ctr] := graph_iri;
	  sv[ctr] := r[0];
	  pv[ctr] := r[1];
	  ov[ctr] := DB.DBA.RDF_OBJ_OF_LONG (r[2]);
	}
      for vectored (in gi any := gv, in si any := sv, in pi any := pv, in oi any array := ov)
         {
	   delete from DB.DBA.RDF_QUAD where G = gi and S = si and P = pi and O = oi;
	 }
      log_enable (old_log_enable, 1);
      return;
    }
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

-- /* delete */
create procedure DB.DBA.RDF_DELETE_TRIPLES_AGG (in graph_iid any, inout triples any, in log_mode integer := null)
{
  declare ctr, old_log_enable, l integer;
  if (not isiri_id (graph_iid))
    graph_iid := iri_to_id (graph_iid);
  if (__rdf_graph_is_in_enabled_repl (graph_iid))
    DB.DBA.RDF_REPL_DELETE_TRIPLES (id_to_iri (graph_iid), triples);
  old_log_enable := log_enable (log_mode, 1);
  declare exit handler for sqlstate '*' { log_enable (old_log_enable, 1); resignal; };
  for vectored (in a_triple any array := triples)
            {
      declare a_s, a_p, a_o any array;
      a_s := a_triple[0];
      a_p := a_triple[1];
      a_o := a_triple[2];
      if (not isiri_id (a_s))
        a_s := __i2idn (a_s);
      if (not isiri_id (a_p))
        a_p := __i2idn (a_p);
      if (isiri_id (a_s) and isiri_id (a_p))
        {
          if (isiri_id (a_o))
            delete from DB.DBA.RDF_QUAD where G = graph_iid and S = a_s and P = a_p and O = a_o;
          else
            {
              declare o_val any array;
              declare o_dt_and_lang_twobyte integer;
              declare search_fields_are_ok integer;
              search_fields_are_ok := __rdf_box_to_ro_id_search_fields (a_o, o_val, o_dt_and_lang_twobyte);
              -- dbg_obj_princ ('__rdf_box_to_ro_id_search_fields (', a_o, ') returned ', search_fields_are_ok, o_val, o_dt_and_lang_twobyte);
	      if (__tag of rdf_box = __tag (a_o) and rdf_box_is_complete (a_o))
                delete from DB.DBA.RDF_QUAD where G = graph_iid and S = a_s and P = a_p and O = a_o;
	      else if (search_fields_are_ok)
                delete from DB.DBA.RDF_QUAD where G = graph_iid and S = a_s and P = a_p and O = (select rdf_box_from_ro_id(RO_ID) from DB.DBA.RDF_OBJ where RO_VAL = o_val and RO_DT_AND_LANG = o_dt_and_lang_twobyte);
              else if (isstring (a_o)) /* it should be string IRI otherwise it's in RDF_OBJ */
                delete from DB.DBA.RDF_QUAD where G = graph_iid and S = a_s and P = a_p and O = iri_to_id (a_o);
              else
                delete from DB.DBA.RDF_QUAD where G = graph_iid and S = a_s and P = a_p and O = a_o;
        }
    }
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
  _env := 0;
}
;

--!AWK PUBLIC
create procedure DB.DBA.SPARQL_INS_OR_DEL_CTOR_IMPL (inout _env any, in graph_iri any, in opcodes any, in vars any, in log_mode integer, in ctor_op integer)
{
  declare triple_ctr, quads_found integer;
  declare blank_ids any;
  declare dict any;
  declare action_ctr integer;
  declare old_log_enable integer;
  old_log_enable := log_enable (log_mode, 1);
  -- dbg_obj_princ ('DB.DBA.SPARQL_INS_OR_DEL_CTOR_IMPL (', _env, graph_iri, opcodes, vars, log_mode, ctor_op, ')');
  declare exit handler for sqlstate '*' { log_enable (old_log_enable, 1); resignal; };
  blank_ids := 0;
  action_ctr := 0;
  quads_found := _env[5 + ctor_op];
  for (triple_ctr := length (opcodes) - 1; triple_ctr >= 0; triple_ctr := triple_ctr-1)
    {
      declare fld_ctr, fld_count integer;
      declare triple_vec any;
      declare g_opcode integer;
      g_opcode := aref_or_default (opcodes, triple_ctr, 6, null);
      if (g_opcode is null)
        {
          fld_count := 3;
          triple_vec := vector (0,0,0);
        }
      else
        {
          fld_count := 4;
          triple_vec := vector (0,0,0,0);
        }
      for (fld_ctr := fld_count - 1; fld_ctr >= 0; fld_ctr := fld_ctr - 1)
        {
          declare op integer;
          declare arg any;
          op := opcodes[triple_ctr][fld_ctr * 2];
          arg := opcodes[triple_ctr][fld_ctr * 2 + 1];
          if (1 = op)
            {
              declare i any;
              i := vars[arg];
              if (i is null)
                goto end_of_adding_triple;
              if (isiri_id (i))
                {
                  if (fld_ctr in (1,3) and is_bnode_iri_id (i))
                    signal ('RDF01', 'Bad variable value in INSERT: blank node can not be used as predicate or graph');
                }
              else if ((isstring (i) and (1 = __box_flags (i))) or (217 = __tag(i)))
                {
                  if (fld_ctr in (1,3) and (i like 'bnode://%'))
                    signal ('RDF01', 'Bad variable value in INSERT: blank node can not be used as predicate or graph');
                  i := iri_to_id (i);
                }
              else if (2 <> fld_ctr)
                signal ('RDF01',
                  sprintf ('Bad variable value in INSERT: "%.100s" (tag %d box flags %d) is not a valid %s, only object of a triple can be a literal',
                    __rdf_strsqlval (i), __tag (i), __box_flags (i),
                    case (fld_ctr) when 1 then 'predicate' else 'subject' end ) );
              triple_vec[fld_ctr] := i;
            }
          else if (2 = op)
            {
              if (isinteger (blank_ids))
                blank_ids := vector (iri_id_from_num (sequence_next ('RDF_URL_IID_BLANK')));
              while (arg >= length (blank_ids))
                blank_ids := vector_concat (blank_ids, vector (iri_id_from_num (sequence_next ('RDF_URL_IID_BLANK'))));
              if (fld_ctr in (1,3))
                signal ('RDF01', 'Bad triple for INSERT: blank node can not be used as predicate');
              triple_vec[fld_ctr] := blank_ids[arg];
            }
          else if (3 = op)
            {
              if (arg is null)
                goto end_of_adding_triple;
              if (isiri_id (arg))
                {
                  if (fld_ctr in (1,3) and is_bnode_iri_id (arg))
                    signal ('RDF01', 'Bad const value in INSERT: blank node can not be used as predicate or graph');
                }
              else if ((isstring (arg) and (1 = __box_flags (arg))) or (217 = __tag(arg)))
                {
                  if (fld_ctr in (1,3) and (arg like 'bnode://%'))
                    signal ('RDF01', 'Bad const value in INSERT: blank node can not be used as predicate or graph');
                  arg := iri_to_id (arg);
                }
              else if (2 <> fld_ctr)
                signal ('RDF01',
                  sprintf ('Bad const value in INSERT: "%.100s" (tag %d box flags %d) is not a valid %s, only object of a triple can be a literal',
                    __rdf_strsqlval (arg), __tag (arg), __box_flags (arg),
                    case (fld_ctr) when 1 then 'predicate' else 'subject' end ) );
              else if (__tag of vector = __tag (arg))
                arg := DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL_STRINGS (arg[0], arg[1], arg[2]);
              triple_vec[fld_ctr] := arg;
            }
          else signal ('RDFXX', 'Bad opcode in DB.DBA.SPARQL_INSERT_CTOR()');
        }
      -- dbg_obj_princ ('generated triple:', triple_vec);
      if (4 = fld_count)
        quads_found := 1;
      dict := _env [2 + ctor_op];
      dict_put (dict, triple_vec, 1);
      if (1 = ctor_op)
        {
--          delete from DB.DBA.RDF_QUAD
--          where G = _env[0] and S = triple_vec[0] and P = triple_vec[1] and O = DB.DBA.RDF_OBJ_OF_LONG(triple_vec[2]);
          if (80000 <= dict_size (dict))
            {
              if (quads_found)
                {
                  DB.DBA.RDF_DELETE_QUADS (_env[0], dict_list_keys (dict, 2), _env[8], _env[5]);
                  quads_found := 0;
                }
              else
                DB.DBA.RDF_DELETE_TRIPLES_AGG (_env[0], dict_list_keys (dict, 2), _env[5]);
            }
        }
      else
        {
--          insert soft DB.DBA.RDF_QUAD (G,S,P,O)
--          values (_env[0], triple_vec[0], triple_vec[1], DB.DBA.RDF_OBJ_OF_LONG(triple_vec[2]));
          if (80000 <= dict_size (dict))
            {
              if (quads_found)
                {
                  DB.DBA.RDF_INSERT_QUADS (_env[0], dict_list_keys (dict, 2), _env[8], _env[5]);
                  quads_found := 0;
                }
              else
                DB.DBA.RDF_INSERT_TRIPLES (_env[0], dict_list_keys (dict, 2), _env[5]);
            }
        }
      action_ctr := action_ctr + 1;
end_of_adding_triple: ;
    }
  _env[ctor_op] := _env[ctor_op] + action_ctr;
  _env[5 + ctor_op] := quads_found;
  log_enable (old_log_enable, 1);
}
;

--!AWK PUBLIC
create function DB.DBA.SPARQL_DELETE_CTOR_ACC (inout _env any, in graph_iri any, in opcodes any, in vars any, in uid integer, in log_mode integer)
{
  if (not (isarray (_env)))
--                  0                      1  2  3                 4     5         6  7  8
    _env := vector (iri_to_id (graph_iri), 0, 0, dict_new (80000), null, log_mode, 0, 0, uid);
  if (not _env[1])
    __rgs_assert_cbk (graph_iri, uid, 2, 'SPARUL DELETE');
  DB.DBA.SPARQL_INS_OR_DEL_CTOR_IMPL (_env, graph_iri, opcodes, vars, log_mode, 1);
}
;

--!AWK PUBLIC
create procedure DB.DBA.SPARQL_INSERT_CTOR_ACC (inout _env any, in graph_iri any, in opcodes any, in vars any, in uid integer, in log_mode integer)
{
  -- dbg_obj_princ ('DB.DBA.SPARQL_INSERT_CTOR_ACC (', _env, graph_iri, opcodes, vars, uid, log_mode);
  if (not (isarray (_env)))
--                  0                      1  2  3     4                 5         6  7  8
    _env := vector (iri_to_id (graph_iri), 0, 0, null, dict_new (80000), log_mode, 0, 0, uid);
  if (not _env[2])
    __rgs_assert_cbk (graph_iri, uid, 2, 'SPARUL INSERT');
  DB.DBA.SPARQL_INS_OR_DEL_CTOR_IMPL (_env, graph_iri, opcodes, vars, log_mode, 2);
}
;

--!AWK PUBLIC
create procedure DB.DBA.SPARQL_MODIFY_CTOR_ACC (inout _env any, in graph_iri any, in del_opcodes any, in ins_opcodes any, in vars any, in uid integer, in log_mode integer)
{
  if (not (isarray (_env)))
--                  0                      1  2  3                 4                 5         6  7  8
    _env := vector (iri_to_id (graph_iri), 0, 0, dict_new (80000), dict_new (80000), log_mode, 0, 0, uid);
  if (not _env[1] and not _env[2])
    __rgs_assert_cbk (graph_iri, uid, 2, 'SPARUL MODIFY');
  DB.DBA.SPARQL_INS_OR_DEL_CTOR_IMPL (_env, graph_iri, del_opcodes, vars, log_mode, 1);
  DB.DBA.SPARQL_INS_OR_DEL_CTOR_IMPL (_env, graph_iri, ins_opcodes, vars, log_mode, 2);
}
;

--!AWK PUBLIC
create procedure DB.DBA.SPARQL_INS_OR_DEL_OR_MODIFY_CTOR_FIN (inout _env any)
{
  if (isarray (_env))
    {
      declare dict any;
      dict := _env[3];
      if (dict is not null and (0 < dict_size (dict)))
        {
          _env[3] := null;
          if (_env[6])
            DB.DBA.RDF_DELETE_QUADS (_env[0], dict_list_keys (dict, 2), _env[8], _env[5]);
          else
            DB.DBA.RDF_DELETE_TRIPLES (_env[0], dict_list_keys (dict, 2), _env[5]);
        }
      dict := _env[4];
      if (dict is not null and (0 < dict_size (dict)))
        {
          _env[4] := null;
          if (_env[7])
            DB.DBA.RDF_INSERT_QUADS (_env[0], dict_list_keys (dict, 2), _env[8], _env[5]);
          else
            DB.DBA.RDF_INSERT_TRIPLES (_env[0], dict_list_keys (dict, 2), _env[5]);
        }
    }
  return _env;
}
;

--!AWK PUBLIC
create aggregate DB.DBA.SPARQL_DELETE_CTOR (in graph_iri any, in opcodes any, in vars any, in uid integer, in log_mode integer) returns any
from DB.DBA.SPARQL_INS_OR_DEL_OR_MODIFY_CTOR_INIT, DB.DBA.SPARQL_DELETE_CTOR_ACC, DB.DBA.SPARQL_INS_OR_DEL_OR_MODIFY_CTOR_FIN
;

--!AWK PUBLIC
create aggregate DB.DBA.SPARQL_INSERT_CTOR (in graph_iri any, in opcodes any, in vars any, in uid integer, in log_mode integer) returns any
from DB.DBA.SPARQL_INS_OR_DEL_OR_MODIFY_CTOR_INIT, DB.DBA.SPARQL_INSERT_CTOR_ACC, DB.DBA.SPARQL_INS_OR_DEL_OR_MODIFY_CTOR_FIN
;

--!AWK PUBLIC
create aggregate DB.DBA.SPARQL_MODIFY_CTOR (in graph_iri any, in del_opcodes any, in ins_opcodes any, in vars any, in uid integer, in log_mode integer) returns any
from DB.DBA.SPARQL_INS_OR_DEL_OR_MODIFY_CTOR_INIT, DB.DBA.SPARQL_MODIFY_CTOR_ACC, DB.DBA.SPARQL_INS_OR_DEL_OR_MODIFY_CTOR_FIN
;

create function DB.DBA.SPARQL_INSERT_DICT_CONTENT (in graph_iri any, in triples_dict any, in uid integer, in log_mode integer := null, in compose_report integer := 0) returns any
{
  declare triples any;
  declare ins_count integer;
  ins_count := 0;
  if (__tag of vector = __tag (graph_iri))
    {
      ins_count := graph_iri[2]; -- 2, not 1
      graph_iri := graph_iri[0]; -- the last op.
    }
  __rgs_assert_cbk (graph_iri, uid, 2, 'SPARUL INSERT');
  while (dict_size (triples_dict) > 0)
    {
      triples := dict_destructive_list_rnd_keys (triples_dict, 80000);
      DB.DBA.RDF_INSERT_TRIPLES (graph_iri, triples, log_mode);
      ins_count := ins_count + length (triples);
    }
  if (isiri_id (graph_iri))
    graph_iri := id_to_iri (graph_iri);
  if (graph_iri is not null and __rdf_graph_is_in_enabled_repl (iri_to_id (graph_iri)))
    repl_text ('__rdf_repl', '__rdf_repl_flush_queue ()');
  if (compose_report)
    {
      if (ins_count)
        return sprintf ('Insert into <%s>, %d (or less) triples -- done', graph_iri, ins_count);
      else
        return sprintf ('Insert into <%s>, 0 triples -- nothing to do', graph_iri);
    }
  else
    return ins_count;
}
;

create function DB.DBA.SPARQL_DELETE_DICT_CONTENT (in graph_iri any, in triples_dict any, in uid integer, in log_mode integer := null, in compose_report integer := 0) returns any
{
  declare triples any;
  declare del_count integer;
  del_count := 0;
  if (__tag of vector = __tag (graph_iri))
    {
      del_count := graph_iri[1];
      graph_iri := graph_iri[0]; -- the last op.
    }
  __rgs_assert_cbk (graph_iri, uid, 2, 'SPARUL DELETE');
  while (dict_size (triples_dict) > 0)
    {
      triples := dict_destructive_list_rnd_keys (triples_dict, 2000000);
      DB.DBA.RDF_DELETE_TRIPLES_AGG (graph_iri, triples, log_mode);
      del_count := del_count + length (triples);
    }
  if (isiri_id (graph_iri))
    graph_iri := id_to_iri (graph_iri);
  if (graph_iri is not null and __rdf_graph_is_in_enabled_repl (iri_to_id (graph_iri)))
    repl_text ('__rdf_repl', '__rdf_repl_flush_queue ()');
  if (compose_report)
    {
      if (del_count)
        return sprintf ('Delete from <%s>, %d (or less) triples -- done', graph_iri, del_count);
      else
        return sprintf ('Delete from <%s>, 0 triples -- nothing to do', graph_iri);
    }
  else
    return del_count;
}
;

create function DB.DBA.SPARQL_MODIFY_BY_DICT_CONTENTS (in graph_iri any, in del_triples_dict any, in ins_triples_dict any, in uid integer, in log_mode integer := null, in compose_report integer := 0) returns any
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
  __rgs_assert_cbk (graph_iri, uid, 2, 'SPARUL MODIFY');
  if (del_triples_dict is not null)
    {
      del_count := del_count + dict_size (del_triples_dict);
      DB.DBA.SPARQL_DELETE_DICT_CONTENT (graph_iri, del_triples_dict, uid, log_mode);
    }
  if (ins_triples_dict is not null)
    {
      ins_count := ins_count + dict_size (ins_triples_dict);
      DB.DBA.SPARQL_INSERT_DICT_CONTENT (graph_iri, ins_triples_dict, uid, log_mode);
    }
  if (isiri_id (graph_iri))
    graph_iri := id_to_iri (graph_iri);
  if (graph_iri is not null and __rdf_graph_is_in_enabled_repl (iri_to_id (graph_iri)))
    repl_text ('__rdf_repl', '__rdf_repl_flush_queue ()');
  if (compose_report)
    return sprintf ('Modify <%s>, delete %d (or less) and insert %d (or less) triples -- done', graph_iri, del_count, ins_count);
  else
    return del_count + ins_count;
}
;

-- /* delete quads */
create procedure DB.DBA.RDF_REPL_DEL (inout rquads any)
{
  declare rquads_ctr, rquads_count, opcode integer;
  declare g_iri, prev_g_iri varchar;
  declare g_iid varchar;
  declare ro_id_dict, app_env any;
  rquads_count := length (rquads);
  prev_g_iri := '';
  for (rquads_ctr := 0; rquads_ctr < rquads_count; rquads_ctr := rquads_ctr + 1)
    {
      -- dbg_obj_princ ('DB.DBA.RDF_REPL_DEL(), rquad ', rquads_ctr, ' / ', rquads_count, ': ', rquads[rquads_ctr]);
      g_iri := rquads[rquads_ctr][1];
      if (g_iri <> prev_g_iri)
        {
          g_iid := iri_to_id (g_iri);
          --DB.DBA.TTLP_EV_CL_GS_NEW_GRAPH (g_iri, g_iid, app_env);
          prev_g_iri := g_iri;
        }
      opcode := rquads[rquads_ctr][0];
      if (0 = opcode)
	{
          delete from DB.DBA.RDF_QUAD
	      where G = g_iid and S = iri_to_id_repl (rquads[rquads_ctr][2]) and P = iri_to_id_repl (rquads[rquads_ctr][3])
	      and O = DB.DBA.RDF_MAKE_OBJ_OF_SQLVAL (rquads[rquads_ctr][4]);
	  if (__rdf_graph_is_in_enabled_repl (g_iid))
	    __rdf_repl_quad (160 + opcode, g_iri, rquads[rquads_ctr][2], rquads[rquads_ctr][3], rquads[rquads_ctr][4]);
	}
      else if (1 = opcode)
	{
	  declare obj any;
	  if (isgeometry (rquads[rquads_ctr][4]))
	    {
	      obj := rdf_box (rquads[rquads_ctr][4], 256, 257, 0, 1);
	      rdf_geo_set_id (obj);
	    }
	  else
	    obj := DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL (rquads[rquads_ctr][4], iri_to_id_repl (rquads[rquads_ctr][5]), null);
	  delete from DB.DBA.RDF_QUAD
	      where G = g_iid and S = iri_to_id_repl (rquads[rquads_ctr][2]) and P = iri_to_id_repl (rquads[rquads_ctr][3]) and O = obj;
	  if (__rdf_graph_is_in_enabled_repl (g_iid))
	    __rdf_repl_quad (160 + opcode, g_iri, rquads[rquads_ctr][2], rquads[rquads_ctr][3], rquads[rquads_ctr][4], rquads[rquads_ctr][5], null);
	}
      else if (2 = opcode)
	{
	  delete from DB.DBA.RDF_QUAD
	      where G = g_iid and S = iri_to_id_repl (rquads[rquads_ctr][2]) and P = iri_to_id_repl (rquads[rquads_ctr][3])
	      and O = DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL (rquads[rquads_ctr][4], null, rquads[rquads_ctr][5]);
	  if (__rdf_graph_is_in_enabled_repl (g_iid))
	    __rdf_repl_quad (160 + opcode, g_iri, rquads[rquads_ctr][2], rquads[rquads_ctr][3], rquads[rquads_ctr][4], null, rquads[rquads_ctr][5]);
	}
      else if (4 = opcode)
	{
	  delete from DB.DBA.RDF_QUAD
	      where G = g_iid and S = iri_to_id_repl (rquads[rquads_ctr][2]) and P = iri_to_id_repl (rquads[rquads_ctr][3])
	      and O = iri_to_id_repl (rquads[rquads_ctr][4]);
	  if (__rdf_graph_is_in_enabled_repl (g_iid))
	    __rdf_repl_quad (160 + opcode, g_iri, rquads[rquads_ctr][2], rquads[rquads_ctr][3], rquads[rquads_ctr][4]);
	}


    }
  app_env := vector (1, null);
  DB.DBA.TTLP_EV_COMMIT (g_iri, app_env);
  --if (1 <> sys_stat ('cl_run_local_only'))
  --  rdf_dpipe_flush_gs (app_env, 1);
  connection_set ('g_dict', null);
  commit work;
}
;

--#IF VER=5
--!AFTER
--#ENDIF
create function DB.DBA.SPARUL_CLEAR (in graph_iris any, in inside_sponge integer, in uid integer := 0, in log_mode integer := null, in compose_report integer := 0, in options any := null, in silent integer := 0) returns any
{
  declare g_iid IRI_ID;
  declare old_log_enable integer;
  declare txtreport varchar;
  txtreport := '';
  if (__tag of vector <> __tag (graph_iris))
    graph_iris := vector (graph_iris);
  foreach (any g_iri in graph_iris) do
    {
      if (isiri_id (g_iri))
        g_iri := id_to_iri (g_iri);
      g_iid := iri_to_id (g_iri);
      __rgs_assert_cbk (g_iri, uid, 2, 'SPARUL CLEAR GRAPH');
    }
  foreach (any g_iri in graph_iris) do
    {
      if (isiri_id (g_iri))
        g_iri := id_to_iri (g_iri);
      g_iid := iri_to_id (g_iri);
      if (__rdf_graph_is_in_enabled_repl (g_iid))
        {
          repl_text ('__rdf_repl', '__rdf_repl_flush_queue()');
          repl_text ('__rdf_repl', 'sparql define input:storage "" clear graph iri ( ?? )', g_iri);
        }
      old_log_enable := log_enable (log_mode, 1);
      declare exit handler for sqlstate '*' { log_enable (old_log_enable, 1); resignal; };
      exec (sprintf ('
      delete from DB.DBA.RDF_QUAD
      where G = __i2id (''%S'') ', g_iri));
      delete from DB.DBA.RDF_QUAD table option (index RDF_QUAD_GS, index_only) where G = iri_to_id (g_iri, 0)  option (index_only, index RDF_QUAD_GS);
      delete from DB.DBA.RDF_OBJ_RO_FLAGS_WORDS where VT_WORD = rdf_graph_keyword (g_iid);
      if (not inside_sponge)
        {
          delete from DB.DBA.SYS_HTTP_SPONGE where HS_LOCAL_IRI = g_iri;
          delete from DB.DBA.SYS_HTTP_SPONGE where HS_LOCAL_IRI like concat ('destMD5=', md5 (g_iri), '&graphMD5=%');
        }
      if (compose_report)
        {
          if (txtreport <> '')
            txtreport := txtreport || '\n';
          txtreport := txtreport || sprintf ('Clear graph <%s> -- done', g_iri);
        }
    }
  /*091202 commit work; */
  log_enable (old_log_enable, 1);
  if (compose_report)
    return txtreport;
  return 1;
}
;

create function DB.DBA.SPARUL_LOAD (in graph_iri any, in resource varchar, in uid integer, in log_mode integer, in compose_report integer, in options any := null, in silent integer := 0) returns any
{
  declare old_log_enable integer;
  declare grab_params any;
  declare grabbed any;
  declare res integer;
  __rgs_assert_cbk (graph_iri, uid, 2, 'SPARUL LOAD');
  old_log_enable := log_enable (log_mode, 1);
  declare exit handler for sqlstate '*' { log_enable (old_log_enable, 1); if (silent) goto fail; resignal; };
  grabbed := dict_new();
  if (isiri_id (graph_iri))
    graph_iri := id_to_iri (graph_iri);
  grab_params := vector_concat (vector (
      'base_iri', resource,
      'get:destination', graph_iri,
      'get:soft', get_keyword ('get:soft', options, 'replacing'),
      'get:refresh', get_keyword ('get:refresh', options, -1),
      'get:error-recovery', get_keyword ('get:error-recovery', options, 'signal'),
      -- 'flags', flags,
      'get:strategy', get_keyword ('get:strategy', options, 'rdfa-only'),
      'get:private', get_keyword ('get:private', options, null),
      'grabbed', grabbed ),
    options );
  commit work;
  res := DB.DBA.RDF_GRAB_SINGLE (resource, grabbed, grab_params);
  commit work;
  log_enable (old_log_enable, 1);
  if (res)
    {
      if (compose_report)
        return sprintf ('Load <%s> into graph <%s> -- done', resource, graph_iri);
      else
        return 1;
    }
  else
    {
      if (compose_report)
        return sprintf ('Load <%s> into graph <%s> -- failed', resource, graph_iri);
      else
        return 0;
    }
fail:
  if (compose_report)
    return sprintf ('Load silent <%s> into graph <%s> -- failed: %s: %s', resource, graph_iri, __SQL_STATE, __SQL_MESSAGE);
  else
    return 0;
}
;

create function DB.DBA.SPARUL_LOAD_SERVICE_DATA (in service_iri any, in proxy_iri varchar, in uid integer, in log_mode integer, in compose_report integer, in options any := null, in silent integer := 0) returns any
{
  declare old_log_enable integer;
  declare mdta, rows any;
  declare stat, msg varchar;
  __rgs_assert_cbk (service_iri, uid, 2, 'SPARUL LOAD SERVICE DATA');
  -- dbg_obj_princ ('DB.DBA.SPARUL_LOAD_SERVICE_DATA (', service_iri, proxy_iri, uid, log_mode, compose_report, options, silent, ')');
  old_log_enable := log_enable (log_mode, 1);
  stat := '00000';
  exec ('DB.DBA.SPARQL_SD_PROBE (?, ?, 0, 0)', stat, msg, vector (service_iri, proxy_iri), 10000, mdta, rows);
  log_enable (old_log_enable, 1);
  if (stat <> '00000')
    {
      if (not silent) signal (stat, msg);
      if (compose_report)
        return sprintf ('Load service <%s> data failed: %s: %s', service_iri, stat, msg);
      else
        return 0;
    }
  if (compose_report)
    {
      if (length (rows))
        return sprintf ('Load service <%s> data -- done. %s', service_iri, rows[length(rows)-1][1]);
      else
        return sprintf ('Load service <%s> data -- nothing done', service_iri);
    }
  else
    return 1;
}
;

create function DB.DBA.SPARUL_CREATE (in graph_iri any, in silent1 integer, in uid integer, in log_mode integer, in compose_report integer, in options any := null, in silent integer := 0) returns any
{
  declare g_iid IRI_ID;
  declare old_log_enable integer;
  __rgs_assert_cbk (graph_iri, uid, 2, 'SPARUL CREATE GRAPH');
  g_iid := iri_to_id (graph_iri);
  if (__rdf_graph_is_in_enabled_repl (g_iid))
    repl_text ('__rdf_repl', 'sparql define input:storage "" create graph iri ( ?? )', graph_iri);
  if ((silent1 is not null) and silent1)
    silent := 1;
  if (exists (select top 1 1 from DB.DBA.RDF_EXPLICITLY_CREATED_GRAPH where REC_GRAPH_IID = g_iid))
    {
      if (silent)
        {
          if (compose_report)
            return sprintf ('Create silent graph <%s> -- already exists', graph_iri);
          else
            return 0;
        }
      else
        signal ('22023', 'SPARUL_CREATE() failed: graph <' || graph_iri || '> has been explicitly created before');
    }
  if (silent)
    {
      old_log_enable := log_enable (log_mode, 1);
      declare exit handler for sqlstate '*' { log_enable (old_log_enable, 1); resignal; };
      insert soft DB.DBA.RDF_EXPLICITLY_CREATED_GRAPH (REC_GRAPH_IID) values (iri_to_id (graph_iri));
      /*091202 commit work; */
      log_enable (old_log_enable, 1);
      if (compose_report)
        return sprintf ('Create silent graph <%s> -- done', graph_iri);
      else
        return 1;
    }
  if (exists (select top 1 1 from DB.DBA.RDF_QUAD where G = iri_to_id (graph_iri)))
    signal ('22023', 'SPARUL_CREATE() failed: graph <' || graph_iri || '> contains triples already');
  if (exists (sparql define input:storage ""
    ask from <http://www.openlinksw.com/schemas/virtrdf#>
    where { ?qmv virtrdf:qmGraphRange-rvrFixedValue `iri(?:graph_iri)` } ) )
    signal ('22023', 'SPARUL_CREATE() failed: graph <' || graph_iri || '> is used for mapping relational data to RDF');
  old_log_enable := log_enable (log_mode, 1);
  declare exit handler for sqlstate '*' { log_enable (old_log_enable, 1); resignal; };
  insert soft DB.DBA.RDF_EXPLICITLY_CREATED_GRAPH (REC_GRAPH_IID) values (iri_to_id (graph_iri));
  /*091202 commit work; */
  log_enable (old_log_enable, 1);
  if (compose_report)
    return sprintf ('Create graph <%s> -- done', graph_iri);
  else
    return 1;
}
;

create function DB.DBA.SPARUL_DROP (in graph_iris any, in silent1 integer, in uid integer, in log_mode integer, in compose_report integer, in options any := null, in silent integer := 0) returns any
{
  declare g_iid IRI_ID;
  declare old_log_enable integer;
  declare txtreport varchar;
  txtreport := '';
  if ((silent1 is not null) and silent1)
    silent := 1;
  if (__tag of vector <> __tag (graph_iris))
    graph_iris := vector (graph_iris);
  foreach (any g_iri in graph_iris) do
    {
      if (isiri_id (g_iri))
        g_iri := id_to_iri (g_iri);
      g_iid := iri_to_id (g_iri);
      __rgs_assert_cbk (g_iri, uid, 2, 'SPARUL DROP GRAPH');
    }
  foreach (any g_iri in graph_iris) do
    {
      if (isiri_id (g_iri))
        g_iri := id_to_iri (g_iri);
      g_iid := iri_to_id (g_iri);
      if (__rdf_graph_is_in_enabled_repl (g_iid))
        {
          repl_text ('__rdf_repl', '__rdf_repl_flush_queue()');
          repl_text ('__rdf_repl', 'sparql define input:storage "" drop graph iri ( ?? )', g_iri);
        }
      old_log_enable := log_enable (log_mode, 1);
      declare exit handler for sqlstate '*' { log_enable (old_log_enable, 1); resignal; };
      if (not exists (select top 1 1 from DB.DBA.RDF_EXPLICITLY_CREATED_GRAPH where REC_GRAPH_IID = g_iid))
        {
          if (silent)
            {
              if (exists (select top 1 1 from DB.DBA.RDF_QUAD where G = g_iid))
                {
                  DB.DBA.SPARUL_CLEAR (g_iri, 0, uid);
                  log_enable (old_log_enable, 1);
                  if (compose_report)
                    return sprintf ('Drop silent graph <%s> -- graph has not been explicitly created before, triples were removed', g_iri);
                  else
                    return 2;
                }
              if (compose_report)
                return sprintf ('Drop silent graph <%s> -- nothing to do', g_iri);
              else
                return 0;
            }
          else
            signal ('22023', 'SPARUL_DROP() failed: graph <' || g_iri || '> has not been explicitly created before');
        }
      if (silent)
        {
          DB.DBA.SPARUL_CLEAR (g_iri, 0, uid);
          delete from DB.DBA.RDF_EXPLICITLY_CREATED_GRAPH where REC_GRAPH_IID = g_iid;
          /*091202 commit work; */
          log_enable (old_log_enable, 1);
          if (compose_report)
            return sprintf ('Drop silent graph <%s> -- done', g_iri);
          else
            return 1;
        }
      if (exists (sparql define input:storage ""
        ask from <http://www.openlinksw.com/schemas/virtrdf#>
        where { ?qmv virtrdf:qmGraphRange-rvrFixedValue `iri(?:g_iri)` } ) )
        signal ('22023', 'SPARUL_DROP() failed: graph <' || g_iri || '> is used for mapping relational data to RDF');
      DB.DBA.SPARUL_CLEAR (g_iri, 0, uid);
      delete from DB.DBA.RDF_EXPLICITLY_CREATED_GRAPH where REC_GRAPH_IID = g_iid;
      if (compose_report)
        {
          if (txtreport <> '')
            txtreport := txtreport || '\n';
          txtreport := txtreport || sprintf ('Drop graph <%s> -- done', g_iri);
        }
    }
  log_enable (old_log_enable, 1);
  /*091202 commit work; */
  if (compose_report)
    return txtreport;
  return 1;
}
;

create function DB.DBA.SPARUL_RUN (in results any, in compose_report integer := 0) returns any
{
  --commit work;
  if (compose_report)
    {
      declare ses any;
      ses := string_output ();
      foreach (varchar r in results) do
        {
          http (cast (r as varchar) || '\n', ses);
        }
      http ('Commit -- done\n', ses);
      return string_output_string (ses);
    }
  else
    {
      declare res integer;
      res := 0;
      foreach (integer c in results) do
        {
          res := res + c;
        }
      return res;
   }
}
;

-- SPARQL 1.1 BINDINGS

--!AWK PUBLIC
create procedure DB.DBA.SPARQL_BINDINGS_VIEW_IMP (in dta any)
{
  declare rcount, rctr integer;
  declare BND any;
  result_names (BND);
  rcount := length (dta);
  for (rctr := 0; rctr < rcount; rctr := rctr+1)
    result (dta[rctr]);
}
;

create procedure view DB.DBA.SPARQL_BINDINGS_VIEW as DB.DBA.SPARQL_BINDINGS_VIEW_IMP (dta) (BND any)
;

grant select on DB.DBA.SPARQL_BINDINGS_VIEW to public
;

--!AWK PUBLIC
create procedure DB.DBA.SPARQL_BINDINGS_VIEW_C1_IMP (in dta any)
{
  declare rcount, rctr integer;
  declare BND0 any;
  result_names (BND0);
  rcount := length (dta);
  for (rctr := 0; rctr < rcount; rctr := rctr+1)
    result (dta[rctr][0]);
}
;

--!AWK PUBLIC
create procedure DB.DBA.SPARQL_BINDINGS_VIEW_C2_IMP (in dta any)
{
  declare rcount, rctr integer;
  declare BND0, BND1 any;
  result_names (BND0, BND1);
  rcount := length (dta);
  for (rctr := 0; rctr < rcount; rctr := rctr+1)
    result (dta[rctr][0], dta[rctr][1]);
}
;

--!AWK PUBLIC
create procedure DB.DBA.SPARQL_BINDINGS_VIEW_C3_IMP (in dta any)
{
  declare rcount, rctr integer;
  declare BND0, BND1, BND2 any;
  result_names (BND0, BND1, BND2);
  rcount := length (dta);
  for (rctr := 0; rctr < rcount; rctr := rctr+1)
    result (dta[rctr][0], dta[rctr][1], dta[rctr][2]);
}
;

--!AWK PUBLIC
create procedure DB.DBA.SPARQL_BINDINGS_VIEW_C4_IMP (in dta any)
{
  declare rcount, rctr integer;
  declare BND0, BND1, BND2, BND3 any;
  result_names (BND0, BND1, BND2, BND3);
  rcount := length (dta);
  for (rctr := 0; rctr < rcount; rctr := rctr+1)
    result (dta[rctr][0], dta[rctr][1], dta[rctr][2], dta[rctr][3]);
}
;

create procedure view DB.DBA.SPARQL_BINDINGS_VIEW_C1 as DB.DBA.SPARQL_BINDINGS_VIEW_C1_IMP (dta) (BND0 any)
;

create procedure view DB.DBA.SPARQL_BINDINGS_VIEW_C2 as DB.DBA.SPARQL_BINDINGS_VIEW_C1_IMP (dta) (BND0 any, BND1 any)
;

create procedure view DB.DBA.SPARQL_BINDINGS_VIEW_C3 as DB.DBA.SPARQL_BINDINGS_VIEW_C1_IMP (dta) (BND0 any, BND1 any, BND2 any)
;

create procedure view DB.DBA.SPARQL_BINDINGS_VIEW_C4 as DB.DBA.SPARQL_BINDINGS_VIEW_C1_IMP (dta) (BND0 any, BND1 any, BND2 any, BND3 any)
;

grant select on DB.DBA.SPARQL_BINDINGS_VIEW_C1 to public
;

grant select on DB.DBA.SPARQL_BINDINGS_VIEW_C2 to public
;

grant select on DB.DBA.SPARQL_BINDINGS_VIEW_C3 to public
;

grant select on DB.DBA.SPARQL_BINDINGS_VIEW_C4 to public
;


-- SPARQL 1.1 UPDATE functions
create procedure DB.DBA.RDF_INSERT_QUADS (in dflt_graph_iri any, inout quads any, in uid integer, in log_mode integer := null) returns any
{
  declare groups any;
  declare group_ctr, group_count integer;
  declare qtst, all_sv, all_pv, all_ov, all_gv, repl_sv, repl_pv, repl_ov, repl_gv any;
  qtst := quads;
  __rgs_prepare_del_or_ins (qtst, uid, dflt_graph_iri, all_sv, all_pv, all_ov, all_gv, repl_sv, repl_pv, repl_ov, repl_gv);
  rowvector_graph_sort (quads, 3, 1);
  groups := rowvector_graph_partition (quads, 3);
  group_count := length (groups);
  for (group_ctr := 0; group_ctr < group_count; group_ctr := group_ctr+1)
    {
      declare g_group, g any;
      g_group := aref_set_0 (groups, group_ctr);
      g := aref_or_default (g_group, 0, 3, dflt_graph_iri);
      __rgs_assert_cbk (g, uid, 2, 'SPARQL 1.1 INSERT');
      DB.DBA.RDF_INSERT_TRIPLES (g, g_group, log_mode);
      if (isiri_id (g))
        g := id_to_iri (g);
      if (g is not null and __rdf_graph_is_in_enabled_repl (iri_to_id (g)))
        repl_text ('__rdf_repl', '__rdf_repl_flush_queue ()');
    }
}
;

create function DB.DBA.RDF_DELETE_QUADS (in dflt_graph_iri any, inout quads any, in uid integer, in log_mode integer := null) returns any
{
  declare groups any;
  declare group_ctr, group_count integer;
  declare old_log_enable integer;
  old_log_enable := log_enable (log_mode, 1);
  declare exit handler for sqlstate '*' { log_enable (old_log_enable, 1); resignal; };
  declare repl_quads any array;
  declare all_sv, all_pv, all_ov, all_gv, repl_sv, repl_pv, repl_ov, repl_gv any;
  -- dbg_obj_princ ('__rgs_prepare_del_or_ins (', quads, uid, dflt_graph_iri, ') formed the following:');
  __rgs_prepare_del_or_ins (quads, uid, dflt_graph_iri, all_sv, all_pv, all_ov, all_gv, repl_sv, repl_pv, repl_ov, repl_gv);
  for vectored (in a_s any array := all_sv, in a_p any array := all_pv, in a_o any array := all_ov, in a_g any array := all_gv)
    {
      declare o_val any array;
      declare o_dt_and_lang_twobyte integer;
      if (not isinteger (a_g))
        {
          if (not isiri_id (a_s))
            a_s := __i2idn (a_s);
          if (not isiri_id (a_p))
            a_p := __i2idn (a_p);
          if (isiri_id (a_s) and isiri_id (a_p))
            {
              if (isiri_id (a_o))
                delete from DB.DBA.RDF_QUAD where G = a_g and S = a_s and P = a_p and O = a_o;
              else
                {
                  declare o_val any array;
                  declare o_dt_and_lang_twobyte integer;
                  declare search_fields_are_ok integer;
                  search_fields_are_ok := __rdf_box_to_ro_id_search_fields (a_o, o_val, o_dt_and_lang_twobyte);
                  -- dbg_obj_princ ('__rdf_box_to_ro_id_search_fields (', a_o, ') returned ', search_fields_are_ok, o_val, o_dt_and_lang_twobyte);
                  if (search_fields_are_ok)
                    delete from DB.DBA.RDF_QUAD where G = a_g and S = a_s and P = a_p and O = (select rdf_box_from_ro_id(RO_ID) from DB.DBA.RDF_OBJ where RO_VAL = o_val and RO_DT_AND_LANG = o_dt_and_lang_twobyte);
                  else if (isstring (a_o)) /* it should be string IRI otherwise it's in RDF_OBJ */
                    delete from DB.DBA.RDF_QUAD where G = a_g and S = a_s and P = a_p and O = iri_to_id (a_o);
                  else
                    delete from DB.DBA.RDF_QUAD where G = a_g and S = a_s and P = a_p and O = a_o;
                }
            }
        }
    }
  if (0 < length (repl_sv))
    {
      for vectored (in r_s any array := repl_sv, in r_p any array := repl_pv, in r_o any array := repl_ov, in r_g any array := repl_gv, out repl_quads := r_q)
        {
          declare r_q, r_o any array;
          declare r_g_iri, r_s_iri, r_p_iri varchar;
          r_g_iri := iri_canonicalize (__id2in (r_q[3]));
          r_s_iri := iri_canonicalize (__id2in (r_q[0]));
          r_p_iri := iri_canonicalize (__id2in (r_q[1]));
          r_o := r_q[2];
          if (isiri_id (r_o) or (__tag (r_o) = 217) or ((__tag (r_o) = __tag of varchar) and bit_and (1, __box_flags (r_o))))
            r_q := vector (r_g_iri, r_s_iri, r_p_iri, iri_canonicalize (__id2in (r_o)));
          else
            r_q := vector (r_g_iri, r_s_iri, r_p_iri, __ro2sq (r_o));
        }
      repl_text ('__rdf_repl', 'DB.DBA.RDF_REPL_DELETE_QUADS (?)', repl_quads);
    }
  log_enable (old_log_enable, 1);
}
;


create function DB.DBA.SPARQL_INSERT_QUAD_DICT_CONTENT (in dflt_graph_iri any, in quads_dict any, in uid integer, in log_mode integer := null, in compose_report integer := 0) returns any
{
  declare ins_count, ins_grp_count integer;
  declare res_ses any;
  ins_count := 0;
  ins_grp_count := 0;
  if (__tag of vector = __tag (dflt_graph_iri))
    {
      ins_count := dflt_graph_iri[2]; -- 2, not 1
      dflt_graph_iri := dflt_graph_iri[0]; -- the last op.
    }
  while (dict_size (quads_dict) > 0)
    {
      declare quads, groups any;
      declare group_ctr, group_count, g_ins_count integer;
      quads := dict_destructive_list_rnd_keys (quads_dict, 80000);

      declare qtst, all_sv, all_pv, all_ov, all_gv, repl_sv, repl_pv, repl_ov, repl_gv any;
      qtst := quads;
      -- dbg_obj_princ ('__rgs_prepare_del_or_ins (', qtst, uid, dflt_graph_iri, ') formed the following:');
      __rgs_prepare_del_or_ins (qtst, uid, dflt_graph_iri, all_sv, all_pv, all_ov, all_gv, repl_sv, repl_pv, repl_ov, repl_gv);
      -- dbg_obj_princ ('All items:');
      --for vectored (in a_s any array := all_sv, in a_p any array := all_pv, in a_o any array := all_ov, in a_g any array := all_gv) {
        -- dbg_obj_princ (a_s, a_p, a_o, a_g);
        --}
      -- dbg_obj_princ ('Replication items:');
      --for vectored (in r_s any array := repl_sv, in r_p any array := repl_pv, in r_o any array := repl_ov, in r_g any array := repl_gv) {
        -- dbg_obj_princ (r_s, r_p, r_o, r_g);
      --}

      rowvector_graph_sort (quads, 3, 1);
      groups := rowvector_graph_partition (quads, 3);
      group_count := length (groups);
      for (group_ctr := 0; group_ctr < group_count; group_ctr := group_ctr+1)
        {
          declare g_group, g any;
          g_group := aref_set_0 (groups, group_ctr);
          g := aref_or_default (g_group, 0, 3, dflt_graph_iri);
          __rgs_assert_cbk (g, uid, 2, 'SPARQL 1.1 INSERT');
          DB.DBA.RDF_INSERT_TRIPLES (g, g_group, log_mode);
          g_ins_count := length (g_group);
          ins_count := ins_count + g_ins_count;
          ins_grp_count := ins_grp_count + 1;
          if (isiri_id (g))
            g := id_to_iri (g);
          if (g is not null and __rdf_graph_is_in_enabled_repl (iri_to_id (g)))
            repl_text ('__rdf_repl', '__rdf_repl_flush_queue ()');
          if (compose_report and ins_grp_count < 1000)
            {
              if (group_ctr)
                http ('\n', res_ses);
              else
                res_ses := string_output();
              http (sprintf ('Insert into <%s>, %d (or less) quads -- done', g, g_ins_count), res_ses);
            }
        }
    }
  if (compose_report)
    {
      if (ins_grp_count >= 1000)
        return sprintf ('Insert into %d (or more) graphs, total %d (or less) quads -- done', ins_grp_count, ins_count);
      if (ins_count)
        return string_output_string (res_ses);
      else
        return sprintf ('Insert into <%s>, 0 quads -- nothing to do', dflt_graph_iri);
    }
  else
    return ins_count;
}
;

create function DB.DBA.SPARQL_DELETE_QUAD_DICT_CONTENT (in dflt_graph_iri any, in quads_dict any, in uid integer, in log_mode integer := null, in compose_report integer := 0) returns any
{
  declare del_count, del_grp_count integer;
  declare res_ses any;
  del_count := 0;
  declare old_log_enable integer;
  old_log_enable := log_enable (log_mode, 1);
  declare exit handler for sqlstate '*' { log_enable (old_log_enable, 1); resignal; };
  if (__tag of vector = __tag (dflt_graph_iri))
    {
      del_count := dflt_graph_iri[1]; -- 1 for del count
      dflt_graph_iri := dflt_graph_iri[0]; -- the last op.
    }
  while (dict_size (quads_dict) > 0)
    {
      declare quads, groups any;
      declare group_ctr, group_count, g_del_count integer;
      declare repl_quads any array;
      quads := dict_destructive_list_rnd_keys (quads_dict, 80000);
      declare all_sv, all_pv, all_ov, all_gv, repl_sv, repl_pv, repl_ov, repl_gv any;
      -- dbg_obj_princ ('__rgs_prepare_del_or_ins (', quads, uid, dflt_graph_iri, ') formed the following:');
      __rgs_prepare_del_or_ins (quads, uid, dflt_graph_iri, all_sv, all_pv, all_ov, all_gv, repl_sv, repl_pv, repl_ov, repl_gv);
      for vectored (in a_s any array := all_sv, in a_p any array := all_pv, in a_o any array := all_ov, in a_g any array := all_gv)
        {
          declare o_val any array;
          declare o_dt_and_lang_twobyte integer;
          if (not isinteger (a_g))
            {
              if (not isiri_id (a_s))
                a_s := __i2idn (a_s);
              if (not isiri_id (a_p))
                a_p := __i2idn (a_p);
              if (isiri_id (a_s) and isiri_id (a_p))
                {
                  if (isiri_id (a_o))
                    delete from DB.DBA.RDF_QUAD where G = a_g and S = a_s and P = a_p and O = a_o;
              else
                    {
                      declare o_val any array;
                      declare o_dt_and_lang_twobyte integer;
                      declare search_fields_are_ok integer;
                      search_fields_are_ok := __rdf_box_to_ro_id_search_fields (a_o, o_val, o_dt_and_lang_twobyte);
                      -- dbg_obj_princ ('__rdf_box_to_ro_id_search_fields (', a_o, ') returned ', search_fields_are_ok, o_val, o_dt_and_lang_twobyte);
                      if (search_fields_are_ok)
                        delete from DB.DBA.RDF_QUAD where G = a_g and S = a_s and P = a_p and O = (select rdf_box_from_ro_id(RO_ID) from DB.DBA.RDF_OBJ where RO_VAL = o_val and RO_DT_AND_LANG = o_dt_and_lang_twobyte);
                      else if (isstring (a_o)) /* it should be string IRI otherwise it's in RDF_OBJ */
                        delete from DB.DBA.RDF_QUAD where G = a_g and S = a_s and P = a_p and O = iri_to_id (a_o);
                      else
                        delete from DB.DBA.RDF_QUAD where G = a_g and S = a_s and P = a_p and O = a_o;
            }
        }
    }
        }
      if (0 < length (repl_sv))
        {
          for vectored (in r_s any array := repl_sv, in r_p any array := repl_pv, in r_o any array := repl_ov, in r_g any array := repl_gv, out repl_quads := r_q)
            {
              declare r_q, r_o any array;
              declare r_g_iri, r_s_iri, r_p_iri varchar;
              r_g_iri := iri_canonicalize (__id2in (r_q[3]));
              r_s_iri := iri_canonicalize (__id2in (r_q[0]));
              r_p_iri := iri_canonicalize (__id2in (r_q[1]));
              r_o := r_q[2];
              if (isiri_id (r_o) or (__tag (r_o) = 217) or ((__tag (r_o) = __tag of varchar) and bit_and (1, __box_flags (r_o))))
                r_q := vector (r_g_iri, r_s_iri, r_p_iri, iri_canonicalize (__id2in (r_o)));
              else
                r_q := vector (r_g_iri, r_s_iri, r_p_iri, __ro2sq (r_o));
            }
          repl_text ('__rdf_repl', 'DB.DBA.RDF_REPL_DELETE_QUADS (?)', repl_quads);
        }
      del_count := del_count + length (quads);
    }
  log_enable (old_log_enable, 1);
  if (compose_report)
    {
      if (del_count)
        return sprintf ('Delete %d (or less) quads -- done', del_count);
      else
        return sprintf ('Delete from <%s>, 0 quads -- nothing to do', dflt_graph_iri);
    }
  else
    return del_count;
}
;

create function DB.DBA.SPARQL_MODIFY_BY_QUAD_DICT_CONTENTS (in dflt_graph_iri any, in del_quads_dict any, in ins_quads_dict any, in uid integer, in log_mode integer := null, in compose_report integer := 0) returns any
{
  declare del_count, ins_count integer;
  declare del_rep, ins_rep any;
  del_count := 0;
  ins_count := 0;
  if (__tag of vector = __tag (dflt_graph_iri))
    {
      del_count := dflt_graph_iri[1];
      ins_count := dflt_graph_iri[2];
      dflt_graph_iri := dflt_graph_iri[0]; -- the last op.
    }
  if (del_quads_dict is not null)
    {
      del_count := del_count + dict_size (del_quads_dict);
      del_rep := DB.DBA.SPARQL_DELETE_QUAD_DICT_CONTENT (dflt_graph_iri, del_quads_dict, uid, log_mode, compose_report);
    }
  else if (compose_report)
    del_rep := '';
  else
    del_rep := 0;
  if (ins_quads_dict is not null)
    {
      ins_count := ins_count + dict_size (ins_quads_dict);
      ins_rep := DB.DBA.SPARQL_INSERT_QUAD_DICT_CONTENT (dflt_graph_iri, ins_quads_dict, uid, log_mode, compose_report);
    }
  else if (compose_report)
    ins_rep := '';
  else
    ins_rep := 0;
  if (compose_report)
    return concat (del_rep, case when ins_rep <> '' and del_rep <> '' then '\n' else '' end, ins_rep);
  else
    return del_count + ins_count;
}
;

create function DB.DBA.SPARUL_COPYMOVEADD_IMPL (in opname varchar, in src_g_iri any, in tgt_g_iri any, in uid integer := 0, in log_mode integer := null, in compose_report integer := 0, in options any := null, in silent integer := 0) returns any
{
  declare src_g_iid IRI_ID;
  declare tgt_g_iid IRI_ID;
  declare old_log_enable, src_repl, tgt_repl integer;
  declare qry, stat, msg varchar;
  if (isiri_id (src_g_iri))
    src_g_iri := id_to_iri (src_g_iri);
  src_g_iid := iri_to_id (src_g_iri);
  if (isiri_id (tgt_g_iri))
    tgt_g_iri := id_to_iri (tgt_g_iri);
  tgt_g_iid := iri_to_id (tgt_g_iri);
  __rgs_assert_cbk (tgt_g_iri, uid, 2, 'SPARQL 1.1 ' || opname);
  __rgs_assert_cbk (src_g_iri, uid, case (opname) when 'MOVE' then 2 else 1 end, 'SPARQL 1.1 ' || opname);
  if (src_g_iid = tgt_g_iid)
    {
      if (compose_report)
        return sprintf ('%s <%s> to itself -- nothing to do', opname, src_g_iri);
      return 1;
    }
  src_repl := __rdf_graph_is_in_enabled_repl (src_g_iid);
  tgt_repl := __rdf_graph_is_in_enabled_repl (tgt_g_iid);
  if (src_repl and not tgt_repl)
    signal ('22023', sprintf ('SPARQL 1.1 can not %s replicated graph <%s> to non-replicated graph <%s>, both should be in same replication status', src_g_iri, tgt_g_iri));
  if (tgt_repl and not src_repl)
    signal ('22023', sprintf ('SPARQL 1.1 can not %s non-replicated graph <%s> to replicated graph <%s>, both should be in same replication status', src_g_iri, tgt_g_iri));
  if ('ADD' <> opname)
    DB.DBA.SPARUL_CLEAR (tgt_g_iri, 0, uid, log_mode, 0, options, silent);
  if (src_repl and tgt_repl)
    {
      repl_text ('__rdf_repl', '__rdf_repl_flush_queue()');
      repl_text ('__rdf_repl', 'sparql define input:storage "" add iri( ?? ) to iri( ?? )', src_g_iri, tgt_g_iri);
    }
  old_log_enable := log_enable (log_mode, 1);
  declare exit handler for sqlstate '*' { log_enable (old_log_enable, 1); resignal; };
  stat := '00000';
  qry := sprintf ('insert soft DB.DBA.RDF_QUAD (G,S,P,O) select __i2id (''%S''), t.S, t.P, t.O from DB.DBA.RDF_QUAD t where t.G = __i2id (''%S'') ',
     tgt_g_iri, src_g_iri );
  exec (qry, stat, msg);
  if (stat <> '00000')
    signal (stat, msg);
  if ('MOVE' = opname)
    DB.DBA.SPARUL_CLEAR (src_g_iri, 0, uid, log_mode, 0, options, silent);
  /*091202 commit work; */
  log_enable (old_log_enable, 1);
  if (compose_report)
    return sprintf ('%s <%s> to <%s> -- done', opname, src_g_iri, tgt_g_iri);
  return 1;
}
;

create function DB.DBA.SPARUL_COPY (in src_g_iri any, in tgt_g_iri any, in uid integer := 0, in log_mode integer := null, in compose_report integer := 0, in options any := null, in silent integer := 0) returns any
{
  return DB.DBA.SPARUL_COPYMOVEADD_IMPL ('COPY', src_g_iri, tgt_g_iri, uid, log_mode, compose_report, options, silent);
}
;

create function DB.DBA.SPARUL_MOVE (in src_g_iri any, in tgt_g_iri any, in uid integer := 0, in log_mode integer := null, in compose_report integer := 0, in options any := null, in silent integer := 0) returns any
{
  return DB.DBA.SPARUL_COPYMOVEADD_IMPL ('MOVE', src_g_iri, tgt_g_iri, uid, log_mode, compose_report, options, silent);
}
;

create function DB.DBA.SPARUL_ADD (in src_g_iri any, in tgt_g_iri any, in uid integer := 0, in log_mode integer := null, in compose_report integer := 0, in options any := null, in silent integer := 0) returns any
{
  return DB.DBA.SPARUL_COPYMOVEADD_IMPL ('ADD', src_g_iri, tgt_g_iri, uid, log_mode, compose_report, options, silent);
}
;

create procedure DB.DBA.SPARQL_SELECT_KNOWN_GRAPHS (in return_iris integer := 1, in lim integer := 2000000000)
{
  declare specials, specials_vec any;
  declare last_iri_id, cur_iri_id IRI_ID;
  declare cr cursor for select G from DB.DBA.RDF_QUAD table option (index G) where G > last_iri_id and not (dict_get (specials, G, 0));
  declare cr_cl cursor for select G from DB.DBA.RDF_QUAD table option (index G)  where G > last_iri_id and 0 >= position (G, specials_vec);
  declare GRAPH_IRI varchar;
  declare GRAPH_IID IRI_ID;
  declare ctr, len integer;
  if (lim is null)
    lim := 2000000000;
  if (return_iris)
    result_names (GRAPH_IRI);
  else
    result_names (GRAPH_IID);
  specials := dict_new (50);
  set isolation = 'repeatable';
  for (sparql define input:storage ""
    select distinct ?graph_rvr_fixed
    from <http://www.openlinksw.com/schemas/virtrdf#>
    where { ?qmv virtrdf:qmGraphRange-rvrFixedValue ?graph_rvr_fixed } ) do
    {
      dict_put (specials, iri_to_id ("graph_rvr_fixed"), 1);
    }
  if (dict_size (specials) >= lim)
    goto done_all;
  for (select REC_GRAPH_IID from DB.DBA.RDF_EXPLICITLY_CREATED_GRAPH) do
    {
      dict_put (specials, REC_GRAPH_IID, 2);
    }
  len := dict_size (specials);
  if (len >= lim)
    goto done_all;
  last_iri_id := #i0;

--  if (1 <> sys_stat ('cl_run_local_only'))
--    {
      specials_vec := dict_list_keys (specials, 0);
      whenever not found goto done_rdf_quad_cl;
      open cr_cl (prefetch 1);

next_fetch_cr_cl:
      fetch cr_cl into cur_iri_id;
      if (return_iris)
        result (id_to_iri (cur_iri_id));
      else
        result (cur_iri_id);
      lim := lim - 1;
      if (len >= lim)
        goto done_rdf_quad_cl;
      last_iri_id := cur_iri_id;
      close cr_cl;
      open cr_cl (prefetch 1);
      goto next_fetch_cr_cl;

done_rdf_quad_cl:
      close cr_cl;
--    }
--  else
--    {
--      whenever not found goto done_rdf_quad;
--      open cr (prefetch 1);

--next_fetch_cr:
--      fetch cr into cur_iri_id;
--      if (return_iris)
--        result (id_to_iri (cur_iri_id));
--      else
--        result (cur_iri_id);
--      lim := lim - 1;
--      if (len >= lim)
--        goto done_rdf_quad;
--      last_iri_id := cur_iri_id;
--      goto next_fetch_cr;

--done_rdf_quad:
--      close cr;
--    }

done_all:
  specials := dict_list_keys (specials, 1);
  len := length (specials);
  for (ctr := 0; ctr < len; ctr := ctr + 1)
    if (return_iris)
      result (id_to_iri (specials[ctr]));
    else
      result (specials[ctr]);
}
;

-----
-- Built-in operations of SPARQL as SQL functions

--!AWK PUBLIC
create function DB.DBA.RDF_REGEX (in s varchar, in p varchar, in coll varchar := null)
{
  if (not iswidestring (s) and not isstring (s))
    return 0;
  if (regexp_match (p, s, 0, coalesce (coll, ''), 1) is not null)
    return 1;
  return 0;
}
;

--!AWK PUBLIC
create function DB.DBA.RDF_LANGMATCHES (in r varchar, in t varchar)
{
  if ((t is null) or (r is null))
    return null;
  if ('*' = t)
    {
      if (r <> '')
        return 1;
      return 0;
    }
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
create procedure DB.DBA.BEST_LANGMATCH_INIT (inout env any)
{
  env := vector (0, -2);
}
;

--!AWK PUBLIC
create procedure DB.DBA.BEST_LANGMATCH_ACC (inout env any, in obj any array, in range varchar, in dflt_lang varchar)
{
  declare lang varchar;
  declare pct integer;
  if (obj is null)
    return;
  if (__tag (env) <> __tag of vector)
    env := vector (0, -2);
  if (__tag of rdf_box = __tag (obj))
    {
      declare twobyte integer;
      twobyte := rdf_box_lang (obj);
      if (257 = twobyte)
        lang := dflt_lang;
      else
        {
          whenever not found goto badlang;
          select lower (RL_ID) into lang from DB.DBA.RDF_LANGUAGE where RL_TWOBYTE = twobyte;
          goto lang_ready;
badlang:
          signal ('RDFXX', sprintf ('Unknown language in DB.DBA.BEST_LANGMATCH_ACC, bad lang id %d', twobyte));
        }
    }
  else if (__tag of varchar = __tag (obj))
      lang := dflt_lang;
  else
    {
      if (env[1] = -2)
        env := vector (obj, -1);
      return;
    }
lang_ready:
  pct := langmatches_pct_http (lang, range);
  if (env[1] < pct)
    env := vector (obj, pct);
}
;

--!AWK PUBLIC
create function DB.DBA.BEST_LANGMATCH_FINAL (inout env any) returns any
{
  if (__tag (env) <> __tag of vector)
    return null;
  return env[0];
}
;

--!AWK PUBLIC
create aggregate DB.DBA.BEST_LANGMATCH (inout obj any, in range varchar, in dflt_lang varchar) from
  DB.DBA.BEST_LANGMATCH_INIT,
  DB.DBA.BEST_LANGMATCH_ACC,
  DB.DBA.BEST_LANGMATCH_FINAL
;

--!AWK PUBLIC
create procedure DB.DBA.SPARQL_CONSTRUCT_INIT (inout _env any)
{
  _env := 0; -- No actual initialization
}
;

--!AWK PUBLIC
create procedure DB.DBA.SPARQL_CONSTRUCT_ACC (inout _env any, in opcodes any, in vars any, in stats any, in use_dict_limit integer)
{
  declare triple_ctr integer;
  declare blank_ids any;
  if (214 <> __tag(_env))
    {
      if (use_dict_limit)
        _env := dict_new (31, sys_stat ('sparql_result_set_max_rows'), sys_stat ('sparql_max_mem_in_use'));
      else
        _env := dict_new (31);
      if (0 < length (stats))
        DB.DBA.SPARQL_CONSTRUCT_ACC (_env, stats, vector(), vector(), use_dict_limit);
    }
  blank_ids := 0;
  for (triple_ctr := length (opcodes) - 1; triple_ctr >= 0; triple_ctr := triple_ctr-1)
    {
      declare fld_ctr, fld_count integer;
      declare triple_vec any;
      declare g_opcode integer;
      g_opcode := aref_or_default (opcodes, triple_ctr, 6, null);
      if (g_opcode is null)
        {
          fld_count := 3;
          triple_vec := vector (0,0,0);
        }
      else
        {
          fld_count := 4;
          triple_vec := vector (0,0,0,0);
        }
      -- dbg_obj_princ ('opcodes[triple_ctr]=', opcodes[triple_ctr]);
      for (fld_ctr := fld_count - 1; fld_ctr >= 0; fld_ctr := fld_ctr - 1)
        {
          declare op integer;
          declare arg any;
          op := opcodes[triple_ctr][fld_ctr * 2];
          arg := opcodes[triple_ctr][fld_ctr * 2 + 1];
          if (1 = op)
            {
              declare i any;
              i := vars[arg];
              if (i is null)
                goto end_of_adding_triple;
              if (isiri_id (i))
                {
                  if (fld_ctr in (1,3) and is_bnode_iri_id (i))
                    signal ('RDF01', 'Bad variable value in CONSTRUCT: blank node can not be used as predicate or graph');
                }
              else if ((isstring (i) and (1 = __box_flags (i))) or (217 = __tag(i)))
                {
                  if (fld_ctr in (1,3) and (i like 'bnode://%'))
                    signal ('RDF01', 'Bad variable value in CONSTRUCT: blank node can not be used as predicate or graph');
                  i := iri_to_id (i);
                }
              else if (2 <> fld_ctr)
                signal ('RDF01',
                  sprintf ('Bad variable value in CONSTRUCT: "%.100s" (tag %d box flags %d) is not a valid %s, only object of a triple can be a literal',
                    __rdf_strsqlval (i), __tag (i), __box_flags (i),
                    case (fld_ctr) when 1 then 'predicate' else 'subject' end ) );
              triple_vec[fld_ctr] := i;
            }
          else if (2 = op)
            {
              if (isinteger (blank_ids))
                blank_ids := vector (iri_id_from_num (sequence_next ('RDF_URL_IID_BLANK')));
              while (arg >= length (blank_ids))
                blank_ids := vector_concat (blank_ids, vector (iri_id_from_num (sequence_next ('RDF_URL_IID_BLANK'))));
              if (fld_ctr in (1,3))
                signal ('RDF01', 'Bad triple for CONSTRUCT: blank node can not be used as predicate or graph');
              triple_vec[fld_ctr] := blank_ids[arg];
            }
          else if (3 = op)
            {
              if (arg is null)
                goto end_of_adding_triple;
              if (isiri_id (arg))
                {
                  if (fld_ctr in (1,3) and is_bnode_iri_id (arg))
                    signal ('RDF01', 'Bad const value in CONSTRUCT: blank node can not be used as predicate or graph');
                }
              else if ((isstring (arg) and (1 = __box_flags (arg))) or (217 = __tag(arg)))
                {
                  if (fld_ctr in (1,3) and (arg like 'bnode://%'))
                    signal ('RDF01', 'Bad const value in CONSTRUCT: blank node can not be used as predicate or graph');
                  arg := iri_to_id (arg);
                }
              else if (2 <> fld_ctr)
                signal ('RDF01',
                  sprintf ('Bad const value in CONSTRUCT: "%.100s" (tag %d box flags %d) is not a valid %s, only object of a triple can be a literal',
                    __rdf_strsqlval (arg), __tag (arg), __box_flags (arg),
                    case (fld_ctr) when 1 then 'predicate' else 'subject' end ) );
              else if (__tag of vector = __tag (arg))
                arg := DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL_STRINGS (arg[0], arg[1], arg[2]);
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
create aggregate DB.DBA.SPARQL_CONSTRUCT (in opcodes any, in vars any, in stats any, in use_dict_limit integer) returns any
from DB.DBA.SPARQL_CONSTRUCT_INIT, DB.DBA.SPARQL_CONSTRUCT_ACC, DB.DBA.SPARQL_CONSTRUCT_FIN
;

create procedure DB.DBA.SPARQL_DESC_AGG_INIT (inout _env any)
{
  _env := 0; -- No actual initialization
}
;

create procedure DB.DBA.SPARQL_INSERT_DATA (in graph_iri any, in triple_ops any)
{
  for vectored (in triple_op any := triple_ops)
    {
      declare op, s, p, o any;

      if (isiri_id (o_val))
        __rdf_repl_quad (84, graph_iri, s_iri, p_iri, iri_canonicalize (o_val));
      else if (__tag of rdf_box <> __tag (o_val))
        __rdf_repl_quad (80, graph_iri, s_iri, p_iri, o_val);
      else
        {
          declare dt_twobyte, lang_twobyte integer;
          dt_twobyte := rdf_box_type (o_val);
          lang_twobyte := rdf_box_lang (o_val);
          if (257 <> dt_twobyte)
            __rdf_repl_quad (81, graph_iri, s_iri, p_iri, rdf_box_data (o_val), (select RDT_QNAME from DB.DBA.RDF_DATATYPE where RDT_TWOBYTE = dt_twobyte), NULL);
          else if (257 <> lang_twobyte)
            __rdf_repl_quad (82, graph_iri, s_iri, p_iri, rdf_box_data (o_val), NULL, (select RL_ID from DB.DBA.RDF_LANGUAGE where RL_TWOBYTE = lang_twobyte));
          else
            __rdf_repl_quad (80, graph_iri, s_iri, p_iri, rdf_box_data (o_val));
        }
    }
}
;

create procedure DB.DBA.SPARQL_DESC_AGG_ACC (inout _env any, in vars any)
{
  declare var_ctr integer;
  declare blank_ids any;
  if (214 <> __tag(_env))
    {
      _env := dict_new (31, sys_stat ('sparql_result_set_max_rows'), sys_stat ('sparql_max_mem_in_use'));
    }
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

create procedure DB.DBA.SPARQL_DESC_DICT (in subj_dict any, in consts any, in good_graphs any, in bad_graphs any, in storage_name any, in options any)
{
  declare all_subj_descs, phys_subjects, sorted_good_graphs, sorted_bad_graphs, g_dict, res any;
  declare uid, graphs_listed, g_ctr, good_g_count, bad_g_count, s_ctr, all_s_count, phys_s_count integer;
  declare gs_app_callback, gs_app_uid, inf_ruleset, sameas varchar;
  declare rdf_type_iid IRI_ID;
  uid := get_keyword ('uid', options, http_nobody_uid());
  gs_app_callback := get_keyword ('gs-app-callback', options);
  if (gs_app_callback is not null)
    gs_app_uid := get_keyword ('gs-app-uid', options);
  inf_ruleset := get_keyword ('inference', options);
  sameas := get_keyword ('same-as', options);
  rdf_type_iid := iri_to_id (UNAME'http://www.w3.org/1999/02/22-rdf-syntax-ns#type');
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
  if (__tag of integer = __tag (good_graphs))
    graphs_listed := 0;
  else
    {
      vectorbld_init (sorted_good_graphs);
      foreach (any g in good_graphs) do
        {
          if (isiri_id (g) and g < min_bnode_iri_id () and
            __rgs_ack_cbk (g, uid, 1) and
            (gs_app_callback is null or bit_and (1, call (gs_app_callback) (g, gs_app_uid))) )
            vectorbld_acc (sorted_good_graphs, g);
        }
      vectorbld_final (sorted_good_graphs);
      good_g_count := length (sorted_good_graphs);
      if (0 = good_g_count)
        return res;
      graphs_listed := 1;
    }
  vectorbld_init (sorted_bad_graphs);
  foreach (any g in bad_graphs) do
    {
      if (isiri_id (g) and g < min_bnode_iri_id ())
        vectorbld_acc (sorted_bad_graphs, g);
    }
  vectorbld_final (sorted_bad_graphs);
  bad_g_count := length (sorted_bad_graphs);
  vectorbld_init (phys_subjects);
  if (storage_name is null)
    storage_name := 'http://www.openlinksw.com/schemas/virtrdf#DefaultQuadStorage';
  else if (('' = storage_name) and (inf_ruleset is null) and (sameas is null))
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
  -- dbg_obj_princ ('storage_name=',storage_name, ' sorted_good_graphs=', sorted_good_graphs, ' sorted_bad_graphs=', sorted_bad_graphs);
  for (s_ctr := 0; s_ctr < all_s_count; s_ctr := s_ctr + 1)
    {
      declare s, phys_s, maps_s, maps_o any;
      declare maps_s_len, maps_o_len integer;
      s := all_subj_descs [s_ctr];
      maps_s := sparql_quad_maps_for_quad (NULL, s, NULL, NULL, storage_name, case (graphs_listed) when 0 then vector() else sorted_good_graphs end, sorted_bad_graphs);
      maps_o := sparql_quad_maps_for_quad (NULL, NULL, NULL, s, storage_name, case (graphs_listed) when 0 then vector() else sorted_good_graphs end, sorted_bad_graphs);
      -- dbg_obj_princ ('s = ', s, ' maps_s = ', maps_s, ' maps_o = ', maps_o);
      maps_s_len := length (maps_s);
      maps_o_len := length (maps_o);
      if ((inf_ruleset is null) and (sameas is null))
        {
          declare phys_as_s, phys_as_o integer;
          phys_as_s := case when ((maps_s_len > 0) and (maps_s[maps_s_len-1][0] = UNAME'http://www.openlinksw.com/schemas/virtrdf#DefaultQuadMap')) then 1 else 0 end;
          phys_as_o := case when ((maps_o_len > 0) and (maps_o[maps_o_len-1][0] = UNAME'http://www.openlinksw.com/schemas/virtrdf#DefaultQuadMap')) then 1 else 0 end;
          if (phys_as_s or phys_as_o)
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
              if (phys_as_s)
                {
                  maps_s := subseq (maps_s, 0, maps_s_len-1);
                  maps_s_len := maps_s_len - 1;
                }
              if (phys_as_o)
                {
                  maps_o := subseq (maps_o, 0, maps_o_len-1);
                  maps_o_len := maps_o_len - 1;
                }
            }
        }
      if ((maps_s_len > 0) or (maps_o_len > 0))
        all_subj_descs [s_ctr] := vector (s, maps_s, maps_o);
      else
        all_subj_descs [s_ctr] := 0;
      -- dbg_obj_princ ('s = ', s, ' maps = ', maps);
      -- dbg_obj_princ ('all_subj_descs [', s_ctr, '] = ', all_subj_descs [s_ctr]);
    }
  vectorbld_final (phys_subjects);
  for (s_ctr := 0; s_ctr < all_s_count; s_ctr := s_ctr + 1)
    {
      declare s_desc, s, maps_s, maps_o any;
      declare map_ctr, maps_s_len, maps_o_len integer;
      declare fname varchar;
      s_desc := all_subj_descs [s_ctr];
      if (isinteger (s_desc))
        goto end_of_s;
      s := s_desc[0];
      maps_s := s_desc[1];
      maps_o := s_desc[2];
      maps_s_len := length (maps_s);
      maps_o_len := length (maps_o);
      fname := sprintf ('SPARQL_DESC_DICT_QMV1_%U', md5 (storage_name || ' ' || inf_ruleset || ' ' || sameas || ' ' || cast (graphs_listed as varchar) || md5_box (maps_s) || md5_box (maps_o) || md5_box (sorted_bad_graphs)));
      if (not exists (select top 1 1 from Db.DBA.SYS_PROCEDURES where P_NAME = 'DB.DBA.' || fname))
        {
          declare ses, txt, saved_user any;
          ses := string_output ();
          http ('create procedure DB.DBA."' || fname || '" (in subj any, in res any', ses);
          if (graphs_listed)
            http (', inout sorted_good_graphs any', ses);
          http (')\n', ses);
          http ('{\n', ses);
          http ('  declare subj_iri varchar;\n', ses);
          http ('  subj_iri := id_to_iri_nosignal (subj);\n', ses);
          if (maps_s_len > 0)
            {
              http ('  for (sparql define output:valmode "LONG" define input:storage <' || storage_name || '> ', ses);
              foreach (any g in sorted_bad_graphs) do
                {
                  http ('  define input:named-graph-exclude <' || id_to_iri_nosignal (g) || '>\n', ses);
                }
              if (inf_ruleset is not null)
                  http ('  define input:inference <' || inf_ruleset || '>\n', ses);
              if (sameas is not null)
                  http ('  define input:same-as <' || sameas || '>\n', ses);
              http ('select ?g1 ?p1 ?o1\n', ses);
              http ('      where { graph ?g1 {\n', ses);
              for (map_ctr := 0; map_ctr < maps_s_len; map_ctr := map_ctr + 1)
                {
                  if (map_ctr > 0) http ('              union\n', ses);
                  http ('              { quad map <' || maps_s[map_ctr][0] || '> { ?:subj_iri ?p1 ?o1 } }\n', ses);
                }
              http ('            } } ) do {\n', ses);
              if (graphs_listed)
                http ('      if (position (__i2idn ("g1"), sorted_good_graphs))\n', ses);
              http ('      dict_bitor_or_put (res, vector (subj, "p1", "o1"), 1);\n    }\n', ses);
            }
          if (maps_o_len > 0)
            {
              http ('  for (sparql define output:valmode "LONG" define input:storage <' || storage_name || '> ', ses);
              foreach (any g in sorted_bad_graphs) do
                {
                  http ('  define input:named-graph-exclude <' || id_to_iri_nosignal (g) || '>\n', ses);
                }
              if (inf_ruleset is not null)
                  http ('  define input:inference <' || inf_ruleset || '>\n', ses);
              if (sameas is not null)
                  http ('  define input:same-as <' || sameas || '>\n', ses);
              http ('select ?g1 ?s1 ?p1\n', ses);
              http ('      where { graph ?g1 {\n', ses);
              for (map_ctr := 0; map_ctr < maps_o_len; map_ctr := map_ctr + 1)
                {
                  if (map_ctr > 0) http ('              union\n', ses);
                  http ('              { quad map <' || maps_o[map_ctr][0] || '> { ?s1 ?p1 ?o1 . FILTER (?p1 != rdf:type) . FILTER(isREF (?o1)) . FILTER (?o1 = iri(?:subj_iri)) } }\n', ses);
                }
              http ('            } } ) do {\n', ses);
              if (graphs_listed)
                http ('      if (position (__i2idn ("g1"), sorted_good_graphs))\n', ses);
              http ('      dict_bitor_or_put (res, vector ("s1", "p1", subj), 4);\n    }\n', ses);
            }
          http ('}\n', ses);
          txt := string_output_string (ses);
          -- dbg_obj_princ ('Procedure text: ', txt); string_to_file (fname || '.sql', txt || '\n;', -2);
          saved_user := user;
          set_user_id ('dba', 1);
          exec (txt);
          set_user_id (saved_user);
        }
      if (graphs_listed)
        {
          -- dbg_obj_princ ('call (''DB.DBA.', fname, ''')(', s, res, sorted_good_graphs, ')');
          call ('DB.DBA.' || fname)(s, res, sorted_good_graphs);
        }
      else
        {
          -- dbg_obj_princ ('call (''DB.DBA.', fname, ''')(', s, res, ')');
          call ('DB.DBA.' || fname)(s, res);
        }
end_of_s: ;
    }

describe_physical_subjects:
  gvector_sort (phys_subjects, 1, 0, 0);
  phys_s_count := length (phys_subjects);
  -- dbg_obj_princ ('phys_subjects = ', phys_subjects);
  if (0 = phys_s_count)
    return res;
  -- dbg_obj_princ ('sorted_bad_graphs = ', sorted_bad_graphs);
  if (graphs_listed)
    {
      gvector_sort (sorted_good_graphs, 1, 0, 0);
      -- dbg_obj_princ ('sorted_good_graphs = ', sorted_good_graphs);
      for (g_ctr := good_g_count - 1; g_ctr >= 0; g_ctr := g_ctr - 1)
        {
          declare graph any;
          graph := sorted_good_graphs [g_ctr];
          for (s_ctr := phys_s_count - 1; s_ctr >= 0; s_ctr := s_ctr - 1)
            {
              declare subj any;
              subj := phys_subjects [s_ctr];
              for (select P as p1, O as obj1 from DB.DBA.RDF_QUAD where G = graph and S = subj) do
                {
                  -- dbg_obj_princ ('found5 ', subj, p1, ' in ', graph);
                  dict_bitor_or_put (res, vector (subj, p1, __rdf_long_of_obj (obj1)), 1);
                }
              for (select S as s1, P as p1 from DB.DBA.RDF_QUAD
                  where G = graph and O = subj and P <> rdf_type_iid
                  option (QUIETCAST)) do
                {
                  -- dbg_obj_princ ('found2 ', s1, p1, subj, ' in ', graph);
                  dict_bitor_or_put (res, vector (s1, p1, subj), 4);
                }
            }
        }
      return res;
    }
  g_dict := dict_new ();
  for (s_ctr := phys_s_count - 1; s_ctr >= 0; s_ctr := s_ctr - 1)
    {
      declare subj, graph any;
      subj := phys_subjects [s_ctr];
      graph := coalesce ((select top 1 G as g1 from DB.DBA.RDF_QUAD where O = subj and
        0 = position (G, sorted_bad_graphs) and
        __rgs_ack_cbk (G, uid, 1) and
        (gs_app_callback is null or bit_and (1, call (gs_app_callback) (G, gs_app_uid))) ) );
      if (graph is not null)
        dict_put (g_dict, graph, 0);
    }
  sorted_good_graphs := dict_list_keys (g_dict, 1);
  if (0 = length (sorted_good_graphs))
    {
      g_dict := dict_new ();
      for (s_ctr := phys_s_count - 1; s_ctr >= 0; s_ctr := s_ctr - 1)
        {
          declare subj, graph any;
          subj := phys_subjects [s_ctr];
          graph := coalesce ((select top 1 G as g1 from DB.DBA.RDF_QUAD where S = subj and P = rdf_type_iid and
            0 = position (G, sorted_bad_graphs) and
            __rgs_ack_cbk (G, uid, 1) and
            (gs_app_callback is null or bit_and (1, call (gs_app_callback) (G, gs_app_uid))) ) );
          if (graph is not null)
            dict_put (g_dict, graph, 0);
        }
      sorted_good_graphs := dict_list_keys (g_dict, 1);
    }
  -- dbg_obj_princ ('sorted_good_graphs = ', sorted_good_graphs);
  gvector_sort (sorted_good_graphs, 1, 0, 0);
  good_g_count := length (sorted_good_graphs);
  -- dbg_obj_princ ('sorted_good_graphs = ', sorted_good_graphs);
  for (g_ctr := good_g_count - 1; g_ctr >= 0; g_ctr := g_ctr - 1)
    {
      declare graph any;
      graph := sorted_good_graphs [g_ctr];
      for (s_ctr := phys_s_count - 1; s_ctr >= 0; s_ctr := s_ctr - 1)
        {
          declare subj any;
          subj := phys_subjects [s_ctr];
          for (select P as p1, O as obj1 from DB.DBA.RDF_QUAD where G = graph and S = subj) do
            {
              -- dbg_obj_princ ('found1 ', subj, p1, ' in ', graph);
              dict_bitor_or_put (res, vector (subj, p1, __rdf_long_of_obj (obj1)), 1);
--              if (isiri_id (obj1))
--                {
--                  for (select P as p2, O as obj2
--                    from DB.DBA.RDF_QUAD
--                    where G = graph and S = obj1 and not (isiri_id (O)) ) do
--                    {
--                      dict_bitor_or_put (dict, vector (obj1, p2, __rdf_long_of_obj (obj2)), 17);
--                    }
--                }
            }
          for (select S as s1, P as p1 from DB.DBA.RDF_QUAD
            where G = graph and O = subj and P <> rdf_type_iid
            option (QUIETCAST)) do
            {
              -- dbg_obj_princ ('found2 ', s1, p1, subj, ' in ', graph);
              dict_bitor_or_put (res, vector (s1, p1, subj), 4);
            }
        }
    }
  -- dbg_obj_princ ('final result is ', res);
  return res;
}
;

create procedure DB.DBA.SPARQL_DESC_DICT_SPO (in subj_dict any, in consts any, in good_graphs any, in bad_graphs any, in storage_name any, in options any)
{
  declare all_subj_descs, phys_subjects, sorted_good_graphs, sorted_bad_graphs, res any;
  declare uid, graphs_listed, g_ctr, good_g_count, bad_g_count, s_ctr, all_s_count, phys_s_count integer;
  declare gs_app_callback, gs_app_uid, inf_ruleset, sameas varchar;
  declare rdf_type_iid IRI_ID;
  uid := get_keyword ('uid', options, http_nobody_uid());
  gs_app_callback := get_keyword ('gs-app-callback', options);
  if (gs_app_callback is not null)
    gs_app_uid := get_keyword ('gs-app-uid', options);
  inf_ruleset := get_keyword ('inference', options);
  sameas := get_keyword ('same-as', options);
  rdf_type_iid := iri_to_id (UNAME'http://www.w3.org/1999/02/22-rdf-syntax-ns#type');
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
  if (__tag of integer = __tag (good_graphs))
    graphs_listed := 0;
  else
    {
      vectorbld_init (sorted_good_graphs);
      foreach (any g in good_graphs) do
        {
          if (isiri_id (g) and g < min_bnode_iri_id () and
            __rgs_ack_cbk (g, uid, 1) and
            (gs_app_callback is null or bit_and (1, call (gs_app_callback) (g, gs_app_uid))) )
            vectorbld_acc (sorted_good_graphs, g);
        }
      vectorbld_final (sorted_good_graphs);
      good_g_count := length (sorted_good_graphs);
      if (0 = good_g_count)
        return res;
      graphs_listed := 1;
    }
  vectorbld_init (sorted_bad_graphs);
  foreach (any g in bad_graphs) do
    {
      if (isiri_id (g) and g < min_bnode_iri_id ())
        vectorbld_acc (sorted_bad_graphs, g);
    }
  vectorbld_final (sorted_bad_graphs);
  bad_g_count := length (sorted_bad_graphs);
  vectorbld_init (phys_subjects);
  if (storage_name is null)
    storage_name := 'http://www.openlinksw.com/schemas/virtrdf#DefaultQuadStorage';
  else if (('' = storage_name) and (inf_ruleset is null) and (sameas is null))
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
  -- dbg_obj_princ ('storage_name=',storage_name, ' sorted_good_graphs=', sorted_good_graphs, ' sorted_bad_graphs=', sorted_bad_graphs);
  for (s_ctr := 0; s_ctr < all_s_count; s_ctr := s_ctr + 1)
    {
      declare s, phys_s, maps any;
      declare maps_len integer;
      s := all_subj_descs [s_ctr];
      maps := sparql_quad_maps_for_quad (NULL, s, NULL, NULL, storage_name, case (graphs_listed) when 0 then vector() else sorted_good_graphs end, sorted_bad_graphs);
      -- dbg_obj_princ ('s = ', s, ' maps = ', maps);
      maps_len := length (maps);
      if ((maps_len > 0) and (inf_ruleset is null) and (sameas is null) and (maps[maps_len-1][0] = UNAME'http://www.openlinksw.com/schemas/virtrdf#DefaultQuadMap'))
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
      fname := sprintf ('SPARQL_DESC_DICT_QMV1_%U', md5 (storage_name || ' ' || inf_ruleset || ' ' || sameas || ' ' || cast (graphs_listed as varchar) || md5_box (maps) || md5_box (sorted_bad_graphs)));
      if (not exists (select top 1 1 from Db.DBA.SYS_PROCEDURES where P_NAME = 'DB.DBA.' || fname))
        {
          declare ses, txt, saved_user any;
          ses := string_output ();
          http ('create procedure DB.DBA."' || fname || '" (in subj any, in res any', ses);
          if (graphs_listed)
            http (', inout sorted_good_graphs any', ses);
          http (')\n', ses);
          http ('{\n', ses);
          http ('  declare subj_iri varchar;\n', ses);
          http ('  subj_iri := id_to_iri_nosignal (subj);\n', ses);
          if (maps_len > 0)
            {
              http ('  for (sparql define output:valmode "LONG" define input:storage <' || storage_name || '> ', ses);
              foreach (any g in sorted_bad_graphs) do
                {
                  http ('  define input:named-graph-exclude <' || id_to_iri_nosignal (g) || '>\n', ses);
                }
              if (inf_ruleset is not null)
                  http ('  define input:inference <' || inf_ruleset || '>\n', ses);
              if (sameas is not null)
                  http ('  define input:same-as <' || sameas || '>\n', ses);
              http ('select ?g1 ?p1 ?o1\n', ses);
              http ('      where { graph ?g1 {\n', ses);
              for (map_ctr := 0; map_ctr < maps_len; map_ctr := map_ctr + 1)
                {
                  if (map_ctr > 0) http ('              union\n', ses);
                  http ('              { quad map <' || maps[map_ctr][0] || '> { ?:subj_iri ?p1 ?o1 } }\n', ses);
                }
              http ('            } } ) do {\n', ses);
              if (graphs_listed)
                http ('      if (position (__i2idn ("g1"), sorted_good_graphs))\n', ses);
              http ('      dict_bitor_or_put (res, vector (subj, "p1", "o1"), 1);\n    }\n', ses);
            }
          http ('}\n', ses);
          txt := string_output_string (ses);
          -- dbg_obj_princ ('Procedure text: ', txt);
          saved_user := user;
          set_user_id ('dba', 1);
          exec (txt);
          set_user_id (saved_user);
        }
      if (graphs_listed)
        {
          -- dbg_obj_princ ('call (''DB.DBA.', fname, ''')(', s, res, sorted_good_graphs, ')');
          call ('DB.DBA.' || fname)(s, res, sorted_good_graphs);
        }
      else
        {
          -- dbg_obj_princ ('call (''DB.DBA.', fname, ''')(', s, res, ')');
          call ('DB.DBA.' || fname)(s, res);
        }
end_of_s: ;
    }

describe_physical_subjects:
  gvector_sort (phys_subjects, 1, 0, 0);
  phys_s_count := length (phys_subjects);
  -- dbg_obj_princ ('phys_subjects = ', phys_subjects);
  if (0 = phys_s_count)
    return res;
  -- dbg_obj_princ ('sorted_bad_graphs = ', sorted_bad_graphs);
  if (graphs_listed)
    {
      gvector_sort (sorted_good_graphs, 1, 0, 0);
      -- dbg_obj_princ ('sorted_good_graphs = ', sorted_good_graphs);
      for (g_ctr := good_g_count - 1; g_ctr >= 0; g_ctr := g_ctr - 1)
        {
          declare graph any;
          graph := sorted_good_graphs [g_ctr];
          for (s_ctr := phys_s_count - 1; s_ctr >= 0; s_ctr := s_ctr - 1)
            {
              declare subj any;
              subj := phys_subjects [s_ctr];
              for (select P as p1, O as obj1 from DB.DBA.RDF_QUAD where G = graph and S = subj) do
                {
                  -- dbg_obj_princ ('found3 ', subj, p1, ' in ', graph);
                  dict_bitor_or_put (res, vector (subj, p1, __rdf_long_of_obj (obj1)), 1);
                }
            }
        }
      return res;
    }
  for (s_ctr := phys_s_count - 1; s_ctr >= 0; s_ctr := s_ctr - 1)
    {
      declare subj any;
      subj := phys_subjects [s_ctr];
      for (select P as p1, O as obj1 from DB.DBA.RDF_QUAD where
        0 = position (G, sorted_bad_graphs) and
        S = subj and
        __rgs_ack_cbk (G, uid, 1) and
        (gs_app_callback is null or bit_and (1, call (gs_app_callback) (G, gs_app_uid))) ) do
        {
          -- dbg_obj_princ ('found4 ', subj, p1);
          dict_bitor_or_put (res, vector (subj, p1, __rdf_long_of_obj (obj1)), 1);
        }
    }
  return res;
}
;

create procedure DB.DBA.SPARQL_DESC_DICT_SPO_PHYSICAL (in subj_dict any, in consts any, in good_graphs any, in bad_graphs any, in storage_name any, in options any)
{
  declare all_subj_descs, phys_subjects, sorted_good_graphs, sorted_bad_graphs, g_dict, res any;
  declare uid, graphs_listed, g_ctr, good_g_count, bad_g_count, s_ctr, all_s_count, phys_s_count integer;
  declare gs_app_callback, gs_app_uid varchar;
  declare rdf_type_iid IRI_ID;
  uid := get_keyword ('uid', options, http_nobody_uid());
  gs_app_callback := get_keyword ('gs-app-callback', options);
  if (gs_app_callback is not null)
    gs_app_uid := get_keyword ('gs-app-uid', options);
  rdf_type_iid := iri_to_id (UNAME'http://www.w3.org/1999/02/22-rdf-syntax-ns#type');
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
  if (__tag of integer = __tag (good_graphs))
    graphs_listed := 0;
  else
    {
      vectorbld_init (sorted_good_graphs);
      foreach (any g in good_graphs) do
        {
          if (isiri_id (g) and g < min_bnode_iri_id () and
            __rgs_ack_cbk (g, uid, 1) and
            (gs_app_callback is null or bit_and (1, call (gs_app_callback) (g, gs_app_uid))) )
            vectorbld_acc (sorted_good_graphs, g);
        }
      vectorbld_final (sorted_good_graphs);
      good_g_count := length (sorted_good_graphs);
      if (0 = good_g_count)
        return res;
      graphs_listed := 1;
    }
  vectorbld_init (sorted_bad_graphs);
  foreach (any g in bad_graphs) do
    {
      if (isiri_id (g) and g < min_bnode_iri_id ())
        vectorbld_acc (sorted_bad_graphs, g);
    }
  vectorbld_final (sorted_bad_graphs);
  bad_g_count := length (sorted_bad_graphs);
  vectorbld_init (phys_subjects);
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
  gvector_sort (phys_subjects, 1, 0, 0);
  phys_s_count := length (phys_subjects);
  -- dbg_obj_princ ('phys_subjects = ', phys_subjects);
  if (0 = phys_s_count)
    return res;
  -- dbg_obj_princ ('sorted_bad_graphs = ', sorted_bad_graphs);
  if (graphs_listed)
    {
      gvector_sort (sorted_good_graphs, 1, 0, 0);
      -- dbg_obj_princ ('sorted_good_graphs = ', sorted_good_graphs);
      for (g_ctr := good_g_count - 1; g_ctr >= 0; g_ctr := g_ctr - 1)
        {
          declare graph any;
          graph := sorted_good_graphs [g_ctr];
          for (s_ctr := phys_s_count - 1; s_ctr >= 0; s_ctr := s_ctr - 1)
            {
              declare subj any;
              subj := phys_subjects [s_ctr];
              for (select P as p1, O as obj1 from DB.DBA.RDF_QUAD where G = graph and S = subj) do
                {
                  -- dbg_obj_princ ('found5 ', subj, p1, ' in ', graph);
                  dict_bitor_or_put (res, vector (subj, p1, __rdf_long_of_obj (obj1)), 1);
                }
            }
        }
      return res;
    }
  g_dict := dict_new ();
  for (s_ctr := phys_s_count - 1; s_ctr >= 0; s_ctr := s_ctr - 1)
    {
      declare subj, graph any;
      subj := phys_subjects [s_ctr];
      graph := coalesce ((select top 1 G as g1 from DB.DBA.RDF_QUAD where O = subj and
          0 = position (G, sorted_bad_graphs) and
          __rgs_ack_cbk (G, uid, 1) and
          (gs_app_callback is null or bit_and (1, call (gs_app_callback) (G, gs_app_uid))) ) );
      if (graph is not null)
        dict_put (g_dict, graph, 0);
    }
  sorted_good_graphs := dict_list_keys (g_dict, 1);
  if (0 = length (sorted_good_graphs))
    {
      g_dict := dict_new ();
      for (s_ctr := phys_s_count - 1; s_ctr >= 0; s_ctr := s_ctr - 1)
        {
          declare subj, graph any;
          subj := phys_subjects [s_ctr];
          graph := coalesce ((select top 1 G as g1 from DB.DBA.RDF_QUAD where S = subj and P = rdf_type_iid and
              0 = position (G, sorted_bad_graphs) and
              __rgs_ack_cbk (G, uid, 1) and
              (gs_app_callback is null or bit_and (1, call (gs_app_callback) (G, gs_app_uid))) ) );
          if (graph is not null)
            dict_put (g_dict, graph, 0);
        }
      sorted_good_graphs := dict_list_keys (g_dict, 1);
    }
  -- dbg_obj_princ ('sorted_good_graphs = ', sorted_good_graphs);
  gvector_sort (sorted_good_graphs, 1, 0, 0);
  good_g_count := length (sorted_good_graphs);
  -- dbg_obj_princ ('sorted_good_graphs = ', sorted_good_graphs);
  for (g_ctr := good_g_count - 1; g_ctr >= 0; g_ctr := g_ctr - 1)
    {
      declare graph any;
      graph := sorted_good_graphs [g_ctr];
      for (s_ctr := phys_s_count - 1; s_ctr >= 0; s_ctr := s_ctr - 1)
        {
          declare subj any;
          subj := phys_subjects [s_ctr];
          for (select P as p1, O as obj1 from DB.DBA.RDF_QUAD where G = graph and S = subj) do
            {
              -- dbg_obj_princ ('found6 ', subj, p1, ' in ', graph);
              dict_bitor_or_put (res, vector (subj, p1, __rdf_long_of_obj (obj1)), 1);
--              if (isiri_id (obj1))
--                {
--                  for (select P as p2, O as obj2
--                    from DB.DBA.RDF_QUAD
--                    where G = graph and S = obj1 and not (isiri_id (O)) ) do
--                    {
--                      dict_bitor_or_put (dict, vector (obj1, p2, __rdf_long_of_obj (obj2)), 17);
--                    }
--                }
            }
--          for (select S as s1, P as p1 from DB.DBA.RDF_QUAD
--            where G = graph and O = subj and P <> rdf_type_iid
--            option (QUIETCAST)) do
--            {
              -- dbg_obj_princ ('found7 ', s1, p1, subj, ' in ', graph);
--              dict_bitor_or_put (res, vector (s1, p1, subj), 4);
--            }
        }
    }
  -- dbg_obj_princ ('final result is ', res);
  return res;
}
;

create procedure DB.DBA.SPARQL_DESC_DICT_CBD (in subj_dict any, in consts any, in good_graphs any, in bad_graphs any, in storage_name any, in options any)
{
  declare all_subjs, phys_subjects, sorted_good_graphs, sorted_bad_graphs, next_iter_subjs, res any;
  declare uid, graphs_listed, g_ctr, good_g_count, bad_g_count, s_ctr, all_s_count, phys_s_count integer;
  declare gs_app_callback, gs_app_uid, inf_ruleset varchar;
  declare rdf_type_iid IRI_ID;
  uid := get_keyword ('uid', options, http_nobody_uid());
  gs_app_callback := get_keyword ('gs-app-callback', options);
  if (gs_app_callback is not null)
    gs_app_uid := get_keyword ('gs-app-uid', options);
  inf_ruleset := get_keyword ('inference', options);
  rdf_type_iid := iri_to_id (UNAME'http://www.w3.org/1999/02/22-rdf-syntax-ns#type');
  res := dict_new ();
  if (isinteger (consts))
    return res;
  foreach (any c in consts) do
    {
      if (isiri_id (c))
        dict_put (subj_dict, c, 0);
    }
  all_subjs := dict_list_keys (subj_dict, 0);
  next_iter_subjs := dict_new ();
  all_s_count := length (all_subjs);
  if (0 = all_s_count)
    return res;

next_iteration:
  all_s_count := length (all_subjs);
  gvector_sort (all_subjs, 1, 0, 0);
  -- dbg_obj_princ ('new iteration: all_subjs = ', all_subjs);
  if (__tag of integer = __tag (good_graphs))
    graphs_listed := 0;
  else
    {
      vectorbld_init (sorted_good_graphs);
      foreach (any g in good_graphs) do
        {
          if (isiri_id (g) and g < min_bnode_iri_id () and
            __rgs_ack_cbk (g, uid, 1) and
            (gs_app_callback is null or bit_and (1, call (gs_app_callback) (g, gs_app_uid))) )
            vectorbld_acc (sorted_good_graphs, g);
        }
      vectorbld_final (sorted_good_graphs);
      good_g_count := length (sorted_good_graphs);
      if (0 = good_g_count)
        return res;
      graphs_listed := 1;
    }
  vectorbld_init (sorted_bad_graphs);
  foreach (any g in bad_graphs) do
    {
      if (isiri_id (g) and g < min_bnode_iri_id ())
        vectorbld_acc (sorted_bad_graphs, g);
    }
  vectorbld_final (sorted_bad_graphs);
  bad_g_count := length (sorted_bad_graphs);
  vectorbld_init (phys_subjects);
  if (storage_name is null)
    storage_name := 'http://www.openlinksw.com/schemas/virtrdf#DefaultQuadStorage';
  else if (('' = storage_name) and (inf_ruleset is null))
    {
      for (s_ctr := 0; s_ctr < all_s_count; s_ctr := s_ctr + 1)
        {
          declare s, phys_s any;
          s := all_subjs [s_ctr];
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
  -- dbg_obj_princ ('storage_name=',storage_name, ' sorted_good_graphs=', sorted_good_graphs, ' sorted_bad_graphs=', sorted_bad_graphs);
  for (s_ctr := 0; s_ctr < all_s_count; s_ctr := s_ctr + 1)
    {
      declare s, phys_s, maps any;
      declare maps_len integer;
      s := all_subjs [s_ctr];
      maps := sparql_quad_maps_for_quad (NULL, s, NULL, NULL, storage_name, case (graphs_listed) when 0 then vector() else sorted_good_graphs end, sorted_bad_graphs);
      -- dbg_obj_princ ('s = ', s, id_to_iri (s), ' maps = ', maps);
      maps_len := length (maps);
      if ((maps_len > 0) and (inf_ruleset is null) and (maps[maps_len-1][0] = UNAME'http://www.openlinksw.com/schemas/virtrdf#DefaultQuadMap'))
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
        all_subjs [s_ctr] := vector (s, maps);
      else
        all_subjs [s_ctr] := 0;
      -- dbg_obj_princ ('s = ', s, ' maps = ', maps);
      -- dbg_obj_princ ('all_subjs [', s_ctr, '] = ', all_subjs [s_ctr]);
    }
  vectorbld_final (phys_subjects);
  for (s_ctr := 0; s_ctr < all_s_count; s_ctr := s_ctr + 1)
    {
      declare s_desc, s, maps any;
      declare map_ctr, maps_len integer;
      declare fname varchar;
      s_desc := all_subjs [s_ctr];
      if (isinteger (s_desc))
        goto end_of_s;
      s := s_desc[0];
      maps := s_desc[1];
      maps_len := length (maps);
      fname := sprintf ('SPARQL_DESC_DICT_CBD_QMV1_%U', md5 (storage_name || inf_ruleset || cast (graphs_listed as varchar) || md5_box (maps) || md5_box (sorted_bad_graphs)));
      if (not exists (select top 1 1 from Db.DBA.SYS_PROCEDURES where P_NAME = 'DB.DBA.' || fname))
        {
          declare ses, txt, saved_user any;
          ses := string_output ();
          http ('create procedure DB.DBA."' || fname || '" (in subj any, in subj_dict any, in next_iter_subjs any, in res any', ses);
          if (graphs_listed)
            http (', inout sorted_good_graphs any', ses);
          http (')\n', ses);
          http ('{\n', ses);
          http ('  declare subj_iri varchar;\n', ses);
          http ('  subj_iri := id_to_iri_nosignal (subj);\n', ses);
          if (maps_len > 0)
            {
              http ('  for (sparql define output:valmode "LONG" define input:storage <' || storage_name || '> ', ses);
              foreach (any g in sorted_bad_graphs) do
                {
                  http ('  define input:named-graph-exclude <' || id_to_iri_nosignal (g) || '>\n', ses);
                }
              if (inf_ruleset is not null)
                  http ('  define input:inference <' || inf_ruleset || '>\n', ses);
              http ('select ?g1 ?p1 ?o1 ?g2 ?st2\n', ses);
              http ('      where { graph ?g1 {\n', ses);
              for (map_ctr := 0; map_ctr < maps_len; map_ctr := map_ctr + 1)
                {
                  if (map_ctr > 0) http ('              union\n', ses);
                  http ('              { quad map <' || maps[map_ctr][0] || '> { ?:subj_iri ?p1 ?o1 } }\n', ses);
                }
              http ('            }\n', ses);
              http ('          optional { graph ?g2 {\n', ses);
              http ('                  ?st2 a rdf:Statement ; rdf:subject ?:subj_iri ; rdf:predicate ?p1 ; rdf:object ?o1 } }\n', ses);
              http ('            } ) do {\n', ses);
              if (graphs_listed)
                http ('      if (position (__i2idn ("g1"), sorted_good_graphs)) {\n', ses);
              http ('      dict_bitor_or_put (res, vector (subj, "p1", "o1"), 1);\n', ses);
              http ('      if (isiri_id ("o1") and "o1" > min_bnode_iri_id() and dict_get (subj_dict, "o1") is null)\n', ses);
              http ('        dict_put (next_iter_subjs, "o1", 1);\n', ses);
              if (graphs_listed)
                http ('      if (position (__i2idn ("g2"), sorted_good_graphs)) {\n', ses);
              http ('      if ("st2" is not null and dict_get (subj_dict, "st2") is null)\n', ses);
              http ('        dict_put (next_iter_subjs, "o1", 1);\n', ses);
              if (graphs_listed)
                http ('        } }\n', ses);
              http ('    }\n', ses);
            }
          http ('}\n', ses);
          txt := string_output_string (ses);
          -- dbg_obj_princ ('Procedure text: ', txt);
          saved_user := user;
          set_user_id ('dba', 1);
          exec (txt);
          set_user_id (saved_user);
        }
      if (graphs_listed)
        {
          -- dbg_obj_princ ('call (''DB.DBA.', fname, ''')(', s, subj_dict, next_iter_subjs, res, sorted_good_graphs, ')');
          call ('DB.DBA.' || fname)(s, subj_dict, next_iter_subjs, res, sorted_good_graphs);
        }
      else
        {
          -- dbg_obj_princ ('call (''DB.DBA.', fname, ''')(', s, subj_dict, next_iter_subjs, res, ')');
          call ('DB.DBA.' || fname)(s, subj_dict, next_iter_subjs, res);
        }
end_of_s: ;
    }

describe_physical_subjects:
  gvector_sort (phys_subjects, 1, 0, 0);
  phys_s_count := length (phys_subjects);
  -- dbg_obj_princ ('phys_subjects = ', phys_subjects);
  if (0 = phys_s_count)
    return res;
  -- dbg_obj_princ ('sorted_bad_graphs = ', sorted_bad_graphs);
  if (graphs_listed)
    {
      gvector_sort (sorted_good_graphs, 1, 0, 0);
      -- dbg_obj_princ ('sorted_good_graphs = ', sorted_good_graphs);
      for (g_ctr := good_g_count - 1; g_ctr >= 0; g_ctr := g_ctr - 1)
        {
          declare graph any;
          graph := sorted_good_graphs [g_ctr];
          for (s_ctr := phys_s_count - 1; s_ctr >= 0; s_ctr := s_ctr - 1)
            {
              declare subj any;
              subj := phys_subjects [s_ctr];
              for (select P as p1, O as obj1 from DB.DBA.RDF_QUAD where G = graph and S = subj) do
                {
                  -- dbg_obj_princ ('found3 ', subj, p1, ' in ', graph);
                  dict_bitor_or_put (res, vector (subj, p1, __rdf_long_of_obj (obj1)), 1);
                  if (isiri_id (obj1) and obj1 > min_bnode_iri_id() and dict_get (subj_dict, obj1) is null)
                    dict_put (next_iter_subjs, obj1, 1);
                  for (sparql define output:valmode "LONG"
                    select ?g2 ?st2 where {
                        graph ?g2 {
                            ?st2 a rdf:Statement ; rdf:subject ?:subj ; rdf:predicate ?:p1 ; rdf:object ?:obj1 } } ) do
                    {
                      if (position ("g2", sorted_good_graphs) and dict_get (subj_dict, "st2") is null)
                        dict_put (next_iter_subjs, "st2", 1);
                    }
                }
            }
        }
    }
  else
    {
      for (s_ctr := phys_s_count - 1; s_ctr >= 0; s_ctr := s_ctr - 1)
        {
          declare subj any;
          subj := phys_subjects [s_ctr];
          for (select P as p1, O as obj1 from DB.DBA.RDF_QUAD where
            0 = position (G, sorted_bad_graphs) and
            S = subj and
            __rgs_ack_cbk (G, uid, 1) and
            (gs_app_callback is null or bit_and (1, call (gs_app_callback) (G, gs_app_uid))) ) do
            {
              -- dbg_obj_princ ('found4 ', subj, p1);
              dict_bitor_or_put (res, vector (subj, p1, __rdf_long_of_obj (obj1)), 1);
              if (isiri_id (obj1) and obj1 > min_bnode_iri_id() and dict_get (subj_dict, obj1) is null)
                dict_put (next_iter_subjs, obj1, 1);
              for (sparql define output:valmode "LONG"
                select ?g2 ?st2 where {
                    graph ?g2 {
                        ?st2 a rdf:Statement ; rdf:subject ?:subj ; rdf:predicate ?:p1 ; rdf:object ?:obj1 } } ) do
                {
                  if (0 = position ("g2", sorted_bad_graphs) and
                    dict_get (subj_dict, "st2") is null and
                    __rgs_ack_cbk ("g2", uid, 1) and
                    (gs_app_callback is null or bit_and (1, call (gs_app_callback) ("g2", gs_app_uid))) )
                    dict_put (next_iter_subjs, "st2", 1);
                }
            }
        }
    }
ret_or_next_iter:
  if (0 = dict_size (next_iter_subjs))
    {
      -- dbg_obj_princ ('no new subjs, res = ', dict_list_keys (res, 0));
      return res;
    }
  all_subjs := dict_list_keys (next_iter_subjs, 1);
  foreach (IRI_ID s in all_subjs) do dict_put (subj_dict, s, 1);
  goto next_iteration;
}
;

create procedure DB.DBA.SPARQL_DESC_DICT_CBD_PHYSICAL (in subj_dict any, in consts any, in good_graphs any, in bad_graphs any, in storage_name any, in options any)
{
  declare all_subjs, sorted_good_graphs, sorted_bad_graphs, next_iter_subjs, res any;
  declare uid, graphs_listed, g_ctr, good_g_count, bad_g_count, s_ctr, all_s_count integer;
  declare gs_app_callback, gs_app_uid varchar;
  declare rdf_type_iid IRI_ID;
  uid := get_keyword ('uid', options, http_nobody_uid());
  gs_app_callback := get_keyword ('gs-app-callback', options);
  if (gs_app_callback is not null)
    gs_app_uid := get_keyword ('gs-app-uid', options);
  rdf_type_iid := iri_to_id (UNAME'http://www.w3.org/1999/02/22-rdf-syntax-ns#type');
  res := dict_new ();
  if (isinteger (consts))
    return res;
  foreach (any c in consts) do
    {
      if (isiri_id (c))
        dict_put (subj_dict, c, 0);
    }
  all_subjs := dict_list_keys (subj_dict, 0);
  next_iter_subjs := dict_new ();
  all_s_count := length (all_subjs);
  if (0 = all_s_count)
    return res;

next_iteration:
  all_s_count := length (all_subjs);
  gvector_sort (all_subjs, 1, 0, 0);
  -- dbg_obj_princ ('new iteration: all_subjs = ', all_subjs);
  if (__tag of integer = __tag (good_graphs))
    graphs_listed := 0;
  else
    {
      vectorbld_init (sorted_good_graphs);
      foreach (any g in good_graphs) do
        {
          if (isiri_id (g) and g < min_bnode_iri_id () and
            __rgs_ack_cbk (g, uid, 1) and
            (gs_app_callback is null or bit_and (1, call (gs_app_callback) (g, gs_app_uid))) )
            vectorbld_acc (sorted_good_graphs, g);
        }
      vectorbld_final (sorted_good_graphs);
      good_g_count := length (sorted_good_graphs);
      if (0 = good_g_count)
        return res;
      graphs_listed := 1;
    }
  vectorbld_init (sorted_bad_graphs);
  foreach (any g in bad_graphs) do
    {
      if (isiri_id (g) and g < min_bnode_iri_id ())
        vectorbld_acc (sorted_bad_graphs, g);
    }
  vectorbld_final (sorted_bad_graphs);
  bad_g_count := length (sorted_bad_graphs);
  -- dbg_obj_princ ('all_subjs = ', all_subjs);
  if (0 = all_s_count)
    return res;
  -- dbg_obj_princ ('sorted_bad_graphs = ', sorted_bad_graphs);
  if (graphs_listed)
    {
      gvector_sort (sorted_good_graphs, 1, 0, 0);
      -- dbg_obj_princ ('sorted_good_graphs = ', sorted_good_graphs);
      for (g_ctr := good_g_count - 1; g_ctr >= 0; g_ctr := g_ctr - 1)
        {
          declare graph any;
          graph := sorted_good_graphs [g_ctr];
          for (s_ctr := all_s_count - 1; s_ctr >= 0; s_ctr := s_ctr - 1)
            {
              declare subj any;
              subj := all_subjs [s_ctr];
              for (select P as p1, O as obj1 from DB.DBA.RDF_QUAD where G = graph and S = subj) do
                {
                  -- dbg_obj_princ ('found3 ', subj, p1, ' in ', graph);
                  dict_bitor_or_put (res, vector (subj, p1, __rdf_long_of_obj (obj1)), 1);
                  if (isiri_id (obj1) and obj1 > min_bnode_iri_id() and dict_get (subj_dict, obj1) is null)
                    dict_put (next_iter_subjs, obj1, 1);
                  for (sparql define output:valmode "LONG"
                    select ?g2 ?st2 where {
                        graph ?g2 {
                            ?st2 a rdf:Statement ; rdf:subject ?:subj ; rdf:predicate ?:p1 ; rdf:object ?:obj1 } } ) do
                    {
                      if (position ("g2", sorted_good_graphs) and dict_get (subj_dict, "st2") is null)
                        dict_put (next_iter_subjs, "st2", 1);
                    }
                }
            }
        }
    }
  else
    {
      for (s_ctr := all_s_count - 1; s_ctr >= 0; s_ctr := s_ctr - 1)
        {
          declare subj any;
          subj := all_subjs [s_ctr];
          for (select P as p1, O as obj1 from DB.DBA.RDF_QUAD where
            0 = position (G, sorted_bad_graphs) and
            S = subj and
            __rgs_ack_cbk (G, uid, 1) and
            (gs_app_callback is null or bit_and (1, call (gs_app_callback) (G, gs_app_uid))) ) do
            {
              -- dbg_obj_princ ('found4 ', subj, p1);
              dict_bitor_or_put (res, vector (subj, p1, __rdf_long_of_obj (obj1)), 1);
              if (isiri_id (obj1) and obj1 > min_bnode_iri_id() and dict_get (subj_dict, obj1) is null)
                dict_put (next_iter_subjs, obj1, 1);
              for (sparql define output:valmode "LONG"
                select ?g2 ?st2 where {
                    graph ?g2 {
                        ?st2 a rdf:Statement ; rdf:subject ?:subj ; rdf:predicate ?:p1 ; rdf:object ?:obj1 } } ) do
                {
                  if (0 = position ("g2", sorted_bad_graphs) and
                    dict_get (subj_dict, "st2") is null and
                    __rgs_ack_cbk ("g2", uid, 1) and
                    (gs_app_callback is null or bit_and (1, call (gs_app_callback) ("g2", gs_app_uid))) )
                    dict_put (next_iter_subjs, "st2", 1);
                }
            }
        }
    }

ret_or_next_iter:
  if (0 = dict_size (next_iter_subjs))
    {
      -- dbg_obj_princ ('no new subjs, res = ', dict_list_keys (res, 0));
      return res;
    }
  all_subjs := dict_list_keys (next_iter_subjs, 1);
  foreach (IRI_ID s in all_subjs) do dict_put (subj_dict, s, 1);
  goto next_iteration;
}
;

create procedure DB.DBA.SPARQL_DESC_DICT_OBJCBD (in obj_dict any, in consts any, in good_graphs any, in bad_graphs any, in storage_name any, in options any)
{
  declare all_objs, phys_objects, sorted_good_graphs, sorted_bad_graphs, next_iter_objs, res any;
  declare uid, graphs_listed, g_ctr, good_g_count, bad_g_count, obj_ctr, all_obj_count, phys_obj_count integer;
  declare gs_app_callback, gs_app_uid, inf_ruleset varchar;
  declare rdf_type_iid IRI_ID;
  uid := get_keyword ('uid', options, http_nobody_uid());
  gs_app_callback := get_keyword ('gs-app-callback', options);
  if (gs_app_callback is not null)
    gs_app_uid := get_keyword ('gs-app-uid', options);
  inf_ruleset := get_keyword ('inference', options);
  rdf_type_iid := iri_to_id (UNAME'http://www.w3.org/1999/02/22-rdf-syntax-ns#type');
  res := dict_new ();
  if (isinteger (consts))
    return res;
  foreach (any c in consts) do
    {
      if (not isnumeric (c))
        dict_put (obj_dict, c, 0);
    }
  all_objs := dict_list_keys (obj_dict, 0);
  next_iter_objs := dict_new ();
  all_obj_count := length (all_objs);
  if (0 = all_obj_count)
    return res;

next_iteration:
  all_obj_count := length (all_objs);
  gvector_sort (all_objs, 1, 0, 0);
  -- dbg_obj_princ ('new iteration: all_objs = ', all_objs);
  if (__tag of integer = __tag (good_graphs))
    graphs_listed := 0;
  else
    {
      vectorbld_init (sorted_good_graphs);
      foreach (any g in good_graphs) do
        {
          if (is_named_iri_id (g) and
            __rgs_ack_cbk (g, uid, 1) and
            (gs_app_callback is null or bit_and (1, call (gs_app_callback) (g, gs_app_uid))) )
            vectorbld_acc (sorted_good_graphs, g);
        }
      vectorbld_final (sorted_good_graphs);
      good_g_count := length (sorted_good_graphs);
      if (0 = good_g_count)
        return res;
      graphs_listed := 1;
    }
  vectorbld_init (sorted_bad_graphs);
  foreach (any g in bad_graphs) do
    {
      if (is_named_iri_id (g))
        vectorbld_acc (sorted_bad_graphs, g);
    }
  vectorbld_final (sorted_bad_graphs);
  bad_g_count := length (sorted_bad_graphs);
  vectorbld_init (phys_objects);
  if (storage_name is null)
    storage_name := 'http://www.openlinksw.com/schemas/virtrdf#DefaultQuadStorage';
  else if (('' = storage_name) and (inf_ruleset is null))
    {
      for (obj_ctr := 0; obj_ctr < all_obj_count; obj_ctr := obj_ctr + 1)
        {
          declare obj, phys_obj any;
          obj := all_objs [obj_ctr];
          if (not isnumeric (obj))
            {
              if (isiri_id (obj))
                vectorbld_acc (phys_objects, obj);
              else
                {
                  phys_obj := iri_to_id (obj, 0, 0);
                  if (not isinteger (phys_obj))
                    vectorbld_acc (phys_objects, phys_obj);
                }
            }
        }
      vectorbld_final (phys_objects);
      goto describe_physical_objects;
    }
  -- dbg_obj_princ ('storage_name=',storage_name, ' sorted_good_graphs=', sorted_good_graphs, ' sorted_bad_graphs=', sorted_bad_graphs);
  for (obj_ctr := 0; obj_ctr < all_obj_count; obj_ctr := obj_ctr + 1)
    {
      declare obj, phys_obj, maps any;
      declare maps_len integer;
      obj := all_objs [obj_ctr];
      maps := sparql_quad_maps_for_quad (NULL, NULL, NULL, obj, storage_name, case (graphs_listed) when 0 then vector() else sorted_good_graphs end, sorted_bad_graphs);
      -- dbg_obj_princ ('obj = ', obj, id_to_iri (obj), ' maps = ', maps);
      maps_len := length (maps);
      if ((maps_len > 0) and (inf_ruleset is null) and (maps[maps_len-1][0] = UNAME'http://www.openlinksw.com/schemas/virtrdf#DefaultQuadMap'))
        {
          if (not isnumeric (obj))
            {
              if (isiri_id (obj))
                {
                  phys_obj := obj;
                  vectorbld_acc (phys_objects, phys_obj);
                }
              else
                {
                  phys_obj := iri_to_id (obj, 0, 0);
                  if (not isinteger (phys_obj))
                    vectorbld_acc (phys_objects, phys_obj);
                }
            }
          maps := subseq (maps, 0, maps_len-1);
          maps_len := maps_len - 1;
        }
      if (maps_len > 0)
        all_objs [obj_ctr] := vector (obj, maps);
      else
        all_objs [obj_ctr] := 0;
      -- dbg_obj_princ ('obj = ', obj, ' maps = ', maps);
      -- dbg_obj_princ ('all_objs [', obj_ctr, '] = ', all_objs [obj_ctr]);
    }
  vectorbld_final (phys_objects);
  for (obj_ctr := 0; obj_ctr < all_obj_count; obj_ctr := obj_ctr + 1)
    {
      declare s_desc, obj, maps any;
      declare map_ctr, maps_len integer;
      declare fname varchar;
      s_desc := all_objs [obj_ctr];
      if (isinteger (s_desc))
        goto end_of_s;
      obj := s_desc[0];
      maps := s_desc[1];
      maps_len := length (maps);
      fname := sprintf ('SPARQL_DESC_DICT_OBJCBD_QMV1_%U', md5 (storage_name || inf_ruleset || cast (graphs_listed as varchar) || md5_box (maps) || md5_box (sorted_bad_graphs)));
      if (not exists (select top 1 1 from Db.DBA.SYS_PROCEDURES where P_NAME = 'DB.DBA.' || fname))
        {
          declare ses, txt, saved_user any;
          ses := string_output ();
          http ('create procedure DB.DBA."' || fname || '" (in obj any, in obj_dict any, in next_iter_objs any, in res any', ses);
          if (graphs_listed)
            http (', inout sorted_good_graphs any', ses);
          http (')\n', ses);
          http ('{\n', ses);
          http ('  declare obj_iri varchar;\n', ses);
          http ('  obj_iri := id_to_iri_nosignal (obj);\n', ses);
          if (maps_len > 0)
            {
              http ('  for (sparql define output:valmode "LONG" define input:storage <' || storage_name || '> ', ses);
              foreach (any g in sorted_bad_graphs) do
                {
                  http ('  define input:named-graph-exclude <' || id_to_iri_nosignal (g) || '>\n', ses);
                }
              if (inf_ruleset is not null)
                  http ('  define input:inference <' || inf_ruleset || '>\n', ses);
              http ('select ?g1 ?p1 ?s1 ?g2 ?st2\n', ses);
              http ('      where { graph ?g1 {\n', ses);
              for (map_ctr := 0; map_ctr < maps_len; map_ctr := map_ctr + 1)
                {
                  if (map_ctr > 0) http ('              union\n', ses);
                  http ('              { quad map <' || maps[map_ctr][0] || '> { ?s1 ?p1 ?:obj_iri } }\n', ses);
                }
              http ('            }\n', ses);
              http ('          optional { graph ?g2 {\n', ses);
              http ('                  ?st2 a rdf:Statement ; rdf:object ?:obj_iri ; rdf:predicate ?p1 ; rdf:subject ?s1 } }\n', ses);
              http ('            } ) do {\n', ses);
              if (graphs_listed)
                http ('      if (position (__i2idn ("g1"), sorted_good_graphs)) {\n', ses);
              http ('      dict_bitor_or_put (res, vector ("s1", "p1", obj), 1);\n', ses);
              http ('      if (is_bnode_iri_id ("s1") and dict_get (obj_dict, "s1") is null)\n', ses);
              http ('        dict_put (next_iter_objs, "s1", 1);\n', ses);
              if (graphs_listed)
                http ('      if (position (__i2idn ("g2"), sorted_good_graphs)) {\n', ses);
              http ('      if ("st2" is not null and dict_get (obj_dict, "st2") is null)\n', ses);
              http ('        dict_put (next_iter_objs, "s1", 1);\n', ses);
              if (graphs_listed)
                http ('        } }\n', ses);
              http ('      }\n', ses);
            }
          http ('}\n', ses);
          txt := string_output_string (ses);
          -- dbg_obj_princ ('Procedure text: ', txt);
          saved_user := user;
          set_user_id ('dba', 1);
          exec (txt);
          set_user_id (saved_user);
        }
      if (graphs_listed)
        {
          -- dbg_obj_princ ('call (''DB.DBA.', fname, ''')(', obj, obj_dict, next_iter_objs, res, sorted_good_graphs, ')');
          call ('DB.DBA.' || fname)(obj, obj_dict, next_iter_objs, res, sorted_good_graphs);
        }
      else
        {
          -- dbg_obj_princ ('call (''DB.DBA.', fname, ''')(', obj, obj_dict, next_iter_objs, res, ')');
          call ('DB.DBA.' || fname)(obj, obj_dict, next_iter_objs, res);
        }
end_of_s: ;
    }

describe_physical_objects:
  gvector_sort (phys_objects, 1, 0, 0);
  phys_obj_count := length (phys_objects);
  -- dbg_obj_princ ('phys_objects = ', phys_objects);
  if (0 = phys_obj_count)
    return res;
  -- dbg_obj_princ ('sorted_bad_graphs = ', sorted_bad_graphs);
  if (graphs_listed)
    {
      gvector_sort (sorted_good_graphs, 1, 0, 0);
      -- dbg_obj_princ ('sorted_good_graphs = ', sorted_good_graphs);
      for (g_ctr := good_g_count - 1; g_ctr >= 0; g_ctr := g_ctr - 1)
        {
          declare graph any;
          graph := sorted_good_graphs [g_ctr];
          for (obj_ctr := phys_obj_count - 1; obj_ctr >= 0; obj_ctr := obj_ctr - 1)
            {
              declare obj any;
              obj := phys_objects [obj_ctr];
              for (select P as p1, S as subj1 from DB.DBA.RDF_QUAD where G = graph and O = obj) do
                {
                  -- dbg_obj_princ ('found3 ', subj1, p1, obj, ' in ', graph);
                  dict_bitor_or_put (res, vector (subj1, p1, __rdf_long_of_obj (obj)), 1);
                  if (is_bnode_iri_id (subj1) and dict_get (obj_dict, subj1) is null)
                    dict_put (next_iter_objs, subj1, 1);
                  for (sparql define output:valmode "LONG"
                    select ?g2 ?st2 where {
                        graph ?g2 {
                            ?st2 a rdf:Statement ; rdf:object ?:obj ; rdf:predicate ?:p1 ; rdf:subject ?:subj1 } } ) do
                    {
                      if (position ("g2", sorted_good_graphs) and dict_get (obj_dict, "st2") is null)
                        dict_put (next_iter_objs, "st2", 1);
                    }
                }
            }
        }
    }
  else
    {
      for (obj_ctr := phys_obj_count - 1; obj_ctr >= 0; obj_ctr := obj_ctr - 1)
        {
          declare obj any;
          obj := phys_objects [obj_ctr];
          for (select P as p1, S as subj1 from DB.DBA.RDF_QUAD where
            0 = position (G, sorted_bad_graphs) and
            O = obj and
            __rgs_ack_cbk (G, uid, 1) and
            (gs_app_callback is null or bit_and (1, call (gs_app_callback) (G, gs_app_uid))) ) do
            {
              -- dbg_obj_princ ('found4 ', obj, p1);
              dict_bitor_or_put (res, vector (subj1, p1, __rdf_long_of_obj (obj)), 1);
              if (is_bnode_iri_id (subj1) and dict_get (obj_dict, subj1) is null)
                dict_put (next_iter_objs, subj1, 1);
              for (sparql define output:valmode "LONG"
                select ?g2 ?st2 where {
                    graph ?g2 {
                        ?st2 a rdf:Statement ; rdf:object ?:obj ; rdf:predicate ?:p1 ; rdf:subject ?:subj1 } } ) do
                {
                  if (0 = position ("g2", sorted_bad_graphs) and
                    dict_get (obj_dict, "st2") is null and
                    __rgs_ack_cbk ("g2", uid, 1) and
                    (gs_app_callback is null or bit_and (1, call (gs_app_callback) ("g2", gs_app_uid))) )
                    dict_put (next_iter_objs, "st2", 1);
                }
            }
        }
    }
ret_or_next_iter:
  if (0 = dict_size (next_iter_objs))
    {
      -- dbg_obj_princ ('no new objs, res = ', dict_list_keys (res, 0));
      return res;
    }
  all_objs := dict_list_keys (next_iter_objs, 1);
  foreach (IRI_ID obj in all_objs) do dict_put (obj_dict, obj, 1);
  goto next_iteration;
}
;

create procedure DB.DBA.SPARQL_DESC_DICT_OBJCBD_PHYSICAL (in obj_dict any, in consts any, in good_graphs any, in bad_graphs any, in storage_name any, in options any)
{
  declare all_objs, sorted_good_graphs, sorted_bad_graphs, next_iter_objs, res any;
  declare uid, graphs_listed, g_ctr, good_g_count, bad_g_count, obj_ctr, all_obj_count integer;
  declare gs_app_callback, gs_app_uid varchar;
  declare rdf_type_iid IRI_ID;
  uid := get_keyword ('uid', options, http_nobody_uid());
  gs_app_callback := get_keyword ('gs-app-callback', options);
  if (gs_app_callback is not null)
    gs_app_uid := get_keyword ('gs-app-uid', options);
  rdf_type_iid := iri_to_id (UNAME'http://www.w3.org/1999/02/22-rdf-syntax-ns#type');
  res := dict_new ();
  if (isinteger (consts))
    return res;
  foreach (any c in consts) do
    {
      if (not isnumeric (c))
        dict_put (obj_dict, c, 0);
    }
  all_objs := dict_list_keys (obj_dict, 0);
  next_iter_objs := dict_new ();
  all_obj_count := length (all_objs);
  if (0 = all_obj_count)
    return res;

next_iteration:
  all_obj_count := length (all_objs);
  gvector_sort (all_objs, 1, 0, 0);
  -- dbg_obj_princ ('new iteration: all_objs = ', all_objs);
  if (__tag of integer = __tag (good_graphs))
    graphs_listed := 0;
  else
    {
      vectorbld_init (sorted_good_graphs);
      foreach (any g in good_graphs) do
        {
          if (is_named_iri_id (g) and
            __rgs_ack_cbk (g, uid, 1) and
            (gs_app_callback is null or bit_and (1, call (gs_app_callback) (g, gs_app_uid))) )
            vectorbld_acc (sorted_good_graphs, g);
        }
      vectorbld_final (sorted_good_graphs);
      good_g_count := length (sorted_good_graphs);
      if (0 = good_g_count)
        return res;
      graphs_listed := 1;
    }
  vectorbld_init (sorted_bad_graphs);
  foreach (any g in bad_graphs) do
    {
      if (isnamed_iri_id (g))
        vectorbld_acc (sorted_bad_graphs, g);
    }
  vectorbld_final (sorted_bad_graphs);
  bad_g_count := length (sorted_bad_graphs);
  -- dbg_obj_princ ('all_objs = ', all_objs);
  if (0 = all_obj_count)
    return res;
  -- dbg_obj_princ ('sorted_bad_graphs = ', sorted_bad_graphs);
  if (graphs_listed)
    {
      gvector_sort (sorted_good_graphs, 1, 0, 0);
      -- dbg_obj_princ ('sorted_good_graphs = ', sorted_good_graphs);
      for (g_ctr := good_g_count - 1; g_ctr >= 0; g_ctr := g_ctr - 1)
        {
          declare graph any;
          graph := sorted_good_graphs [g_ctr];
          for (obj_ctr := all_obj_count - 1; obj_ctr >= 0; obj_ctr := obj_ctr - 1)
            {
              declare obj any;
              obj := all_objs [obj_ctr];
              for (select P as p1, S as subj1 from DB.DBA.RDF_QUAD where G = graph and O = obj) do
                {
                  -- dbg_obj_princ ('found3 ', subj1, p1, obj, ' in ', graph);
                  dict_bitor_or_put (res, vector (subj1, p1, __rdf_long_of_obj (obj)), 1);
                  if (is_bnode_iri_id (subj1) and dict_get (obj_dict, subj1) is null)
                    dict_put (next_iter_objs, subj1, 1);
                  for (sparql define output:valmode "LONG"
                    select ?g2 ?st2 where {
                        graph ?g2 {
                            ?st2 a rdf:Statement ; rdf:object ?:obj ; rdf:predicate ?:p1 ; rdf:subject ?:subj1 } } ) do
                    {
                      if (position ("g2", sorted_good_graphs) and dict_get (obj_dict, "st2") is null)
                        dict_put (next_iter_objs, "st2", 1);
                    }
                }
            }
        }
    }
  else
    {
      for (obj_ctr := all_obj_count - 1; obj_ctr >= 0; obj_ctr := obj_ctr - 1)
        {
          declare obj any;
          obj := all_objs [obj_ctr];
          for (select P as p1, S as subj1 from DB.DBA.RDF_QUAD where
            0 = position (G, sorted_bad_graphs) and
            O = obj and
            __rgs_ack_cbk (G, uid, 1) and
            (gs_app_callback is null or bit_and (1, call (gs_app_callback) (G, gs_app_uid))) ) do
            {
              -- dbg_obj_princ ('found4 ', subj1, p1, obj);
              dict_bitor_or_put (res, vector (subj1, p1, __rdf_long_of_obj (obj)), 1);
              if (is_bnode_iri_id (subj1) and dict_get (obj_dict, subj1) is null)
                dict_put (next_iter_objs, subj1, 1);
              for (sparql define output:valmode "LONG"
                select ?g2 ?st2 where {
                    graph ?g2 {
                        ?st2 a rdf:Statement ; rdf:object ?:obj ; rdf:predicate ?:p1 ; rdf:subject ?:subj1 } } ) do
                {
                  if (0 = position ("g2", sorted_bad_graphs) and
                    dict_get (obj_dict, "st2") is null and
                    __rgs_ack_cbk ("g2", uid, 1) and
                    (gs_app_callback is null or bit_and (1, call (gs_app_callback) ("g2", gs_app_uid))) )
                    dict_put (next_iter_objs, "st2", 1);
                }
            }
        }
    }

ret_or_next_iter:
  if (0 = dict_size (next_iter_objs))
    {
      -- dbg_obj_princ ('no new objs, res = ', dict_list_keys (res, 0));
      return res;
    }
  all_objs := dict_list_keys (next_iter_objs, 1);
  foreach (IRI_ID obj in all_objs) do dict_put (obj_dict, obj, 1);
  goto next_iteration;
}
;

create procedure DB.DBA.SPARQL_DESC_DICT_SCBD (in node_dict any, in consts any, in good_graphs any, in bad_graphs any, in storage_name any, in options any)
{
  declare cbd_res, objcbd_res, triples any;
  cbd_res := DB.DBA.SPARQL_DESC_DICT_CBD (node_dict, consts, good_graphs, bad_graphs, storage_name, options);
  objcbd_res := DB.DBA.SPARQL_DESC_DICT_OBJCBD (node_dict, consts, good_graphs, bad_graphs, storage_name, options);
again:
  triples := dict_destructive_list_rnd_keys (objcbd_res, 80000);
  if (0 = length (triples))
    return cbd_res;
  foreach (any triple in triples) do { dict_put (cbd_res, triple, 1); }
  goto again;
}
;

create procedure DB.DBA.SPARQL_DESC_DICT_SCBD_PHYSICAL (in node_dict any, in consts any, in good_graphs any, in bad_graphs any, in storage_name any, in options any)
{
  declare cbd_res, objcbd_res, triples any;
  cbd_res := DB.DBA.SPARQL_DESC_DICT_CBD_PHYSICAL (node_dict, consts, good_graphs, bad_graphs, storage_name, options);
  objcbd_res := DB.DBA.SPARQL_DESC_DICT_OBJCBD_PHYSICAL (node_dict, consts, good_graphs, bad_graphs, storage_name, options);
again:
  triples := dict_destructive_list_rnd_keys (objcbd_res, 80000);
  if (0 = length (triples))
    return cbd_res;
  foreach (any triple in triples) do { dict_put (cbd_res, triple, 1); }
  goto again;
}
;

--!AWK PUBLIC
create procedure DB.DBA.RDF_DICT_OF_TRIPLES_TO_THREE_COLS (in dict any, in destructive integer := 0)
{
  declare ctr, len, max_batch_sz integer;
  declare editable_dict, triples, O any;
  declare S, P, O_DT, O_LANG varchar;
  declare O_IS_IRI, dt_twobyte, lang_twobyte integer;
  result_names (S, P, O);
  max_batch_sz := __min (sys_stat ('dc_max_batch_sz'), 1000000);
  editable_dict := null;
  if (not destructive and dict_size (dict) > max_batch_sz)
    editable_dict := dict_duplicate (dict);
next_batch:
  if (editable_dict is not null)
    {
      if (dict_size (editable_dict))
        triples := dict_destructive_list_rnd_keys (editable_dict, max_batch_sz);
      else
        return;
    }
  else
    {
      if (dict_size (dict))
        {
          if (dict_size (dict) > max_batch_sz)
            triples := dict_destructive_list_rnd_keys (dict, max_batch_sz);
          else
            {
              triples := dict_list_keys (dict, destructive);
              dict := null;
            }
        }
      else
        return;
    }
  DB.DBA.RDF_TRIPLES_BATCH_COMPLETE (triples);
--  exec_result_names (vector (vector ('S', 182, 0, 4072, 1, 0, 1, 0, 0, 0, 0, 0), vector ('P', 182, 0, 4072, 1, 0, 1, 0, 0, 0, 0, 0), vector ('O', 125, 0, 2147483647, 1, 0, 0, 0, 0, 0, 0, 0)));
  len := length (triples);
  for (ctr := 0; ctr < len; ctr := ctr+1)
    {
      if (isiri_id (triples[ctr][0]))
        S := id_to_iri (triples[ctr][0]);
      else
        S := triples[ctr][0];

      if (isiri_id (triples[ctr][1]))
        P := id_to_iri (triples[ctr][1]);
      else
        P := triples[ctr][1];
      O := triples[ctr][2];
      if (isiri_id (O))
        {
          result (S, P, id_to_iri (O) --, 1, NULL, NULL
          );
        }
--      else if (is_rdf_box (O))
--        {
--          dt_twobyte := rdf_box_type (O);
--          O_DT := case (dt_twobyte) when 257 then NULL else coalesce (
--            (select id_to_iri (RDT_IID) from DB.DBA.RDF_DATATYPE where RDT_TWOBYTE = dt_twobyte) ) end;
--          lang_twobyte := rdf_box_lang (O);
--          O_LANG := case (lang_twobyte) when 257 then NULL else coalesce (
--            (select lower (RL_ID) from DB.DBA.RDF_LANGUAGE where RL_TWOBYTE = lang_twobyte) ) end;
--          result (S, P, O, 0, O_DT, O_LANG);
--        }
      else if (S is not null and P is not null and O is not null)
        result (S, P, O --, 0, __xsd_type (O, NULL), NULL
        );
    }
  goto next_batch;
}
;

--!AWK PUBLIC
create procedure DB.DBA.RDF_DICT_OF_TRIPLES_TO_FOUR_COLS (in dict any, in destructive integer := 0)
{
  declare ctr, len integer;
  declare triples, O any;
  declare S, P, O_DT, O_LANG varchar;
  declare O_IS_IRI, dt_twobyte, lang_twobyte integer;
  triples := dict_list_keys (dict, destructive);
  DB.DBA.RDF_TRIPLES_BATCH_COMPLETE (triples);
  exec_result_names (vector (vector ('S', 182, 0, 4072, 1, 0, 1, 0, 0, 0, 0, 0), vector ('P', 182, 0, 4072, 1, 0, 1, 0, 0, 0, 0, 0), vector ('O', 182, 0, 2147483647, 1, 0, 0, 0, 0, 0, 0, 0), vector ('O_TYPE', 182, 0, 4072, 1, 0, 1, 0, 0, 0, 0, 0)));
  len := length (triples);
  for (ctr := 0; ctr < len; ctr := ctr+1)
    {
      if (isiri_id (triples[ctr][0]))
        S := id_to_iri (triples[ctr][0]);
      else
        S := triples[ctr][0];

      if (isiri_id (triples[ctr][1]))
        P := id_to_iri (triples[ctr][1]);
      else
        P := triples[ctr][1];
      O := triples[ctr][2];
      if (isiri_id (O))
        {
          result (S, P, id_to_iri (O), NULL);
        }
      else if (is_rdf_box (O))
        {
          dt_twobyte := rdf_box_type (O);
          O_DT := case (dt_twobyte) when 257 then NULL else coalesce (
            (select id_to_iri (RDT_IID) from DB.DBA.RDF_DATATYPE where RDT_TWOBYTE = dt_twobyte) ) end;
          lang_twobyte := rdf_box_lang (O);
          --O_LANG := case (lang_twobyte) when 257 then NULL else coalesce (
          --  (select lower (RL_ID) from DB.DBA.RDF_LANGUAGE where RL_TWOBYTE = lang_twobyte) ) end;
          result (S, P, O, coalesce (O_DT, ''));
        }
      else if (S is not null and P is not null and O is not null)
        result (S, P, O, coalesce (__xsd_type (O, NULL), ''));
    }
}
;

-----
-- Internal functions used in SQL generated by SPARQL compiler.
-- They will change frequently, do not try to use them in applications!

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
create function DB.DBA.RDF_DIST_SER_LONG (in val any) returns any
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
create function DB.DBA.RDF_DIST_DESER_LONG (in strg any) returns any
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

create function DB.DBA.JSO_MAKE_INHERITANCE (in jgraph varchar, in class varchar, in rootinst varchar, in destinst varchar, in dest_iid iri_id, inout noinherits any, inout inh_stack any)
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
-- This fails. !!!TBD: fix sparql2sql.c to preserve data about equalities, fixed values and globals when triples are moved from gp to gp
--  for (sparql
--    define input:storage ""
--    prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
--    select ?pred
--    where {
--        graph ?:jgraph {
--            { {
--                ?destnode rdf:type `iri(?:class)` .
--                filter (?destnode = iri(?:destinst)) }
--              union
--              {
--                ?destnode rdf:type `iri(?:class)` .
--                ?destnode rdf:name `iri(?:destinst)` } } .
--            ?destnode virtrdf:noInherit ?pred .
--           } } ) do
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
  for (select "pred_id", "predval"
    from (sparql
      define input:storage ""
      define output:valmode "LONG"
      prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
      select ?pred_id, ?predval
      where {
          graph ?:jgraph {
              ?:base_iid ?pred_id ?predval
            } } ) as "t00"
      where not exists (sparql
          define input:storage ""
          prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
          ask where { graph ?:jgraph { ?:"t00"."pred_id" virtrdf:loadAs virtrdf:jsoTriple } } )
      ) do
    {
      declare "pred" any;
      "pred" := id_to_iri ("pred_id");
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
  DB.DBA.JSO_MAKE_INHERITANCE (jgraph, class, rootinst, baseinst, base_iid, noinherits, inh_stack);
}
;

create function DB.DBA.JSO_LOAD_INSTANCE (in jgraph varchar, in jinst varchar, in delete_first integer, in make_new integer, in jsubj_iid iri_id := null)
{
  declare jinst_iid, jgraph_iid IRI_ID;
  declare jclass varchar;
  declare noinherits, inh_stack, "p" any;
  -- dbg_obj_princ ('JSO_LOAD_INSTANCE (', jgraph, ')');
  noinherits := dict_new ();
  jinst_iid := iri_ensure (jinst);
  jgraph_iid := iri_ensure (jgraph);
  if (jsubj_iid is null)
    {
      jsubj_iid := (sparql
        define input:storage ""
        define output:valmode "LONG"
        select ?s
        where { graph ?:jgraph { ?s rdf:name ?:jinst } } );
      if (jsubj_iid is null)
        jsubj_iid := jinst_iid;
    }
  jclass := (sparql
    define input:storage ""
    select ?t
    where {
      graph ?:jgraph { ?:jsubj_iid rdf:type ?t } } );
  if (jclass is null)
    {
      if (exists (sparql
          define input:storage ""
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
  for (select "p_id", coalesce ("o2", "o1") as "o"
      from (sparql
          define input:storage ""
          define output:valmode "LONG"
          select ?p_id ?o1 ?o2
          where {
          graph ?:jgraph_iid {
              { ?:jsubj_iid ?p_id ?o1 }  optional { ?o1 rdf:name ?o2 }
            } }
        ) as "t00"
      where not exists (sparql
          define input:storage ""
          prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
          ask where { graph ?:jgraph_iid { ?:"t00"."p_id" virtrdf:loadAs virtrdf:jsoTriple } } ) option (quietcast)
      ) do
    {
      "p" := id_to_iri ("p_id");
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
  DB.DBA.JSO_MAKE_INHERITANCE (jgraph, jclass, jinst, jinst, jsubj_iid, noinherits, inh_stack);
}
;

create procedure DB.DBA.JSO_LIST_INSTANCES_OF_GRAPH (in jgraph varchar, out instances any)
{
  declare md, res, st, msg any;
  st:= '00000';
  exec (
    'select DB.DBA.VECTOR_AGG (
      vector (
        id_to_iri ("jclass"),
        id_to_iri ("jinst"),
        coalesce ("s", "jinst") ) )
    from ( sparql
      define output:valmode "LONG"
      define input:storage ""
      select ?jclass ?jinst ?s
      where {
        graph ?? {
          { ?jinst rdf:type ?jclass .
            filter (!isBLANK (?jinst)) }
          union
          { ?s rdf:type ?jclass .
            ?s rdf:name ?jinst .
            filter (isBLANK (?s))
            } } }
      ) as inst',
    st, msg, vector (jgraph), 1, md, res);
  if (st <> '00000') signal (st, msg);
 	instances := res[0][0];
}
;


create procedure DB.DBA.CL_EXEC_AND_LOG (in txt varchar, in args any)
{
  DB.DBA.CL_EXEC (txt, args);
  DB.DBA.CL_EXEC ('log_text_array (?, ?)', vector (txt, args), 1);
}
;

create function DB.DBA.JSO_LOAD_GRAPH_MEMONLY (in jgraph varchar, in pin_now integer, in instances any, in triples any)
{
  declare chk any;
/* Pass 1. Deleting all obsolete instances. */
  foreach (any j in instances) do
    jso_delete (j[0], j[1], 1);
/* Pass 2. Creating all instances. */
  foreach (any j in instances) do
    jso_new (j[0], j[1]);
/* Pass 3. Loading all instances, including loading inherited values. */
  foreach (any j in instances) do
    DB.DBA.JSO_LOAD_INSTANCE (jgraph, j[1], 0, 0, j[2]);
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
  foreach (any t in triples) do
    jso_triple_add (t[0], t[1], t[2]);
  chk := jso_triple_get_objs (
    UNAME'http://www.openlinksw.com/schemas/virtrdf#loadAs',
    UNAME'http://www.openlinksw.com/schemas/virtrdf#loadAs' );
  if ((1 <> length (chk)) or (cast (chk[0] as varchar) <> 'http://www.openlinksw.com/schemas/virtrdf#jsoTriple'))
    signal ('22023', 'JSO_LOAD_GRAPH_MEMONLY has not found expected metadata in the graph');
}
;

create function DB.DBA.JSO_LOAD_GRAPH (in jgraph varchar, in pin_now integer := 1)
{
  declare jgraph_iid IRI_ID;
  declare qry, stat, msg varchar;
  declare instances, mdata, rset, triples any;
  -- dbg_obj_princ ('JSO_LOAD_GRAPH (', jgraph, ')');
  jgraph_iid := iri_ensure (jgraph);
  DB.DBA.JSO_LIST_INSTANCES_OF_GRAPH (jgraph, instances);
  qry := 'sparql
    define input:storage ""
    define sql:table-option "LOOP"
    prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
    select (sql:VECTOR_AGG (bif:vector (?s, ?p, ?o)))
    where { graph <' || id_to_iri (jgraph_iid) || '> { ?p virtrdf:loadAs virtrdf:jsoTriple . ?s ?p ?o } }';
  stat := '00000';
  exec (qry, stat, msg, vector(), 1, mdata, rset);
  if (stat <> '00000')
    signal (stat, msg);
  triples := rset[0][0];
  DB.DBA.JSO_LOAD_GRAPH_MEMONLY (jgraph, pin_now, instances, triples);
}
;

create function DB.DBA.JSO_PIN_GRAPH_MEMONLY (in jgraph varchar, in instances any)
{
  foreach (any j in instances) do
    jso_pin (j[0], j[1]);
}
;

create function DB.DBA.JSO_PIN_GRAPH (in jgraph varchar)
{
  declare instances any;
  DB.DBA.JSO_LIST_INSTANCES_OF_GRAPH (jgraph, instances);
  DB.DBA.JSO_PIN_GRAPH_MEMONLY (jgraph, instances);
}
;

--!AWK PUBLIC
create function DB.DBA.JSO_SYS_GRAPH () returns varchar
{
  return 'http://www.openlinksw.com/schemas/virtrdf#';
}
;

-- same as DB.DBA.JSO_LOAD_AND_PIN_SYS_GRAPH but no drop procedures
create procedure DB.DBA.JSO_LOAD_AND_PIN_SYS_GRAPH_RO (in graphiri varchar := null)
{
  if (graphiri is null)
    graphiri := DB.DBA.JSO_SYS_GRAPH();
  if (not exists (select 1 from SYS_KEYS where KEY_TABLE = 'DB.DBA.RDF_QUAD'))
    return;
  DB.DBA.JSO_LOAD_GRAPH (graphiri, 0);
  DB.DBA.JSO_PIN_GRAPH (graphiri);
}
;

create procedure DB.DBA.JSO_LOAD_AND_PIN_SYS_GRAPH (in graphiri varchar := null)
{
  if (graphiri is null)
    graphiri := DB.DBA.JSO_SYS_GRAPH();
  commit work;
  DB.DBA.JSO_LOAD_GRAPH (graphiri, 0);
  DB.DBA.JSO_PIN_GRAPH (graphiri);
  for (select P_NAME from SYS_PROCEDURES
    where (
      (P_NAME > 'DB.DBA.SPARQL_DESC_DICT') and
      (P_NAME < 'DB.DBA.SPARQL_DESC_DICU') and
      (
        (P_NAME like 'DB.DBA.SPARQL_DESC_DICT_QMV1_%') or
        (P_NAME like 'DB.DBA.SPARQL_DESC_DICT_CBD_QMV1_%') or
        (P_NAME like 'DB.DBA.SPARQL_DESC_DICT_OBJCBD_QMV1_%') or
        (P_NAME like 'DB.DBA.SPARQL_DESC_DICT_SCBD_QMV1_%') ) )
    for update) do
    {
      exec ('drop procedure DB.DBA."' || subseq (P_NAME, 7) || '"');
    }
  commit work;
}
;

create function DB.DBA.JSO_DUMP_IRI (in v varchar, inout ses any)
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

create function DB.DBA.JSO_DUMP_FLD (in v any, inout ses any)
{
  declare v_tag integer;
  v_tag := __tag(v);
  if (v_tag = 217)
    DB.DBA.JSO_DUMP_IRI (cast (v as varchar), ses);
  else if (v_tag = 243)
    DB.DBA.JSO_DUMP_IRI (id_to_iri (v), ses);
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
      http_escape (__rdf_strsqlval (v), 11, ses, 1, 1);
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
        http (' ;\n  ', ses);
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
	    http (' .\n', ses);
	  prev_obj := obj;
	  DB.DBA.JSO_DUMP_FLD (obj, ses);
          http ('\n  ', ses);
	}
      DB.DBA.JSO_DUMP_FLD (p, ses);
      http ('\t', ses);
      DB.DBA.JSO_DUMP_FLD (o, ses);
    }
  if (prev_obj is not null)
    http (' .\n', ses);
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
      proplist := ((select DB.DBA.VECTOR_AGG (vector ("sub"."s", "sub"."p", "sub"."o")) from (
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
      inh_id := iri_ensure ('http://www.openlinksw.com/schemas/virtrdf#inheritFrom');
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
            obj_long := iri_ensure (obj);
          else
            obj_long := obj;
          if (217 = __tag (p))
            p_long := iri_ensure (p);
          else
            p_long := p;
          if (217 = __tag (o))
            o_long := iri_ensure (o);
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
    proplist := ((select DB.DBA.VECTOR_AGG (vector ("sub"."s", "sub"."p", "sub"."o")) from (
          sparql define input:storage "" define output:valmode "LONG"
          select ?s ?p ?o where { graph `iri(?:backup_name)` { ?s ?p ?o } } ) as "sub"));
  if (0 = length (proplist))
    signal ('22023', sprintf ('There are no metadata in %.200 to restore', backup_name));
  graphiri_id := iri_ensure (DB.DBA.JSO_SYS_GRAPH ());
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
      if (pl <> iri_ensure ('http://www.openlinksw.com/schemas/virtrdf#status'))
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
  graphiri_id := iri_to_id (graphiri);
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
          for (sparql define input:storage ""
            prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
            select ?s from <http://www.openlinksw.com/schemas/virtrdf#> where {
                ?s rdf:type virtrdf:array-of-QuadMap } ) do
            {
              if (DB.DBA.RDF_QM_GC_SUBTREE ("s", 3) is null)
                result ('00000', 'Quad map array <' || "s" || '> is not used, removed');
            }
          for (sparql define input:storage ""
            prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
            select ?s from <http://www.openlinksw.com/schemas/virtrdf#> where {
                ?s rdf:type virtrdf:QuadMap } ) do
            {
              if (DB.DBA.RDF_QM_GC_MAPPING_SUBTREE ("s", 1) is null)
                result ('00000', 'Quad map <' || "s" || '> is not used, removed');
            }
          for (sparql define input:storage ""
            prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
            select ?s from <http://www.openlinksw.com/schemas/virtrdf#> where {
                ?s rdf:type virtrdf:array-of-QuadMapFormat } ) do
            {
              if (DB.DBA.RDF_QM_GC_SUBTREE ("s", 3) is null)
                result ('00000', 'Quad map format array <' || "s" || '> is not used, removed');
            }
          for (sparql define input:storage ""
            prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
            select ?s from <http://www.openlinksw.com/schemas/virtrdf#> where {
                ?s rdf:type virtrdf:QuadMapFormat } ) do
            {
              if (DB.DBA.RDF_QM_GC_SUBTREE ("s", 3) is null)
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
          sparql define input:storage ""
          delete from graph ?:graphiri_id { ?:"lst" ?:"p" ?:"itm" };
        }
    }
  vectorbld_init (all_lists);
  prev_subj := #i0;
  for (
    select "sub"."lst", cast ("sub"."idx" as integer) as "idx", serialize ("sub"."itm") as "itmsz", "sub"."itmstr", "sub"."itmislit", "sub"."t"
    from (sparql define input:storage "" define output:valmode "LONG"
      select ?lst
        (bif:aref (bif:sprintf_inverse (str(?p),
            bif:concat (str (rdf:_), "%d"), 2 ),
          0 ) ) as ?idx
       ?itm
       (str(?itm)) as ?itmstr
       (isliteral(?itm)) as ?itmislit
       ?t
     where { graph ?:graphiri_id {
              ?lst ?p ?itm .
              optional { ?itm a ?t } .
              filter (
              str(?p) > str(rdf:_) && str(?p) < str(rdf:_A))
               } } ) as "sub"
    order by 1, 2, 3, 4 ) do
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
      vectorbld_acc (prev_list, vector ("idx", deserialize("itmsz"), "itmstr", "itmislit", "t"));
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
              result ('42000', sprintf ('Items rdf:_%d to rdf:_%d are not set in list <%s>', last_idx + 1, curr_idx - 1, id_to_iri (subj)));
              list_needs_rebuild := 1;
            }
          else
            {
              while ((last_idx + 1) < curr_idx)
                {
                  result ('42000', sprintf ('Item rdf:_%d is not set in list <%s>', last_idx + 1, id_to_iri (subj)));
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
              declare objstr varchar;
              declare objislit integer;
              curr_idx := items[pos][0];
              obj := items[pos][1];
              objstr := items[pos][2];
              objislit := items[pos][3];
              if (objislit)
                {
                  sparql define input:storage ""
                  insert into graph ?:graphiri_id {
                    `iri(?:subj)` `iri (bif:sprintf ("%s%d", str (rdf:_), 1 + ?:pos))` ?:obj };
                }
              else
                {
                  sparql define input:storage ""
                  insert into graph ?:graphiri_id {
                    `iri(?:subj)` `iri (bif:sprintf ("%s%d", str (rdf:_), 1 + ?:pos))` `iri(?:objstr)` };
                }
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
-- Internal routines for SPARQL macro library and quad map syntax extensions

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
      warnings := exec (string_output_string (exectext), STATE, MESSAGE, arglist, 10000, md, rs);
      -- dbg_obj_princ ('md = ', md, ' rs = ', rs, ' warnings = ', warnings, STATE, MESSAGE);
      if (__tag of vector <> __tag (warnings) and __tag of vector = __tag (rs))
        warnings := case (length (rs)) when 0 then null else rs[0][0] end;
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
    {
      jso_delete (deleted [ctr], deleted [ctr+1], 1);
      log_text ('jso_delete (?,?,1)', deleted [ctr], deleted [ctr+1]);
    }
  len := length (affected);
  for (ctr := 0; ctr < len; ctr := ctr + 1)
    {
      jso_mark_affected (affected [ctr]);
      log_text ('jso_mark_affected (?)', affected [ctr]);
    }
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
          signal ('22023', 'The RDF QM schema object <' || inst || '> does not exist, should be of type <' || expected || '>');
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

create function DB.DBA.RDF_QM_GC_SUBTREE (in seed any, in gc_flags integer := 0) returns integer
{ -- gc_flags: 0x1 = quick gc only, 0x2 = override virtrdf:isGcResistantType
  declare graphiri varchar;
  declare seed_id, graphiri_id, subjs, objs any;
  declare o_to_s, s_to_o any;
  declare subjs_of_o, objs_of_s any;
  set isolation = 'serializable';
  -- dbg_obj_princ ('DB.DBA.RDF_QM_GC_SUBTREE (', seed, '), ', seed, '=', id_to_iri(iri_to_id(seed)));
  o_to_s := dict_new ();
  s_to_o := dict_new ();
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  graphiri_id := iri_to_id (graphiri);
  seed_id := iri_to_id (seed);
  for (sparql define input:storage ""
    define output:valmode "LONG"
    select ?s
    from <http://www.openlinksw.com/schemas/virtrdf#>
    where { ?s virtrdf:item ?:seed_id } ) do
    {
      -- dbg_obj_princ ('DB.DBA.RDF_QM_GC_SUBTREE (', seed, ') found virtrdf:item subject ', "s");
      return "s";
    }
  if (not bit_and (gc_flags, 2))
    {
      for (sparql define input:storage ""
        define output:valmode "LONG"
        select ?t ?n
        from <http://www.openlinksw.com/schemas/virtrdf#>
        where { ?:seed_id a ?t . ?t virtrdf:isGcResistantType ?n } ) do
        {
          -- dbg_obj_princ ('DB.DBA.RDF_QM_GC_SUBTREE (', seed, ') has gc-resistant type ', "t", ' resistance ', "n");
          return "t";
        }
    }
  for (sparql define input:storage ""
    define output:valmode "LONG"
    select ?s
    from <http://www.openlinksw.com/schemas/virtrdf#>
    where { ?s a [] ; ?p ?:seed_id } ) do
    {
      -- dbg_obj_princ ('DB.DBA.RDF_QM_GC_SUBTREE (', seed, ') found use case ', "s");
      if (bit_and (gc_flags, 1))
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
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s virtrdf:isSubClassOf ?o }
  from <http://www.openlinksw.com/schemas/virtrdf#>
  where { ?s virtrdf:isSubClassOf ?o . filter (?o = iri(?:seed_id)) };

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

create function DB.DBA.RDF_QM_GC_MAPPING_SUBTREE (in mapname any, in gc_flags integer) returns any
{
  declare gc_res, submaps any;
  submaps := (select DB.DBA.VECTOR_AGG (s1."subm") from (
      sparql define input:storage ""
      select ?subm where {
          graph <http://www.openlinksw.com/schemas/virtrdf#> {
            `iri(?:mapname)` virtrdf:qmUserSubMaps ?submlist .
                    ?submlist ?p ?subm . filter (?p != rdf:type) . ?subm a [] } } ) as s1 );
  gc_res := DB.DBA.RDF_QM_GC_SUBTREE (mapname, gc_flags);
  if (gc_res is not null)
    return gc_res;
  commit work;
  foreach (any submapname in submaps) do
    {
      DB.DBA.RDF_QM_GC_MAPPING_SUBTREE (submapname, gc_flags);
    }
  return NULL;
}
;

create function DB.DBA.RDF_QM_DROP_MAPPING (in storage varchar, in mapname any) returns any
{
  declare graphiri varchar;
  declare qmid, qmgraph varchar;
  declare silent integer;
  qmid := get_keyword_ucase ('ID', mapname, NULL);
  qmgraph := get_keyword_ucase ('GRAPH', mapname, NULL);
  silent := get_keyword_ucase ('SILENT', mapname, 0);
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
  else
    {
      if (silent and not exists ((sparql define input:storage ""
        prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
        select (1) where {
            graph ?:graphiri {
                `iri(?:qmid)` a ?t } } ) ) )
        return vector (vector ('00000', 'Quad map <' || qmid || '> does not exist, the DROP statement is ignored due to SILENT option'));
    }
  DB.DBA.RDF_QM_ASSERT_JSO_TYPE (qmid, 'http://www.openlinksw.com/schemas/virtrdf#QuadMap');
  if (storage is null)
    {
      declare report, storages any;
      vectorbld_init (storages);
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
          DB.DBA.RDF_QM_ASSERT_STORAGE_FLAG ("st", 0);
          vectorbld_acc (storages, cast ("st" as varchar));
        }
      vectorbld_final (storages);
      vectorbld_init (report);
      foreach (varchar alt_st in storages) do
        {
          -- dbg_obj_princ ('Will run DB.DBA.RDF_QM_DELETE_MAPPING_FROM_STORAGE (', alt_st, ', NULL, ', qmid, ')');
          DB.DBA.RDF_QM_DELETE_MAPPING_FROM_STORAGE (alt_st, NULL, qmid);
          vectorbld_acc (report, vector ('00000', 'Quad map <' || qmid || '> is no longer used in storage <' || alt_st || '>'));
        }
      DB.DBA.RDF_QM_GC_MAPPING_SUBTREE (qmid, 0);
      vectorbld_acc (report, vector ('00000', 'Quad map <' || qmid || '> is deleted'));
      vectorbld_final (report);
      if (length (storages))
        report := vector_concat (report, DB.DBA.RDF_QM_APPLY_CHANGES (null, storages));
      return report;
    }
  else
    {
      if (not exists (sparql
        define input:storage ""
        select ?st where {
            graph <http://www.openlinksw.com/schemas/virtrdf#> {
                  { ?st virtrdf:qsUserMaps ?subm .
                    ?subm ?p `iri(?:qmid)` }
                union
                  { ?st virtrdf:qsDefaultMap `iri(?:qmid)` }
                filter (?st = iri(?:storage))
              } } ) )
        {
          if (silent)
            return vector (vector ('00000', 'Quad map <' || qmid || '> is not used in storage <' || storage || '>, the DROP statement is ignored due to SILENT option'));
          signal ('22023', 'Quad map <' || qmid || '> is not used in storage <' || storage || '>');
        }
      DB.DBA.RDF_QM_DELETE_MAPPING_FROM_STORAGE (storage, NULL, qmid);
      DB.DBA.RDF_QM_GC_MAPPING_SUBTREE (qmid, 1);
      return vector (vector ('00000', 'Quad map <' || qmid || '> is no longer used in storage <' || storage || '>'));
    }
}
;

create function DB.DBA.RDF_QM_MACROEXPAND_TEMPLATE (in iritmpl varchar) returns varchar
{
  declare pos integer;
  pos := strstr (iritmpl, '^{URIQADefaultHost}^');
  if (pos is not null)
    {
      declare host varchar;
      host := registry_get ('URIQADefaultHost');
      if (not isstring (host))
        signal ('22023', 'Can not use ^{URIQADefaultHost}^ in IRI template if there is no DefaultHost parameter in [URIQA] section of Virtuoso configuration file');
      iritmpl := replace (iritmpl, '^{URIQADefaultHost}^', host);
    }
  pos := strstr (iritmpl, '^{DynamicLocalFormat}^');
  if (pos is not null)
    {
      declare host varchar;
      host := registry_get ('URIQADefaultHost');
      if (not isstring (host))
        signal ('22023', 'Can not use ^{DynamicLocalFormat}^ in IRI template if there is no DefaultHost parameter in [URIQA] section of Virtuoso configuration file');
--      if (atoi (coalesce (virtuoso_ini_item_value ('URIQA', 'DynamicLocal'), '0')))
--        signal ('22023', 'Can not use ^{DynamicLocalFormat}^ in IRI template if DynamicLocal is not set to 1 in [URIQA] section of Virtuoso configuration file');
      if ((pos > 0) and (pos < 10) and strchr (subseq (iritmpl, 0, pos), ':') is not null)
        signal ('22023', 'Misplaced ^{DynamicLocalFormat}^: its expansion will contain protocol prefix but the template contains one already');
      if (strchr (host, ':') is not null)
        iritmpl := replace (iritmpl, '^{DynamicLocalFormat}^', 'http://%{WSHostName}U:%{WSHostPort}U');
      else
        iritmpl := replace (iritmpl, '^{DynamicLocalFormat}^', 'http://%{WSHost}U');
    }
  pos := strstr (iritmpl, '^{');
  if (pos is not null)
    {
      declare pos2 integer;
      pos2 := strstr (subseq (iritmpl, pos), '^}');
      if (pos2 is not null)
        signal ('22023', 'The macro ' || subseq (iritmpl, pos, pos + pos2 + 2) || ' is not known, supported names are ^{URIQADefaultHost}^ and ^{DynamicLocalFormat}^');
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
            optional { ?sups ?supp ?supo . FILTER (str(?supo) != bif:concat (str(?:classiri), '-nullable')) }
          } } ) );
  descr := dict_list_keys (descr, 2);
  rowvector_digit_sort (descr, 0, 1);
  rowvector_digit_sort (descr, 1, 1);
  return descr;
}
;

create function DB.DBA.RDF_QM_DEFINE_IRI_CLASS_FORMAT (in classiri varchar, in iritmpl varchar, in arglist any, in options any, in origclassiri varchar := null) returns any
{
  declare graphiri varchar;
  declare sprintffsid, superformatsid, nullablesuperformatid varchar;
  declare basetype, basetypeiri varchar;
  declare bij, deref integer;
  declare sffs, res any;
  declare argctr, arglist_len, isnotnull, sff_ctr, sff_count, bij_sff_count integer;
  declare needs_arg_dtps integer;
  declare arg_dtps varchar;
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  if (get_keyword_ucase ('DATATYPE', options) is not null or get_keyword_ucase ('LANG', options) is not null)
    signal ('22023', 'IRI class <' || classiri || '> can not have DATATYPE or LANG options specified');
  bij := get_keyword_ucase ('BIJECTION', options, 0);
  deref := get_keyword_ucase ('DEREF', options, 0);
  sffs := get_keyword_ucase ('RETURNS', options);
  if (sffs is null)
    sffs := vector (iritmpl); -- note that this is before macroexpand
  sff_count := length (sffs);
  iritmpl := DB.DBA.RDF_QM_MACROEXPAND_TEMPLATE (iritmpl);
  sprintffsid := classiri || '--Sprintffs';
  superformatsid := classiri || '--SuperFormats';
  nullablesuperformatid := null;
  res := vector ();
  foreach (any arg in arglist) do
    if (UNAME'in' <> arg[0])
      signal ('22023', 'Only "in" parameters are now supported in argument lists of class formats, "' || arg[0] || '" is not supported in CREATE IRI CLASS <' || classiri || '>' );
  arglist_len := length (arglist);
  isnotnull := 1;
  needs_arg_dtps := 0;
  arg_dtps := '';
  if (arglist_len <> 1)
    {
      declare type_name varchar;
      declare dtp integer;
      if (arglist_len = 0)
        basetype := 'zeropart-uri';
      else
        basetype := 'multipart-uri';
      for (argctr := 0; (argctr < arglist_len) and isnotnull; argctr := argctr + 1)
        {
          if (not (coalesce (arglist[argctr][3], 0)))
            isnotnull := 0;
          type_name := lower (arglist[argctr][2]);
          dtp := case (type_name)
            when 'integer' then __tag of integer
            when 'varchar' then __tag of varchar
            when 'date' then __tag of date
            when 'datetime' then __tag of datetime
            when 'double precision' then __tag of double precision
            when 'numeric' then __tag of numeric
            when 'nvarchar' then __tag of nvarchar
            else 255 end;
          if (type_name = 'nvarchar')
            needs_arg_dtps := 1;
          arg_dtps := arg_dtps || chr (bit_and (127, dtp));
        }
    }
  else /* arglist is 1 item long */
    {
      basetype := lower (arglist[0][2]);
      if (not (basetype in ('integer', 'varchar', 'date', /* 'datetime', 'double precision',*/ 'numeric', 'nvarchar')))
        signal ('22023', 'The datatype "' || basetype || '" is not supported in CREATE IRI CLASS <' || classiri || '>' );
      basetype := 'sql-' || replace (basetype, ' ', '') || '-uri';
      if (not (coalesce (arglist[0][3], 0)))
        isnotnull := 0;
      if (basetype = 'nvarchar')
        {
          needs_arg_dtps := 1;
          arg_dtps := chr (bit_and (127, __tag of nvarchar));
        }
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
          nullablesuperformatid := classiri || '-nullable';
          res := vector_concat (res,
            DB.DBA.RDF_QM_DEFINE_IRI_CLASS_FORMAT (nullablesuperformatid, iritmpl, arglist_copy, options, NULL) );
        }
      origclassiri := classiri;
    }
  if (DB.DBA.RDF_QM_ASSERT_JSO_TYPE (classiri, 'http://www.openlinksw.com/schemas/virtrdf#QuadMapFormat', 1))
    {
      declare side_s IRI_ID;
      side_s := DB.DBA.RDF_QM_GC_SUBTREE (classiri, 2);
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
          -- dbg_obj_princ ('old descr is ', old_descr);
          -- dbg_obj_princ ('new descr is ', new_descr);
          if (md5 (serialize (old_descr)) = md5 (serialize (new_descr)))
            {
              sparql define input:storage ""
              delete from graph <http://www.openlinksw.com/schemas/virtrdf#>  { `iri(?:tmpname)` ?p ?o }
              where { `iri(?:tmpname)` ?p ?o };
              return vector (vector ('00000', 'Previous definition of IRI class <' || classiri || '> is identical to the new one, not touched'));
            }
          signal ('22023', 'Can not change IRI class <' || classiri || '> because it is used by other quad map objects, e.g., <' || id_to_iri_nosignal (side_s) || '>');
        }
      res := vector_concat (res, vector (vector ('00000', 'Previous definition of IRI class <' || classiri || '> has been dropped')));
    }
  else
    res := vector ();
  if (bij)
    {
      if (__sprintff_is_proven_unparseable (iritmpl))
        signal ('22023', 'IRI class <' || classiri || '> has OPTION (BIJECTION) but its format string can not be unambiguously parsed by sprintf_inverse()');
    }
  else
    {
      if (__sprintff_is_proven_bijection (iritmpl))
        bij := 1;
    }
  bij_sff_count := 0;
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s ?p ?o }
  from <http://www.openlinksw.com/schemas/virtrdf#>
  where { ?s ?p ?o . filter (?s = iri(?:sprintffsid)) };
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
  if (not needs_arg_dtps)
    arg_dtps := NULL;
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s ?p ?o }
  from <http://www.openlinksw.com/schemas/virtrdf#>
  where { ?s ?p ?o . filter (?s = iri(?:classiri)) };
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s ?p ?o }
  from <http://www.openlinksw.com/schemas/virtrdf#>
  where { ?s ?p ?o . filter (?s = iri(?:superformatsid)) };
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
        virtrdf:qmfCustomString1 ?:iritmpl ;
        virtrdf:qmfColumnCount ?:arglist_len ;
        virtrdf:qmfSuperFormats `iri(?:superformatsid)` ;
        virtrdf:qmfIsBijection ?:bij ;
        virtrdf:qmfDerefFlags ?:deref ;
        virtrdf:qmfArgDtps ?:arg_dtps ;
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
  if (isnotnull and (arglist_len > 0))
    {
      sparql define input:storage ""
      prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
      insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
          `iri(?:classiri)`
            virtrdf:qmfValRange-rvrRestrictions
              virtrdf:SPART_VARR_NOT_NULL .
          `iri(?:superformatsid)`
            rdf:_1 `iri(?:nullablesuperformatid)` };
    }
  commit work;
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
  declare superformatsid, nullablesuperformatid varchar;
  declare bij, deref integer;
  declare sffs any;
  declare res any;
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  superformatsid := classiri || '--SuperFormats';
  nullablesuperformatid := null;
  if (get_keyword_ucase ('DATATYPE', options) is not null or get_keyword_ucase ('LANG', options) is not null)
    signal ('22023', 'IRI class <' || classiri || '> can not have DATATYPE or LANG options specified');
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
      if (arglist_len = 0)
        basetype := 'zeropart-uri-fn-nullable';
      else
        basetype := 'multipart-uri-fn-nullable';
      isnotnull := 0;
    }
  else
    {
      basetype := lower (arglist[0][2]);
      if (not (basetype in ('integer', 'varchar', 'date', 'datetime', 'double precision', 'numeric', 'nvarchar')))
        signal ('22023', 'The datatype "' || basetype || '" is not supported in CREATE IRI CLASS <' || classiri || '> USING FUNCTION' );
      basetype := 'sql-' || replace (basetype, ' ', '') || '-uri-fn';
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
      side_s := DB.DBA.RDF_QM_GC_SUBTREE (classiri, 2);
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
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s ?p ?o }
  from <http://www.openlinksw.com/schemas/virtrdf#>
  where { ?s ?p ?o . filter (?s = iri(?:classiri)) };
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s ?p ?o }
  from <http://www.openlinksw.com/schemas/virtrdf#>
  where { ?s ?p ?o . filter (?s = iri(?:superformatsid)) };
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
      delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s ?p ?o }
      from <http://www.openlinksw.com/schemas/virtrdf#>
      where { ?s ?p ?o . filter (?s = iri(?:sffsid)) };
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
  commit work;
  return vector_concat (res, vector (vector ('00000', 'IRI class <' || classiri || '> has been defined (inherited from rdfdf:' || basetype || ') using ' || uriprintname)));
}
;

create function DB.DBA.RDF_QM_DEFINE_LITERAL_CLASS_FORMAT (in classiri varchar, in iritmpl varchar, in arglist any, in options any, in origclassiri varchar := null) returns any
{
  declare graphiri varchar;
  declare sprintffsid, superformatsid, nullablesuperformatid varchar;
  declare basetype, basetypeiri varchar;
  declare const_dt, dt_expn, const_lang varchar;
  declare bij, deref integer;
  declare sffs, res any;
  declare argctr, arglist_len, isnotnull, sff_ctr, sff_count, bij_sff_count integer;
  declare needs_arg_dtps integer;
  declare arg_dtps varchar;
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  const_dt := get_keyword_ucase ('DATATYPE', options);
  const_lang := get_keyword_ucase ('LANG', options);
  bij := get_keyword_ucase ('BIJECTION', options, 0);
  deref := get_keyword_ucase ('DEREF', options, 0);
  sffs := get_keyword_ucase ('RETURNS', options);
  if (sffs is null)
    sffs := vector (iritmpl); -- note that this is before macroexpand
  sff_count := length (sffs);
  iritmpl := DB.DBA.RDF_QM_MACROEXPAND_TEMPLATE (iritmpl);
  sprintffsid := classiri || '--Sprintffs';
  superformatsid := classiri || '--SuperFormats';
  nullablesuperformatid := null;
  res := vector ();
  foreach (any arg in arglist) do
    if (UNAME'in' <> arg[0])
      signal ('22023', 'Only "in" parameters are now supported in argument lists of class formats, "' || arg[0] || '" is not supported in CREATE IRI CLASS <' || classiri || '>' );
  arglist_len := length (arglist);
  isnotnull := 1;
  needs_arg_dtps := 0;
  arg_dtps := '';
  if (arglist_len <> 1)
    {
      declare type_name varchar;
      declare dtp integer;
      if (arglist_len = 0)
        basetype := 'zeropart-literal';
      else
        basetype := 'multipart-literal';
      for (argctr := 0; (argctr < arglist_len) and isnotnull; argctr := argctr + 1)
        {
          if (not (coalesce (arglist[argctr][3], 0)))
            isnotnull := 0;
          type_name := lower (arglist[argctr][2]);
          dtp := case (type_name)
            when 'integer' then __tag of integer
            when 'varchar' then __tag of varchar
            when 'date' then __tag of date
            when 'datetime' then __tag of datetime
            when 'double precision' then __tag of double precision
            when 'numeric' then __tag of numeric
            when 'nvarchar' then __tag of nvarchar
            else 255 end;
          if (type_name = 'nvarchar')
            needs_arg_dtps := 1;
          arg_dtps := arg_dtps || chr (bit_and (127, dtp));
        }
    }
  else /* arglist is 1 item long */
    {
      basetype := lower (arglist[0][2]);
      if (not (basetype in ('integer', 'varchar', 'date', 'datetime', 'double precision', 'numeric', 'nvarchar')))
        signal ('22023', 'The datatype "' || basetype || '" is not supported in CREATE LITERAL CLASS <' || classiri || '>' );
      basetype := 'sql-' || replace (basetype, ' ', '') || '-literal';
      if (not (coalesce (arglist[0][3], 0)))
        isnotnull := 0;
      if (basetype = 'nvarchar')
        {
          needs_arg_dtps := 1;
          arg_dtps := chr (bit_and (127, __tag of nvarchar));
        }
    }
  if (not isnotnull)
    basetype := basetype || '-nullable';
  basetypeiri := 'http://www.openlinksw.com/virtrdf-data-formats#' || basetype;
  if (const_dt is not null)
    dt_expn := ' ' || WS.WS.STR_SQL_APOS (const_dt);
  else
    dt_expn := NULL;
  if (origclassiri is null)
    {
      if (isnotnull and (arglist_len > 0))
        {
          declare arglist_copy any;
          if (classiri like '%-nullable')
            signal ('22023', 'The name of non-nullable literal class in CREATE LITERAL CLASS <' || classiri || '> is misleading' );
          arglist_copy := arglist;
          for (argctr := 0; (argctr < arglist_len); argctr := argctr + 1)
            arglist_copy[argctr][3] := 0;
          nullablesuperformatid := classiri || '-nullable';
          res := vector_concat (res,
            DB.DBA.RDF_QM_DEFINE_IRI_CLASS_FORMAT (nullablesuperformatid, iritmpl, arglist_copy, options, NULL) );
        }
      origclassiri := classiri;
    }
  if (DB.DBA.RDF_QM_ASSERT_JSO_TYPE (classiri, 'http://www.openlinksw.com/schemas/virtrdf#QuadMapFormat', 1))
    {
      declare side_s IRI_ID;
      side_s := DB.DBA.RDF_QM_GC_SUBTREE (classiri, 2);
      if (side_s is not null)
        {
          declare tmpname varchar;
          declare old_descr, new_descr any;
          tmpname := uuid();
          { declare exit handler for sqlstate '*' {
              signal ('22023', 'Can not change literal class <' || classiri || '> because it is used by other quad map objects, e.g., <' || id_to_iri_nosignal (side_s) || '>; moreover, the new declaration may be invalid.'); };
            DB.DBA.RDF_QM_DEFINE_LITERAL_CLASS_FORMAT (tmpname, iritmpl, arglist, options, classiri);
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
          signal ('22023', 'Can not change IRI class <' || classiri || '> because it is used by other quad map objects, e.g., <' || id_to_iri_nosignal (side_s) || '>');
        }
      res := vector_concat (res, vector (vector ('00000', 'Previous definition of IRI class <' || classiri || '> has been dropped')));
    }
  else
    res := vector ();
  if (bij)
    {
      if (__sprintff_is_proven_unparseable (iritmpl))
        signal ('22023', 'Literal class <' || classiri || '> has OPTION (BIJECTION) but its format string can not be unambiguously parsed by sprintf_inverse()');
    }
  else
    {
      if (__sprintff_is_proven_bijection (iritmpl))
        bij := 1;
    }
  bij_sff_count := 0;
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s ?p ?o }
  from <http://www.openlinksw.com/schemas/virtrdf#>
  where { ?s ?p ?o . filter (?s = iri(?:sprintffsid)) };
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
  if (not needs_arg_dtps)
    arg_dtps := NULL;
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s ?p ?o }
  from <http://www.openlinksw.com/schemas/virtrdf#>
  where { ?s ?p ?o . filter (?s = iri(?:classiri)) };
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s ?p ?o }
  from <http://www.openlinksw.com/schemas/virtrdf#>
  where { ?s ?p ?o . filter (?s = iri(?:superformatsid)) };
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
        virtrdf:qmfCustomString1 ?:iritmpl ;
        virtrdf:qmfDatatypeOfShortTmpl ?:dt_expn ;
        virtrdf:qmfColumnCount ?:arglist_len ;
        virtrdf:qmfSuperFormats `iri(?:superformatsid)` ;
        virtrdf:qmfIsBijection ?:bij ;
        virtrdf:qmfDerefFlags ?:deref ;
        virtrdf:qmfArgDtps ?:arg_dtps ;
        virtrdf:qmfValRange-rvrRestrictions virtrdf:SPART_VARR_IS_LIT, virtrdf:SPART_VARR_IRI_CALC;
        virtrdf:qmfValRange-rvrDatatype ?:const_dt ;
        virtrdf:qmfValRange-rvrLanguage ?:const_lang ;
        virtrdf:qmfValRange-rvrSprintffs `iri(?:sprintffsid)` ;
        virtrdf:qmfValRange-rvrSprintffCount ?:sff_count .
      `iri(?:sprintffsid)`
        rdf:type virtrdf:array-of-string .
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
  commit work;
  return vector_concat (res, vector_concat (res, vector (vector ('00000', 'Literal class <' || classiri || '> has been defined (inherited from rdfdf:' || basetype || ')'))));
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
  declare superformatsid, nullablesuperformatid varchar;
  declare res any;
  declare const_dt, dt_expn, const_lang varchar;
  declare bij, deref integer;
  superformatsid := classiri || '--SuperFormats';
  nullablesuperformatid := null;
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
    {
      if (arglist_len = 0)
        basetype := 'zeropart-literal-fn-nullable';
      else
        basetype := 'multipart-literal-fn-nullable';
    }
  else
    {
      basetype := lower (arglist[0][2]);
      if (not (basetype in ('integer', 'varchar' /*, 'date', 'double precision'*/, 'nvarchar')))
        signal ('22023', 'The datatype "' || basetype || '" is not supported in CREATE IRI CLASS <' || classiri || '> USING FUNCTION' );
      basetype := 'sql-' || replace (basetype, ' ', '') || '-literal-fn';
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
      side_s := DB.DBA.RDF_QM_GC_SUBTREE (classiri, 2);
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
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s ?p ?o }
  from <http://www.openlinksw.com/schemas/virtrdf#>
  where { ?s ?p ?o . filter (?s = iri(?:classiri)) };
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s ?p ?o }
  from <http://www.openlinksw.com/schemas/virtrdf#>
  where { ?s ?p ?o . filter (?s = iri(?:superformatsid)) };
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
  commit work;
  return vector_concat (res, vector (vector ('00000', 'LITERAL class <' || classiri || '> has been defined (inherited from rdfdf:' || basetype || ') using ' || uriprintname)));
}
;

create function DB.DBA.RDF_QM_DEFINE_LITERAL_CLASS_WITH_FIXED_LANG (in coltype varchar, in o_lang varchar, in is_nullable integer := 0) returns any
{
  declare src_lname, res_lname, src_fmtid, res_fmtid, src_baseid, res_baseid, superformatsid, nullablesuperformatid, o_lang_str varchar;
  nullablesuperformatid := null;
  if (not is_nullable)
    nullablesuperformatid := DB.DBA.RDF_QM_DEFINE_LITERAL_CLASS_WITH_FIXED_LANG (coltype, o_lang, 1);
  src_baseid := 'http://www.openlinksw.com/virtrdf-data-formats#' || 'sql-' || replace (coltype, ' ', '') || '-fixedlang-x-any' ;
  res_baseid := 'http://www.openlinksw.com/virtrdf-data-formats#' || 'sql-' || replace (coltype, ' ', '') || '-fixedlang-' || o_lang ;
  src_lname := 'sql-' || replace (coltype, ' ', '') || '-fixedlang-x-any' || case when is_nullable then '-nullable' else '' end;
  res_lname := 'sql-' || replace (coltype, ' ', '') || '-fixedlang-' || o_lang || case when is_nullable then '-nullable' else '' end ;
  src_fmtid := 'http://www.openlinksw.com/virtrdf-data-formats#' || src_lname;
  res_fmtid := 'http://www.openlinksw.com/virtrdf-data-formats#' || res_lname;
  superformatsid := res_fmtid || '--SuperFormats';
  if (exists (sparql define input:storage ""
      prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
      prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
      ask where { graph virtrdf: { `iri(?:res_fmtid)` a virtrdf:QuadMapFormat } } ) )
    {
      -- dbg_obj_princ ('DB.DBA.RDF_QM_DEFINE_LITERAL_CLASS_WITH_FIXED_LANG (', coltype, o_lang, is_nullable, ') exists');
      return res_fmtid;
    }
  if (not exists (sparql define input:storage ""
      prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
      prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
      ask where { graph virtrdf: { `iri(?:src_fmtid)` a virtrdf:QuadMapFormat } } ) )
    {
      -- dbg_obj_princ ('DB.DBA.RDF_QM_DEFINE_LITERAL_CLASS_WITH_FIXED_LANG (', coltype, o_lang, is_nullable, '): ', src_fmtid, 'does not exist');
      signal ('22023', 'Unable to find appropriate quad map format to make its analog for a fixed language');
    }
  -- dbg_obj_princ ('DB.DBA.RDF_QM_DEFINE_LITERAL_CLASS_WITH_FIXED_LANG (', coltype, o_lang, is_nullable, '): will make ', res_fmtid, ' from ', src_fmtid);
  o_lang_str := WS.WS.STR_SQL_APOS (o_lang);
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
  prefix xsd: <http://www.w3.org/2001/XMLSchema#>
  with virtrdf:
  delete { `iri(?:res_fmtid)` ?p ?o }
  where  { `iri(?:res_fmtid)` ?p ?o };
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
  prefix xsd: <http://www.w3.org/2001/XMLSchema#>
  with virtrdf:
  delete { `iri(?:superformatsid)` ?p ?o }
  where  { `iri(?:superformatsid)` ?p ?o };
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
  prefix xsd: <http://www.w3.org/2001/XMLSchema#>
  insert in virtrdf:
    {
      `iri(?:res_fmtid)` ?p
            `if (isref (?o) || isnumeric (?o) || datatype(?o) != xsd:string,
                if (isref (?o) && (?o = iri(?:src_baseid)), iri(?:res_baseid), ?o),
                bif:replace (?o, "'x-any'", ?:o_lang_str) ) ` ;
        virtrdf:qmfSuperFormats `iri(?:superformatsid)` .
      `iri(?:superformatsid)`
        rdf:type virtrdf:array-of-QuadMapFormat ;
        rdf:_1 `iri(?:nullablesuperformatid)` .
    }
  from virtrdf:
  where
    {
      `iri(?:src_fmtid)` ?p ?o .
      filter (?p != virtrdf:qmfSuperFormats ) };
  commit work;
  return res_fmtid;
}
;

--!AWK PUBLIC
create function DB.DBA.RDF_BAD_CLASS_INV_FUNCTION (inout val any) returns any
{
  return NULL;
}
;

--!AWK PUBLIC
create function DB.DBA.SQLNAME_NOTATION_TO_NAME (in str varchar) returns varchar
{
  if ('' = str)
    return NULL;
  if (34 = str[0])
    return subseq (str, 1, length (str) - 1);
  return fix_identifier_case (str);
}
;

--!AWK PUBLIC
create function DB.DBA.SQLQNAME_NOTATION_TO_QNAME (in str varchar, in expected_part_count integer) returns varchar
{
  declare part_ctr, dot_pos integer;
  declare name, res varchar;
  res := '';
  part_ctr := 1;
next_dot:
  dot_pos := strchr (str, '.');
  if (dot_pos is not null)
    {
      if (0 = dot_pos)
        {
          if (2 = part_ctr)
            res := res || USER || '.';
          else
            return NULL;
        }
      else
        {
          name := DB.DBA.SQLNAME_NOTATION_TO_NAME(subseq (str, 0, dot_pos));
          if (name is null)
            return NULL;
          res := res || name  || '.';
        }
      str := subseq (str, dot_pos + 1);
      part_ctr := part_ctr + 1;
      goto next_dot;
    }
  if (expected_part_count <> part_ctr)
    return NULL;
  name := DB.DBA.SQLNAME_NOTATION_TO_NAME (str);
  if (name is null)
    return NULL;
  return res || name;
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
      declare uriparsename varchar;
      if (uriprintname like '%"')
        uriparsename := subseq (uriprintname, 0, length (uriprintname)-1) || '_INVERSE"';
      else
        uriparsename := uriprintname || '_INVERSE';
      if (fheaders[1][0] <> uriparsename)
        signal ('22023', 'Name of ' || invdesc || ' function should be ' || uriparsename || ', not ' || fheaders[1][0] || ', other variants are not supported by the current version' );
    }
  else
    {
      for (argctr := 0; argctr < argcount; argctr := argctr + 1)
        {
          declare uriparsename varchar;
          if (uriprintname like '%"')
            uriparsename := sprintf ('%s_INV_%d"', subseq (uriprintname, 0, length (uriprintname)-1), argctr+1);
          else
            uriparsename := sprintf ('%s_INV_%d', uriprintname, argctr+1);
          if (fheaders[argctr + 1][0] <> uriparsename)
            signal ('22023', 'Name of inverse function should be ' || uriparsename || ', not ' || fheaders[argctr + 1][0] || ', other variants are not supported by the current version' );
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
  commit work;
  return vector (vector ('00000', 'IRI class <' || subclassiri || '> is now known as a subclass of <' || superclassiri || '>'));
}
;

create function DB.DBA.RDF_QM_DROP_CLASS (in classiri varchar, in silent integer := 0) returns any
{
  declare graphiri varchar;
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  if (silent and not exists ((sparql define input:storage ""
    prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
    select (1) where {
        graph ?:graphiri {
            `iri(?:classiri)` a ?t } } ) ) )
    return vector (vector ('00000', 'Class <' || classiri || '> does not exist, the DROP statement is ignored due to SILENT option'));
  if (DB.DBA.RDF_QM_ASSERT_JSO_TYPE (classiri, 'http://www.openlinksw.com/schemas/virtrdf#QuadMapFormat', 1))
    {
      declare side_s IRI_ID;
      side_s := DB.DBA.RDF_QM_GC_SUBTREE (classiri, 2);
      if (side_s is not null)
        signal ('22023', 'Can not drop class <' || classiri || '> because it is used by other quad map objects, e.g., <' || id_to_iri_nosignal (side_s) || '>');
    }
  commit work;
  return vector (vector ('00000', 'Previous definition of class <' || classiri || '> has been dropped'));
}
;

create function DB.DBA.RDF_QM_DROP_QUAD_STORAGE (in storage varchar, in silent integer := 0) returns any
{
  declare graphiri varchar;
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  if (silent and not exists ((sparql define input:storage ""
    prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
    select (1) where {
        graph ?:graphiri {
            `iri(?:storage)` a ?t } } ) ) )
    return vector (vector ('00000', 'Quad storage <' || storage || '> does not exist, the DROP statement is ignored due to SILENT option'));
  DB.DBA.RDF_QM_ASSERT_STORAGE_FLAG (storage, 0);
  DB.DBA.RDF_QM_GC_SUBTREE (storage);
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> {
      `iri(?:storage)` ?p ?o
    }
  where { graph ?:graphiri { `iri(?:storage)` ?p ?o } };
  commit work;
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
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s ?p ?o }
  from <http://www.openlinksw.com/schemas/virtrdf#>
  where { ?s ?p ?o . filter (?s = iri(?:storage)) };
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s ?p ?o }
  from <http://www.openlinksw.com/schemas/virtrdf#>
  where { ?s ?p ?o . filter (?s = iri(?:qsusermaps)) };
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
      `iri(?:storage)`
        rdf:type virtrdf:QuadStorage ;
        virtrdf:qsUserMaps `iri(?:qsusermaps)` .
      `iri(?:qsusermaps)`
        rdf:type virtrdf:array-of-QuadMap };
  commit work;
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
  commit work;
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
  commit work;
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
      if (starts_with (qtable, '/*[sqlquery[*/'))
        {
          qtable := '(' || qtable || ')';
          inner_id := qmvid || '-atable-' || alias || '-sql-query';
        }
      else
        inner_id := qmvid || '-atable-' || alias || '-' || qtable;
      sparql define input:storage ""
      prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
      delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s ?p ?o }
      from <http://www.openlinksw.com/schemas/virtrdf#>
      where { ?s ?p ?o . filter (?s = iri(?:inner_id)) };
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
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s ?p ?o }
  from <http://www.openlinksw.com/schemas/virtrdf#>
  where { ?s ?p ?o . filter (?s = iri(?:ftid)) };
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s ?p ?o }
  from <http://www.openlinksw.com/schemas/virtrdf#>
  where { ?s ?p ?o . filter (?s = iri(?:ftcondsid)) };
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

registry_set ('DB.DBA.RDF_QM_PEDANTIC_GC', '')
;

create function DB.DBA.RDF_QM_DEFINE_MAP_VALUE (in qmv any, in fldname varchar, inout tablename varchar, in o_dt any := null, in o_lang any := null) returns varchar
{
/* iqi qmv: vector ( UNAME'http://www.openlinksw.com/schemas/oplsioc#user_iri' ,
    vector ( vector ('alias1', 'DB.DBA.SYS_USERS')),
   vector ( vector ('DB.DBA.SYS_USERS', 'alias1', 'U_ID') ),
   vector ('^{alias1.}^.U+IS_ROLE = 0'),
   NULL
 ) */
  declare atables, sqlcols, conds, items_for_pedantic_gc any;
  declare ftextid varchar;
  declare qry_metas any;
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
  qry_metas := null;
  atablecount := length (atables);
  colcount := length (sqlcols);
  condcount := length (conds);
  items_for_pedantic_gc := NULL;
  if (fmtid <> UNAME'literal')
    {
      DB.DBA.RDF_QM_ASSERT_JSO_TYPE (fmtid, 'http://www.openlinksw.com/schemas/virtrdf#QuadMapFormat');
      if (o_dt is not null)
        signal ('22023', 'Only default literal class can have DATATYPE clause in the mapping, <' || fmtid || '> can not');
      if (o_lang is not null)
        signal ('22023', 'Only default literal class can have LANG clause in the mapping, <' || fmtid || '> can not');
      fmtcolcount := ((sparql define input:storage ""
          select ?cc from <http://www.openlinksw.com/schemas/virtrdf#>
          where { `iri(?:fmtid)` virtrdf:qmfColumnCount ?cc } ) );
      if (fmtcolcount <> colcount)
        signal ('22023', 'Number of columns of quad map value does not match number of arguments of format <' || fmtid || '>');
    }
  for (colctr := 0; colctr < colcount; colctr := colctr + 1)
    {
      declare sqlcol any;
      declare alias_msg_txt, final_tblname, final_colname varchar;
      sqlcol := sqlcols [colctr];
      final_colname := DB.DBA.SQLNAME_NOTATION_TO_NAME (sqlcol[2]);
      if (sqlcol[1] is not null)
        alias_msg_txt := ' (alias ' || sqlcol[1] || ')';
      else
        alias_msg_txt := ' (without alias)';
      if (starts_with (sqlcol[0], '/*[sqlquery[*/'))
        {
          declare qry varchar;
          declare qry_colcount, qry_colctr integer;
          declare qry_mdata any;
          qry := sqlcol[0];
          if (qry_metas is null)
            qry_metas := dict_new (5);
          qry_mdata := dict_get (qry_metas, qry, null);
          if (qry_mdata is null)
            {
              declare stat, msg varchar;
              declare exec_metas any;
              stat := '00000';
              exec_metadata (sqlcol[0], stat, msg, exec_metas);
              if (stat <> '00000')
                signal ('22023', 'The compilation of SQLQUERY' || alias_msg_txt || ' results in Error ' || stat || ': ' || msg);
              if (exec_metas[1] <> 1)
                signal ('R2RML', 'Dangerous DML in SQLQUERY' || alias_msg_txt);
              exec_metas := exec_metas[0];
              qry_colcount := length (exec_metas);
              qry_mdata := make_array (qry_colcount*2, 'any');
              for (qry_colctr := 0; qry_colctr < qry_colcount; qry_colctr := qry_colctr + 1)
                {
                  qry_mdata[qry_colctr*2] := exec_metas[qry_colctr][0];
                  qry_mdata[qry_colctr*2+1] := exec_metas[qry_colctr];
                }
              dict_put (qry_metas, qry, qry_mdata);
              -- dbg_obj_princ ('DB.DBA.RDF_QM_DEFINE_MAP_VALUE(): storing metadata ', qry_mdata, ' for ', qry);
            }
          -- dbg_obj_princ ('DB.DBA.RDF_QM_DEFINE_MAP_VALUE(): final_colname = ', final_colname);
          if (get_keyword (final_colname, qry_mdata) is null)
            signal ('22023', 'The result of SQLQUERY' || alias_msg_txt || ' does not contain column ' || sqlcol[2] || ', please check spelling and character case');
        }
      else
        {
          final_tblname := DB.DBA.SQLQNAME_NOTATION_TO_QNAME (sqlcol[0], 3);
          if (not exists (select top 1 1 from DB.DBA.TABLE_COLS where "TABLE" = final_tblname))
            signal ('22023', 'No table ' || sqlcol[0] || alias_msg_txt || ' in database, please check spelling and character case');
          if (not exists (select top 1 1 from DB.DBA.TABLE_COLS where "TABLE" = final_tblname and "COLUMN" = final_colname))
            signal ('22023', 'No column ' || sqlcol[2] || ' in table ' || sqlcol[0] || alias_msg_txt || ' in database, please check spelling and character case');
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
      declare sqlcol any;
      declare final_tblname, final_colname varchar;
      declare coldtp, colnullable integer;
      declare coltype varchar;
      sqlcol := sqlcols [0];
      final_colname := DB.DBA.SQLNAME_NOTATION_TO_NAME (sqlcol[2]);
      if (starts_with (sqlcol[0], '/*[sqlquery[*/'))
        {
          declare col_mdata any;
          col_mdata := get_keyword (final_colname, dict_get (qry_metas, sqlcol[0], null));
          coldtp := col_mdata[1];
          colnullable := col_mdata[4];
        }
      else
        {
          final_tblname := DB.DBA.SQLQNAME_NOTATION_TO_QNAME (sqlcol[0], 3);
          select COL_DTP, coalesce (COL_NULLABLE, 1) into coldtp, colnullable
          from DB.DBA.TABLE_COLS where "TABLE" = final_tblname and "COLUMN" = final_colname;
        }
      coltype := case (coldtp)
        when __tag of long varchar then 'longvarchar'
        when __tag of timestamp then 'datetime' -- timestamp
        when __tag of date then 'date'
        when __tag of time then 'time'
        when __tag of long varbinary then 'longvarbinary'
        when __tag of varbinary then 'longvarbinary'
        when 188 then 'integer'
        when __tag of integer then 'integer'
        when __tag of varchar then 'varchar'
        when __tag of real then 'double precision' -- actually single precision float
        when __tag of double precision then 'double precision'
        when 192 then 'varchar' -- actually character
        when __tag of datetime then 'datetime'
        when __tag of numeric then 'numeric'
        when __tag of nvarchar then 'nvarchar'
        when __tag of long nvarchar then 'longnvarchar'
        when __tag of bigint then 'integer'
        else NULL end;
      if (coltype is null)
        signal ('22023', 'The datatype of column "' || sqlcols[0][2] ||
          '" of table "' || sqlcols[0][0] || '" (COL_DTP=' || cast (coldtp as varchar) ||
          ') can not be mapped to an RDF literal in current version of Virtuoso' );
      if (o_lang is not null and not (coltype in ('varchar', 'long varchar', 'nvarchar', 'long nvarchar')))
        signal ('22023', 'The datatype of column "' || sqlcols[0][2] ||
          '" of table "' || sqlcols[0][0] || '" (COL_DTP=' || cast (coldtp as varchar) ||
          ') conflicts with LANG clause, only strings may have language' );
      if (o_dt is not null and not (coltype in ('varchar', 'long varchar', 'nvarchar', 'long nvarchar')))
        signal ('22023', 'Current version of Virtuoso does not support DATATYPE clause for columns other than varchar/nvarchar; the column "' || sqlcols[0][2] ||
          '" of table "' || sqlcols[0][0] || '" has COL_DTP=' || cast (coldtp as varchar) );
      fmtid := 'http://www.openlinksw.com/virtrdf-data-formats#sql-' || replace (coltype, ' ', '');
      if (o_dt is not null)
        {
          if (__tag (o_dt) = __tag of vector)
            {
              if (o_dt[1] <> sqlcols[0][1])
                signal ('22023', 'The alias in DATATYPE clause and the alias in object column should be the same');
              fmtid := fmtid || '-dt';
              sqlcols := vector_concat (sqlcols, vector (o_dt));
              colcount := colcount + 1;
            }
          else
            fmtid := DB.DBA.RDF_QM_DEFINE_LITERAL_CLASS_WITH_FIXED_DT (coltype, o_dt);
        }
      if (o_lang is not null)
        {
          if (__tag (o_lang) = __tag of vector)
            {
              if (o_lang[1] <> sqlcols[0][1])
                signal ('22023', 'The alias in LANG clause and the alias in object column should be the same');
              fmtid := fmtid || '-lang';
              sqlcols := vector_concat (sqlcols, vector (o_lang));
              colcount := colcount + 1;
            }
          else
            fmtid := DB.DBA.RDF_QM_DEFINE_LITERAL_CLASS_WITH_FIXED_LANG (coltype, o_lang);
        }
      if (colnullable)
        fmtid := fmtid || '-nullable';
      iriclassid := null;
    }
  else
    {
      if (exists (sparql define input:storage ""
          ask where {
              graph <http://www.openlinksw.com/schemas/virtrdf#> { `iri (?:fmtid)` virtrdf:qmfValRange-rvrRestrictions virtrdf:SPART_VARR_IS_REF } } ) )
        iriclassid := fmtid;
      else
        iriclassid := null;
    }
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
  if (registry_get ('DB.DBA.RDF_QM_PEDANTIC_GC') <> '')
    {
      vectorbld_init (items_for_pedantic_gc);
      for (sparql define input:storage ""
        prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
        select ?atable where { graph <http://www.openlinksw.com/schemas/virtrdf#> {
                `iri(?:qmvatablesid)` ?p ?atable . filter (?p != rdf:type) } } ) do {
          vectorbld_acc (items_for_pedantic_gc, "atable");
        }
      for (sparql define input:storage ""
        prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
        select ?col where { graph <http://www.openlinksw.com/schemas/virtrdf#> {
                `iri(?:qmvcolsid)` ?p ?col . filter (?p != rdf:type) } } ) do {
          vectorbld_acc (items_for_pedantic_gc, "col");
        }
      vectorbld_final (items_for_pedantic_gc);
    }
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> {
    `iri(?:qmvid)` ?p ?o . }
  where { graph <http://www.openlinksw.com/schemas/virtrdf#> {
          `iri(?:qmvid)` ?p ?o .
        } };
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> {
    `iri(?:qmvatablesid)` ?p ?o }
  where { graph <http://www.openlinksw.com/schemas/virtrdf#> {
          `iri(?:qmvatablesid)` ?p ?o .
        } };
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
  if (items_for_pedantic_gc is not null)
    {
      foreach (any i in items_for_pedantic_gc) do
        {
          DB.DBA.RDF_QM_GC_SUBTREE (i);
        }
    }
  if (0 = atablecount)
    qmvatablesid := NULL;
  if (0 = condcount)
    qmvcondsid := NULL;
  columnsformkey := DB.DBA.RDF_QM_CHECK_COLUMNS_FORM_KEY (sqlcols);
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
      `iri(?:qmvid)`
        rdf:type virtrdf:QuadMapValue ;
        virtrdf:qmvTableName ?:tablename ;
        virtrdf:qmvATables `iri(?:qmvatablesid)` ;
        virtrdf:qmvColumns `iri(?:qmvcolsid)` ;
        virtrdf:qmvConds `iri(?:qmvcondsid)` ;
        virtrdf:qmvFormat `iri(?:fmtid)` ;
        virtrdf:qmvFText `iri(?:ftextid)` ;
        virtrdf:qmvIriClass `iri(?:iriclassid)` ;
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
      delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s ?p ?o }
      from <http://www.openlinksw.com/schemas/virtrdf#>
      where { ?s ?p ?o . filter (?s = iri(?:inner_id)) };
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
  in can_be_literal integer, in fldname varchar, inout tablename varchar, in o_dt any := null, in o_lang any := null )
{
  -- dbg_obj_princ ('DB.DBA.RDF_QM_NORMALIZE_QMV (', qmv, ' ..., ..., ', can_be_literal, fldname, ')');
  qmvid := qmvfix := NULL;
  if ((__tag of vector = __tag (qmv)) and (5 = length (qmv)))
    qmvid := DB.DBA.RDF_QM_DEFINE_MAP_VALUE (qmv, fldname, tablename, o_dt, o_lang);
  else if (217 = __tag (qmv))
      qmvfix := iri_to_id (qmv);
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
  in qmv_g any, in qmv_s any, in qmv_p any, in qmv_o any, in o_dt any, in o_lang any,
  in is_real integer, in atables any, in conds any, in opts any ) returns any
{
  declare old_actual_type varchar;
  declare tablename, qmvid_g, qmvid_s, qmvid_p, qmvid_o varchar;
  declare qmvfix_g, qmvfix_s, qmvfix_p, qmvfix_o, qmvfix_o_typed, qmvfix_o_dt any;
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
  DB.DBA.RDF_QM_NORMALIZE_QMV (qmv_o, qmvfix_o, qmvid_o, 1, 'object', tablename, o_dt, o_lang);
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
        {
          tablename := 'DB.DBA.SYS_IDONLY_ONE';
          if (0 < length (conds))
            signal ('22023', 'Quad Mapping <' || qmid || '> has four constants and no one quad map value; it does not access tables so it can not have WHERE conditions');
        }
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
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s ?p ?o }
  from <http://www.openlinksw.com/schemas/virtrdf#>
  where { ?s ?p ?o . filter (?s = iri(?:qmid)) };
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s ?p ?o }
  from <http://www.openlinksw.com/schemas/virtrdf#>
  where { ?s ?p ?o . filter (?s = iri(?:atablesid)) };
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s ?p ?o }
  from <http://www.openlinksw.com/schemas/virtrdf#>
  where { ?s ?p ?o . filter (?s = iri(?:qmcondsid)) };
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> { ?s ?p ?o }
  from <http://www.openlinksw.com/schemas/virtrdf#>
  where { ?s ?p ?o . filter (?s = iri(?:qmusersubmapsid)) };
-- This did not work for some reason:
--      `iri(?:qmid)`
--        virtrdf:qmObjectRange-rvrRestrictions
--            `if (((bif:isnotnull(datatype(?:qmvfix_o)) && (datatype(?:qmvfix_o) != xsd:string)) || bound(?:o_dt)), virtrdf:SPART_VARR_TYPED, ?:NULL)` ;
--        virtrdf:qmObjectRange-rvrDatatype
--            `if (bound (?:o_dt), ?:o_dt, if ((bif:isnotnull(datatype(?:qmvfix_o)) && (datatype(?:qmvfix_o) != xsd:string)), datatype (?:qmvfix_o), ?:NULL))` ;
-- ... so it's replaced with SQL
  qmvfix_o_typed := 0;
  if (o_dt is not null)
    {
      qmvfix_o_typed := 1;
      qmvfix_o_dt := o_dt;
    }
  else if (isstring (qmvfix_o) || iswidestring (qmvfix_o))
    {
      qmvfix_o_typed := 0;
      qmvfix_o_dt := NULL;
    }
  else
    {
      qmvfix_o_typed := 1;
      qmvfix_o_dt := __xsd_type (qmvfix_o);
    }
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
      `iri(?:qmid)`
        rdf:type virtrdf:QuadMap ;
        virtrdf:qmGraphRange-rvrFixedValue ?:qmvfix_g ;
        virtrdf:qmGraphRange-rvrRestrictions
            `if (bound(?:qmvfix_g), virtrdf:SPART_VARR_NOT_NULL, ?:NULL)` ,
            `if (bound(?:qmvfix_g), virtrdf:SPART_VARR_FIXED, ?:NULL)` ,
            `if (bound(?:qmvfix_g), virtrdf:SPART_VARR_IS_REF, ?:NULL)` ,
            `if (bound(?:qmvfix_g), virtrdf:SPART_VARR_IS_IRI, ?:NULL)` ;
        virtrdf:qmGraphMap `iri(?:qmvid_g)` ;
        virtrdf:qmSubjectRange-rvrFixedValue ?:qmvfix_s ;
        virtrdf:qmSubjectRange-rvrRestrictions
            `if (bound(?:qmvfix_s), virtrdf:SPART_VARR_NOT_NULL, ?:NULL)` ,
            `if (bound(?:qmvfix_s), virtrdf:SPART_VARR_FIXED, ?:NULL)` ,
            `if (bound(?:qmvfix_s), virtrdf:SPART_VARR_IS_REF, ?:NULL)` ,
            `if (bound(?:qmvfix_s), virtrdf:SPART_VARR_IS_IRI, ?:NULL)` ;
        virtrdf:qmSubjectMap `iri(?:qmvid_s)` ;
        virtrdf:qmPredicateRange-rvrFixedValue ?:qmvfix_p ;
        virtrdf:qmPredicateRange-rvrRestrictions
            `if (bound(?:qmvfix_p), virtrdf:SPART_VARR_NOT_NULL, ?:NULL)` ,
            `if (bound(?:qmvfix_p), virtrdf:SPART_VARR_FIXED, ?:NULL)` ,
            `if (bound(?:qmvfix_p), virtrdf:SPART_VARR_IS_REF, ?:NULL)` ,
            `if (bound(?:qmvfix_p), virtrdf:SPART_VARR_IS_IRI, ?:NULL)` ;
        virtrdf:qmPredicateMap `iri(?:qmvid_p)` ;
        virtrdf:qmObjectRange-rvrFixedValue ?:qmvfix_o ;
        virtrdf:qmObjectRange-rvrRestrictions
            `if (bound(?:qmvfix_o), virtrdf:SPART_VARR_NOT_NULL, ?:NULL)` ,
            `if (bound(?:qmvfix_o), virtrdf:SPART_VARR_FIXED, ?:NULL)` ,
            `if (bound(?:qmvfix_o), if (isREF(?:qmvfix_o), virtrdf:SPART_VARR_IS_REF, virtrdf:SPART_VARR_IS_LIT), ?:NULL)` ,
            `if (isIRI(?:qmvfix_o), virtrdf:SPART_VARR_IS_IRI, ?:NULL)` ,
            `if (?:qmvfix_o_typed, virtrdf:SPART_VARR_TYPED, ?:NULL)` ;
        virtrdf:qmObjectRange-rvrDatatype ?:qmvfix_o_dt ;
        virtrdf:qmObjectRange-rvrLanguage `if (<bif:length> (lang (?:qmvfix_o)), lang (?:qmvfix_o), ?:NULL)` ;
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
  DB.DBA.RDF_ADD_qmAliasesKeyrefdByQuad (qmid);
  commit work;
  if (qm_is_default is not null)
    DB.DBA.RDF_QM_SET_DEFAULT_MAPPING (storage, qmid);
  else
    DB.DBA.RDF_QM_ADD_MAPPING_TO_STORAGE (storage, qmparentid, qmid, qm_order);
  commit work;
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
  commit work;
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
    select DB.DBA.VECTOR_AGG (vector (sub."id", sub."p", sub."ord1"))
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
    select DB.DBA.VECTOR_AGG (vector (sub."id", sub."p", sub."ord1"))
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
          -- dbg_obj_princ ('DB.DBA.RDF_QM_DELETE_MAPPING_FROM_STORAGE: reinsert ', itm, ' in rdf:_', ctr);
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
  commit work;
}
;

create function DB.DBA.RDF_SML_DROP (in smliri varchar, in silent integer, in compose_report integer := 1) returns any
{
  declare report, affected any;
  report := '';
  vectorbld_init (affected);
  for (sparql define input:storage ""
    select ?storageiri
    from virtrdf:
    where { ?storageiri virtrdf:qsMacroLibrary `iri(?:smliri)` } ) do
    {
      report := report || 'SPARQL macro library <' || smliri || '> has been detached from quad storage <' || "storageiri" || '>\n';
      vectorbld_acc (affected, "storageiri");
    }
  vectorbld_final (affected);
  sparql define input:storage ""
  delete from virtrdf:
    { ?storageiri virtrdf:qsMacroLibrary `iri(?:smliri)` }
  from virtrdf:
    where { ?storageiri virtrdf:qsMacroLibrary `iri(?:smliri)` };
  commit work;
  if (not exists (
      sparql define input:storage ""
      select 1 from virtrdf: where { `iri(?:smliri)` ?p ?o } ) )
    {
      DB.DBA.RDF_QM_APPLY_CHANGES (null, affected);
      if (silent)
        {
          if (compose_report)
            return report || 'SPARQL macro library <' || smliri || '> does not exists, nothing to delete';
          else
            return 0;
        }
      else
        signal ('22023', 'SPARQL macro library <' || smliri || '> does not exists, nothing to delete');
    }
  DB.DBA.RDF_QM_ASSERT_JSO_TYPE (smliri, 'http://www.openlinksw.com/schemas/virtrdf#SparqlMacroLibrary');
  sparql define input:storage ""
  delete from graph virtrdf: {
      `iri(?:smliri)` ?p ?o }
  from virtrdf:
  where { `iri(?:smliri)` ?p ?o };
  DB.DBA.RDF_QM_APPLY_CHANGES (vector ('http://www.openlinksw.com/schemas/virtrdf#SparqlMacroLibrary', smliri), affected);
  if (compose_report)
    return report || 'SPARQL macro library <' || smliri || '> has been deleted';
  else
    return 1;
}
;

create function DB.DBA.RDF_SML_CREATE (in smliri varchar, in txt varchar) returns any
{
  declare stat, msg, smliri_copy varchar;
  declare mdata, rset, affected any;
  DB.DBA.RDF_QM_ASSERT_JSO_TYPE (smliri, 'http://www.openlinksw.com/schemas/virtrdf#SparqlMacroLibrary', 1);
  stat := '00000';
  if (__tag (txt) = __tag of nvarchar)
    txt := charset_recode (txt, '_WIDE_', 'UTF-8');
  exec ('sparql define input:macro-lib-ignore-create "yes" define input:disable-storage-macro-lib "yes" ' || txt, stat, msg, null, 1, mdata, rset);
  if (stat <> '00000')
    signal (stat, msg);
  if (length (rset))
    signal ('SPAR0', 'Assertion failed: the validation query of macro library should return nothing');
  vectorbld_init (affected);
  for (sparql define input:storage ""
    select ?storageiri
    from virtrdf:
    where { ?storageiri virtrdf:qsMacroLibrary `iri(?:smliri)` } ) do
    {
      vectorbld_acc (affected, "storageiri");
    }
  smliri_copy := smliri;
  vectorbld_acc (affected, smliri_copy);
  vectorbld_final (affected);
  sparql define input:storage ""
  delete from graph <http://www.openlinksw.com/schemas/virtrdf#> {
      `iri(?:smliri)` ?p ?o }
  from <http://www.openlinksw.com/schemas/virtrdf#>
  where { `iri(?:smliri)` ?p ?o };
  commit work;
  sparql define input:storage ""
  insert in graph <http://www.openlinksw.com/schemas/virtrdf#> {
      `iri(?:smliri)` a virtrdf:SparqlMacroLibrary ; virtrdf:smlSourceText ?:txt };
  DB.DBA.RDF_QM_APPLY_CHANGES (null, affected);
  return 'SPARQL macro library <' || smliri || '> has been (re)created';
}
;

create function DB.DBA.RDF_QM_DETACH_MACRO_LIBRARY (in storageiri varchar, in args any) returns any
{
  declare expected_smliri varchar;
  declare old_ctr, expected_found integer;
  declare silent, report any;
  expected_smliri := get_keyword_ucase ('ID', args, NULL);
  silent := get_keyword_ucase ('SILENT', args, 0);
  expected_found := 0;
  old_ctr := 0;
  vectorbld_init (report);
  for (sparql define input:storage ""
    select ?oldsmliri
    from virtrdf:
    where { ?storageiri virtrdf:qsMacroLibrary ?oldsmliri } ) do
    {
      if (expected_smliri is not null and cast (expected_smliri as nvarchar) <> cast ("oldsmliri" as nvarchar))
        {
          if (silent)
            vectorbld_acc (report, vector ('00100', 'The SPARQL macro library to detach from <' || storageiri || '> is <' || expected_smliri || '> but actually attached one is <' || "oldsmliri" || '>, nothing to do'));
          else
            signal ('22023', 'The SPARQL macro library to detach from <' || storageiri || '> is <' || expected_smliri || '> but actually attached one is <' || "oldsmliri" || '>');
        }
      else
        {
          if (expected_smliri is not null)
            expected_found := 1;
          vectorbld_acc (report, vector ('00000', 'SPARQL macro library <' || "oldsmliri" || '> has been detached from quad storage <' || storageiri || '>'));
        }
      old_ctr := old_ctr + 1;
    }
  if (expected_smliri is not null)
    {
      sparql define input:storage ""
      delete from virtrdf:
        { ?storageiri virtrdf:qsMacroLibrary ?smliri }
      from virtrdf:
        where { ?storageiri virtrdf:qsMacroLibrary ?smliri };
    }
  else
    {
      sparql define input:storage ""
      delete from virtrdf:
        { ?storageiri virtrdf:qsMacroLibrary ?smliri }
      from virtrdf:
        where { ?storageiri virtrdf:qsMacroLibrary ?smliri };
    }
  commit work;
  if (old_ctr > 1)
    vectorbld_acc (report, vector ('00100', 'Note that there was a configuration error: more than one macro library was attached to the quad storage <' || storageiri || '>'));
  else if (old_ctr = 0)
    {
      if (silent)
        vectorbld_acc (report, vector ('00100', 'No one SPARQL macro library is attached to the quad storage <' || storageiri || '>, nothing to detach'));
      else
        signal ('22023', 'No one SPARQL macro library is attached to the quad storage <' || storageiri || '>, nothing to detach');
    }
  vectorbld_final (report);
-- dbg_obj_princ ('DB.DBA.RDF_QM_DETACH_MACRO_LIBRARY (', storageiri, args, ') returns ', report);
  return report;
}
;

create function DB.DBA.RDF_QM_ATTACH_MACRO_LIBRARY (in storageiri varchar, in args any) returns any
{
  declare smliri varchar;
  smliri := get_keyword_ucase ('ID', args, NULL);
  DB.DBA.RDF_QM_ASSERT_JSO_TYPE (storageiri, 'http://www.openlinksw.com/schemas/virtrdf#QuadStorage');
  DB.DBA.RDF_QM_ASSERT_JSO_TYPE (smliri, 'http://www.openlinksw.com/schemas/virtrdf#SparqlMacroLibrary');
  declare report any;
  vectorbld_init (report);
  for (sparql define input:storage ""
    select ?oldsmliri
    from virtrdf:
    where { ?storageiri virtrdf:qsMacroLibrary ?oldsmliri } ) do
    {
      vectorbld_acc (report, vector ('00000', 'SPARQL macro library <' || "oldsmliri" || '> has been detached from quad storage <' || storageiri || '>'));
    }
  sparql define input:storage ""
  delete from virtrdf:
    { ?storageiri virtrdf:qsMacroLibrary ?oldsmliri }
  from virtrdf:
    where { ?storageiri virtrdf:qsMacroLibrary ?oldsmliri };
  commit work;
  sparql define input:storage ""
  prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  insert in graph virtrdf: {
      `iri(?:storageiri)` virtrdf:qsMacroLibrary `iri(?:smliri)` };
  vectorbld_acc (report, vector ('00000', 'SPARQL macro library <' || smliri || '> has been attached to quad storage <' || storageiri || '>'));
  vectorbld_final (report);
  return report;
}
;

create procedure DB.DBA.RDF_ADD_qmAliasesKeyrefdByQuad (in qm_iri varchar)
{
  declare kr_iri varchar;
  declare good_ctr, all_ctr integer;
  kr_iri := qm_iri || '--qmAliasesKeyrefdByQuad';
  sparql define input:storage "" delete from virtrdf: { `iri(?:kr_iri)` ?p ?o } from virtrdf: where { `iri(?:kr_iri)` ?p ?o };
  sparql define input:storage "" insert in virtrdf: { `iri(?:qm_iri)` virtrdf:qmAliasesKeyrefdByQuad `iri(?:kr_iri)` . `iri(?:kr_iri)` a virtrdf:array-of-string };
  good_ctr := 0;
  all_ctr := 0;
  for ( sparql define input:storage ""
    select ?alias ?tbl (sql:VECTOR_AGG (str(?col))) as ?cols
    from virtrdf:
    where {
        `iri(?:qm_iri)` a virtrdf:QuadMap ;
          ?fld_p ?qmv .
        filter (?fld_p in (virtrdf:qmGraphMap , virtrdf:qmSubjectMap , virtrdf:qmPredicateMap , virtrdf:qmObjectMap))
        ?qmv a virtrdf:QuadMapValue ;
          virtrdf:qmvATables [
              ?qmvat_p [ a virtrdf:QuadMapATable ;
                  virtrdf:qmvaAlias ?alias ;
                  virtrdf:qmvaTableName ?tbl ] ] ;
          virtrdf:qmvColumns [
              ?qmvc_p [ a virtrdf:QuadMapColumn ;
                  virtrdf:qmvcAlias ?alias ;
                  virtrdf:qmvcColumnName ?col ] ] ;
          virtrdf:qmvFormat [ a virtrdf:QuadMapFormat ;
              virtrdf:qmfIsBijection ?bij ] .
        filter (?bij != 0)
      } ) do
    {
      -- dbg_obj_princ ('Quad map ', "qm_iri", ' has alias ', "alias", ' of table ', "tbl", ' with cols ', "cols");
      all_ctr := all_ctr + 1;
      for (select KEY_ID, KEY_N_SIGNIFICANT from DB.DBA.SYS_KEYS where KEY_TABLE = "tbl" and KEY_IS_UNIQUE) do
        {
          for (select "COLUMN" from DB.DBA.SYS_KEY_PARTS, DB.DBA.SYS_COLS
            where  KP_KEY_ID = KEY_ID and KP_NTH < KEY_N_SIGNIFICANT and COL_ID = KP_COL ) do
            {
              if (not position ("COLUMN", "cols"))
                {
                  -- dbg_obj_princ ("COLUMN", ' not in ', "cols");
                  goto wrong_key;
                }
            }
          good_ctr := good_ctr + 1;
          -- dbg_obj_princ ('Quad map ', qm_iri, ' can identify source rows in alias ', "alias", ' of table ', "tbl");
          sparql define input:storage "" insert in virtrdf: { `iri(?:kr_iri)` `iri(bif:sprintf("%s%d", str(rdf:_), ?:good_ctr))` ?:"alias" };
          goto right_key;
wrong_key: ;
        }
right_key: ;
    }
  -- dbg_obj_princ ('Quad map ', qm_iri, ' can identify source rows in ', good_ctr, ' of ', all_ctr, ' its aliases with bijections.');
}
;

create procedure DB.DBA.RDF_UPGRADE_QUAD_MAP (in qm_iri varchar)
{
  declare keyrefd any;
  if (not exists (sparql define input:storage "" select (1) from virtrdf: where { `iri(?:qm_iri)` a virtrdf:QuadMap }))
    signal ('RDFxx', sprintf ('Quad map <%s> does not exist, nothing to upgrade', qm_iri));
  if (not exists (sparql define input:storage "" select (1) from virtrdf: where { `iri(?:qm_iri)` virtrdf:qmAliasesKeyrefdByQuad ?keyrefs }))
    DB.DBA.RDF_ADD_qmAliasesKeyrefdByQuad (qm_iri);
}
;

create procedure DB.DBA.RDF_UPGRADE_METADATA ()
{
  for (sparql define input:storage "" select ?qm_iri from virtrdf: where { ?qm_iri a virtrdf:QuadMap }) do
    {
      DB.DBA.RDF_UPGRADE_QUAD_MAP ("qm_iri");
    }
  commit work;
}
;

-----
-- RDF parallel load


create procedure DB.DBA.TTLP_EV_TRIPLE_W (
  in g_iid IRI_ID, in s_uri varchar, in p_uri varchar,
  in o_uri varchar, in env any )
{
  -- dbg_obj_princ ('DB.DBA.TTLP_EV_TRIPLE_W (', g_iid, s_uri, p_uri, o_uri, env, ')');
  declare log_mode integer;
  declare s_iid, p_iid, o_iid IRI_ID;
  log_mode := env[0];
  if (isstring (registry_get ('DB.DBA.RDF_REPL')))
    repl_publish ('__rdf_repl', '__rdf_repl.log');

  if (log_mode = 1)
    {
      whenever sqlstate '40001' goto deadlock_1;
again_1:
      log_enable (1, 1);
      s_iid := iri_to_id (s_uri);
      p_iid := iri_to_id (p_uri);
      o_iid := iri_to_id (o_uri);
      commit work;
      log_enable (0, 1);
      insert soft DB.DBA.RDF_QUAD (G,S,P,O)
      values (g_iid, s_iid, p_iid, o_iid);
      commit work;
      -- dbg_obj_princ ('DB.DBA.TTLP_EV_TRIPLE_W (', g_iid, s_uri, p_uri, o_uri, env, ') done /1');
      return;
    }
  if (log_mode = 0)
    {
      whenever sqlstate '40001' goto deadlock_0;
again_0:
      log_enable (0, 1);
      s_iid := iri_to_id (s_uri);
      p_iid := iri_to_id (p_uri);
      o_iid := iri_to_id (o_uri);
      commit work;
      insert soft DB.DBA.RDF_QUAD (G,S,P,O) values (g_iid, s_iid, p_iid, o_iid);
      commit work;
      -- dbg_obj_princ ('DB.DBA.TTLP_EV_TRIPLE_W (', g_iid, s_uri, p_uri, o_uri, env, ') done /0');
      return;
    }
  whenever sqlstate '40001' goto deadlock_2;
again_2:
  log_enable (1, 1);
  s_iid := iri_to_id (s_uri);
  p_iid := iri_to_id (p_uri);
  o_iid := iri_to_id (o_uri);
  commit work;
  insert soft DB.DBA.RDF_QUAD (G,S,P,O) values (g_iid, s_iid, p_iid, o_iid);
  commit work;
  -- dbg_obj_princ ('DB.DBA.TTLP_EV_TRIPLE_W (', g_iid, s_uri, p_uri, o_uri, env, ') done /2');
  return;
deadlock_0:
  rollback work;
  goto again_0;
deadlock_1:
  rollback work;
  goto again_1;
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
	      if (256 = rdf_box_type (parsed))
		db..rdf_geo_add (parsed);
	      else
                rdf_box_set_type (parsed,
                  DB.DBA.RDF_TWOBYTE_OF_DATATYPE (iri_to_id (o_type)));
              parsed := DB.DBA.RDF_OBJ_ADD (257, parsed, 257, ro_id_dict);
              -- dbg_obj_princ ('rdf_box_type is set to ', rdf_box_type (parsed));
            }
          o_val := parsed;
        }
    }
  whenever sqlstate '40001' goto deadlck;
again:
  if (log_mode = 0)
    log_enable (0, 1);
  else
    log_enable (1, 1);
  s_iid := iri_to_id (s_uri);
  p_iid := iri_to_id (p_uri);
  if (isstring (o_val) or (__tag of XML = __tag (o_val)))
    {
      if (isstring (o_type) or isstring (o_lang))
        {
          if (not isstring (o_type))
            o_type := null;
          if (not isstring (o_lang))
            o_lang := null;
          o_val := DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL_FT (o_val,
              iri_to_id (o_type),
              o_lang, g_iid, p_iid, ro_id_dict );
	}
      else
        o_val := DB.DBA.RDF_MAKE_OBJ_OF_SQLVAL_FT (o_val, g_iid, p_iid, ro_id_dict);
    }
  else if (__tag of rdf_box = __tag (o_val))
    {
      if (__tag of varchar = rdf_box_data_tag (o_val) and __rdf_obj_ft_rule_check (g_iid, p_iid))
        o_val := DB.DBA.RDF_OBJ_ADD (257, o_val, 257, ro_id_dict);
      else if (0 < rdf_box_needs_digest (o_val))
        o_val := DB.DBA.RDF_OBJ_ADD (257, o_val, 257);
    }
  -- dbg_obj_princ ('final o_val = ', o_val);
  if (log_mode <= 1)
    log_enable (0, 1);
  insert soft DB.DBA.RDF_QUAD (G,S,P,O)
  values (g_iid, s_iid, p_iid, o_val);
  -- dbg_obj_princ ('DB.DBA.TTLP_EV_TRIPLE_L_W (', g_iid, s_uri, p_uri, o_val, o_type, o_lang, env, ') done');
  commit work;
  return;
deadlck:
  rollback work;
  goto again;
}
;

create procedure DB.DBA.TTLP_EV_NEW_GRAPH_A (inout g varchar, inout g_iid IRI_ID, inout app_env any) {
  -- dbg_obj_princ ('DB.DBA.TTLP_EV_NEW_GRAPH_A(', g, g_iid, app_env, ')');
  if (__rdf_obj_ft_rule_count_in_graph (g_iid))
    app_env[2][1] := dict_new (app_env[3]);
  else
    app_env[2][1] := null;
  if (__rdf_graph_is_in_enabled_repl (g_iid))
    app_env[4] := g;
  else
    app_env[4] := null;
}
;

create procedure DB.DBA.TTLP_EV_TRIPLE_A (
  inout g_iid IRI_ID, inout s_uri varchar, inout p_uri varchar,
  inout o_uri varchar,
  inout app_env any )
{
  -- dbg_obj_princ ('DB.DBA.TTLP_EV_TRIPLE_A (', g_iid, s_uri, p_uri, o_uri, app_env, ')');
  if (app_env[4] is not null)
    __rdf_repl_quad (84, app_env[4], iri_canonicalize (s_uri), iri_canonicalize (p_uri), iri_canonicalize (o_uri));
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
  if (app_env[4] is not null)
    {
      if (isstring (o_type))
        __rdf_repl_quad (81, app_env[4], iri_canonicalize (s_uri), iri_canonicalize (p_uri), o_val, iri_canonicalize (o_type), NULL);
      else if (isstring (o_lang))
        __rdf_repl_quad (82, app_env[4], iri_canonicalize (s_uri), iri_canonicalize (p_uri), o_val, null, o_lang);
      else
        __rdf_repl_quad (80, app_env[4], iri_canonicalize (s_uri), iri_canonicalize (p_uri), o_val);
    }
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
      aq_wait_all (app_env[0]);
    }
}
;

create procedure DB.DBA.TTLP_EV_COMMIT_A (
  inout graph_iri varchar, inout app_env any )
{
  -- dbg_obj_princ ('DB.DBA.TTLP_EV_COMMIT_A (', graph_iri, app_env, ')');
  commit work;
  aq_wait_all (app_env[0]);
  commit work;
  DB.DBA.TTLP_EV_COMMIT (graph_iri, app_env[2]);
  commit work;
}
;

-- for replication should not use AQ
create procedure DB.DBA.TTLP_EV_TRIPLE_R (
  inout g_iid IRI_ID, inout s_uri varchar, inout p_uri varchar,
  inout o_uri varchar,
  inout app_env any )
{
  -- dbg_obj_princ ('DB.DBA.TTLP_EV_TRIPLE_A (', g_iid, s_uri, p_uri, o_uri, app_env, ')');
  if (app_env[4] is not null)
    __rdf_repl_quad (84, app_env[4], iri_canonicalize (s_uri), iri_canonicalize (p_uri), iri_canonicalize (o_uri));
  commit work;
  app_env[1] := coalesce (app_env[1], 0) + 1;
  DB.DBA.TTLP_EV_TRIPLE_W (g_iid, s_uri, p_uri, o_uri, app_env[2]);
  if (mod (app_env[1], 100000) = 0)
    {
      declare ro_id_dict any;
      ro_id_dict := app_env[2][1];
      if (ro_id_dict is not null)
        DB.DBA.RDF_OBJ_ADD_KEYWORD_FOR_GRAPH (g_iid, ro_id_dict);
    }
}
;

create procedure DB.DBA.TTLP_EV_TRIPLE_L_R (
  inout g_iid IRI_ID, inout s_uri varchar, inout p_uri varchar,
  inout o_val any, inout o_type varchar, inout o_lang varchar,
  inout app_env any )
{
  -- dbg_obj_princ ('DB.DBA.TTLP_EV_TRIPLE_L_A (', g_iid, s_uri, p_uri, o_val, o_type, o_lang, app_env, ')');
  if (app_env[4] is not null)
    {
      if (isstring (o_type))
        __rdf_repl_quad (81, app_env[4], iri_canonicalize (s_uri), iri_canonicalize (p_uri), o_val, iri_canonicalize (o_type), NULL);
      else if (isstring (o_lang))
        __rdf_repl_quad (82, app_env[4], iri_canonicalize (s_uri), iri_canonicalize (p_uri), o_val, null, o_lang);
      else
        __rdf_repl_quad (80, app_env[4], iri_canonicalize (s_uri), iri_canonicalize (p_uri), o_val);
    }
  commit work;
  if (__tag of XML = __tag (o_val))
    {
      DB.DBA.TTLP_EV_TRIPLE_L_W (g_iid, s_uri, p_uri, o_val, o_type, o_lang, app_env[2]);
      return;
    }
  app_env[1] := coalesce (app_env[1], 0) + 1;
  DB.DBA.TTLP_EV_TRIPLE_L_W (g_iid, s_uri, p_uri, o_val, o_type, o_lang, app_env[2]);
  if (mod (app_env[1], 100000) = 0)
    {
      declare ro_id_dict any;
      ro_id_dict := app_env[2][1];
      if (ro_id_dict is not null)
        DB.DBA.RDF_OBJ_ADD_KEYWORD_FOR_GRAPH (g_iid, ro_id_dict);
    }
}
;

create procedure DB.DBA.TTLP_EV_COMMIT_R (
  inout graph_iri varchar, inout app_env any )
{
  -- dbg_obj_princ ('DB.DBA.TTLP_EV_COMMIT_A (', graph_iri, app_env, ')');
  DB.DBA.TTLP_EV_COMMIT (graph_iri, app_env[2]);
}
;

create function DB.DBA.TTLP_MT (in strg varchar, in base varchar, in graph varchar := null, in flags integer := 0,
				 in log_mode integer := 2, in threads integer := 3, in transactional int := 0)
{
  declare app_env any;
  if (graph = '')
    signal ('22023', 'Empty string is not a valid graph IRI in DB.DBA.TTLP_MT()');
  else if (graph is null)
    {
      graph := base;
      if ((graph is null) or (graph = ''))
        signal ('22023', 'DB.DBA.TTLP_MT() requires a valid IRI as a base argument if graph is not specified');
    }
  DB.DBA.TTLP_V (strg, base, graph, flags, threads, transactional, log_mode);
}
;

create function DB.DBA.TTLP_MT_LOCAL_FILE (in filename varchar, in base varchar, in graph varchar := null, in flags integer := 0,
				 in log_mode integer := 2, in threads integer := 3, in transactional int := 0)
{
  signal ('DEPRE', 'TTLP_MT_LOCAL_FILE  deprecated.  Use TTLP');
}
;

create function DB.DBA.RDF_LOAD_RDFXML_MT (in strg varchar, in base varchar, in graph varchar,
  in log_mode integer := 2, in threads integer := 3, in transactional int := 0)
{
  declare ro_id_dict, app_env any;
  if (graph = '')
    signal ('22023', 'Empty string is not a valid graph IRI in DB.DBA.RDF_LOAD_RDFXML_MT()');
  else if (graph is null)
    {
      graph := base;
      if ((graph is null) or (graph = ''))
        signal ('22023', 'DB.DBA.RDF_LOAD_RDFXML_MT() requires a valid IRI as a base argument if graph is not specified');
    }
  if (transactional = 0)
    {
      if (log_mode = 1 or log_mode = 0)
	log_mode := log_mode + 2;
    }
  DB.DBA.RDF_LOAD_RDFXML (strg, base, graph);
  return graph;
}
;


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
  if (not sys_stat ('rdf_query_graph_keywords'))
    return sprintf ('[__enc "UTF-8"] %s', phrase);
  graph_keyword := WS.WS.STR_SQL_APOS (rdf_graph_keyword (graph_keyword));
  return sprintf ('[__enc "UTF-8"] ^%s AND (%s)', graph_keyword, phrase);
err:
  return '^"#nosuch"';
}
;

--!AWK PUBLIC
create function DB.DBA.RDF_OBJ_PATCH_CONTAINS_BY_MANY_GRAPHS (in phrase varchar, in graph_iris any)
{
  declare isfirst, gctr, gcount integer;
  declare ses, graph_keyword any;
  if (not sys_stat ('rdf_query_graph_keywords'))
    return sprintf ('[__enc "UTF-8"] %s', phrase);
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
          http (WS.WS.STR_SQL_APOS (rdf_graph_keyword (graph_keyword)), ses);
        }
    }
  if (not isfirst)
    return sprintf ('[__enc "UTF-8"] (%s) AND (%s)', string_output_string (ses), phrase);
err:
  return '^"#nosuch"';
}
;

create procedure DB.DBA.RDF_OBJ_ADD_KEYWORD_FOR_GRAPH (in graph_iid IRI_ID, inout ro_id_dict any array, in daq any array := 0)
{
  declare ro_id_offset, ro_ids_count integer;
  declare new_ro_ids, vtb any;
  declare gwordump varchar;
  declare n_w, n_ins, n_upd, n_next integer;
  if (not sys_stat ('rdf_create_graph_keywords'))
    {
      dict_zap (ro_id_dict, 2);
      return;
    }
next_batch:
  new_ro_ids := dict_destructive_list_rnd_keys (ro_id_dict, 500000);
  ro_ids_count := length (new_ro_ids);
  if (0 = ro_ids_count)
    return;
  gwordump := ' ' || rdf_graph_keyword (graph_iid);
  gwordump[0] := length (gwordump) - 1;
  gvector_digit_sort (new_ro_ids, 1, 0, 1);
  if (0 = sys_stat ('cl_run_local_only'))
    {
      commit work;
      cl_g_words (new_ro_ids, gwordump, daq);
      goto next_batch;
    }
  vtb := vt_batch (__min (__max (ro_ids_count, 31), 500000));
  commit work;
  whenever sqlstate '40001' goto retry_add;
again:
  for (ro_id_offset := 0; ro_id_offset < ro_ids_count; ro_id_offset := ro_id_offset + 1)
    {
      vt_batch_d_id (vtb, new_ro_ids[ro_id_offset]);
      vt_batch_feed_wordump (vtb, gwordump, 0);
    }
  if (0 = sys_stat ('cl_run_local_only'))
    {
      declare is_local_daq int;
      if (0 = daq)
	{
	daq := daq (1);
	  is_local_daq := 1;
	}
      cl_g_text_index (vtb, daq);
      if (is_local_daq)
	{
	  while (daq_next (daq));
	  commit work;
	  goto next_batch;
	}
    }
  else
    "DB"."DBA"."VT_BATCH_PROCESS_DB_DBA_RDF_OBJ" (vtb, null);
  commit work;
  goto next_batch;
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
    select VT_D_ID, VT_D_ID_2, coalesce (VT_DATA, cast (VT_LONG_DATA as varchar)) from RDF_OBJ_RO_FLAGS_WORDS
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
        update RDF_OBJ_RO_FLAGS_WORDS set VT_D_ID_2 = split[split_len-1][1], VT_DATA = split[split_len-1][2], VT_LONG_DATA = null
      where current of cr;
      split_len := split_len - 1;
    }
  if (split_len > 0)
    {
      delete from RDF_OBJ_RO_FLAGS_WORDS
        where (VT_WORD = cast (graph_iid as varchar)) and (VT_D_ID >= split[0][0]) and (VT_D_ID_2 <= split[split_len-1][1]);
    }
  for (split_ctr := 0; split_ctr < split_len; split_ctr := split_ctr+1)
    {
      insert replacing RDF_OBJ_RO_FLAGS_WORDS (VT_WORD, VT_D_ID, VT_D_ID_2, VT_DATA)
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
      delete from RDF_OBJ_RO_FLAGS_WORDS
        where (VT_WORD = cast (graph_iid as varchar)) and (VT_D_ID >= split[0][0]) and (VT_D_ID_2 <= split[split_len-1][1]);
    }
  for (split_ctr := 0; split_ctr < split_len; split_ctr := split_ctr+1)
    {
      insert replacing RDF_OBJ_RO_FLAGS_WORDS (VT_WORD, VT_D_ID, VT_D_ID_2, VT_DATA)
      values (cast (graph_iid as varchar), split[split_ctr][0], split[split_ctr][1], split[split_ctr][2]);
    }
  if (length (carry_data)  <> 0)
    {
      insert replacing RDF_OBJ_RO_FLAGS_WORDS (VT_WORD, VT_D_ID, VT_D_ID_2, VT_DATA)
      values (cast (graph_iid as varchar), carry_d_id, carry_d_id_2, carry_data);
    }
  commit work;
-- debug begin
--  for (
--    select VT_WORD, VT_D_ID, VT_D_ID_2, coalesce (VT_DATA, cast (VT_LONG_DATA as varchar)) as vtd from RDF_OBJ_RO_FLAGS_WORDS
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

create procedure DB.DBA.RDF_OBJ_FT_INS_ALL (in this_box_only integer := 0)
{
  declare id, f integer;
  if (not this_box_only)
    {
      cl_exec ('DB.DBA.RDF_OBJ_FT_INS_ALL (1)');
      return;
    }
  set triggers off;

  declare c1 cursor for select RO_ID, RO_FLAGS from DB.DBA.RDF_OBJ where not (bit_and (RO_FLAGS, 1)) and RO_VAL > '' and RO_VAL < '\xFF\xFF\xFF\xFF\xFF\xFF' and isstring (RO_VAL) and RO_LONG is null for update option (no cluster);
start_c1:
  open c1;
  whenever sqlstate '42000' goto deadl_c1;
  whenever not found goto done_c1;
again_c1:
  fetch c1 into id, f;
  update DB.DBA.RDF_OBJ set RO_FLAGS = bit_or (RO_FLAGS, 1) where current of c1;
  insert into VTLOG_DB_DBA_RDF_OBJ option (no cluster) (VTLOG_RO_ID, SNAPTIME, DMLTYPE) values (id, curdatetime (), 'I');
  commit work;
  goto again_c1;
done_c1:
  close c1;

  declare c2 cursor for select RO_ID, RO_FLAGS from DB.DBA.RDF_OBJ where not (bit_and (RO_FLAGS, 1)) and RO_LONG is not NULL for update option (no cluster);
start_c2:
  open c2;
  whenever sqlstate '42000' goto deadl_c2;
  whenever not found goto done_c2;
again_c2:
  fetch c2 into id, f;
  update DB.DBA.RDF_OBJ set RO_FLAGS = bit_or (RO_FLAGS, 1) where current of c2;
  insert into VTLOG_DB_DBA_RDF_OBJ option (no cluster) (VTLOG_RO_ID, SNAPTIME, DMLTYPE) values (id, curdatetime (), 'I');
  commit work;
  goto again_c2;
done_c2:
  close c2;

start_g:
  whenever sqlstate '42000' goto deadl_g;
  for (select distinct G as curr_g FROm DB.DBA.RDF_QUAD table option (index RDF_QUAD_GS, index_only) option (no cluster)) do
    {
      declare ro_id_dict any;
      ro_id_dict := dict_new (100000);
      for (select distinct rdf_box_ro_id (O) as o_id from DB.DBA.RDF_QUAD join DB.DBA.RDF_OBJ on (RO_ID = rdf_box_ro_id (O))
        where G = curr_g
        and 0 = bit_and (RO_FLAGS, 1) and __tag (coalesce (RO_LONG, RO_VAL)) in (__tag of varchar, __tag of XML) ) do
        {
          update DB.DBA.RDF_OBJ set RO_FLAGS = bit_or (RO_FLAGS, 1) where RO_ID = o_id;
          insert soft DB.DBA.VTLOG_DB_DBA_RDF_OBJ option (no cluster) (VTLOG_RO_ID, SNAPTIME, DMLTYPE) values (o_id, curdatetime (), 'I');
          --insert soft rdf_ft (rf_id, rf_o) values (id, obj);
          dict_put (ro_id_dict, o_id, 1);
          commit work;
          if (dict_size (ro_id_dict) > 100000)
            DB.DBA.RDF_OBJ_ADD_KEYWORD_FOR_GRAPH (curr_g, ro_id_dict);
        }
      DB.DBA.RDF_OBJ_ADD_KEYWORD_FOR_GRAPH (curr_g, ro_id_dict);
      commit work;
    }

  return;
deadl_c1:
  rollback work;
  close c1;
  goto start_c1;
deadl_c2:
  rollback work;
  close c2;
  goto start_c2;
deadl_g:
  rollback work;
  goto start_g;
}
;

create function DB.DBA.RDF_OBJ_FT_RULE_ADD (in rule_g varchar, in rule_p varchar, in reason varchar) returns integer
{
  declare rule_g_iid, rule_p_iid IRI_ID;
  declare ro_id_dict any;
  if (0 = sys_stat ('cl_run_local_only'))
    signal ('42000', 'DB.DBA.RDF_OBJ_FT_RULE_ADD() is not available in cluster. Do DB.DBA.CL_TEXT_INDEX (1) to enable text index on all future RDF loads on cluster.');
  set triggers off;
  if (rule_g is null)
    rule_g := '';
  if (rule_p is null)
    rule_p := '';
  rule_g_iid := case (rule_g) when '' then null else iri_to_id (rule_g) end;
  rule_p_iid := case (rule_p) when '' then null else iri_to_id (rule_p) end;
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
          for (select distinct rdf_box_ro_id (O) as id from DB.DBA.RDF_QUAD join DB.DBA.RDF_OBJ on (RO_ID = rdf_box_ro_id (O))
            where G=rule_g_iid and P=rule_p_iid
            and 0 = bit_and (RO_FLAGS, 1) and __tag(coalesce (RO_LONG, RO_VAL)) in (__tag of varchar, __tag of XML) ) do
                    {
              update DB.DBA.RDF_OBJ set RO_FLAGS = bit_or (RO_FLAGS, 1) where RO_ID = id;
              insert soft DB.DBA.VTLOG_DB_DBA_RDF_OBJ option (no cluster) (VTLOG_RO_ID, SNAPTIME, DMLTYPE) values (id, curdatetime (), 'I');
		      --insert soft rdf_ft (rf_id, rf_o) values (id, obj);
                      dict_put (ro_id_dict, id, 1);
                  commit work;
              if (dict_size (ro_id_dict) > 100000)
                DB.DBA.RDF_OBJ_ADD_KEYWORD_FOR_GRAPH (rule_g_iid, ro_id_dict);
            }
          DB.DBA.RDF_OBJ_ADD_KEYWORD_FOR_GRAPH (rule_g_iid, ro_id_dict);
        }
      else if (rule_g <> '')
        {
          ro_id_dict := dict_new (100000);
          for (select distinct rdf_box_ro_id (O) as id from DB.DBA.RDF_QUAD join DB.DBA.RDF_OBJ on (RO_ID = rdf_box_ro_id (O))
            where G=rule_g_iid
            and 0 = bit_and (RO_FLAGS, 1) and __tag(coalesce (RO_LONG, RO_VAL)) in (__tag of varchar, __tag of XML) ) do
            {
              update DB.DBA.RDF_OBJ set RO_FLAGS = bit_or (RO_FLAGS, 1) where RO_ID = id;
              insert soft DB.DBA.VTLOG_DB_DBA_RDF_OBJ option (no cluster) (VTLOG_RO_ID, SNAPTIME, DMLTYPE) values (id, curdatetime (), 'I');
		      --insert soft rdf_ft (rf_id, rf_o) values (id, obj);
                      dict_put (ro_id_dict, id, 1);
                  commit work;
              if (dict_size (ro_id_dict) > 100000)
                DB.DBA.RDF_OBJ_ADD_KEYWORD_FOR_GRAPH (rule_g_iid, ro_id_dict);
            }
          DB.DBA.RDF_OBJ_ADD_KEYWORD_FOR_GRAPH (rule_g_iid, ro_id_dict);
        }
      else if (rule_p <> '')
        {
          declare old_g IRI_ID;
          old_g := #i0;
                      ro_id_dict := dict_new (100000);
          for (select G as curr_g, S as curr_s from DB.DBA.RDF_QUAD table option (index RDF_QUAD_GS, index_only)) do
                {
              for (select distinct rdf_box_ro_id (O) as id from DB.DBA.RDF_QUAD join DB.DBA.RDF_OBJ on (RO_ID = rdf_box_ro_id (O))
                where G = curr_g and P = rule_p_iid
                and 0 = bit_and (RO_FLAGS, 1) and __tag(coalesce (RO_LONG, RO_VAL)) in (__tag of varchar, __tag of XML) ) do
                    {
                      if (curr_g <> old_g)
                        {
                            DB.DBA.RDF_OBJ_ADD_KEYWORD_FOR_GRAPH (old_g, ro_id_dict);
                          old_g := curr_g;
                        }
                  update DB.DBA.RDF_OBJ set RO_FLAGS = bit_or (RO_FLAGS, 1) where RO_ID = id;
                  insert soft DB.DBA.VTLOG_DB_DBA_RDF_OBJ option (no cluster) (VTLOG_RO_ID, SNAPTIME, DMLTYPE) values (id, curdatetime (), 'I');
		      --insert soft rdf_ft (rf_id, rf_o) values (id, obj);
                      dict_put (ro_id_dict, id, 1);
                      commit work;
                      if (dict_size (ro_id_dict) > 100000)
                        DB.DBA.RDF_OBJ_ADD_KEYWORD_FOR_GRAPH (curr_g, ro_id_dict);
                    }
                }
          DB.DBA.RDF_OBJ_ADD_KEYWORD_FOR_GRAPH (old_g, ro_id_dict);
          commit work;
    }
      else
        DB.DBA.RDF_OBJ_FT_INS_ALL ();
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
  rule_g_iid := case (rule_g) when '' then null else iri_to_id (rule_g) end;
  rule_p_iid := case (rule_p) when '' then null else iri_to_id (rule_p) end;
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
  if (((0 = sys_stat ('cl_run_local_only')) and (1 = cast (registry_get ('cl_rdf_text_index') as integer)))
    or exists (select 1 from DB.DBA.RDF_OBJ_FT_RULES where ROFR_G = '' and ROFR_P = '') )
    {
      result ('One of rules requires total indexing, so the rest of rules will not require any selective processing...');
      DB.DBA.RDF_OBJ_FT_INS_ALL ();
    }
  else
    {
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
    }
  result ('Now starting incremental update of free-text index...');
  VT_INC_INDEX_DB_DBA_RDF_OBJ();
  result ('... done');
}
;

-----
-- Security

create table DB.DBA.RDF_GRAPH_GROUP (
  RGG_IID IRI_ID not null primary key,
  RGG_IRI varchar not null,
  RGG_MEMBER_PATTERN varchar,
  RGG_COMMENT varchar
  )
alter index RDF_GRAPH_GROUP on DB.DBA.RDF_GRAPH_GROUP partition cluster replicated
create index RDF_GRAPH_GROUP_IRI on DB.DBA.RDF_GRAPH_GROUP (RGG_IRI) partition cluster replicated
;

create table DB.DBA.RDF_GRAPH_GROUP_MEMBER (
  RGGM_GROUP_IID IRI_ID not null,
  RGGM_MEMBER_IID IRI_ID not null,
  primary key (RGGM_GROUP_IID, RGGM_MEMBER_IID)
  )
alter index RDF_GRAPH_GROUP_MEMBER on DB.DBA.RDF_GRAPH_GROUP_MEMBER partition cluster replicated
;

create table DB.DBA.RDF_GRAPH_USER (
  RGU_GRAPH_IID IRI_ID not null,
  RGU_USER_ID integer not null,
  RGU_PERMISSIONS integer not null, -- 1 for read, 2 for write, 4 for sponge, 8 for list, 16 for admin, 256 for owner.
  primary key (RGU_GRAPH_IID, RGU_USER_ID)
  )
alter index RDF_GRAPH_USER on DB.DBA.RDF_GRAPH_USER partition cluster replicated
create index RDF_GRAPH_USER_USER_ID on DB.DBA.RDF_GRAPH_USER (RGU_USER_ID, RGU_GRAPH_IID, RGU_PERMISSIONS) partition cluster replicated
;

create procedure DB.DBA.RDF_GRAPH_CACHE_IID (in iid IRI_ID)
{
  declare iri any;
  iri := __uname (id_to_canonicalized_iri (iid));
  dict_put (__rdf_graph_iri2id_dict(), iri, iid);
  dict_put (__rdf_graph_id2iri_dict(), iid, iri);
}
;

create procedure DB.DBA.RDF_GRAPH_GROUP_CREATE_MEMONLY (in group_iri varchar, in group_iid IRI_ID)
{
  group_iri := cast (group_iri as varchar);
  DB.DBA.RDF_GRAPH_CACHE_IID (group_iid);
  dict_put (__rdf_graph_group_dict(), group_iid, vector ());
  jso_mark_affected (group_iri);
  log_text ('jso_mark_affected (?)', group_iri);
  __rdf_cli_mark_qr_to_recompile ();
}
;

create function DB.DBA.RDF_GRAPH_GROUP_IRI_CHECK (in group_iri varchar, in fname varchar) returns IRI_ID
{
  declare group_iid IRI_ID;
  group_iri := cast (group_iri as varchar);
  group_iid := iri_to_id (group_iri);
  if (group_iri <> id_to_canonicalized_iri (group_iid))
    signal ('RDF99', sprintf ('Group IRI should be canonical, but the specified group IRI <%s> differs from its canonical form <%s>', group_iri, id_to_canonicalized_iri (group_iid)));
  for (select RGG_IID from DB.DBA.RDF_GRAPH_GROUP where RGG_IRI = group_iri) do
    {
      if (RGG_IID = group_iid)
        return RGG_IID;
      if (not exists (select top 1 1 from DB.DBA.RDF_GRAPH_GROUP where RGG_IID = group_iid))
        signal ('RDF99', sprintf ('Integrity violation in DB.DBA.RDF_GRAPH_GROUP table (found group IRI <%s>, not found group IRI ID %s)', group_iri, cast (group_iid as varchar)));
    }
  for (select RGG_IRI from DB.DBA.RDF_GRAPH_GROUP where RGG_IID = group_iid) do
    {
      if (RGG_IRI = id_to_canonicalized_iri (group_iid))
        signal ('RDF99', sprintf ('Table DB.DBA.RDF_GRAPH_GROUP contains group with IRI <%s>, not IRI <%s>, for group IRI ID %s', RGG_IRI, group_iri, cast (group_iid as varchar)));
      signal ('RDF99', sprintf ('Integrity violation in DB.DBA.RDF_GRAPH_GROUP table (not found group IRI <%s>, found group IRI ID %s)', group_iri, cast (group_iid as varchar)));
    }
  return NULL;
}
;

create procedure DB.DBA.RDF_GRAPH_GROUP_CREATE (in group_iri varchar, in quiet integer, in member_pattern varchar := null, in comment varchar := null)
{
  declare group_iid IRI_ID;
  group_iri := cast (group_iri as varchar);
  group_iid := iri_to_id (group_iri);
  DB.DBA.RDF_GRAPH_GROUP_IRI_CHECK (group_iri, 'DB.DBA.RDF_GRAPH_GROUP_CREATE');
  if (exists (select top 1 1 from DB.DBA.RDF_GRAPH_GROUP where RGG_IRI = group_iri))
    {
      if (quiet)
        return;
      signal ('RDF99', sprintf ('The graph group <%s> already exists (%s)', group_iri, coalesce (
          (select top 1 RGG_COMMENT from DB.DBA.RDF_GRAPH_GROUP where RGG_IRI = group_iri), 'group has no comment' ) ) );
    }
  insert into DB.DBA.RDF_GRAPH_GROUP (
    RGG_IID, RGG_IRI, RGG_MEMBER_PATTERN, RGG_COMMENT )
  values (group_iid, group_iri, member_pattern, comment);
  commit work;
  DB.DBA.SECURITY_CL_EXEC_AND_LOG ('DB.DBA.RDF_GRAPH_GROUP_CREATE_MEMONLY (?, ?)', vector (group_iri, group_iid));
}
;

create procedure DB.DBA.RDF_GRAPH_GROUP_DROP_MEMONLY (in group_iri varchar, in group_iid IRI_ID)
{
  group_iri := cast (group_iri as varchar);
  DB.DBA.RDF_GRAPH_CACHE_IID (group_iid);
  dict_put (__rdf_graph_group_dict(), group_iid, vector ());
  dict_remove (__rdf_graph_group_dict(), group_iid);
  jso_mark_affected (group_iri);
  log_text ('jso_mark_affected (?)', group_iri);
  if (group_iri = 'http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs')
    {
      declare privates any;
      privates := dict_list_keys (__rdf_graph_group_of_privates_dict(), 2);
      foreach (IRI_ID iid in privates) do
        {
          jso_mark_affected (id_to_iri (iid));
          log_text ('jso_mark_affected (?)', id_to_iri (iid));
        }
    }
  __rdf_cli_mark_qr_to_recompile ();
}
;

create procedure DB.DBA.RDF_GRAPH_GROUP_DROP (in group_iri varchar, in quiet integer)
{
  declare group_iid IRI_ID;
  group_iri := cast (group_iri as varchar);
  group_iid := iri_to_id (group_iri);
  DB.DBA.RDF_GRAPH_GROUP_IRI_CHECK (group_iri, 'DB.DBA.RDF_GRAPH_GROUP_DROP');
  if (not exists (select top 1 1 from DB.DBA.RDF_GRAPH_GROUP where RGG_IRI = group_iri))
    {
      if (quiet)
        return;
      signal ('RDF99', sprintf ('The graph group <%s> does not exist (%s)', group_iri, coalesce (
          (select top 1 RGG_COMMENT from DB.DBA.RDF_GRAPH_GROUP where RGG_IRI = group_iri), 'group has no comment' ) ) );
    }
  if (group_iri = 'http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs')
    signal ('RDF99', sprintf ('The graph group <%s> is a special one and used to control security, can not drop it' ) );
  delete from DB.DBA.RDF_GRAPH_GROUP_MEMBER where RGGM_GROUP_IID = group_iid;
  delete from DB.DBA.RDF_GRAPH_GROUP where RGG_IID = group_iid;
  commit work;
  DB.DBA.SECURITY_CL_EXEC_AND_LOG ('DB.DBA.RDF_GRAPH_GROUP_DROP_MEMONLY (?, ?)', vector (group_iri, group_iid));
}
;

create procedure DB.DBA.RDF_GRAPH_CHECK_VISIBILITY_CHANGE (in memb_iri varchar, in special_iid IRI_ID)
{
  declare memb_iid IRI_ID;
  memb_iid := iri_to_id (memb_iri);
  declare new_default_perms integer;
  new_default_perms := (select RGU_PERMISSIONS from DB.DBA.RDF_GRAPH_USER where RGU_GRAPH_IID = special_iid and RGU_USER_ID = http_nobody_uid());
  for (select g.RGU_PERMISSIONS as g_perms, s.RGU_PERMISSIONS as s_perms, g.RGU_USER_ID as uid
    from DB.DBA.RDF_GRAPH_USER as g left outer join DB.DBA.RDF_GRAPH_USER as s on (g.RGU_USER_ID = s.RGU_USER_ID and s.RGU_GRAPH_IID = special_iid)
    where g.RGU_GRAPH_IID = memb_iid ) do
    {
      if (s_perms is not null and bit_and (s_perms, bit_not (g_perms)))
        signal ('RDF99', sprintf ('Default %s permissions of user "%s" (UID %d) on RDF store can not be broader than permissions on specific graph <%s> so the graph can not be %s now',
          case (equ (special_iid, #i8192)) when 0 then '"world"' else '"private area"' end,
          (select U_NAME from DB.DBA.SYS_USERS where U_ID = uid),
          uid,
          memb_iri,
          case (equ (special_iid, #i8192)) when 0 then 'removed from the "private area"' else 'added to the "private area"' end ) );
      if (new_default_perms is not null and bit_and (new_default_perms, bit_not (g_perms)))
        signal ('RDF99', sprintf ('Default %s permissions of unauthenticated user on RDF store can not be broader than permissions of user "%s" (UID %d)  on specific graph <%s> so the graph can not be %s now',
          case (equ (special_iid, #i8192)) when 0 then '"world"' else '"private area"' end,
          (select U_NAME from DB.DBA.SYS_USERS where U_ID = uid),
          uid,
          memb_iri,
          case (equ (special_iid, #i8192)) when 0 then 'removed from the "private area"' else 'added to the "private area"' end ) );
    }
}
;

create procedure DB.DBA.RDF_GRAPH_GROUP_INS_MEMONLY (in group_iri varchar, in group_iid IRI_ID, in memb_iri varchar, in memb_iid IRI_ID)
{
  declare membs any;
  group_iri := cast (group_iri as varchar);
  memb_iri := cast (memb_iri as varchar);
  DB.DBA.RDF_GRAPH_CACHE_IID (group_iid);
  DB.DBA.RDF_GRAPH_CACHE_IID (memb_iid);
--  This is not scalable enough for big groups: N*N/2 time to create a group of size N.
--  dict_put (__rdf_graph_group_dict(), group_iid,
--    (select VECTOR_AGG (RGGM_MEMBER_IID) from DB.DBA.RDF_GRAPH_GROUP_MEMBER
--     where RGGM_GROUP_IID = group_iid
--     order by RGGM_MEMBER_IID ) );
  membs := dict_get (__rdf_graph_group_dict(), group_iid, null);
  if (membs is null)
    dict_put (__rdf_graph_group_dict(), group_iid, vector (memb_iid));
  else if (isvector (membs))
    {
      if (0 >= position (memb_iid, membs))
        {
          if (length (membs) < 1000)
            dict_put (__rdf_graph_group_dict(), group_iid, vector_concat (membs, vector (memb_iid)));
          else
            {
              declare new_membs any;
              new_membs := dict_new (1000);
              foreach (IRI_ID m in membs) do dict_put (new_membs, m, 1);
              dict_put (new_membs, memb_iid, 1);
              dict_put (__rdf_graph_group_dict(), group_iid, new_membs);
            }
        }
    }
  else
    {
      dict_put (membs, memb_iid, 1);
      dict_put (__rdf_graph_group_dict(), group_iid, membs);
    }
  jso_mark_affected (group_iri);
  log_text ('jso_mark_affected (?)', group_iri);
  if (group_iri = 'http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs')
    {
      dict_put (__rdf_graph_group_of_privates_dict(), memb_iid, 1);
      jso_mark_affected (memb_iri);
      log_text ('jso_mark_affected (?)', memb_iri);
    }
}
;

create procedure DB.DBA.RDF_GRAPH_GROUP_INS (in group_iri varchar, in memb_iri varchar)
{
  declare group_iid, memb_iid IRI_ID;
  group_iri := cast (group_iri as varchar);
  DB.DBA.RDF_GRAPH_GROUP_IRI_CHECK (group_iri, 'DB.DBA.RDF_GRAPH_GROUP_INS');
  memb_iri := cast (memb_iri as varchar);
  group_iid := iri_to_id (group_iri);
  memb_iid := iri_to_id (memb_iri);
  set isolation = 'serializable';
  commit work;
  if (not exists (select top 1 1 from DB.DBA.RDF_GRAPH_GROUP where RGG_IRI = group_iri))
    signal ('RDF99', sprintf ('Graph group <%s> does not exist', group_iri));
  if (group_iri = 'http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs')
    {
      DB.DBA.RDF_GRAPH_CHECK_VISIBILITY_CHANGE (memb_iri, #i8192);
      if (isstring (registry_get ('DB.DBA.RDF_REPL'))
        and exists (select top 1 1 from DB.DBA.RDF_GRAPH_GROUP_MEMBER
          where RGGM_GROUP_IID = iri_to_id (UNAME'http://www.openlinksw.com/schemas/virtrdf#rdf_repl_graph_group') and RGGM_MEMBER_IID = memb_iid)
        and not exists (select RGU_PERMISSIONS from DB.DBA.RDF_GRAPH_USER
          where RGU_GRAPH_IID = memb_iid and RGU_USER_ID = http_nobody_uid() and bit_and (RGU_PERMISSIONS, 1) )
        and not exists (select RGU_PERMISSIONS from DB.DBA.RDF_GRAPH_USER
          where RGU_GRAPH_IID = #i8192 and RGU_USER_ID = http_nobody_uid() and bit_and (RGU_PERMISSIONS, 1) )
        and not exists (select RGU_PERMISSIONS from DB.DBA.RDF_GRAPH_USER
          where RGU_GRAPH_IID = memb_iid and RGU_USER_ID = __rdf_repl_uid() and bit_and (RGU_PERMISSIONS, 1) )
        and not exists (select RGU_PERMISSIONS from DB.DBA.RDF_GRAPH_USER
          where RGU_GRAPH_IID = #i8192 and RGU_USER_ID = __rdf_repl_uid() and bit_and (RGU_PERMISSIONS, 1) ) )
        signal ('RDF99', 'Can not add graph <' || memb_iri || '> to group of private graphs <' || group_iri || '>; either stop the RDF replication of this graph or grant an explicit read permission to __rdf_repl account');
    }
  else if (group_iri = 'http://www.openlinksw.com/schemas/virtrdf#rdf_repl_graph_group')
    {
      if (memb_iri = DB.DBA.JSO_SYS_GRAPH())
        signal ('RDF99', 'Graph group <' || group_iri || '> is for RDF replication; can not enable RDF replication of <' || memb_iri || '> (the system metadata graph)');
      if (isstring (registry_get ('DB.DBA.RDF_REPL')) and not __rgs_ack_cbk (memb_iid, __rdf_repl_uid(), 1))
        signal ('RDF99', 'Graph group <' || group_iri || '> is for RDF replication; can not enable RDF replication of graph <' || memb_iri || '> because it is not readable by __rdf_repl account');
    }
  insert soft DB.DBA.RDF_GRAPH_GROUP_MEMBER (RGGM_GROUP_IID, RGGM_MEMBER_IID)
  values (group_iid, memb_iid);
  commit work;
  DB.DBA.SECURITY_CL_EXEC_AND_LOG ('DB.DBA.RDF_GRAPH_GROUP_INS_MEMONLY (?, ?, ?, ?)', vector (group_iri, group_iid, memb_iri, memb_iid));
}
;

create procedure DB.DBA.RDF_GRAPH_GROUP_DEL_MEMONLY (in group_iri varchar, in group_iid IRI_ID, in memb_iri varchar, in memb_iid IRI_ID)
{
  declare membs any;
  group_iri := cast (group_iri as varchar);
  memb_iri := cast (memb_iri as varchar);
  DB.DBA.RDF_GRAPH_CACHE_IID (group_iid);
  DB.DBA.RDF_GRAPH_CACHE_IID (memb_iid);
--  This is not scalable enough for big groups: N*N/2 time to drop a group of size N item by item.
--  dict_put (__rdf_graph_group_dict(), group_iid,
--    (select VECTOR_AGG (RGGM_MEMBER_IID) from DB.DBA.RDF_GRAPH_GROUP_MEMBER
--     where RGGM_GROUP_IID = group_iid
--     order by RGGM_MEMBER_IID ) );
  membs := dict_get (__rdf_graph_group_dict(), group_iid, null);
  if (membs is null)
    dict_put (__rdf_graph_group_dict(), group_iid, vector ());
  else if (isvector (membs))
    {
      declare p integer;
again:
      p := position (memb_iid, membs);
      if (p > 0)
        {
          membs := vector_concat (subseq (membs, 0, p-1), subseq (membs, p));
          goto again; -- Paranoidal check for multiple occurencies of memb_iid in the graph group
        }
      dict_put (__rdf_graph_group_dict(), group_iid, membs);
    }
  else
    {
      dict_remove (membs, memb_iid);
      dict_put (__rdf_graph_group_dict(), group_iid, membs);
    }
  jso_mark_affected (group_iri);
  log_text ('jso_mark_affected (?)', group_iri);
  if (group_iri = 'http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs')
    {
      dict_remove (__rdf_graph_group_of_privates_dict(), memb_iid);
      jso_mark_affected (memb_iri);
      log_text ('jso_mark_affected (?)', memb_iri);
    }
}
;

create procedure DB.DBA.RDF_GRAPH_GROUP_DEL (in group_iri varchar, in memb_iri varchar)
{
  declare group_iid, memb_iid IRI_ID;
  group_iri := cast (group_iri as varchar);
  DB.DBA.RDF_GRAPH_GROUP_IRI_CHECK (group_iri, 'DB.DBA.RDF_GRAPH_GROUP_DEL');
  memb_iri := cast (memb_iri as varchar);
  group_iid := iri_to_id (group_iri);
  memb_iid := iri_to_id (memb_iri);
  set isolation = 'serializable';
  commit work;
  if (not exists (select top 1 1 from DB.DBA.RDF_GRAPH_GROUP where RGG_IRI = group_iri))
    signal ('RDF99', sprintf ('Graph group <%s> does not exist', group_iri));
  if (group_iri = 'http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs')
    DB.DBA.RDF_GRAPH_CHECK_VISIBILITY_CHANGE (memb_iri, #i0);
  delete from DB.DBA.RDF_GRAPH_GROUP_MEMBER
  where RGGM_GROUP_IID = group_iid and RGGM_MEMBER_IID = memb_iid;
  commit work;
  DB.DBA.SECURITY_CL_EXEC_AND_LOG ('DB.DBA.RDF_GRAPH_GROUP_DEL_MEMONLY (?, ?, ?, ?)', vector (group_iri, group_iid, memb_iri, memb_iid));
}
;

create function DB.DBA.RDF_GRAPH_USER_PERMS_GET (in graph_iri varchar, in uid any) returns integer
{
  declare graph_iid IRI_ID;
  declare res integer;
  graph_iid := iri_to_id (graph_iri);
  if (isstring (uid))
    uid := ((select U_ID from DB.DBA.SYS_USERS where U_NAME = uid and (U_NAME='nobody' or (U_SQL_ENABLE and not U_ACCOUNT_DISABLED))));
  if (uid is null)
    return 0;
  if (uid = 0)
    return 1023;
  res := coalesce (
    (select RGU_PERMISSIONS from DB.DBA.RDF_GRAPH_USER where RGU_GRAPH_IID = graph_iid and RGU_USER_ID = uid),
    __rdf_graph_approx_perms (graph_iid, uid) );
  return res;
}
;

create function DB.DBA.RDF_GRAPH_USER_PERMS_ACK (in graph_iri any, in uid any, in req_perms integer) returns integer
{
  declare app_cbk, app_uid varchar;
  declare graph_iid IRI_ID;
  declare perms integer;
  -- dbg_obj_princ ('DB.DBA.RDF_GRAPH_USER_PERMS_ACK (', graph_iri, uid, req_perms, ')');
  graph_iid := iri_to_id (graph_iri);
  if (__tag (uid) = __tag of vector)
    {
      app_cbk := uid[1];
      app_uid := uid[2];
      uid := uid[0];
    }
  else
    app_cbk := NULL;
  if (isstring (uid))
    uid := ((select U_ID from DB.DBA.SYS_USERS where U_NAME = uid and (U_NAME='nobody' or (U_SQL_ENABLE and not U_ACCOUNT_DISABLED))));
  if (uid is null)
    perms := 0;
  else if (uid = 0)
    perms := 1023;
  else
    {
      perms := __rdf_graph_approx_perms (graph_iid, uid);
      if (bit_and (perms, req_perms) <> req_perms)
        perms := coalesce ((select RGU_PERMISSIONS from DB.DBA.RDF_GRAPH_USER where RGU_GRAPH_IID = graph_iid and RGU_USER_ID = uid), perms);
    }
  if (bit_and (perms, req_perms) <> req_perms)
    return 0;
  if (app_cbk is not null)
    {
      perms := call (app_cbk)(graph_iid, app_uid);
      if (bit_and (perms, req_perms) <> req_perms)
        return 0;
    }
  return 1;
}
;

--!AWK PUBLIC
create function DB.DBA.RDF_GRAPH_USER_PERM_TITLE (in perms integer) returns varchar
{
  if (bit_and (perms, 1))
    return 'read';
  if (bit_and (perms, 2))
    return 'write';
  if (bit_and (perms, 4))
    return 'sponge';
  if (bit_and (perms, 8))
    return 'get-group-list';
  return sprintf ('"%d"', perms);
}
;

create function DB.DBA.RDF_GRAPH_USER_PERMS_ASSERT (in graph_iri varchar, in uid any, in req_perms integer, in opname varchar) returns varchar
{
  declare app_cbk, app_uid varchar;
  declare graph_iid IRI_ID;
  declare perms integer;
  -- dbg_obj_princ ('DB.DBA.RDF_GRAPH_USER_PERMS_ASSERT (', graph_iri, uid, req_perms, opname, ')');
  return __rgs_assert_cbk (graph_iri, uid, req_perms, opname);
  graph_iid := iri_to_id (graph_iri);
  if (__tag (uid) = __tag of vector)
    {
      app_cbk := uid[1];
      app_uid := uid[2];
      uid := uid[0];
    }
  else
    app_cbk := NULL;
  if (isstring (uid))
    uid := ((select U_ID from DB.DBA.SYS_USERS where U_NAME = uid and (U_NAME='nobody' or (U_SQL_ENABLE and not U_ACCOUNT_DISABLED))));
  if (uid is null)
    perms := 0;
  else if (uid = 0)
    perms := 1023;
  else
    perms := coalesce (
      (select RGU_PERMISSIONS from DB.DBA.RDF_GRAPH_USER where RGU_GRAPH_IID = graph_iid and RGU_USER_ID = uid),
      (select RGU_PERMISSIONS from DB.DBA.RDF_GRAPH_USER where RGU_GRAPH_IID = graph_iid and RGU_USER_ID = http_nobody_uid()),
      (select RGU_PERMISSIONS from DB.DBA.RDF_GRAPH_USER where RGU_GRAPH_IID = #i0 and RGU_USER_ID = uid),
      (select RGU_PERMISSIONS from DB.DBA.RDF_GRAPH_USER where RGU_GRAPH_IID = #i0 and RGU_USER_ID = http_nobody_uid()),
      15 );
  if (bit_and (perms, req_perms) <> req_perms)
    signal ('RDF02', sprintf ('%s access denied: database user %s (%s) has no %s permission on graph %s',
      opname, cast (uid as varchar), coalesce ((select top 1 U_NAME from DB.DBA.SYS_USERS where U_ID=uid)),
      DB.DBA.RDF_GRAPH_USER_PERM_TITLE (bit_and (bit_not (perms), req_perms)),
      graph_iri ) );
  if (app_cbk is not null)
    {
      perms := call (app_cbk)(graph_iid, app_uid);
      if (bit_and (perms, req_perms) <> req_perms)
        signal ('RDF02', sprintf ('%s access denied: application user %s has no %s permission on graph %s',
          opname, cast (uid as varchar), coalesce ((select top 1 U_NAME from DB.DBA.SYS_USERS where U_ID=uid)),
          DB.DBA.RDF_GRAPH_USER_PERM_TITLE (bit_and (bit_not (perms), req_perms)),
          graph_iri ) );
    }
  return graph_iri;
}
;

create procedure DB.DBA.RDF_DEFAULT_USER_PERMS_SET_MEMONLY (in uname varchar, in uid integer, in perms integer, in special_iid IRI_ID, in set_private integer, in affected_jso any)
{
  if (perms is null)
    dict_remove (__rdf_graph_default_perms_of_user_dict (set_private), uid);
  else
    dict_put (__rdf_graph_default_perms_of_user_dict (set_private), uid, perms);
  if (uid = http_nobody_uid())
    {
      if (perms is null)
        dict_remove (__rdf_graph_public_perms_dict(), special_iid);
      else
        dict_put (__rdf_graph_public_perms_dict(), special_iid, perms);
    }
  foreach (varchar jso_key in affected_jso) do
    {
      jso_mark_affected (jso_key);
      log_text ('jso_mark_affected (?)', jso_key);
    }
}
;

create procedure DB.DBA.RDF_DEFAULT_USER_PERMS_SET (in uname varchar, in perms integer, in set_private integer := 0)
{
  declare uid integer;
  declare special_iid IRI_ID;
  declare affected_jso any;
  -- dbg_obj_princ ('gs_hist.sql'); string_to_file ('gs_hist.sql', sprintf ('-- DB.DBA.RDF_DEFAULT_USER_PERMS_SET (''%s'', %d, %d);\n', uname, perms, set_private), -1);
  if (perms is null)
    {
      DB.DBA.RDF_DEFAULT_USER_PERMS_DEL (uname, set_private);
      return;
    }
  uid := (select U_ID from DB.DBA.SYS_USERS where U_NAME = uname and (U_NAME='nobody' or (U_SQL_ENABLE and not U_ACCOUNT_DISABLED)));
  set isolation = 'serializable';
  commit work;
  if (uid is null)
    signal ('RDF99', sprintf ('No active SQL user "%s" found, can not set its default permissions on RDF quad storage', uname));
  if (set_private)
    {
      special_iid := #i8192;
      for (select RGU_GRAPH_IID, RGU_PERMISSIONS from DB.DBA.RDF_GRAPH_USER
        where RGU_GRAPH_IID <> #i0 and RGU_GRAPH_IID <> #i8192 and
          RGU_USER_ID = uid and bit_and (bit_not (RGU_PERMISSIONS), perms) <> 0 and
          exists (select top 1 1 from DB.DBA.RDF_GRAPH_GROUP_MEMBER where
              RGGM_GROUP_IID = iri_to_id ('http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs') and
              RGGM_MEMBER_IID = RGU_GRAPH_IID ) ) do
        signal ('RDF99', sprintf ('Default "private area" permissions of user "%s" on RDF quad store can not become broader than permissions on specific "private" graph <%s>',
            uname, id_to_iri (RGU_GRAPH_IID) ) );
    }
  else
    {
      special_iid := #i0;
      for (select RGU_GRAPH_IID, RGU_PERMISSIONS from DB.DBA.RDF_GRAPH_USER
        where RGU_GRAPH_IID <> #i0 and RGU_GRAPH_IID <> #i8192 and
          RGU_USER_ID = uid and bit_and (bit_not (RGU_PERMISSIONS), perms) <> 0 and
          not exists (select top 1 1 from DB.DBA.RDF_GRAPH_GROUP_MEMBER where
              RGGM_GROUP_IID = iri_to_id ('http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs') and
              RGGM_MEMBER_IID = RGU_GRAPH_IID ) ) do
        signal ('RDF99', sprintf ('Default "world" permissions of user "%s" on RDF quad store can not become broader than permissions on specific "world" graph <%s>',
            uname, id_to_iri (RGU_GRAPH_IID) ) );
    }
  if (uname='nobody')
    {
      for (select RGU_USER_ID, RGU_PERMISSIONS from DB.DBA.RDF_GRAPH_USER
        where RGU_USER_ID <> uid and RGU_GRAPH_IID = special_iid and bit_and (bit_not (RGU_PERMISSIONS), perms) <> 0 ) do
          signal ('RDF99', sprintf ('Default %s permissions of unauthenticated user ("nobody") on RDF quad store can not become broader than permissions of user %s (UID %d)',
            (case (set_private) when 0 then '"world"' else '"private area"' end),
            (select top 1 U_NAME from Db.DBA.SYS_USERS where U_ID = RGU_USER_ID), RGU_USER_ID) );
-- This is not required:
--      for (select RGU_GRAPH_IID, RGU_USER_ID, RGU_PERMISSIONS from DB.DBA.RDF_GRAPH_USER where RGU_USER_ID <> uid and RGU_GRAPH_IID <> #i0 and bit_and (bit_not (RGU_PERMISSIONS), perms) <> 0)
--        signal ('RDF99', sprintf ('Default permissions of unauthenticated user ("nobody") on RDF quad store can not become broader than permissions of user %s (UID %d) on specific graph <%s>',
--          (select top 1 U_NAME from Db.DBA.SYS_USER where U_ID = RGU_USER_ID), RGU_USER_ID, id_to_iri (RGU_GRAPH_IID) ) );
      if (isstring (registry_get ('DB.DBA.RDF_REPL')) and not (bit_and (perms, 1))
        and not exists (select top 1 1 from DB.DBA.RDF_GRAPH_USER where RGU_GRAPH_IID = special_iid and RGU_USER_ID = __rdf_repl_uid() and bit_and (RGU_PERMISSIONS, 1)))
        {
          if (set_private)
            {
              for (select RGGM_MEMBER_IID from DB.DBA.RDF_GRAPH_GROUP_MEMBER repl
                where repl.RGGM_GROUP_IID = iri_to_id (UNAME'http://www.openlinksw.com/schemas/virtrdf#rdf_repl_graph_group')
                  and exists (select top 1 1 from DB.DBA.RDF_GRAPH_GROUP_MEMBER priv
                    where priv.RGGM_GROUP_IID = iri_to_id (UNAME'http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs')
                    and priv.RGGM_MEMBER_IID = repl.RGGM_MEMBER_IID )
                  and not exists (select top 1 1 from DB.DBA.RDF_GRAPH_USER where RGU_GRAPH_IID = repl.RGGM_MEMBER_IID and RGU_USER_ID = __rdf_repl_uid() and bit_and (RGU_PERMISSIONS, 1))
                  and not exists (select top 1 1 from DB.DBA.RDF_GRAPH_USER where RGU_GRAPH_IID = special_iid and RGU_USER_ID = __rdf_repl_uid() and bit_and (RGU_PERMISSIONS, 1)) ) do
                signal ('RDF99', 'Can not disable public read on private area while RDF replication is enabled and the replication account will loose its read permission on, e.g., <' || id_to_iri(RGGM_MEMBER_IID) || '>');
            }
          else
            {
              for (select RGGM_MEMBER_IID from DB.DBA.RDF_GRAPH_GROUP_MEMBER repl
                where repl.RGGM_GROUP_IID = iri_to_id (UNAME'http://www.openlinksw.com/schemas/virtrdf#rdf_repl_graph_group')
                  and not exists (select top 1 1 from DB.DBA.RDF_GRAPH_GROUP_MEMBER priv
                    where priv.RGGM_GROUP_IID = iri_to_id (UNAME'http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs')
                    and priv.RGGM_MEMBER_IID = repl.RGGM_MEMBER_IID )
                  and not exists (select top 1 1 from DB.DBA.RDF_GRAPH_USER where RGU_GRAPH_IID = repl.RGGM_MEMBER_IID and RGU_USER_ID = __rdf_repl_uid() and bit_and (RGU_PERMISSIONS, 1))
                  and not exists (select top 1 1 from DB.DBA.RDF_GRAPH_USER where RGU_GRAPH_IID = special_iid and RGU_USER_ID = __rdf_repl_uid() and bit_and (RGU_PERMISSIONS, 1)) ) do
                signal ('RDF99', 'Can not disable public read on "world" area while RDF replication is enabled and the replication account will loose its read permission on, e.g., <' || id_to_iri(RGGM_MEMBER_IID) || '>');
            }
        }
    }
  if (uname <> 'dba')
    {
      if (not (exists (select top 1 1 from DB.DBA.RDF_GRAPH_USER where RGU_GRAPH_IID = #i0 and RGU_USER_ID = 0)))
        DB.DBA.RDF_DEFAULT_USER_PERMS_SET ('dba', 1023);
      if (not (exists (select top 1 1 from DB.DBA.RDF_GRAPH_USER where RGU_GRAPH_IID = #i8192 and RGU_USER_ID = 0)))
        DB.DBA.RDF_DEFAULT_USER_PERMS_SET ('dba', 1023, 1);
    }
  insert replacing DB.DBA.RDF_GRAPH_USER (RGU_GRAPH_IID, RGU_USER_ID, RGU_PERMISSIONS)
  values (special_iid, uid, perms);
  -- dbg_obj_princ ('gs_hist.sql'); string_to_file ('gs_hist.sql', sprintf ('insert replacing DB.DBA.RDF_GRAPH_USER (RGU_GRAPH_IID, RGU_USER_ID, RGU_PERMISSIONS) values (%s, %d, %d);\n', cast (special_iid as varchar), uid, perms), -1);
  commit work;
  if (uname = 'nobody')
    affected_jso := ((select DB.DBA.VECTOR_AGG (sub."jso_key")
        from (sparql
          define input:storage ""
          prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
          select (str(?s)) as ?jso_key where {
            graph <http://www.openlinksw.com/schemas/virtrdf#> { { ?s a virtrdf:QuadMap } union { ?s a virtrdf:QuadMap } } } ) sub
            option (QUIETCAST) ));
  else
    affected_jso := vector (uname);
  commit work;
  DB.DBA.SECURITY_CL_EXEC_AND_LOG ('DB.DBA.RDF_DEFAULT_USER_PERMS_SET_MEMONLY (?,?,?,?,?,?)', vector (uname, uid, perms, special_iid, set_private, affected_jso));
}
;

create procedure DB.DBA.RDF_DEFAULT_USER_PERMS_DEL (in uname varchar, in set_private integer := 0)
{
  declare uid integer;
  declare special_iid IRI_ID;
  declare affected_jso any;
  -- dbg_obj_princ ('gs_hist.sql'); string_to_file ('gs_hist.sql', sprintf ('-- DB.DBA.RDF_DEFAULT_USER_PERMS_DEL (''%s'', %d);\n', uname, set_private), -1);
  if (uname in ('nobody', 'dba'))
    signal ('RDF99', sprintf ('Default permissions of "%s" can be changed but can not be deleted', uname));
  uid := (select U_ID from DB.DBA.SYS_USERS where U_NAME = uname);
  set isolation = 'serializable';
  commit work;
  if (uid is null)
    signal ('RDF99', sprintf ('No user "%s" found, can not delete its default permissions on RDF quad storage', uname));
  if (set_private)
    special_iid := #i8192;
  else
    special_iid := #i0;
  delete from DB.DBA.RDF_GRAPH_USER where RGU_GRAPH_IID = special_iid and RGU_USER_ID = uid;
  -- dbg_obj_princ ('gs_hist.sql'); string_to_file ('gs_hist.sql', sprintf ('delete from DB.DBA.RDF_GRAPH_USER where RGU_GRAPH_IID = %s and RGU_USER_ID = %d', cast (special_iid as varchar), uid), -1);
  commit work;
  affected_jso := vector (uname);
  commit work;
  DB.DBA.SECURITY_CL_EXEC_AND_LOG ('DB.DBA.RDF_DEFAULT_USER_PERMS_SET_MEMONLY (?,?,null,?,?,?)', vector (uname, uid, special_iid, set_private, affected_jso));
}
;

create procedure DB.DBA.RDF_GRAPH_USER_PERMS_SET_MEMONLY (in graph_iri varchar, in graph_iid IRI_ID, in uid integer, in perms integer)
{
  graph_iri := cast (graph_iri as varchar);
  DB.DBA.RDF_GRAPH_CACHE_IID (graph_iid);
  if (uid = http_nobody_uid())
    dict_put (__rdf_graph_public_perms_dict(), graph_iid, perms);
  else
    __rdf_graph_specific_perms_of_user (graph_iid, uid, perms);
  jso_mark_affected (graph_iri);
  log_text ('jso_mark_affected (?)', graph_iri);
}
;

create procedure DB.DBA.RDF_GRAPH_USER_PERMS_SET (in graph_iri varchar, in uname varchar, in perms integer)
{
  declare graph_iid IRI_ID;
  declare uid, graph_is_private, common_perms integer;
  declare special_iid IRI_ID;
  -- dbg_obj_princ ('gs_hist.sql'); string_to_file ('gs_hist.sql', sprintf ('-- DB.DBA.RDF_GRAPH_USER_PERMS_SET (''%s'', ''%s'', %d);\n', graph_iri, uname, perms), -1);
  if (perms is null)
    {
      RDF_GRAPH_USER_PERMS_DEL (graph_iri, uname);
      return;
    }
  graph_iid := iri_to_id (graph_iri);
  uid := ((select U_ID from DB.DBA.SYS_USERS where U_NAME = uname and (U_NAME='nobody' or (U_SQL_ENABLE and not U_ACCOUNT_DISABLED))));
  set isolation = 'serializable';
  commit work;
  if (uid is null)
    signal ('RDF99', sprintf ('No active SQL user "%s" found, can not set its permissions on graph <%s>', uname, graph_iri));
  graph_is_private := (select count (1) from DB.DBA.RDF_GRAPH_GROUP_MEMBER where
    RGGM_GROUP_IID = iri_to_id ('http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs') and
    RGGM_MEMBER_IID = graph_iid );
  if (graph_is_private)
    special_iid := #i8192;
  else
    special_iid := #i0;
  common_perms := coalesce (
    (select RGU_PERMISSIONS from DB.DBA.RDF_GRAPH_USER where RGU_GRAPH_IID = special_iid and RGU_USER_ID = uid),
    (select RGU_PERMISSIONS from DB.DBA.RDF_GRAPH_USER where RGU_GRAPH_IID = special_iid and RGU_USER_ID = http_nobody_uid()),
    15 );
  if (bit_and (bit_not (perms), common_perms))
    signal ('RDF99', sprintf ('Default permissions of user "%s" on RDF quad store are broader than new permissions on specific graph <%s>', uname, graph_iri));
  if (uname = 'nobody')
    {
      if (isstring (registry_get ('DB.DBA.RDF_REPL')) and not (bit_and (perms, 1))
        and exists (select top 1 1 from DB.DBA.RDF_GRAPH_GROUP_MEMBER
          where RGGM_GROUP_IID = iri_to_id (UNAME'http://www.openlinksw.com/schemas/virtrdf#rdf_repl_graph_group') and RGGM_MEMBER_IID = graph_iid)
        and not exists (select top 1 1 from DB.DBA.RDF_GRAPH_USER where RGU_GRAPH_IID = graph_iid and RGU_USER_ID = __rdf_repl_uid() and bit_and (RGU_PERMISSIONS, 1))
        and not exists (select top 1 1 from DB.DBA.RDF_GRAPH_USER where RGU_GRAPH_IID = special_iid and RGU_USER_ID = __rdf_repl_uid() and bit_and (RGU_PERMISSIONS, 1)) )
        signal ('RDF99', 'Can not disable public read access to <' || id_to_iri (graph_iid) || '> while it is included in RDF replication and the replication is enabled and the replication account will loose its read permission');
      jso_mark_affected (graph_iri);
      log_text ('jso_mark_affected (?)', graph_iri);
    }
  else
    {
      common_perms := coalesce (
        (select RGU_PERMISSIONS from DB.DBA.RDF_GRAPH_USER where RGU_GRAPH_IID = graph_iid and RGU_USER_ID = http_nobody_uid()),
        (select RGU_PERMISSIONS from DB.DBA.RDF_GRAPH_USER where RGU_GRAPH_IID = special_iid and RGU_USER_ID = http_nobody_uid()),
        15 );
      if (bit_and (bit_not (perms), common_perms))
        signal ('RDF99', sprintf ('Permissions of unauthenticated user are broader than new permissions of user "%s" on specific graph <%s>', uname, graph_iri));
      if ((uname = '__rdf_repl') and isstring (registry_get ('DB.DBA.RDF_REPL')) and not (bit_and (perms, 1)) and
            exists (select top 1 1 from DB.DBA.RDF_GRAPH_GROUP_MEMBER
              where RGGM_GROUP_IID = iri_to_id (UNAME'http://www.openlinksw.com/schemas/virtrdf#rdf_repl_graph_group') and RGGM_MEMBER_IID = graph_iid) )
        signal ('RDF99', 'Can not disable read access of __rdf_repl account to <' || id_to_iri (graph_iid) || '> while it is included in RDF replication and the replication is enabled');
    }
  if (not (exists (select top 1 1 from DB.DBA.RDF_GRAPH_USER where RGU_GRAPH_IID = #i0 and RGU_USER_ID = 0)))
    DB.DBA.RDF_DEFAULT_USER_PERMS_SET ('dba', 1023);
  if (not (exists (select top 1 1 from DB.DBA.RDF_GRAPH_USER where RGU_GRAPH_IID = #i8192 and RGU_USER_ID = 0)))
    DB.DBA.RDF_DEFAULT_USER_PERMS_SET ('dba', 1023, 1);
  insert replacing DB.DBA.RDF_GRAPH_USER (RGU_GRAPH_IID, RGU_USER_ID, RGU_PERMISSIONS)
  values (graph_iid, uid, perms);
  -- dbg_obj_princ ('gs_hist.sql'); string_to_file ('gs_hist.sql', sprintf ('insert replacing DB.DBA.RDF_GRAPH_USER (RGU_GRAPH_IID, RGU_USER_ID, RGU_PERMISSIONS) values (%s, %d, %d);\n', cast (graph_iid as varchar), uid, perms), -1);
  commit work;
  DB.DBA.SECURITY_CL_EXEC_AND_LOG ('DB.DBA.RDF_GRAPH_USER_PERMS_SET_MEMONLY (?,?,?,?)', vector (graph_iri, graph_iid, uid, perms));
}
;

create procedure DB.DBA.RDF_GRAPH_USER_PERMS_DEL_MEMONLY (in graph_iri varchar, in graph_iid IRI_ID, in uid integer)
{
  graph_iri := cast (graph_iri as varchar);
  DB.DBA.RDF_GRAPH_CACHE_IID (graph_iid);
  if (uid = http_nobody_uid())
    dict_remove (__rdf_graph_public_perms_dict(), graph_iid);
  else
    __rdf_graph_specific_perms_of_user (graph_iid, uid, -1);
  jso_mark_affected (graph_iri);
  log_text ('jso_mark_affected (?)', graph_iri);
}
;

create procedure DB.DBA.RDF_GRAPH_USER_PERMS_DEL (in graph_iri varchar, in uname varchar)
{
  declare graph_iid IRI_ID;
  declare uid integer;
  declare special_iid IRI_ID;
  -- dbg_obj_princ ('gs_hist.sql'); string_to_file ('gs_hist.sql', sprintf ('-- DB.DBA.RDF_GRAPH_USER_PERMS_SET (''%s'', ''%s'', %d);\n', graph_iri, uname, perms), -1);
  graph_iid := iri_to_id (graph_iri);
  uid := (select U_ID from DB.DBA.SYS_USERS where U_NAME = uname);
  set isolation = 'serializable';
  commit work;
  if (uid is null)
    signal ('RDF99', sprintf ('No user "%s" found, can not change its permissions on graph <%s>', uname, graph_iri));
  delete from DB.DBA.RDF_GRAPH_USER where RGU_GRAPH_IID = graph_iid and RGU_USER_ID = uid;
  -- dbg_obj_princ ('gs_hist.sql'); string_to_file ('gs_hist.sql', sprintf ('delete from DB.DBA.RDF_GRAPH_USER where RGU_GRAPH_IID = %s and RGU_USER_ID = %d;\n', cast (graph_iid as varchar), uid), -1);
  commit work;
  DB.DBA.SECURITY_CL_EXEC_AND_LOG ('DB.DBA.RDF_GRAPH_USER_PERMS_DEL_MEMONLY (?,?,?)', vector (graph_iri, graph_iid, uid));
}
;

create procedure DB.DBA.RDF_ALL_USER_PERMS_DEL (in uname varchar, in uid integer := null)
{
  declare special_iid IRI_ID;
  declare graphs any;
  declare graphs_count, graphs_ctr integer;
  -- dbg_obj_princ ('gs_hist.sql'); string_to_file ('gs_hist.sql', sprintf ('-- DB.DBA.RDF_ALL_USER_PERMS_DEL (''%s'', %s);\n', uname, case (isnotnull (uid)) when 0 then 'null' else cast (uid as varchar) end), -1);
  set isolation = 'serializable';
  commit work;
  if (uid is null)
    {
      uid := (select U_ID from DB.DBA.SYS_USERS where U_NAME = uname);
      if (uid is null)
        signal ('RDF99', sprintf ('No user "%s" found, can not change its permissions on RDF graphs', uname));
    }
  if (uname is null)
    uname := (select U_NAME from DB.DBA.SYS_USERS where U_ID = uid);
  if (uid = http_nobody_uid() or uid = 0)
    {
      graphs := (select DB.DBA.VECTOR_AGG (RGU_GRAPH_IID) from DB.DBA.RDF_GRAPH_USER where RGU_USER_ID = uid and not (RGU_GRAPH_IID in (#i0, #i8192)));
      delete from DB.DBA.RDF_GRAPH_USER where RGU_USER_ID = uid and not (RGU_GRAPH_IID in (#i0, #i8192));
    }
  else
    {
      graphs := (select DB.DBA.VECTOR_AGG (RGU_GRAPH_IID) from DB.DBA.RDF_GRAPH_USER where RGU_USER_ID = uid);
      delete from DB.DBA.RDF_GRAPH_USER where RGU_USER_ID = uid;
    }
  gvector_digit_sort (graphs, 1, 0, 1);
  -- dbg_obj_princ ('graphs=', graphs);
  graphs_count := length (graphs);
  for (graphs_ctr := graphs_count-1; graphs_ctr >= 0; graphs_ctr := graphs_ctr-1)
    {
      declare g_iid IR_ID;
      g_iid := graphs [graphs_ctr];
      if (g_iid = #i0 or g_iid = #i8192)
        {
          declare affected_jso any;
          if (uname is null)
            affected_jso := vector ();
          else
            affected_jso := vector (uname);
          DB.DBA.SECURITY_CL_EXEC_AND_LOG ('DB.DBA.RDF_DEFAULT_USER_PERMS_SET_MEMONLY (?,?,null,?,?,?)',
            vector (uname, uid, g_iid, case (g_iid) when #i8192 then 1 else 0 end, affected_jso));
        }
      else
        DB.DBA.SECURITY_CL_EXEC_AND_LOG ('DB.DBA.RDF_GRAPH_USER_PERMS_DEL_MEMONLY (?,?,?)', vector (id_to_iri_nosignal (g_iid), g_iid, uid));
    }
  commit work;
}
;

create function DB.DBA.RDF_GRAPH_GROUP_LIST_GET (in group_iri any, in extra_graphs any, in uid any, in gs_app_cbk varchar, in gs_app_uid varchar, in req_perms integer) returns any
{
  declare group_iid IRI_ID;
  declare world_perms, private_perms, common_perms, perms integer;
  declare perms_dict, full_list, filtered_list any;
  -- dbg_obj_princ ('DB.DBA.RDF_GRAPH_GROUP_LIST_GET (', group_iri, extra_graphs, uid, req_perms, ')');
  if (isstring (uid))
    uid := ((select U_ID from DB.DBA.SYS_USERS where U_NAME = uid and (U_NAME='nobody' or (U_SQL_ENABLE and not U_ACCOUNT_DISABLED))));
  if (uid is null)
    return vector ();
  perms_dict := __rdf_graph_default_perms_of_user_dict(0);
  world_perms := coalesce (
    dict_get (perms_dict, uid, NULL),
    dict_get (perms_dict, http_nobody_uid(), NULL),
    15 );
  perms_dict := __rdf_graph_default_perms_of_user_dict(1);
  private_perms := coalesce (
    dict_get (perms_dict, uid, NULL),
    dict_get (perms_dict, http_nobody_uid(), NULL),
    15 );
  if (gs_app_cbk is not null)
    {
      world_perms := bit_and (world_perms, call (gs_app_cbk)(#i0, gs_app_uid));
      private_perms := bit_and (private_perms, call (gs_app_cbk)(#i8192, gs_app_uid));
    }
  common_perms := bit_and (world_perms, private_perms);
  -- dbg_obj_princ ('DB.DBA.RDF_GRAPH_GROUP_LIST_GET: common_perms = ', common_perms);
  if (__tag (group_iri) = __tag of vector)
    {
      vectorbld_init (full_list);
      foreach (any g_iri in group_iri) do
        {
          group_iid := iri_to_id (g_iri);
          if (not bit_and (common_perms, 8))
            {
              perms := __rdf_graph_approx_perms (group_iid, uid);
              if (not bit_and (perms, 8))
                perms := coalesce (
                  (select RGU_PERMISSIONS from DB.DBA.RDF_GRAPH_USER where RGU_GRAPH_IID = group_iid and RGU_USER_ID = uid),
                  perms );
              if (gs_app_cbk is not null and bit_and (perms, 8))
                perms := bit_and (perms, call (gs_app_cbk)(group_iid, gs_app_uid));
              -- dbg_obj_princ ('DB.DBA.RDF_GRAPH_GROUP_LIST_GET: perms for list = ', perms);
            }
          else
            perms := common_perms;
          if (bit_and (perms, 8))
            {
              declare membs any;
              membs := dict_get (__rdf_graph_group_dict(), group_iid, null);
              if (membs is not null)
                {
                  if (isvector (membs))
                    vectorbld_concat_acc (full_list, membs);
                  else
                    vectorbld_concat_acc (full_list, dict_list_keys (membs, 0));
                }
            }
        }
      vectorbld_final (full_list);
    }
  else
    {
      group_iid := iri_to_id (group_iri);
      if (not bit_and (common_perms, 8))
        {
          perms := __rdf_graph_approx_perms (group_iid, uid);
          if (not bit_and (perms, 8))
            perms := coalesce (
              (select RGU_PERMISSIONS from DB.DBA.RDF_GRAPH_USER where RGU_GRAPH_IID = group_iid and RGU_USER_ID = uid),
              perms );
          if (gs_app_cbk is not null and bit_and (perms, 8))
            perms := bit_and (perms, call (gs_app_cbk)(group_iid, gs_app_uid));
          -- dbg_obj_princ ('DB.DBA.RDF_GRAPH_GROUP_LIST_GET: perms for list = ', perms);
        }
      else
        perms := common_perms;
      if (bit_and (perms, 8))
        {
          full_list := dict_get (__rdf_graph_group_dict(), group_iid, null);
          if (full_list is null)
            full_list := vector ();
          else if (not isvector (full_list))
            full_list := dict_list_keys (full_list, 0);
        }
      else
        full_list := vector ();
    }
  if (bit_and (common_perms, req_perms) = req_perms)
    {
      declare ctr integer;
      if (extra_graphs is null)
        return full_list;
      ctr := length (extra_graphs);
      while (ctr > 0)
        {
          ctr := ctr - 1;
          extra_graphs [ctr] := iri_to_id (extra_graphs[ctr]);
        }
      full_list := vector_concat (full_list, extra_graphs);
      gvector_digit_sort (full_list, 1, 0, 1);
      return full_list;
    }
  vectorbld_init (filtered_list);
  foreach (IRI_ID member_iid in full_list) do
    {
      perms := __rdf_graph_approx_perms (member_iid, uid);
      if (bit_and (perms, req_perms) <> req_perms)
        perms := coalesce (
          (select RGU_PERMISSIONS from DB.DBA.RDF_GRAPH_USER where RGU_GRAPH_IID = member_iid and RGU_USER_ID = uid),
          dict_get (__rdf_graph_public_perms_dict(), member_iid, NULL),
          perms );
      if (gs_app_cbk is not null and bit_and (perms, req_perms) = req_perms)
        perms := bit_and (perms, call (gs_app_cbk)(member_iid, gs_app_uid));
      -- dbg_obj_princ ('DB.DBA.RDF_GRAPH_GROUP_LIST_GET: perms for ', member_iid, ' = ', perms);
      if (bit_and (perms, req_perms) = req_perms)
        vectorbld_acc (filtered_list, member_iid);
    }
  foreach (any g in extra_graphs) do
    {
      declare g_iid IRI_ID;
      g_iid := iri_to_id (g);
      perms := coalesce (
        (select RGU_PERMISSIONS from DB.DBA.RDF_GRAPH_USER where RGU_GRAPH_IID = g_iid and RGU_USER_ID = uid),
        dict_get (__rdf_graph_public_perms_dict(), g_iid, NULL),
        common_perms );
      if (gs_app_cbk is not null and bit_and (perms, req_perms) = req_perms)
        perms := bit_and (perms, call (gs_app_cbk)(g_iid, gs_app_uid));
      -- dbg_obj_princ ('DB.DBA.RDF_GRAPH_GROUP_LIST_GET: perms for ', g_iid, ' = ', perms);
      if (bit_and (perms, req_perms) = req_perms)
        vectorbld_acc (filtered_list, g_iid);
    }
  vectorbld_final (filtered_list);
  gvector_digit_sort (filtered_list, 1, 0, 1);
  return filtered_list;
}
;

create procedure DB.DBA.RDF_GRAPH_SECURITY_AUDIT (in recovery integer)
{
  declare SEVERITY, GRAPH_IRI, USER_NAME, MESSAGE varchar;
  declare GRAPH_IID IRI_ID;
  declare USER_ID integer;
  result_names (SEVERITY, GRAPH_IID, GRAPH_IRI, USER_ID, USER_NAME, MESSAGE);
  declare mem_dict, mem_dict_inv, pg_mem_dict, mem_vec, mem_vec_inv, fake any;
  declare mem_ctr, mem_count, pg_count, err_bad_count, err_recoverable_count, err_recoverable_count_total, err_count_total integer;
  declare sparql_u_id integer;
  declare user_sparql_half_protects_from_extra_access integer;
  err_recoverable_count_total := 0; err_count_total := 0;
  sparql_u_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME='SPARQL');
  -- dbg_obj_princ ('Starting RDF Graph Security Audit, please be patient.');
  result ('', null, null, null, null, 'Inspecting caches of IRI_IDs of IRIs mentioned in security data...');
  err_bad_count := 0;
  err_recoverable_count := 0;
  mem_dict := __rdf_graph_iri2id_dict();
  mem_dict_inv := __rdf_graph_id2iri_dict();
  if (dict_size (mem_dict_inv) <> dict_size (mem_dict))
    {
      result ('ERROR', null, null, null, null,
        sprintf ('Cache of IRI_IDs of IRIs contains %d items, but cache of IRIs of IRI_IDs contains %d items, mismatch',
        dict_size (mem_dict_inv), dict_size (mem_dict) ) );
      err_recoverable_count := err_recoverable_count + 1;
    }
  mem_vec := dict_to_vector (mem_dict, 0);
  mem_vec_inv := dict_to_vector (mem_dict_inv, 0);
  mem_count := length (mem_vec);
  -- dbg_obj_princ ('Inspecting ', mem_count, ' IRIs cached in memory for structures related to security and graph groups...');
  for (mem_ctr := 0; mem_ctr < mem_count; mem_ctr := mem_ctr + 2)
    {
      declare iri varchar;
      declare iid IRI_ID;
      iri := mem_vec[mem_ctr];
      iid := mem_vec[mem_ctr+1];
      if ((__tag (iri) <> 217 /* __tag of UNAME */) or (__tag (iid) <> __tag of IRI_ID))
        {
          result ('ERROR', null, null, null, null,
            sprintf ('Unexpected datatypes: tag of IRI "%.300s" is %d, tag of IRI_ID "%.300s" is %d; should be %d and %d',
              cast (iri as varchar), __tag (iri),
              cast (iid as varchar), __tag (iid),
              217 /* __tag of UNAME */, __tag of IRI_ID ) );
          err_recoverable_count := err_recoverable_count + 1;
          if (recovery)
            dict_remove (mem_dict, iri);
        }
      else if (iri_to_id (iri) <> iid)
        {
          result ('ERROR', null, null, null, null,
            sprintf ('Cached IRI_IDs of IRI <%.300s> is %s, actual is %s, mismatch',
              cast (iri as varchar), cast (iid as varchar), cast (iri_to_id (iri) as varchar) ) );
          err_recoverable_count := err_recoverable_count + 1;
          if (recovery)
            {
              iid := iri_to_id_nosignal (iri);
              if (iid is not null)
                {
                  dict_put (mem_dict, iri, iid);
                  dict_put (mem_dict_inv, iid, iri);
                }
              else
                dict_remove (mem_dict, iri);
            }
        }
      if (0 = mod (mem_ctr, 100000))
        {
          -- dbg_obj_princ ('...', mem_ctr, '/', mem_count, ' IRIs passed forward check...');
          ;
        }
    }
  mem_count := length (mem_vec_inv);
  -- dbg_obj_princ ('Inspecting ', mem_count, ' IRI IDs cached in memory for structures related to security and graph groups');
  for (mem_ctr := 0; mem_ctr < mem_count; mem_ctr := mem_ctr + 2)
    {
      declare iid IRI_ID;
      declare iri varchar;
      iid := mem_vec_inv[mem_ctr];
      iri := mem_vec_inv[mem_ctr+1];
      if ((__tag (iid) <> __tag of IRI_ID) or (__tag (iri) <> 217 /* __tag of UNAME */))
        {
          result ('ERROR', null, null, null, null,
            sprintf ('Unexpected datatypes: tag of IRI_ID "%.300s" is %d, tag of IRI "%.300s" is %d; should be %d and %d',
              cast (iid as varchar), __tag (iid),
              cast (iri as varchar), __tag (iri),
              __tag of IRI_ID, 217 /* __tag of UNAME */ ) );
          err_recoverable_count := err_recoverable_count + 1;
          if (recovery)
            dict_remove (mem_dict_inv, iid);
        }
      else if (__uname (id_to_iri (iid)) <> iri)
        {
          result ('ERROR', null, null, null, null,
            sprintf ('Cached IRI of IRI_ID %s is <%.300s>, actual is <%.300s>, mismatch',
              cast (iid as varchar), cast (iri as varchar), cast (id_to_iri (iid) as varchar) ) );
          err_recoverable_count := err_recoverable_count + 1;
          if (recovery)
            {
              iri := id_to_iri_nosignal (iid);
              if (iri is not null)
                {
                  iri := __uname (iri);
                  dict_put (mem_dict_inv, iid, iri);
                  dict_put (mem_dict, iri, iid);
                }
              else
                dict_remove (mem_dict_inv, iid);
            }
        }
      if (0 = mod (mem_ctr, 100000))
        {
          -- dbg_obj_princ ('...', mem_ctr, '/', mem_count, ' IRI IDs passed reverse check');
          ;
        }
    }
  if (err_recoverable_count)
    {
      if (not recovery)
        {
          result ('FATAL', null, null, null, null,
            sprintf ('%d errors need urgent recovery, the rest of security audit has little sence while these errors persist',
              err_recoverable_count ) );
          return;
        }
      else
        {
          if (dict_size (mem_dict_inv) <> dict_size (mem_dict))
            {
              result ('FATAL', null, null, null, null,
                sprintf ('Cache of IRI_IDs of IRIs contains %d items, but cache of IRIs of IRI_IDs contains %d items, mismatch even after recovery',
                dict_size (mem_dict_inv), dict_size (mem_dict) ) );
              err_bad_count := err_bad_count + 1;
            }
        }
    }
  err_count_total := err_count_total + err_recoverable_count + err_bad_count;
  err_recoverable_count_total := err_recoverable_count_total + err_recoverable_count;
  -- dbg_obj_princ ('Inspecting completeness of IRI cache for graph groups...');
  result ('', null, null, null, null, 'Inspecting completeness of IRI cache for graph groups...');
  err_bad_count := 0;
  err_recoverable_count := 0;
  for (select RGG_IID from DB.DBA.RDF_GRAPH_GROUP where dict_get (__rdf_graph_id2iri_dict(), RGG_IID, null) is null
    union select RGGM_GROUP_IID from DB.DBA.RDF_GRAPH_GROUP_MEMBER where dict_get (__rdf_graph_id2iri_dict(), RGGM_GROUP_IID, null) is null
    for update ) do
    {
      if (id_to_iri_nosignal (RGG_IID) is null)
        result ('ERROR', RGG_IID, null, null, null,
          sprintf ('The IRI_ID %s of a graph group does not correspond to any IRI',
            cast (RGG_IID as varchar) ) );
      else
        result ('ERROR', RGG_IID, id_to_iri_nosignal (RGG_IID), null, null,
          sprintf ('The IRI <%.300s> of graph group IRI_ID %s is not cached',
            id_to_iri_nosignal (RGG_IID), cast (RGG_IID as varchar) ) );
      err_recoverable_count := err_recoverable_count + 1;
    }
  if (err_recoverable_count and recovery)
    {
      -- dbg_obj_princ ('Erasing invalid graph groups...');
      delete from DB.DBA.RDF_GRAPH_GROUP where id_to_iri_nosignal (RGG_IID) is null;
      -- dbg_obj_princ ('Erasing membership data about invalid graph groups...');
      delete from DB.DBA.RDF_GRAPH_GROUP_MEMBER where id_to_iri_nosignal (RGGM_GROUP_IID) is null;
      commit work;
      -- dbg_obj_princ ('Updating IRI caches for graph groups...');
      fake := (select
          count (dict_put (__rdf_graph_iri2id_dict(), __uname (id_to_canonicalized_iri (RGG_IID)), RGG_IID)) +
          count (dict_put (__rdf_graph_id2iri_dict(), RGG_IID, __uname (id_to_canonicalized_iri (RGG_IID))))
          from DB.DBA.RDF_GRAPH_GROUP );
      -- dbg_obj_princ ('Updating IRI caches for graph groups via memberships...');
      fake := (select
          count (dict_put (__rdf_graph_iri2id_dict(), __uname (id_to_canonicalized_iri (RGGM_GROUP_IID)), RGGM_GROUP_IID)) +
          count (dict_put (__rdf_graph_id2iri_dict(), RGGM_GROUP_IID, __uname (id_to_canonicalized_iri (RGGM_GROUP_IID))))
          from DB.DBA.RDF_GRAPH_GROUP_MEMBER );
      -- dbg_obj_princ ('Updating IRI caches for graph group members...');
      fake := (select
          count (dict_put (__rdf_graph_iri2id_dict(), __uname (id_to_canonicalized_iri (RGGM_MEMBER_IID)), RGGM_MEMBER_IID)) +
          count (dict_put (__rdf_graph_id2iri_dict(), RGGM_MEMBER_IID, __uname (id_to_canonicalized_iri (RGGM_MEMBER_IID))))
          from DB.DBA.RDF_GRAPH_GROUP_MEMBER );
    }
  err_count_total := err_count_total + err_recoverable_count + err_bad_count;
  err_recoverable_count_total := err_recoverable_count_total + err_recoverable_count;
  -- dbg_obj_princ ('Inspecting completeness of IRI cache for graph group members...');
  result ('', null, null, null, null, 'Inspecting completeness of IRI cache for graph group members...');
  err_bad_count := 0;
  err_recoverable_count := 0;
  for (select RGGM_MEMBER_IID, min (RGGM_GROUP_IID) as SAMPLE_GROUP_IID from DB.DBA.RDF_GRAPH_GROUP_MEMBER where dict_get (__rdf_graph_id2iri_dict(), RGGM_MEMBER_IID, null) is null group by RGGM_MEMBER_IID for update) do
    {
      if (id_to_iri_nosignal (RGGM_MEMBER_IID) is null)
        result ('ERROR', RGGM_MEMBER_IID, null, null, null,
          sprintf ('The IRI_ID %s of a member of a graph group <%.300s> does not correspond to any IRI',
            cast (RGGM_MEMBER_IID as varchar), id_to_iri_nosignal (SAMPLE_GROUP_IID) ) );
      else
        result ('ERROR', RGGM_MEMBER_IID, id_to_iri_nosignal (RGGM_MEMBER_IID), null, null,
          sprintf ('The IRI <%.300s> of IRI_ID %s of the member of a graph group <%.300s> is not cached',
            id_to_iri_nosignal (RGGM_MEMBER_IID), cast (RGGM_MEMBER_IID as varchar), id_to_iri_nosignal (SAMPLE_GROUP_IID) ) );
      err_recoverable_count := err_recoverable_count + 1;
    }
  if (err_recoverable_count and recovery)
    {
      delete from DB.DBA.RDF_GRAPH_GROUP_MEMBER where id_to_iri_nosignal (RGGM_MEMBER_IID) is null;
      commit work;
      fake := (select
          count (dict_put (__rdf_graph_iri2id_dict(), __uname (id_to_iri (RGGM_MEMBER_IID)), RGGM_MEMBER_IID)) +
          count (dict_put (__rdf_graph_id2iri_dict(), RGGM_MEMBER_IID, __uname (id_to_iri (RGGM_MEMBER_IID))))
          from DB.DBA.RDF_GRAPH_GROUP_MEMBER );
    }
  err_count_total := err_count_total + err_recoverable_count + err_bad_count;
  err_recoverable_count_total := err_recoverable_count_total + err_recoverable_count;

  -- dbg_obj_princ ('Check for mismatches between graph group IRIs and graph group IRI_IDs...');
  result ('', null, null, null, null, 'Check for mismatches between graph group IRIs and graph group IRI_IDs...');
  err_bad_count := 0;
  err_recoverable_count := 0;
  for (select RGG_IID, id_to_iri_nosignal (RGG_IID) as actual_iri, RGG_IRI from DB.DBA.RDF_GRAPH_GROUP where id_to_iri_nosignal (RGG_IID) <> __bft (RGG_IRI, 1)) do
    {
      if (actual_iri is not null)
        {
          result ('ERROR', RGG_IID, actual_iri, null, null,
            sprintf ('The IRI_ID %s of a graph group is the IRI_ID of <%.300s> IRI whereas the group declaration states it is supposed to be <%.300s>',
              cast (RGG_IID as varchar), actual_iri, RGG_IRI ) );
          err_recoverable_count := err_recoverable_count + 1;
        }
    }
  for (select RGG_IID, id_to_iri_nosignal (RGG_IID) as actual_iri, RGG_IRI from DB.DBA.RDF_GRAPH_GROUP
    where (id_to_iri_nosignal (RGG_IID) <> __bft (RGG_IRI, 1))
    and (id_to_iri_nosignal (RGG_IID) = 'http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs' or RGG_IRI = 'http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs') ) do
    {
      result ('FATAL', RGG_IID, actual_iri, null, null,
        sprintf ('The IRI_ID and IRI of a virtrdf:PrivateGraphs graph group does not match to each other, it means that some application has made a security hole. You may wish to disable any access to the database while the error is not fixed.',
          cast (RGG_IID as varchar), actual_iri, RGG_IRI ) );
      return;
    }
  -- dbg_obj_princ ('Check for memberships in nonexisting graph groups...');
  for (select distinct RGGM_GROUP_IID as new_group_iid, iri_to_id_nosignal (RGGM_GROUP_IID) as new_group_iri from DB.DBA.RDF_GRAPH_GROUP_MEMBER
    where not exists (select 1 from DB.DBA.RDF_GRAPH_GROUP where RGG_IID = RGGM_GROUP_IID) for update) do
    {
      if (new_group_iri is null)
        {
          result ('ERROR', new_group_iid, new_group_iri, null, null,
            sprintf ('Garbage in list of members of all groups: the group does not exists and group IRI ID is invalid') );
          err_recoverable_count := err_recoverable_count + 1;
          if (recovery)
            {
              delete from DB.DBA.RDF_GRAPH_GROUP_MEMBER where RGGM_GROUP_IID = new_group_iid;
              commit work;
            }
        }
      else if (exists (select 1 from DB.DBA.RDF_GRAPH_GROUP where RGG_IRI = new_group_iri))
        {
          result ('ERROR', new_group_iid, new_group_iri, null, null,
            sprintf ('Conflicting data in list of groups: the group does not exists, the group IRI is used in a corrupted group record') );
          err_recoverable_count := err_recoverable_count + 1;
          if (recovery)
            {
              delete from DB.DBA.RDF_GRAPH_GROUP_MEMBER where RGGM_GROUP_IID = new_group_iid;
              commit work;
            }
        }
      else
        {
          result ('ERROR', new_group_iid, new_group_iri, null, null,
            sprintf ('The record about graph group does not exist but there exists a list of members') );
          err_recoverable_count := err_recoverable_count + 1;
          if (recovery)
            {
              insert soft DB.DBA.RDF_GRAPH_GROUP (RGG_IID, RGG_IRI, RGG_MEMBER_PATTERN, RGG_COMMENT)
              values (new_group_iid, new_group_iri, NULL, sprintf ('Group created %s by DB.DBA.RDF_GRAPH_SECURITY_AUDIT()', cast (now() as varchar)));
              commit work;
            }
        }
    }
  err_count_total := err_count_total + err_recoverable_count + err_bad_count;
  err_recoverable_count_total := err_recoverable_count_total + err_recoverable_count;

  result ('', null, null, null, null, 'Inspecting caching of list of private graphs...');
  err_bad_count := 0;
  err_recoverable_count := 0;

  pg_mem_dict := mem_dict := __rdf_graph_group_of_privates_dict();
  pg_count := (select count (1) from DB.DBA.RDF_GRAPH_GROUP_MEMBER where RGGM_GROUP_IID = iri_to_id ('http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs'));
  -- dbg_obj_princ ('Inspecting caching of list of private graphs (', pg_mem_dict, ' items in memory, ', pg_count, ' items in the table) ...');
  if (dict_size (mem_dict) <> pg_count)
    {
      result ('ERROR', null, null, null, null,
        sprintf ('Cache of list of private graphs contains %d items, but virtrdf:PrivateGraphs group contains %d members, mismatch',
        dict_size (mem_dict), pg_count ) );
      err_recoverable_count := err_recoverable_count + 1;
    }
  mem_vec := dict_list_keys (mem_dict, 0);
  mem_count := length (mem_vec);
  for (mem_ctr := 0; mem_ctr < mem_count; mem_ctr := mem_ctr + 1)
    {
      declare mem_iid IRI_ID;
      mem_iid := mem_vec[mem_ctr];
      if (not exists (select 1 from DB.DBA.RDF_GRAPH_GROUP_MEMBER
        where RGGM_GROUP_IID = iri_to_id ('http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs')
        and RGGM_MEMBER_IID = mem_iid ) )
        {
          result ('ERROR', mem_iid, id_to_iri_nosignal (mem_iid), null, null,
            sprintf ('Cache of list of private graphs contains IRI_ID %s for graph IRI <%.300s> but virtrdf:PrivateGraphs group does not contain it',
              cast (mem_iid as varchar), id_to_iri_nosignal (mem_iid) ) );
          err_recoverable_count := err_recoverable_count + 1;
          if (recovery)
            {
              insert soft DB.DBA.RDF_GRAPH_GROUP_MEMBER (RGGM_GROUP_IID, RGGM_MEMBER_IID)
              values (iri_to_id ('http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs'), mem_iid);
              commit work;
            }
        }
      if (0 = mod (mem_ctr, 100000))
        {
          -- dbg_obj_princ ('...', mem_ctr, '/', mem_count, ' in-memory private graphs done...');
          ;
        }
    }
  -- dbg_obj_princ ('...reverse check...');
  for (select RGGM_MEMBER_IID from DB.DBA.RDF_GRAPH_GROUP_MEMBER
    where RGGM_GROUP_IID = iri_to_id ('http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs') ) do
    {
      if (not dict_get (mem_dict, RGGM_MEMBER_IID, 0))
        {
          result ('ERROR', RGGM_MEMBER_IID, id_to_iri_nosignal (RGGM_MEMBER_IID), null, null,
            sprintf ('Cache of list of private graphs does not contain IRI_ID %s of graph IRI <%.300s> but virtrdf:PrivateGraphs group contains it',
              cast (RGGM_MEMBER_IID as varchar), id_to_iri_nosignal (RGGM_MEMBER_IID) ) );
          err_recoverable_count := err_recoverable_count + 1;
          if (recovery)
            dict_put (mem_dict, RGGM_MEMBER_IID, 1);
        }
    }
  err_count_total := err_count_total + err_recoverable_count + err_bad_count;
  err_recoverable_count_total := err_recoverable_count_total + err_recoverable_count;

  -- dbg_obj_princ ('Inspecting permissions of users...');
  result ('', null, null, null, null, 'Inspecting permissions of users...');
  err_bad_count := 0;
  err_recoverable_count := 0;

  for (select RGU_USER_ID
    from (select distinct RGU_USER_ID from DB.DBA.RDF_GRAPH_USER rgu) dist_rgu
    where not exists (select 1 from DB.DBA.SYS_USERS where U_ID = RGU_USER_ID) ) do
    {
      result ('ERROR', NULL, NULL, RGU_USER_ID, null,
         sprintf ('Garbage in table DB.DBA.RDF_GRAPH_USER: permissions are specified for nonexisting user ID') );
      err_recoverable_count := err_recoverable_count + 1;
      if (recovery)
        DB.DBA.RDF_ALL_USER_PERMS_DEL (null, RGU_USER_ID);
    }
  for (select special.RGU_GRAPH_IID as s_g_iid, special.RGU_USER_ID as s_userid, special.RGU_PERMISSIONS as s_perms,
    common.RGU_GRAPH_IID as c_g_iid, common.RGU_USER_ID as c_userid, common.RGU_PERMISSIONS as c_p
    from DB.DBA.RDF_GRAPH_USER special, DB.DBA.RDF_GRAPH_USER common
    where (common.RGU_GRAPH_IID = special.RGU_GRAPH_IID
      and common.RGU_USER_ID = http_nobody_uid() and special.RGU_USER_ID <> http_nobody_uid()
      and bit_and (common.RGU_PERMISSIONS, special.RGU_PERMISSIONS) < common.RGU_PERMISSIONS )
    union select special.RGU_GRAPH_IID, special.RGU_USER_ID, special.RGU_PERMISSIONS,
    common.RGU_GRAPH_IID, common.RGU_USER_ID, common.RGU_PERMISSIONS
    from DB.DBA.RDF_GRAPH_USER special, DB.DBA.RDF_GRAPH_USER common
    where (common.RGU_GRAPH_IID = #i8192 and dict_get (pg_mem_dict, special.RGU_GRAPH_IID, 0)
      and common.RGU_USER_ID = http_nobody_uid() and special.RGU_USER_ID <> http_nobody_uid()
      and bit_and (common.RGU_PERMISSIONS, special.RGU_PERMISSIONS) < common.RGU_PERMISSIONS )
    union select special.RGU_GRAPH_IID, special.RGU_USER_ID, special.RGU_PERMISSIONS,
    common.RGU_GRAPH_IID, common.RGU_USER_ID, common.RGU_PERMISSIONS
    from DB.DBA.RDF_GRAPH_USER special, DB.DBA.RDF_GRAPH_USER common
    where (common.RGU_GRAPH_IID = #i0 and special.RGU_GRAPH_IID <> #i8192 and not dict_get (pg_mem_dict, special.RGU_GRAPH_IID, 0)
      and common.RGU_USER_ID = http_nobody_uid() and special.RGU_USER_ID <> http_nobody_uid()
      and bit_and (common.RGU_PERMISSIONS, special.RGU_PERMISSIONS) < common.RGU_PERMISSIONS )
    union select special.RGU_GRAPH_IID, special.RGU_USER_ID, special.RGU_PERMISSIONS,
    common.RGU_GRAPH_IID, common.RGU_USER_ID, common.RGU_PERMISSIONS
    from DB.DBA.RDF_GRAPH_USER special, DB.DBA.RDF_GRAPH_USER common
    where (common.RGU_GRAPH_IID = #i8192 and dict_get (pg_mem_dict, special.RGU_GRAPH_IID, 0)
      and common.RGU_USER_ID = special.RGU_USER_ID
      and bit_and (common.RGU_PERMISSIONS, special.RGU_PERMISSIONS) < common.RGU_PERMISSIONS )
    union select special.RGU_GRAPH_IID, special.RGU_USER_ID, special.RGU_PERMISSIONS,
    common.RGU_GRAPH_IID, common.RGU_USER_ID, common.RGU_PERMISSIONS
    from DB.DBA.RDF_GRAPH_USER special, DB.DBA.RDF_GRAPH_USER common
    where (common.RGU_GRAPH_IID = #i0 and special.RGU_GRAPH_IID <> #i8192 and not dict_get (pg_mem_dict, special.RGU_GRAPH_IID, 0)
      and common.RGU_USER_ID = special.RGU_USER_ID
      and bit_and (common.RGU_PERMISSIONS, special.RGU_PERMISSIONS) < common.RGU_PERMISSIONS )
    order by c_userid, c_g_iid ) do
    {
      declare c_g_iri_txt varchar;
      c_g_iri_txt := case (c_g_iid) when #i0 then 'default public graph' when #i8192 then 'default private graph' else sprintf ('graph <%.300s>', id_to_iri_nosignal (c_g_iid)) end;
      result ('ERROR', s_g_iid, id_to_iri_nosignal (s_g_iid), s_userid, (select U_NAME from DB.DBA.SYS_USERS where U_ID = s_userid),
         sprintf ('Specific permissions %x are smaller than %s permissions %x of user %s',
           s_perms, c_g_iri_txt, c_p, (select U_NAME from DB.DBA.SYS_USERS where U_ID = c_userid) ) );
      err_bad_count := err_bad_count + 1;
      if (s_g_iid = sparql_u_id)
        {
          user_sparql_half_protects_from_extra_access := 1;
          result ('ERROR', s_g_iid, id_to_iri_nosignal (s_g_iid), s_userid, (select U_NAME from DB.DBA.SYS_USERS where U_ID = s_userid),
            'Note that The fix of above error by removal of all SPARQL''s permissions can give more access rights to users of ill applications that re-used "SPARQL" account' );
        }
    }
  err_count_total := err_count_total + err_recoverable_count + err_bad_count;
  err_recoverable_count_total := err_recoverable_count_total + err_recoverable_count;
  -- dbg_obj_princ ('Inspecting SPARQL user...');
  result ('', null, null, null, null, 'Inspecting SPARQL user...');
  err_bad_count := 0;
  err_recoverable_count := 0;
  if (sparql_u_id is null)
    {
      result ('WARNING', null, null, sparql_u_id, 'SPARQL', 'The "SPARQL" user does not exist. It is not a security issue (no account --- no related leaks), just unusual');
    }
  else
    {
      if (exists (select 1 from DB.DBA.SYS_USERS where U_NAME='SPARQL' and not U_ACCOUNT_DISABLED))
        {
          result ('ERROR', null, null, sparql_u_id, 'SPARQL', 'The "SPARQL" user should be disabled. Applications should create separate accounts and grant SPARQL_SELECT etc., the account "SPARQL" is for system purposes only');
          err_recoverable_count := err_recoverable_count + 1;
          if (recovery)
            {
              update DB.DBA.SYS_USERS set U_ACCOUNT_DISABLED = 1 where U_NAME='SPARQL';
              commit work;
            }
        }
      if (not user_sparql_half_protects_from_extra_access)
        {
          declare user_sparql_has_perms integer;
          user_sparql_has_perms := 0;
          for (select RGU_GRAPH_IID from DB.DBA.RDF_GRAPH_USER where RGU_USER_ID = sparql_u_id) do
            {
              result ('ERROR', RGU_GRAPH_IID, id_to_iri_nosignal (RGU_GRAPH_IID), sparql_u_id, 'SPARQL', 'The "SPARQL" user has got some specific permissions. That''s strange and redundand, at best, it may also mislead somebody');
              err_recoverable_count := err_recoverable_count + 1;
              user_sparql_has_perms := 1;
            }
          if (user_sparql_has_perms and recovery)
            DB.DBA.RDF_ALL_USER_PERMS_DEL ('SPARQL');
        }
    }
  err_count_total := err_count_total + err_recoverable_count + err_bad_count;
  err_recoverable_count_total := err_recoverable_count_total + err_recoverable_count;

  if (0 = err_count_total)
    result ('', null, null, null, null,
      sprintf ('No errors found in RDF security', err_count_total) );
  else if (recovery)
    result ('', null, null, null, null,
      sprintf ('%d security errors were found, DB.DBA.RDF_GRAPH_SECURITY_AUDIT (0) will list errors that may remain unfixed', err_count_total) );
  else if (err_recoverable_count_total)
    result ('', null, null, null, null,
      sprintf ('%d security errors found, you may wish to run DB.DBA.RDF_GRAPH_SECURITY_AUDIT (1) to repair', err_count_total) );
  else
    result ('', null, null, null, null,
      sprintf ('%d security errors found and none of them can be repaired by DB.DBA.RDF_GRAPH_SECURITY_AUDIT (1)', err_count_total) );
  -- dbg_obj_princ ('Starting RDF Graph Security Audit complete, ', err_recoverable_count_total, '/', err_count_total, ' recoverable/total errors.');
}
;

-----
-- Loading default set of quad map metadata.

create procedure DB.DBA.SPARQL_RELOAD_QM_GRAPH ()
{
  declare ver varchar;
  declare inx int;
  ver := '2014-02-20 0001v7';
  if (USER <> 'dba')
    signal ('RDFXX', 'Only DBA can reload quad map metadata');
  if (not exists (sparql define input:storage "" ask where {
          graph <http://www.openlinksw.com/schemas/virtrdf#> {
              <http://www.openlinksw.com/sparql/virtrdf-data-formats.ttl>
                virtrdf:version ?:ver
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

virtrdf:DefaultServiceStorage
  rdf:type virtrdf:QuadStorage ;
  virtrdf:qsUserMaps virtrdf:DefaultServiceStorage-UserMaps ;
  virtrdf:qsDefaultMap virtrdf:DefaultServiceMap ;
  virtrdf:qsMatchingFlags virtrdf:SPART_QS_NO_IMPLICIT_USER_QM .
virtrdf:DefaultServiceStorage-UserMaps
  rdf:type virtrdf:array-of-QuadMap .

virtrdf:SyncToQuads
  rdf:type virtrdf:QuadStorage ;
  virtrdf:qsUserMaps virtrdf:SyncToQuads-UserMaps .
virtrdf:SyncToQuads-UserMaps
  rdf:type virtrdf:array-of-QuadMap .
      ';
      jso_sys_g_iid := iri_to_id (JSO_SYS_GRAPH ());
      dict1 := DB.DBA.RDF_TTL2HASH (txt1, '');
      dict2 := DB.DBA.RDF_TTL2HASH (txt2, '');
      lst1 := dict_list_keys (dict1, 1);
      lst2 := dict_list_keys (dict2, 1);
      sum_lst := vector_concat (lst1, lst2);
      inx := 0;
      foreach (any triple in sum_lst) do
        {
          if ((triple[1] = iri_to_id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#type')) and
            isiri_id (triple[2]) and (triple[2] = iri_to_id ('http://www.openlinksw.com/schemas/virtrdf#QuadMapFormat')))
            {
              -- dbg_obj_princ ('will delete whole ', id_to_iri (triple[0]));
              delete from DB.DBA.RDF_QUAD where G = jso_sys_g_iid and S = triple[0];
            }
          else
            delete from DB.DBA.RDF_QUAD where G = jso_sys_g_iid and S = triple[0] and P = triple[1];
	  if (
	      triple[0] = iri_to_id ('http://www.openlinksw.com/sparql/virtrdf-data-formats.ttl')
	      and
	      triple[1] = iri_to_id ('http://www.openlinksw.com/schemas/virtrdf#version')
	      and
	      triple[2] <> ver
	      )
	    {
	      log_message (sprintf ('RDF metadata version: %s', ver));
	      triple[2] := ver;
	      sum_lst[inx] := triple;
	    }
	  inx := inx + 1;
        }
      DB.DBA.RDF_INSERT_TRIPLES (jso_sys_g_iid, sum_lst);
      commit work;
      cl_exec ('checkpoint');
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
    'grant select on DB.DBA.RDF_PREFIX to SPARQL_SELECT',
    'grant all on DB.DBA.RDF_PREFIX to SPARQL_UPDATE',
    'grant select on DB.DBA.RDF_IRI to SPARQL_SELECT',
    'grant all on DB.DBA.RDF_IRI to SPARQL_UPDATE',
    'grant select on DB.DBA.RDF_OBJ to SPARQL_SELECT',
    'grant all on DB.DBA.RDF_OBJ to SPARQL_UPDATE',
    --'grant select on DB.DBA.RDF_FT to SPARQL_SELECT',
    --'grant all on DB.DBA.RDF_FT to SPARQL_UPDATE',
    'grant select on DB.DBA.RDF_DATATYPE to SPARQL_SELECT',
    'grant all on DB.DBA.RDF_DATATYPE to SPARQL_UPDATE',
    'grant select on DB.DBA.RDF_LANGUAGE to SPARQL_SELECT',
    'grant all on DB.DBA.RDF_LANGUAGE to SPARQL_UPDATE',
    'grant select on DB.DBA.SYS_SPARQL_HOST to SPARQL_SELECT',
    'grant all on DB.DBA.SYS_SPARQL_HOST to SPARQL_UPDATE',
    'grant select on DB.DBA.RDF_EXPLICITLY_CREATED_GRAPH to SPARQL_SELECT',
    'grant all on DB.DBA.RDF_EXPLICITLY_CREATED_GRAPH to SPARQL_UPDATE',
    'grant select on DB.DBA.SYS_IDONLY_EMPTY to SPARQL_SELECT',
    'grant select on DB.DBA.SYS_IDONLY_ONE to SPARQL_SELECT',
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
    'grant execute on DB.DBA.RDF_QNAME_OF_LONG_SAFE to SPARQL_SELECT', -- DEPRECATED
    'grant execute on DB.DBA.RDF_SQLVAL_OF_LONG to SPARQL_SELECT', -- DEPRECATED
    'grant execute on DB.DBA.RDF_BOOL_OF_LONG to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_DATATYPE_OF_LONG to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_DATATYPE_IRI_OF_LONG to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_LANGUAGE_OF_LONG to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_STRSQLVAL_OF_LONG to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_WIDESTRSQLVAL_OF_LONG to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_LONG_OF_SQLVAL to SPARQL_SELECT',
    'grant execute on DB.DBA.rdf_strdt_impl to SPARQL_SELECT',
    'grant execute on DB.DBA.rdf_strlang_impl to SPARQL_SELECT',
    'grant execute on DB.DBA.rdf_uuid_impl to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_QUAD_URI to SPARQL_UPDATE',
    'grant execute on DB.DBA.RDF_QUAD_URI_L to SPARQL_UPDATE',
    'grant execute on DB.DBA.RDF_QUAD_URI_L_TYPED to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP_EV_NEW_GRAPH to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP_EV_NEW_BLANK to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP_EV_GET_IID to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP_EV_TRIPLE to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP_EV_TRIPLE_L to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP_EV_TRIPLE_XLAT to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP_EV_TRIPLE_L_XLAT to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP_WITH_IRI_TRANSLATION to SPARQL_UPDATE',
    'grant execute on DB.DBA.RDF_TTL2HASH_EXEC_NEW_GRAPH to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_TTL2HASH_EXEC_NEW_BLANK to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_TTL2HASH_EXEC_GET_IID to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_TTL2HASH_EXEC_TRIPLE to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_TTL2HASH_EXEC_TRIPLE_L to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_TTL2HASH to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_LOAD_RDFXML to SPARQL_UPDATE',
    'grant execute on DB.DBA.RDF_RDFA11_FETCH_PROFILES to SPARQL_UPDATE',
    'grant execute on DB.DBA.RDF_LOAD_RDFA to SPARQL_UPDATE',
    'grant execute on DB.DBA.RDF_LOAD_RDFA_WITH_IRI_TRANSLATION to SPARQL_UPDATE',
    'grant execute on DB.DBA.RDF_LOAD_XHTML_MICRODATA to SPARQL_UPDATE',
    'grant execute on DB.DBA.RDF_RDFXML_TO_DICT to SPARQL_UPDATE',
    'grant execute on DB.DBA.RDF_LONG_TO_TTL to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_TRIPLES_TO_TTL to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_TRIPLES_TO_TRIG to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_TRIPLES_TO_NT to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_GRAPH_TO_TTL to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_TRIPLES_TO_RDF_XML_TEXT to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_TRIPLES_TO_TALIS_JSON to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_TRIPLES_TO_JSON_LD to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_TRIPLES_TO_CSV to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_TRIPLES_TO_TSV to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_TRIPLES_TO_RDFA_XHTML to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_TRIPLES_TO_HTML_UL to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_TRIPLES_TO_HTML_TR to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_TRIPLES_TO_HTML_MICRODATA to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_TRIPLES_TO_HTML_NICE_MICRODATA to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_TRIPLES_TO_HTML_NICE_TTL to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_TRIPLES_TO_JSON_MICRODATA to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_TRIPLES_TO_ATOM_XML_TEXT to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_TRIPLES_TO_ODATA_JSON to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_RESULT_SET_AS_TTL_INIT to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_RESULT_SET_AS_TTL_ACC to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_RESULT_SET_AS_TTL_FIN to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_RESULT_SET_AS_NT_INIT to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_RESULT_SET_AS_NT_ACC to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_RESULT_SET_AS_NT_FIN to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_RESULT_SET_AS_RDF_XML_INIT to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_RESULT_SET_AS_RDF_XML_ACC to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_RESULT_SET_AS_RDF_XML_FIN to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_RESULT_SET_AS_HTML_NICE_TTL to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_RESULT_SET_AS_JSON_INIT to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_RESULT_SET_AS_JSON_ACC to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_RESULT_SET_AS_JSON_FIN to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_RESULT_SET_AS_CSV_INIT to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_RESULT_SET_AS_CSV_ACC to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_RESULT_SET_AS_TSV_ACC to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_RESULT_SET_AS_CSV_FIN to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_RESULT_SET_AS_CXML_INIT to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_RESULT_SET_AS_CXML_ACC to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_RESULT_SET_AS_CXML_FIN to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_ATOM_XML to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_ODATA_JSON to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_TTL to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_NICE_TTL to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_NT to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_RDF_XML to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_TALIS_JSON to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_JSON_LD to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_HTML_MICRODATA to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_HTML_NICE_MICRODATA to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_HTML_NICE_TTL to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_JSON_MICRODATA to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_CSV to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_TSV to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_RDFA_XHTML to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_CXML to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_CXML_QRCODE to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_INSERT_TRIPLES to SPARQL_UPDATE',
    'grant execute on DB.DBA.RDF_DELETE_TRIPLES to SPARQL_UPDATE',
    'grant execute on DB.DBA.RDF_DELETE_TRIPLES_AGG to SPARQL_UPDATE',
    'grant execute on DB.DBA.RDF_MODIFY_TRIPLES to SPARQL_UPDATE',
    'grant execute on DB.DBA.RDF_INSERT_QUADS to SPARQL_UPDATE',
    'grant execute on DB.DBA.RDF_DELETE_QUADS to SPARQL_UPDATE',
    'grant execute on DB.DBA.SPARQL_INSERT_DICT_CONTENT to SPARQL_UPDATE',
    'grant execute on DB.DBA.SPARQL_INSERT_QUAD_DICT_CONTENT to SPARQL_UPDATE',
    'grant execute on DB.DBA.SPARQL_DELETE_DICT_CONTENT to SPARQL_UPDATE',
    'grant execute on DB.DBA.SPARQL_DELETE_QUAD_DICT_CONTENT to SPARQL_UPDATE',
    'grant execute on DB.DBA.SPARQL_MODIFY_BY_DICT_CONTENTS to SPARQL_UPDATE',
    'grant execute on DB.DBA.SPARQL_MODIFY_BY_QUAD_DICT_CONTENTS to SPARQL_UPDATE',
    'grant execute on DB.DBA.SPARUL_ADD to SPARQL_UPDATE',
    'grant execute on DB.DBA.SPARUL_CLEAR to SPARQL_UPDATE',
    'grant execute on DB.DBA.SPARUL_COPY to SPARQL_UPDATE',
    'grant execute on SPARUL_LOAD_SERVICE_DATA to SPARQL_SPONGE',
    'grant execute on DB.DBA.SPARUL_CREATE to SPARQL_UPDATE',
    'grant execute on DB.DBA.SPARUL_DROP to SPARQL_UPDATE',
    'grant execute on DB.DBA.SPARUL_LOAD to SPARQL_UPDATE',
    'grant execute on DB.DBA.SPARUL_LOAD_SERVICE_DATA to SPARQL_UPDATE',
    'grant execute on DB.DBA.SPARUL_MOVE to SPARQL_UPDATE',
    'grant execute on DB.DBA.SPARUL_RUN to SPARQL_UPDATE',
    'grant execute on DB.DBA.SPARQL_SELECT_KNOWN_GRAPHS to SPARQL_SELECT',
    'grant execute on DB.DBA.SPARQL_DESC_AGG_INIT to SPARQL_SELECT',
    'grant execute on DB.DBA.SPARQL_DESC_AGG_ACC to SPARQL_SELECT',
    'grant execute on DB.DBA.SPARQL_DESC_AGG_FIN to SPARQL_SELECT',
    'grant execute on DB.DBA.SPARQL_DESC_DICT to SPARQL_SELECT',
    'grant execute on DB.DBA.SPARQL_DESC_DICT_SPO to SPARQL_SELECT',
    'grant execute on DB.DBA.SPARQL_DESC_DICT_SPO_PHYSICAL to SPARQL_SELECT',
    'grant execute on DB.DBA.SPARQL_DESC_DICT_CBD to SPARQL_SELECT',
    'grant execute on DB.DBA.SPARQL_DESC_DICT_CBD_PHYSICAL to SPARQL_SELECT',
    'grant execute on DB.DBA.SPARQL_DESC_DICT_OBJCBD to SPARQL_SELECT',
    'grant execute on DB.DBA.SPARQL_DESC_DICT_OBJCBD_PHYSICAL to SPARQL_SELECT',
    'grant execute on DB.DBA.SPARQL_DESC_DICT_SCBD to SPARQL_SELECT',
    'grant execute on DB.DBA.SPARQL_DESC_DICT_SCBD_PHYSICAL to SPARQL_SELECT',
    'grant execute on DB.DBA.SPARQL_CONSTRUCT_INIT to SPARQL_SELECT',
    'grant execute on DB.DBA.SPARQL_CONSTRUCT_ACC to SPARQL_SELECT',
    'grant execute on DB.DBA.SPARQL_CONSTRUCT_FIN to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_TYPEMIN_OF_OBJ to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_TYPEMAX_OF_OBJ to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_IID_CMP to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_OBJ_CMP to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_LONG_CMP to SPARQL_SELECT',
    'grant execute on DB.DBA.TTLP_MT to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP_MT_LOCAL_FILE to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP_EV_TRIPLE_W to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP_EV_TRIPLE_L_W to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP_EV_NEW_GRAPH_A to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP_EV_TRIPLE_A to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP_EV_TRIPLE_L_A to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP_EV_REPORT_DEFAULT to SPARQL_UPDATE',
    'grant execute on DB.DBA.RDF_LOAD_RDFXML_MT to SPARQL_UPDATE',
    'grant execute on DB.DBA.RDF_LOAD_HTTP_RESPONSE to SPARQL_UPDATE',
    'grant execute on DB.DBA.RDF_FORGET_HTTP_RESPONSE to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP_EV_COMMIT to SPARQL_UPDATE',
    'grant execute on DB.DBA.RDF_PROC_COLS to "SPARQL"',
    'grant execute on DB.DBA.RDF_GRAPH_USER_PERMS_ACK to SPARQL_SELECT', -- DEPRECATED
    'grant execute on DB.DBA.RDF_GRAPH_USER_PERMS_ASSERT to SPARQL_SELECT', -- DEPRECATED
    'grant execute on DB.DBA.RL_FLUSH to SPARQL_UPDATE',
    'grant execute on DB.DBA.RDF_OBJ_ADD_KEYWORD_FOR_GRAPH to SPARQL_UPDATE',
    'grant execute on DB.DBA.RDF_GRAPH_GROUP_LIST_GET to SPARQL_SELECT',
    'grant execute on L_O_LOOK to SPARQL_SPONGE',
    'grant execute on RL_I2ID_NP to SPARQL_SPONGE',
    'grant execute on rl_i2id to SPARQL_SPONGE',
    'grant execute on DB.DBA.TTLP_RL_TRIPLE to SPARQL_UPDATE',
    'grant execute on rdf_rl_type_id to SPARQL_UPDATE',
    'grant execute on rdf_rl_lang_id to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP_RL_TRIPLE_L to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP_RL_NEW_GRAPH to SPARQL_UPDATE',
    'grant execute on rl_local_dpipe to SPARQL_UPDATE',
    'grant execute on rl_local_dpipe_gs to SPARQL_UPDATE',
    'grant execute on RL_FLUSH to SPARQL_UPDATE',
    'grant execute on rl_send to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP_RL_COMMIT to SPARQL_UPDATE',
    'grant execute on rl_send_gs to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP_RL_GS_TRIPLE to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP_RL_GS_TRIPLE_L to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP_RL_GS_NEW_GRAPH to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP_EV_NULL_IID to SPARQL_UPDATE',
    'grant execute on TTLP_V_GS to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP_V to SPARQL_UPDATE',
    'grant execute on DB.DBA.RDF_LOAD_RDFXML_V to SPARQL_UPDATE',
    'grant execute on ID_TO_IRI_VEC to SPARQL_UPDATE' );
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
    where "TABLE" = fix_identifier_case ('DB.DBA.RDF_OBJ_RO_FLAGS_WORDS')
    and "COLUMN" = fix_identifier_case ('VT_WORD') )
    and exists (select top 1 1 from DB.DBA.SYS_COLS
    where "TABLE" = fix_identifier_case ('DB.DBA.RDF_OBJ')
    and "COLUMN" = fix_identifier_case ('RO_FLAGS')
    and COL_DTP = 188 ) )
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

create procedure DB.DBA.RDF_QUAD_OUTLINE_ALL (in force integer := 0)
{
  declare c_main, c_pogs, c_op integer;
  declare c_main_tmp, c_pogs_tmp, c_op_tmp, old_mode integer;
  declare c_main_fixed, c_pogs_fixed, c_op_fixed integer;
  declare c_check char;

  if ((registry_get ('__rb_id_only_for_plain_ro_obj') = '1') and not force)
    return;
  if (0 = sys_stat ('db_exists') or not exists (select top 1 1 from DB.DBA.RDF_QUAD option (no cluster)))
    {
      registry_set ('__rb_id_only_for_plain_ro_obj', '1');
      return;
    }
  log_message ('This database may contain RDF data that could cause indexing problems on previous versions of the server.');
  log_message ('The content of the DB.DBA.RDF_QUAD table will be checked and an update may automatically be performed if');
  log_message ('such data is found.');
  log_message ('This check will take some time but is made only once.');

  if (not exists (select top 1 1 from DB.DBA.RDF_QUAD table option (index RDF_QUAD_OP, index_only) where rdf_box_migrate_after_06_02_3129 (O)))
    {
      log_message ('No need to update DB.DBA.RDF_QUAD.');
      registry_set ('__rb_id_only_for_plain_ro_obj', '1');
      exec ('checkpoint');
      return;
    }
  if (coalesce (virtuoso_ini_item_value ('SPARQL', 'RecoveryMode'), '0') > '0')
    {
      log_message ('Update skipped in recovery mode');
      return;
    }
  log_message ('An update is required.');
  c_check := coalesce (virtuoso_ini_item_value ('Parameters', 'AnalyzeFixQuadStore'), '0');
  if (coalesce (virtuoso_ini_item_value ('Parameters', 'LiteMode'), '0') <> '0') c_check := '1';
  if (c_check <> '1')
    {
	log_message ('');
	log_message ('NOTICE: Before Virtuoso can continue fixing the DB.DBA.RDF_QUAD table and its indexes');
 	log_message ('        the DB Administrator should check make sure that:');
	log_message ('');
	log_message ('         * there is a recent backup of the database');
	log_message ('         * there is enough free disk space available to complete this conversion');
	log_message ('         * the database can be offline for the duration of this conversion');
	log_message ('');
	log_message ('        Since the update can take a considerable amount of time on large databases');
	log_message ('        it is advisable to schedule this at an appropriate time.'); 
	log_message ('');
	log_message ('To continue the DBA must change the virtuoso.ini file and add the following flag:');
	log_message ('');
	log_message ('    [Parameters]');
	log_message ('    AnalyzeFixQuadStore = 1');
	log_message ('');
	log_message ('For additional information please contact OpenLink Support <support@openlinksw.com>');
	log_message ('This process will now exit.');
	raw_exit();
    }

  log_message ('Please be patient.');
  log_message ('The table DB.DBA.RDF_QUAD and two of its additional indexes will be patched now.');
  log_message ('In case of error during the operation, delete the transaction log before restarting the server.');
  exec ('checkpoint');
  declare exit handler for sqlstate '*'
    {
      log_message (sprintf ('Error %s: %s', __SQL_STATE, __SQL_MESSAGE));
      log_message ('Do not forget to delete the transaction log before restarting the server.');
      raw_exit ();
    };
  log_enable (2);
  log_message ('Phase 1 of 9: Gathering statistics ...');
  c_main := (select count (1) from DB.DBA.RDF_QUAD table option (index RDF_QUAD) option (no cluster));
  c_pogs := (select count (1) from DB.DBA.RDF_QUAD table option (index RDF_QUAD_POGS) option (no cluster));
  if (c_main <> c_pogs)
    log_message ('* Existing indexes are damaged, will try to recover...');
  c_op := (select count (1) from DB.DBA.RDF_QUAD table option (index RDF_QUAD_OP, index_only) option (no cluster));
  log_message (sprintf (' * Index sizes before the processing: %09d RDF_QUAD, %09d POGS, %09d OP', c_main, c_pogs, c_op));
  delete from DB.DBA.RDF_QUAD_RECOV_TMP table option (index RDF_QUAD_RECOV_TMP, no cluster) option (index RDF_QUAD_RECOV_TMP, no cluster);
  delete from DB.DBA.RDF_QUAD_RECOV_TMP table option (index RDF_QUAD_RECOV_TMP_POGS, no cluster) option (index RDF_QUAD_RECOV_TMP_POGS, no cluster);
  delete from DB.DBA.RDF_QUAD_RECOV_TMP table option (index RDF_QUAD_RECOV_TMP_OP, index_only, no cluster) option (index RDF_QUAD_RECOV_TMP_OP, no cluster);
  log_message ('Phase 2 of 9: Copying all quads to a temporary table ...');
  insert soft DB.DBA.RDF_QUAD_RECOV_TMP index RDF_QUAD_RECOV_TMP option (no cluster) (G1,S1,P1,O1) select G,S,P,O from DB.DBA.RDF_QUAD table option (index RDF_QUAD) option (no cluster);
  insert soft DB.DBA.RDF_QUAD_RECOV_TMP index RDF_QUAD_RECOV_TMP_POGS option (no cluster) (G1,S1,P1,O1) select G,S,P,O from DB.DBA.RDF_QUAD table option (index RDF_QUAD_POGS) option (no cluster);
  insert soft DB.DBA.RDF_QUAD_RECOV_TMP index RDF_QUAD_RECOV_TMP_OP option (index_only, no cluster) (P1,O1) select P,O from DB.DBA.RDF_QUAD table option (index RDF_QUAD_OP, index_only) option (no cluster);
  if (c_main <> c_pogs) -- cluster should not do that
    {
      log_message ('* Recovering additional data from existing indexes');
      if (c_main < c_pogs)
        insert soft DB.DBA.RDF_QUAD_RECOV_TMP option (no cluster) (G1,S1,P1,O1) select G,S,P,O from DB.DBA.RDF_QUAD table option (index RDF_QUAD_POGS) option (no cluster);
      if (c_pogs < c_main)
        insert soft DB.DBA.RDF_QUAD_RECOV_TMP option (no cluster) (G1,S1,P1,O1) select G,S,P,O from DB.DBA.RDF_QUAD table option (index RDF_QUAD) option (no cluster);
    }
  c_op_tmp := (select count (1) from DB.DBA.RDF_QUAD_RECOV_TMP table option (index RDF_QUAD_RECOV_TMP_OP, index_only) option (no cluster));
  log_message (sprintf ('* Index sizes of temporary table: %09d OP', c_op_tmp));
  if (c_op_tmp < c_op)
    log_message ('** Some data are lost or the corruption was strong before the processing.');

  log_message ('Phase 3 of 9: Cleaning the quad storage ...');
  delete from DB.DBA.RDF_QUAD table option (index RDF_QUAD, no cluster) option (index RDF_QUAD, no cluster);
  delete from DB.DBA.RDF_QUAD table option (index RDF_QUAD_POGS, no cluster) option (index RDF_QUAD_POGS, no cluster);
  delete from DB.DBA.RDF_QUAD table option (index RDF_QUAD_OP, index_only, no cluster) option (index RDF_QUAD_OP, no cluster);
  log_message ('Phase 4 of 9: Refilling the quad storage from the temporary table...');
  insert soft DB.DBA.RDF_QUAD index RDF_QUAD option (no cluster) (G,S,P,O) select G1,S1,P1,O1 from DB.DBA.RDF_QUAD_RECOV_TMP table option (index RDF_QUAD_RECOV_TMP) option (no cluster);
  insert soft DB.DBA.RDF_QUAD index RDF_QUAD_POGS option (no cluster) (G,S,P,O) select G1,S1,P1,O1 from DB.DBA.RDF_QUAD_RECOV_TMP table option (index RDF_QUAD_RECOV_TMP_POGS) option (no cluster);
  insert soft DB.DBA.RDF_QUAD index RDF_QUAD_OP option (index_only, no cluster) (P,O) select P1,O1 from DB.DBA.RDF_QUAD_RECOV_TMP table option (index RDF_QUAD_RECOV_TMP_OP, index_only) option (no cluster);

  log_message ('Phase 5 of 9: Cleaning the temporary table ...');
  delete from DB.DBA.RDF_QUAD_RECOV_TMP table option (index RDF_QUAD_RECOV_TMP, no cluster) option (index RDF_QUAD_RECOV_TMP, no cluster);
  delete from DB.DBA.RDF_QUAD_RECOV_TMP table option (index RDF_QUAD_RECOV_TMP_POGS, no cluster) option (index RDF_QUAD_RECOV_TMP_POGS, no cluster);
  delete from DB.DBA.RDF_QUAD_RECOV_TMP table option (index RDF_QUAD_RECOV_TMP_OP, index_only, no cluster) option (index RDF_QUAD_RECOV_TMP_OP, no cluster);

  log_message ('Phase 6 of 9: Gathering statistics again ...');
  c_main_fixed := (select count (1) from DB.DBA.RDF_QUAD table option (index RDF_QUAD) option (no cluster));
  c_pogs_fixed := (select count (1) from DB.DBA.RDF_QUAD table option (index RDF_QUAD_POGS) option (no cluster));
  c_op_fixed := (select count (1) from DB.DBA.RDF_QUAD table option (index RDF_QUAD_OP, index_only) option (no cluster));
  log_message (sprintf ('* Index sizes after the processing: %09d RDF_QUAD, %09d POGS, %09d OP', c_main_fixed, c_pogs_fixed, c_op_fixed));
  if ((__min (c_main_fixed, c_pogs_fixed) < __max (c_main, c_pogs)) or (c_op_fixed < c_op))
    log_message ('** Some data are lost or the corruption was strong before the processing.');

--select * from DB.DBA.RDF_QUAD a table option (index RDF_QUAD) where not exists (select top 1 1 from DB.DBA.RDF_QUAD b table option (index RDF_QUAD) where a.G=b.G and a.S=b.S and a.P=b.P and a.O=b.O);
--select * from DB.DBA.RDF_QUAD a table option (index RDF_QUAD_POGS) where not exists (select top 1 1 from DB.DBA.RDF_QUAD b table option (index RDF_QUAD_POGS) where a.G=b.G and a.S=b.S and a.P=b.P and a.O=b.O);
--select * from DB.DBA.RDF_QUAD a table option (index RDF_QUAD_POGS) where not exists (select top 1 1 from DB.DBA.RDF_QUAD b table option (index RDF_QUAD) where a.G=b.G and a.S=b.S and a.P=b.P and a.O=b.O);
--select * from DB.DBA.RDF_QUAD a table option (index RDF_QUAD) where not exists (select top 1 1 from DB.DBA.RDF_QUAD b table option (index RDF_QUAD_POGS) where a.G=b.G and a.S=b.S and a.P=b.P and a.O=b.O);
--select * from DB.DBA.RDF_QUAD a table option (index RDF_QUAD_OP, index_only) where not exists (select top 1 1 from DB.DBA.RDF_QUAD b table option (index RDF_QUAD_OP, index_only) where a.P=b.P and a.O=b.O);
--select * from DB.DBA.RDF_QUAD a table option (index RDF_QUAD_OP, index_only) where not exists (select top 1 1 from DB.DBA.RDF_QUAD b table option (index RDF_QUAD) where a.P=b.P and a.O=b.O);
--select * from DB.DBA.RDF_QUAD a table option (index RDF_QUAD) where not exists (select top 1 1 from DB.DBA.RDF_QUAD b table option (index RDF_QUAD_OP, index_only) where a.P=b.P and a.O=b.O);

  log_message ('Phase 7 of 9: integrity check (completeness of index RDF_QUAD_POGS of DB.DBA.RDF_QUAD) ...');
  if (exists (select top 1 1 from DB.DBA.RDF_QUAD a table option (index RDF_QUAD) where not exists (select 1 from DB.DBA.RDF_QUAD b table option (loop, index RDF_QUAD_POGS) where a.g = b.g and a.p = b.p and a.o = b.o and a.s = b.s)))
    log_message ('** IMPORTANT WARNING: not all rows of DB.DBA.RDF_QUAD are found in RDF_QUAD_POGS, data reloading is strictly recommended.');

  log_message ('Phase 8 of 9: integrity check (completeness of primary key of DB.DBA.RDF_QUAD) ...');
  if (exists (select top 1 1 from DB.DBA.RDF_QUAD a table option (index RDF_QUAD_POGS) where not exists (select 1 from DB.DBA.RDF_QUAD b table option (loop, index primary key) where a.g = b.g and a.p = b.p and a.o = b.o and a.s = b.s)))
    log_message ('** IMPORTANT WARNING: not all rows of DB.DBA.RDF_QUAD are found in RDF_QUAD_POGS, data reloading is strictly recommended.');

  log_message ('Phase 9 of 9: final checkpoint...');
  registry_set ('__rb_id_only_for_plain_ro_obj', '1');
  exec ('checkpoint');
  log_enable (old_mode, 1);
  log_message ('Update complete.');
}
;

--!AFTER
DB.DBA.RDF_QUAD_OUTLINE_ALL ()
;


create procedure DB.DBA.RDF_QUAD_LOAD_CACHE ()
{
  declare fake integer;
  fake := (select count (rdf_cache_id ('t', RDT_QNAME, RDT_TWOBYTE)) from DB.DBA.RDF_DATATYPE);
  fake := (select count (rdf_cache_id ('l', RL_ID, RL_TWOBYTE)) from DB.DBA.RDF_LANGUAGE);
  fake := (select
      count (dict_put (__rdf_graph_iri2id_dict(), __uname (id_to_iri (RGG_IID)), RGG_IID)) +
      count (dict_put (__rdf_graph_id2iri_dict(), RGG_IID, __uname (id_to_iri (RGG_IID))))
      from DB.DBA.RDF_GRAPH_GROUP );
  fake := (select
      count (dict_put (__rdf_graph_iri2id_dict(), __uname (id_to_iri (RGGM_GROUP_IID)), RGGM_GROUP_IID)) +
      count (dict_put (__rdf_graph_id2iri_dict(), RGGM_GROUP_IID, __uname (id_to_iri (RGGM_GROUP_IID))))
      from DB.DBA.RDF_GRAPH_GROUP_MEMBER );
  fake := (select
      count (dict_put (__rdf_graph_iri2id_dict(), __uname (id_to_iri (RGGM_MEMBER_IID)), RGGM_MEMBER_IID)) +
      count (dict_put (__rdf_graph_id2iri_dict(), RGGM_MEMBER_IID, __uname (id_to_iri (RGGM_MEMBER_IID))))
      from DB.DBA.RDF_GRAPH_GROUP_MEMBER );
  fake := (select
      count (dict_put (__rdf_graph_iri2id_dict(), __uname (id_to_iri (RGU_GRAPH_IID)), RGU_GRAPH_IID)) +
      count (dict_put (__rdf_graph_id2iri_dict(), RGU_GRAPH_IID, __uname (id_to_iri (RGU_GRAPH_IID))))
      from DB.DBA.RDF_GRAPH_USER where RGU_GRAPH_IID <> #i8192 and RGU_GRAPH_IID <> #i0 );
  for (select RGGM_GROUP_IID as group_iid, DB.DBA.VECTOR_AGG (RGGM_MEMBER_IID) as membs
         from DB.DBA.RDF_GRAPH_GROUP_MEMBER join DB.DBA.RDF_GRAPH_GROUP on (RGGM_GROUP_IID = RGG_IID) ) do
    {
      if (length (membs) < 1000)
        {
          gvector_digit_sort (membs, 1, 0, 1);
          dict_put (__rdf_graph_group_dict(), group_iid, membs);
        }
      else
        {
          declare new_membs any;
          new_membs := dict_new (length (membs));
          foreach (IRI_ID m in membs) do dict_put (new_membs, m, 1);
          dict_put (__rdf_graph_group_dict(), group_iid, new_membs);
        }
    }
  fake := (select count (dict_put (__rdf_graph_group_of_privates_dict(), RGGM_MEMBER_IID, 1))
    from DB.DBA.RDF_GRAPH_GROUP_MEMBER where RGGM_GROUP_IID = iri_to_id('http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs'));
  fake := (select count (dict_put (__rdf_graph_default_perms_of_user_dict(0), RGU_USER_ID, RGU_PERMISSIONS))
    from DB.DBA.RDF_GRAPH_USER where RGU_GRAPH_IID = #i0 );
  fake := (select count (dict_put (__rdf_graph_default_perms_of_user_dict(1), RGU_USER_ID, RGU_PERMISSIONS))
    from DB.DBA.RDF_GRAPH_USER where RGU_GRAPH_IID = #i8192 );
  fake := (select count (dict_put (__rdf_graph_public_perms_dict(), RGU_GRAPH_IID, RGU_PERMISSIONS))
    from DB.DBA.RDF_GRAPH_USER where RGU_USER_ID = http_nobody_uid () );
}
;

create procedure DB.DBA.RDF_QUAD_FT_UPGRADE ()
{
  declare stat, msg varchar;
  declare fake integer;
  if (USER <> 'dba')
    signal ('RDFXX', 'Only DBA can alter DB.DBA.RDF_QUAD schema or initialize RDF storage');

  if (sys_stat ('disable_rdf_init') = 1)
    return;
  if (0 = sys_stat ('db_exists') and 1 = sys_stat ('cl_run_local_only'))
    {
      -- v7 index is on by default
      DB.DBA.RDF_OBJ_FT_RULE_ADD ('', '', 'ALL');
    }
  RDF_QUAD_FT_INIT ();
  DB.DBA.RDF_QUAD_LOAD_CACHE ();
  delete from DB.DBA.RDF_GRAPH_USER where not exists (select 1 from DB.DBA.SYS_USERS where RGU_USER_ID = U_ID);
  if (row_count ())
    log_message ('Non-existing users are removed from graph security list');
  fake := (select count (__rdf_graph_specific_perms_of_user (RGU_GRAPH_IID, RGU_USER_ID, RGU_PERMISSIONS))
    from DB.DBA.RDF_GRAPH_USER where RGU_USER_ID <> http_nobody_uid () and not (RGU_GRAPH_IID in (#i0, #i8192)) );
  if (coalesce (virtuoso_ini_item_value ('SPARQL', 'RecoveryMode'), '0') > '0')
    {
      log_message ('Switching to RecoveryMode as set in [SPARQL] section of the configuration.');
      log_message ('For safety, the use of SPARQL_UPDATE role is restricted.');
      exec ('revoke "SPARQL_UPDATE" from "SPARQL"', stat, msg);
      return;
    }
  if (1 <> sys_stat ('cl_run_local_only'))
    goto final_qm_reload;
  if (244 = coalesce ((select COL_DTP from SYS_COLS where "TABLE" = 'DB.DBA.RDF_QUAD' and "COLUMN"='G'), 0))
    {
      __set_64bit_min_bnode_iri_id();
      sequence_set ('RDF_URL_IID_BLANK', iri_id_num (min_bnode_iri_id ()), 1);
    }
  --exec ('create index RO_DIGEST on DB.DBA.RDF_OBJ (RO_DIGEST)', stat, msg);
  if (exists (select top 1 1 from DB.DBA.SYS_COLS
    where "TABLE" = fix_identifier_case ('DB.DBA.RDF_OBJ_RO_FLAGS_WORDS')
    and "COLUMN" = fix_identifier_case ('VT_WORD') )
    and exists (select top 1 1 from DB.DBA.SYS_COLS
    where "TABLE" = fix_identifier_case ('DB.DBA.RDF_OBJ')
    and "COLUMN" = fix_identifier_case ('RO_FLAGS')
    and COL_DTP = 188 ) )
    goto final_qm_reload;
  exec ('DB.DBA.vt_create_text_index (
    fix_identifier_case (''DB.DBA.RDF_OBJ''),
    fix_identifier_case (''RO_FLAGS''),
    fix_identifier_case (''RO_ID''),
    0, 0, vector (), 1, ''*ini*'', ''UTF-8-QR'')', stat, msg);
  __vt_index ('DB.DBA.RDF_QUAD', 'RDF_QUAD_OP', 'O', 'O', 'DB.DBA.RDF_OBJ_RO_FLAGS_WORDS');
  exec ('DB.DBA.vt_batch_update (fix_identifier_case (''DB.DBA.RDF_OBJ''), ''ON'', 1)', stat, msg);

final_qm_reload:
  DB.DBA.SPARQL_RELOAD_QM_GRAPH ();
  insert soft rdf_datatype (rdt_iid, rdt_twobyte, rdt_qname) values
    (iri_to_id ('http://www.openlinksw.com/schemas/virtrdf#Geometry'), 256, 'http://www.openlinksw.com/schemas/virtrdf#Geometry');

  return;
}
;

--!AFTER
DB.DBA.RDF_QUAD_FT_UPGRADE ()
;

--#IF VER=5
--!AFTER __PROCEDURE__ DB.DBA.USER_CREATE !
--#ENDIF
DB.DBA.RDF_CREATE_SPARQL_ROLES ()
;

-- loading subclass inference ctxs


create procedure rdfs_pn (in is_class int)
{
  return case when is_class = 1 then iri_to_id ('http://www.w3.org/2000/01/rdf-schema#subClassOf')
  else  iri_to_id ('http://www.w3.org/2000/01/rdf-schema#subPropertyOf') end;
}
;


create procedure rdf_owl_sas_p (in gr iri_id, in name varchar, in super_c iri_id, in c iri_id, in visited any, inout supers any, in pos int)
{
  declare txt varchar;
  declare meta, cc, res any;
  txt := sprintf ('sparql define output:valmode "LONG"  define input:storage ""select ?o from <%s> where { <%s> <http://www.w3.org/2002/07/owl#sameAs> ?o }',
    id_to_iri(gr), id_to_iri(c) );
  exec (txt, null, null,  vector (), 0, meta, null, cc);
  while (0 = exec_next (cc, null, null, res))
    {
      rdfs_closure_1 (gr, name, super_c, res[0], 0, visited, supers, pos);
    }
  exec_close (cc);
  txt := sprintf ('sparql define output:valmode "LONG" define input:storage "" select ?s from <%s> where { ?s <http://www.w3.org/2002/07/owl#sameAs> <%s> }',
    id_to_iri(gr), id_to_iri(c) );
  exec (txt, null, null,  vector (), 0, meta, null, cc);
  while (0 = exec_next (cc, null, null, res))
    {
      rdfs_closure_1 (gr, name, super_c, res[0], 0, visited, supers, pos);
    }
  exec_close (cc);
}
;

create table DB.DBA.SYS_RDF_SCHEMA (RS_NAME VARCHAR , RS_URI VARCHAR, RS_G IRI_ID,
	PRIMARY KEY (RS_NAME, RS_URI))
alter index SYS_RDF_SCHEMA on DB.DBA.SYS_RDF_SCHEMA partition cluster replicated
;


create function rdfs_load_schema (in ri_name varchar, in gn varchar := null) returns integer
{
  declare gr iri_id;
  declare visited any;
  declare supers any;
  declare eq_c, eq_p iri_id;
  declare txt varchar;
  declare idx integer;
  declare cc, res, st, msg, meta  any;
  declare v any;
  declare inx int;
  declare from_text varchar;
  declare rules_count integer;
  from_text := '';
  res := 0;
  if (gn is null)
    {
      for (select RS_URI from DB.DBA.SYS_RDF_SCHEMA where RS_NAME=ri_name) do
        {
          from_text := from_text || sprintf (' from <%s>', RS_URI);
        }
    }
  else
    {
      if (isiri_id (gn))
        from_text := from_text || sprintf (' from <%s>', id_to_iri (gn));
      else
        from_text := from_text || sprintf (' from <%s>', gn);
    }
  if ('' = from_text)
    return 0;

  for (idx := 0; idx <= 4; idx := idx + 1)
    {
      txt := sprintf ('sparql define output:valmode "LONG" define input:storage "" select ?s ?o %s where { ?s <%s> ?o . filter (!isLITERAL (?o)) }',
        from_text, id_to_iri (case (idx) when 4 then rdf_sas_iri () else rdf_owl_iri (idx) end) );
      exec (txt, null, null, vector (), 0, meta, null, cc);
      while (0 = exec_next (cc, null, null, res))
        {
          declare s, o any;
          s := res[0]; o := res[1];
          if (idx = 4)
            {
              rdf_inf_dir (ri_name, s, o, 2);
              rdf_inf_dir (ri_name, s, o, 3);
              rules_count := rules_count + 2;
            }
          else
            {
              rdf_inf_dir (ri_name, o, s, idx);
              rules_count := rules_count + 1;
            }
        }
    }
  exec_close (cc);
-- Loading inverse functional properties
  txt := sprintf ('select DB.DBA.VECTOR_AGG (sub."s") from
  (sparql define output:valmode "LONG" define input:storage ""
    select distinct ?s %s
    where {
          { ?s a <http://www.w3.org/2002/07/owl#InverseFunctionalProperty> }
        union
          { ?s a <http://www.w3.org/2002/07/owl#FunctionalProperty> , <http://www.w3.org/2002/07/owl#SymmetricProperty> }
        union
          { ?s1 a <http://www.w3.org/2002/07/owl#FunctionalProperty> .
            ?s <http://www.w3.org/2002/07/owl#inverseOf> ?s1 }
        union
          { ?s1 a <http://www.w3.org/2002/07/owl#FunctionalProperty> .
            ?s1 <http://www.w3.org/2002/07/owl#inverseOf> ?s }
 }
    ) sub option (QUIETCAST)',
    from_text );
  exec (txt, null, null, vector (), 0, meta, res);
  v := res[0][0];
  if (0 < length (v))
    {
      txt := sprintf ('select DB.DBA.VECTOR_AGG (sub."s") from
      (sparql define output:valmode "LONG" define input:storage ""
        select ?s %s
        where {
            ?s <http://www.w3.org/2000/01/rdf-schema#subPropertyOf> ?sp option (TRANSITIVE, T_MIN 1) .
            filter (?sp = iri (?::0)) } ) sub option (QUIETCAST)',
        from_text );
      for (inx := length (v) - 1; 0 <= inx; inx := inx - 1)
        {
          declare meta1, res1 any;
          declare subprops any;
          exec (txt, null, null, vector (v[inx]), 0, meta1, res1);
          subprops := res1[0][0];
          foreach (IRI_ID subp in subprops) do
            {
              -- dbg_obj_princ ('Handled subproperty ', id_to_iri (subp), ' of ifp ', id_to_iri (v[inx]));
              if (0 >= position (subp, v))
                v := vector_concat (v, vector (subp));
            }
        }
      -- dbg_obj_princ ('known ifps are: '); foreach (IRI_ID i in v) do -- dbg_obj_princ (id_to_iri(i));
      gvector_digit_sort (v, 1, 0, 1);
      rdf_inf_set_ifp_list (ri_name, v); --- Note that this should be after all super/sub relations in order to fill ric_iid_to_rel_ifp
      rules_count := rules_count + length (v);
      txt := sprintf ('
        select vector_agg (sub."o") from
          (sparql define output:valmode "LONG" define input:storage ""
            select distinct ?o %s where {
                  { ?::0 <http://www.openlinksw.com/schemas/virtrdf#nullIFPValue> ?o .
                    filter (isREF (?o)) }
                union
                  {
                    ?subp <http://www.w3.org/2000/01/rdf-schema#subPropertyOf> ?superp option (TRANSITIVE, T_MIN 1) .
                    ?subp <http://www.openlinksw.com/schemas/virtrdf#nullIFPValue> ?o .
                    filter (?superp = ?::0)
                    filter (isREF (?o)) } } ) sub option (QUIETCAST)',
        from_text );
      for (inx := 0; inx < length (v); inx := inx + 1)
        {
          declare meta1, res1 any;
          declare excl any;
          exec (txt, null, null, vector (v[inx]), 0, meta1, res1);
          excl := meta1[0][0];
          if (length (excl) > 0)
            rdf_inf_set_ifp_exclude_list (ri_name, v[inx], excl);
        }
    }
-- Loading inverse functions
  txt := sprintf ('select DB.DBA.VECTOR_CONCAT_AGG (vector (sub."s", sub."o", sub."o", sub."s")) from
  (sparql define input:storage "" select ?s ?o %s where {
    ?s <http://www.w3.org/2002/07/owl#inverseOf> ?o .
    optional { ?o <http://www.w3.org/2002/07/owl#inverseOf> ?s2 . filter (?s2 = ?s ) }
    filter ((str (?s) <= str (?o)) || !BOUND(?s2)) }) sub option (QUIETCAST)',
    from_text );
  exec (txt, null, null, vector (), 0, meta, res);
  v := res[0][0];
  txt := sprintf ('select DB.DBA.VECTOR_CONCAT_AGG (vector (sub."s", sub."s")) from
  (sparql define input:storage "" select ?s %s where {
    ?s a <http://www.w3.org/2002/07/owl#SymmetricProperty> }) sub option (QUIETCAST)',
    from_text );
  exec (txt, null, null, vector (), 0, meta, res);
  v := vector_concat (v, res[0][0]);
  if (0 < length (v))
    {
      gvector_sort (v, 2, 0, 1);
      rdf_inf_set_inverses (ri_name, v);
      rules_count := rules_count + length (v);
    }
-- Loading bitmask properties of functions
  txt := sprintf ('select DB.DBA.VECTOR_CONCAT_AGG (vector (sub."s", 1)) from
  (sparql define input:storage "" select ?s %s where {
        { ?s a <http://www.w3.org/2002/07/owl#TransitiveProperty> }
      union
        { ?s <http://www.w3.org/2002/07/owl#inverseOf> [ a <http://www.w3.org/2002/07/owl#TransitiveProperty> ] }
      union
        { [ a <http://www.w3.org/2002/07/owl#TransitiveProperty> ] <http://www.w3.org/2002/07/owl#inverseOf> ?s }
    } ) sub option (QUIETCAST)',
    from_text );
  exec (txt, null, null, vector (), 0, meta, res);
  v := res[0][0];
  if (0 < length (v))
    {
      gvector_sort (v, 2, 0, 1);
      rdf_inf_set_prop_props (ri_name, v);
      rules_count := rules_count + length (v);
    }
  jso_mark_affected (ri_name);
  log_text ('jso_mark_affected (?)', ri_name);
--  if (not rules_count)
    rdf_inf_dir (ri_name, null, null, 0);
  return rules_count + 1;
}
;

create procedure rdf_schema_ld ()
{
  if (1 <> sys_stat ('cl_run_local_only'))
    return 0;
  return (select count (*) from (select distinct s.RS_NAME from DB.DBA.SYS_RDF_SCHEMA s) sub where 0 = rdfs_load_schema (sub.RS_NAME));
}
;

rdf_schema_ld ()
;


create function CL_RDF_INF_CHANGED_SRV (in name varchar) returns integer
{
  declare res integer;
  set isolation = 'committed';
  rdf_inf_clear (name);
  return case (rdfs_load_schema (name)) when 0 then 1 else 0 end;
  return res;
}
;

create procedure CL_RDF_INF_CHANGED (in name varchar)
{
  declare aq any;
  if (2 = sys_stat ('cl_run_local_only'))
    return;
  aq := async_queue (1, 4);
  aq_request (aq, 'DB.DBA.CL_RDF_INF_CHANGED_SRV', vector (name));
  aq_wait_all (aq);
}
;

create function rdfs_rule_set (in name varchar, in gn varchar, in remove int := 0) returns integer
{
  delete from DB.DBA.SYS_RDF_SCHEMA where RS_NAME = name and RS_URI = gn;
  if (not remove)
    {
      insert into DB.DBA.SYS_RDF_SCHEMA (RS_NAME, RS_URI) values (name, gn);
    }
  commit work;
  if (0 = sys_stat ('cl_run_local_only'))
    {
      DB.DBA.SECURITY_CL_EXEC_AND_LOG ('DB.DBA.CL_RDF_INF_CHANGED (?)', vector (name));
      return 1;
    }
  else
    {
      declare res integer;
      rdf_inf_clear (name);
      res := rdfs_load_schema (name);
      log_text ('db.dba.rdfs_load_schema (?)', name);
      return res;
    }
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
      item_value := virtuoso_ini_item_value ('SPARQL', item_name);
      http (sprintf ('<http://www.openlinksw.com/schemas/virtini#SPARQL> <http://www.openlinksw.com/schemas/virtini#%U> "%s" .\r\n',
	    item_name, item_value), tmp);
    }
  tmp := string_output_string (tmp);
  res_dict := DB.DBA.RDF_TTL2HASH (tmp, '');
  metas := vector (vector (vector ('res_dict', 242, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0)), 1);
  dta := vector (vector (res_dict));
}
;


--
-- Make geometries for geo:long, geo:lat pairs
--
create procedure num_or_null (in n any)
{
  declare exit handler for sqlstate '*'{ return null; };
  return cast (cast (n as decimal) as real);
}
;

create procedure GEO_FILL_SRV  (in arr any, in fill int)
{
  declare lat, lng, s, g, l any;
  declare inx int;
  log_enable (2, 1);
  declare geop iri_id_8;
  declare gs, ss, os any array;
  gs := make_array (fill, 'any');
  ss := make_array (fill, 'any');
  os := make_array (fill, 'any');
  geop := iri_to_id ('http://www.w3.org/2003/01/geo/wgs84_pos#geometry');
  for (inx := 0; inx < fill; inx := inx + 1)
    {
      l := aref_set_0 (arr, inx);
      gs[inx]  := aref_set_0 (l, 0);
      ss[inx] := aref_set_0 (l, 1);
      os[inx] := st_point (aref_set_0 (l, 2), aref_set_0 (l, 3));
    }
  for vectored (in g1 iri_id_8 := gs, in s1 iri_id_8 := ss, in o1 any array := os)
    {
      insert soft rdf_quad (g, s, p, o) values ("g1", "s1", geop, rdf_geo_add (rdf_box (o1, 256, 257, 0, 1)));
    }
}
;

create procedure rdf_geo_fill (in threads int := null, in batch int := 100000)
{
  declare arr, fill, aq, ctr any;
  if (threads is null) threads := sys_stat ('enable_qp');
  aq := async_queue (threads);
  arr := make_array (batch, 'any');
  fill := 0;
  ctr := 0;
  log_enable (2, 1);
  for select "s", "long", "lat", "g" from (sparql define output:valmode "LONG" select ?g ?s ?long ?lat where {
    graph ?g { ?s geo:long ?long . ?s geo:lat ?lat}}) f  do
    {
      declare lat2, long2 any;
      long2 := num_or_null (rdf_box_data ("long"));
      lat2 := num_or_null (rdf_box_data ("lat"));
      if (isnumeric (long2) and isnumeric (lat2))
	{
	  arr[fill] := vector ("g", "s", long2, lat2);
	  fill := fill + 1;
	  if (batch = fill)
	    {
	      aq_request (aq, 'DB.DBA.GEO_FILL_SRV', vector (arr, fill));
	      ctr := ctr + 1;
	      if (ctr > 100)
		{
		  commit work;
		  aq_wait_all (aq);
		  ctr := 0;
		}
	      arr := make_array (batch, 'any');
	      fill := 0;
	    }
	}
    }
  geo_fill_srv (arr, fill);
  commit work;
  aq_wait_all (aq);
}
;
