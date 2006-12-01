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
create bitmap index RDF_QUAD_PGOS on DB.DBA.RDF_QUAD (P, G, O, S)
;

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
  RO_LONG long varchar
)
create index RO_VAL on DB.DBA.RDF_OBJ (RO_VAL)
;

create table DB.DBA.RDF_DATATYPE (
  RDT_IID IRI_ID not null primary key,
  RDT_TWOBYTE integer not null unique,
  RDT_QNAME varchar )
;

create table DB.DBA.RDF_LANGUAGE (
  RL_ID varchar not null primary key,
  RL_TWOBYTE integer not null unique )
;

create table DB.DBA.SYS_SPARQL_HOST (
  SH_HOST	varchar not null primary key,
  SH_GRAPH_URI	varchar,
  SH_USER_URI	varchar )
;

sequence_set ('RDF_URL_IID_NAMED', 1000000, 1)
;

sequence_set ('RDF_PREF_SEQ', 1, 1)
;

sequence_set ('RDF_URL_IID_BLANK', 1000000000, 1)
;

sequence_set ('RDF_RO_ID', 1, 1)
;

sequence_set ('RDF_DATATYPE_TWOBYTE', 258, 1)
;

sequence_set ('RDF_LANGUAGE_TWOBYTE', 258, 1)
;

-- create text index on DB.DBA.RDF_OBJ (RO_VAL) with key RO_ID
-- ;

create procedure DB.DBA.RDF_GLOBAL_RESET ()
{
--  checkpoint;
  __atomic (1);
  iri_id_cache_flush ();
  delete from DB.DBA.RDF_QUAD;
  delete from DB.DBA.RDF_URL;
  delete from DB.DBA.RDF_IRI;
  delete from DB.DBA.RDF_PREFIX;
  delete from DB.DBA.RDF_OBJ;
  delete from DB.DBA.RDF_DATATYPE;
  delete from DB.DBA.RDF_LANGUAGE;
  sequence_set ('RDF_URL_IID_NAMED', 1000000, 0);
  sequence_set ('RDF_URL_IID_BLANK', 1000000000, 0);
  sequence_set ('RDF_PREF_SEQ', 1, 0);
  sequence_set ('RDF_RO_ID', 1, 0);
  sequence_set ('RDF_DATATYPE_TWOBYTE', 258, 0);
  sequence_set ('RDF_LANGUAGE_TWOBYTE', 258, 0);
  __atomic (0);
--  checkpoint;
  TTLP (
    cast ( XML_URI_GET (
        'http://www.openlinksw.com/sparql/virtrdf-data-formats.ttl', '' ) as varchar ),
    '', 'http://www.openlinksw.com/schemas/virtrdf#' );
  TTLP ('
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
  virtrdf:qsDefaultMap virtrdf:DefaultQuadMap .
virtrdf:DefaultQuadStorage-UserMaps
      rdf:type virtrdf:array-of-QuadMap .
  ', '', 'http://www.openlinksw.com/schemas/virtrdf#' );
  delete from SYS_HTTP_SPONGE where HS_PARSER = 'DB.DBA.RDF_LOAD_HTTP_RESPONSE';
--  checkpoint;
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
  if (193 = __tag (qname))
    qname := DB.DBA.RDF_STRSQLVAL_OF_LONG (qname);
  whenever sqlstate '*' goto retnull;
  return iri_to_id (qname, 1);
retnull:
  return null;
}
;

create function DB.DBA.RDF_QNAME_OF_IID (in iid IRI_ID) returns varchar
{
  if (iid >= #i1000000000)
    return sprintf ('nodeID://%d', iri_id_num (iid));
  return id_to_iri (iid);
}
;

create function DB.DBA.RDF_IID_OF_QNAME_SAFE (in qname varchar) returns IRI_ID
{
  whenever sqlstate '*' goto retnull;
  return iri_to_id (qname, 0);
retnull:
  return null;
}
;

create function DB.DBA.RDF_IID_OF_QNAME (in qname varchar) returns IRI_ID
{
  return iri_to_id (qname, 0);
}
;

create function DB.DBA.RDF_MAKE_GRAPH_IIDS_OF_QNAMES (in qnames any) returns any
{
  if (193 <> __tag (qnames))
    return vector ();
  declare res_acc any;
  vectorbld_init (res_acc);
  foreach (any qname in qnames) do
    {
          declare iid IRI_ID;
      whenever sqlstate '*' goto skip_acc;
      iid := iri_to_id (qname, 0);
          if (iid is not null)
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
      if (new_iid is NULL or new_iid >= #i1000000000)
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
  values (iid, res, DB.DBA.RDF_QNAME_OF_IID (iid));
  return res;
}
;

create function DB.DBA.RDF_TWOBYTE_OF_LANGUAGE (in id varchar) returns integer
{
  declare res integer;
  if (id is null)
    return 257;
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

create function DB.DBA.RDF_DATATYPE_OF_TAG (in t integer)
{
  if (t = 182)
    return UNAME'http://www.w3.org/2001/XMLSchema#string';
  if (t = 189)
    return UNAME'http://www.w3.org/2001/XMLSchema#integer';
  if (t = 211)
    return UNAME'http://www.w3.org/2001/XMLSchema#dateTime';
  if (t = 191)
    return UNAME'http://www.w3.org/2001/XMLSchema#double';
  if (t = 204) /* DB NULL */
    return NULL;
  signal ('RDFXX', sprintf ('Unsupported tag in DB.DBA.RDF_DATATYPE_OF_TAG(): %d', t));
}
;

-----
-- Conversions from and to _table fields_ in short representation

create function DB.DBA.RQ_LONG_OF_O (in o_col any) returns any
{
  declare t, l, len integer;
  if (not isstring (o_col))
    return o_col;
  l := 20;
  len := length (o_col);
  if (len = (l + 9))
    {
      declare v2 varchar;
      declare id int;
      id := o_col[l+3] + 256 * (o_col [l+4] + 256 * (o_col [l+5] + 256 * o_col [l+6]));
      v2 := (select case (isnull (RO_LONG)) when 0 then blob_to_string (RO_LONG) else RO_VAL end from DB.DBA.RDF_OBJ where RO_ID = id);
      if (v2 is null)
        signal ('RDFXX', sprintf ('Integrity violation in DB.DBA.RQ_LONG_OF_O, bad id %d', id));
      return vector (
        o_col[0] + 256 * (o_col[1]),
        v2,
        o_col[len-2] + 256 * (o_col[len-1]),
        id,
        o_col );
    }
  if ((len > (l + 5)) or (len < 5))
    signal ('RDFXX', sprintf ('Integrity violation in DB.DBA.RQ_LONG_OF_O, bad string "%s"', o_col));
  return vector (
    o_col[0] + 256 * (o_col[1]),
    subseq (o_col, 2, len-3),
    o_col[len-2] + 256 * (o_col[len-1]),
    0,
    o_col );
}
;

create function DB.DBA.RQ_SQLVAL_OF_O (in o_col any) returns any
{
  declare t, l, len integer;
  if (isiri_id (o_col))
    {
      declare res varchar;
      if (o_col >= #i1000000000)
        return sprintf ('nodeID://%d', iri_id_num (o_col));
      res := id_to_iri (o_col);
--      res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = o_col));
      if (res is null)
        signal ('RDFXX', 'Wrong iid in DB.DBA.RQ_SQLVAL_OF_O()');
      return res;
    }
  if (not isstring (o_col))
    return o_col;
  l := 20;
  len := length (o_col);
  if (len = (l + 9))
    {
      declare v2 varchar;
      declare id int;
      id := o_col[l+3] + 256 * (o_col [l+4] + 256 * (o_col [l+5] + 256 * o_col [l+6]));
      v2 := (select case (isnull (RO_LONG)) when 0 then blob_to_string (RO_LONG) else RO_VAL end from DB.DBA.RDF_OBJ where RO_ID = id);
      if (v2 is null)
        signal ('RDFXX', sprintf ('Integrity violation in DB.DBA.RQ_SQLVAL_OF_O, bad id %d', id));
      return v2;
    }
  if ((len > (l + 5)) or (len < 5))
    signal ('RDFXX', sprintf ('Integrity violation in DB.DBA.RQ_LONG_OF_O, bad string "%s"', o_col));
  return subseq (o_col, 2, len-3);
}
;

create function DB.DBA.RQ_BOOL_OF_O (in o_col any) returns any
{
  declare t, l, len integer;
  if (isiri_id (o_col))
    return NULL;
  if (isinteger (o_col))
    {
      if (o_col)
        return 1;
      return 0;
    }
  if (not isstring (o_col))
    {
      if (o_col is null)
        return null;
      return neq (o_col, 0.0);
    }
  l := 20;
  len := length (o_col);
  if (((len > (l + 5)) and (len <> (l + 9))) or (len < 5))
    signal ('RDFXX', sprintf ('Integrity violation in DB.DBA.RQ_BOOL_OF_O, bad string "%s"', o_col));

  declare twobyte integer;
  declare dtqname any;
  twobyte := o_col[0] + 256 * (o_col[1]);
  if (257 = twobyte)
    goto type_ok;
  whenever not found goto badtype;
  select RDT_QNAME into dtqname from DB.DBA.RDF_DATATYPE where RDT_TWOBYTE = twobyte;
  if (dtqname <> UNAME'http://www.w3.org/2001/XMLSchema#string')
    return null;

type_ok:
  return case (len) when 5 then 0 else 1 end;

badtype:
  signal ('RDFXX', sprintf ('Unknown datatype in DB.DBA.RQ_BOOL_OF_O, bad string "%s"', o_col));
}
;

create function DB.DBA.RQ_IID_OF_O (in shortobj any) returns IRI_ID
{
  if (not isiri_id (shortobj))
    return NULL;
  return shortobj;
}
;

create function DB.DBA.RQ_O_IS_LIT (in shortobj any) returns integer
{
  if (isiri_id (shortobj))
    return 0;
  return 1;
}
;

-----
-- Conversions from and to values in short representation that may be not field values (may perform more validation checks)

create function DB.DBA.RDF_MAKE_RO_ID_OF_STRING (in v varchar) returns integer
{
  declare llong, id int;
  declare tridgell varchar;
  llong := 1010;
  if (length (v) > llong)
    {
      tridgell := tridgell32 (v, 1);
      set isolation='committed';
      id := (select RO_ID from DB.DBA.RDF_OBJ where RO_VAL = tridgell and blob_to_string (RO_LONG) = v);
      if (id is null)
        {
          set isolation='serializable';
          declare id_cr cursor for select RO_ID from DB.DBA.RDF_OBJ where RO_VAL = tridgell and blob_to_string (RO_LONG) = v;
          open id_cr (exclusive);
          whenever not found goto new_id_for_long;
          fetch id_cr into id;
          return id;
new_id_for_long:
              id := sequence_next ('RDF_RO_ID');
              insert into DB.DBA.RDF_OBJ (RO_ID, RO_VAL, RO_LONG) values (id, tridgell, v);
            }
        }
  else
    {
      set isolation='committed';
      id := (select RO_ID from DB.DBA.RDF_OBJ where RO_VAL = v);
      if (id is null)
        {
          set isolation='serializable';
          declare id_cr cursor for select RO_ID from DB.DBA.RDF_OBJ where RO_VAL = v;
          open id_cr (exclusive);
          whenever not found goto new_id_for_short;
          fetch id_cr into id;
          return id;
new_id_for_short:
              id := sequence_next ('RDF_RO_ID');
              insert into DB.DBA.RDF_OBJ (RO_ID, RO_VAL) values (id, v);
            }
        }
  return id;
}
;

create function DB.DBA.RDF_FIND_RO_ID_OF_STRING (in v varchar) returns integer
{
  declare llong int;
  declare tridgell varchar;
  llong := 1010;
  if (length (v) > llong)
    {
      tridgell := tridgell32 (v, 1);
      return (select RO_ID from DB.DBA.RDF_OBJ where RO_VAL = tridgell and blob_to_string (RO_LONG) = v);
    }
  else
    {
      return (select RO_ID from DB.DBA.RDF_OBJ where RO_VAL = v);
    }
}
;

create function DB.DBA.RDF_MAKE_OBJ_OF_SQLVAL (in v any) returns any
{
  declare l, t int;
  t := __tag (v);
  if (not t in (126, 182, 217, 225, 230))
    return v;
  if (225 = t)
    v := charset_recode (v, '_WIDE_', 'UTF-8');
  else if (217 = t or 126 = t)
    v := cast (v as varchar);
  else if (230 = t)
    v := serialize_to_UTF8_xml (v);
  l := 20;
  if (length (v) > l)
    {
      declare v2 varchar;
      declare id int;
      id := DB.DBA.RDF_MAKE_RO_ID_OF_STRING (v);
      v2 := concat ('\001\001', subseq (v, 0, l), '\0ABCD\001\001');
      v2 [l+3] := bit_and (id, 255);
      v2 [l+4] := bit_and (bit_shift (id, -8), 255);
      v2 [l+5] := bit_and (bit_shift (id, -16), 255);
      v2 [l+6] := bit_and (bit_shift (id, -24), 255);
      return v2;
    }
  return concat ('\001\001', v, '\0\001\001');
}
;

create function DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL (in v any, in dt_iid IRI_ID, in lang varchar) returns any
{
  declare l, t, dt_twobyte, lang_twobyte int;
  declare dt_s, lang_s varchar;
  t := __tag (v);
  if (not t in (126, 182, 217, 225, 230))
    signal ('RDFXX', 'DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL() accepts only string representations of typed values');
  if (225 = t)
    v := charset_recode (v, '_WIDE_', 'UTF-8');
  else if (217 = t or 126 = t)
    v := cast (v as varchar);
  else if (230 = t)
    v := serialize_to_UTF8_xml (v);
  dt_s := '\001\001';
  if (dt_iid is not null)
    {
      dt_twobyte := DB.DBA.RDF_TWOBYTE_OF_DATATYPE (dt_iid);
      dt_s[0] := bit_and (dt_twobyte, 255);
      dt_s[1] := bit_and (bit_shift (dt_twobyte, -8), 255);
    }
  lang_s := '\001\001';
  if (lang is not null)
    {
      lang_twobyte := DB.DBA.RDF_TWOBYTE_OF_LANGUAGE (lang);
      lang_s[0] := bit_and (lang_twobyte, 255);
      lang_s[1] := bit_and (bit_shift (lang_twobyte, -8), 255);
    }
  l := 20;
  if (length (v) > l)
    {
      declare v2 varchar;
      declare id int;
      id := DB.DBA.RDF_MAKE_RO_ID_OF_STRING (v);
      v2 := concat (dt_s, subseq (v, 0, l), '\0ABCD', lang_s);
      v2 [l+3] := bit_and (id, 255);
      v2 [l+4] := bit_and (bit_shift (id, -8), 255);
      v2 [l+5] := bit_and (bit_shift (id, -16), 255);
      v2 [l+6] := bit_and (bit_shift (id, -24), 255);
      return v2;
    }
  return concat (dt_s, v, '\0', lang_s);
}
;

create function DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL_STRINGS (
  in o_val any, in o_type varchar, in o_lang varchar ) returns any
{
  if ('http://www.w3.org/2001/XMLSchema#boolean' = o_type)
    {
      if (('true' = o_val) or ('1' = o_val))
        return 1;
      else if (('false' = o_val) or ('0' = o_val))
        return 0;
      else signal ('RDFXX', 'Invalid notation of boolean literal');
    }
  if ('http://www.w3.org/2001/XMLSchema#dateTime' = o_type)
    return __xqf_str_parse ('dateTime', o_val);
  if ('http://www.w3.org/2001/XMLSchema#double' = o_type)
    return cast (o_val as double precision);
  if ('http://www.w3.org/2001/XMLSchema#float' = o_type)
    return cast (o_val as float);
  if ('http://www.w3.org/2001/XMLSchema#integer' = o_type)
    return cast (o_val as int);
  if (isstring(o_type) or isstring (o_lang))
    {
      return DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL (
        o_val,
        DB.DBA.RDF_MAKE_IID_OF_QNAME (o_type),
        o_lang );
    }
  return DB.DBA.RDF_MAKE_OBJ_OF_SQLVAL (o_val);
}
;

create function DB.DBA.RDF_LONG_OF_OBJ (in shortobj any) returns any
{
  declare t, l, len integer;
  if (not isstring (shortobj))
    return shortobj;
  l := 20;
  len := length (shortobj);
  if (len = (l + 9))
    {
      declare v2 varchar;
      declare id int;
      id := shortobj[l+3] + 256 * (shortobj [l+4] + 256 * (shortobj [l+5] + 256 * shortobj [l+6]));
      v2 := (select case (isnull (RO_LONG)) when 0 then blob_to_string (RO_LONG) else RO_VAL end from DB.DBA.RDF_OBJ where RO_ID = id);
      if (v2 is null)
        signal ('RDFXX', sprintf ('Integrity violation in DB.DBA.RQ_LONG_OF_OBJ, bad id %d', id));
      return vector (
        shortobj[0] + 256 * (shortobj[1]),
        v2,
        shortobj[len-2] + 256 * (shortobj[len-1]),
        id,
        shortobj );
    }
  if ((len > (l + 5)) or (len < 5))
    signal ('RDFXX', sprintf ('Integrity violation in DB.DBA.RQ_LONG_OF_OBJ, bad string "%s"', shortobj));
  return vector (
    shortobj[0] + 256 * (shortobj[1]),
    subseq (shortobj, 2, len-3),
    shortobj[len-2] + 256 * (shortobj[len-1]),
    0,
    shortobj );
}
;

create function DB.DBA.RDF_DATATYPE_OF_OBJ (in shortobj any) returns any
{
  declare l, len, twobyte integer;
  declare res any;
  if (not isstring (shortobj))
    {
      if (isiri_id (shortobj))
        return NULL;
      return DB.DBA.RDF_DATATYPE_OF_TAG (__tag (shortobj));
    }
  l := 20;
  len := length (shortobj);
  if (((len <> (l + 9)) and (len > (l + 5))) or (len < 5))
    signal ('RDFXX', sprintf ('Integrity violation in DB.DBA.RQ_DATATYPE_OF_OBJ, bad string "%s"', shortobj));
  twobyte := shortobj[0] + 256 * (shortobj[1]);
  if (257 = twobyte)
    return null;
  whenever not found goto badtype;
  select RDT_QNAME into res from DB.DBA.RDF_DATATYPE where RDT_TWOBYTE = twobyte;
  return res;

badtype:
  signal ('RDFXX', sprintf ('Unknown datatype in DB.DBA.RQ_DATATYPE_OF_OBJ, bad string "%s"', shortobj));
}
;

create function DB.DBA.RDF_LANGUAGE_OF_OBJ (in shortobj any) returns any
{
  declare l, len, twobyte integer;
  declare res varchar;
  if (not isstring (shortobj))
    return null;
  l := 20;
  len := length (shortobj);
  if (((len <> (l + 9)) and (len > (l + 5))) or (len < 5))
    signal ('RDFXX', sprintf ('Integrity violation in DB.DBA.RDF_LANGUAGE_OF_OBJ, bad string "%s"', shortobj));
  twobyte := shortobj[len-2] + 256 * (shortobj[len-1]);
  if (257 = twobyte)
    return null;
  whenever not found goto badtype;
  select RL_ID into res from DB.DBA.RDF_LANGUAGE where RL_TWOBYTE = twobyte;
  return res;

badtype:
  signal ('RDFXX', sprintf ('Unknown language in DB.DBA.RDF_LANGUAGE_OF_OBJ, bad string "%s"', shortobj));
}
;

create function DB.DBA.RDF_SQLVAL_OF_OBJ (in shortobj any) returns any
{
  declare t, l, len integer;
  if (isiri_id (shortobj))
    {
      if (shortobj >= #i1000000000)
        return sprintf ('nodeID://%d', iri_id_num (shortobj));
      else
        {
          declare res varchar;
            res := id_to_iri (shortobj);
--          res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = shortobj));
          if (res is null)
            signal ('RDFXX', 'Wrong iid in DB.DBA.RDF_SQLVAL_OF_OBJ()');
          return res;
        }
    }
  if (not isstring (shortobj))
    return shortobj;
  l := 20;
  len := length (shortobj);
  if (len = (l + 9))
    {
      declare v2 varchar;
      declare id int;
      id := shortobj[l+3] + 256 * (shortobj [l+4] + 256 * (shortobj [l+5] + 256 * shortobj [l+6]));
      v2 := (select case (isnull (RO_LONG)) when 0 then blob_to_string (RO_LONG) else RO_VAL end from DB.DBA.RDF_OBJ where RO_ID = id);
      if (v2 is null)
        signal ('RDFXX', sprintf ('Integrity violation in DB.DBA.RQ_SQLVAL_OF_O, bad id %d', id));
      return v2;
    }
  if ((len > (l + 5)) or (len < 5))
    signal ('RDFXX', sprintf ('Integrity violation in DB.DBA.RQ_LONG_OF_O, bad string "%s"', shortobj));
  return subseq (shortobj, 2, len-3);
}
;

create function DB.DBA.RDF_BOOL_OF_OBJ (in shortobj any) returns any
{
  declare t, l, len integer;
  if (shortobj is null)
    return null;
  if (isiri_id (shortobj))
    return null;
  if (isinteger (shortobj))
    {
      if (shortobj)
        return 1;
      return 0;
    }
  if (not isstring (shortobj))
    {
      if (shortobj is null)
        return null;
      return neq (shortobj, 0.0);
    }
  l := 20;
  len := length (shortobj);
  if (((len > (l + 5)) and (len <> (l + 9))) or (len < 5))
    signal ('RDFXX', sprintf ('Integrity violation in DB.DBA.RDF_BOOL_OF_OBJ, bad string "%s"', shortobj));

  declare twobyte integer;
  declare dtqname any;
  twobyte := shortobj[0] + 256 * (shortobj[1]);
  if (257 = twobyte)
    goto type_ok;
  whenever not found goto badtype;
  select RDT_QNAME into dtqname from DB.DBA.RDF_DATATYPE where RDT_TWOBYTE = twobyte;
  if (dtqname <> UNAME'http://www.w3.org/2001/XMLSchema#string')
    return null;

type_ok:
  return case (len) when 5 then 0 else 1 end;

badtype:
  signal ('RDFXX', sprintf ('Unknown datatype in DB.DBA.RDF_BOOL_OF_OBJ, bad string "%s"', shortobj));
}
;

create function DB.DBA.RDF_QNAME_OF_OBJ (in shortobj any) returns varchar
{
  if (isiri_id (shortobj))
    {
      if (shortobj >= #i1000000000)
        return sprintf ('nodeID://%d', iri_id_num (shortobj));
      else
        {
          declare res varchar;
            res := id_to_iri (shortobj);
--          res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = shortobj));
          if (res is null)
            signal ('RDFXX', 'Wrong iid in DB.DBA.RDF_QNAME_OF_OBJ()');
          return res;
        }
    }
  return NULL;
}
;

create function DB.DBA.RDF_STRSQLVAL_OF_OBJ (in shortobj any)
{
  declare t, l, len integer;
  if (isiri_id (shortobj))
    {
      declare res varchar;
      if (shortobj >= #i1000000000)
        return sprintf ('nodeID://%d', iri_id_num (shortobj));
        res := id_to_iri (shortobj);
--      res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = shortobj));
      if (res is null)
        signal ('RDFXX', 'Wrong iid in DB.DBA.RDF_STRSQLVAL_OF_OBJ()');
      return res;
    }
  if (not isstring (shortobj))
    {
      if (211 = __tag (shortobj))
        {
          declare vc varchar;
          vc := cast (shortobj as varchar); --!!!TBD: replace with proper serialization
          return replace (vc, ' ', 'T');
        }
      if (225 =  __tag (shortobj))
        return charset_recode (shortobj, '_WIDE_', 'UTF-8');
      return cast (shortobj as varchar);
    }
  l := 20;
  len := length (shortobj);
  if (len = (l + 9))
    {
      declare v2 varchar;
      declare id int;
      id := shortobj[l+3] + 256 * (shortobj [l+4] + 256 * (shortobj [l+5] + 256 * shortobj [l+6]));
      v2 := (select case (isnull (RO_LONG)) when 0 then blob_to_string (RO_LONG) else RO_VAL end from DB.DBA.RDF_OBJ where RO_ID = id);
      if (v2 is null)
        signal ('RDFXX', sprintf ('Integrity violation in DB.DBA.RDF_STRSQLVAL_OF_OBJ, bad id %d', id));
      return v2;
    }
  if ((len > (l + 5)) or (len < 5))
    signal ('RDFXX', sprintf ('Integrity violation in DB.DBA.RDF_STRSQLVAL_OF_OBJ, bad string "%s"', shortobj));
  return subseq (shortobj, 2, len-3);
}
;


create function DB.DBA.RDF_OBJ_OF_LONG (in longobj any) returns any
{
  if (193 <> __tag(longobj))
    return longobj;
  if (length (longobj) > 5)
    return call (longobj[5] || '_OBJ_OF_LONG')(longobj);
  else if ((length (longobj) = 5) and isstring (longobj[4]))
    return longobj[4];
  else
    {
      declare l, dt_twobyte, lang_twobyte int;
      declare v, dt_s, lang_s varchar;
      v := longobj[1];
      dt_s := '\001\001';
      if (257 <> longobj[0])
        {
          dt_twobyte := longobj[0];
          dt_s[0] := bit_and (dt_twobyte, 255);
          dt_s[1] := bit_and (bit_shift (dt_twobyte, -8), 255);
        }
      lang_s := '\001\001';
      if (257 <> longobj[2])
        {
          lang_twobyte := longobj[2];
          lang_s[0] := bit_and (lang_twobyte, 255);
          lang_s[1] := bit_and (bit_shift (lang_twobyte, -8), 255);
        }
      l := 20;
      if (length (v) > l)
        {
          declare v2 varchar;
          declare id int;
          id := DB.DBA.RDF_MAKE_RO_ID_OF_STRING (v);
          v2 := concat (dt_s, subseq (v, 0, l), '\0ABCD', lang_s);
          v2 [l+3] := bit_and (id, 255);
          v2 [l+4] := bit_and (bit_shift (id, -8), 255);
          v2 [l+5] := bit_and (bit_shift (id, -16), 255);
          v2 [l+6] := bit_and (bit_shift (id, -24), 255);
          return v2;
        }
      return concat (dt_s, v, '\0', lang_s);
    }
}
;

create function DB.DBA.RDF_OBJ_OF_SQLVAL (in v any) returns any
{
  declare l, t int;
  t := __tag (v);
  if (not t in (182, 217, 225))
    return v;
  if (225 = t)
    v := charset_recode (v, '_WIDE_', 'UTF-8');
  else if (217 = t)
    v := cast (v as varchar);
  l := 20;
  if (length (v) > l)
    {
      declare v2 varchar;
      declare id int;
      id := DB.DBA.RDF_FIND_RO_ID_OF_STRING (v);
      if (id is null)
        return null;
      v2 := concat ('\001\001', subseq (v, 0, l), '\0ABCD\001\001');
      v2 [l+3] := bit_and (id, 255);
      v2 [l+4] := bit_and (bit_shift (id, -8), 255);
      v2 [l+5] := bit_and (bit_shift (id, -16), 255);
      v2 [l+6] := bit_and (bit_shift (id, -24), 255);
      return v2;
    }
  return concat ('\001\001', v, '\0\001\001');
}
;

-----
-- Functions for long object representation.

create function DB.DBA.RDF_MAKE_LONG_OF_SQLVAL (in v any) returns any
{
  declare l, t int;
  t := __tag (v);
  if (not t in (126, 182, 217, 225, 230))
    return v;
  if (225 = t)
    v := charset_recode (v, '_WIDE_', 'UTF-8');
  else if (217 = t or 126 = t)
    v := cast (v as varchar);
  else if (230 = t)
    v := serialize_to_UTF8_xml (v);
  l := 20;
  if (length (v) > l)
    {
      declare v2 varchar;
      declare id int;
      id := DB.DBA.RDF_MAKE_RO_ID_OF_STRING (v);
      v2 := concat ('\001\001', subseq (v, 0, l), '\0ABCD\001\001');
      v2 [l+3] := bit_and (id, 255);
      v2 [l+4] := bit_and (bit_shift (id, -8), 255);
      v2 [l+5] := bit_and (bit_shift (id, -16), 255);
      v2 [l+6] := bit_and (bit_shift (id, -24), 255);
      return vector (257, v, 257, id, v2);
    }
  return vector (257, v, 257, 0, concat ('\001\001', v, '\0\001\001'));
}
;


create function DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL (in v any, in dt_iid IRI_ID, in lang varchar) returns any
{
  declare l, t, dt_twobyte, lang_twobyte int;
  declare dt_s, lang_s varchar;
  t := __tag (v);
  if (not t in (182, 217, 225, 230))
    signal ('RDFXX', 'DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL() accepts only string representations of typed values');
  if (225 = t)
    v := charset_recode (v, '_WIDE_', 'UTF-8');
  else if (217 = t)
    v := cast (v as varchar);
  else if (230 = t)
    v := serialize_to_UTF8_xml (v);
  dt_s := '\001\001';
  if (dt_iid is not null)
    {
      dt_twobyte := DB.DBA.RDF_TWOBYTE_OF_DATATYPE (dt_iid);
      dt_s[0] := bit_and (dt_twobyte, 255);
      dt_s[1] := bit_and (bit_shift (dt_twobyte, -8), 255);
    }
  else
    dt_twobyte := 257;
  lang_s := '\001\001';
  if (lang is not null)
    {
      lang_twobyte := DB.DBA.RDF_TWOBYTE_OF_LANGUAGE (lang);
      lang_s[0] := bit_and (lang_twobyte, 255);
      lang_s[1] := bit_and (bit_shift (lang_twobyte, -8), 255);
    }
  else
    lang_twobyte := 257;
  l := 20;
  if (length (v) > l)
    {
      declare v2 varchar;
      declare id int;
      id := DB.DBA.RDF_MAKE_RO_ID_OF_STRING (v);
      v2 := concat (dt_s, subseq (v, 0, l), '\0ABCD', lang_s);
      v2 [l+3] := bit_and (id, 255);
      v2 [l+4] := bit_and (bit_shift (id, -8), 255);
      v2 [l+5] := bit_and (bit_shift (id, -16), 255);
      v2 [l+6] := bit_and (bit_shift (id, -24), 255);
      return vector (dt_twobyte, v, lang_twobyte, id, v2);
    }
  return vector (dt_twobyte, v, lang_twobyte, 0, concat (dt_s, v, '\0', lang_s));
}
;

create function DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL_STRINGS (
  in o_val any, in o_type varchar, in o_lang varchar ) returns any
{
  if ('http://www.w3.org/2001/XMLSchema#boolean' = o_type)
    {
      if (('true' = o_val) or ('1' = o_val))
        return 1;
      else if (('false' = o_val) or ('0' = o_val))
        return 0;
      else signal ('RDFXX', 'Invalid notation of boolean literal');
    }
  if ('http://www.w3.org/2001/XMLSchema#dateTime' = o_type)
    return __xqf_str_parse ('dateTime', o_val);
  if ('http://www.w3.org/2001/XMLSchema#double' = o_type)
    return cast (o_val as double precision);
  if ('http://www.w3.org/2001/XMLSchema#float' = o_type)
    return cast (o_val as float);
  if ('http://www.w3.org/2001/XMLSchema#integer' = o_type)
    return cast (o_val as int);
  if (isstring(o_type) or isstring (o_lang))
    {
      return DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL (
        o_val,
        DB.DBA.RDF_MAKE_IID_OF_QNAME (o_type),
        o_lang );
    }
  return DB.DBA.RDF_MAKE_LONG_OF_SQLVAL (o_val);
}
;

create function DB.DBA.RDF_SQLVAL_OF_LONG (in longobj any) returns any
{
  --dbg_obj_princ ('DB.DBA.RDF_SQLVAL_OF_LONG (', longobj, ', tag ', __tag (longobj));
  if (isiri_id (longobj))
    {
      if (longobj >= #i1000000000)
        return sprintf ('nodeID://%d', iri_id_num (longobj));
      else
        {
          declare res varchar;
          res := id_to_iri (longobj);
--          res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = longobj));
          if (res is null)
            signal ('RDFXX', 'Wrong iid in DB.DBA.RDF_SQLVAL_OF_LONG()');
          return res;
        }
    }
  if (193 = __tag (longobj))
    {
      declare v2 varchar;
      if (isstring (longobj[1]))
        return longobj[1];
      if (length (longobj) > 5)
        return call (longobj[5] || '_SQLVAL_OF_LONG')(longobj);
      v2 := (select case (isnull (RO_LONG)) when 0 then blob_to_string (RO_LONG) else RO_VAL end from DB.DBA.RDF_OBJ where RO_ID = longobj[3]);
      if (v2 is null)
        signal ('RDFXX', sprintf ('Integrity violation in DB.DBA.RDF_SQLVAL_OF_LONG, bad id %d', longobj[3]));
      return v2;
    }
  return longobj;
}
;

create function DB.DBA.RDF_BOOL_OF_LONG (in longobj any) returns any
{
  if (longobj is null)
    return null;
  if (isiri_id (longobj))
    return NULL;
  if (isinteger (longobj))
    {
      if (longobj)
        return 1;
      return 0;
    }
  if (193 <> __tag (longobj))
    return neq (longobj, 0.0);
  declare dtqname any;
  if (257 = longobj[0])
    goto type_ok;
  whenever not found goto badtype;
  select RDT_QNAME into dtqname from DB.DBA.RDF_DATATYPE where RDT_TWOBYTE = longobj[0];
  if (dtqname <> UNAME'http://www.w3.org/2001/XMLSchema#string')
    return null;

type_ok:
  return case (length (longobj[1])) when 0 then 0 else 1 end;

badtype:
  signal ('RDFXX', sprintf ('Unknown datatype in DB.DBA.RDF_BOOL_OF_LONG (code %d)', longobj[0]));
}
;

create function DB.DBA.RDF_DATATYPE_OF_LONG (in longobj any) returns any
{
  if (193 = __tag (longobj))
    {
      declare twobyte integer;
      declare res varchar;
      twobyte := longobj[0];
      if (257 = twobyte)
        return null;
      whenever not found goto badtype;
      select RDT_QNAME into res from DB.DBA.RDF_DATATYPE where RDT_TWOBYTE = twobyte;
      return res;

badtype:
  signal ('RDFXX', sprintf ('Unknown datatype in DB.DBA.RDF_DATATYPE_OF_LONG, bad id %d', twobyte));
    }
  if (isiri_id (longobj))
    return NULL;
  return DB.DBA.RDF_DATATYPE_OF_TAG (__tag (longobj));
}
;

create function DB.DBA.RDF_LANGUAGE_OF_LONG (in longobj any) returns any
{
  if (193 = __tag (longobj))
    {
      declare twobyte integer;
      declare res varchar;
      twobyte := longobj[2];
      if (257 = twobyte)
        return null;
      whenever not found goto badlang;
      select RL_ID into res from DB.DBA.RDF_LANGUAGE where RL_TWOBYTE = twobyte;
      return res;

badlang:
  signal ('RDFXX', sprintf ('Unknown language in DB.DBA.RDF_LANGUAGE_OF_LONG, bad id %d', twobyte));
    }
  return NULL;
}
;

create function DB.DBA.RDF_STRSQLVAL_OF_LONG (in longobj any)
{
  declare t, l, len integer;
  if (193 = __tag (longobj))
    {
      declare v2 varchar;
      if (isstring (longobj[1]))
        return longobj[1];
      if (length (longobj) > 5)
        return call (longobj[5] || '_STRSQLVAL_OF_LONG')(longobj);
      v2 := (select case (isnull (RO_LONG)) when 0 then blob_to_string (RO_LONG) else RO_VAL end from DB.DBA.RDF_OBJ where RO_ID = longobj[3]);
      if (v2 is null)
        signal ('RDFXX', sprintf ('Integrity violation in DB.DBA.RDF_STRSQLVAL_OF_LONG, bad id %d', longobj[3]));
      return v2;
    }
  if (isiri_id (longobj))
    {
      declare res varchar;
      if (longobj >= #i1000000000)
        return sprintf ('nodeID://%d', iri_id_num (longobj));
      res := id_to_iri (longobj);
--      res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = longobj));
      if (res is null)
        signal ('RDFXX', 'Wrong iid in DB.DBA.RDF_STRSQLVAL_OF_LONG()');
      return res;
    }
  if (211 = __tag (longobj))
    {
      declare vc varchar;
      vc := cast (longobj as varchar); --!!!TBD: replace with proper serialization
      return replace (vc, ' ', 'T');
    }
  if (225 = __tag (longobj))
    return charset_recode (longobj, '_WIDE_', 'UTF-8');
  return cast (longobj as varchar);
}
;

create function DB.DBA.RDF_LONG_OF_SQLVAL (in v any) returns any
{
  declare l, t int;
  t := __tag (v);
  if (not t in (182, 217, 225))
    return v;
  if (225 = t)
    v := charset_recode (v, '_WIDE_', 'UTF-8');
  else if (217 = t)
    v := cast (v as varchar);
  l := 20;
  if (length (v) > l)
    {
      declare v2 varchar;
      declare id int;
      id := DB.DBA.RDF_FIND_RO_ID_OF_STRING (v);
      if (id is null)
        return vector (257, v, 257, null, null);
      v2 := concat ('\001\001', subseq (v, 0, l), '\0ABCD\001\001');
      v2 [l+3] := bit_and (id, 255);
      v2 [l+4] := bit_and (bit_shift (id, -8), 255);
      v2 [l+5] := bit_and (bit_shift (id, -16), 255);
      v2 [l+6] := bit_and (bit_shift (id, -24), 255);
      return vector (257, v, 257, id, v2);
    }
  return vector (257, v, 257, 0, concat ('\001\001', v, '\0\001\001'));
}
;

-----
-- Conversions for SQL values

--!AWK PUBLIC
create function DB.DBA.RDF_STRSQLVAL_OF_SQLVAL (in sqlval any)
{
  declare t, l, len integer;
  if (193 = __tag (sqlval))
    {
      signal ('RDFXX', 'Long object in DB.DBA.RDF_STRSQLVAL_OF_SQLVAL()');
    }
  if (isiri_id (sqlval))
    {
      declare res varchar;
      if (sqlval >= #i1000000000)
        return sprintf ('nodeID://%d', iri_id_num (sqlval));
      res := id_to_iri (sqlval);
--      res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = sqlval));
      if (res is null)
        signal ('RDFXX', 'Wrong iid in DB.DBA.RDF_STRSQLVAL_OF_SQLVAL()');
      return res;
    }
  if (211 = __tag (sqlval))
    {
      declare vc varchar;
      vc := cast (sqlval as varchar); --!!!TBD: replace with proper serialization
      return replace (vc, ' ', 'T');
    }
  if (225 = __tag (sqlval))
    return charset_recode (sqlval, '_WIDE_', 'UTF-8');
  return cast (sqlval as varchar);
}
;

--!AWK PUBLIC
create function DB.DBA.RDF_DATATYPE_OF_SQLVAL (in v any) returns any
{
  declare t int;
  t := __tag (v);
  if (not t in (182, 217, 225))
    return DB.DBA.RDF_DATATYPE_OF_TAG (t);
  return UNAME'http://www.w3.org/2001/XMLSchema#string';
}
;

--!AWK PUBLIC
create function DB.DBA.RDF_LANGUAGE_OF_SQLVAL (in v any) returns any
{
  declare t int;
  return NULL;
--  t := __tag (v);
--  if (not t in (182, 217, 225))
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
  if (not isstring (v))
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
create function DB.DBA."http://www.w3.org/2001/XMLSchema#dateTime" (in strg any) returns datetime
{
  if (211 = __tag (strg))
    return strg;
  if (isstring (strg))
    return __xqf_str_parse ('dateTime', strg);
}
;

--!AWK PUBLIC
create function DB.DBA."http://www.w3.org/2001/XMLSchema#double" (in strg varchar) returns double precision
{
  return cast (strg as double precision);
}
;

--!AWK PUBLIC
create function DB.DBA."http://www.w3.org/2001/XMLSchema#float" (in strg varchar) returns float
{
  return cast (strg as float);
}
;

--!AWK PUBLIC
create function DB.DBA."http://www.w3.org/2001/XMLSchema#integer" (in strg varchar) returns integer
{
  return cast (strg as integer);
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
  insert replacing DB.DBA.RDF_QUAD (G,S,P,O)
  values (
    DB.DBA.RDF_MAKE_IID_OF_QNAME (g_uri),
    DB.DBA.RDF_MAKE_IID_OF_QNAME (s_uri),
    DB.DBA.RDF_MAKE_IID_OF_QNAME (p_uri),
    DB.DBA.RDF_MAKE_IID_OF_QNAME (o_uri) );
}
;

create procedure DB.DBA.RDF_QUAD_URI_L (in g_uri varchar, in s_uri varchar, in p_uri varchar, in o_lit any)
{
  insert replacing DB.DBA.RDF_QUAD (G,S,P,O)
  values (
    DB.DBA.RDF_MAKE_IID_OF_QNAME (g_uri),
    DB.DBA.RDF_MAKE_IID_OF_QNAME (s_uri),
    DB.DBA.RDF_MAKE_IID_OF_QNAME (p_uri),
    DB.DBA.RDF_MAKE_OBJ_OF_SQLVAL (o_lit) );
}
;

create procedure DB.DBA.RDF_QUAD_URI_L_TYPED (in g_uri varchar, in s_uri varchar, in p_uri varchar, in o_lit any, in dt any, in lang varchar)
{
  insert replacing DB.DBA.RDF_QUAD (G,S,P,O)
  values (
    DB.DBA.RDF_MAKE_IID_OF_QNAME (g_uri),
    DB.DBA.RDF_MAKE_IID_OF_QNAME (s_uri),
    DB.DBA.RDF_MAKE_IID_OF_QNAME (p_uri),
    DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL (
      o_lit, DB.DBA.RDF_MAKE_IID_OF_QNAME (dt), lang ) );
}
;

create procedure DB.DBA.TTLP_EXEC_NEW_GRAPH (in g varchar, inout app_env any) {
  -- dbg_obj_princ ('DB.DBA.TTLP_EXEC_NEW_GRAPH(', g, app_env, ')');
  ;
}
;

create function DB.DBA.TTLP_EXEC_NEW_BLANK (in g varchar, inout app_env any) returns IRI_ID {
  declare res IRI_ID;
  res := iri_id_from_num (sequence_next ('RDF_URL_IID_BLANK'));
  -- dbg_obj_princ ('DB.DBA.TTLP_EXEC_NEW_BLANK (', g, app_env, ') returns ', res);
  return res;
}
;

create function DB.DBA.TTLP_EXEC_GET_IID (in uri varchar, in g varchar, inout app_env any) returns IRI_ID {
  declare res IRI_ID;
  -- dbg_obj_princ ('DB.DBA.TTLP_EXEC_GET_IID (', uri, g, app_env, ')');
  res := DB.DBA.RDF_MAKE_IID_OF_QNAME (uri);
  -- dbg_obj_princ ('DB.DBA.TTLP_EXEC_GET_IID (', uri, g, app_env, ') returns ', res);
  return res;
}
;

create procedure DB.DBA.TTLP_EXEC_TRIPLE (
  in g_uri varchar, in g_iid IRI_ID,
  in s_uri varchar, in s_iid IRI_ID,
  in p_uri varchar, in p_iid IRI_ID,
  in o_uri varchar, in o_iid IRI_ID,
  inout app_env any )
{
  insert replacing DB.DBA.RDF_QUAD (G,S,P,O)
  values (g_iid, s_iid, p_iid, o_iid);
}
;

create procedure DB.DBA.TTLP_EXEC_TRIPLE_L (
  in g_uri varchar, in g_iid IRI_ID,
  in s_uri varchar, in s_iid IRI_ID,
  in p_uri varchar, in p_iid IRI_ID,
  in o_val any, in o_type varchar, in o_lang varchar,
  inout app_env any )
{
  if ('http://www.w3.org/2001/XMLSchema#boolean' = o_type)
    {
      if (('true' = o_val) or ('1' = o_val))
        o_val := 1;
      else if (('false' = o_val) or ('0' = o_val))
        o_val := 0;
      else signal ('RDFXX', 'Invalid notation of boolean literal');
    }
  else if ('http://www.w3.org/2001/XMLSchema#dateTime' = o_type)
    {
      o_val := __xqf_str_parse ('dateTime', o_val);
    }
  else if ('http://www.w3.org/2001/XMLSchema#double' = o_type)
    {
      o_val := cast (o_val as double precision);
    }
  else if ('http://www.w3.org/2001/XMLSchema#float' = o_type)
    {
      o_val := cast (o_val as float);
    }
  else if ('http://www.w3.org/2001/XMLSchema#integer' = o_type)
    {
      o_val := cast (o_val as int);
    }
  else if (isstring (o_type) or isstring (o_lang))
    {
      if (not isstring (o_type))
        o_type := null;
      if (not isstring (o_lang))
        o_lang := null;
      insert replacing DB.DBA.RDF_QUAD (G,S,P,O)
      values (g_iid, s_iid, p_iid,
        DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL (
          o_val,
          DB.DBA.RDF_MAKE_IID_OF_QNAME (o_type),
          o_lang ) );
      return;
    }
  insert replacing DB.DBA.RDF_QUAD (G,S,P,O)
  values (g_iid, s_iid, p_iid, DB.DBA.RDF_MAKE_OBJ_OF_SQLVAL (o_val));
}
;

create procedure DB.DBA.TTLP (in strg varchar, in base varchar, in graph varchar := null, in flags integer := 0)
{
  return rdf_load_turtle (blob_to_string (strg), base, graph, flags,
    vector (
      'DB.DBA.TTLP_EXEC_NEW_GRAPH(?,?)',
      'select DB.DBA.TTLP_EXEC_NEW_BLANK(?,?)',
      'select DB.DBA.TTLP_EXEC_GET_IID(?,?,?)',
      'DB.DBA.TTLP_EXEC_TRIPLE(?,?, ?,?, ?,?, ?,?, ?)',
      'DB.DBA.TTLP_EXEC_TRIPLE_L(?,?, ?,?, ?,?, ?,?,?, ?)',
      'commit work' ),
    'app-env');
}
;

create procedure DB.DBA.RDF_TTL2HASH_EXEC_NEW_GRAPH (in g varchar, inout app_env any) {
  -- dbg_obj_princ ('DB.DBA.RDF_TTL2HASH_EXEC_NEW_GRAPH(', g, app_env, ')');
  ;
}
;

create function DB.DBA.RDF_TTL2HASH_EXEC_NEW_BLANK (in g varchar, inout app_env any) returns IRI_ID {
  declare res IRI_ID;
  res := iri_id_from_num (sequence_next ('RDF_URL_IID_BLANK'));
  -- dbg_obj_princ ('DB.DBA.RDF_TTL2HASH_EXEC_NEW_BLANK (', g, app_env, ') returns ', res);
  return res;
}
;

create function DB.DBA.RDF_TTL2HASH_EXEC_GET_IID (in uri varchar, in g varchar, inout app_env any) returns IRI_ID {
  declare res IRI_ID;
  -- dbg_obj_princ ('DB.DBA.RDF_TTL2HASH_EXEC_GET_IID (', uri, g, app_env, ')');
  res := DB.DBA.RDF_MAKE_IID_OF_QNAME (uri);
  -- dbg_obj_princ ('DB.DBA.RDF_TTL2HASH_EXEC_GET_IID (', uri, g, app_env, ') returns ', res);
  return res;
}
;

create procedure DB.DBA.RDF_TTL2HASH_EXEC_TRIPLE (
  in g_uri varchar, in g_iid IRI_ID,
  in s_uri varchar, in s_iid IRI_ID,
  in p_uri varchar, in p_iid IRI_ID,
  in o_uri varchar, in o_iid IRI_ID,
  inout app_env any )
{
  dict_put (app_env, vector (s_iid, p_iid, o_iid), 0);
}
;

create procedure DB.DBA.RDF_TTL2HASH_EXEC_TRIPLE_L (
  in g_uri varchar, in g_iid IRI_ID,
  in s_uri varchar, in s_iid IRI_ID,
  in p_uri varchar, in p_iid IRI_ID,
  in o_val any, in o_type varchar, in o_lang varchar,
  inout app_env any )
{
  if (not isstring (o_type))
    o_type := null;
  if (not isstring (o_lang))
    o_lang := null;
  dict_put (app_env,
    vector (s_iid, p_iid, DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL_STRINGS (o_val, o_type, o_lang)),
    0 );
}
;

create function DB.DBA.RDF_TTL2HASH (in str varchar, in base varchar, in graph varchar := null, in flags integer := 0) returns any
{
  declare res any;
  res := dict_new ();
  rdf_load_turtle (str, base, graph, flags,
    vector (
      'DB.DBA.RDF_TTL2HASH_EXEC_NEW_GRAPH(?,?)',
      'select DB.DBA.RDF_TTL2HASH_EXEC_NEW_BLANK(?,?)',
      'select DB.DBA.RDF_TTL2HASH_EXEC_GET_IID(?,?,?)',
      'DB.DBA.RDF_TTL2HASH_EXEC_TRIPLE(?,?, ?,?, ?,?, ?,?, ?)',
      'DB.DBA.RDF_TTL2HASH_EXEC_TRIPLE_L(?,?, ?,?, ?,?, ?,?,?, ?)',
      'isinteger(0)' ),
    res);
  return res;
}
;

create procedure DB.DBA.RDF_LOAD_RDFXML (in strg varchar, in base varchar, in graph varchar)
{
  rdf_load_rdfxml (strg, 0,
    graph,
    vector (
      'DB.DBA.TTLP_EXEC_NEW_GRAPH(?,?)',
      'select DB.DBA.TTLP_EXEC_NEW_BLANK(?,?)',
      'select DB.DBA.TTLP_EXEC_GET_IID(?,?,?)',
      'DB.DBA.TTLP_EXEC_TRIPLE(?,?, ?,?, ?,?, ?,?, ?)',
      'DB.DBA.TTLP_EXEC_TRIPLE_L(?,?, ?,?, ?,?, ?,?,?, ?)',
      'commit work' ),
    'app-env',
    base );
  return graph;
}
;

create procedure DB.DBA.RDF_RDFXML_TO_DICT (in strg varchar, in base varchar, in graph varchar)
{
  declare res any;
  res := dict_new ();
  rdf_load_rdfxml (strg, 0,
    graph,
    vector (
      'DB.DBA.TTL2HASH_EXEC_NEW_GRAPH(?,?)',
      'select DB.DBA.RDF_TTL2HASH_EXEC_NEW_BLANK(?,?)',
      'select DB.DBA.RDF_TTL2HASH_EXEC_GET_IID(?,?,?)',
      'DB.DBA.RDF_TTL2HASH_EXEC_TRIPLE(?,?, ?,?, ?,?, ?,?, ?)',
      'DB.DBA.RDF_TTL2HASH_EXEC_TRIPLE_L(?,?, ?,?, ?,?, ?,?,?, ?)',
      'isinteger(0)' ),
    res,
    base );
  return res;
}
;


-----
-- Export into external serializations

create procedure DB.DBA.RDF_LONG_TO_TTL (inout obj any, inout ses any)
{
      declare res varchar;
      if (obj is null)
        signal ('RDFXX', 'DB.DBA.TRIPLES_TO_TTL(): object is NULL');
      if (isiri_id (obj))
        {
          if (obj >= #i1000000000)
            http (sprintf ('_:b%d ', iri_id_num (obj)), ses);
          else
            {
          res := coalesce (id_to_iri (obj), sprintf ('_:bad_iid_%d', iri_id_num (obj)));
--          res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = obj), sprintf ('_:bad_iid_%d', iri_id_num (obj)));
              http ('<', ses);
              http_escape (res, 12, ses, 1, 1);
	      http ('> ', ses);
            }
        }
      else if (193 = __tag (obj))
        {
          http ('"', ses);
          http_escape (obj[1], 11, ses, 1, 1);
          if (257 <> obj[0])
            {
              res := coalesce ((select RDT_QNAME from DB.DBA.RDF_DATATYPE where RDT_TWOBYTE = obj[0]));
              http ('"^^<', ses);
              http_escape (res, 12, ses, 1, 1);
	      http ('> ', ses);
            }
          else if (257 <> obj[2])
            {
              res := coalesce ((select RL_ID from DB.DBA.RDF_LANGUAGE where RL_TWOBYTE = obj[2]));
              http ('"@', ses); http (res, ses); http (' ', ses);
            }
	  else
            http ('"', ses);
        }
      else if (182 = __tag (obj))
        {
          http ('"', ses);
          http_escape (obj, 11, ses, 1, 1);
          http ('" ', ses);
        }
      else
        {
          http ('"', ses);
          http_escape (DB.DBA.RDF_STRSQLVAL_OF_LONG (obj), 11, ses, 1, 1);
          http ('"^^<', ses);
          http_escape (cast (DB.DBA.RDF_DATATYPE_OF_TAG (__tag (obj)) as varchar), 12, ses, 1, 1);
          http ('> ', ses);
        }
}
;


create procedure DB.DBA.RDF_TRIPLES_TO_TTL (inout triples any, inout ses any)
{
  declare tcount, tctr integer;
  declare res varchar;
  tcount := length (triples);
  -- dbg_obj_princ ('DB.DBA.RDF_TRIPLES_TO_TTL:'); for (tctr := 0; tctr < tcount; tctr := tctr + 1) -- dbg_obj_princ (triples[tctr]);
  if (0 = tcount)
    {
      http ('# Empty TURTLE', ses);
      return;
    }
  for (tctr := 0; tctr < tcount; tctr := tctr + 1)
    {
      declare subj,pred,obj any;
      subj := triples[tctr][0];
      pred := triples[tctr][1];
      obj := triples[tctr][2];
      if (not isiri_id (subj))
        {
          if (subj is null)
            signal ('RDFXX', 'DB.DBA.TRIPLES_TO_TTL(): subject is NULL');
          signal ('RDFXX', 'DB.DBA.TRIPLES_TO_TTL(): subject is literal');
        }
      if (subj >= #i1000000000)
        http (sprintf ('_:b%d ', iri_id_num (subj)), ses);
      else
        {
          res := id_to_iri (subj);
--          res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = subj));
          http ('<', ses);
          http_escape (res, 12, ses, 1, 1);
	  http ('> ', ses);
        }
      if (not isiri_id (pred))
        {
          if (pred is null)
            signal ('RDFXX', 'DB.DBA.TRIPLES_TO_TTL(): predicate is NULL');
          signal ('RDFXX', 'DB.DBA.TRIPLES_TO_TTL(): predicate is literal');
        }
      if (pred >= #i1000000000)
        signal ('RDFXX', 'DB.DBA.TRIPLES_TO_TTL(): blank node as predicate');
      else
        {
          res := id_to_iri (pred);
--          res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = pred));
          http ('<', ses);
          http_escape (res, 12, ses, 1, 1);
          http ('> ', ses);
        }
      DB.DBA.RDF_LONG_TO_TTL (obj, ses);
      http ('.\n', ses);
    }
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
      http ('<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">', ses);
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
          if (subj is null)
            signal ('RDFXX', 'DB.DBA.TRIPLES_TO_RDF_XML_TEXT(): subject is NULL');
          signal ('RDFXX', 'DB.DBA.TRIPLES_TO_RDF_XML_TEXT(): subject is literal');
        }
      if (subj >= #i1000000000)
        http (sprintf (' rdf:nodeID="b%d">', iri_id_num (subj)), ses);
      else
        {
          res := id_to_iri (subj);
--          res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = subj));
          http (' rdf:about="', ses); http_value (res, 0, ses); http ('">', ses);
        }
      if (not isiri_id (pred))
        {
          if (pred is null)
            signal ('RDFXX', 'DB.DBA.TRIPLES_TO_RDF_XML_TEXT(): predicate is NULL');
          signal ('RDFXX', 'DB.DBA.TRIPLES_TO_RDF_XML_TEXT(): predicate is literal');
        }
      if (pred >= #i1000000000)
        signal ('RDFXX', 'DB.DBA.TRIPLES_TO_RDF_XML_TEXT(): blank node as predicate');
      else
        {
          res := id_to_iri (pred);
--          res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = pred));
          declare delim integer;
          delim := __max (strrchr (res, '/'), strrchr (res, '#'), strrchr (res, ':'));
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
        }
      if (obj is null)
        signal ('RDFXX', 'DB.DBA.TRIPLES_TO_RDF_XML_TEXT(): object is NULL');
      if (isiri_id (obj))
        {
          if (obj >= #i1000000000)
            http (sprintf (' rdf:nodeID="b%d"/>', iri_id_num (subj)), ses);
          else
            {
              res := coalesce (id_to_iri(obj), sprintf ('_:bad_iid_%d', iri_id_num (obj)));
--              res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = obj), sprintf ('_:bad_iid_%d', iri_id_num (obj)));
              http (' rdf:resource="', ses); http_value (res, 0, ses); http ('"/>', ses);
            }
        }
      else if (193 = __tag (obj))
        {
          if (257 <> obj[0])
            {
              res := coalesce ((select RDT_QNAME from DB.DBA.RDF_DATATYPE where RDT_TWOBYTE = obj[0]));
              http (' rdf:type="', ses); http_value (res, 0, ses); http ('"', ses);
            }
          else if (257 <> obj[2])
            {
              res := coalesce ((select RDT_QNAME from DB.DBA.RDF_DATATYPE where RDT_TWOBYTE = obj[0]));
              http (' xml:lang="', ses); http_value (res, 0, ses); http ('"', ses);
            }
          if (230 = __tag (obj[1]))
            {
              http (' rdf:parseType="Literal">', ses);
              http_value (obj[1], 0, ses);
              http ('</', ses); http (pred_tagname, ses); http ('>', ses);
            }
          else
            {
              http ('>', ses);
              http_value (DB.DBA.RDF_STRSQLVAL_OF_LONG (obj), 0, ses);
              http ('</', ses); http (pred_tagname, ses); http ('>', ses);
            }
        }
      else if (182 = __tag (obj))
        {
          http ('>', ses);
          http_value (obj, 0, ses);
          http ('</', ses); http (pred_tagname, ses); http ('>', ses);
        }
      else
        {
          http (' rdf:type="', ses);
          http_value (DB.DBA.RDF_DATATYPE_OF_TAG (__tag (obj)), 0, ses);
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
          if (_val >= #i1000000000)
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
	  declare lang, dt varchar;
	  lang := DB.DBA.RDF_LANGUAGE_OF_LONG (_val);
	  dt := DB.DBA.RDF_DATATYPE_OF_LONG (_val);
	  http ('"', _env);
	  http_escape (DB.DBA.RDF_SQLVAL_OF_LONG (_val), 11, _env, 1, 1);
	  if (lang is not null)
	    {
	      if (dt is not null)
                http (sprintf ('"@"%V"^^<%V> ] ;',
		    cast (lang as varchar), cast (dt as varchar)), _env);
	      else
                http (sprintf ('"@"%V" ] ;',
		    cast (lang as varchar)), _env);
	    }
	  else
	    {
	      if (dt is not null)
                http (sprintf ('"^^<%V> ] ;',
		    cast (dt as varchar)), _env);
	      else
                http (sprintf ('" ] ;'), _env);
	    }
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
          if (_val >= #i1000000000)
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
	  lang := DB.DBA.RDF_LANGUAGE_OF_LONG (_val);
	  dt := DB.DBA.RDF_DATATYPE_OF_LONG (_val);
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
	  http_value (DB.DBA.RDF_SQLVAL_OF_LONG (_val), 0, _env);
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
-- Insert and delete operations for lists of triples

create function DB.DBA.RDF_INSERT_TRIPLES (in graph_iri any, in triples any)
{
  declare ctr integer;
  if (not isiri_id (graph_iri))
    graph_iri := DB.DBA.RDF_MAKE_IID_OF_QNAME (graph_iri);
  for (ctr := length (triples) - 1; ctr >= 0; ctr := ctr - 1)
    {
      -- dbg_obj_princ ('DB.DBA.RDF_INSERT_TRIPLES: ', graph_iri, triples[ctr][0], triples[ctr][1], triples[ctr][2]);
      insert replacing DB.DBA.RDF_QUAD (G,S,P,O)
      values (graph_iri, triples[ctr][0], triples[ctr][1], DB.DBA.RDF_OBJ_OF_LONG (triples[ctr][2]));
    }
}
;

create function DB.DBA.RDF_DELETE_TRIPLES (in graph_iri any, in triples any)
{
  declare ctr integer;
  if (not isiri_id (graph_iri))
    graph_iri := DB.DBA.RDF_MAKE_IID_OF_QNAME (graph_iri);
  for (ctr := length (triples) - 1; ctr >= 0; ctr := ctr - 1)
    {
      delete from DB.DBA.RDF_QUAD
      where G = graph_iri and
      S = triples[ctr][0] and
      P = triples[ctr][1] and
      O = DB.DBA.RDF_OBJ_OF_LONG (triples[ctr][2]);
    }
}
;

create function DB.DBA.SPARQL_INSERT_DICT_CONTENT (in graph_iri any, in triples_dict any)
{
  declare triples any;
  declare len integer;
  triples := dict_list_keys (triples_dict, 1);
  len := length (triples);
  DB.DBA.RDF_INSERT_TRIPLES (graph_iri, triples);
  return len;
}
;

create function DB.DBA.SPARQL_DELETE_DICT_CONTENT (in graph_iri any, in triples_dict any)
{
  declare triples any;
  declare len integer;
  triples := dict_list_keys (triples_dict, 1);
  len := length (triples);
  DB.DBA.RDF_DELETE_TRIPLES (graph_iri, triples);
  return len;
}
;

-----
-- Built-in operations of SPARQL as SQL functions

--!AWK PUBLIC
create function DB.DBA.RDF_REGEX (in s varchar, in p varchar, in coll varchar := null)
{
-- !!!TBD proper use of third argument
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
  t := toupper (t);
  r := toupper (r);
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
              if ((2 > fld_ctr) and not isiri_id (i))
                signal ('RDF01',
                  sprintf ('Bad variable value in CONSTRUCT: "%.100s" is not a valid %s, only object of a triple can be a literal',
                    DB.DBA.RDF_STRSQLVAL_OF_LONG (i),
                    case (fld_ctr) when 1 then 'predicate' else 'subject' end ) );
              if ((1 = fld_ctr) and isiri_id (i) and (i >= #i1000000000))
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
              if ((2 > fld_ctr) and not isiri_id (arg))
                signal ('RDF01', sprintf ('Bad const value in CONSTRUCT: "%.100s" is not a valid %s, only object of a triple can be a literal',
                  DB.DBA.RDF_STRSQLVAL_OF_LONG (arg),
                  case (fld_ctr) when 1 then 'predicate' else 'subject' end ) );
              if ((1 = fld_ctr) and isiri_id (arg) and (arg >= #i1000000000))
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

create procedure DB.DBA.SPARQL_DESCRIBE_INIT (inout _env any)
{
  _env := 0; -- No actual initialization
}
;

create procedure DB.DBA.SPARQL_DESCRIBE_ACC (inout _env any, in vars any, in stats any, in options any)
{
  declare var_ctr integer;
  declare blank_ids any;
  if (193 <> __tag(_env))
    {
      _env := vector (dict_new (), options);
      if (0 < length (stats))
        DB.DBA.SPARQL_DESCRIBE_ACC (_env, stats, vector(), vector());
    }
  for (var_ctr := length (vars) - 1; var_ctr >= 0; var_ctr := var_ctr - 1)
    {
      declare i any;
      i := vars[var_ctr];
      if (isiri_id (i))
        dict_put (_env[0], i, 0);
    }
}
;

create procedure DB.DBA.SPARQL_DESCRIBE_FIN (inout _env any)
{
  declare subjects, options, res any;
  declare subj_ctr integer;
  if (193 <> __tag(_env))
    return dict_new ();
  subjects := dict_list_keys (_env[0], 1);
  options := _env[1];
  res := dict_new ();
  for (subj_ctr := length (subjects) - 1; subj_ctr >= 0; subj_ctr := subj_ctr - 1)
    {
      declare subj any;
      subj := subjects[subj_ctr];
      DB.DBA.RDF_DESCRIBE_PUT (res, subj, options);
    }
-- The commented-out code below is to debug DESCRIBE functionality using server's console.
-- A DESCRIBE statement returns dictionary that can not be transmitted to the client via SQL connection,
-- so the client will loose connection to server instead of printing the result-set.
-- Debugging version will print to the console and return zero.
--  declare rdump any;
--  rdump := dict_list_keys (res, 1);
--  foreach (any r in rdump) do
--    {
--      -- dbg_obj_princ ('descr: ', r);
--    }
--  return 0;
  return res;
}
;

create aggregate DB.DBA.SPARQL_DESCRIBE (in opcodes any, in vars any, in stats any) returns any
from DB.DBA.SPARQL_DESCRIBE_INIT, DB.DBA.SPARQL_DESCRIBE_ACC, DB.DBA.SPARQL_DESCRIBE_FIN
;

create procedure DB.DBA.RDF_DESCRIBE_PUT (in dict any, in subj IRI_ID, inout options any)
{
-- TBD something later
  for (select G as g1, P as p1, O as obj1 from DB.DBA.RDF_QUAD where S = subj) do
    {
      dict_put (dict, vector (subj, p1, DB.DBA.RDF_LONG_OF_OBJ (obj1)), 0);
      if (isiri_id (obj1))
        {
          for (select P as p2, O as obj2
            from DB.DBA.RDF_QUAD
            where G = g1 and S = obj1 and not (isiri_id (O)) ) do
            {
              dict_put (dict, vector (obj1, p2, DB.DBA.RDF_LONG_OF_OBJ (obj2)), 0);
            }
        }
    }
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
  if (tag = 182)
--    return concat (subseq (obj, 0, 1), '\0', subseq (obj, length (obj)-2));
    return concat (subseq (obj, 0, 1), '\0\0\0');
  if (tag in (189, 191, 219))
    return -3.40282347e+38;
  if (tag = 211)
    return cast ('0101-01-01' as datetime);
  return NULL; -- Nothing else can be compared hence no min.
}
;

create function DB.DBA.RDF_TYPEMAX_OF_OBJ (in obj any) returns any
{
  declare tag integer;
  if (obj is null)
    return NULL;
  tag := __tag (obj);
  if (tag = 182)
--    return concat (subseq (obj, 0, 1), '\377\377\377\377\377\377\377\377\377\377\377\377\0', subseq (obj, length (obj)-2));
    return concat (subseq (obj, 0, 1), '\377\377\377\377\377\377\377\377\377\377\377\377\0\377\377');
  if (tag in (189, 191, 219))
    return 3.40282347e+38;
  if (tag = 211)
    return cast ('9999-12-30' as datetime);
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
  if (tag1 = 182)
    {
      if (tag2 = 182)
        {
          declare l, len1, len2, id1, id2 integer;
          declare begin1, begin2, full1, full2 varchar;
          if (obj1 = obj2)
            return 0;
          if (subseq (obj1, 0, 1) <> subseq (obj1, 0, 1))
            return null;
          len1 := length (obj1);
          len2 := length (obj2);
--          if (subseq (obj1, len1-2) <> subseq (obj2, len2-2))
--            return null;
          l := 20;
          if (len1 = (l + 9))
            {
              begin1 := subseq (obj1, 2, len1-7);
              id1 := obj1 [l+3] + 256 * (obj1 [l+4] + 256 * (obj1 [l+5] + 256 * obj1 [l+6]));
            }
          else
            {
              begin1 := subseq (obj1, 2, len1-3);
              id1 := 0;
            }
          if (len2 = (l + 9))
            {
              begin2 := subseq (obj2, 2, len2-7);
              id2 := obj2 [l+3] + 256 * (obj2 [l+4] + 256 * (obj2 [l+5] + 256 * obj2 [l+6]));
            }
          else
            {
              begin2 := subseq (obj2, 2, len2-3);
              id2 := 0;
            }
          if (begin1 <> begin2)
            {
              if (begin1 < begin2)
                return -1;
              return 1;
            }
          if (id1 = id2)
            return 0;
          full1 := (select case (isnull (RO_LONG)) when 0 then blob_to_string (RO_LONG) else RO_VAL end from DB.DBA.RDF_OBJ where RO_ID = id1);
          if (full1 is null)
            signal ('RDFXX', sprintf ('Integrity violation in DB.DBA.RDF_OBJ_CMP, bad id %d', id1));
          full2 := (select case (isnull (RO_LONG)) when 0 then blob_to_string (RO_LONG) else RO_VAL end from DB.DBA.RDF_OBJ where RO_ID = id2);
          if (full2 is null)
            signal ('RDFXX', sprintf ('Integrity violation in DB.DBA.RDF_OBJ_CMP, bad id %d', id2));
          if (full1 <> full2)
            {
              if (full1 < full2)
                return -1;
              return 1;
            }
          return 0;
        }
       return null;
     }
  if (tag1 in (189, 191, 219))
    {
      if (tag2 in (189, 191, 219))
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
  if (tag1 = 211)
    {
      if (tag2 = 211)
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
  if (tag1 = 193)
    {
      if (tag2 = 193)
        {
          declare full1, full2 varchar;
          if (long1[0] <> long2[0])
            return null;
          full1 := long1 [1];
          full2 := long2 [1];
          if (full1 <> full2)
            {
              if (full1 < full2)
                return -1;
              return 1;
            }
          return 0;
        }
       return null;
     }
  if (tag1 in (189, 191, 219))
    {
      if (tag2 in (189, 191, 219))
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
  if (tag1 = 211)
    {
      if (tag2 = 211)
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
      srcinst := DB.DBA.RDF_QNAME_OF_IID ("src_iid");
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
      "pred" := DB.DBA.RDF_QNAME_OF_IID ("pred");
      if (DB.DBA.RDF_LANGUAGE_OF_LONG ("predval") is not null)
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
          jso_set (class, rootinst, "pred", DB.DBA.RDF_SQLVAL_OF_LONG ("predval"), isiri_id ("predval"));
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
  for (select "p", coalesce ("o2", "o1") as "o"
      from (sparql
          define input:storage ""
          define output:valmode "LONG"
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
      "p" := DB.DBA.RDF_QNAME_OF_IID ("p");
      if (DB.DBA.RDF_LANGUAGE_OF_LONG ("o") is not null)
        signal ('22023', 'JSO_LOAD_INSTANCE does not support language marks on objects');
      if ('http://www.w3.org/1999/02/22-rdf-syntax-ns#type' = "p")
        {
	  if (DB.DBA.RDF_SQLVAL_OF_LONG ("o") <> jclass)
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
          jso_set (jclass, jinst, "p", DB.DBA.RDF_SQLVAL_OF_LONG ("o"), isiri_id ("o"));
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
        DB.DBA.RDF_QNAME_OF_IID ("jclass"),
        DB.DBA.RDF_QNAME_OF_IID ("jinst"),
        coalesce ("s", "jinst") ) )
    from ( sparql
      define output:valmode "LONG"
      define input:storage ""
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

create function JSO_SYS_GRAPH () returns varchar
{
  return 'http://www.openlinksw.com/schemas/virtrdf#';
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
  else if (v_tag = 203)
    http (jso_dbg_dump_rtti (v), ses);
  else if (v_tag = 182)
    {
      http ('"', ses);
      http_escape (v, 11, ses, 1, 1);
      http ('"', ses);
    }
  else if (isinteger (v))
    http_value (v, 0, ses);
  else
    {
      http ('"', ses);
      http_escape (DB.DBA.RDF_STRSQLVAL_OF_LONG (v), 11, ses, 1, 1);
      http ('"^^<', ses);
      http_escape (cast (DB.DBA.RDF_DATATYPE_OF_TAG (__tag (v)) as varchar), 12, ses, 1, 1);
      http ('>', ses);
    }
}
;

create function JSO_DUMP_ALL () returns any
{
  declare proplist, ses any;
  declare prev_obj any;
  declare ctr, len integer;
  ses := string_output ();
  proplist := jso_proplist ();
  gvector_sort (proplist, 1, 0, 1);
  prev_obj := null;
  len := length (proplist);
  for (ctr := 0; ctr < len; ctr := ctr+1)
    {
      declare obj any;
      obj := proplist[ctr][0];
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
      JSO_DUMP_FLD (proplist[ctr][1], ses);
      http ('\t', ses);
      JSO_DUMP_FLD (proplist[ctr][2], ses);
    }
  if (prev_obj is not null)
    http ('.\n', ses);
  return ses;
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

create function DB.DBA.RDF_QM_APPLY_CHANGES (in deleted any, in affected any) returns any
{
  declare ctr, len integer;
  declare graphiri varchar;
  graphiri := JSO_SYS_GRAPH ();
  commit work;
  DB.DBA.JSO_LOAD_GRAPH (graphiri, 0);
  DB.DBA.JSO_PIN_GRAPH (graphiri);
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
            graph `sql:JSO_SYS_GRAPH NIL` { `iri(?:inst)` rdf:type ?t } } ));
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
          graph `sql:JSO_SYS_GRAPH NIL` { `iri(?:inst)` rdf:type ?t } } ) do
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

create function DB.DBA.RDF_QM_GC_SUBTREE (in id varchar) returns integer
{
  declare graphiri varchar;
  declare objs any;
  -- dbg_obj_princ ('DB.DBA.RDF_QM_GC_SUBTREE (', id, ')');
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  for (sparql define input:storage "" select ?s where {
          graph ?g { ?s ?p `iri(?:id)` } } ) do
    {
      -- dbg_obj_princ ('DB.DBA.RDF_QM_GC_SUBTREE (', id, ') does not delete: side link', "s");
      return "s";
    }
  objs := (select VECTOR_AGG (sub."o") from
    (sparql define input:storage ""
     select ?o where {
         graph ?:graphiri { `iri(?:id)` ?p ?o . filter (!isliteral (?o)) } } ) as sub );
  for (sparql define input:storage ""
    delete from graph ?:graphiri { `iri(?:id)` ?p ?o }
    where { graph ?:graphiri { `iri(?:id)` ?p ?o } } ) do {;}
  foreach (varchar obj in objs) do
    DB.DBA.RDF_QM_GC_SUBTREE (obj);
  return NULL;
}
;

create function DB.DBA.RDF_QM_DROP_MAPPING (in storage varchar, in mapname any) returns any
{
  declare qmid, qmgraph varchar;
  qmid := get_keyword_ucase ('ID', mapname, NULL);
  qmgraph := get_keyword_ucase ('GRAPH', mapname, NULL);
  if (qmid is null)
    {
      qmid := coalesce ((sparql
          define input:storage ""
          prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
          select ?s where {
            graph `sql:JSO_SYS_GRAPH NIL` {
                ?s rdf:type virtrdf:QuadMap .
                ?s virtrdf:qmGraphRange-rvrFixedValue `iri(?:qmgraph)` .
                ?s virtrdf:qmTableName "" .
              } } ));
      if (qmid is null)
        return vector (vector ('00100', 'Quad map for graph <' || qmgraph || '> is not found'));
    }
  DB.DBA.RDF_QM_ASSERT_JSO_TYPE (qmid, 'http://www.openlinksw.com/schemas/virtrdf#QuadMap');
  if (storage is null)
    {
      delete from RDF_QUAD
      where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (DB.DBA.JSO_SYS_GRAPH()) and
        O = DB.DBA.RDF_MAKE_IID_OF_QNAME (qmid);
      DB.DBA.RDF_QM_GC_SUBTREE (qmid);
      delete from RDF_QUAD
      where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (DB.DBA.JSO_SYS_GRAPH()) and
        S = DB.DBA.RDF_MAKE_IID_OF_QNAME (qmid);
      return vector (vector ('00000', 'Quad map <' || qmid || '> is deleted'));
    }
  else
    {
--      declare submaps_iid any;
--      submaps_iid := coalesce ((sparql
--          define input:storage ""
--          define output:valmode "LONG"
--          prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
--          select ?subm where {
--            graph `sql:JSO_SYS_GRAPH NIL` {
--                ?:storage virtrdf:qmUserSubMaps ?subm .
--              } } ));
--      delete from RDF_QUAD
--      where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (DB.DBA.JSO_SYS_GRAPH()) and
--        S = submaps_iid and
--        O = DB.DBA.RDF_MAKE_IID_OF_QNAME (qmid);
      DB.DBA.RDF_QM_DELETE_MAPPING_FROM_STORAGE (storage, NULL, qmid);
      return vector (vector ('00000', 'Quad map <' || qmid || '> is no longer used in storage <' || storage || '>'));
    }
}
;

create function DB.DBA.RDF_QM_DEFINE_IRI_CLASS_FORMAT (in classiri varchar, in iritmpl varchar, in arglist any) returns any
{
  declare graphiri varchar;
  declare superformatsid varchar;
  declare res any;
  declare arglist_len integer;
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  if (strstr (iritmpl, '^{URIQADefaultHost}^') is not null)
    {
      declare host varchar;
      host := registry_get ('URIQADefaultHost');
      if (not isstring (host))
        signal ('22023', 'Can not use ^{URIQADefaultHost}^ in IRI template if there is no DefaultHost parameter in [URIQA] section of Virtuoso configuration file');
      iritmpl := replace (iritmpl, '^{URIQADefaultHost}^', host);
    }
  superformatsid := classiri || '--SuperFormats';
  foreach (any arg in arglist) do
    if (UNAME'in' <> arg[0])
      signal ('22023', 'Only "in" parameters are now supported in argument lists of class formats, "' || arg[0] || '" is not supported in CREATE IRI CLASS <' || classiri || '>' );
  if (length (arglist) = 0)
    signal ('22023', 'Empty argument list in CREATE IRI CLASS <' || classiri || '>');
  if (DB.DBA.RDF_QM_ASSERT_JSO_TYPE (classiri, 'http://www.openlinksw.com/schemas/virtrdf#QuadMapFormat', 1))
    {
      declare side_s varchar;
      side_s := DB.DBA.RDF_QM_GC_SUBTREE (classiri);
      if (side_s is not null)
        signal ('22023', 'Can not change iri class <' || classiri || '> because it is used by other quad map objects, e.g., <' || side_s || '>');
      res := vector (vector ('00000', 'Previous definition of IRI class <' || classiri || '> has been dropped'));
    }
  else
    res := vector ();
  arglist_len := length (arglist);
  if (arglist_len > 1)
    {
      for (sparql define input:storage ""
      prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
      insert in graph ?:graphiri
        {
          `iri(?:classiri)`
            rdf:type virtrdf:QuadMapFormat ;
            virtrdf:inheritFrom rdfdf:multipart-uri ;
            virtrdf:noInherit virtrdf:qmfCustomString1 ;
            virtrdf:qmfCustomString1 `?:iritmpl` ;
            virtrdf:qmfColumnCount ?:arglist_len ;
            virtrdf:qmfSuperFormats `iri(?:superformatsid)` .
          `iri(?:superformatsid)`
            rdf:type virtrdf:array-of-QuadMapFormat .
        }
      where {} ) do {;}
      return vector_concat (res, vector (vector ('00000', 'IRI class <' || classiri || '> has been defined (inherited from rdfdf:multipart-uri)')));
    }
  else /* arglist is 1 item long */
    {
      declare basetype, basetypeiri varchar;
      basetype := lower (arglist[0][2]);
      if (not (basetype in ('integer', 'varchar', 'date', 'datetime', 'doubleprecision')))
        signal ('22023', 'The datatype "' || basetype || '" is not supported in CREATE IRI CLASS <' || classiri || '>' );
      basetype := 'sql-' || basetype || '-uri';
      if (not (coalesce (arglist[0][3], 0)))
        basetype := basetype || '-nullable';
      basetypeiri := 'http://www.openlinksw.com/virtrdf-data-formats#' || basetype;
      for (sparql define input:storage ""
      prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
      insert in graph ?:graphiri
        {
          `iri(?:classiri)`
            rdf:type virtrdf:QuadMapFormat;
            virtrdf:inheritFrom `iri(?:basetypeiri)`;
            virtrdf:noInherit virtrdf:qmfCustomString1;
            virtrdf:qmfCustomString1 ?:iritmpl;
            virtrdf:qmfColumnCount 1 ;
            virtrdf:qmfSuperFormats `iri(?:superformatsid)` .
          `iri(?:superformatsid)`
            rdf:type virtrdf:array-of-QuadMapFormat .
        }
      where {} ) do {;}
      return vector_concat (res, vector (vector ('00000', 'IRI class <' || classiri || '> has been defined (inherited from rdfdf:' || basetype || ')')));
    }
  return vector_concat (res, vector (vector ('22023', 'DB.DBA.RDF_QM_DEFINE_IRI_CLASS_FORMAT() is not yet implemented')));
}
;

create function DB.DBA.RDF_QM_DEFINE_IRI_CLASS_FUNCTIONS (in classiri varchar, in uriprint any, in uriparse any) returns any
{
/*
   uriprint is, say,
            vector ( 'DB.DBA.RDF_DF_GRANTEE_ID_URI' ,
                vector (
                    vector ( 306,  'id' ,  'integer' ,  NULL ) ),  'varchar' ,  NULL ),
   uriparse is, say,
            vector ( 'DB.DBA.RDF_DF_GRANTEE_ID_URI_INVERSE' ,
                vector (
                    vector ( 306,  'id_iri' ,  'varchar' ,  NULL ) ),  'integer' ,  NULL ) ),
*/
  declare uriprintname, uriparsename varchar;
  declare numofnotnulls integer;
  declare graphiri varchar;
  declare superformatsid varchar;
  declare res any;
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  superformatsid := classiri || '--SuperFormats';
  DB.DBA.RDF_QM_ASSERT_JSO_TYPE (classiri, NULL);
  uriprintname := uriprint[0];
  uriparsename := uriparse[0];
  if (uriparsename <> uriprintname || '_INVERSE')
    signal ('22023', 'Name of inverse function should be "' || uriprintname || '_INVERSE", not "' || uriparsename || '", other variants are not supported by the current version' );
  if (uriprint[2] <> 'varchar')
    signal ('22023', 'IRI composing function "' || uriprintname || '" should return varchar, not ' || uriprint[2]);
  if (1 <> length (uriprint[1]))
    signal ('22023', 'IRI composing function "' || uriprintname || '" should have exactly one argument');
  foreach (any arg in uriprint[1]) do
    if (UNAME'in' <> arg[0])
      signal ('22023', 'Only "in" parameters are now supported in argument lists of IRI class functions, not "' || arg[0] || '"');
  if (1 <> length (uriparse[1]))
    signal ('22023', 'IRI parsing function "' || uriparsename || '" should have exactly one argument');
  foreach (any arg in uriparse[1]) do
    if (UNAME'in' <> arg[0])
      signal ('22023', 'Only "in" parameters are now supported in argument lists of IRI class functions, not "' || arg[0] || '"');
  if (uriparse[1][0][2] <> 'varchar')
    signal ('22023', 'IRI parsing function "' || uriparsename || '" should have argument of type varchar, not ' || uriparse[1][0][2]);
  if (uriparse[2] <> uriprint[1][0][2])
    signal ('22023', 'The return value of "' || uriparsename || '" and the argument of "' || uriprintname || '" should be of the same data type');
  numofnotnulls :=
    coalesce (uriprint[1][0][3], 0) + coalesce (uriprint[3], 0) +
    coalesce (uriparse[1][0][3], 0) + coalesce (uriparse[3], 0);
  if ((0 <> numofnotnulls) and (4 <> numofnotnulls))
    signal ('22023', 'Both arguments and return values of both "' || uriparsename || '" and "' || uriprintname || '" should be either all four nullable or all four NOT NULL');
  declare arglist, basetype, basetypeiri varchar;
  arglist := uriprint[1];
  basetype := lower (arglist[0][2]);
  if (not (basetype in ('integer', 'varchar' /*, 'date', 'doubleprecision'*/)))
    signal ('22023', 'The datatype "' || basetype || '" is not supported in CREATE IRI CLASS <' || classiri || '> USING FUNCTION' );
  basetype := 'sql-' || basetype || '-uri-fn';
  if (not (coalesce (arglist[0][3], 0)))
    basetype := basetype || '-nullable';
  basetypeiri := 'http://www.openlinksw.com/virtrdf-data-formats#' || basetype;
  if (DB.DBA.RDF_QM_ASSERT_JSO_TYPE (classiri, 'http://www.openlinksw.com/schemas/virtrdf#QuadMapFormat', 1))
    {
      declare side_s varchar;
      side_s := DB.DBA.RDF_QM_GC_SUBTREE (classiri);
      if (side_s is not null)
        signal ('22023', 'Can not change iri class <' || classiri || '> because it is used by other quad map objects, e.g., <' || side_s || '>');
      res := vector (vector ('00000', 'Previous definition of IRI class <' || classiri || '> has been dropped'));
    }
  else
    res := vector ();
  for (sparql define input:storage ""
    prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
    insert in graph ?:graphiri
      {
        `iri(?:classiri)`
          rdf:type virtrdf:QuadMapFormat;
          virtrdf:inheritFrom `iri(?:basetypeiri)`;
          virtrdf:noInherit virtrdf:qmfCustomString1;
          virtrdf:qmfCustomString1 ?:uriprintname;
          virtrdf:qmfSuperFormats `iri(?:superformatsid)` .
        `iri(?:superformatsid)`
          rdf:type virtrdf:array-of-QuadMapFormat .
      }
    where {} ) do {;}
  return vector_concat (res, vector (vector ('00000', 'IRI class <' || classiri || '> has been defined (inherited from rdfdf:' || basetype || ') using ' || uriprintname)));
}
;

create function DB.DBA.RDF_QM_DEFINE_SUBCLASS (in subclassiri varchar, in superclassiri varchar) returns any
{
  declare graphiri varchar;
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  DB.DBA.RDF_QM_ASSERT_JSO_TYPE (subclassiri, 'http://www.openlinksw.com/schemas/virtrdf#QuadMapFormat');
  DB.DBA.RDF_QM_ASSERT_JSO_TYPE (superclassiri, 'http://www.openlinksw.com/schemas/virtrdf#QuadMapFormat');
  for (sparql define input:storage ""
    prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
    insert in graph ?:graphiri
      {
        `iri(?:subclassiri)` virtrdf:isSubclassOf `iri(?:superclassiri)` .
      }
    where {} ) do {;}
  return vector (vector ('00000', 'IRI class <' || subclassiri || '> is now known as a subclass of <' || superclassiri || '>'));
}
;

create function DB.DBA.RDF_QM_DROP_QUAD_STORAGE (in storage varchar) returns any
{
  declare graphiri varchar;
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  DB.DBA.RDF_QM_ASSERT_STORAGE_FLAG (storage, 0);
  DB.DBA.RDF_QM_GC_SUBTREE (storage);
  for (sparql define input:storage ""
    prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
    delete from graph ?:graphiri {
        `iri(?:storage)` ?p ?o
      }
    where { graph ?:graphiri {
            `iri(?:storage)` ?p ?o .
          } } ) do {;}
  return vector (vector ('00000', 'Quad storage <' || storage || '> is removed from the quad mapping schema'));
}
;

create function DB.DBA.RDF_QM_DEFINE_QUAD_STORAGE (in storage varchar) returns any
{
  declare graphiri, qsusermaps varchar;
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  DB.DBA.RDF_QM_ASSERT_JSO_TYPE (storage, NULL);
  qsusermaps := storage || '--UserMaps';
  for (sparql define input:storage ""
    prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
    insert in graph ?:graphiri {
        `iri(?:storage)`
          rdf:type virtrdf:QuadStorage ;
          virtrdf:qsUserMaps `iri(?:qsusermaps)` .
        `iri(?:qsusermaps)`
          rdf:type virtrdf:array-of-QuadMap .
      }
    where {} ) do {;}
  return vector (vector ('00000', 'A new empty quad storage <' || storage || '> is added to the quad mapping schema'));
}
;

create function DB.DBA.RDF_QM_BEGIN_ALTER_QUAD_STORAGE (in storage varchar) returns any
{
  declare graphiri varchar;
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  DB.DBA.RDF_QM_ASSERT_STORAGE_FLAG (storage, 0);
  for (sparql define input:storage ""
    prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
    insert in graph ?:graphiri {
        `iri(?:storage)` virtrdf:qsAlterInProgress `bif:now NIL` .
      }
    where {} ) do {;}
  return vector (vector ('00000', 'Quad storage <' || storage || '> is flagged as being edited'));
}
;

create function DB.DBA.RDF_QM_END_ALTER_QUAD_STORAGE (in storage varchar) returns any
{
  declare graphiri varchar;
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  DB.DBA.RDF_QM_ASSERT_JSO_TYPE (storage, 'http://www.openlinksw.com/schemas/virtrdf#QuadStorage');
  for (sparql define input:storage ""
    prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
    delete from graph ?:graphiri {
        `iri(?:storage)` virtrdf:qsAlterInProgress ?dtstart
      }
    where { graph ?:graphiri {
            `iri(?:storage)` virtrdf:qsAlterInProgress ?dtstart .
          } } ) do {;}
  return vector (vector ('00000', 'Quad storage <' || storage || '> is unflagged and can be edited by other transactions'));
}
;

create function DB.DBA.RDF_QM_DEFINE_MAP_VALUE (in qmv any, in fldname varchar, inout tablename varchar) returns varchar
{
/* iqi qmv: vector ( UNAME'http://www.openlinksw.com/schemas/oplsioc#user_iri' , vector ( vector ('DB.DBA.SYS_USERS', 'alias1', 'U_ID') ) ) */
  declare graphiri varchar;
  declare atables, sqlcols, conds any;
  declare atablectr, atablecount integer;
  declare colctr, colcount integer;
  declare condctr, condcount integer;
  declare fmtid, iriclassid, qmvid, qmvatablesid, qmvcolsid, qmvcondsid varchar;
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  fmtid := qmv[0];
  if (fmtid <> UNAME'literal')
    DB.DBA.RDF_QM_ASSERT_JSO_TYPE (fmtid, 'http://www.openlinksw.com/schemas/virtrdf#QuadMapFormat');
  atables := qmv[1];
  sqlcols := qmv[2];
  conds := qmv[3];
  atablecount := length (atables);
  colcount := length (sqlcols);
  condcount := length (conds);
  for (colctr := 0; colctr < colcount; colctr := colctr + 1)
    {
      declare sqlcol any;
      sqlcol := sqlcols [colctr];
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
  if (fmtid = UNAME'literal')
    {
      declare coldtp, colnullable integer;
      declare coltype varchar;
      select COL_DTP, COL_NULLABLE into coldtp, colnullable
      from DB.DBA.SYS_COLS where "TABLE" = sqlcols[0][0] and "COLUMN" = sqlcols[0][2];
      coltype := case (coldtp)
        when 125 then 'longvarchar'
        when 128 then 'datetime' -- timestamp
        when 129 then 'date'
        when 131 then 'longvarbinary'
        when 189 then 'integer'
        when 182 then 'varchar'
        when 211 then 'datetime'
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
        graph ?:graphiri {
          ?:qmvid
            rdf:type virtrdf:QuadMapValue ;
            virtrdf:qmvATables `iri(?:qmvatablesid)` ;
            virtrdf:qmvColumns `iri(?:qmvcolsid)` ;
            virtrdf:qmvConds `iri(?:qmvcondsid)` ;
            virtrdf:qmvFormat `iri(?:fmtid)` . } } ) )
    return qmvid;
/* Create everything if qmv has not been found */
  for (sparql define input:storage ""
    prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
    delete from graph ?:graphiri {
      `iri(?:qmvid)` ?p ?o . }
    where { graph ?:graphiri {
            `iri(?:qmvid)` ?p ?o .
          } } ) do {;}
  for (sparql define input:storage ""
    prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
    select ?atable where { graph ?:graphiri {
            `iri(?:qmvatablesid)` ?p ?atable } } ) do {
      DB.DBA.RDF_QM_GC_SUBTREE ("atable");
    }
  for (sparql define input:storage ""
    prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
    delete from graph ?:graphiri {
      `iri(?:qmvatablesid)` ?p ?o }
    where { graph ?:graphiri {
            `iri(?:qmvatablesid)` ?p ?o .
          } } ) do {;}
  for (sparql define input:storage ""
    prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
    select ?col where { graph ?:graphiri {
            `iri(?:qmvcolsid)` ?p ?col } } ) do {
      DB.DBA.RDF_QM_GC_SUBTREE ("col");
    }
  for (sparql define input:storage ""
    prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
    delete from graph ?:graphiri {
      `iri(?:qmvcolsid)` ?p ?o }
    where { graph ?:graphiri {
            `iri(?:qmvcolsid)` ?p ?o .
          } } ) do {;}
  for (sparql define input:storage ""
    prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
    delete from graph ?:graphiri {
      `iri(?:qmvcondsid)` ?p ?o }
    where { graph ?:graphiri {
            `iri(?:qmvcondsid)` ?p ?o .
          } } ) do {;}
  if (0 = atablecount)
    qmvatablesid := NULL;
  if (0 = condcount)
    qmvcondsid := NULL;
  for (sparql define input:storage ""
    prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
    insert in graph ?:graphiri {
        `iri(?:qmvid)`
          rdf:type virtrdf:QuadMapValue;
          virtrdf:qmvTableName ?:tablename;
          virtrdf:qmvATables `iri(?:qmvatablesid)`;
          virtrdf:qmvColumns `iri(?:qmvcolsid)`;
          virtrdf:qmvConds `iri(?:qmvcondsid)`;
          virtrdf:qmvFormat `iri(?:fmtid)`;
          virtrdf:qmvIriClass `iri(?:iriclassid)`;
          virtrdf:qmvColumnsFormKey 0 .  #!!!TBD: detection of unique keys.
        `iri(?:qmvatablesid)`
          rdf:type virtrdf:array-of-QuadMapATable .
        `iri(?:qmvcolsid)`
          rdf:type virtrdf:array-of-QuadMapColumn .
        `iri(?:qmvcondsid)`
          rdf:type virtrdf:array-of-string .
      }
    where {} ) do {;}
  for (atablectr := 0; atablectr < atablecount; atablectr := atablectr + 1)
    {
      declare pair any;
      declare qtable, alias, inner_id varchar;
      pair := atables [atablectr];
      alias := pair[0];
      qtable := pair[1];
      inner_id := qmvid || '-atable-' || alias || '-' || qtable;
      for (sparql define input:storage ""
        prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
        insert in graph ?:graphiri {
            `iri(?:qmvatablesid)`
              `iri (bif:sprintf ("%s%d", str (rdf:_), ?:atablectr+1))` `iri(?:inner_id)` .
            `iri(?:inner_id)`  
              rdf:type virtrdf:QuadMapATable ;
              virtrdf:qmvaAlias ?:alias ;
              virtrdf:qmvaTableName ?:qtable .
      }
    where {} ) do {;}
    }
  for (colctr := 0; colctr < colcount; colctr := colctr + 1)
    {
      declare sqlcol any;
      declare qtable, alias, colname, inner_id varchar;
      sqlcol := sqlcols [colctr];
      alias := sqlcol[1];
      colname := sqlcol[2];
      inner_id := qmvid || '-col-' || alias || '-' || colname;
      for (sparql define input:storage ""
        prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
        insert in graph ?:graphiri {
            `iri(?:qmvcolsid)`
              `iri (bif:sprintf ("%s%d", str (rdf:_), ?:colctr+1))` `iri(?:inner_id)` .
            `iri(?:inner_id)`  
              rdf:type virtrdf:QuadMapColumn ;
              virtrdf:qmvcAlias ?:alias ;
              virtrdf:qmvcColumnName ?:colname .
          }
        where {} ) do {;}
    }
  for (condctr := 0; condctr < condcount; condctr := condctr + 1)
    {
      declare sqlcond varchar;
      sqlcond := conds [condctr];
      for (sparql define input:storage ""
        prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
        insert in graph ?:graphiri {
            `iri(?:qmvcondsid)`
              `iri (bif:sprintf ("%s%d", str (rdf:_), ?:condctr+1))` ?:sqlcond .
          }
        where {} ) do {;}
    }
  return qmvid;
}
;

create procedure DB.DBA.RDF_QM_NORMALIZE_QMV (
  inout qmv any, inout qmvfix any, inout qmvid any,
  in can_be_literal integer, in fldname varchar, inout tablename varchar )
{
  qmvid := qmvfix := NULL;
  if ((193 = __tag (qmv)) and (4 = length (qmv)))
    qmvid := DB.DBA.RDF_QM_DEFINE_MAP_VALUE (qmv, fldname, tablename);
  else if (217 = __tag (qmv))
      qmvfix := DB.DBA.RDF_MAKE_IID_OF_QNAME (qmv);
  else if (qmv is not null and not can_be_literal)
    signal ('22023', sprintf ('Quad map declaration can not specify a literal (non-IRI) constant for its %s (tag %d, length %d)',
      fldname, __tag (qmv), length (qmv) ) );
  else if (193 = __tag (qmv))
    signal ('22023', sprintf ('Quad map declaration contains constant %s of unsupported type (tag %d, length %d)',
      fldname, __tag (qmv), length (qmv) ) );
  else
    qmvfix := qmv;
}
;

create function DB.DBA.RDF_QM_DEFINE_MAPPING (in storage varchar,
  in qmrawid varchar, in qmid varchar, in qmparentid varchar,
  in qmv_g any, in qmv_s any, in qmv_p any, in qmv_o any,
  in is_real integer, in rowfilter varchar, in opts any ) returns any
{
  declare graphiri, old_actual_type varchar;
  declare tablename, qmvid_g, qmvid_s, qmvid_p, qmvid_o varchar;
  declare qmvfix_g, qmvfix_s, qmvfix_p, qmvfix_o any;
  declare qm_exclusive, qm_empty, qm_is_default, qmusersubmaps varchar;
  declare qm_order integer;
  -- dbg_obj_princ ('DB.DBA.RDF_QM_DEFINE_MAPPING (', storage, qmrawid, qmid, qmparentid, qmv_g, qmv_s, qmv_p, qmv_o, is_real, rowfilter, opts, ')');
  graphiri := DB.DBA.JSO_SYS_GRAPH ();
  DB.DBA.RDF_QM_ASSERT_STORAGE_FLAG (storage, 1);
--  DB.DBA.RDF_QM_ASSERT_JSO_TYPE (qmid, NULL);
  old_actual_type := coalesce ((sparql define input:storage ""
      prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
      select ?t where {
        graph ?:graphiri { `iri(?:qmid)` rdf:type ?t } } ));
  if (old_actual_type is not null)
    {
      declare old_lstiri, old_side_use varchar;
      if (old_actual_type <> 'http://www.openlinksw.com/schemas/virtrdf#QuadMap')
        signal ('22023', 'The RDF QM schema object <' || qmid || '> already exists, type <' || old_actual_type || '>');
      old_lstiri := (sparql define input:storage ""
        select ?lst where { graph ?:graphiri {
            `iri(?:storage)` virtrdf:qsUserMaps ?lst } } );
      old_side_use := coalesce ((sparql define input:storage ""
          select ?s where {
            graph ?:graphiri { ?s ?p `iri(?:qmid)` filter ((?s != iri(?:storage)) && (?s != iri(?:old_lstiri))) } } ) );
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
  if ('' = tablename)
    tablename := NULL;
  if (get_keyword_ucase ('EXCLUSIVE', opts))
    qm_exclusive := 'http://www.openlinksw.com/schemas/virtrdf#SPART_QM_EXCLUSIVE';
  else
    qm_exclusive := NULL;
  if (get_keyword_ucase ('OK_FOR_ANY_QUAD', opts))
    qm_is_default := 'http://www.openlinksw.com/schemas/virtrdf#SPART_QM_OK_FOR_ANY_QUAD';
  else
    qm_is_default := NULL;
  if (not is_real)
    {
      qm_empty := 'http://www.openlinksw.com/schemas/virtrdf#SPART_QM_EMPTY';
      if (tablename is null)
        tablename := '';
    }
  else
    {
      qm_empty := NULL;
      if (tablename is null)
        signal ('22023', 'At least one field of a quad map should be map value, not a constant');
    }
  qm_order := get_keyword_ucase ('ORDER', opts);
  if (not is_real)
    qmusersubmaps := qmid || '--UserSubMaps';
  else
    qmusersubmaps := NULL;
  if (qm_is_default is not null)
    {
      if (qm_order is not null)
        signal ('22023', 'ORDER option is not applicable to default quad map');
      if (qmparentid is not null)
        signal ('22023', 'A default quad map can not be a sub-map of other quad map');
    }
  for (sparql define input:storage ""
    prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
    insert in graph ?:graphiri {
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
          virtrdf:qmTableRowFilter ?:rowfilter ;
          virtrdf:qmUserSubMaps `iri(?:qmusersubmaps)` ;
          virtrdf:qmMatchingFlags `iri(?:qm_exclusive)` ;
          virtrdf:qmMatchingFlags `iri(?:qm_empty)` ;
          virtrdf:qmMatchingFlags `iri(?:qm_is_default)` ;
          virtrdf:qmPriorityOrder ?:qm_order .
        `iri(?:qmusersubmaps)`
          rdf:type virtrdf:array-of-QuadMap .
          }
        where {} ) do {;}
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
      order by 2, 1 ) as sub );
  -- dbg_obj_princ ('DB.DBA.RDF_QM_ADD_MAPPING_TO_STORAGE: found ', iris_and_orders);
  foreach (any itm in iris_and_orders) do
    {
      declare id, p varchar;
      id := itm[0];
      p := itm[1];
      for (sparql define input:storage ""
        delete from graph ?:graphiri {
         `iri(?:lstiri)` `iri(?:p)` `iri(?:id)` . }
        where { } ) do {;}
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
          for (sparql define input:storage ""
            insert in graph ?:graphiri {
             `iri(?:lstiri)`
               `iri(bif:sprintf("%s%d", str(rdf:_), ?:ctr))`
                 `iri(?:qmid)` . }
            where { } ) do {;}
          -- dbg_obj_princ ('DB.DBA.RDF_QM_ADD_MAPPING_TO_STORAGE: qmid is printed: ', ctr);
          ctr := ctr + 1;
          qmid_is_printed := 1;
        }
      for (sparql define input:storage ""
        insert in graph ?:graphiri {
         `iri(?:lstiri)`
           `iri(bif:sprintf("%s%d", str(rdf:_), ?:ctr))`
             `iri(?:id)` . }
        where { } ) do {;}
      ctr := ctr + 1;
    }
  if (not qmid_is_printed)
    {
      for (sparql define input:storage ""
        insert in graph ?:graphiri {
         `iri(?:lstiri)`
           `iri(bif:sprintf("%s%d", str(rdf:_), ?:ctr))`
             `iri(?:qmid)` . }
        where { } ) do {;}
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
      order by 2, 1 ) as sub );
  -- dbg_obj_princ ('DB.DBA.RDF_QM_DELETE_MAPPING_FROM_STORAGE: found ', iris_and_orders);
  foreach (any itm in iris_and_orders) do
    {
      declare id, p varchar;
      id := itm[0];
      p := itm[1];
      for (sparql define input:storage ""
        delete from graph ?:graphiri {
         `iri(?:lstiri)` `iri(?:p)` `iri(?:id)` . }
        where { } ) do {;}
    }
  ctr := 1;
  foreach (any itm in iris_and_orders) do
    {
      declare id varchar;
      declare ord integer;
      id := itm[0];
      ord := itm[2];
      if (id <> qmid)
        {
          for (sparql define input:storage ""
            insert in graph ?:graphiri {
             `iri(?:lstiri)`
               `iri(bif:sprintf("%s%d", str(rdf:_), ?:ctr))`
                 `iri(?:id)` . }
            where { } ) do {;}
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
  for (sparql define input:storage ""
    insert in graph ?:graphiri { `iri(?:storage)` virtrdf:qsDefaultMap `iri(?:qmid)` . }
    where {} ) do {;}
}
;

create function DB.DBA.RDF_QM_AUTO_LITERAL_FIELD (in qtable varchar, in alias varchar, in col varchar) returns any
{
  return vector (UNAME'literal', vector (vector (coalesce (alias, ''), qtable)), vector (vector (qtable, alias, col)), vector ());
}
;


-----
-- Procedures for graph grabber

create procedure
DB.DBA.SPARQL_GRABBER (in seed varchar, in iter varchar, in final varchar, in limit integer, in depth integer, in base_iri varchar, in resolver varchar)
{
  declare grabbed any;
  declare rctr, rcount, colcount, iter_ctr integer;
  declare stat, msg varchar;
  declare params any; --!!!TBD pass.
  declare metas, rset any;
  result_names (rset);
  params := vector(); --!!!TBD pass.
  grabbed := dict_new ();
  for (iter_ctr := 0; iter_ctr <= depth; iter_ctr := iter_ctr + 1)
    {
      declare new_found integer;
      new_found := 0;
      stat := '00000';
      exec (case (iter_ctr) when 0 then seed else iter end, stat, msg, params, limit, metas, rset);
      if (stat <> '00000')
        signal (stat, msg);
      rcount := length (rset);
      colcount := length (metas[0]);
      for (rctr := 0; rctr < rcount; rctr := rctr + 1)
        {
          declare colctr integer;
          for (colctr := 0; colctr < colcount; colctr := colctr + 1)
            {
              declare val any;
              val := rset[rctr][colctr];
              if (isiri_id (val) and (val < #i1000000000))
                {
                  declare url, get_method varchar;
                  call (resolver) (base_iri, val, url, get_method);
                  if (url is not null and not dict_get (grabbed, url, 0))
                    {
                      whenever sqlstate '*' goto end_of_sponge;
                      DB.DBA.RDF_SPONGE_UP (url, vector (UNAME'get:soft', 'YES', UNAME'get:method', get_method));
                      new_found := 1;
end_of_sponge:
                      dict_put (grabbed, url, 1);
                    }
                }
            }
        }
      if (not new_found)
        goto final_exec;
    }

final_exec:
  stat := '00000';
  exec (final, stat, msg, params, limit, metas, rset);
    if (stat <> '00000')
    signal (stat, msg);
  rcount := length (rset);
  for (rctr := 0; rctr < rcount; rctr := rctr + 1)
    result (rset[rctr]);
}
;

create function DB.DBA.SPARQL_GRABBER_DEFAULT_RESOLVER (in base varchar, in rel_iid IRI_ID, out abs_uri varchar, out get_method varchar)
{
  declare rel varchar;
  rel := DB.DBA.RDF_QNAME_OF_IID (rel_iid);
  if (base = '')
    abs_uri := rel;
  else
    abs_uri := XML_URI_RESOLVE_LIKE_GET (base, rel);
  if ((abs_uri like '%/') or (abs_uri like '%#%'))
    get_method := 'MGET';
  else
    get_method := 'GET';
}
;


-----
-- Procedures to execute local SPARQL statements (obsolete, now SPARQL can be simply inlined in SQL)

create procedure DB.DBA.SPARQL_EVAL_TO_ARRAY (in query varchar, in dflt_graph varchar, in maxrows integer)
{
  declare sqltext, state, msg varchar;
  declare metas, rset any;
  sparql_explain (query);
  sqltext := string_output_string (sparql_to_sql_text (query));
  state := '00000';
  metas := null;
  rset := null;
  connection_set (':default_graph', dflt_graph);
  exec (sqltext, state, msg, vector(), maxrows, metas, rset);
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
  sparql_explain (query);
  sqltext := string_output_string (sparql_to_sql_text (query));
  state := '00000';
  metas := null;
  rset := null;
--  exec ('explain(?)', state, msg, vector (sqltext), 10000, metas, rset);
--  if (state <> '00000')
--    signal (state, msg);
  state := '00000';
  metas := null;
  rset := null;
  connection_set (':default_graph', dflt_graph);
  exec (sqltext, state, msg, vector(), maxrows, metas, rset);
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
  req_body := string_output_string (req_body);
  local_req_hdr := 'Accept: application/sparql-results+xml, text/rdf+n3, application/rdf+xml, application/xml';
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
      strstr (ret_content_type, 'text/rdf+n3') is null ) )
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
                      dt := charset_recode (xpath_eval ('*/datatype', ret_col), '_WIDE_', 'UTF-8');
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
      res_dict := DB.DBA.RDF_RDFXML_TO_DICT (ret_body,'http://local.virt/tmp','');
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
  if (strstr (ret_content_type, 'text/rdf+n3') is not null)
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
  http ('<sparql xmlns="http://www.w3.org/2005/sparql-results#" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.w3.org/2001/sw/DataAccess/rf1/result2.xsd">', ses);
}
;

create procedure SPARQL_RESULTS_XML_WRITE_HEAD (inout ses any, in mdta any)
{
  declare i, l integer;

  http ('\n <head>', ses);

  mdta := mdta[0];
  i := 0; l := length (mdta);
  while (i < l)
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

create procedure SPARQL_RESULTS_XML_WRITE_ROW (inout ses any, in mdta any, inout dta any)
{

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
      if (isiri_id (_val))
        {
          if (_val >= #i1000000000)
	    {
	      http (sprintf ('\n   <binding name="%s"><bnode>nodeID://%d</bnode></binding>', _name, iri_id_num (_val)), ses);
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
	  if (__tag (_val) = 185) -- string output
	    {
              http (sprintf ('\n   <binding name="%s"><literal>', _name), ses);
	      http_value (_val, 0, ses);
              http ('</literal></binding>', ses);
              goto end_of_binding;
	    }
	  lang := DB.DBA.RDF_LANGUAGE_OF_LONG (_val);
	  dt := DB.DBA.RDF_DATATYPE_OF_LONG (_val);
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
	  http_value (DB.DBA.RDF_SQLVAL_OF_LONG (_val), 0, ses);
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
  declare i, l integer;
  mdta := mdta[0];
  i := 0; l := length (mdta);
  while (i < l)
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
      http (sprintf ('\n      <res:binding rdf:nodeID="r%dc%d"><res:variable>%V</res:variable><res:value', rowno, x, _name), ses);
      if (isiri_id (_val))
        {
          if (_val >= #i1000000000)
	    {
	      http (sprintf (' rdf:nodeID="nodeID://%d"/></res:binding>', iri_id_num (_val)), ses);
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
	  lang := DB.DBA.RDF_LANGUAGE_OF_LONG (_val);
	  dt := DB.DBA.RDF_DATATYPE_OF_LONG (_val);
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
	  http_value (DB.DBA.RDF_SQLVAL_OF_LONG (_val), 0, ses);
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
  declare i, l integer;
  mdta := mdta[0];
  i := 0; l := length (mdta);
  while (i < l)
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
      if (i < l)
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

create procedure SPARQL_RESULTS_JAVASCRIPT_HTML_WRITE (inout ses any, inout metas any, inout rset any, in is_js integer := 0)
{
  declare varctr, varcount, resctr, rescount integer;
  varcount := length (metas[0]);
  rescount := length (rset);
  if (is_js)
  {
	  declare tmp_str varchar;
	  declare tmp_ses any;
	  tmp_ses := string_output();
    http ('document.writeln(''', tmp_ses);
    SPARQL_RESULTS_JAVASCRIPT_HTML_WRITE(tmp_ses,metas,rset,0);
	  tmp_str := string_output_string(tmp_ses);
	  tmp_str := replace(tmp_str, '\n', ''');\ndocument.writeln(''');
	  http (tmp_str, ses);
	  http (''');', ses);
	  return;
  }
  http ('<table class="sparql" border="1">', ses);
  http ('\n  <tr>', ses);
  --http ('\n    <th>Row</th>', ses);
  for (varctr := 0; varctr < varcount; varctr := varctr + 1)
    {
      http('\n    <th>', ses);
      http_escape (metas[0][varctr][0], 11, ses, 0, 1);
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
	           http_escape (DB.DBA.RDF_QNAME_OF_IID (val), 11, ses, 0, 1);
            }
          else if (182 = __tag (val))
			{
			  http_escape (val, 11, ses, 1, 1);
			}
          else if (193 = __tag (val))
            {
              http_escape (val[1], 11, ses, 1, 1);
            }
	  else if (185 = __tag (val)) -- string output
	    {
              http_escape (cast (val as varchar), 11, ses, 1, 1);
	    }
          else
            {
              http_escape (DB.DBA.RDF_STRSQLVAL_OF_LONG (val), 11, ses, 1, 1);
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
              if (val > #i1000000000)
                http (sprintf ('"type": "bnode", "value": "nodeID://%d', iri_id_num (val)), ses);
              else
                {
                  http ('"type": "uri", "value": "', ses);
                  http_escape (DB.DBA.RDF_QNAME_OF_IID (val), 11, ses, 0, 1);
                }
            }
          else if (193 = __tag (val))
            {
              declare res varchar;
              if (257 <> val[0])
                {
                  http ('"type": "typed-literal", "datatype": "', ses);
                  res := coalesce ((select RDT_QNAME from DB.DBA.RDF_DATATYPE where RDT_TWOBYTE = val[0]));
                  http_escape (res, 11, ses, 1, 1);
                  http ('", "value": "', ses);
                }
              else if (257 <> val[2])
                {
                  http ('"type": "literal", "xml:lang": "', ses);
                  res := coalesce ((select RL_ID from DB.DBA.RDF_LANGUAGE where RL_TWOBYTE = val[2]));
                  http_escape (res, 11, ses, 1, 1);
                  http ('", "value": "', ses);
                }
              else
                http ('"type": "literal", "value": "', ses);
              http_escape (val[1], 11, ses, 1, 1);
            }
          else if (182 = __tag (val))
            {
              http ('"type": "literal", "value": "', ses);
              http_escape (val, 11, ses, 1, 1);
            }
          else if (185 = __tag (val))
            {
              http ('"type": "literal", "value": "', ses);
              http_escape (cast (val as varchar), 11, ses, 1, 1);
            }
          else
            {
              http ('"type": "typed-literal", "datatype": "', ses);
              http_escape (cast (DB.DBA.RDF_DATATYPE_OF_TAG (__tag (val)) as varchar), 11, ses, 1, 1);
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
      if (strstr (accept, 'text/rdf+n3') is not null or (accept = 'auto'))
        {
          ret_mime := 'text/rdf+n3';
          DB.DBA.RDF_TRIPLES_TO_TTL (triples, ses);
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
      ret_mime := 'application/soap+xml';
      http ('<soapenv:Envelope xmlns:soapenv="http://www.w3.org/2003/05/soap-envelope"><soapenv:Body><query-result xmlns="http://www.w3.org/2005/09/sparql-protocol-types/#">', ses);
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
      if (strstr (accept, 'text/rdf+n3') is not null)
        {
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
    http_header ('Content-Type: ' || ret_mime || '\r\n');
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
  if (accept is not null and accept = 'application/soap+xml')
    {
      declare err_str any;
      http_request_status (sprintf ('HTTP/1.1 500 %s', httpstatus));
      err_str := soap_make_error ('320', state, msg, 12);
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

create procedure WS.WS."/!sparql/" (inout path varchar, inout params any, inout lines any)
{
  declare query, dflt_graph, full_query, format varchar;
  declare named_graphs any;
  declare paramctr, paramcount, maxrows, can_sponge, should_sponge integer;
  declare ses, content any;
  declare def_max, add_http_headers int;
  declare http_meth, content_type, ini_dflt_graph varchar;

  ses := 0;
  query := null;
  dflt_graph := null;
  format := '';
  add_http_headers := 1;
  named_graphs := vector ();
  maxrows := 1024*1024; -- More than enough for web-interface.
  http_meth := http_request_get ('REQUEST_METHOD');
  ini_dflt_graph := cfg_item_value (virtuoso_ini_path (), 'SPARQL', 'DefaultGraph');
  content_type := http_request_header (lines, 'Content-Type', null, '');
  content := null;
  can_sponge := coalesce ((select top 1 1
      from DB.DBA.SYS_USERS as sup
        join DB.DBA.SYS_ROLE_GRANTS as g on (sup.U_ID = g.GI_SUPER)
        join DB.DBA.SYS_USERS as sub on (g.GI_SUB = sub.U_ID)
      where sup.U_NAME = 'SPARQL' and sub.U_NAME = 'SPARQL_UPDATE' ), 0);
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

  paramcount := length (params);
  if (((0 = paramcount) or ((2 = paramcount) and ('Content' = params[0]))) and content_type <> 'application/soap+xml')
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
http('			<p>This query page is designed to help you test Openlink Virtuoso SPARQL protocol endpoint. <br/>\n');
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
http('			  <input type="checkbox"' ||
  case (isnull (get_keyword ('should-sponge', params))) when 0 then ' checked="checked"' else '' end ||
  ' name="should-sponge" id="should-sponge" value="soft"/>\n');
http('			  <label for="should-sponge">Retrieve remote RDF data for all missing source graphs</label>\n');
http('			  <br /><br />\n');
  }
else
  {
http('			  <i>Security restrictions of this server does not allow you to retrieve remote RDF data.
DBA may wish to grant "SPARQL_UPDATE" privilege to "SPARQL" account to remove the restriction.</i>\n');
http('			  <br /><br />\n');
  }
http('			  <label for="query">Query text</label>\n');
http('			  <br />\n');
http('			  <textarea rows="10" cols="60" name="query" id="query" onchange="format_select(this)" onkeyup="format_select(this)">SELECT * WHERE {?s ?p ?o}</textarea>\n');
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
        dflt_graph := pvalue;
      else if ('named-graph-uri' = pname)
        {
	  if (position (pvalue, named_graphs) < 0)
	    named_graphs := vector_concat (named_graphs, vector (pvalue));
	}
      else if ('maxrows' = pname)
        {
	  maxrows := cast (pvalue as integer);
	}
      else if ('should-sponge' = pname)
        {
          if (can_sponge)
            should_sponge := 1;
	}
      else if ('format' = pname)
        {
	  format := pvalue;
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
		  query := XML_URI_GET ('', pvalue);
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
    }
  def_max := atoi (coalesce (cfg_item_value (virtuoso_ini_path (), 'SPARQL', 'ResultSetMaxRows'), '-1'));
  if (def_max > 0 and def_max < maxrows)
    maxrows := def_max;

  --if (dflt_graph is null and length (ini_dflt_graph))
  --  dflt_graph := ini_dflt_graph;


  -- SOAP 1.2 operation begins
  if (http_meth = 'POST' and content_type = 'application/soap+xml')
    {
       declare xt, ng any;
       content := http_body_read ();
--       dbg_obj_print (string_output_string (content));
       xt := xtree_doc (content);
       query := charset_recode (xpath_eval ('[ xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:sp="http://www.w3.org/2005/09/sparql-protocol-types/#" ] string (/soap:Envelope/soap:Body/sp:query-request/sp:query)', xt), '_WIDE_', 'UTF-8');
       dflt_graph := charset_recode (xpath_eval ('[ xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:sp="http://www.w3.org/2005/09/sparql-protocol-types/#" ] string (/soap:Envelope/soap:Body/sp:query-request/sp:default-graph-uri)', xt), '_WIDE_', 'UTF-8');
       ng := xpath_eval ('[ xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:sp="http://www.w3.org/2005/09/sparql-protocol-types/#" ] /soap:Envelope/soap:Body/sp:query-request/sp:named-graph-uri', xt, 0);

       foreach (any frag in ng) do
	 {
	   declare pvalue varchar;
	   pvalue := charset_recode (xpath_eval ('string(.)', frag), '_WIDE_', 'UTF-8');
	   if (position (pvalue, named_graphs) < 0)
	     named_graphs := vector_concat (named_graphs, vector (pvalue));
	 }
       format := 'application/soap+xml';
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
  if (dflt_graph is null)
    {
      declare req_hosts varchar;
      declare req_hosts_split any;
      declare hctr integer;
      req_hosts := http_request_header (lines, 'Host', null, null);
      req_hosts := replace (req_hosts, ', ', ',');
      req_hosts_split := split_and_decode (req_hosts, 0, '\0\0,');
      for (hctr := length (req_hosts_split) - 1;
        (hctr >= 0) and dflt_graph is null;
	hctr := hctr - 1)
        {
          dflt_graph := coalesce ((
            select SH_GRAPH_URI from DB.DBA.SYS_SPARQL_HOST
            where SH_HOST = req_hosts_split [hctr] ) );
        }
      full_query := query;
    }
  else
    {
      full_query := concat ('define input:default-graph-uri "', dflt_graph, '" ', query);
    }
  if (can_sponge and should_sponge)
    full_query := concat ('define get:soft "soft" ', full_query);
  full_query := concat ('define output:valmode "LONG" ', full_query);
  declare state, msg varchar;
  declare metas, rset any;
  state := '00000';
  metas := null;
  rset := null;
  exec ('isnull (sparql_to_sql_text (?))', state, msg, vector (full_query));
  if (state <> '00000')
    {
      DB.DBA.SPARQL_PROTOCOL_ERROR_REPORT (path, params, lines,
        '400', 'Bad Request',
	query, state, msg, format);
      return;
    }
  state := '00000';
  metas := null;
  rset := null;
  connection_set (':default_graph', dflt_graph);
  connection_set (':named_graphs', named_graphs);
  http_header (sprintf ('X-SPARQL-default-graph: %U\r\n', dflt_graph));
--  http (sprintf ('<!-- X-SPARQL-default-graph: %U\r\n -->\n', dflt_graph));
--  http ('<!-- Query:\n' || query || '\n-->\n', 0);
  set_user_id ('SPARQL');
  exec ( concat ('sparql ', full_query), state, msg, vector(), maxrows, metas, rset);
  -- dbg_obj_princ ('exec metas=', metas);
  if (state <> '00000')
    {
      DB.DBA.SPARQL_PROTOCOL_ERROR_REPORT (path, params, lines,
        '500', 'SPARQL Request Failed',
	query, state, msg, format);
      return;
    }
  declare accept varchar;
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






create procedure DB.DBA.TTLP_EXEC_TRIPLE_W (
  in g_iid IRI_ID,
  in s_iid IRI_ID,
  in p_iid IRI_ID,
  in o_iid any)
{
  log_enable (0);
  insert soft DB.DBA.RDF_QUAD (G,S,P,O)
  values (g_iid, s_iid, p_iid, o_iid);
  commit work;
}
;


create procedure DB.DBA.TTLP_EXEC_TRIPLE_W_L (
  in g_iid IRI_ID,
  in s_iid IRI_ID,
  in p_iid IRI_ID,
  in o_val any, in o_type any, in o_lang any)
{
  log_enable (0);
  if ('http://www.w3.org/2001/XMLSchema#boolean' = o_type)
    {
      if (('true' = o_val) or ('1' = o_val))
        o_val := 1;
      else if (('false' = o_val) or ('0' = o_val))
        o_val := 0;
      else signal ('RDFXX', 'Invalid notation of boolean literal');
    }
  else if ('http://www.w3.org/2001/XMLSchema#dateTime' = o_type)
    {
      o_val := __xqf_str_parse ('dateTime', o_val);
    }
  else if ('http://www.w3.org/2001/XMLSchema#double' = o_type)
    {
      o_val := cast (o_val as double precision);
    }
  else if ('http://www.w3.org/2001/XMLSchema#float' = o_type)
    {
      o_val := cast (o_val as float);
    }
  else if ('http://www.w3.org/2001/XMLSchema#integer' = o_type)
    {
      o_val := cast (o_val as int);
    }
  else if (isstring (o_type) or isstring (o_lang))
    {
      if (not isstring (o_type))
        o_type := null;
      if (not isstring (o_lang))
        o_lang := null;

      insert soft DB.DBA.RDF_QUAD (G,S,P,O)
	values (g_iid, s_iid, p_iid,
	  DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL (o_val,
	    iri_to_id (o_type, 1),
	  o_lang ) );
      commit work;
      return;
    }

  insert soft DB.DBA.RDF_QUAD (G,S,P,O)
  values (g_iid, s_iid, p_iid, DB.DBA.RDF_MAKE_OBJ_OF_SQLVAL (o_val));
  commit work;
}
;


create procedure DB.DBA.TTLP_EXEC_TRIPLE_A (
  in g_uri varchar, in g_iid IRI_ID,
  in s_uri varchar, in s_iid IRI_ID,
  in p_uri varchar, in p_iid IRI_ID,
  in o_uri varchar, in o_iid IRI_ID,
  inout app_env any )
{
  declare err any;
  app_env[1] := aq_request (app_env[0], 'DB.DBA.TTLP_EXEC_TRIPLE_W', vector (g_iid, s_iid, p_iid, o_iid));
  if (mod (app_env[1], 4000) = 0)
    {
      commit work;
      aq_wait (app_env[0], app_env[1], err, 1);
      aq_wait_all (app_env[0]);
    }
}
;


create procedure DB.DBA.TTLP_EXEC_TRIPLE_L_A (
  in g_uri varchar, in g_iid IRI_ID,
  in s_uri varchar, in s_iid IRI_ID,
  in p_uri varchar, in p_iid IRI_ID,
  in o_val any, in o_type varchar, in o_lang varchar,
  inout app_env any )
{
  declare err any;
  app_env[1] := aq_request (app_env[0], 'DB.DBA.TTLP_EXEC_TRIPLE_W_L', vector  (g_iid, s_iid, p_iid, o_val, o_type, o_lang));
  if (mod (app_env[1], 4000) = 0)
    {
      commit work;
      aq_wait (app_env[0], app_env[1], err, 1);
      aq_wait_all (app_env[0]);
    }
}
;


create procedure DB.DBA.TTLP_MT (in strg varchar, in base varchar, in graph varchar := null, in flags integer := 0)
{
  declare app_env, err any;
  app_env := vector (async_queue (3), 0);
  rdf_load_turtle (strg, base, graph, flags,
    vector (
      'DB.DBA.TTLP_EXEC_NEW_GRAPH(?,?)',
      'select DB.DBA.TTLP_EXEC_NEW_BLANK(?,?)',
      'select iri_to_id(cast (? as varchar), 1), ?, ?', -- was 'select DB.DBA.TTLP_EXEC_GET_IID(?,?,?)',
      'DB.DBA.TTLP_EXEC_TRIPLE_A(?,?, ?,?, ?,?, ?,?, ?)',
      'DB.DBA.TTLP_EXEC_TRIPLE_L_A(?,?, ?,?, ?,?, ?,?,?, ?)',
      'commit work' ),
    app_env);
  commit work;
  aq_wait (app_env[0], app_env[1], err, 1);
  aq_wait_all (app_env[0]);
}
;

create procedure DB.DBA.RDF_LOAD_RDFXML_MT (in strg varchar, in base varchar, in graph varchar)
{
  declare app_env, err any;
  app_env := vector (async_queue (3), 0);
  rdf_load_rdfxml (strg, 0,
    graph,
    vector (
      'DB.DBA.TTLP_EXEC_NEW_GRAPH(?,?)',
      'select DB.DBA.TTLP_EXEC_NEW_BLANK(?,?)',
      'select iri_to_id (cast (? as varchar), 1), ?, ?', -- was 'select DB.DBA.TTLP_EXEC_GET_IID(?,?,?)',
      'DB.DBA.TTLP_EXEC_TRIPLE_A(?,?, ?,?, ?,?, ?,?, ?)',
      'DB.DBA.TTLP_EXEC_TRIPLE_L_A(?,?, ?,?, ?,?, ?,?,?, ?)',
      'commit work' ),
    app_env,
    base );
  commit work;
  aq_wait (app_env[0], app_env[1], err, 1);
  aq_wait_all (app_env[0]);

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
  HS_QUALITY double precision,
  primary key (HS_LOCAL_IRI, HS_PARSER)
)
create index SYS_HTTP_SPONGE_EXPIRATION on DB.DBA.SYS_HTTP_SPONGE (HS_EXPIRATION desc)
;

create function DB.DBA.SYS_HTTP_SPONGE_UP (in local_iri varchar, in parser varchar, in eraser varchar, in options any)
{
  declare new_origin_uri, new_origin_login, new_last_etag varchar;
  declare old_origin_uri, old_origin_login, old_last_etag varchar;
  declare new_last_load, new_expiration datetime;
  declare old_last_load, old_expiration, old_last_modified datetime;
  declare load_begin_msec, load_end_msec, old_exp_is_true,
    old_download_size, old_download_msec_time, old_read_count,
    new_download_size, explicit_refresh integer;
  declare get_method varchar;
  declare ret_hdr any;
  declare req_hdr varchar;
  declare ret_body, ret_content_type, ret_etag, ret_last_modified, ret_date, ret_last_modif, ret_expires varchar;
  declare get_proxy varchar;
  declare ret_dt_date, ret_dt_last_modified, ret_dt_expires datetime;
  declare ret_304_not_modified integer;
  -- dbg_obj_princ ('DB.DBA.RDF_SPONGE_UP (', local_iri, options, ')');
  new_origin_uri := cast (get_keyword_ucase ('get:uri', options, local_iri) as varchar);
  new_origin_login := cast (get_keyword_ucase ('get:login', options) as varchar);
  explicit_refresh := get_keyword_ucase ('get:refresh', options);
  set isolation='serializable';
  whenever not found goto add_new_origin;
  select HS_ORIGIN_URI, HS_ORIGIN_LOGIN, HS_LAST_LOAD, HS_LAST_ETAG,
    HS_EXP_IS_TRUE, HS_EXPIRATION, HS_LAST_MODIFIED,
    HS_DOWNLOAD_SIZE, HS_DOWNLOAD_MSEC_TIME, HS_READ_COUNT
  into old_origin_uri, old_origin_login, old_last_load, old_last_etag,
    old_exp_is_true, old_expiration, old_last_modified,
    old_download_size, old_download_msec_time, old_read_count
  from DB.DBA.SYS_HTTP_SPONGE where HS_LOCAL_IRI = local_iri and HS_PARSER = parser;
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
          return local_iri;
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
  goto perform_actual_load;

add_new_origin:
  -- dbg_obj_princ ('adding new origin...');
  old_origin_uri := NULL; old_origin_login := NULL; old_last_load := NULL; old_last_etag := NULL;
  old_expiration := NULL; old_download_size := NULL; old_download_msec_time := NULL;
  old_exp_is_true := 0; old_read_count := 0;
  insert into DB.DBA.SYS_HTTP_SPONGE (HS_LOCAL_IRI, HS_PARSER, HS_ORIGIN_URI, HS_ORIGIN_LOGIN, HS_LAST_LOAD)
  values (local_iri, parser, new_origin_uri, new_origin_login, now());
  goto perform_actual_load;

perform_actual_load:
  new_expiration := NULL;
  new_last_etag := NULL;
  ret_304_not_modified := 0;
  load_begin_msec := msec_time();
  set isolation='committed';

  get_method := cast (get_keyword_ucase ('get:method', options, 'GET') as varchar);
  if (get_method in ('POST', 'GET'))
    {
      req_hdr := NULL;
      get_proxy := get_keyword_ucase ('get:proxy', options);
      --!!!TBD: proper support for POST
      --!!!TBD: proper authentication if get:login / get:password is provided.
      if (old_last_etag is not null)
        req_hdr := 'If-None-Match: ' || old_last_etag;
      -- dbg_obj_princ ('Calling http_get (', new_origin_uri, ',..., ', get_method, req_hdr, NULL, get_proxy, ')');
      ret_body := http_get (new_origin_uri, ret_hdr, get_method, req_hdr, NULL, get_proxy);
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
        new_expiration := dateadd ('second', __min (3600 * 24 * 7, 0.7 * datediff ('second', ret_dt_last_modified, ret_dt_date)), now());
    }
  if (ret_304_not_modified)
    {
      if (new_expiration is null and explicit_refresh is not null)
        new_expiration := dateadd ('second', 0.7 * explicit_refresh, now());
      if (ret_dt_expires is null and new_expiration is not null and explicit_refresh is not null)
        new_expiration := __min (new_expiration, dateadd ('second', explicit_refresh, now()));
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
      return local_iri;
    }
  if (ret_body is null)
    signal ('RDFXX', sprintf ('Unable to retrieve RDF data from "%.500s": %.500s', new_origin_uri, ret_hdr[0]));
  --!!!TBD: proper character set handling in response
  new_download_size := length (ret_body);

  whenever sqlstate '*' goto error_during_load;
  call (parser) (local_iri, new_origin_uri, ret_content_type, ret_hdr, ret_body, options);
    new_last_etag := ret_etag;
  load_end_msec := msec_time();
  if (new_expiration is null)
    new_expiration := dateadd ('second', load_end_msec - load_begin_msec, now()); -- assuming that expiration is at least 1000 times larger than load time.
  if (ret_dt_expires is null and explicit_refresh is not null)
    new_expiration := __min (new_expiration, dateadd ('second', 0.7 * explicit_refresh, now()));
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
  return local_iri;

error_during_load:
  -- dbg_obj_princ ('error during load: ', __SQL_STATE, __SQL_MESSAGE);
  update DB.DBA.SYS_HTTP_SPONGE
  set HS_SQL_STATE = __SQL_STATE,
    HS_SQL_MESSAGE = __SQL_MESSAGE
  where
    HS_LOCAL_IRI = local_iri and HS_PARSER = parser;
  return local_iri;
}
;

create function DB.DBA.RDF_SPONGE_GUESS_CONTENT_TYPE (in origin_uri varchar, in ret_content_type varchar, inout ret_body any) returns varchar
{
  if (ret_content_type is not null)
    {
      if (strstr (ret_content_type, 'application/sparql-results+xml') is not null)
        return 'application/sparql-results+xml';
      if (strstr (ret_content_type, 'application/rdf+xml') is not null)
        return 'application/rdf+xml';
      if (strstr (ret_content_type, 'text/rdf+n3') is not null)
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

create procedure DB.DBA.RDF_LOAD_HTTP_RESPONSE (in graph_iri varchar, in new_origin_uri varchar, inout ret_content_type varchar, inout ret_hdr any, inout ret_body any, inout options any)
{
  --!!!TBD: proper calculation of new_expiration, usingdata from HTTP header of the response
  ret_content_type := DB.DBA.RDF_SPONGE_GUESS_CONTENT_TYPE (new_origin_uri, ret_content_type, ret_body);
  -- dbg_obj_princ ('ret_content_type is ', ret_content_type);
  if (strstr (ret_content_type, 'application/sparql-results+xml') is not null)
    signal ('RDFXX', sprintf ('Unable to load RDF graph <%.500s> from <%.500s>: the sparql-results XML answer does not contain triples', graph_iri, new_origin_uri));
  if (strstr (ret_content_type, 'application/rdf+xml') is not null)
    {
      delete from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (graph_iri);
      DB.DBA.RDF_LOAD_RDFXML (ret_body, new_origin_uri, graph_iri);
      return;
    }
  if (strstr (ret_content_type, 'text/rdf+n3') is not null)
    {
      delete from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (graph_iri);
      DB.DBA.TTLP (ret_body, new_origin_uri, graph_iri);
      return;
    }
  delete from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (graph_iri);
  if (strstr (ret_content_type, 'text/plain') is not null)
    {
      signal ('RDFXX', sprintf (
          'Unable to load RDF graph <%.500s> from <%.500s>: returned Content-Type ''%.300s'' status ''%.300s''\n%.1000s',
          graph_iri, new_origin_uri, ret_content_type, ret_hdr[0], "LEFT" (ret_body, 1024) ) );
    }
  if (strstr (ret_content_type, 'text/html') is not null)
    {
      signal ('RDFZZ', sprintf (
          'Unable to load RDF graph <%.500s> from <%.500s>: returned Content-Type ''%.300s'' status ''%.300s''\n%.1000s',
          graph_iri, new_origin_uri, ret_content_type, ret_hdr[0],
          cast (xtree_doc (ret_body, 2) as varchar) ) );
    }
  signal ('RDFZZ', sprintf (
      'Unable to load RDF graph <%.500s> from <%.500s>: returned unsupported Content-Type ''%.300s''',
      graph_iri, new_origin_uri, ret_content_type ) );
}
;

create procedure DB.DBA.RDF_FORGET_HTTP_RESPONSE (in graph_iri varchar, in new_origin_uri varchar, inout options any)
{
  delete from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (graph_iri);
}
;

create function DB.DBA.RDF_SPONGE_UP (in graph_iri varchar, in options any)
{
  declare get_soft varchar;
  get_soft := get_keyword ('get:soft', options);
  if ('soft' = get_soft)
    {
      if (
        exists (select top 1 1 from DB.DBA.RDF_QUAD
          where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (graph_iri) ) and
        not exists (select top 1 1 from DB.DBA.SYS_HTTP_SPONGE
          where HS_LOCAL_IRI = graph_iri and HS_PARSER = 'DB.DBA.RDF_LOAD_HTTP_RESPONSE' ) )
        return graph_iri;
    }
  return DB.DBA.SYS_HTTP_SPONGE_UP (graph_iri, 'DB.DBA.RDF_LOAD_HTTP_RESPONSE', 'DB.DBA.RDF_FORGET_HTTP_RESPONSE', options);
}
;


-----
-- Loading default set of quad map metadata.

create procedure DB.DBA.SPARQL_RELOAD_QM_GRAPH ()
{
  if (not exists (sparql define input:storage "" ask where {
          graph <http://www.openlinksw.com/schemas/virtrdf#> {
              <http://www.openlinksw.com/sparql/virtrdf-data-formats.ttl>
                virtrdf:version '2006-11-12 0001'
            } } ) )
    {
      declare txt1, txt2 varchar;
      declare jso_sys_g_iid IRI_ID;
      declare dict1, lst1, dict2, lst2, sum_lst any;
      txt1 := cast ( XML_URI_GET (
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
  virtrdf:qsDefaultMap virtrdf:DefaultQuadMap .
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
          delete from DB.DBA.RDF_QUAD where G = jso_sys_g_iid and S = triple[0] and P = triple[1];
        }
      foreach (any triple in sum_lst) do
        {
          insert into DB.DBA.RDF_QUAD (G,S,P,O) values (jso_sys_g_iid, triple[0], triple[1], DB.DBA.RDF_OBJ_OF_LONG (triple[2]));
        }
    commit work;
  }
  JSO_LOAD_GRAPH (JSO_SYS_GRAPH (), 0);
  JSO_PIN_GRAPH (JSO_SYS_GRAPH ());
}
;

create procedure DB.DBA.RDF_CREATE_SPARQL_ROLES ()
{
  declare state, msg varchar;
  declare cmds any;
  cmds := vector (
    'create role SPARQL_SELECT',
    'create role SPARQL_UPDATE',
    'grant SPARQL_SELECT to SPARQL_UPDATE',
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
    'grant execute on DB.DBA.RDF_QNAME_OF_IID to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_IID_OF_QNAME_SAFE to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_IID_OF_QNAME to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_MAKE_GRAPH_IIDS_OF_QNAMES to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_TWOBYTE_OF_DATATYPE to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_TWOBYTE_OF_LANGUAGE to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_DATATYPE_OF_TAG to SPARQL_SELECT',
    'grant execute on DB.DBA.RQ_LONG_OF_O to SPARQL_SELECT',
    'grant execute on DB.DBA.RQ_SQLVAL_OF_O to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_BOOL_OF_O to SPARQL_SELECT',
    'grant execute on DB.DBA.RQ_IID_OF_O to SPARQL_SELECT',
    'grant execute on DB.DBA.RQ_O_IS_LIT to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_MAKE_RO_ID_OF_STRING to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_FIND_RO_ID_OF_STRING to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_MAKE_OBJ_OF_SQLVAL to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL_STRINGS to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_LONG_OF_OBJ to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_DATATYPE_OF_OBJ to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_LANGUAGE_OF_OBJ to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_SQLVAL_OF_OBJ to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_BOOL_OF_OBJ to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_QNAME_OF_OBJ to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_STRSQLVAL_OF_OBJ to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_OBJ_OF_LONG to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_OBJ_OF_SQLVAL to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_MAKE_LONG_OF_SQLVAL to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL_STRINGS to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_SQLVAL_OF_LONG to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_BOOL_OF_LONG to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_DATATYPE_OF_LONG to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_LANGUAGE_OF_LONG to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_STRSQLVAL_OF_LONG to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_LONG_OF_SQLVAL to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_DATATYPE_OF_SQLVAL to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_QUAD_URI to SPARQL_UPDATE',
    'grant execute on DB.DBA.RDF_QUAD_URI_L to SPARQL_UPDATE',
    'grant execute on DB.DBA.RDF_QUAD_URI_L_TYPED to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP_EXEC_NEW_GRAPH to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP_EXEC_NEW_BLANK to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP_EXEC_GET_IID to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP_EXEC_TRIPLE to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP_EXEC_TRIPLE_L to SPARQL_UPDATE',
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
    'grant execute on DB.DBA.SPARQL_INSERT_DICT_CONTENT to SPARQL_UPDATE',
    'grant execute on DB.DBA.SPARQL_DELETE_DICT_CONTENT to SPARQL_UPDATE',
    'grant execute on DB.DBA.SPARQL_DESCRIBE_INIT to SPARQL_SELECT',
    'grant execute on DB.DBA.SPARQL_DESCRIBE_ACC to SPARQL_SELECT',
    'grant execute on DB.DBA.SPARQL_DESCRIBE_FIN to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_DESCRIBE_PUT to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_TYPEMIN_OF_OBJ to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_TYPEMAX_OF_OBJ to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_IID_CMP to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_OBJ_CMP to SPARQL_SELECT',
    'grant execute on DB.DBA.RDF_LONG_CMP to SPARQL_SELECT',
    'grant execute on DB.DBA.SPARQL_EVAL_TO_ARRAY to SPARQL_SELECT',
    'grant execute on DB.DBA.SPARQL_EVAL to SPARQL_SELECT',
    'grant execute on DB.DBA.SPARQL_REXEC to SPARQL_SELECT',
    'grant execute on DB.DBA.SPARQL_REXEC_TO_ARRAY to SPARQL_SELECT',
    'grant execute on DB.DBA.SPARQL_REXEC_WITH_META to SPARQL_SELECT',
    'grant execute on WS.WS."/!sparql/" to "SPARQL"',
    'grant execute on DB.DBA.TTLP_MT  to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP_EXEC_TRIPLE_W  to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP_EXEC_TRIPLE_A  to SPARQL_UPDATE',
    'grant execute on DB.DBA.TTLP_EXEC_TRIPLE_L_A  to SPARQL_UPDATE',
    'grant execute on DB.DBA.RDF_LOAD_RDFXML_MT to SPARQL_UPDATE',
    'grant execute on DB.DBA.RDF_LOAD_HTTP_RESPONSE to SPARQL_UPDATE',
    'grant execute on DB.DBA.RDF_FORGET_HTTP_RESPONSE to SPARQL_UPDATE',
    'grant execute on DB.DBA.RDF_SPONGE_UP to SPARQL_UPDATE' );
  foreach (varchar cmd in cmds) do
    {
      exec (cmd, state, msg);
    }
}
;

--!AFTER __PROCEDURE__ DB.DBA.USER_CREATE !
DB.DBA.RDF_CREATE_SPARQL_ROLES ()
;

--!AFTER __PROCEDURE__ DB.DBA.XML_URI_GET !
DB.DBA.SPARQL_RELOAD_QM_GRAPH ()
;

