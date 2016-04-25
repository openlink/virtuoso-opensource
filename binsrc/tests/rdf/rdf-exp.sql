--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2016 OpenLink Software
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
drop table DB.DBA.RDF_QUAD;
drop table DB.DBA.RDF_OBJ;
drop table DB.DBA.RDF_URL;
drop table DB.DBA.RDF_DATATYPE;
drop table DB.DBA.RDF_LANGUAGE;

create table DB.DBA.RDF_QUAD (
  G IRI,
  S IRI,
  P IRI,
  O any,
  primary key (G,S,P,O)
  )
;

create index RDF_QUAD_PGOS on DB.DBA.RDF_QUAD (P, G, O, S)
;

create table DB.DBA.RDF_URL (
  RU_IID IRI not null primary key,
  RU_QNAME varchar )
;

create unique index RU_QNAME on DB.DBA.RDF_URL (RU_QNAME)
;

create table DB.DBA.RDF_OBJ (
  RO_ID integeR primary key,
  RO_VAL varchar,
  RO_LONG long varchar
)
;

create table DB.DBA.RDF_DATATYPE (
  RDT_IID IRI not null primary key,
  RDT_TWOBYTE integer not null unique,
  RDT_QNAME varchar );

create table DB.DBA.RDF_LANGUAGE (
  RL_ID varchar not null primary key,
  RL_TWOBYTE integer not null unique );


sequence_set ('RDF_URL_IID_NAMED', 1000000, 0)
;

sequence_set ('RDF_URL_IID_BLANK', 1000000000, 0)
;

sequence_set ('RDF_RO_ID', 1, 0)
;

sequence_set ('RDF_DATATYPE_TWOBYTE', 258, 0)
;

sequence_set ('RDF_LANGUAGE_TWOBYTE', 258, 0)
;

create index RO_VAL on DB.DBA.RDF_OBJ (RO_VAL)
;

-- create text index on DB.DBA.RDF_OBJ (RO_VAL) with key RO_ID
-- ;

create function DB.DBA.RDF_QNAME_OF_IID (in iid IRI) returns varchar
{
  declare res varchar;
  if (not isiri (iid))
    signal ('RDFXX', 'Wrong type of argument in DB.DBA.RDF_QNAME_OF_IID()');  
  if (iid >= #i1000000000)
    return sprintf ('nodeID://%d', iri_num (iid));
  res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = iid));
  if (res is null)
    signal ('RDFXX', 'Wrong iid in DB.DBA.RDF_QNAME_OF_IID()');
  return res;
}
;

create function DB.DBA.RDF_IID_OF_QNAME_SAFE (in qname varchar) returns IRI
{
  set isolation='commited';
  if (__tag (qname) in (182, 217, 225))
    return coalesce ((select RU_IID from DB.DBA.RDF_URL where RU_QNAME = qname));  
  return NULL;
}
;

create function DB.DBA.RDF_IID_OF_QNAME (in qname varchar) returns IRI
{
  set isolation='commited';
  if (__tag (qname) in (182, 217, 225))
    return coalesce ((select RU_IID from DB.DBA.RDF_URL where RU_QNAME = qname));  
  signal ('RDFXX', 'Wrong tag of argument in DB.DBA.RDF_IID_OF_QNAME()');
}
;

create function DB.DBA.RDF_TWOBYTE_OF_DATATYPE (in iid IRI) returns integer
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
      v2 := coalesce ((select RO_VAL from DB.DBA.RDF_OBJ where RO_ID = id));
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
  if (isiri (o_col))
    {
      declare res varchar;
      if (o_col >= #i1000000000)
        return sprintf ('nodeID://%d', iri_num (o_col));
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
      v2 := coalesce ((select RO_VAL from DB.DBA.RDF_OBJ where RO_ID = id));
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
  if (isiri (o_col))
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

create function DB.DBA.RQ_IID_OF_O (in shortobj any) returns IRI
{
  if (not isiri (shortobj))
    return NULL;
  return shortobj;
}
;

create function DB.DBA.RQ_O_IS_LIT (in shortobj any) returns integer
{
  if (isiri (shortobj))
    return 0;
  return 1;
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
      v2 := coalesce ((select RO_VAL from DB.DBA.RDF_OBJ where RO_ID = id));
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
      if (isiri (shortobj))
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
    signal ('RDFXX', sprintf ('Integrity violation in DB.DBA.RQ_LANGUAGE_OF_OBJ, bad string "%s"', shortobj));
  twobyte := shortobj[len-2] + 256 * (shortobj[len-1]);
  if (257 = twobyte)
    return null;
  whenever not found goto badtype;
  select RL_ID into res from DB.DBA.RDF_LANGUAGE where RL_TWOBYTE = twobyte;
  return res;

badtype:
  signal ('RDFXX', sprintf ('Unknown language in DB.DBA.RQ_LANGUAGE_OF_OBJ, bad string "%s"', shortobj));
}
;

create function DB.DBA.RDF_SQLVAL_OF_OBJ (in shortobj any) returns any
{
  declare t, l, len integer;
  if (isiri (shortobj))
    {
      if (shortobj >= #i1000000000)
        return sprintf ('nodeID://%d', iri_num (shortobj));
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
      v2 := coalesce ((select RO_VAL from DB.DBA.RDF_OBJ where RO_ID = id));
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
  if (isiri (shortobj))
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
  if (isiri (shortobj))
    {
      if (shortobj >= #i1000000000)
        return sprintf ('nodeID://%d', iri_num (shortobj));
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

create function DB.DBA.RDF_STRSQLVAL_OF_OBJ (in shortobj any)
{
  declare t, l, len integer;
  if (isiri (shortobj))
    {
      declare res varchar;
      if (shortobj >= #i1000000000)
        return sprintf ('nodeID://%d', iri_num (shortobj));
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
      v2 := coalesce ((select RO_VAL from DB.DBA.RDF_OBJ where RO_ID = id));
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
  if (193 = __tag(longobj))
    return longobj[4];
  return longobj;
}
;

create function DB.DBA.RDF_SQLVAL_OF_LONG (in longobj any) returns any
{
  if (isiri (longobj))
    {
      if (longobj >= #i1000000000)
        return sprintf ('nodeID://%d', iri_num (longobj));
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
    return longobj[1];
  return longobj;
}
;

create function DB.DBA.RDF_BOOL_OF_LONG (in longobj any) returns any
{
  if (longobj is null)
    return null;
  if (isiri (longobj))
    return NULL;
  if (isinteger (longobj))
    {
      if (longobj)
        return 1;
      return 0;
    }
  if (193 <> __tag (longobj))
    {
      longobj := longobj[1];
      if (longobj is null)
        return null;
      return neq (longobj, 0.0);
    }
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
  if (isiri (longobj))
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
      return longobj[1];
    }
  if (isiri (longobj))
    {
      declare res varchar;
      if (longobj >= #i1000000000)
        return sprintf ('nodeID://%d', iri_num (longobj));
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

create function DB.DBA.RDF_STRSQLVAL_OF_SQLVAL (in sqlval any)
{
  declare t, l, len integer;
  if (193 = __tag (sqlval))
    {
      signal ('RDFXX', 'Long object in DB.DBA.RDF_STRSQLVAL_OF_SQLVAL()');
    }
  if (isiri (sqlval))
    {
      declare res varchar;
      if (sqlval >= #i1000000000)
        return sprintf ('nodeID://%d', iri_num (sqlval));
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
      id := (select RO_ID from DB.DBA.RDF_OBJ where RO_VAL = v);
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
      id := (select RO_ID from DB.DBA.RDF_OBJ where RO_VAL = v);
      if (id is null)
        return null;
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

create function DB.DBA.RDF_DATATYPE_OF_SQLVAL (in v any) returns any
{
  declare t int;
  t := __tag (v);
  if (not t in (182, 217, 225))
    return DB.DBA.RDF_DATATYPE_OF_TAG (t);
  return UNAME'http://www.w3.org/2001/XMLSchema#string';
}
;

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


-- Data loading

create function DB.DBA.RDF_MAKE_IID_OF_QNAME (in qname varchar) returns IRI
{
  if (__tag (qname) in (182, 217, 225, 230))
    {
      declare res IRI;
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
      res := iri_from_num (sequence_next ('RDF_URL_IID_NAMED'));
      insert into DB.DBA.RDF_URL (RU_IID, RU_QNAME) values (res, qname);
      commit work;
      return res;
    }
  if (qname is null)
    return null;
  signal ('RDFXX', 'Wrong tag of argument in DB.DBA.RDF_MAKE_IID_OF_QNAME()');
}
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
      set isolation='commited';
      id := coalesce ((select RO_ID from DB.DBA.RDF_OBJ where RO_VAL = v));
      if (id is null)
        {
          set isolation='serializable';
          id := coalesce ((select RO_ID from DB.DBA.RDF_OBJ where RO_VAL = v));
          if (id is null)
            {
              id := sequence_next ('RDF_RO_ID');
              insert into DB.DBA.RDF_OBJ (RO_ID, RO_VAL) values (id, v);
	      commit work;
	    }
        }
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
      set isolation='commited';
      id := (select RO_ID from DB.DBA.RDF_OBJ where RO_VAL = v);
      if (id is null)
        {
          set isolation='serializable';
          id := coalesce ((select RO_ID from DB.DBA.RDF_OBJ where RO_VAL = v));
          if (id is null)
            {
              id := sequence_next ('RDF_RO_ID');
              insert into DB.DBA.RDF_OBJ (RO_ID, RO_VAL) values (id, v);
	      commit work;
	    }
        }
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

create function DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL (in v any, in dt_iid IRI, in lang varchar) returns any
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
      set isolation='commited';
      id := (select RO_ID from DB.DBA.RDF_OBJ where RO_VAL = v);
      if (id is null)
        {
          set isolation='serializable';
          id := coalesce ((select RO_ID from DB.DBA.RDF_OBJ where RO_VAL = v));
          if (id is null)
            {
              id := sequence_next ('RDF_RO_ID');
              insert into DB.DBA.RDF_OBJ (RO_ID, RO_VAL) values (id, v);
	      commit work;
	    }
        }
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

create function DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL (in v any, in dt_iid IRI, in lang varchar) returns any
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
      set isolation='commited';
      id := (select RO_ID from DB.DBA.RDF_OBJ where RO_VAL = v);
      if (id is null)
        {
          set isolation='serializable';
          id := coalesce ((select RO_ID from DB.DBA.RDF_OBJ where RO_VAL = v));
          if (id is null)
            {
              id := sequence_next ('RDF_RO_ID');
              insert into DB.DBA.RDF_OBJ (RO_ID, RO_VAL) values (id, v);
	      commit work;
	    }
        }
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

create procedure DB.DBA.TTLP_EXEC_NEW_GRAPH (in g varchar, inout app_env any) {
  -- dbg_obj_princ ('DB.DBA.TTLP_EXEC_NEW_GRAPH(', g, app_env, ')');
  ;
}
;

create function DB.DBA.TTLP_EXEC_NEW_BLANK (in g varchar, inout app_env any) returns IRI {
  declare res IRI;
  res := iri_from_num (sequence_next ('RDF_URL_IID_BLANK'));
  -- dbg_obj_princ ('DB.DBA.TTLP_EXEC_NEW_BLANK (', g, app_env, ') returns ', res);
  return res;
}
;

create function DB.DBA.TTLP_EXEC_GET_IID (in uri varchar, in g varchar, inout app_env any) returns IRI {
  declare res IRI;
  -- dbg_obj_princ ('DB.DBA.TTLP_EXEC_GET_IID (', uri, g, app_env, ')');
  res := DB.DBA.RDF_MAKE_IID_OF_QNAME (uri);
  -- dbg_obj_princ ('DB.DBA.TTLP_EXEC_GET_IID (', uri, g, app_env, ') returns ', res);
  return res;
}
;

create procedure DB.DBA.TTLP_EXEC_TRIPLE (
  in g_uri varchar, in g_iid IRI,
  in s_uri varchar, in s_iid IRI,
  in p_uri varchar, in p_iid IRI,
  in o_uri varchar, in o_iid IRI,
  inout app_env any )
{
  insert replacing DB.DBA.RDF_QUAD (G,S,P,O)
  values (g_iid, s_iid, p_iid, o_iid);
}
;

create procedure DB.DBA.TTLP_EXEC_TRIPLE_L (
  in g_uri varchar, in g_iid IRI,
  in s_uri varchar, in s_iid IRI,
  in p_uri varchar, in p_iid IRI,
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

create function DB.DBA.RDF_EXP_XSLT_MAKE_IID_OF_BLANK (in s varchar, in app_env any) returns integeR
{
  declare res integeR;
  declare dict any;
  dict := connection_get ('DB.DBA.RDF_EXP_LOAD_RDFXML');
  s := cast (s as varchar);
  res := dict_get (dict, s, 0);
  if (res <> 0)
    return res;
  res := iri_from_num (sequence_next ('RDF_URL_IID_BLANK'));
  dict_put (dict, s, res);
  return res;
}
;

create function DB.DBA.RDF_EXP_XSLT_ADD_QUAD (
  in g integeR, in s any, in p any, in o_col any, in app_env any)
{
  -- dbg_obj_princ ('DB.DBA.RDF_EXP_XSLT_ADD_QUAD (', g, s, p, o_col, '...)');
  if (not isinteger (s))
    if (cast (s as varchar) like 'nodeID://%')
      s := DB.DBA.RDF_EXP_XSLT_MAKE_IID_OF_BLANK (s, app_env);
    else
      s := DB.DBA.RDF_MAKE_IID_OF_QNAME (s);
  else
    s := iri_from_num (s);
  if (not isinteger (p))
    if (cast (p as varchar) like 'nodeID://%')
      p := DB.DBA.RDF_EXP_XSLT_MAKE_IID_OF_BLANK (p, app_env);
    else
      p := DB.DBA.RDF_MAKE_IID_OF_QNAME (p);
  else
    p := iri_from_num (p);
  if (not isinteger (o_col))
    if (cast (o_col as varchar) like 'nodeID://%')
      o_col := DB.DBA.RDF_EXP_XSLT_MAKE_IID_OF_BLANK (o_col, app_env);
    else
      o_col := DB.DBA.RDF_MAKE_IID_OF_QNAME (o_col);
  else
    o_col := iri_from_num (o_col);
  insert replacing DB.DBA.RDF_QUAD (G,S,P,O)
  values (iri_from_num (g), s, p, o_col);
  if (0 = rnd (1000))
    {
      -- dbg_obj_princ ('.');
      commit work;
    }
  return '';
}
;

grant execute on DB.DBA.RDF_EXP_XSLT_ADD_QUAD to public
;

xpf_extension ('http://www.openlinksw.com/schemas/virtrdf#:ADD_QUAD', fix_identifier_case ('DB.DBA.RDF_EXP_XSLT_ADD_QUAD'), 0)
;


create function DB.DBA.RDF_EXP_XSLT_ADD_QUAD_L (
  in g integeR,
  in s any,
  in p any,
  in v any,
  in v_lang any,
  inout app_env any )
{
  -- dbg_obj_princ ('DB.DBA.RDF_EXP_XSLT_ADD_QUAD_L (', g, s, p, v, v_lang, '...)');
  if (not isinteger (s))
    if (cast (s as varchar) like 'nodeID://%')
      s := DB.DBA.RDF_EXP_XSLT_MAKE_IID_OF_BLANK (s, app_env);
    else
      s := DB.DBA.RDF_MAKE_IID_OF_QNAME (s);
  else
    s := iri_from_num (s);
  if (not isinteger (p))
    if (cast (p as varchar) like 'nodeID://%')
      p := DB.DBA.RDF_EXP_XSLT_MAKE_IID_OF_BLANK (p, app_env);
    else
      p := DB.DBA.RDF_MAKE_IID_OF_QNAME (p);
  else
    p := iri_from_num (p);
  if (v_lang <> '')
    insert replacing DB.DBA.RDF_QUAD (G,S,P,O)
      values (iri_from_num(g), s, p, DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL (v, null, v_lang));
  else
    insert replacing DB.DBA.RDF_QUAD (G,S,P,O)
      values (iri_from_num(g), s, p, DB.DBA.RDF_MAKE_OBJ_OF_SQLVAL (v));
  if (0 = rnd (1000))
    {
      -- dbg_obj_princ ('.');
      commit work;
    }
  return '';   
}
;

grant execute on DB.DBA.RDF_EXP_XSLT_ADD_QUAD_L to public
;

xpf_extension ('http://www.openlinksw.com/schemas/virtrdf#:ADD_QUAD_L', fix_identifier_case ('DB.DBA.RDF_EXP_XSLT_ADD_QUAD_L'), 0)
;

create function DB.DBA.RDF_EXP_XSLT_ADD_QUAD_L_TYPED (
  in g integeR,
  in s any,
  in p any,
  in v any,
  in dt any,
  in v_lang any,
  inout app_env any )
{
  declare dtqname varchar;
  declare o_col any;
  -- dbg_obj_princ ('DB.DBA.RDF_EXP_XSLT_ADD_QUAD_L_TYPED (', g, s, p, v, v_lang, '...)');
  if (not isinteger (s))
    if (cast (s as varchar) like 'nodeID://%')
      s := DB.DBA.RDF_EXP_XSLT_MAKE_IID_OF_BLANK (s, app_env);
    else
      s := DB.DBA.RDF_MAKE_IID_OF_QNAME (s);
  else
    s := iri_from_num (s);
  if (not isinteger (p))
    if (cast (p as varchar) like 'nodeID://%')
      p := DB.DBA.RDF_EXP_XSLT_MAKE_IID_OF_BLANK (p, app_env);
    else
      p := DB.DBA.RDF_MAKE_IID_OF_QNAME (p);
  else
    p := iri_from_num (p);
  if (not isinteger (dt))
    if (cast (dt as varchar) like 'nodeID://%')
      signal ('RDFXX', 'DB.DBA.RDF_EXP_XSLT_ADD_QUAD_L_TYPED (): cannot use nodeID://... IRI for a datatype');
    else
      {
        dtqname := dt;
        dt := DB.DBA.RDF_MAKE_IID_OF_QNAME (dtqname);
      }
  else
    {
      dt := iri_from_num (dt);
      dtqname := DB.DBA.RDF_QNAME_OF_IID (dt);
    }
  if ('http://www.w3.org/2001/XMLSchema#boolean' = dtqname)
    {
      v := cast (v as varchar);
      if (('true' = v) or ('1' = v))
        o_col := 1;
      else if (('false' = v) or ('0' = v))
        o_col := 0;
      else signal ('RDFXX', 'Invalid notation of boolean literal');
    }
  else if ('http://www.w3.org/2001/XMLSchema#dateTime' = dtqname)
    o_col := __xqf_str_parse ('dateTime', cast (v as varchar));
  else if ('http://www.w3.org/2001/XMLSchema#double' = dtqname)
    o_col := cast (cast (v as varchar) as double precision);
  else if ('http://www.w3.org/2001/XMLSchema#float' = dtqname)
    o_col := cast (cast (v as varchar) as float);
  else if ('http://www.w3.org/2001/XMLSchema#integer' = dtqname)
    o_col := cast (cast (v as varchar) as int);
  else if (v_lang <> '')
    o_col := DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL (v, dt, v_lang);
  else
    o_col := DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL (v, dt, null);
  insert replacing DB.DBA.RDF_QUAD (G,S,P,O) values (iri_from_num(g), s, p, o_col);
  if (0 = rnd (1000))
    {
      -- dbg_obj_princ ('.');
      commit work;
    }
  return '';   
}
;

grant execute on DB.DBA.RDF_EXP_XSLT_ADD_QUAD_L_TYPED to public
;

xpf_extension ('http://www.openlinksw.com/schemas/virtrdf#:ADD_QUAD_L_TYPED', fix_identifier_case ('DB.DBA.RDF_EXP_XSLT_ADD_QUAD_L_TYPED'), 0)
;

create function DB.DBA.RDF_EXP_LOAD_RDFXML_XSL() returns varchar
{
  return 'file://rdf-exp-load.xsl';
}
;

create procedure DB.DBA.RDF_EXP_LOAD_RDFXML (in g any, inout ent any, in process_as_large_xper integer, in app_env any := null)
{
  if (isiri (g))
    g := iri_num (g);
  else if (not isinteger (g))
    g := iri_num (DB.DBA.RDF_MAKE_IID_OF_QNAME (g));
  connection_set ('DB.DBA.RDF_EXP_LOAD_RDFXML', dict_new ());
  xslt (DB.DBA.RDF_EXP_LOAD_RDFXML_XSL(),
    ent, vector ('graph-iid', g, 'fragment-only', 0, 'app-env', app_env));
  connection_set ('DB.DBA.RDF_EXP_LOAD_RDFXML', NULL);
}
;

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

create function DB.DBA."http://www.w3.org/2001/XMLSchema#dateTime" (in strg any) returns datetime
{
  if (211 = __tag (strg))
    return strg;
  if (isstring (strg))
    return __xqf_str_parse ('dateTime', strg);
}
;

create function DB.DBA."http://www.w3.org/2001/XMLSchema#double" (in strg varchar) returns double precision
{
  return cast (strg as double precision);
}
;

create function DB.DBA."http://www.w3.org/2001/XMLSchema#float" (in strg varchar) returns float
{
  return cast (strg as float);
}
;

create function DB.DBA."http://www.w3.org/2001/XMLSchema#integer" (in strg varchar) returns integer
{
  return cast (strg as integer);
}
;

create function DB.DBA.__and (in e1 any, in e2 any) returns integer
{
  if (e1 and e2)
    return 1;
  return 0;
}
;

create function DB.DBA.__or (in e1 any, in e2 any) returns integer
{
  if (e1 or e2)
    return 1;
  return 0;
}
;

create function DB.DBA.__not (in e1 any) returns integer
{
  if (e1)
    return 0;
  return 1;
}
;

create function DB.DBA.RDF_REGEX (in s varchar, in p varchar, in coll varchar := null)
{
-- !!!TBD proper use of third argument
  if (regexp_match (p, s, 0) is not null)
    return 1;
  return 0;
}
;

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

create procedure DB.DBA."sparql_construct_init" (inout _env any)
{
  _env := 0; -- No actual initialization
}
;

create procedure DB.DBA."sparql_construct_acc" (inout _env any, in opcodes any, in vars any, in stats any)
{
  declare triple_ctr integer;
  declare blank_ids any;
  if (214 <> __tag(_env))
    {
      _env := dict_new ();
      if (0 < length (stats))
        DB.DBA."sparql_construct_acc" (_env, stats, vector(), vector());
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
              declare i iri;
              i := vars[arg];
              if (i is null)
                goto end_of_adding_triple;
              if ((2 > fld_ctr) and not isiri (i))
                signal ('RDF01', sprintf ('Bad variable value in CONSTRUCT: only object of a triple can be a literal like "%.30s"', DB.DBA.RDF_STRSQLVAL_OF_LONG (i)));
              if ((1 = fld_ctr) and isiri (i) and (i >= #i1000000000))
                signal ('RDF01', 'Bad variable value in CONSTRUCT: blank node can not be used as predicate');
              triple_vec[fld_ctr] := i;
            }
          else if (2 = op)
            {
	      if (isinteger (blank_ids))
	        blank_ids := vector (iri_from_num (sequence_next ('RDF_URL_IID_BLANK')));
              while (arg >= length (blank_ids))
                blank_ids := vector_concat (blank_ids, vector (iri_from_num (sequence_next ('RDF_URL_IID_BLANK'))));
              if (1 = fld_ctr)
                signal ('RDF01', 'Bad triple for CONSTRUCT: blank node can not be used as predicate');
              triple_vec[fld_ctr] := blank_ids[arg];
            }
          else if (3 = op)
            {
              if ((2 > fld_ctr) and not isiri (arg))
                signal ('RDF01', sprintf ('Bad const value in CONSTRUCT: only object of a triple can be a literal like "%.30s"', DB.DBA.RDF_STRSQLVAL_OF_LONG (arg)));
              if ((1 = fld_ctr) and isiri (arg) and (arg >= #i1000000000))
                signal ('RDF01', 'Bad const value in CONSTRUCT: blank node can not be used as predicate');
              triple_vec[fld_ctr] := arg;
            }
          else signal ('RDFXX', 'Bad opcode in DB.DBA."sparql_construct"()');
        }
      -- dbg_obj_princ ('generated triple:', triple_vec);
      dict_put (_env, triple_vec, 0);
end_of_adding_triple: ;
    }
}
;

create procedure DB.DBA."sparql_construct_fin" (inout _env any)
{
  if (214 <> __tag(_env))
    _env := dict_new ();
  return _env;
}
;

create aggregate DB.DBA."sparql_construct" (in opcodes any, in vars any, in stats any) returns any
from DB.DBA."sparql_construct_init", DB.DBA."sparql_construct_acc", DB.DBA."sparql_construct_fin"
;

create procedure DB.DBA."sparql_describe_init" (inout _env any)
{
  _env := 0; -- No actual initialization
}
;

create procedure DB.DBA."sparql_describe_acc" (inout _env any, in vars any, in stats any, in options any)
{
  declare var_ctr integer;
  declare blank_ids any;
  if (193 <> __tag(_env))
    {
      _env := vector (dict_new (), options);
      if (0 < length (stats))
        DB.DBA."sparql_describe_acc" (_env, stats, vector(), vector());
    }
  for (var_ctr := length (vars) - 1; var_ctr >= 0; var_ctr := var_ctr - 1)
    {
      declare i any;
      i := vars[var_ctr];
      if (isiri (i))
        dict_put (_env[0], i, 0);
    }
}
;

create procedure DB.DBA."sparql_describe_fin" (inout _env any)
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

create aggregate DB.DBA."sparql_describe" (in opcodes any, in vars any, in stats any) returns any
from DB.DBA."sparql_describe_init", DB.DBA."sparql_describe_acc", DB.DBA."sparql_describe_fin"
;

create procedure DB.DBA.RDF_DESCRIBE_PUT (in dict any, in subj iri, inout options any)
{
-- TBD something later
  for (select G as g1, P as p1, O as obj1 from DB.DBA.RDF_QUAD where S = subj) do
    {
      dict_put (dict, vector (subj, p1, DB.DBA.RDF_LONG_OF_OBJ (obj1)), 0);
      if (isiri (obj1))
        {
          for (select P as p2, O as obj2
            from DB.DBA.RDF_QUAD
            where G = g1 and S = obj1 and not (isiri (O)) ) do
            {
              dict_put (dict, vector (obj1, p2, DB.DBA.RDF_LONG_OF_OBJ (obj2)), 0);
            }
        }
    }
}
;

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
      if (not isiri (subj))
        {
          if (subj is null)
            signal ('RDFXX', 'DB.DBA.TRIPLES_TO_TTL(): subject is NULL');
          signal ('RDFXX', 'DB.DBA.TRIPLES_TO_TTL(): subject is literal');
        }
      if (subj >= #i1000000000)
        http (sprintf ('_:b%d ', iri_num (subj)), ses);
      else
        {
          res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = subj));
          http ('<', ses); http (res, ses); http ('> ', ses);
        }
      if (not isiri (pred))
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
          http ('<', ses); http (res, ses); http ('> ', ses);
        }
      if (obj is null)
        signal ('RDFXX', 'DB.DBA.TRIPLES_TO_TTL(): object is NULL');
      if (isiri (obj))
        {
          if (obj >= #i1000000000)
            http (sprintf ('_:b%d ', iri_num (obj)), ses);
          else
            {
              res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = obj), sprintf ('_:bad_iid_%d', iri_num (obj)));
              http ('<', ses); http (res, ses); http ('> ', ses);
            }
        }
      else if (193 = __tag (obj))
        {
          http ('"', ses);
          http (replace (replace (obj[1], '\\', '\\\\'), '"', '\\"'), ses);
          if (257 <> obj[0])
            {
              res := coalesce ((select RDT_QNAME from DB.DBA.RDF_DATATYPE where RDT_TWOBYTE = obj[0]));
              http ('"^^<', ses); http (res, ses); http ('> ', ses);
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
          http (replace (obj[1], '"', '\\"'), ses);
          http ('" ', ses);
        }
      else
        {
          http ('"', ses);
          http (replace (DB.DBA.RDF_STRSQLVAL_OF_LONG (obj), '"', '\\"'), ses);
          http ('"^^<', ses);
          http (cast (DB.DBA.RDF_DATATYPE_OF_TAG (__tag (obj)) as varchar), ses); http ('> ', ses);

        }      
      http ('.\n', ses);
    }
}
;

create procedure DB.DBA.TEST_SPARQL_TTL (in query varchar, in dflt_graph varchar)
{
  declare ses, rset, triples any;
  declare txt varchar;
  ses := string_output ();
  rset := DB.DBA.SPARQL_EVAL_TO_ARRAY (query, dflt_graph, 1);
  triples := dict_list_keys (rset[0][0], 1);
  DB.DBA.RDF_TRIPLES_TO_TTL (triples, ses);
  txt := string_output_string (ses);
  dump_large_text (txt);
}
;

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
      if (not isiri (subj))
        {
          if (subj is null)
            signal ('RDFXX', 'DB.DBA.TRIPLES_TO_RDF_XML_TEXT(): subject is NULL');
          signal ('RDFXX', 'DB.DBA.TRIPLES_TO_RDF_XML_TEXT(): subject is literal');
        }
      if (subj >= #i1000000000)
        http (sprintf (' rdf:nodeID="b%d">', iri_num (subj)), ses);
      else
        {
          res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = subj));
          http (' about="', ses); http_value (res, 0, ses); http ('">', ses);
        }
      if (not isiri (pred))
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
      if (isiri (obj))
        {
          if (obj >= #i1000000000)
            http (sprintf (' rdf:nodeID="b%d"/>', iri_num (subj)), ses);
          else
            {
              res := coalesce ((select RU_QNAME from DB.DBA.RDF_URL where RU_IID = obj), sprintf ('_:bad_iid_%d', iri_num (obj)));
              http (' rdf:resource="', ses); http_value (res, 0, ses); http ('/>', ses);
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

create procedure DB.DBA.TEST_SPARQL_RDF_XML_TEXT (in query varchar, in dflt_graph varchar)
{
  declare ses, rset, triples any;
  declare txt varchar;
  ses := string_output ();
  rset := DB.DBA.SPARQL_EVAL_TO_ARRAY (query, dflt_graph, 1);
  triples := dict_list_keys (rset[0][0], 1);
  DB.DBA.RDF_TRIPLES_TO_RDF_XML_TEXT (triples, 1, ses);
  txt := string_output_string (ses);
  dump_large_text (txt);
}
;


create procedure DB.DBA.RDF_TTL2HASH_EXEC_NEW_GRAPH (in g varchar, inout app_env any) {
  -- dbg_obj_princ ('DB.DBA.RDF_TTL2HASH_EXEC_NEW_GRAPH(', g, app_env, ')');
  ;
}
;

create function DB.DBA.RDF_TTL2HASH_EXEC_NEW_BLANK (in g varchar, inout app_env any) returns IRI {
  declare res IRI;
  res := iri_from_num (sequence_next ('RDF_URL_IID_BLANK'));
  -- dbg_obj_princ ('DB.DBA.RDF_TTL2HASH_EXEC_NEW_BLANK (', g, app_env, ') returns ', res);
  return res;
}
;

create function DB.DBA.RDF_TTL2HASH_EXEC_GET_IID (in uri varchar, in g varchar, inout app_env any) returns IRI {
  declare res IRI;
  -- dbg_obj_princ ('DB.DBA.RDF_TTL2HASH_EXEC_GET_IID (', uri, g, app_env, ')');
  res := DB.DBA.RDF_MAKE_IID_OF_QNAME (uri);
  -- dbg_obj_princ ('DB.DBA.RDF_TTL2HASH_EXEC_GET_IID (', uri, g, app_env, ') returns ', res);
  return res;
}
;

create procedure DB.DBA.RDF_TTL2HASH_EXEC_TRIPLE (
  in g_uri varchar, in g_iid IRI,
  in s_uri varchar, in s_iid IRI,
  in p_uri varchar, in p_iid IRI,
  in o_uri varchar, in o_iid IRI,
  inout app_env any )
{
  dict_put (app_env, vector (s_iid, p_iid, o_iid), 0);
}
;

create procedure DB.DBA.RDF_TTL2HASH_EXEC_TRIPLE_L (
  in g_uri varchar, in g_iid IRI,
  in s_uri varchar, in s_iid IRI,
  in p_uri varchar, in p_iid IRI,
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
  declare req_body, local_req_hdr, ret_body, ret_hdr any;
  declare ret_content_type varchar;
  req_body := string_output();
  http ('query=', req_body);
  http_url (query, 0, req_body);
  if (dflt_graph is not null)
    {
      http ('&default-graph-uri=', req_body);
      http_url (dflt_graph, 0, req_body);
    }
  foreach (varchar uri in named_graphs) do
    {
      http ('&named-graph-uri=', req_body);
      http_url (uri, 0, req_body);
    }
  local_req_hdr := 'Accept: text/rdf+n3, application/rdf+xml, application/sparql-results+xml\r\nContent-Type: application/x-www-form-urlencoded';
  if (length (req_hdr) > 0) 
    req_hdr := concat (req_hdr, '\r\n', local_req_hdr );
  else
    req_hdr := local_req_hdr;
  ret_body := http_get (service, ret_hdr, 'POST', req_hdr, string_output_string (req_body));
  -- dbg_obj_princ ('Returned header: ', ret_hdr);
  -- dbg_obj_princ ('Returned body: ', ret_body);
  ret_content_type := http_request_header (ret_hdr, 'Content-Type', null, '');
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
                      declare local_iid iri;
                      if (bnode_dict is null)
                        {
                          bnode_dict := dict_new ();
                          local_iid := iri_from_num (sequence_next ('RDF_URL_IID_BLANK'));
                          dict_put (bnode_dict, var_strval, local_iid);
                        }
                      else
                        {
                          local_iid := dict_get (bnode_dict, var_strval, null);
                          if (local_iid is null)
                            {
                              local_iid := iri_from_num (sequence_next ('RDF_URL_IID_BLANK'));
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
          full1 := coalesce ((select RO_VAL from DB.DBA.RDF_OBJ where RO_ID = id1));
          if (full1 is null)
            signal ('RDFXX', sprintf ('Integrity violation in DB.DBA.RDF_OBJ_CMP, bad id %d', id1));
          full2 := coalesce ((select RO_VAL from DB.DBA.RDF_OBJ where RO_ID = id2));
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
