--
--  tvvec_api_keys.sql
--
--  Embedding-provider API keys are readable and writable by DBA accounts only.
--
--  DB.DBA.ONNX_API_KEY_SET and ONNX_PROVIDER_API_KEY_SET are DBA-only, but
--  they keep the key in the server registry, under a name of the
--  ONNX_API_KEY_ convention, and registry_get had no authorization at all:
--  any SQL account could read every provider key, and registry_set or
--  registry_remove could replace or delete it.  Keys under that prefix are
--  now visible to DBA accounts and to procedures a DBA owns -- the embedding
--  procedures read them that way, so non-DBA callers can still use a model
--  that needs a key -- and to no one else.  ONNX_API_KEY_SET accepts only
--  names under the prefix, so no key it stores falls outside the rule.
--
--  1-5 are tests of the change (each fails before it); 6-9 are guards and
--  hold on both sides:
--    1. A non-DBA account's registry_get of a key returns what it returns
--       for a name that is not set, 0.  Before: the key.
--    2. ... and with a default, the default.  Before: the key.
--    3. Its registry_set of a key is refused, and the key is unchanged.
--       Before: replaced.
--    4. Its registry_remove of a key is refused, and the key is still there.
--       Before: removed.
--    5. ONNX_API_KEY_SET refuses a name outside the prefix.  Before: stored,
--       where any account could read it.
--    6. A DBA account reads the key.
--    7. A procedure a DBA owns, executed by the non-DBA account, reads the
--       key: what the embedding procedures do.
--    8. The non-DBA account still reads and writes a registry name outside
--       the prefix.
--    9. ONNX_API_KEY_SET stays DBA-only.
--
--  Self-contained: its own registry names and its own account, removed at
--  the end.  Needs neither the plugin nor a provider.
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

echo BOTH "STARTED: embedding-provider API keys are DBA-only\n";

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------

select DB.DBA.ONNX_API_KEY_SET ('ONNX_API_KEY_TVK', 'tvk-dummy-key');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": store a dummy key STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

registry_set ('TVK_PUBLIC_SETTING', 'tvk-public-value');

create procedure DB.DBA.TVK_USER (in _n varchar, in _pw varchar)
{
  declare exit handler for sqlstate '*' { ; };
  if (exists (select 1 from DB.DBA.SYS_USERS where U_NAME = _n))
    DB.DBA.USER_DROP (_n, 0);
  DB.DBA.USER_CREATE (_n, _pw, vector ('SQL_ENABLE', 1));
};
DB.DBA.TVK_USER ('tvk_user', 'tvk_user_pw');
select count (*) from DB.DBA.SYS_USERS where U_NAME = 'tvk_user';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": a SQL account with no grants: " $LAST[1] "\n";

--  Run a statement as _USER and return its first column of its first row, as
--  varchar; 'NULL' for a null, '(none)' for no row, 'ERR <state>' when it was
--  refused.  exec () compiles as the user, so a bif in it sees the user, not
--  the owner of this procedure.
create function DB.DBA.TVK_AS (in _user varchar, in _stmt varchar) returns varchar
{
  declare _st, _msg varchar;
  declare _md, _rows any;
  __set_user_id (_user);
  _st := '00000';
  _rows := null;
  exec (_stmt, _st, _msg, vector (), 0, _md, _rows);
  __pop_user_id ();
  if (_st <> '00000')
    return 'ERR ' || _st;
  if (not isarray (_rows) or 0 = length (_rows))
    return '(none)';
  if (_rows[0][0] is null)
    return 'NULL';
  return cast (_rows[0][0] as varchar);
};

--  What the embedding procedures do: a procedure a DBA owns reads the key.
create function DB.DBA.TVK_KEY_LENGTH () returns integer
{
  return length (registry_get ('ONNX_API_KEY_TVK'));
};
grant execute on DB.DBA.TVK_KEY_LENGTH to "tvk_user";
grant execute on DB.DBA.ONNX_API_KEY_SET to "tvk_user";

-- ---------------------------------------------------------------------------
-- 1-4. A non-DBA account and a key
-- ---------------------------------------------------------------------------

select DB.DBA.TVK_AS ('tvk_user', 'select registry_get (''ONNX_API_KEY_TVK'')');
ECHO BOTH $IF $EQU $LAST[1] "0" "PASSED" "***FAILED";
ECHO BOTH ": non-DBA registry_get of a key: " $LAST[1] "\n";

select DB.DBA.TVK_AS ('tvk_user', 'select registry_get (''ONNX_API_KEY_TVK'', ''tvk-default'')');
ECHO BOTH $IF $EQU $LAST[1] "tvk-default" "PASSED" "***FAILED";
ECHO BOTH ": non-DBA registry_get of a key with a default: " $LAST[1] "\n";

select DB.DBA.TVK_AS ('tvk_user', 'select registry_set (''ONNX_API_KEY_TVK'', ''tvk-replaced'')'), registry_get ('ONNX_API_KEY_TVK');
ECHO BOTH $IF $EQU $LAST[1] "ERR 42000" "PASSED" "***FAILED";
ECHO BOTH ": non-DBA registry_set of a key: " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] "tvk-dummy-key" "PASSED" "***FAILED";
ECHO BOTH ": ... and the key is unchanged: " $LAST[2] "\n";
registry_set ('ONNX_API_KEY_TVK', 'tvk-dummy-key');

select DB.DBA.TVK_AS ('tvk_user', 'select registry_remove (''ONNX_API_KEY_TVK'')'), registry_get ('ONNX_API_KEY_TVK');
ECHO BOTH $IF $EQU $LAST[1] "ERR 42000" "PASSED" "***FAILED";
ECHO BOTH ": non-DBA registry_remove of a key: " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] "tvk-dummy-key" "PASSED" "***FAILED";
ECHO BOTH ": ... and the key is still there: " $LAST[2] "\n";
registry_set ('ONNX_API_KEY_TVK', 'tvk-dummy-key');

-- ---------------------------------------------------------------------------
-- 5. ONNX_API_KEY_SET keeps keys under the prefix
-- ---------------------------------------------------------------------------

select DB.DBA.TVK_AS ('dba', 'select DB.DBA.ONNX_API_KEY_SET (''TVK_UNPREFIXED_KEY'', ''tvk-dummy-key'')'),
       case when isstring (registry_get ('TVK_UNPREFIXED_KEY')) then 'stored' else 'not stored' end;
ECHO BOTH $IF $EQU $LAST[1] "ERR 22023" "PASSED" "***FAILED";
ECHO BOTH ": ONNX_API_KEY_SET under a name outside ONNX_API_KEY_: " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] "not stored" "PASSED" "***FAILED";
ECHO BOTH ": ... and nothing is stored: " $LAST[2] "\n";
registry_remove ('TVK_UNPREFIXED_KEY');

-- ---------------------------------------------------------------------------
-- 6-9. Guards
-- ---------------------------------------------------------------------------

select registry_get ('ONNX_API_KEY_TVK');
ECHO BOTH $IF $EQU $LAST[1] "tvk-dummy-key" "PASSED" "***FAILED";
ECHO BOTH ": a DBA account reads the key: " $LAST[1] "\n";

select DB.DBA.TVK_AS ('tvk_user', 'select DB.DBA.TVK_KEY_LENGTH ()');
ECHO BOTH $IF $EQU $LAST[1] "13" "PASSED" "***FAILED";
ECHO BOTH ": a DBA-owned procedure reads the key for the non-DBA account, length: " $LAST[1] "\n";

select DB.DBA.TVK_AS ('tvk_user', 'select registry_get (''TVK_PUBLIC_SETTING'')'),
       DB.DBA.TVK_AS ('tvk_user', 'select registry_set (''TVK_PUBLIC_SETTING'', ''tvk-public-2'')'),
       registry_get ('TVK_PUBLIC_SETTING');
ECHO BOTH $IF $EQU $LAST[1] "tvk-public-value" "PASSED" "***FAILED";
ECHO BOTH ": the non-DBA account reads a name outside the prefix: " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[3] "tvk-public-2" "PASSED" "***FAILED";
ECHO BOTH ": ... and writes it: " $LAST[3] "\n";

select DB.DBA.TVK_AS ('tvk_user', 'select DB.DBA.ONNX_API_KEY_SET (''ONNX_API_KEY_TVK'', ''tvk-replaced'')'), registry_get ('ONNX_API_KEY_TVK');
ECHO BOTH $IF $EQU $LAST[1] "ERR 42000" "PASSED" "***FAILED";
ECHO BOTH ": ONNX_API_KEY_SET stays DBA-only: " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] "tvk-dummy-key" "PASSED" "***FAILED";
ECHO BOTH ": ... and the key is unchanged: " $LAST[2] "\n";

-- ---------------------------------------------------------------------------
-- Cleanup
-- ---------------------------------------------------------------------------

registry_remove ('ONNX_API_KEY_TVK');
registry_remove ('TVK_PUBLIC_SETTING');
DB.DBA.USER_DROP ('tvk_user', 0);
drop function DB.DBA.TVK_KEY_LENGTH;
drop function DB.DBA.TVK_AS;
drop procedure DB.DBA.TVK_USER;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": cleanup STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

echo BOTH "COMPLETED: embedding-provider API keys are DBA-only\n";
