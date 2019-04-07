set verbose off;

create table LEXCOLL (CP integer not null primary key, DECOMP varchar, TITLE1 varchar, TITLE2 varchar, PARENT integer, IS_ACUTED_PARENT integer, PARENT_TLEN integer);

create table LEXCOLL_EXPLAIN (E_CP integer not null primary key, E_WEIGHT integer, E_REASON varchar);
create table LEXCOLL_ACUTE_EXPLAIN (E_CP integer not null primary key, E_WEIGHT integer, E_REASON varchar);

create procedure UNICODE3_HEADER()
{
  delete from LEXCOLL;
}
;

create function UNICODE3_G (in s varchar) { return 0; }
;
create function UNICODE3_S1 (in s varchar, in n1 integer) { return ' ' || n1 || ' '; }
;
create function UNICODE3_S2 (in s varchar, in n1 integer, in n2 integer) { return ' ' || n1 || ' ' || n2 || ' '; }
;
create function UNICODE3_S3 (in s varchar, in n1 integer, in n2 integer, in n3 integer) { return ' ' || n1 || ' ' || n2 || ' ' || n3 || ' '; }
;
create function UNICODE3_S4 (in s varchar, in n1 integer, in n2 integer, in n3 integer, in n4 integer) { return ' ' || n1 || ' ' || n2 || ' ' || n3 || ' ' || n4 || ' '; }
;
create function UNICODE3_S5 (in s varchar, in n1 integer, in n2 integer, in n3 integer, in n4 integer, in n5 integer) { return ' ' || n1 || ' ' || n2 || ' ' || n3 || ' ' || n4 || ' ' || n5 || ' '; }
;
create function UNICODE3_S6 (in s varchar, in n1 integer, in n2 integer, in n3 integer, in n4 integer, in n5 integer, in n6 integer) { return ' ' || n1 || ' ' || n2 || ' ' || n3 || ' ' || n4 || ' ' || n5 || ' ' || n6 || ' '; }
;
create function UNICODE3_SX (in s varchar, in x varchar) { return x; }
;
create function UNICODE3_long_ligature (in s varchar) { return 0; }
;

create procedure UNICODE3_REC(in codepoint1 integer, in class2 varchar, in a3 integer, in cla4 varchar, in d5 decimal, in d6 decimal, in d7 decimal, in h8 integer, in h9 integer, in h10 integer,
    in d11 integer, in a12 any, in s13 varchar, in descr14 varchar, in descr15 varchar) {
--               1           2       3       4       5       6       7               8               9               10      
-- UNICODE3_REC( 0hexFFB9  , 'Lo'  , 0     , 'L'   , -1    , -1    , -1.0          , 0hex0000      , 0hex0000      , 0hex0000
--        11      12                                        13    14                                         15
--      , 0     , UNICODE3_S1(UNICODE3_narrow(), 0hex3149), ''  , 'HALFWIDTH HANGUL LETTER SSANG JIEUJ'    , 'HALFWIDTH HANGUL LETTER SSANGCIEUC');
  insert into LEXCOLL (CP, DECOMP, TITLE1, TITLE2, IS_ACUTED_PARENT) values (codepoint1, a12, descr14, descr15, 0);
  if (mod (codepoint1, 4096) = 4095)
    dbg_obj_princ ('Codepoint ', codepoint1, ' done...');
}
;

create procedure LEXICAL_COLL_WRITE()
{
  declare ctr, prev_cp integer;
  declare ses any;
  delete from LEXCOLL_EXPLAIN;
  ses := string_output();
  ctr := -1;
  prev_cp := -2;
  for (select l1.CP, l1.PARENT, l1.IS_ACUTED_PARENT, l2.PARENT as parent2 from LEXCOLL l1 left outer join LEXCOLL l2 on (l2.CP = l1.PARENT)
    order by coalesce (l2.PARENT, l1.PARENT, l1.CP),
    case when l1.PARENT is null then 0 when l2.PARENT is null and l1.IS_ACUTED_PARENT then 1 when l2.PARENT is null then l1.CP * 10 when l1.IS_ACUTED_PARENT then l1.PARENT * 10 + 1 else l1.PARENT * 10 + 2 end,
    l1.CP) do
    {
      if (not IS_ACUTED_PARENT or prev_cp<>PARENT)
        {
          ctr := ctr+1;
          prev_cp := cp;
        }
      if (CP <> ctr)
        http ('0' || CP || '=0' || case (ctr) when 0 then 1 else ctr end || '\n', ses);
      insert into LEXCOLL_EXPLAIN (E_CP, E_WEIGHT, E_REASON) values (
        CP, ctr, sprintf ('%d is sorted as %d, %d, %d, parent %d, acute %d', CP, coalesce (parent2, PARENT, CP),
          case when PARENT is null then 0 when parent2 is null and IS_ACUTED_PARENT then 1 when parent2 is null then CP * 10 when IS_ACUTED_PARENT then PARENT * 10 + 1 else PARENT * 10 + 2 end,
          CP, coalesce (PARENT,0), IS_ACUTED_PARENT ) );
    }
  string_to_file ('lexical_acute.coll', ses, -2);
  delete from LEXCOLL_ACUTE_EXPLAIN;
  ctr := 0;
  ses := string_output();
  for (select l1.CP, l1.PARENT, l1.IS_ACUTED_PARENT, l2.PARENT as parent2 from LEXCOLL l1 left outer join LEXCOLL l2 on (l2.CP = l1.PARENT)
    order by coalesce (l2.PARENT, l1.PARENT, l1.CP),
    case when l1.PARENT is null then 0 when l2.PARENT is null then l1.CP * 10 else l1.PARENT * 10 + 2 end,
    l1.CP) do
    {
      if (CP <> ctr)
        http ('0' || CP || '=0' || case (ctr) when 0 then 1 else ctr end || '\n', ses);
      insert into LEXCOLL_ACUTE_EXPLAIN (E_CP, E_WEIGHT, E_REASON) values (
        CP, ctr, sprintf ('(because %d is sorted as %d, %d, %d, parent %d, acute %d)', CP, coalesce (parent2, PARENT, CP),
          case when PARENT is null then 0 when parent2 is null then CP * 10 else PARENT * 10 + 2 end,
          CP, coalesce (PARENT,0), IS_ACUTED_PARENT ) );
      ctr := ctr+1;
    }
  string_to_file ('lexical.coll', ses, -2);
}
;

create procedure UNICODE3_FOOTER()
{
  commit work;
  declare ctr, max_cp integer;
  declare ses any;
  max_cp := (select MAX (CP) from LEXCOLL);
  for (ctr := 0; ctr <= max_cp; ctr := ctr+1)
    {
      declare t1, t2 varchar;
      t1 := (select TITLE1 from LEXCOLL where CP = ctr);
      t2 := (select TITLE2 from LEXCOLL where CP = ctr);
      if (t2 <> '<control>')
        {
          if (t1 is not null and t1 <> '')
            update LEXCOLL set PARENT=ctr, PARENT_TLEN=length(t1) where ctr <> CP and (TITLE2 <> '<control>') and
              (strstr (TITLE1, t1) is not null and (PARENT is null or PARENT_TLEN < length (t1)));
          if (t2 is not null and t2 <> '')
            update LEXCOLL set PARENT=ctr, PARENT_TLEN=length(t2) where ctr <> CP and (TITLE2 <> '<control>') and
              (strstr (TITLE2, t2) is not null and (PARENT is null or PARENT_TLEN < length (t2)));
        }
      if (mod (ctr, 4096) = 4095)
        dbg_obj_princ ('Codepoint ', ctr, ' done...');
      commit work;
    }
  for (select acuted.CP as acp, acuted.PARENT as aparent, base.CP as bcp from LEXCOLL as acuted, LEXCOLL as base
    where acuted.CP <> 0hex00B4 and acuted.CP <> base.CP and acuted.DECOMP is not null and
      (strstr (acuted.DECOMP, ' ' || 0hex301 || ' ') is not null or strstr (acuted.DECOMP, ' ' || 0hex30B || ' ') is not null) and
      (base.CP = acuted.PARENT or acuted.PARENT is null) and
      (base.DECOMP is null or not (base.DECOMP = ' ' || base.PARENT || ' ')) and
      (coalesce (base.DECOMP, ' ' || base.CP || ' ') =
         replace (replace (acuted.DECOMP, ' ' || 0hex301 || ' ', ' '), ' ' || 0hex30B || ' ', ' ') )
    order by base.CP
 ) do
    {
      dbg_obj_princ ('Codepoint ', bcp, ' is base for acuted ', acp);
      update LEXCOLL set PARENT=bcp, IS_ACUTED_PARENT=1 where CP=acp and not IS_ACUTED_PARENT;
    } 
  LEXICAL_COLL_WRITE();
}
;

create procedure LEXICAL_SQL ()
{
  collation_define ('LEXICAL_TMP', 'lexical.coll', 2);
  collation_define ('LEXICAL_ACUTE_TMP', 'lexical_acute.coll', 2);
  string_to_file ('sys_unicode3_collations.sql', '
create procedure DB.DBA.__MAKE_UNICODE3_COLLATIONS_1 ()
{
  declare ccname varchar;
  declare ses, tbl any;
  ses := string_output ();
  gz_uncompress (uudecode (''' ||
      uuencode (gz_compress ((select cast (COLL_TABLE as varchar) from SYS_COLLATIONS where COLL_NAME=complete_collation_name ('LEXICAL_TMP', 1))), 2, 100000)[0] ||
''', 2), ses);
  tbl := charset_recode (string_output_string (ses), ''UTF-8'', ''_WIDE_'');
  ccname := complete_collation_name (''LEXICAL'', 1);
  __collation_define_memonly (ccname, tbl);
  insert replacing SYS_COLLATIONS (COLL_NAME, COLL_TABLE, COLL_WIDE) values (ccname, cast (tbl as varbinary), 1);
  commit work;
  log_text (''__collation_define_memonly (?,?)'', ccname, tbl);
}
;

create procedure DB.DBA.__MAKE_UNICODE3_COLLATIONS_2 ()
{
  declare ccname varchar;
  declare ses, tbl any;
-- LEXICAL_ACUTE collation
  ses := string_output ();
  gz_uncompress (uudecode (''' ||
      uuencode (gz_compress ((select cast (COLL_TABLE as varchar) from SYS_COLLATIONS where COLL_NAME=complete_collation_name ('LEXICAL_ACUTE_TMP', 1))), 2, 100000)[0] ||
''', 2), ses);
  tbl := charset_recode (string_output_string (ses), ''UTF-8'', ''_WIDE_'');
  ccname := complete_collation_name (''LEXICAL_ACUTE'', 1);
  __collation_define_memonly (ccname, tbl);
  insert replacing SYS_COLLATIONS (COLL_NAME, COLL_TABLE, COLL_WIDE) values (ccname, cast (tbl as varbinary), 1);
  commit work;
  log_text (''__collation_define_memonly (?,?)'', ccname, tbl);
}
;

create procedure DB.DBA.__MAKE_UNICODE3_COLLATIONS (in force integer := 0)
{
  declare ctr integer;
  declare ccname varchar;
  if (exists (select 1 from DB.DBA.SYS_COLLATIONS where COLL_NAME = complete_collation_name (''LEXICAL_ACUTE'', 1)) and not force)
    return;
  declare ses, tbl any;
  DB.DBA.__MAKE_UNICODE3_COLLATIONS_1();
  DB.DBA.__MAKE_UNICODE3_COLLATIONS_2();
-- Lowercase
  tbl := make_wstring (65536, wchr1(1));
  for (ctr := 1; ctr < 65536; ctr := ctr+1)
    tbl[ctr] := lcase (wchr1(ctr))[0];
  ccname := complete_collation_name (''LCASE'', 1);
  __collation_define_memonly (ccname, tbl);
  insert replacing DB.DBA.SYS_COLLATIONS (COLL_NAME, COLL_TABLE, COLL_WIDE) values (ccname, cast (tbl as varbinary), 1);
  commit work;
  log_text (''__collation_define_memonly (?,?)'', ccname, tbl);
-- Uppercase
  tbl := make_wstring (65536, wchr1(1));
  for (ctr := 1; ctr < 65536; ctr := ctr+1)
    tbl[ctr] := ucase (wchr1(ctr))[0];
  ccname := complete_collation_name (''UCASE'', 1);
  __collation_define_memonly (ccname, tbl);
  insert replacing DB.DBA.SYS_COLLATIONS (COLL_NAME, COLL_TABLE, COLL_WIDE) values (ccname, cast (tbl as varbinary), 1);
  commit work;
  log_text (''__collation_define_memonly (?,?)'', ccname, tbl);
-- Remove accents
  tbl := make_wstring (65536, wchr1(1));
  for (ctr := 1; ctr < 65536; ctr := ctr+1)
    tbl[ctr] := remove_unicode3_accents (wchr1(ctr))[0];
  ccname := complete_collation_name (''BASECHAR'', 1);
  __collation_define_memonly (ccname, tbl);
  insert replacing DB.DBA.SYS_COLLATIONS (COLL_NAME, COLL_TABLE, COLL_WIDE) values (ccname, cast (tbl as varbinary), 1);
  commit work;
  log_text (''__collation_define_memonly (?,?)'', ccname, tbl);
-- Remove accents, then lcase
  tbl := make_wstring (65536, wchr1(1));
  for (ctr := 1; ctr < 65536; ctr := ctr+1)
    tbl[ctr] := lcase(remove_unicode3_accents (wchr1(ctr)))[0];
  ccname := complete_collation_name (''BASECHAR_LCASE'', 1);
  __collation_define_memonly (ccname, tbl);
  insert replacing DB.DBA.SYS_COLLATIONS (COLL_NAME, COLL_TABLE, COLL_WIDE) values (ccname, cast (tbl as varbinary), 1);
  commit work;
  log_text (''__collation_define_memonly (?,?)'', ccname, tbl);
-- Remove accents, then ucase
  tbl := make_wstring (65536, wchr1(1));
  for (ctr := 1; ctr < 65536; ctr := ctr+1)
    tbl[ctr] := ucase(remove_unicode3_accents (wchr1(ctr)))[0];
  ccname := complete_collation_name (''BASECHAR_UCASE'', 1);
  __collation_define_memonly (ccname, tbl);
  insert replacing DB.DBA.SYS_COLLATIONS (COLL_NAME, COLL_TABLE, COLL_WIDE) values (ccname, cast (tbl as varbinary), 1);
  commit work;
  log_text (''__collation_define_memonly (?,?)'', ccname, tbl);
}
;
', -2);
}
;


load unicode3_all_chars.sql;
--LEXICAL_COLL_WRITE();
LEXICAL_SQL();
