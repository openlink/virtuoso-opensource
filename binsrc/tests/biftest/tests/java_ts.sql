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

USE JAVATS;

drop type testsuite;
drop type testsuite_ns;
drop type testsuite_base;
drop table testsuite;

create type testsuite_base language java external name 'testsuite_base'
as (
    protected_I integer external name 'protected_I' external type 'I',
    private_I integer external name 'private_I' external type 'I',
    sZ smallint external name 'Z' external type 'Z',
    sfalseZ smallint external name 'falseZ' external type 'Z',
    sB smallint external name 'B' external type 'B',
    sC smallint external name 'C' external type 'C',
    sS smallint external name 'S' external type 'S',
    sI int external name 'I' external type 'I',
    sJ int external name 'J' external type 'J',
    sF real external name 'F' external type 'F',
    sD double precision external name 'D' external type 'D',
    sL any external name 'L' external type 'Ljava/lang/Short;',
    sAI any external name 'AI' external type '[I',
    sAL any external name 'AL' external type '[Ljava/lang/Short;',
    sstr nvarchar external name 'str' external type 'Ljava/lang/String;',
    sdat datetime external name 'dat' external type 'Ljava/util/Date;',

    tF real external name 'F',
    "F" real,

    non_existant_var integer external name 'non_existant_var' external type 'I'
   )
--unrestricted

static method get_static_ro_I ()
    returns integer external type 'I' external variable name 'static_ro_I',
static method get_static_I ()
    returns integer external type 'I' external variable name 'static_I',
static method get_protected_static_I ()
    returns integer external type 'I' external variable name 'protected_static_I',
static method get_private_static_I ()
    returns integer external type 'I' external variable name 'private_static_I',

static method test_bool (x integer external type 'I')
    returns smallint external type 'Z' external name 'test_bool',

constructor method testsuite_base (),
constructor method testsuite_base (i integer external type 'I'),

static method echoDouble (a double precision external type 'D')
    returns any external type 'Ljava/lang/Double;' external name 'echoDouble',
static method getObjectType (a any external type 'Ljava/lang/Object;')
    returns varchar external type 'Ljava/lang/String;' external name 'getObjectType',
static method echoThis (a testsuite_base external type 'Ltestsuite_base;')
    returns integer external type 'I' external name 'echoThis',
static method static_echoInt (a integer external type 'I')
    returns integer external type 'I' external name 'static_echoInt',

static method change_it (a testsuite_base)
    returns integer external type 'I' external name 'change_it',

method "overload_method" (i integer external type 'I')
    returns integer external type 'I',

method echoInt (a integer external type 'I')
    returns integer external type 'I' external name 'echoInt',

method echoInt (a double precision external type 'D')
    returns integer external type 'I' external name 'echoInt',

method protected_echo_int (a integer external type 'I')
    returns integer external type 'I' external name 'protected_echo_int',

method private_echo_int (a integer external type 'I')
    returns integer external type 'I' external name 'private_echo_int',

method "echoDbl" (a double precision)
    returns double precision,

method non_existant_method (a integer external type 'I')
    returns integer external type 'I' external name 'non_existant_method',

static method non_existant_static_var (a integer external type 'I')
    returns integer external type 'I' external variable name 'non_existant_static_var';

create type testsuite under testsuite_base language java external name 'testsuite'
as
  (ts_fld int external name 'ts_fld' external type 'I')
--temporary

  overriding method "overload_method" (i integer external type 'I') returns integer;

create type testsuite_ns language java external name 'testsuite_ns'
as
  (ts_fld int external name 'ts_fld' external type 'I')
--temporary

    method "overload_method" (i integer external type 'I')
	returns integer external type 'I';

create table testsuite (id int primary key, b_data testsuite_base, ns_data testsuite_ns, ts_data testsuite, a_data any);
