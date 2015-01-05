--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2015 OpenLink Software
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
--set echo on;

ECHO BOTH "Starting URL-Rewriter tests. In case of errors this may result a wait for timeout\n";

delete from DB.DBA.URL_REWRITE_RULE;
delete from DB.DBA.URL_REWRITE_RULE_LIST;

DB.DBA.URLREWRITE_CREATE_SPRINTF_RULE('rule1', 1, '/%s/%s/%d', vector('app_name', 'user_name', 'post_id'), 3, '/app_name=%s&post_id=%d&user_name=%s', vector('app_name', 'post_id', 'user_name'), NULL);
select URLREWRITE_ENUMERATE_RULES('%rul%')[0];
ECHO BOTH $IF $EQU $LAST[1] rule1  "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] "\n";

DB.DBA.URLREWRITE_CREATE_SPRINTF_RULE('rule2', 1, '/%s/%s/%d', vector('app_name', 'user_name', 'post_id'), 3, '/app_name=%s&post_id=%d&user_name=%s', vector('app_name', 'post_id', 'user_name'), NULL);
select URLREWRITE_ENUMERATE_RULES('%rul%')[1];
ECHO BOTH $IF $EQU $LAST[1] rule2  "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] "\n";

DB.DBA.URLREWRITE_CREATE_SPRINTF_RULE('rule22', 1, '/%s/%s/%d', vector('app_name', 'user_name', 'post_id'), 3, '/app_name2=%s&post_id2=%d&user_name2=%s', vector('app_name', 'post_id', 'user_name'), NULL);
select URLREWRITE_ENUMERATE_RULES('%rul%')[2];
ECHO BOTH $IF $EQU $LAST[1] rule22 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] "\n";


DB.DBA.URLREWRITE_CREATE_REGEX_RULE('rule4', 1, '/\([^/]*\)/\([^/]*\)/\([^/]*\)', vector('app_name', 'user_name', 'post_id'), 3, '/app_name3=%s&post_id3=%s&user_name3=%s', vector('app_name', 'post_id', 'user_name'), NULL);
select URLREWRITE_ENUMERATE_RULES('%rule4')[0];
ECHO BOTH $IF $EQU $LAST[1] rule4  "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] "\n";

DB.DBA.URLREWRITE_CREATE_RULELIST('rule_list2', 1, vector('rule1', 'rule2'));
DB.DBA.URLREWRITE_CREATE_RULELIST('rule_list1', 1, vector('rule_list2'));
DB.DBA.URLREWRITE_CREATE_RULELIST('rule_list22', 1, vector('rule22'));

select DB.DBA.URLREWRITE_ENUMERATE_RULELISTS('%rul%')[0];
ECHO BOTH $IF $EQU $LAST[1] rule_list1  "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] "\n";

select DB.DBA.URLREWRITE_ENUMERATE_RULELISTS('%rul%')[1];
ECHO BOTH $IF $EQU $LAST[1] rule_list2  "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] "\n";

DB.DBA.URLREWRITE_CREATE_SPRINTF_RULE('rule3', 1, '%/%s/%d', vector('app_name', 'user_name', 'post_id'), 3, '/app_name=%s&post_id=%d&user_name=%s', vector('app_name', 'post_id', 'user_name'), NULL);
select URLREWRITE_ENUMERATE_RULES('%rul%')[2];
ECHO BOTH $IF $EQU $LAST[1] rule22 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] "\n";

DB.DBA.URLREWRITE_DROP_RULE('rule3');
select length(URLREWRITE_ENUMERATE_RULES('%rule3'));
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] "\n";

DB.DBA.URLREWRITE_CREATE_RULELIST('rule_list4', 1, vector('rule4'));

DB.DBA.URLREWRITE_CREATE_RULELIST('rule_list3', 1, vector('rule_list2', 'rule1'));
select DB.DBA.URLREWRITE_ENUMERATE_RULELISTS('rule_list3')[0];
ECHO BOTH $IF $EQU $LAST[1] rule_list3  "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] "\n";

DB.DBA.URLREWRITE_DROP_RULELIST('rule_list3');
select length(DB.DBA.URLREWRITE_ENUMERATE_RULELISTS('rule_list3'));
ECHO BOTH $IF $EQU $LAST[1] 0  "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] "\n";

VHOST_REMOVE ('*ini*', '*ini*', '/weblog');
VHOST_REMOVE ('*ini*', '*ini*', '/weblog/aziz');
DB.DBA.VHOST_DEFINE(lpath=>'/weblog', ppath=>'/weblog/', vsp_user=>'dba', is_dav=>1,
        def_page => 'index.vspx', is_brws=>0,
        opts=>vector ('url_rewrite', 'rule_list2'));

create procedure DB.DBA.test_sprintf(in  path varchar) returns any
{
  declare long_url varchar;
  declare params any;
  declare nice_vhost_pkey any;
  declare top_rulelist_iri varchar;
  declare rule_iri varchar;
  declare target_vhost_pkey any;
  declare result int;
  DB.DBA.URLREWRITE_APPLY (path, null,
  long_url,
  params,
  nice_vhost_pkey,
  top_rulelist_iri,
  rule_iri,
  target_vhost_pkey);

  dbg_obj_princ('Result: ', long_url,  params,   nice_vhost_pkey,   top_rulelist_iri,  rule_iri,  target_vhost_pkey);

  return long_url;
};
select DB.DBA.test_sprintf('http://localhost:$U{HTTPPORT}/weblog/aziz/1');
ECHO BOTH $IF $EQU $LAST[1] '/app_name=weblog&post_id=1&user_name=aziz'  "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] "\n";


VHOST_REMOVE ('*ini*', '*ini*', '/weblog/aziz');
DB.DBA.VHOST_DEFINE(lpath=>'/weblog/aziz', ppath=>'/weblog/aziz/', vsp_user=>'dba', is_dav=>1,
        def_page => 'index.vspx', is_brws=>0,
        opts=>vector ('url_rewrite', 'rule_list22'));
select DB.DBA.test_sprintf('http://localhost:$U{HTTPPORT}/weblog/aziz/1');
ECHO BOTH $IF $EQU $LAST[1] '/app_name2=weblog&post_id2=1&user_name2=aziz'  "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] "\n";

select DB.DBA.test_sprintf('http://localhost:$U{HTTPPORT}/weblog/aziz');
ECHO BOTH $IF $EQU $LAST[1] '/app_name2=weblog&user_name2=aziz'  "***FAILED" "PASSED" ;
ECHO BOTH ": " $LAST[1] "\n";


VHOST_REMOVE ('*ini*', '*ini*', '/weblog');
DB.DBA.VHOST_DEFINE(lpath=>'/weblog', ppath=>'/weblog/', vsp_user=>'dba', is_dav=>1,
        def_page => 'index.vspx', is_brws=>0,
        opts=>vector ('url_rewrite', 'rule_list4'));
create procedure DB.DBA.test_regexp(in path varchar) returns any
{
  declare long_url varchar;
  declare params any;
  declare nice_vhost_pkey any;
  declare top_rulelist_iri varchar;
  declare rule_iri varchar;
  declare target_vhost_pkey any;
  declare result int;
  DB.DBA.URLREWRITE_APPLY (path, null,
  long_url,
  params,
  nice_vhost_pkey,
  top_rulelist_iri,
  rule_iri,
  target_vhost_pkey);

  dbg_obj_princ('Result22222222: ', long_url,  params,  nice_vhost_pkey,  top_rulelist_iri,  rule_iri,  target_vhost_pkey);

  return long_url;
};
select DB.DBA.test_regexp('http://localhost:$U{HTTPPORT}/weblog/aziz/1');
ECHO BOTH $IF $EQU $LAST[1] '/app_name=weblog&post_id=1&user_name=aziz'  "***FAILED" "PASSED";
ECHO BOTH ": " $LAST[1] "\n";

VHOST_REMOVE ('*ini*', '*ini*', '/weblog/aziz');
select DB.DBA.test_regexp('http://localhost:$U{HTTPPORT}/weblog/aziz/1');
ECHO BOTH $IF $EQU $LAST[1] '/app_name3=weblog&post_id3=1&user_name3=aziz'  "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] "\n";

select DB.DBA.test_regexp('http://localhost:$U{HTTPPORT}/weblog/aziz');
ECHO BOTH $IF $EQU $LAST[1] '/app_name3=weblog&user_name3=aziz'  "***FAILED" "PASSED";
ECHO BOTH ": " $LAST[1] "\n";


create procedure DB.DBA.test_inverse(in rule varchar, in path varchar)
{
  declare nice_path varchar;
  declare nice_params any;
  declare error_report varchar;
  declare param_retrieval_cache any;
  param_retrieval_cache := null;

-- dbg_obj_princ('\r\n');
-- dbg_obj_princ('\r\nBegin:');
  DB.DBA.URLREWRITE_TRY_INVERSE (
  rule,
  path,
  null,
  null,
  null,
  param_retrieval_cache,
  nice_path,
  nice_params,
  error_report);

  dbg_obj_princ('Result: ', nice_path, nice_params, error_report);
  return nice_path;
};

select DB.DBA.test_inverse('rule1', 'http://localhost:$U{HTTPPORT}/app_name=weblog&post_id=1&user_name=aziz');
ECHO BOTH $IF $EQU $LAST[1] 'weblog/aziz/1'  "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] "\n";


select DB.DBA.test_inverse('rule2', 'http://localhost:$U{HTTPPORT}/app_name=weblog&post_id=1&user_name=aziz');
ECHO BOTH $IF $EQU $LAST[1] 'weblog/aziz/1'  "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] "\n";


select DB.DBA.test_inverse('rule4', 'http://localhost:$U{HTTPPORT}/app_name=weblog&post_id=1&user_name=aziz');
ECHO BOTH $IF $EQU $LAST[1] 'weblog/aziz/1'  "***FAILED" "PASSED";
ECHO BOTH ": " $LAST[1] "\n";


select DB.DBA.test_inverse('rule3', 'http://localhost:$U{HTTPPORT}/app_name=weblog&post_id=1&user_name=aziz');
ECHO BOTH $IF $EQU $LAST[1] 'weblog/aziz/1'  "***FAILED" "PASSED";
ECHO BOTH ": " $LAST[1] "\n";

select DB.DBA.test_inverse('rule22', 'http://localhost:$U{HTTPPORT}/app_name=weblog&post_id=1&user_name=aziz');
ECHO BOTH $IF $EQU $LAST[1] 'weblog/aziz/1'  "***FAILED" "PASSED";
ECHO BOTH ": " $LAST[1] "\n";
