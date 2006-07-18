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

create procedure DB.DBA.RDF_CREATE_SPARQL_ROLES ()
{
  declare state, msg varchar;
  exec ('create role SPARQL_SELECT', state, msg);
  exec ('create role SPARQL_UPDATE', state, msg);
  exec ('grant SPARQL_SELECT to SPARQL_UPDATE', state, msg);
}
;

DB.DBA.RDF_CREATE_SPARQL_ROLES()
;

create table DB.DBA.RDF_QUAD (
  G IRI_ID,
  S IRI_ID,
  P IRI_ID,
  O any,
  primary key (G,S,P,O)
  )
create index RDF_QUAD_PGOS on DB.DBA.RDF_QUAD (P, G, O, S)
;

grant select on DB.DBA.RDF_QUAD to SPARQL_SELECT
;

grant all on DB.DBA.RDF_QUAD to SPARQL_UPDATE
;

create table DB.DBA.RDF_URL (
  RU_IID IRI_ID not null primary key,
  RU_QNAME varchar )
create unique index RU_QNAME on DB.DBA.RDF_URL (RU_QNAME)
;

grant select on DB.DBA.RDF_URL to SPARQL_SELECT
;

grant all on DB.DBA.RDF_URL to SPARQL_UPDATE
;

create table DB.DBA.RDF_OBJ (
  RO_ID integeR primary key,
  RO_VAL varchar,
  RO_LONG long varchar
)
create index RO_VAL on DB.DBA.RDF_OBJ (RO_VAL)
;

grant select on DB.DBA.RDF_OBJ to SPARQL_SELECT
;

grant all on DB.DBA.RDF_OBJ to SPARQL_UPDATE
;

create table DB.DBA.RDF_DATATYPE (
  RDT_IID IRI_ID not null primary key,
  RDT_TWOBYTE integer not null unique,
  RDT_QNAME varchar )
;

grant select on DB.DBA.RDF_DATATYPE to SPARQL_SELECT
;

grant all on DB.DBA.RDF_DATATYPE to SPARQL_UPDATE
;

create table DB.DBA.RDF_LANGUAGE (
  RL_ID varchar not null primary key,
  RL_TWOBYTE integer not null unique )
;

grant select on DB.DBA.RDF_LANGUAGE to SPARQL_SELECT
;

grant all on DB.DBA.RDF_LANGUAGE to SPARQL_UPDATE
;

create table DB.DBA.SYS_SPARQL_HOST (
  SH_HOST	varchar not null primary key,
  SH_GRAPH_URI	varchar,
  SH_USER_URI	varchar )
;

grant select on DB.DBA.SYS_SPARQL_HOST to SPARQL_SELECT
;

grant all on DB.DBA.SYS_SPARQL_HOST to SPARQL_UPDATE
;

sequence_set ('RDF_URL_IID_NAMED', 1000000, 1)
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
  delete from DB.DBA.RDF_QUAD;
  delete from DB.DBA.RDF_URL;
  delete from DB.DBA.RDF_OBJ;
  delete from DB.DBA.RDF_DATATYPE;
  delete from DB.DBA.RDF_LANGUAGE;
  sequence_set ('RDF_URL_IID_NAMED', 1000000, 0);
  sequence_set ('RDF_URL_IID_BLANK', 1000000000, 0);
  sequence_set ('RDF_RO_ID', 1, 0);
  sequence_set ('RDF_DATATYPE_TWOBYTE', 258, 0);
  sequence_set ('RDF_LANGUAGE_TWOBYTE', 258, 0);
  __atomic (0);
--  checkpoint;
}
;

grant execute on DB.DBA.RDF_GLOBAL_RESET to SPARQL_UPDATE
;

-----
-- Handling of IRI IDs

create function DB.DBA.RDF_MAKE_IID_OF_QNAME (in qname varchar) returns IRI_ID
{
  if (__tag (qname) in (182, 217, 225, 230))
    {
      declare res IRI_ID;
      if (__tag (qname) <> 182)
        qname := cast (qname as varchar);
      if (qname like 'nodeID://%')
        signal ('RDFXX', 'Cannot make IID for nodeID:// in DB.DBA.RDF_MAKE_IID_OF_QNAME()');
      set isolation='commited';
      res := coalesce ((select RU_IID from DB.DBA.RDF_URL where RU_QNAME = qname));
      if (res is not null)
        return res;
      set isolation='serializable';
      res := coalesce ((select RU_IID from DB.DBA.RDF_URL where RU_QNAME = qname));
      if (res is not null)
        return res;
      res := iri_id_from_num (sequence_next ('RDF_URL_IID_NAMED'));
      insert into DB.DBA.RDF_URL (RU_IID, RU_QNAME) values (res, qname);
      commit work;
      return res;
    }
  if (qname is null)
    return null;
  signal ('RDFXX', 'Wrong tag of argument in DB.DBA.RDF_MAKE_IID_OF_QNAME()');
}
;

grant execute on DB.DBA.RDF_MAKE_IID_OF_QNAME to SPARQL_SELECT
;

create function DB.DBA.RDF_QNAME_OF_IID (in iid IRI_ID) returns varchar
{
  declare res varchar;
  if (not isiri_id (iid))
    signal ('RDFXX', 'Wrong type of argument in DB.DBA.RDF_QNAME_OF_IID()');
  if (iid >= #i1000000000)
    return sprintf ('nodeID://%d', iri_id_num (iid));
  res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = iid));
  if (res is null)
    signal ('RDFXX', 'Wrong iid in DB.DBA.RDF_QNAME_OF_IID()');
  return res;
}
;

grant execute on DB.DBA.RDF_QNAME_OF_IID to SPARQL_SELECT
;

create function DB.DBA.RDF_IID_OF_QNAME_SAFE (in qname varchar) returns IRI_ID
{
  set isolation='commited';
  if (__tag (qname) in (182, 217, 225, 230))
    return coalesce ((select RU_IID from DB.DBA.RDF_URL where RU_QNAME = qname));
  if (isiri_id (qname))
    return qname;
  return NULL;
}
;

grant execute on DB.DBA.RDF_IID_OF_QNAME_SAFE to SPARQL_SELECT
;

create function DB.DBA.RDF_IID_OF_QNAME (in qname varchar) returns IRI_ID
{
  set isolation='commited';
  if (__tag (qname) in (182, 217, 225, 230))
    return coalesce ((select RU_IID from DB.DBA.RDF_URL where RU_QNAME = qname));
  if (isiri_id (qname))
    return qname;
  signal ('RDFXX', 'Wrong tag of argument in DB.DBA.RDF_IID_OF_QNAME()');
}
;

grant execute on DB.DBA.RDF_IID_OF_QNAME to SPARQL_SELECT
;

create function DB.DBA.RDF_MAKE_GRAPH_IIDS_OF_QNAMES (in qnames any) returns any
{
  if (193 <> __tag (qnames))
    return vector ();
  declare res_acc any;
  vectorbld_init (res_acc);
  foreach (any qname in qnames) do
    {
      if (__tag (qname) in (182, 217, 225, 230))
        {
          declare iid IRI_ID;
          if (__tag (qname) <> 182)
            qname := cast (qname as varchar);
          iid := coalesce ((select RU_IID from DB.DBA.RDF_URL join DB.DBA.RDF_QUAD on (RU_IID = G) where RU_QNAME = qname));
          if (iid is not null)
            vectorbld_acc (res_acc, iid);
        }
    }
  vectorbld_final (res_acc);
  return res_acc;
}
;

grant execute on DB.DBA.RDF_MAKE_GRAPH_IIDS_OF_QNAMES to SPARQL_SELECT
;

-----
-- Datatypes and languages

create function DB.DBA.RDF_TWOBYTE_OF_DATATYPE (in iid IRI_ID) returns integer
{
  declare res integer;
  if (iid is null)
    return 257;
  whenever not found goto mknew;
  set isolation='commited';
  select RDT_TWOBYTE into res from DB.DBA.RDF_DATATYPE where RDT_IID = iid;
  return res;

mknew:
  whenever not found goto mknew_ser;
  set isolation='serializable';
  select RDT_TWOBYTE into res from DB.DBA.RDF_DATATYPE where RDT_IID = iid;
  return res;

mknew_ser:
  res := sequence_next ('RDF_DATATYPE_TWOBYTE');
  if (0 = bit_and (res, 255))
    res := sequence_next ('RDF_DATATYPE_TWOBYTE');
  insert into DB.DBA.RDF_DATATYPE
    (RDT_IID, RDT_TWOBYTE, RDT_QNAME)
  values (iid, res, DB.DBA.RDF_QNAME_OF_IID (iid));
  commit work;
  return res;
}
;

grant execute on DB.DBA.RDF_TWOBYTE_OF_DATATYPE to SPARQL_SELECT
;

create function DB.DBA.RDF_TWOBYTE_OF_LANGUAGE (in id varchar) returns integer
{
  declare res integer;
  if (id is null)
    return 257;
  whenever not found goto mknew;
  set isolation='commited';
  select RL_TWOBYTE into res from DB.DBA.RDF_LANGUAGE where RL_ID = id;
  return res;

mknew:
  whenever not found goto mknew_ser;
  set isolation='serializable';
  select RL_TWOBYTE into res from DB.DBA.RDF_LANGUAGE where RL_ID = id;

mknew_ser:
  res := sequence_next ('RDF_LANGUAGE_TWOBYTE');
  if (0 = bit_and (res, 255))
    res := sequence_next ('RDF_LANGUAGE_TWOBYTE');
  insert into DB.DBA.RDF_LANGUAGE (RL_ID, RL_TWOBYTE) values (id, res);
  commit work;
  return res;
}
;

grant execute on DB.DBA.RDF_TWOBYTE_OF_LANGUAGE to SPARQL_SELECT
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
  signal ('RDFXX', sprintf ('Unsupported tag in DB.DBA.RDF_DATATYPE_OF_TAG(): %d', t));
}
;

grant execute on DB.DBA.RDF_DATATYPE_OF_TAG to SPARQL_SELECT
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

grant execute on DB.DBA.RQ_LONG_OF_O to SPARQL_SELECT
;

create function DB.DBA.RQ_SQLVAL_OF_O (in o_col any) returns any
{
  declare t, l, len integer;
  if (isiri_id (o_col))
    {
      declare res varchar;
      if (o_col >= #i1000000000)
        return sprintf ('nodeID://%d', iri_id_num (o_col));
      res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = o_col));
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

grant execute on DB.DBA.RQ_SQLVAL_OF_O to SPARQL_SELECT
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

grant execute on DB.DBA.RDF_BOOL_OF_O to SPARQL_SELECT
;

create function DB.DBA.RQ_IID_OF_O (in shortobj any) returns IRI_ID
{
  if (not isiri_id (shortobj))
    return NULL;
  return shortobj;
}
;

grant execute on DB.DBA.RQ_IID_OF_O to SPARQL_SELECT
;

create function DB.DBA.RQ_O_IS_LIT (in shortobj any) returns integer
{
  if (isiri_id (shortobj))
    return 0;
  return 1;
}
;

grant execute on DB.DBA.RQ_O_IS_LIT to SPARQL_SELECT
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
      set isolation='commited';
      id := (select RO_ID from DB.DBA.RDF_OBJ where RO_VAL = tridgell and blob_to_string (RO_LONG) = v);
      if (id is null)
        {
          set isolation='serializable';
          id := (select RO_ID from DB.DBA.RDF_OBJ where RO_VAL = tridgell and blob_to_string (RO_LONG) = v);
          if (id is null)
            {
              id := sequence_next ('RDF_RO_ID');
              insert into DB.DBA.RDF_OBJ (RO_ID, RO_VAL, RO_LONG) values (id, tridgell, v);
              commit work;
            }
        }
    }
  else
    {
      set isolation='commited';
      id := (select RO_ID from DB.DBA.RDF_OBJ where RO_VAL = v);
      if (id is null)
        {
          set isolation='serializable';
          id := (select RO_ID from DB.DBA.RDF_OBJ where RO_VAL = v);
          if (id is null)
            {
              id := sequence_next ('RDF_RO_ID');
              insert into DB.DBA.RDF_OBJ (RO_ID, RO_VAL) values (id, v);
              commit work;
            }
        }
    }
  return id;
}
;

grant execute on DB.DBA.RDF_MAKE_RO_ID_OF_STRING to SPARQL_SELECT
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

grant execute on DB.DBA.RDF_FIND_RO_ID_OF_STRING to SPARQL_SELECT
;

create function DB.DBA.RDF_MAKE_OBJ_OF_SQLVAL (in v any) returns any
{
  declare l, t int;
  t := __tag (v);
  if (not t in (182, 217, 225, 230))
    return v;
  if (225 = t)
    v := charset_recode (v, '_WIDE_', 'UTF-8');
  else if (217 = t)
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

grant execute on DB.DBA.RDF_MAKE_OBJ_OF_SQLVAL to SPARQL_SELECT
;

create function DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL (in v any, in dt_iid IRI_ID, in lang varchar) returns any
{
  declare l, t, dt_twobyte, lang_twobyte int;
  declare dt_s, lang_s varchar;
  t := __tag (v);
  if (not t in (182, 217, 225, 230))
    signal ('RDFXX', 'DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL() accepts only string representations of typed values');
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

grant execute on DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL to SPARQL_SELECT
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

grant execute on DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL_STRINGS to SPARQL_SELECT
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

grant execute on DB.DBA.RDF_LONG_OF_OBJ to SPARQL_SELECT
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

grant execute on DB.DBA.RDF_DATATYPE_OF_OBJ to SPARQL_SELECT
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

grant execute on DB.DBA.RDF_LANGUAGE_OF_OBJ to SPARQL_SELECT
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
          res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = shortobj));
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

grant execute on DB.DBA.RDF_SQLVAL_OF_OBJ to SPARQL_SELECT
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

grant execute on DB.DBA.RDF_BOOL_OF_OBJ to SPARQL_SELECT
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
          res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = shortobj));
          if (res is null)
            signal ('RDFXX', 'Wrong iid in DB.DBA.RDF_QNAME_OF_OBJ()');
          return res;
        }
    }
  return NULL;
}
;

grant execute on DB.DBA.RDF_QNAME_OF_OBJ to SPARQL_SELECT
;

create function DB.DBA.RDF_STRSQLVAL_OF_OBJ (in shortobj any)
{
  declare t, l, len integer;
  if (isiri_id (shortobj))
    {
      declare res varchar;
      if (shortobj >= #i1000000000)
        return sprintf ('nodeID://%d', iri_id_num (shortobj));
      res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = shortobj));
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

grant execute on DB.DBA.RDF_STRSQLVAL_OF_OBJ to SPARQL_SELECT
;


create function DB.DBA.RDF_OBJ_OF_LONG (in longobj any) returns any
{
  if (193 <> __tag(longobj))
    return longobj;
  if (isstring (longobj[4]))
    return longobj[4];
  if (length (longobj) > 5)
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
  return DB.DBA.RDF_OBJ_OF_SQLVAL (longobj[2]);
}
;

grant execute on DB.DBA.RDF_OBJ_OF_LONG to SPARQL_SELECT
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

grant execute on DB.DBA.RDF_OBJ_OF_SQLVAL to SPARQL_SELECT
;

-----
-- Functions for long object representation.

create function DB.DBA.RDF_MAKE_LONG_OF_SQLVAL (in v any) returns any
{
  declare l, t int;
  t := __tag (v);
  if (not t in (182, 217, 225, 230))
    return v;
  if (225 = t)
    v := charset_recode (v, '_WIDE_', 'UTF-8');
  else if (217 = t)
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

grant execute on DB.DBA.RDF_MAKE_LONG_OF_SQLVAL to SPARQL_SELECT
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

grant execute on DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL to SPARQL_SELECT
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

grant execute on DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL_STRINGS to SPARQL_SELECT
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
          res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = longobj));
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

grant execute on DB.DBA.RDF_SQLVAL_OF_LONG to SPARQL_SELECT
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

grant execute on DB.DBA.RDF_BOOL_OF_LONG to SPARQL_SELECT
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

grant execute on DB.DBA.RDF_DATATYPE_OF_LONG to SPARQL_SELECT
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

grant execute on DB.DBA.RDF_LANGUAGE_OF_LONG to SPARQL_SELECT
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
      res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = longobj));
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

grant execute on DB.DBA.RDF_STRSQLVAL_OF_LONG to SPARQL_SELECT
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

grant execute on DB.DBA.RDF_LONG_OF_SQLVAL to SPARQL_SELECT
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
      res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = sqlval));
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

grant execute on DB.DBA.RDF_DATATYPE_OF_SQLVAL to SPARQL_SELECT
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

grant execute on DB.DBA.RDF_QUAD_URI to SPARQL_UPDATE
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

grant execute on DB.DBA.RDF_QUAD_URI_L to SPARQL_UPDATE
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

grant execute on DB.DBA.RDF_QUAD_URI_L_TYPED to SPARQL_UPDATE
;

create procedure DB.DBA.TTLP_EXEC_NEW_GRAPH (in g varchar, inout app_env any) {
  -- dbg_obj_princ ('DB.DBA.TTLP_EXEC_NEW_GRAPH(', g, app_env, ')');
  ;
}
;

grant execute on DB.DBA.TTLP_EXEC_NEW_GRAPH to SPARQL_UPDATE
;

create function DB.DBA.TTLP_EXEC_NEW_BLANK (in g varchar, inout app_env any) returns IRI_ID {
  declare res IRI_ID;
  res := iri_id_from_num (sequence_next ('RDF_URL_IID_BLANK'));
  -- dbg_obj_princ ('DB.DBA.TTLP_EXEC_NEW_BLANK (', g, app_env, ') returns ', res);
  return res;
}
;

grant execute on DB.DBA.TTLP_EXEC_NEW_BLANK to SPARQL_UPDATE
;

create function DB.DBA.TTLP_EXEC_GET_IID (in uri varchar, in g varchar, inout app_env any) returns IRI_ID {
  declare res IRI_ID;
  -- dbg_obj_princ ('DB.DBA.TTLP_EXEC_GET_IID (', uri, g, app_env, ')');
  res := DB.DBA.RDF_MAKE_IID_OF_QNAME (uri);
  -- dbg_obj_princ ('DB.DBA.TTLP_EXEC_GET_IID (', uri, g, app_env, ') returns ', res);
  return res;
}
;

grant execute on DB.DBA.TTLP_EXEC_GET_IID to SPARQL_UPDATE
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

grant execute on DB.DBA.TTLP_EXEC_TRIPLE to SPARQL_UPDATE
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

grant execute on DB.DBA.TTLP_EXEC_TRIPLE_L to SPARQL_UPDATE
;

create procedure DB.DBA.TTLP (in strg varchar, in base varchar, in graph varchar)
{
  return rdf_load_turtle (strg, base, graph,
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

grant execute on DB.DBA.TTLP to SPARQL_UPDATE
;

create procedure DB.DBA.RDF_TTL2HASH_EXEC_NEW_GRAPH (in g varchar, inout app_env any) {
  -- dbg_obj_princ ('DB.DBA.RDF_TTL2HASH_EXEC_NEW_GRAPH(', g, app_env, ')');
  ;
}
;

grant execute on DB.DBA.RDF_TTL2HASH_EXEC_NEW_GRAPH to SPARQL_SELECT
;

create function DB.DBA.RDF_TTL2HASH_EXEC_NEW_BLANK (in g varchar, inout app_env any) returns IRI_ID {
  declare res IRI_ID;
  res := iri_id_from_num (sequence_next ('RDF_URL_IID_BLANK'));
  -- dbg_obj_princ ('DB.DBA.RDF_TTL2HASH_EXEC_NEW_BLANK (', g, app_env, ') returns ', res);
  return res;
}
;

grant execute on DB.DBA.RDF_TTL2HASH_EXEC_NEW_BLANK to SPARQL_SELECT
;

create function DB.DBA.RDF_TTL2HASH_EXEC_GET_IID (in uri varchar, in g varchar, inout app_env any) returns IRI_ID {
  declare res IRI_ID;
  -- dbg_obj_princ ('DB.DBA.RDF_TTL2HASH_EXEC_GET_IID (', uri, g, app_env, ')');
  res := DB.DBA.RDF_MAKE_IID_OF_QNAME (uri);
  -- dbg_obj_princ ('DB.DBA.RDF_TTL2HASH_EXEC_GET_IID (', uri, g, app_env, ') returns ', res);
  return res;
}
;

grant execute on DB.DBA.RDF_TTL2HASH_EXEC_GET_IID to SPARQL_SELECT
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

grant execute on DB.DBA.RDF_TTL2HASH_EXEC_TRIPLE to SPARQL_SELECT
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

grant execute on DB.DBA.RDF_TTL2HASH_EXEC_TRIPLE_L to SPARQL_SELECT
;

create function DB.DBA.RDF_TTL2HASH (in str varchar, in base varchar, in graph varchar) returns any
{
  declare res any;
  res := dict_new ();
  rdf_load_turtle (str, base, graph,
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

grant execute on DB.DBA.RDF_TTL2HASH to SPARQL_SELECT
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

grant execute on DB.DBA.RDF_LOAD_RDFXML to SPARQL_UPDATE
;

create procedure DB.DBA.RDF_RDFXML_TO_DICT (in strg varchar, in base varchar, in graph varchar)
{
  declare res any;
  res := dict_new ();
  rdf_load_rdfxml (strg, 0,
    graph,
    vector (
      'DB.DBA.TTL2HASH_EXEC_NEW_GRAPH(?,?)',
      'select DB.DBA.TTL2HASH_EXEC_NEW_BLANK(?,?)',
      'select DB.DBA.TTL2HASH_EXEC_GET_IID(?,?,?)',
      'DB.DBA.TTL2HASH_EXEC_TRIPLE(?,?, ?,?, ?,?, ?,?, ?)',
      'DB.DBA.TTL2HASH_EXEC_TRIPLE_L(?,?, ?,?, ?,?, ?,?,?, ?)',
      'isinteger(0)' ),
    res,
    base );
  return res;
}
;

grant execute on DB.DBA.RDF_RDFXML_TO_DICT to SPARQL_UPDATE
;


-----
-- Export into external serializations

create procedure DB.DBA.RDF_TRIPLES_TO_TTL (inout triples any, inout ses any)
{
  declare tcount, tctr integer;
  tcount := length (triples);
  -- dbg_obj_princ ('DB.DBA.RDF_TRIPLES_TO_TTL:');
  for (tctr := 0; tctr < tcount; tctr := tctr + 1)
    -- dbg_obj_princ (triples[tctr]);
  for (tctr := 0; tctr < tcount; tctr := tctr + 1)
    {
      declare subj,pred,obj any;
      declare res varchar;
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
          res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = subj));
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
          res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = pred));
          http ('<', ses);
          http_escape (res, 12, ses, 1, 1);
          http ('> ', ses);
        }
      if (obj is null)
        signal ('RDFXX', 'DB.DBA.TRIPLES_TO_TTL(): object is NULL');
      if (isiri_id (obj))
        {
          if (obj >= #i1000000000)
            http (sprintf ('_:b%d ', iri_id_num (obj)), ses);
          else
            {
              res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = obj), sprintf ('_:bad_iid_%d', iri_id_num (obj)));
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
      http ('.\n', ses);
    }
}
;

grant execute on DB.DBA.RDF_TRIPLES_TO_TTL to SPARQL_SELECT
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
          res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = subj));
          http (' about="', ses); http_value (res, 0, ses); http ('">', ses);
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
          res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = pred));
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
              res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = obj), sprintf ('_:bad_iid_%d', iri_id_num (obj)));
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

grant execute on DB.DBA.RDF_TRIPLES_TO_RDF_XML_TEXT to SPARQL_SELECT
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

grant execute on DB.DBA.RDF_FORMAT_RESULT_SET_AS_TTL_INIT to SPARQL_SELECT
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
              res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = _val));
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

grant execute on DB.DBA.RDF_FORMAT_RESULT_SET_AS_TTL_ACC to SPARQL_SELECT
;

create function DB.DBA.RDF_FORMAT_RESULT_SET_AS_TTL_FIN (inout _env any) returns long varchar
{
  if (185 <> __tag(_env))
    DB.DBA.RDF_FORMAT_RESULT_SET_AS_TTL_INIT (_env);

  http ('\n    ] .', _env);
  return string_output_string (_env);
}
;

grant execute on DB.DBA.RDF_FORMAT_RESULT_SET_AS_TTL_FIN to SPARQL_SELECT
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

grant execute on DB.DBA.RDF_FORMAT_RESULT_SET_AS_RDF_XML_INIT to SPARQL_SELECT
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
              res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = _val));
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

grant execute on DB.DBA.RDF_FORMAT_RESULT_SET_AS_RDF_XML_ACC to SPARQL_SELECT
;

create function DB.DBA.RDF_FORMAT_RESULT_SET_AS_RDF_XML_FIN (inout _env any) returns long varchar
{
  if (185 <> __tag(_env))
    DB.DBA.RDF_FORMAT_RESULT_SET_AS_RDF_XML_INIT (_env);

  http ('\n </rs:results>\n</rdf:RDF>', _env);
  return string_output_string (_env);
}
;

grant execute on DB.DBA.RDF_FORMAT_RESULT_SET_AS_RDF_XML_FIN to SPARQL_SELECT
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

grant execute on DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_TTL to SPARQL_SELECT
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

grant execute on DB.DBA.RDF_FORMAT_TRIPLE_DICT_AS_RDF_XML to SPARQL_SELECT
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
  if (not isiri (graph_iri))
    graph_iri := DB.DBA.RDF_MAKE_IID_FROM_QNAME (graph_iri);
  for (ctr := length (triples) - 1; ctr >= 0; ctr := ctr - 1)
    {
      insert replacing DB.DBA.RDF_QUAD (G,S,P,O)
      values (graph_iri, triples[ctr][0], triples[ctr][1], DB.DBA.RDF_OBJ_OF_LONG (triples[ctr][2]));
    }
}
;

grant execute on DB.DBA.RDF_INSERT_TRIPLES to SPARQL_UPDATE
;

create function DB.DBA.RDF_DELETE_TRIPLES (in graph_iri any, in triples any)
{
  declare ctr integer;
  if (not isiri (graph_iri))
    graph_iri := DB.DBA.RDF_MAKE_IID_FROM_QNAME (graph_iri);
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

grant execute on DB.DBA.RDF_DELETE_TRIPLES to SPARQL_UPDATE
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
                signal ('RDF01', sprintf ('Bad variable value in CONSTRUCT: only object of a triple can be a literal like "%.30s"', DB.DBA.RDF_STRSQLVAL_OF_LONG (i)));
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
              if ((2 > fld_ctr) and not isiri_id (arg))
                signal ('RDF01', sprintf ('Bad const value in CONSTRUCT: only object of a triple can be a literal like "%.30s"', DB.DBA.RDF_STRSQLVAL_OF_LONG (arg)));
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

create aggregate DB.DBA.SPARQL_CONSTRUCT (in opcodes any, in vars any, in stats any) returns any
from DB.DBA.SPARQL_CONSTRUCT_INIT, DB.DBA.SPARQL_CONSTRUCT_ACC, DB.DBA.SPARQL_CONSTRUCT_FIN
;

create procedure DB.DBA.SPARQL_DESCRIBE_INIT (inout _env any)
{
  _env := 0; -- No actual initialization
}
;

grant execute on DB.DBA.SPARQL_DESCRIBE_INIT to SPARQL_SELECT
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

grant execute on DB.DBA.SPARQL_DESCRIBE_ACC to SPARQL_SELECT
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
-- The commented-out code below is to debug DESCRIBE functionaly using server's console.
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

grant execute on DB.DBA.SPARQL_DESCRIBE_FIN to SPARQL_SELECT
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

grant execute on DB.DBA.RDF_DESCRIBE_PUT to SPARQL_SELECT
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

grant execute on DB.DBA.RDF_TYPEMIN_OF_OBJ to SPARQL_SELECT
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

grant execute on DB.DBA.RDF_TYPEMAX_OF_OBJ to SPARQL_SELECT
;

create function DB.DBA.RDF_IID_CMP (in obj1 any, in obj2 any) returns integer
{
  return NULL;
}
;

grant execute on DB.DBA.RDF_IID_CMP to SPARQL_SELECT
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

grant execute on DB.DBA.RDF_OBJ_CMP to SPARQL_SELECT
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

grant execute on DB.DBA.RDF_LONG_CMP to SPARQL_SELECT
;

-----
-- JSO procedures

create function JSO_LOAD_INSTANCE (in jgraph varchar, in jinst varchar, in delete_first integer, in make_new integer)
{
  declare jinst_iri_id, jgraph_iri_id IRI_ID;
  declare jclass varchar;
  dbg_obj_princ ('JSO_LOAD_INSTANCE (', jgraph, ')');
  jinst_iri_id := DB.DBA.RDF_MAKE_IID_OF_QNAME (jinst);
  jgraph_iri_id := DB.DBA.RDF_MAKE_IID_OF_QNAME (jgraph);
  jclass := (sparql
#    define input:storage ""
    select ?t
    where {
      graph ?:jgraph {
        { ?:jinst rdf:type ?t }
        union
        { ?s rdf:type ?t .
          ?s rdf:name ?ji .
          filter (str (?ji) = ?:jinst)
          } } } );
  if (jclass is null)
    {
      if (exists (sparql
#          define input:storage ""
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
  for (sparql
#      define input:storage ""      
      select ?p ?o
      where {
        graph ?:jgraph {
          { ?:jinst ?p ?o .
            filter (!isBLANK (?o))
            }
          union
          { ?:jinst ?p ?n .
            ?n rdf:name ?o .
            filter (isBLANK (?n))
            }
          union
          { ?s rdf:name ?ji .
            ?s ?p ?o .
            filter ((str (?ji) = ?:jinst) && !isBLANK (?o))
            }
          union
          { ?s rdf:name ?ji .
            ?s ?p ?n .
            ?n rdf:name ?o .
            filter ((str (?ji) = ?:jinst) && isBLANK (?n))
            }
        } } ) do
    {
      if ('http://www.w3.org/1999/02/22-rdf-syntax-ns#type' = "p")
        {
	  if ("o" <> jclass)
            signal ('22023', 'JSO_LOAD_INSTANCE has found that the object <' || jinst || '> has multiple type declarations');
	}
      else if ('http://www.w3.org/1999/02/22-rdf-syntax-ns#name' = "p")
        ;
      else if ('http://www.openlinksw.com/schemas/virtrdf#inheritFrom' = "p")
        ;
      else if ('http://www.openlinksw.com/schemas/virtrdf#noInherit' = "p")
        ;
      else
        jso_set (jclass, jinst, "p", "o");
    }
}
;

create procedure JSO_LIST_INSTANCES_OF_GRAPH (in jgraph varchar, out instances any)
{
  instances := (
    select vector_agg (vector ("jclass", "jinst"))
    from ( sparql
#      define input:storage ""      
      select ?jclass ?jinst
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
}
;

create function JSO_LOAD_GRAPH (in jgraph varchar, in pin_now integer := 1)
{
  declare jgraph_iri_id IRI_ID;
  declare instances any;
  dbg_obj_princ ('JSO_LOAD_GRAPH (', jgraph, ')');
  jgraph_iri_id := DB.DBA.RDF_MAKE_IID_OF_QNAME (jgraph);
  JSO_LIST_INSTANCES_OF_GRAPH (jgraph, instances);
-- Pass 1. Deleting all obsolete instances.
  foreach (any j in instances) do
    jso_delete (j[0], j[1], 1);
-- Pass 2. Creating all instances.
  foreach (any j in instances) do
    jso_new (j[0], j[1]);
-- Pass 3. Loading all instances.
  foreach (any j in instances) do
    JSO_LOAD_INSTANCE (jgraph, j[1], 0, 0);
-- Pass 4. Making the inheritance.
  for (sparql
#    define input:storage ""      
    prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
    select ?jdestclass ?dest ?pred ?srcpredval
    where {
        graph ?:jgraph {
            ?dest rdf:type ?jdestclass .
            ?dest virtrdf:inheritFrom ?src .
            ?src ?pred ?srcpredval
            optional {
              ?dest1 virtrdf:noInherit ?pred
              filter (?dest1 = ?dest) }
            optional {
              ?dest ?pred ?destval }
            filter (!bound (?dest1) && !bound (?destval))
          } } ) do
    jso_set ("jdestclass", "dest", "pred", "srcpredval");
-- Pass 5. Validation all instances.
  foreach (any j in instances) do
    jso_validate (j[0], j[1], 1);
-- Pass 6. Pin all instances.
  if (pin_now)
    JSO_PIN_GRAPH (jgraph);
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

grant execute on DB.DBA.SPARQL_EVAL_TO_ARRAY to SPARQL_SELECT
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

grant execute on DB.DBA.SPARQL_EVAL to SPARQL_SELECT
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
  local_req_hdr := 'Accept: application/sparql-results+xml, text/rdf+n3, application/rdf+xml';
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
  if (ret_content_type is null)
    {
      declare ret_begin, ret_html any;
      ret_begin := "LEFT" (ret_body, 1024);
      ret_html := xtree_doc (ret_begin, 2);
      if (xpath_eval ('/html|/xhtml', ret_html) is not null)
        ret_content_type := 'text/html';
      else if (xpath_eval ('[xmlns:rset="http://www.w3.org/2005/sparql-results#"] /rset:sparql', ret_html) is not null)
        ret_content_type := 'application/sparql-results+xml';
      else if (xpath_eval ('[xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"] /rdf:rdf', ret_html) is not null)
        ret_content_type := 'application/rdf+xml';
      else if (strstr (ret_begin, '<html>') is not null or
        strstr (ret_begin, '<xhtml>') is not null )
        ret_content_type := 'text/html';
      else
        ret_content_type := 'text/plain';
    }
  if (strstr (ret_content_type, 'application/sparql-results+xml') is not null)
    {
      declare ret_xml, var_list, var_metas, ret_row, out_nulls any;
      declare var_ctr, var_count integer;
      declare vect_acc any;
      -- dbg_obj_princ ('application/sparql-results+xml ret_body=', ret_body);
      ret_xml := xtree_doc (ret_body, 0);
      var_list := xpath_eval ('[xmlns:rset="http://www.w3.org/2005/sparql-results#"] /rset:sparql/rset:head/rset:variable', ret_xml, 0);
      if (0 = length (var_list))
        {
	  declare bool_ret any;
          bool_ret := xpath_eval ('[xmlns:rset="http://www.w3.org/2005/sparql-results#"] /rset:sparql/rset:boolean', ret_xml);
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
      for (ret_row := xpath_eval ('[xmlns:rset="http://www.w3.org/2005/sparql-results#"] /rset:sparql/rset:results/rset:result', ret_xml);
        ret_row is not null;
        ret_row := xpath_eval ('[xmlns:rset="http://www.w3.org/2005/sparql-results#"] following-sibling::rset:result', ret_row) )
        {
          declare out_fields, ret_cols any;
          declare col_ctr, col_count integer;
          out_fields := out_nulls;
          ret_cols := xpath_eval ('[xmlns:rset="http://www.w3.org/2005/sparql-results#"] rset:binding', ret_row, 0);
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
      declare res_xml any;
      declare res_dict any;
      res_xml := xtree_doc (ret_body);
      res_dict := DB.DBA.RDF_EXP_RDFXML2DICT ('http://local.virt/tmp', res_xml);
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
      res_dict := DB.DBA.RDF_TTL2HASH (ret_body, '', '');
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
          service, ret_content_type, ret_hdr[0], ret_body ) );
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

grant execute on DB.DBA.SPARQL_REXEC to SPARQL_SELECT
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

grant execute on DB.DBA.SPARQL_REXEC_TO_ARRAY to SPARQL_SELECT
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

grant execute on DB.DBA.SPARQL_REXEC_WITH_META to SPARQL_SELECT
;

-----
-- SPARQL SOAP web service (incomplete, do not try to use in applications!)

create procedure
"querySoap"  (in  "Command" varchar
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

--sparql-protocol-query/#:querySoap

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
	      http (sprintf ('\n   <binding name="%s"><bnode>nodeID://%d</bnode></binding>', _name, iri_id_num (_val)));
	    }
	  else
	    {
              declare res varchar;
              res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = _val));
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
    http ('document.writeln(\'', tmp_ses);
    SPARQL_RESULTS_JAVASCRIPT_HTML_WRITE(tmp_ses,metas,rset,0);
	  tmp_str := string_output_string(tmp_ses);
	  tmp_str := replace(tmp_str, '\n', '\');\ndocument.writeln(\'');
	  http (tmp_str, ses);
	  http ('\');', ses);
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
                http (sprintf ('"type": "bnode", "value": "_%d" }', iri_id_num (val)), ses);
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
  declare ret_mime varchar;
  if ((1 = length (metas[0])) and
    ('__ask_retval' = metas[0][0][0]) )
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
    }
  else if ((1 = length (rset)) and
    (1 = length (rset[0])) and
    (214 = __tag (rset[0][0])) )
    {
      declare triples any;
      triples := dict_list_keys (rset[0][0], 1);
      if (strstr (accept, 'text/rdf+n3') is not null)
        {
          ret_mime := 'text/rdf+n3';
          DB.DBA.RDF_TRIPLES_TO_TTL (triples, ses);
	}
      else
        {
          ret_mime := 'application/rdf+xml';
          DB.DBA.RDF_TRIPLES_TO_RDF_XML_TEXT (triples, 1, ses);
	}
    }
  else if (strstr (accept, 'application/sparql-results+json') is not null or strstr (accept, 'application/json') is not null)
    {
      if (strstr (accept, 'application/sparql-results+json') is not null)
        ret_mime := 'application/sparql-results+json';
      else
        ret_mime := 'application/json';
      SPARQL_RESULTS_JSON_WRITE (ses, metas, rset);
    }
  else if (strstr (accept, 'text/html') is not null)
    {
      ret_mime := 'text/html';
      SPARQL_RESULTS_JAVASCRIPT_HTML_WRITE(ses, metas, rset, 0);
    }
  else if (strstr (accept, 'application/javascript') is not null)
    {
      ret_mime := 'application/javascript';
      SPARQL_RESULTS_JAVASCRIPT_HTML_WRITE(ses, metas, rset, 1);
    }
  else
    {
      ret_mime := 'application/sparql-results+xml';
      SPARQL_RESULTS_XML_WRITE_NS (ses);
      SPARQL_RESULTS_XML_WRITE_HEAD (ses, metas);
      SPARQL_RESULTS_XML_WRITE_RES (ses, metas, rset);
      http ('\n</sparql>', ses);
    }
  if (add_http_headers)
    http_header ('Content-Type: ' || ret_mime || '\r\n');
  return ret_mime;
}
;

-- CLIENT --
--select -- dbg_obj_princ (soap_client (url=>'http://neo:6666/SPARQL', operation=>'querySoap', target_namespace=>'urn:FIXME', soap_action =>'urn:FIXME:querySoap', parameters=> vector ('Command', soap_box_structure ('Statement' , 'select TEST from DB.DBA.SPARQL_TABLE3'), 'Properties', soap_box_structure ('PropertyList', 'None' )), style=>2));


create procedure SPARQL_USER_INIT ()
{
  if (exists (select 1 from "DB"."DBA"."SYS_USERS" where U_NAME = 'SPARQL'))
    return;
  DB.DBA.USER_CREATE ('SPARQL', uuid(), vector ('DISABLED', 1, 'LOGIN_QUALIFIER', 'SPARQL'));
}
;

SPARQL_USER_INIT ()
;


VHOST_REMOVE (lpath=>'/SPARQL')
;

VHOST_REMOVE (lpath=>'/sparql')
;

VHOST_REMOVE (lpath=>'/services/sparql-query')
;

VHOST_DEFINE (lpath=>'/services/sparql-query', ppath=>'/SOAP/', soap_user=>'SPARQL',
              soap_opts => vector ('ServiceName', 'XMLAnalysis', 'elementFormDefault', 'qualified'))
;

grant execute on DB.."querySoap" to "SPARQL"
;


-----
-- SPARQL HTTP request handler

DB.DBA.VHOST_DEFINE (lpath=>'/sparql/', ppath=>'/!sparql/', is_dav=>1, vsp_user=>'dba', opts=>vector('noinherit', 1))
;

create procedure DB.DBA.SPARQL_PROTOCOL_ERROR_REPORT (
  inout path varchar, inout params any, inout lines any,
  in httpcode varchar, in httpstatus varchar,
  in query varchar, in state varchar, in msg varchar)
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

create procedure WS.WS."/!sparql/" (inout path varchar, inout params any, inout lines any)
{
  declare query, dflt_graph, full_query, format varchar;
  declare named_graphs any;
  declare paramctr, paramcount, maxrows integer;
  declare ses any;
  ses := 0;
  query := null;
  dflt_graph := null;
  format := '';
  named_graphs := vector ();
  maxrows := 1024*1024; -- More than enough for web-interface.
  declare exit handler for sqlstate '*' {
    DB.DBA.SPARQL_PROTOCOL_ERROR_REPORT (path, params, lines,
      '500', 'SPARQL Request Failed',
      query, __SQL_STATE, __SQL_MESSAGE );
     return;
   };
  paramcount := length (params);
  if ((0 = paramcount) or ((2 = paramcount) and ('Content' = params[0])))
    {
       declare redir varchar;
       redir := registry_get ('WS.WS.SPARQL_DEFAULT_REDIRECT');
       if (isstring (redir))
         {
            http_request_status ('HTTP/1.1 301 Moved Permanently');
            http_header (sprintf ('Location: %s\r\n', redir));
            return;
         }
http('<html xmlns="http://www.w3.org/1999/xhtml">');
http('	<head>');
http('		<title>Virtuoso SPARQL Query Form</title>');
http('		<style type="text/css">');
http('label.n');
http('{ display: inline; margin-top: 10pt; }');
http('body { font-family: arial, helvetica, sans-serif; font-size: 9pt; color: #234; }');
http('fieldset { border: 2px solid #86b9d9; }');
http('legend { font-size: 12pt; color: #86b9d9; }');
http('label { font-weight: bold; }');
http('h1 { width: 100%; background-color: #86b9d9; font-size: 18pt; font-weight: normal; color: #fff; height: 4ex; text-align: right; vertical-align: middle; padding-right:  8px; }');
http('		</style>');
http('	</head>');
http('	<body>');
http('		<div id="header">');
http('			<h1>OpenLink Virtuoso SPARQL Query</h1>');
http('		</div>');
http('		<div id="main">');
http('			<form action="" method="GET">');
http('			<fieldset>');
http('			<legend>Query</legend>');
http('			  <label for="default-graph-uri">Default Graph URI</label>');
http('			  <br />');
http('			  <input type="text" name="default-graph-uri" id="default-graph-uri"');
http('				  	value="" size="80"/>');
http('			  <br /><br />');
http('			  <label for="query">Query text</label>');
http('			  <br />');
http('			  <textarea rows="10" cols="60" name="query" id="query">SELECT * WHERE {?s ?p ?o}</textarea>');
http('			  <br /><br />');
--http('			  <label for="maxrows">Max Rows:</label>');
--http('			  <input type="text" name="maxrows" id="maxrows"');
--http(sprintf('				  	value="%d"/>',maxrows));
--http('			  <br />');
http('			  <label for="format" class="n">Display Results As:</label>');
http('			  <select name="format">');
http('			    <option value="text/html" selected="selected">HTML</option>');
http('			    <option value="application/sparql-results+xml">XML</option>');
http('			    <option value="text/rdf+n3">TURTLE</option>');
http('			    <option value="application/sparql-results+json">JSON</option>');
http('			    <option value="application/javascript">Javascript</option>');
http('			  </select>');
http('			  <input type="submit" value="Run Query"/>');
http('			  <input type="reset" value="Reset"/>');
http('			</fieldset>');
http('			</form>');
http('		</div>');
http('	</body>');
http('</html>');
       return;
    }
  for (paramctr := 0; paramctr < paramcount; paramctr := paramctr + 2)
    {
      declare pname, pvalue varchar;
      pname := params [paramctr];
      pvalue := params [paramctr+1];
      if ('query' = pname)
        query := pvalue;
      else if ('default-graph-uri' = pname)
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
      else if ('format' = pname)
        {
	  format := pvalue;
	}
    }
  if (query is null)
    {
      if (strstr (http_request_header (lines, 'Content-Type', null, ''), 'application/xml') is not null)
        {
          DB.DBA.SPARQL_PROTOCOL_ERROR_REPORT (path, params, lines,
            '400', 'Bad Request',
	    query, '22023', 'XML notation of SPARQL queries is not supported' );
	  return;
	}
      DB.DBA.SPARQL_PROTOCOL_ERROR_REPORT (path, params, lines,
        '400', 'Bad Request',
        query, '22023', 'The request does not contain text of SPARQL query' );
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
  full_query := concat ('define output:valmode "LONG" ', full_query);
  declare sqltext, state, msg varchar;
  declare metas, rset any;
--  sqltext := string_output_string (sparql_to_sql_text (query));
  state := '00000';
  metas := null;
  rset := null;
  exec ('string_output_string (sparql_to_sql_text (?))', state, msg, vector (full_query));
  if (state <> '00000')
    {
      DB.DBA.SPARQL_PROTOCOL_ERROR_REPORT (path, params, lines,
        '400', 'Bad Request',
	query, state, msg );
      return;
    }
  sqltext := string_output_string (sparql_to_sql_text (full_query));
  state := '00000';
  metas := null;
  rset := null;
  connection_set (':default_graph', dflt_graph);
  connection_set (':named_graphs', named_graphs);
  http_header (sprintf ('X-SPARQL-default-graph: %U\r\n', dflt_graph));
--  http (sprintf ('<!-- X-SPARQL-default-graph: %U\r\n -->\n', dflt_graph));
--  http ('<!-- Query:\n' || query || '\n-->\n', 0);
  exec (sqltext, state, msg, vector(), maxrows, metas, rset);
  -- dbg_obj_princ ('exec metas=', metas);
  if (state <> '00000')
    {
      DB.DBA.SPARQL_PROTOCOL_ERROR_REPORT (path, params, lines,
        '500', 'SPARQL Request Failed',
	query, state, msg );
      return;
    }
  declare accept varchar;
  accept := http_request_header (lines, 'Accept', null, '');
  if (format <> '')
    accept := format;
  DB.DBA.SPARQL_RESULTS_WRITE (ses, metas, rset, accept, 1);
}
;

registry_set ('/!sparql/', 'no_vsp_recompile')
;




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
      insert soft  DB.DBA.RDF_QUAD (G,S,P,O)
      values (g_iid, s_iid, p_iid,
        DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL (
          o_val,
          DB.DBA.RDF_MAKE_IID_OF_QNAME (o_type),
          o_lang ) );
      return;
    }
  app_env[1] := aq_request (app_env[0], 'DB.DBA.TTLP_EXEC_TRIPLE_W', vector  (g_iid, s_iid, p_iid, DB.DBA.RDF_MAKE_OBJ_OF_SQLVAL (o_val)));
  if (mod (app_env[1], 4000) = 0)
    {
      commit work;
      aq_wait (app_env[0], app_env[1], err, 1);
      aq_wait_all (app_env[0]);
    }
}
;


create procedure DB.DBA.TTLP_MT (in strg varchar, in base varchar, in graph varchar)
{
  declare app_env, err any;
  app_env := vector (async_queue (6), 0);
  rdf_load_turtle (strg, base, graph,
    vector (
      'DB.DBA.TTLP_EXEC_NEW_GRAPH(?,?)',
      'select DB.DBA.TTLP_EXEC_NEW_BLANK(?,?)',
      'select DB.DBA.TTLP_EXEC_GET_IID(?,?,?)',
      'DB.DBA.TTLP_EXEC_TRIPLE_A(?,?, ?,?, ?,?, ?,?, ?)',
      'DB.DBA.TTLP_EXEC_TRIPLE_L_A(?,?, ?,?, ?,?, ?,?,?, ?)',
      'commit work' ),
    app_env);
  commit work;
  aq_wait (app_env[0], app_env[1], err, 1);
  aq_wait_all (app_env[0]);
}


grant execute on DB.DBA.TTLP_MT  to SPARQL_UPDATE
;
grant execute on  DB.DBA.TTLP_EXEC_TRIPLE_W  to SPARQL_UPDATE
;
