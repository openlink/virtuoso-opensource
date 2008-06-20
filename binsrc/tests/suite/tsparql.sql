create function DB.DBA.RDF_DF_GRANTEE_ID_URI (in id integer)
{
  declare isrole integer;
  isrole := coalesce ((select top 1 U_IS_ROLE from DB.DBA.SYS_USERS where U_ID = id));
  if (isrole is null)
    return NULL;
  else if (isrole)
    return sprintf ('http://%{WSHostName}U:%{WSHostPort}U/sys/group?id=%d', id);
  else
    return sprintf ('http://%{WSHostName}U:%{WSHostPort}U/sys/user?id=%d', id);
}
;

DB.DBA.VHOST_DEFINE (vhost=>'localhost:$U{HTTPPORT1}', lhost=>'localhost:$U{HTTPPORT1}', lpath=>'/sparql/', ppath => '/!sparql/', is_dav => 1, vsp_user => 'dba', opts => vector('noinherit', 1));

grant execute on DB.DBA.RDF_DF_GRANTEE_ID_URI to SPARQL_SELECT
;

create function DB.DBA.RDF_DF_GRANTEE_ID_URI_INVERSE (in id_iri varchar)
{
  declare parts any;
  parts := sprintf_inverse (id_iri, sprintf ('http://%{WSHostName}U:%{WSHostPort}U/sys/user?id=%%d'), 1);
  if (parts is not null)
    {
      if (exists (select top 1 1 from DB.DBA.SYS_USERS where U_ID = parts[0] and not U_IS_ROLE))
        return parts[0];
    }
  parts := sprintf_inverse (id_iri, sprintf ('http://%{WSHostName}U:%{WSHostPort}U/sys/group?id=%%d'), 1);
  if (parts is not null)
    {
      if (exists (select top 1 1 from DB.DBA.SYS_USERS where U_ID = parts[0] and U_IS_ROLE))
        return parts[0];
    }
  return NULL;
}
;

grant execute on DB.DBA.RDF_DF_GRANTEE_ID_URI_INVERSE to SPARQL_SELECT
;

create function DB.DBA.RDF_DF_MN_URI (in super integer, in sub integer) returns varchar
{
  declare super_is_role integer;
  super_is_role := coalesce ((select top 1 U_IS_ROLE from DB.DBA.SYS_USERS where U_ID = super));
  if (super_is_role is null)
    return NULL;
  else if (super_is_role)
    return sprintf ('http://%{WSHostName}U:%{WSHostPort}U/sys/mn?group=%d&role=%d', super, sub);
  else
    return sprintf ('http://%{WSHostName}U:%{WSHostPort}U/sys/mn?user=%d&role=%d', super, sub);
}
;

grant execute on DB.DBA.RDF_DF_MN_URI to SPARQL_SELECT
;

create function DB.DBA.RDF_DF_MN_URI_INV_1 (in mn_iri varchar) returns integer
{
  declare parts any;
  parts := sprintf_inverse (mn_iri, sprintf ('http://%{WSHostName}U:%{WSHostPort}U/sys/mn?user=%%d&role=%%d'), 1);
  if (parts is not null)
    {
      if (exists (select top 1 1 from DB.DBA.SYS_USERS where U_ID = parts[0] and not U_IS_ROLE))
        return parts[0];
    }
  parts := sprintf_inverse (mn_iri, sprintf ('http://%{WSHostName}U:%{WSHostPort}U/sys/mn?group=%%d&role=%%d'), 1);
  if (parts is not null)
    {
      if (exists (select top 1 1 from DB.DBA.SYS_USERS where U_ID = parts[0] and U_IS_ROLE))
        return parts[0];
    }
  return NULL;
}
;

grant execute on DB.DBA.RDF_DF_MN_URI_INV_1 to SPARQL_SELECT
;

create function DB.DBA.RDF_DF_MN_URI_INV_2 (in mn_iri varchar) returns integer
{
  declare parts any;
  parts := sprintf_inverse (mn_iri, sprintf ('http://%{WSHostName}U:%{WSHostPort}U/sys/mn?user=%%d&role=%%d'), 1);
  if (parts is not null)
    {
      if (exists (select top 1 1 from DB.DBA.SYS_USERS where U_ID = parts[0] and not U_IS_ROLE))
        return parts[1];
    }
  parts := sprintf_inverse (mn_iri, sprintf ('http://%{WSHostName}U:%{WSHostPort}U/sys/mn?group=%%d&role=%%d'), 1);
  if (parts is not null)
    {
      if (exists (select top 1 1 from DB.DBA.SYS_USERS where U_ID = parts[0] and U_IS_ROLE))
        return parts[1];
    }
  return NULL;
}
;

grant execute on DB.DBA.RDF_DF_MN_URI_INV_2 to SPARQL_SELECT
;

create function DB.DBA.RDF_DF_GRANTEE_ID_LIT (in id integer)
{
  declare isrole integer;
  isrole := coalesce ((select top 1 U_IS_ROLE from DB.DBA.SYS_USERS where U_ID = id));
  if (isrole is null)
    return NULL;
  else if (isrole)
    return sprintf ('lit-%{WSHostName}U:%{WSHostPort}U/sys/group?id=%d', id);
  else
    return sprintf ('lit-%{WSHostName}U:%{WSHostPort}U/sys/user?id=%d', id);
}
;

grant execute on DB.DBA.RDF_DF_GRANTEE_ID_LIT to SPARQL_SELECT
;

create function DB.DBA.RDF_DF_GRANTEE_ID_LIT_INVERSE (in id_lit varchar)
{
  declare parts any;
  parts := sprintf_inverse (id_lit, sprintf ('lit-%{WSHostName}U:%{WSHostPort}U/sys/user?id=%%d'), 1);
  if (parts is not null)
    {
      if (exists (select top 1 1 from DB.DBA.SYS_USERS where U_ID = parts[0] and not U_IS_ROLE))
        return parts[0];
    }
  parts := sprintf_inverse (id_lit, sprintf ('lit-%{WSHostName}U:%{WSHostPort}U/sys/group?id=%%d'), 1);
  if (parts is not null)
    {
      if (exists (select top 1 1 from DB.DBA.SYS_USERS where U_ID = parts[0] and U_IS_ROLE))
        return parts[0];
    }
  return NULL;
}
;

grant execute on DB.DBA.RDF_DF_GRANTEE_ID_LIT_INVERSE to SPARQL_SELECT
;

create function DB.DBA.RDF_DF_MN_LIT (in super integer, in sub integer) returns varchar
{
  declare super_is_role integer;
  super_is_role := coalesce ((select top 1 U_IS_ROLE from DB.DBA.SYS_USERS where U_ID = super));
  if (super_is_role is null)
    return NULL;
  if (super_is_role)
    return sprintf ('lit-%{WSHostName}U:%{WSHostPort}U/sys/mn?group=%d&role=%d', super, sub);
  else
    return sprintf ('lit-%{WSHostName}U:%{WSHostPort}U/sys/mn?user=%d&role=%d', super, sub);
}
;

grant execute on DB.DBA.RDF_DF_MN_LIT to SPARQL_SELECT
;

create function DB.DBA.RDF_DF_MN_LIT_INV_1 (in mn_lit varchar) returns integer
{
  declare parts any;
  parts := sprintf_inverse (mn_lit, sprintf ('lit-%{WSHostName}U:%{WSHostPort}U/sys/mn?user=%%d&role=%%d'), 1);
  if (parts is not null)
    {
      if (exists (select top 1 1 from DB.DBA.SYS_USERS where U_ID = parts[0] and not U_IS_ROLE))
        return parts[0];
    }
  parts := sprintf_inverse (mn_lit, sprintf ('lit-%{WSHostName}U:%{WSHostPort}U/sys/mn?group=%%d&role=%%d'), 1);
  if (parts is not null)
    {
      if (exists (select top 1 1 from DB.DBA.SYS_USERS where U_ID = parts[0] and U_IS_ROLE))
        return parts[0];
    }
  return NULL;
}
;

grant execute on DB.DBA.RDF_DF_MN_LIT_INV_1 to SPARQL_SELECT
;

create function DB.DBA.RDF_DF_MN_LIT_INV_2 (in mn_lit varchar) returns integer
{
  declare parts any;
  parts := sprintf_inverse (mn_lit, sprintf ('lit-%{WSHostName}U:%{WSHostPort}U/sys/mn?user=%%d&role=%%d'), 1);
  if (parts is not null)
    {
      if (exists (select top 1 1 from DB.DBA.SYS_USERS where U_ID = parts[0] and not U_IS_ROLE))
        return parts[1];
    }
  parts := sprintf_inverse (mn_lit, sprintf ('lit-%{WSHostName}U:%{WSHostPort}U/sys/mn?group=%%d&role=%%d'), 1);
  if (parts is not null)
    {
      if (exists (select top 1 1 from DB.DBA.SYS_USERS where U_ID = parts[0] and U_IS_ROLE))
        return parts[1];
    }
  return NULL;
}
;

grant execute on DB.DBA.RDF_DF_MN_LIT_INV_2 to SPARQL_SELECT
;

create function DB.DBA.RDF_DF_GRANTEE_ID_NUM (in id integer)
{
  declare isrole integer;
  isrole := coalesce ((select top 1 U_IS_ROLE from DB.DBA.SYS_USERS where U_ID = id));
  if (isrole is null)
    return NULL;
  else if (isrole)
    return 1000+id;
  else
    return 500+id;
}
;

grant execute on DB.DBA.RDF_DF_GRANTEE_ID_NUM to SPARQL_SELECT
;

create function DB.DBA.RDF_DF_GRANTEE_ID_NUM_INVERSE (in id_num integer)
{
  declare parts any;
  if (not isinteger (id_num))
    return NULL;
  if ((500 <= id_num) and (id_num < 1000))
    {
      if (exists (select top 1 1 from DB.DBA.SYS_USERS where U_ID = id_num-1000 and not U_IS_ROLE))
        return id_num-1000;
    }
  else if ((1000 <= id_num) and (id_num < 2000))
    {
      if (exists (select top 1 1 from DB.DBA.SYS_USERS where U_ID = id_num-500 and U_IS_ROLE))
        return id_num-500;
    }
  return NULL;
}
;

grant execute on DB.DBA.RDF_DF_GRANTEE_ID_NUM_INVERSE to SPARQL_SELECT
;

create function DB.DBA.RDF_DF_MN_NUM (in super integer, in sub integer) returns integer
{
  declare super_is_role integer;
  super_is_role := coalesce ((select top 1 U_IS_ROLE from DB.DBA.SYS_USERS where U_ID = super));
  if (super_is_role is null)
    return NULL;
  else if (super_is_role)
    return 1000+super + 10000 * (1000+sub);
  else
    return 500+super + 10000 * (1000+sub);
}
;

grant execute on DB.DBA.RDF_DF_MN_NUM to SPARQL_SELECT
;

create function DB.DBA.RDF_DF_MN_NUM_INV_1 (in mn_num integer) returns integer
{
  declare super, sub integer;
  if (not isinteger (mn_num))
    return NULL;
  super := mod (mn_num, 10000);
  sub := mn_num / 10000;
  if ((500 <= super) and (super < 1000))
    {
      if (exists (select top 1 1 from DB.DBA.SYS_USERS where U_ID = super-500 and not U_IS_ROLE))
        return super-500;
    }
  else if ((1000 <= super) and (super < 2000))
    {
      if (exists (select top 1 1 from DB.DBA.SYS_USERS where U_ID = super-1000 and not U_IS_ROLE))
        return super-1000;
    }
  return NULL;
}
;

grant execute on DB.DBA.RDF_DF_MN_NUM_INV_1 to SPARQL_SELECT
;

create function DB.DBA.RDF_DF_MN_NUM_INV_2 (in mn_num integer) returns integer
{
  declare super, sub integer;
  if (not isinteger (mn_num))
    return NULL;
  super := mod (mn_num, 10000);
  sub := mn_num / 10000;
  if ((500 <= super) and (super < 1000))
    {
      if (exists (select top 1 1 from DB.DBA.SYS_USERS where U_ID = super-500 and not U_IS_ROLE))
        return sub;
    }
  else if ((1000 <= super) and (super < 2000))
    {
      if (exists (select top 1 1 from DB.DBA.SYS_USERS where U_ID = super-1000 and not U_IS_ROLE))
        return sub;
    }
  return NULL;
}
;

grant execute on DB.DBA.RDF_DF_MN_NUM_INV_2 to SPARQL_SELECT
;

drop quad map graph iri("http://example.com/sys") .
create quad storage virtrdf:sys
  {
  } .
drop quad storage virtrdf:sys .
;

DB.DBA.RDF_QM_END_ALTER_QUAD_STORAGE ( UNAME'http://www.openlinksw.com/schemas/virtrdf#sys' )
;

sparql
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
drop quad map graph iri("http://example.com/sys") .
create iri class oplsioc:user_iri  "http://%{WSHostName}U:%{WSHostPort}U/sys/user?id=%d" (in uid integer not null) .
create iri class oplsioc:user_name_iri  "http://%{WSHostName}U:%{WSHostPort}U/sys/user?name=%U" (in uname varchar not null) .
create iri class oplsioc:group_iri "http://%{WSHostName}U:%{WSHostPort}U/sys/group?id=%d" (in gid integer not null) .
create iri class oplsioc:group_name_iri "http://%{WSHostName}U:%{WSHostPort}U/sys/group?name=%U" (in gname varchar not null) .
create iri class oplsioc:membership_iri "http://%{WSHostName}U:%{WSHostPort}U/sys/membersip?super=%d&sub=%d" (in super integer not null, in sub integer not null) .
create iri class oplsioc:membership_names_iri "http://%{WSHostName}U:%{WSHostPort}U/sys/membersip?supername=%U&subname=%U" (in super varchar not null, in sub varchar not null) .
create iri class oplsioc:dav_iri "http://%{WSHostName}U:%{WSHostPort}U%s" (in path varchar) .
create iri class oplsioc:grantee_iri using
  function DB.DBA.RDF_DF_GRANTEE_ID_URI (in id integer) returns varchar ,
  function DB.DBA.RDF_DF_GRANTEE_ID_URI_INVERSE (in id_iri varchar) returns integer
  option ( bijection ,
    returns	"http://%{WSHostName}U:%{WSHostPort}U/sys/group?id=%d"
    union	"http://%{WSHostName}U:%{WSHostPort}U/sys/user?id=%d" ) .
make oplsioc:user_iri subclass of oplsioc:grantee_iri .
make oplsioc:group_iri subclass of oplsioc:grantee_iri .
create iri class oplsioc:mn_iri using
  function DB.DBA.RDF_DF_MN_URI (in super integer, in sub integer) returns varchar ,
  function DB.DBA.RDF_DF_MN_URI_INV_1 (in mn_iri varchar) returns integer ,
  function DB.DBA.RDF_DF_MN_URI_INV_2 (in mn_iri varchar) returns integer
  option ( bijection ,
    returns	"http://%{WSHostName}U:%{WSHostPort}U/sys/mn?group=%d&role=%d"
    union	"http://%{WSHostName}U:%{WSHostPort}U/sys/mn?user=%d&role=%d" ) .

create literal class oplsioc:grantee_lit using
  function DB.DBA.RDF_DF_GRANTEE_ID_LIT (in id integer) returns varchar ,
  function DB.DBA.RDF_DF_GRANTEE_ID_LIT_INVERSE (in id_iri varchar) returns integer
  option (bijection) .
create literal class oplsioc:grantee_num using
  function DB.DBA.RDF_DF_GRANTEE_ID_NUM (in id integer) returns integer ,
  function DB.DBA.RDF_DF_GRANTEE_ID_NUM_INVERSE (in id_num integer) returns integer
  option (bijection, datatype xsd:integer) .
create literal class oplsioc:mn_lit using
  function DB.DBA.RDF_DF_MN_LIT (in super integer, in sub integer) returns varchar ,
  function DB.DBA.RDF_DF_MN_LIT_INV_1 (in mn_lit varchar) returns integer ,
  function DB.DBA.RDF_DF_MN_LIT_INV_2 (in mn_lit varchar) returns integer
  option (bijection) .
create literal class oplsioc:mn_num using
  function DB.DBA.RDF_DF_MN_NUM (in super integer, in sub integer) returns integer ,
  function DB.DBA.RDF_DF_MN_NUM_INV_1 (in mn_lit integer) returns integer ,
  function DB.DBA.RDF_DF_MN_NUM_INV_2 (in mn_lit integer) returns integer
  option (bijection, datatype xsd:integer) .
;

sparql
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
create quad storage virtrdf:sys
from DB.DBA.SYS_USERS as user where (^{user.}^.U_IS_ROLE = 0)
from DB.DBA.SYS_USERS as group where (^{group.}^.U_IS_ROLE = 1)
from DB.DBA.SYS_USERS as account
from DB.DBA.SYS_USERS as active_user where (^{active_user.}^.U_IS_ROLE = 0) where (^{active_user.}^.U_ACCOUNT_DISABLED = 0)
from DB.DBA.SYS_USERS as active_group where (^{active_group.}^.U_IS_ROLE = 1) where (^{active_group.}^.U_ACCOUNT_DISABLED = 0)
from DB.DBA.SYS_USERS as active_account where (^{active_account.}^.U_ACCOUNT_DISABLED = 0)
from DB.DBA.SYS_ROLE_GRANTS as role_grant
  where (^{role_grant.}^.GI_SUPER = ^{account.}^.U_ID)
  where (^{role_grant.}^.GI_SUB = ^{group.}^.U_ID)
  where (^{role_grant.}^.GI_SUPER = ^{user.}^.U_ID)
  where (^{role_grant.}^.GI_SUPER = ^{active_user.}^.U_ID)
  where (^{role_grant.}^.GI_SUPER = ^{active_group.}^.U_ID)
  where (^{role_grant.}^.GI_SUB = ^{active_group.}^.U_ID)
from DB.DBA.SYS_ROLE_GRANTS as super_role_grant
  where (^{super_role_grant.}^.GI_SUB = ^{role_grant.}^.GI_SUPER)
  {
    create virtrdf:SysUsers as graph iri ("http://example.com/sys") option (exclusive)
      {
        oplsioc:user_iri (active_user.U_ID)
            a oplsioc:active-user
                    as virtrdf:SysUserType-ActiveUser .
        oplsioc:user_iri (user.U_ID)
            a sioc:user
                    as virtrdf:SysUserType-User ;
            sioc:email user.U_E_MAIL
                    as virtrdf:SysUsersEMail-User ;
            sioc:login user.U_NAME
                    as virtrdf:SysUsersName-User ;
            oplsioc:login user.U_NAME
                    as virtrdf:SysUsersName-User1 ;
            oplsioc:home oplsioc:dav_iri (user.U_HOME) where (^{user.}^.U_DAV_ENABLE = 1)
                    as virtrdf:SysUsersHome ;
            oplsioc:name user.U_FULL_NAME where (^{user.}^.U_FULL_NAME is not null)
                    as virtrdf:SysUsersFullName .
        oplsioc:user_name_iri (user.U_NAME)
            oplsioc:subname-of-supername oplsioc:group_name_iri (group.U_NAME) option (using role_grant)
		    as virtrdf:SysUsers-subname-of-supername .
        oplsioc:group_iri (active_group.U_ID)
            a oplsioc:active-role
                    as virtrdf:SysUserType-ActiveRole .
        oplsioc:group_iri (group.U_ID)
            a sioc:role
                    as virtrdf:SysUserType-Role ;
            oplsioc:login group.U_NAME
                    as virtrdf:SysUsersName-Role ;
            oplsioc:name group.U_FULL_NAME where (^{group.}^.U_FULL_NAME is not null)
                    as virtrdf:SysUsersFullName-Role .
        oplsioc:group_iri (role_grant.GI_SUB)
            sioc:has_member oplsioc:grantee_iri (role_grant.GI_SUPER)
                    as virtrdf:SysRoleGrantsHasMember ;
            oplsioc:group_of_membership
                oplsioc:membership_iri (role_grant.GI_SUPER, role_grant.GI_SUB)
                    as virtrdf:SysRoleGrantsGroupOfMembership .
        oplsioc:grantee_iri (role_grant.GI_SUPER)
            sioc:has_function oplsioc:group_iri (role_grant.GI_SUB)
                    as virtrdf:SysRoleGrantsHasFunction ;
            oplsioc:member_of
                oplsioc:membership_iri (role_grant.GI_SUPER, role_grant.GI_SUB)
                    as virtrdf:SysRoleGrantsMemberOfMembership .
        oplsioc:membership_iri (role_grant.GI_SUPER, role_grant.GI_SUB)
            a oplsioc:membership as virtrdf:SysRoleGrantType-Membership;
            oplsioc:is_direct role_grant.GI_DIRECT
                    as virtrdf:SysRoleGrantsMembershipIsDirect ;
            rdf:type oplsioc:grant
                    as virtrdf:SysRoleGrantsTypeMembership .
        oplsioc:membership_iri (super_role_grant.GI_SUPER, role_grant.GI_SUB)
            a oplsioc:submembership as virtrdf:SysRoleGrantType-Submembership.
        oplsioc:mn_iri (role_grant.GI_SUPER, role_grant.GI_SUB)
            a oplsioc:mn as virtrdf:SysRoleGrantType-MN.
        oplsioc:grantee_iri (account.U_ID)
            <grantee-lit> oplsioc:grantee_lit (account.U_ID) as virtrdf:SysUsers-grantee_lit ;
            <grantee-num> oplsioc:grantee_num (account.U_ID) as virtrdf:SysUsers-grantee_num .
        oplsioc:mn_iri (role_grant.GI_SUPER, role_grant.GI_SUB)
            <mn-lit> oplsioc:mn_lit (role_grant.GI_SUPER, role_grant.GI_SUB) as virtrdf:SysRoleGrants-mn_lit ;
            <mn-num> oplsioc:mn_num (role_grant.GI_SUPER, role_grant.GI_SUB) as virtrdf:SysRoleGrants-mn_num .
      }
  }
;

sparql define input:storage virtrdf:sys select ?s ?p ?o (isliteral(?o)) as ?o_is_lit
from <http://example.com/sys>
where {
  ?s ?p ?o ; ?p2 "dba" }
order by ?s ?p ?o
;

grant select on SYS_USERS to "SPARQL";
grant select on DB.DBA.SYS_ROLE_GRANTS to "SPARQL";
