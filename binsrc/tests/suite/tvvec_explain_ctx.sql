--
--  tvvec_explain_ctx.sql
--
--  Every BIF that reports through trset_printf() shares one report context
--  (trset_ctx_t, allocated by trset_start()).  __vvec_explain_str added a
--  member to that struct, tc_ses, which redirects the report into a string
--  session instead of pushing result rows -- but trset_start() allocates the
--  context with dk_alloc_box(), which does not zero, and never assigned the
--  new member.  Every trset_start() caller therefore read whatever the heap
--  happened to hold: a non-NULL value swallows the whole report (zero rows),
--  a wild one crashes the server, and on a fresh database the crash happened
--  during startup.
--
--  These assertions cover the observable half: every trset reporter still
--  returns its rows, and mixing __vvec_explain_str (which does set tc_ses)
--  with the row-returning reporters does not leak that setting into them.
--  The structural half -- that trset_start() initialises every member -- is
--  asserted from the source by tvvec_explain_ctx.sh, because whether an
--  uninitialised read happens to be NULL is not reproducible.
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2026 OpenLink Software
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

--  Count the rows a report BIF pushes, without depending on its text.  An
--  uninitialised tc_ses that happens to be non-NULL diverts every line away
--  from bif_result_inside_bif, so the count drops to zero.
create function DB.DBA.VVEC_TRSET_ROWS (in stmt varchar) returns integer
{
  declare _stat, _msg varchar;
  declare _meta, _rows any;
  _stat := '00000';
  _rows := null;
  exec (stmt, _stat, _msg, vector (), 0, _meta, _rows);
  if (_stat <> '00000')
    return -1;
  --  A reporter that legitimately has nothing to say (http_acl_stats with no
  --  rate-limited ACLs) leaves _rows an integer, not an array.  Returning 0
  --  rather than letting length () raise keeps a real failure from arriving as
  --  an out-of-bounds $LAST[1], which ECHO reads as a pass.
  if (isarray (_rows))
    return length (_rows);
  return 0;
};

select DB.DBA.VVEC_TRSET_ROWS ('explain (''select 1'')');
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": explain () pushes report rows rows=" $LAST[1] "\n";

select DB.DBA.VVEC_TRSET_ROWS ('status ('''')');
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": status () pushes report rows rows=" $LAST[1] "\n";

--  http_acl_stats is a trset reporter too, and driving it here turned up a
--  second, unrelated crash: it dereferences the http_acls hash, which used to
--  be created only when an HTTP listener was configured, so on a server
--  without one this call killed the process.  Zero rows is the right answer
--  for a server with no rate-limited ACLs; not surviving the call is not.
select DB.DBA.VVEC_TRSET_ROWS ('http_acl_stats ()');
ECHO BOTH $IF $GTE $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": http_acl_stats () completes rows=" $LAST[1] "\n";

--  __vvec_explain_str is the one reporter that does set tc_ses: it returns the
--  plan as a string rather than as rows.
select case when strstr (__vvec_explain_str ('select 1'), 'Select') is not null then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": __vvec_explain_str returns the plan as a string\n";

select length (__vvec_explain_str ('select 1'));
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": __vvec_explain_str output is non-empty len=" $LAST[1] "\n";

--  Interleave the two surfaces.  trset_start () must not inherit the tc_ses
--  __vvec_explain_str left behind (in a freed context of exactly this size),
--  and __vvec_explain_str must not start pushing rows.
select DB.DBA.VVEC_TRSET_ROWS ('explain (''select 1'')') +
       DB.DBA.VVEC_TRSET_ROWS ('explain (''select count (*) from DB.DBA.SYS_KEYS'')');
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": explain () after __vvec_explain_str still pushes rows rows=" $LAST[1] "\n";

create function DB.DBA.VVEC_TRSET_MIXED () returns integer
{
  declare inx, rows integer;
  rows := 0;
  for (inx := 0; inx < 8; inx := inx + 1)
    {
      __vvec_explain_str ('select ' || cast (inx as varchar));
      rows := rows + DB.DBA.VVEC_TRSET_ROWS ('explain (''select ' || cast (inx as varchar) || ''')');
      __vvec_explain_str ('select count (*) from DB.DBA.SYS_KEYS');
      rows := rows + DB.DBA.VVEC_TRSET_ROWS ('status ('''')');
    }
  return rows;
};

select DB.DBA.VVEC_TRSET_MIXED ();
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": 16 interleaved string/row reports all produced output rows=" $LAST[1] "\n";

--  A report raised from inside a failing compile must restore the previous
--  context rather than leave a freed one installed for the next reporter.
create function DB.DBA.VVEC_TRSET_AFTER_ERROR () returns integer
{
  declare _stat, _msg varchar;
  declare _meta, _rows any;
  _stat := '00000';
  exec ('select __vvec_explain_str (''select * from DB.DBA.NO_SUCH_TABLE_HERE'')',
        _stat, _msg, vector (), 0, _meta, _rows);
  return DB.DBA.VVEC_TRSET_ROWS ('explain (''select 1'')');
};

select DB.DBA.VVEC_TRSET_AFTER_ERROR ();
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": explain () after a failed __vvec_explain_str still pushes rows rows=" $LAST[1] "\n";

drop function DB.DBA.VVEC_TRSET_AFTER_ERROR;
drop function DB.DBA.VVEC_TRSET_MIXED;
drop function DB.DBA.VVEC_TRSET_ROWS;

select 'tvvec_explain_ctx done' as done;
