--
--  terror.sql
--
--  $Id$
--
--  Various tests that should return an error.
--  The intent is that the server recover from these, hence results are
--  not checked.
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

select blob_to_string (ROW_NO) from T2 where T2 = 11;
select blob_to_string (ROW_NO) from BLOBS where ROW_NO = 1;
select blob_to_string (A) from T2;
select blob_to_string (A) from T2 where A = 12;

select word from words where word < 'ad' or txn_error (1);
select word from words where txn_error (1);
select word, txn_error (1) from words;

create procedure txn_error_pl (in e integer)
{
  txn_error (e);
}

select word from words where word < 'abb' or txn_error (1);
select word from words where txn_error (1);
select word, txn_error (1) from words;

create procedure txn_error_pl (in e integer)
{
  txn_error (e);
}

select word from words where word < 'abb' or txn_error_pl (1);
select word from words where txn_error_pl (1);
select word, txn_error_pl (1) from words;

set autocommit on;
select word from words where word < 'abb' or txn_error_pl (1);
select word from words where txn_error_pl (1);
select word, txn_error_pl (1) from words;

-- set timeout 1;
-- select count (*) from words w1, words w2;

select BLOBS.* from BLOBS where BLOBS.ROW_NO = 1;
select BLOBS.* from DB.DBA.BLOBS where BLOBS.ROW_NO = 1;
select BLB.* from DB.DBA.BLOBS where BLOBS.ROW_NO = 1;
select BLB.* from DB.DBA.BLOBS B where BLOBS.ROW_NO = 1;

select sum (ROW_NO), STRING1 from T1 group by DB.DBA.T1.STRING2;

select sum (ROW_NO), STRING1 from T1 group by DB.DBA.T1.STRING1 having STRING2 > '2';

-- column reference scope

select ROW_NO, X.ROW_NO from T1, T1 X where ROW_NO + 2 = X.ROW_NO;
ECHO BOTH $IF $EQU $ROWCNT 18 "PASSED" "***FAILED";
ECHO BOTH ": uncorrelated, correlated join " $ROWCNT " rows.\n";

select ROW_NO, X.ROW_NO from T1 X, T1 where ROW_NO + 2 = X.ROW_NO;
ECHO BOTH $IF $EQU $ROWCNT 18 "PASSED" "***FAILED";
ECHO BOTH ": correlated, uncorrelated join " $ROWCNT " rows.\n";

select ROW_NO, ROW_NO from T1, T1 where ROW_NO + 2 = ROW_NO;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": Ambiguous column state " $STATE "\n";

select ROW_NO, Y.ROW_NO from T1 X, T1 Y where X.ROW_NO + 2 = Y.ROW_NO;
ECHO BOTH $IF $EQU $STATE 42S22 "PASSED" "***FAILED";
ECHO BOTH ": Ambiguous column state " $STATE "\n";

select ROW_NO, X.ROW_NO, Y.ROW_NO from T1 X, T1 Y, T1 where X.ROW_NO + 2 = Y.ROW_NO and ROW_NO = X.ROW_NO + 4;
ECHO BOTH $IF $EQU $ROWCNT 16 "PASSED" "***FAILED";
ECHO BOTH ": correlated, correlated, uncorrelated join " $ROWCNT " rows.\n";

create table terror (error_1 integer, error_2 integer, primary key (no_such));
ECHO BOTH $IF $EQU $STATE 42S22  "PASSED" "***FAILED";
ECHO BOTH ": table with bad primary key part state " $STATE "\n";

create table terror (error_1 integer, error_2 integer, primary key (error_1));
insert into terror values (1, 2);
select count (*) from terror;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": Inserted row into terror table count " $LAST[1] " state " $STATE "\n";

drop table terror;


create procedure rec (in q integer) { dbg_obj_print ('rec', q); rec (q + 1); };
rec (0);




create procedure txn_test (in q integer)
{
  whenever sqlstate '40001' goto dead;
  txn_error (2);
  dbg_obj_print ('error made');
 retry:
  select count (*) into q from SYS_KEYS;
  return q;
 dead:
  rollback work;
  dbg_obj_print ('rolled back');
  goto retry;
}

txn_test (1);

drop table colcnttest;

create table colcnttest (
col1 char (10),
col2 char (10),
col3 char (10),
col4 char (10),
col5 char (10),
col6 char (10),
col7 char (10),
col8 char (10),
col9 char (10),
col10 char (10),
col11 char (10),
col12 char (10),
col13 char (10),
col14 char (10),
col15 char (10),
col16 char (10),
col17 char (10),
col18 char (10),
col19 char (10),
col20 char (10),
col21 char (10),
col22 char (10),
col23 char (10),
col24 char (10),
col25 char (10),
col26 char (10),
col27 char (10),
col28 char (10),
col29 char (10),
col30 char (10),
col31 char (10),
col32 char (10),
col33 char (10),
col34 char (10),
col35 char (10),
col36 char (10),
col37 char (10),
col38 char (10),
col39 char (10),
col40 char (10),
col41 char (10),
col42 char (10),
col43 char (10),
col44 char (10),
col45 char (10),
col46 char (10),
col47 char (10),
col48 char (10),
col49 char (10),
col50 char (10),
col51 char (10),
col52 char (10),
col53 char (10),
col54 char (10),
col55 char (10),
col56 char (10),
col57 char (10),
col58 char (10),
col59 char (10),
col60 char (10),
col61 char (10),
col62 char (10),
col63 char (10),
col64 char (10),
col65 char (10),
col66 char (10),
col67 char (10),
col68 char (10),
col69 char (10),
col70 char (10),
col71 char (10),
col72 char (10),
col73 char (10),
col74 char (10),
col75 char (10),
col76 char (10),
col77 char (10),
col78 char (10),
col79 char (10),
col80 char (10),
col81 char (10),
col82 char (10),
col83 char (10),
col84 char (10),
col85 char (10),
col86 char (10),
col87 char (10),
col88 char (10),
col89 char (10),
col90 char (10),
col91 char (10),
col92 char (10),
col93 char (10),
col94 char (10),
col95 char (10),
col96 char (10),
col97 char (10),
col98 char (10),
col99 char (10),
col100 char (10),
col101 char (10),
col102 char (10),
col103 char (10),
col104 char (10),
col105 char (10),
col106 char (10),
col107 char (10),
col108 char (10),
col109 char (10),
col110 char (10),
col111 char (10),
col112 char (10),
col113 char (10),
col114 char (10),
col115 char (10),
col116 char (10),
col117 char (10),
col118 char (10),
col119 char (10),
col120 char (10),
col121 char (10),
col122 char (10),
col123 char (10),
col124 char (10),
col125 char (10),
col126 char (10),
col127 char (10),
col128 char (10),
col129 char (10),
col130 char (10),
col131 char (10),
col132 char (10),
col133 char (10),
col134 char (10),
col135 char (10),
col136 char (10),
col137 char (10),
col138 char (10),
col139 char (10),
col140 char (10),
col141 char (10),
col142 char (10),
col143 char (10),
col144 char (10),
col145 char (10),
col146 char (10),
col147 char (10),
col148 char (10),
col149 char (10),
col150 char (10),
col151 char (10),
col152 char (10),
col153 char (10),
col154 char (10),
col155 char (10),
col156 char (10),
col157 char (10),
col158 char (10),
col159 char (10),
col160 char (10),
col161 char (10),
col162 char (10),
col163 char (10),
col164 char (10),
col165 char (10),
col166 char (10),
col167 char (10),
col168 char (10),
col169 char (10),
col170 char (10),
col171 char (10),
col172 char (10),
col173 char (10),
col174 char (10),
col175 char (10),
col176 char (10),
col177 char (10),
col178 char (10),
col179 char (10),
col180 char (10),
col181 char (10),
col182 char (10),
col183 char (10),
col184 char (10),
col185 char (10),
col186 char (10),
col187 char (10),
col188 char (10),
col189 char (10),
col190 char (10),
col191 char (10),
col192 char (10),
col193 char (10),
col194 char (10),
col195 char (10),
col196 char (10),
col197 char (10),
col198 char (10),
col199 char (10),
col200 char (10),
col201 char (10),
col202 char (10),
col203 char (10),
col204 char (10),
col205 char (10),
col206 char (10),
col207 char (10),
col208 char (10),
col209 char (10),
col210 char (10),
col211 char (10),
col212 char (10),
col213 char (10),
col214 char (10),
col215 char (10),
col216 char (10),
col217 char (10),
col218 char (10),
col219 char (10),
col220 char (10),
col221 char (10),
col222 char (10),
col223 char (10),
col224 char (10),
col225 char (10),
col226 char (10),
col227 char (10),
col228 char (10),
col229 char (10),
col230 char (10),
col231 char (10),
col232 char (10),
col233 char (10),
col234 char (10),
col235 char (10),
col236 char (10),
col237 char (10),
col238 char (10),
col239 char (10),
col240 char (10),
col241 char (10),
col242 char (10),
col243 char (10),
col244 char (10),
col245 char (10),
col246 char (10),
col247 char (10),
col248 char (10),
col249 char (10),
col250 char (10),
col251 char (10),
col252 char (10),
col253 char (10),
col254 char (10),
col255 char (10),
col256 char (10),
col257 char (10),
col258 char (10),
col259 char (10),
col260 char (10),
col261 char (10),
col262 char (10),
col263 char (10),
col264 char (10),
col265 char (10),
col266 char (10),
col267 char (10),
col268 char (10),
col269 char (10),
col270 char (10),
col271 char (10),
col272 char (10),
col273 char (10),
col274 char (10),
col275 char (10),
col276 char (10),
col277 char (10),
col278 char (10),
col279 char (10),
col280 char (10),
col281 char (10),
col282 char (10),
col283 char (10),
col284 char (10),
col285 char (10),
col286 char (10),
col287 char (10),
col288 char (10),
col289 char (10),
col290 char (10),
col291 char (10),
col292 char (10),
col293 char (10),
col294 char (10),
col295 char (10),
col296 char (10),
col297 char (10),
col298 char (10),
col299 char (10),
col300 char (10),
col301 char (10)
);
ECHO BOTH $IF $EQU $STATE 37000  "PASSED" "***FAILED";
ECHO BOTH ": table with 301 cols in create table " $STATE "\n";

drop table colcnttest;

create table colcnttest (
col1 char (10),
col2 char (10),
col3 char (10),
col4 char (10),
col5 char (10),
col6 char (10),
col7 char (10),
col8 char (10),
col9 char (10),
col10 char (10),
col11 char (10),
col12 char (10),
col13 char (10),
col14 char (10),
col15 char (10),
col16 char (10),
col17 char (10),
col18 char (10),
col19 char (10),
col20 char (10),
col21 char (10),
col22 char (10),
col23 char (10),
col24 char (10),
col25 char (10),
col26 char (10),
col27 char (10),
col28 char (10),
col29 char (10),
col30 char (10),
col31 char (10),
col32 char (10),
col33 char (10),
col34 char (10),
col35 char (10),
col36 char (10),
col37 char (10),
col38 char (10),
col39 char (10),
col40 char (10),
col41 char (10),
col42 char (10),
col43 char (10),
col44 char (10),
col45 char (10),
col46 char (10),
col47 char (10),
col48 char (10),
col49 char (10),
col50 char (10),
col51 char (10),
col52 char (10),
col53 char (10),
col54 char (10),
col55 char (10),
col56 char (10),
col57 char (10),
col58 char (10),
col59 char (10),
col60 char (10),
col61 char (10),
col62 char (10),
col63 char (10),
col64 char (10),
col65 char (10),
col66 char (10),
col67 char (10),
col68 char (10),
col69 char (10),
col70 char (10),
col71 char (10),
col72 char (10),
col73 char (10),
col74 char (10),
col75 char (10),
col76 char (10),
col77 char (10),
col78 char (10),
col79 char (10),
col80 char (10),
col81 char (10),
col82 char (10),
col83 char (10),
col84 char (10),
col85 char (10),
col86 char (10),
col87 char (10),
col88 char (10),
col89 char (10),
col90 char (10),
col91 char (10),
col92 char (10),
col93 char (10),
col94 char (10),
col95 char (10),
col96 char (10),
col97 char (10),
col98 char (10),
col99 char (10),
col100 char (10),
col101 char (10),
col102 char (10),
col103 char (10),
col104 char (10),
col105 char (10),
col106 char (10),
col107 char (10),
col108 char (10),
col109 char (10),
col110 char (10),
col111 char (10),
col112 char (10),
col113 char (10),
col114 char (10),
col115 char (10),
col116 char (10),
col117 char (10),
col118 char (10),
col119 char (10),
col120 char (10),
col121 char (10),
col122 char (10),
col123 char (10),
col124 char (10),
col125 char (10),
col126 char (10),
col127 char (10),
col128 char (10),
col129 char (10),
col130 char (10),
col131 char (10),
col132 char (10),
col133 char (10),
col134 char (10),
col135 char (10),
col136 char (10),
col137 char (10),
col138 char (10),
col139 char (10),
col140 char (10),
col141 char (10),
col142 char (10),
col143 char (10),
col144 char (10),
col145 char (10),
col146 char (10),
col147 char (10),
col148 char (10),
col149 char (10),
col150 char (10),
col151 char (10),
col152 char (10),
col153 char (10),
col154 char (10),
col155 char (10),
col156 char (10),
col157 char (10),
col158 char (10),
col159 char (10),
col160 char (10),
col161 char (10),
col162 char (10),
col163 char (10),
col164 char (10),
col165 char (10),
col166 char (10),
col167 char (10),
col168 char (10),
col169 char (10),
col170 char (10),
col171 char (10),
col172 char (10),
col173 char (10),
col174 char (10),
col175 char (10),
col176 char (10),
col177 char (10),
col178 char (10),
col179 char (10),
col180 char (10),
col181 char (10),
col182 char (10),
col183 char (10),
col184 char (10),
col185 char (10),
col186 char (10),
col187 char (10),
col188 char (10),
col189 char (10),
col190 char (10),
col191 char (10),
col192 char (10),
col193 char (10),
col194 char (10),
col195 char (10),
col196 char (10),
col197 char (10),
col198 char (10),
col199 char (10),
col200 char (10),
col201 char (10),
col202 char (10),
col203 char (10),
col204 char (10),
col205 char (10),
col206 char (10),
col207 char (10),
col208 char (10),
col209 char (10),
col210 char (10),
col211 char (10),
col212 char (10),
col213 char (10),
col214 char (10),
col215 char (10),
col216 char (10),
col217 char (10),
col218 char (10),
col219 char (10),
col220 char (10),
col221 char (10),
col222 char (10),
col223 char (10),
col224 char (10),
col225 char (10),
col226 char (10),
col227 char (10),
col228 char (10),
col229 char (10),
col230 char (10),
col231 char (10),
col232 char (10),
col233 char (10),
col234 char (10),
col235 char (10),
col236 char (10),
col237 char (10),
col238 char (10),
col239 char (10),
col240 char (10),
col241 char (10),
col242 char (10),
col243 char (10),
col244 char (10),
col245 char (10),
col246 char (10),
col247 char (10),
col248 char (10),
col249 char (10),
col250 char (10),
col251 char (10),
col252 char (10),
col253 char (10),
col254 char (10),
col255 char (10),
col256 char (10),
col257 char (10),
col258 char (10),
col259 char (10),
col260 char (10),
col261 char (10),
col262 char (10),
col263 char (10),
col264 char (10),
col265 char (10),
col266 char (10),
col267 char (10),
col268 char (10),
col269 char (10),
col270 char (10),
col271 char (10),
col272 char (10),
col273 char (10),
col274 char (10),
col275 char (10),
col276 char (10),
col277 char (10),
col278 char (10),
col279 char (10),
col280 char (10),
col281 char (10),
col282 char (10),
col283 char (10),
col284 char (10),
col285 char (10),
col286 char (10),
col287 char (10),
col288 char (10),
col289 char (10),
col290 char (10),
col291 char (10),
col292 char (10),
col293 char (10),
col294 char (10),
col295 char (10),
col296 char (10),
col297 char (10),
col298 char (10),
col299 char (10),
col300 char (10)
);

alter table colcnttest  add errorcol integer;
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": adding column to table with 300 cols with alter table " $STATE "\n";

create table colinher  (under colcnttest, errorcol integer);
ECHO BOTH $IF $EQU $STATE 42S22  "PASSED" "***FAILED";
ECHO BOTH ": inheriting table with 300 cols with UNDER " $STATE "\n";


create table dupcols (id integer, id varchar);
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": creating a table with duplicate name " $STATE "\n";


create table dupcols (id integer);
alter table dupcols add id varchar;
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": alter table add with duplicate name " $STATE "\n";


drop table del_tst;

create table del_tst (id integer, ud varchar, primary key (id));

insert into del_tst values (2, '2');

create procedure del_proc (in dta varchar)
{
  declare b varchar;
  declare a, rc, n integer;
  declare c cursor for select id, ud from del_tst where id = n;

  n := atoi (dta);
  delete from del_tst where id = n;

  rc := 0;

  open c;
  whenever not found goto nf;
  fetch c into a, b;
  if (b = dta)
    {
      rc := 1;
    }
nf:
  close c;
  return rc;
}

select del_proc ('2');
ECHO BOTH $IF $EQU $LAST[1] 0  "PASSED" "***FAILED";
ECHO BOTH ": FETCH AFTER DELETE : COUNT=" $LAST[1] "\n";


create view sk as select a.key_table  from sys_keys a natural join sys_keys b;
update sk set key_table = 1;

create view vnulls as select CAST(null as float) as col0, 0 as col1;
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": create a view over a non-from select " $STATE "\n";

select * from vnulls;
ECHO BOTH $IF $EQU $LAST[1] NULL  "PASSED" "***FAILED";
ECHO BOTH ": view over a non-from select returned 1 " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] 0  "PASSED" "***FAILED";
ECHO BOTH ": view over a non-from select returned 2 " $LAST[2] "\n";

create procedure explore_table()
{
  declare keyid, subid integer;
  declare tablename varchar;
  declare cr cursor for select KEY_ID,KEY_TABLE from DB.DBA.SYS_KEYS;

  open cr;
  whenever not found goto fin;
  while (1)
    {
      fetch cr into keyid,tablename,subid;
    }
fin:
  close cr;
}
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": Virtuoso/PL fetch with 3 into params on a select with 2 output columns STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table WIDEZTEST;
create table WIDEZTEST (ID int not null primary key, DATA nvarchar);

insert into WIDEZTEST (ID, DATA) values (1, N'\5\0\1\0\2\0\3\0\4');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": inserting \\0 into nvarchar column STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into WIDEZTEST (ID, DATA) values (2, N'\x5\x0\x1\x0\x2\x0\x3\x0\x4');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": inserting \\x0 into nvarchar column STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into WIDEZTEST (ID, DATA) values (3, cast ('\x5\x0\x1\x0\x2\x0\x3\x0\x4' as nvarchar));
select length (DATA) from WIDEZTEST where ID = 3;
ECHO BOTH $IF $EQU $LAST[1] 9 "PASSED" "*** FAILED";
ECHO BOTH ": casting narrow binary zeroes string into nvarchar column STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into WIDEZTEST (ID, DATA) values (4, 0x81);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": inserting invalid varbinary into nvarchar column STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from (select xssfdsd from WIDEZTEST) a;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": select from a subquery containing invalid column STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create table SYS_COLS (id integer);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": create table SYS_COLS (an meta seed table) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

alter table WIDEZTEST add D2 varchar;
select COL_PREC, COL_SCALE, COL_CHECK from DB.DBA.SYS_COLS where "COLUMN" = 'D2' and "TABLE" = 'DB.DBA.WIDEZTEST';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "*** FAILED";
ECHO BOTH ": alter table add D2 varchar have precision " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] NULL "PASSED" "*** FAILED";
ECHO BOTH ": alter table add D2 varchar have scale " $LAST[2] "\n";
ECHO BOTH $IF $EQU $LAST[3] '' "PASSED" "*** FAILED";
ECHO BOTH ": alter table add D2 varchar have COL_CHECK " $LAST[3] "\n";

alter table WIDEZTEST add Z2 varchar(0);
select COL_PREC, COL_SCALE, COL_CHECK from DB.DBA.SYS_COLS where "COLUMN" = 'Z2' and "TABLE" = 'DB.DBA.WIDEZTEST';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "*** FAILED";
ECHO BOTH ": alter table add Z2 varchar(0) have precision " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] NULL "PASSED" "*** FAILED";
ECHO BOTH ": alter table add Z2 varchar(0) have scale " $LAST[2] "\n";
ECHO BOTH $IF $EQU $LAST[3] '' "PASSED" "*** FAILED";
ECHO BOTH ": alter table add Z2 varchar(0) have COL_CHECK " $LAST[3] "\n";

select * from ALEXANDER_THE_GREAT;
ECHO BOTH $IF $EQU $STATE 42S02 "PASSED" "*** FAILED";
ECHO BOTH ": select from non-existing table returns STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select 0x1234567890abcdef00;
ECHO BOTH $IF $EQU $LAST[1] "1234567890ABCDEF00" "PASSED" "*** FAILED";
ECHO BOTH ": parsing correctly the binary literals returned " $LAST[1] "\n";

select 0x1234567890abcdef0;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": parsing non-even bin literal STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select X'1234567890abcdef00';
ECHO BOTH $IF $EQU $LAST[1] "1234567890ABCDEF00" "PASSED" "*** FAILED";
ECHO BOTH ": parsing correctly the SQL binary literals returned " $LAST[1] "\n";

select X'1234567890abcdef0';
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": parsing non-even bin SQL literal STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select B'';
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": parsing zero len bit literal STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select B'3';
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": parsing invalid bit literal STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select B'1';
ECHO BOTH $IF $EQU $LAST[1] "01" "PASSED" "*** FAILED";
ECHO BOTH ": parsing correctly the bit literals returned " $LAST[1] "\n";

select B'100000001';
ECHO BOTH $IF $EQU $LAST[1] "0101" "PASSED" "*** FAILED";
ECHO BOTH ": parsing correctly non-even bit literals returned " $LAST[1] "\n";

select length (B'11111111');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "*** FAILED";
ECHO BOTH ": parsing correctly 1 byte bit literals returned len=" $LAST[1] "\n";

select length (B'111111110');
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "*** FAILED";
ECHO BOTH ": parsing correctly 2 byte bit literals returned len=" $LAST[1] "\n";

drop table ERR_T;
CREATE TABLE ERR_T ( ID integer, FILENAME varchar, XML_TEXT1 varchar identified by FILENAME, XML_TEXT2 varchar identified by FILENAME, primary key (ID));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": two identified by columns in a table STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure labeltest ()
{
  declare tid, sid integer;
  whenever not found goto fin;
  sid := '0';
fin:
  return 0;
fin:
  signal('xxx12','yyy34');
};
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": duplicate label declaration STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure test_var_scope ()
{
  if (1=2)
    {
      declare tvar integer;
    }
  else
    {
      tvar := 33;
    }
};
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": variable used outside it's scope STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- we just tested that server will not crash on log_text()
create procedure vtb_err(in vtb any) { return; };

log_text ('vtb_err(?)', vt_batch());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": vt_batch() object in log_text() STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table BUG1136..X;
drop table BUG1136..ERR;
create table BUG1136..X (ID integer primary key);
alter table  BUG1136..X add "t5.t6" integer;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": BUG 1136: alter STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
create table BUG1136..ERR ("t5.t6" integer primary key);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": BUG 1136: create STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


drop table BUG1444;
create table BUG1444 (id integer, FN varchar(16), LN varchar(16));

--And insert rows into it:

insert into BUG1444 values (1, 'Joe', 'Smith');
insert into BUG1444 values (2, 'Joe', 'Jones');
insert into BUG1444 values (3, 'Joe', 'Zupke');
insert into BUG1444 values (4, 'Sue', 'Smith');
insert into BUG1444 values (5, 'Sue', 'Jones');

--And execute a query directly against Oracle in sqlplus:

select * from BUG1444 where (FN, LN) in (('Joe', 'Smith'), ('Sue', 'Jones'));
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "*** FAILED";
ECHO BOTH ": BUG 1144: nested IN STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


create procedure BUG1534()
{
    if((SELECT 1 FROM SYS_KEYS WHERE KEY_ID = -1))
      {
         return;
      };
};

BUG1534 ();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": BUG 1534: scalar subq in IF STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select (select 1 from SYS_KEYS where KEY_ID = -1);
ECHO BOTH $IF $EQU $LAST[1] NULL "PASSED" "*** FAILED";
ECHO BOTH ": BUG 1534: scalar subq in select STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- suite for bug #1498
CREATE PROCEDURE OB..test(
      IN param INTEGER := -1, IN param1 numeric := -11.00, IN param3 integer := +2, IN param4 numeric := -12.12)
{
    RETURN param;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": BUG 1498: proc param negative default STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

exec ('CREATE TABLE BUG1647PERSONS (
      IDNUM INTEGER NOT NULL,
      NAME  VARCHAR(50),
      NATIONALITY VARCHAR(50),
      ADDRESS VARCHAR(30),
      PRIMARY KEY (IDNUM));
    INSERT INTO BUG1647PERSONS VALUES (
      111223333, ''Alan Wexelblat'', ''US Citizen'', ''Burlington, MA'');
    INSERT INTO BUG1647PERSONS VALUES (
      222334444, ''Vlad Kaluzhny'', ''Russian Citizen'', ''Novosibirsk'')');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": BUG 1647: semicolon .y error STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


create table BUG1886(FLD decimal(10, 13));
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": BUG 1886: numeric precision check STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table "%n";
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": BUG 2460: format string in the error message STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select deserialize(serialize(1000001));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": BUG 2864: deserialize integer STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select left('Virtuoso', -1);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": BUG 3094: negative left size STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


explain ('
create procedure bug ()
{
  declare a,b varchar;
  a := ''1'';
  b := ''2'';
  return concat (a -- test
                 b);
}
')
;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": AS exp not allowed outside select list STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop procedure B3743;
create procedure B3743(){

  declare aValue,retvalue any;

  aValue := vector(501,501);

  dbg_obj_print('-========-');
  dbg_obj_print('the value alone                    :',aValue);
  dbg_obj_print('serialized value                   :',serialize(aValue));
  dbg_obj_print('serialized and deserialized value  :',deserialize(serialize (aValue)));
  dbg_obj_print('result of registry_set             :',registry_set ('B3743',serialize(aValue)));
  dbg_obj_print('result of registry_get             :',registry_get ('B3743'));
  retvalue := deserialize(registry_get ('B3743'));
  dbg_obj_print('deserialized result of registry_get:',retvalue);

  if (serialize(aValue) <> serialize(retvalue))
    signal ('ts001', 'registry serialized value different');
};

call B3743();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": B3743: seralization & registry co-exist STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


-- bug #3946
select top 10 KEY_TABLE from SYS_KEYS where not exists (select V_NAME from SYS_VIEWS where KEY_TABLE = V_NAME);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": B3946: GPF check in the wrong place STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table B5378;
create table B5378(
  ID  integer  primary key,
  TXT varchar(10000)
);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": B5378: wrong column prec STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table OVERFLOW_TESTS;
create table OVERFLOW_TESTS (ID varchar, ID_PK varchar, ID_FK varchar, primary key (ID, ID_PK));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": OVERFLOW_TESTS table created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create index OT_ID_FK on OVERFLOW_TESTS (ID, ID_FK);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": OVERFLOW_TESTS inx created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete from OVERFLOW_TESTS;
insert into OVERFLOW_TESTS (ID, ID_PK) values (repeat ('a', 3000), repeat ('b', 2000));
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": OVERFLOW_TESTS INS: p key too long STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete from OVERFLOW_TESTS;
insert into OVERFLOW_TESTS (ID, ID_PK, ID_FK) values (repeat ('a', 3000), 'b', repeat ('c', 2000));
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": OVERFLOW_TESTS INS: sec key too long STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete from OVERFLOW_TESTS;
insert into OVERFLOW_TESTS (ID, ID_PK) values (repeat ('a', 1000), repeat ('b', 4000));
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": OVERFLOW_TESTS INS: p row too long STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete from OVERFLOW_TESTS;
insert into OVERFLOW_TESTS (ID, ID_PK, ID_FK) values (repeat ('a', 1000), 'b', repeat ('c', 4000));
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": OVERFLOW_TESTS INS: sec row too long STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete from OVERFLOW_TESTS;

insert into OVERFLOW_TESTS (ID, ID_PK, ID_FK) values ('a', 'b', 'c');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": OVERFLOW_TESTS ins OK STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update OVERFLOW_TESTS set ID = repeat ('a', 3000), ID_PK = repeat ('b', 2000);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": OVERFLOW_TESTS UPD: p key too long STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update OVERFLOW_TESTS set ID = repeat ('a', 3000), ID_PK = 'b', ID_FK = repeat ('c', 2000);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": OVERFLOW_TESTS UPD: sec key too long STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update OVERFLOW_TESTS set ID = repeat ('a', 1000), ID_PK = repeat ('b', 4000);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": OVERFLOW_TESTS UPD: p row too long STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update OVERFLOW_TESTS set ID = repeat ('a', 1000), ID_PK = 'b', ID_FK = repeat ('c', 4000);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": OVERFLOW_TESTS UPD: sec row too long STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table TTROW1;
create table TTROW1 (
    I1 INTEGER identity,
    I2 INTEGER,
    I3 INTEGER,
    I4 INTEGER,
    V1 VARCHAR,
    V2 VARCHAR,
    D1 VARCHAR,
    primary key (I1, I2, I3, I4, V1, V2));

insert into TTROW1 (I2, I3, I4, V1, V2) values (1,2,3, make_string (1024), make_string (850));
create index xx_tt2 on TTROW1 (V2, V1, I4, I3, I2, I1);
update TTROW1 set D1 = make_string (1);

create index TTROW1_SEC on TTROW1 (D1, V1, I4, I3, I2, I1);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": Can't create index : ruling part too long STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from DB.DBA.SYS_KEYS where KEY_TABLE = 'DB.DBA.TTROW1' and KEY_NAME = 'TTROW1_SEC';
select count (*) from DB.DBA.SYS_KEYS where KEY_TABLE = 'DB.DBA.TTROW1' and KEY_NAME = 'TTROW1_SEC';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": Can't create index : no index after the error STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update TTROW1 set D1 = make_string (2179);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": max row length row updated STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

foreach integer between 1 1000 insert into TTROW1 (I2, I3, I4, V1, V2, D1)
   values (1,2,3, make_string (1024), make_string (850), make_string (2179));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": max row length row inserted STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into TTROW1 (I2, I3, I4, V1, V2)
   values (1,2,3, make_string (1024), make_string (1853));
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": PK key too long in insert STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into TTROW1 (I2, I3, I4, V1, V2, D1)
   values (1,2,3, make_string (1024), make_string (850), make_string (2186));
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": PK key row too long in insert STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update TTROW1 set V2 = make_string (2180);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": PK key too long in update STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update TTROW1 set D1 = make_string (2186);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": PK key row too long in update STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete from TTROW1;
create index TTROW1_SEC on TTROW1 (D1, V1, I4, I3, I2, I1);
insert into TTROW1 (I2, I3, I4, V1, V2, D1) values
   (1,2,3, make_string (1024), make_string (800), make_string (1200));
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": sec key too long in insert STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


drop table QQ;
create table QQ (I integer primary key, V varchar);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": PK replace tb made STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create index QQ on QQ(V,i);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": PK replace tried STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table B8648;
create table B8648 (id int primary key, data varchar (50));

foreach integer between 1 20000 insert into B8648 (id) values (?);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": B8648-1: 20k rows added STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create index B8648_INX on B8648 (data, data2);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": B8648-2: wrong col in create index STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from SYS_KEYS where KEY_NAME = 'B8648_INX';
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
ECHO BOTH ": B8648-3: no schema after wrong create index STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create index B8648_INX on B8648 (data, data2);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": B8648-4: wrong col in create index STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select sprintf ('%s %s', make_string (10000000), make_string (10000000));
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": 8961: sprintf returns string too long STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table DCOL_PK;
create table DCOL_PK (ID int, DATA varchar (50), primary key (ID, ID, ID));
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": duplicate column primary key STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table DCOL_INX;
create table DCOL_INX (ID int, DATA varchar (50), primary key (ID));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": duplicate column inx table STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create unique index DCOL_INX_I on DCOL_INX (ID, ID, ID);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": duplicate column inx STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select cast ('2005-02-31' as date);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": bug 10188 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


create procedure test_cursor_pars ()
{
  declare rw, tmp, inx int;
  declare cr cursor for select ROW_NO from T1 where ROW_NO > rw;
  rw := '';
  inx := 0;
  whenever not found goto _end;
  open cr (prefetch 1);
  while (1)
    {
      fetch cr into tmp;
      rw := tmp;
      if (mod (inx, 2) = 0)
	rw := cast (tmp as varchar);
      inx := inx + 1;
      --if (inx > 10)
	--goto _end;
    }
 _end:
  close cr;
  return inx;
};


select test_cursor_pars ();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": search param changed on oppened cursor STATE=" $STATE " MESSAGE=" $MESSAGE "\n";



create procedure bf ()
{
  declare _b1 any;
  select b1 into _b1 from blobs where row_no = 1;
  delete from blobs where row_no = 1;
  commit work;
  insert into blobs (row_no, b1) values (1,  _b1);
}



create procedure bf2 ()
{
  declare _b1 any;
  select b1 into _b1 from blobs where row_no = 2;
  delete from blobs where row_no = 2;
  commit work;
  return blob_to_string (_b1);
}
ECHO BOTH "Error messages about reading free pages and bad blobs are expected next.  Ignore until a message says that this is no longer expected.\n";

--bf();
--bf2();

--ECHO BOTH $IF $EQU $SQLSTATE "22023" "PASSED" "***FAILED";
--ECHO BOTH ": deleted blob read in blob_to_string\n";

ECHO BOTH "Error messages about bad blobs or reading free pages are not expected after this point.\n";


-- bad nvarchar processing in ins replacing 
create table DB.DBA.UZZZER (
  KOD integer not null primary key,
  LGN nvarchar not null unique,
  FNAME nvarchar,
  MNAME nvarchar,
  LNAME nvarchar,
  ISGRP integer not null,
  ENB integer not null,
  CMT long nvarchar 
);

insert replacing DB.DBA.UZZZER (
  KOD, LGN, FNAME, MNAME, LNAME, ISGRP, ENB, CMT )
  values ( 1, N'?? ??', N'????????', N'????', N'??????????', 0, 1, N'?? ??????? ????????, ??????? ? ???????? ???????? ?? ?????, ????? ?????? ??? ???? ?????? ??????????? ????? ? ????????, ??? ????? ????? ????? ?????' );

insert replacing DB.DBA.UZZZER (
  KOD, LGN, FNAME, MNAME, LNAME, ISGRP, ENB, CMT )
  values ( 1, N'?? ??', N'????????', N'????', N'??????????', 0, 1, N'?? ??????? ????????, ??????? ? ???????? ???????? ?? ?????, ????? ?????? ??? ???? ?????? ??????????? ????? ? ????????, ??? ????? ????? ????? ?????' );


-- some non serializable cluster msg 
cl_exec ('dbg_obj_print (?)', params => vector (dict_new ()));

create table mig (id int primary key, d1 int);
create table mig2 (under mig, d2 int);
create table mig3 (under mig, d3 int);
create table mig4 (under mig3, d3 int);


alter table mig add d4 varchar;
alter table mig add d5 varchar;
alter table mig drop d4;
alter table mig drop d5;

alter table mig add d4 varchar;
alter table mig add d5 varchar;
alter table mig drop d4;
alter table mig drop d5;

alter table mig add d4 varchar;
alter table mig add d5 varchar;
alter table mig drop d4;
alter table mig drop d5;

alter table mig add d4 varchar;
alter table mig add d5 varchar;
alter table mig drop d4;
alter table mig drop d5;

alter table mig add d4 varchar;
alter table mig add d5 varchar;
alter table mig drop d4;
alter table mig drop d5;

alter table mig add d4 varchar;
alter table mig add d5 varchar;
alter table mig drop d4;
alter table mig drop d5;

alter table mig add d4 varchar;
alter table mig add d5 varchar;
alter table mig drop d4;
alter table mig drop d5;

alter table mig add d4 varchar;
alter table mig add d5 varchar;
alter table mig drop d4;
alter table mig drop d5;

alter table mig add d4 varchar;
alter table mig add d5 varchar;
alter table mig drop d4;
alter table mig drop d5;


alter table mig add d4 varchar;
alter table mig add d5 varchar;
alter table mig drop d4;
alter table mig drop d5;



alter table mig add d4 varchar;
alter table mig add d5 varchar;
alter table mig drop d4;
alter table mig drop d5;





drop table mig;
