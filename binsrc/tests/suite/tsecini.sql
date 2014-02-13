--
--  tsecini.sql
--
--  $Id$
--
--  Test security - initialization
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

SET ARGV[0] 0;
SET ARGV[1] 0;

drop table SEC_TEST_1;
drop table SEC_TEST_2;
drop table SEC_TEST_3;
drop table SEC_TEST_4;
drop table SET_T1;
drop table U1.U1_T1;
drop table U1.U1_T2;
drop table T2;


create table SEC_TEST_1  (a integer, b integer, c integer, primary key (a));
create table SEC_TEST_2  (a integer, b integer, c integer, primary key (a));
create table SEC_TEST_3  (a integer, b integer, c integer, primary key (a));
create table SEC_TEST_4  (a integer, b integer, c integer, primary key (a));
create table T2 (A integer, B integer, primary key (A));

insert into T2 (A, B) values (1,1);
insert into T2 (A, B) values (2,1);
insert into T2 (A, B) values (3,1);
insert into T2 (A, B) values (4,1);
insert into T2 (A, B) values (5,1);
insert into T2 (A, B) values (6,1);
insert into T2 (A, B) values (7,1);
insert into T2 (A, B) values (8,1);
insert into T2 (A, B) values (9,1);
insert into T2 (A, B) values (10,1);
insert into T2 (A, B) values (11,1);
insert into T2 (A, B) values (12,1);
insert into T2 (A, B) values (13,1);
--
-- Check that all tables were created above and that SQLTables returns
-- them sorted in alphabetical order:
--

TABLES SEC_TEST_%/TABLE;

ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": TABLES SEC_TEST_%/TABLE; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH $IF $EQU $ROWCNT 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " tables with name like 'SEC_TEST_%' in SYS_KEYS after all test tables have been created; \n";

ECHO BOTH $IF $EQU $LAST[3] "SEC_TEST_4" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": of which " $ROWCNT "th one is " $LAST[3] "\n";


insert into SEC_TEST_1 values (1, 2, 3);
insert into SEC_TEST_2 values (11, 22, 33);
insert into SEC_TEST_3 values (121, 242, 363);
insert into SEC_TEST_4 values (1331, 2662, 3993);

delete user U1;
delete user U1RUS;
delete user U2;
delete user U3;
delete user U4;
delete user U5;

--
-- First check that there is only one user named 'U1' after this command:
--

create user U1;
select U_ID, U_GROUP from SYS_USERS where U_NAME = 'U1';
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " user(s) named 'U1' after CREATE USER U1;\n";

--
-- Then check that the user-id and group-id are initially equal:
--

ECHO BOTH $IF $EQU $LAST[1] $LAST[2] "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": U_ID (" $LAST[1] ") " $IF $LIF "==" "!=" " U_GROUP (" $LAST[2] ")\n";

--
-- Now a user named 'U1RUS' is created for tests of "national" passwords:
--

create user U1RUS;
select U_ID, U_GROUP from SYS_USERS where U_NAME = 'U1RUS';
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " user(s) named 'U1RUS' after CREATE USER U1RUS;\n";
user_set_password ('U1RUS', charset_recode ('Абракадабра1', 'UTF-8', '_WIDE_'));
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": User U1RUS got wide password via user_set_password; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
DB.DBA.USER_CHANGE_PASSWORD ('U1RUS', charset_recode ('Абракадабра1', 'UTF-8', '_WIDE_'), charset_recode ('Абракадабра2', 'UTF-8', '_WIDE_'));
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": User U1RUS got changed wide password via DB.DBA.USER_CHANGE_PASSWORD; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--
-- First check that there is only one user named 'U2' after this command:
--

create user U2;
select U_NAME, pwd_magic_calc (U_NAME, U_PASSWORD, 1) from SYS_USERS where U_NAME = 'U2';
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " user(s) named 'U2' after CREATE USER U2;\n";

--
-- Then check that the username and password are initially equal
-- (This might change in later implementations):
--
ECHO BOTH $IF $EQU $LAST[1] $LAST[2] "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": U_NAME (" $LAST[1] ") " $IF $LIF "==" "!=" " U_PASSWORD (" $LAST[2] ")\n";

create user U3;
-- Just check that there was one user created:
select U_GROUP from SYS_USERS where U_NAME = 'U3';
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " user(s) named 'U3' after CREATE USER U3;\n";

create user U4;
-- Just check that there was one user created:
select U_GROUP from SYS_USERS where U_NAME = 'U4';
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " user(s) named 'U4' after CREATE USER U4;\n";

create user U5;
-- Current Implementation of GRANT ALL PRIVILEGES TO ux is exactly same
-- as SET USER GROUP ux dba;
--
grant all privileges to U5;
select U_GROUP from SYS_USERS where U_NAME = 'U5';
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " user(s) named 'U5' after CREATE USER U5;\n";

ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": User Group of U5=" $LAST[1] " after GRANT ALL PRIVILEGES TO U5;\n";

grant select on SEC_TEST_1 to public;
TABLEPRIVILEGES SEC_TEST_1;
ECHO BOTH $IF $EQU $ROWCNT 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " grants on SEC_TEST_1 after GRANT SELECT ON SEC_TEST_1 TO public;\n";

ECHO BOTH $IF $EQU $LAST[3] "SEC_TEST_1" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Granted on table " $LAST[3] "\n";

ECHO BOTH $IF $EQU $LAST[5] "public" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Granted to " $LAST[5] "\n";

ECHO BOTH $IF $EQU $LAST[6] "SELECT" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Privilege granted is " $LAST[6] "\n";

grant select (a) on SEC_TEST_2 to U1, U2;
TABLEPRIVILEGES SEC_TEST_2;
ECHO BOTH $IF $EQU $ROWCNT 8 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " grants on SEC_TEST_2 after GRANT SELECT ON SEC_TEST_2 TO U1, U2;\n";

ECHO BOTH $IF $EQU $LAST[3] "SEC_TEST_2" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Granted on table " $LAST[3] "\n";

--
-- Note how $+ works like OR here, as either of the $EQU -clauses have
-- to be non-zero that their sum were non-zero as well:
--
ECHO BOTH $IF $+ $EQU $LAST[5] "U1" $EQU $LAST[5] "U2" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Granted to " $LAST[5] "\n";

ECHO BOTH $IF $EQU $LAST[6] "SELECT" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Privilege granted is " $LAST[6] "\n";

--
-- Same with SQLColumnPrivileges:
--

COLUMNPRIVILEGES SEC_TEST_2;
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " column grants on SEC_TEST_2 after GRANT SELECT ON SEC_TEST_2 TO U1, U2;\n";

ECHO BOTH $IF $EQU $LAST[3] "SEC_TEST_2" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Granted on table " $LAST[3] "\n";

ECHO BOTH $IF $EQU $LAST[4] "A" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Granted on column " $LAST[4] "\n";

--
-- Note how $+ works like OR here, as either of the $EQU -clauses have
-- to be non-zero that their sum were non-zero as well:
--
ECHO BOTH $IF $+ $EQU $LAST[6] "U1" $EQU $LAST[6] "U2" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Granted to " $LAST[6] "\n";

ECHO BOTH $IF $EQU $LAST[7] "SELECT" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Privilege granted is " $LAST[7] "\n";

grant update (b, c) on SEC_TEST_3 to U1, U3, U4;

-- O, this is tedious, but nevertheless, we do it all:
TABLEPRIVILEGES SEC_TEST_3;
ECHO BOTH $IF $EQU $ROWCNT 12 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " grants on SEC_TEST_3 after GRANT UPDATE (b, c) ON SEC_TEST_3 TO U1, U3, U4;\n";

ECHO BOTH $IF $EQU $LAST[3] "SEC_TEST_3" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Granted on table " $LAST[3] "\n";

--
-- Note how $+ macros work like logical OR shere, as one of the
-- $EQU -clauses have to be non-zero that their sum were non-zero as well:
--
ECHO BOTH $IF $+ $+ $EQU $LAST[5] "U1" $EQU $LAST[5] "U3" $EQU $LAST[5] "U4" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Granted to " $LAST[5] "\n";

ECHO BOTH $IF $EQU $LAST[6] "SELECT" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Privilege granted is " $LAST[6] "\n";

--
-- Same with SQLColumnPrivileges:
--
COLUMNPRIVILEGES SEC_TEST_3;
ECHO BOTH $IF $EQU $ROWCNT 6 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " column grants on SEC_TEST_3 after GRANT UPDATE (b, c) ON SEC_TEST_3 TO U1, U3, U4;\n";

ECHO BOTH $IF $EQU $LAST[3] "SEC_TEST_3" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Granted on table " $LAST[3] "\n";

--
-- Has to be column c, not b, as result set is (i.e. should be) sorted by
-- TABLE_QUALIFIER, TABLE_OWNER, TABLE_NAME, COLUMN_NAME and PRIVILEGE
-- Actually, there is no ORDER BY in the select producing this in
-- internal procedure column_privileges, but the primary key of
-- SYS_GRANTS is composed of columns G_USER, G_OP, G_OBJECT and G_COL
-- in that order, so at least column names should be sorted correctly.
--

ECHO BOTH $IF $EQU $LAST[4] "C" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Granted on column " $LAST[4] "\n";

--
-- Note how $+ macros work like logical OR shere, as one of the
-- $EQU -clauses have to be non-zero that their sum were non-zero as well:
--
ECHO BOTH $IF $+ $+ $EQU $LAST[6] "U1" $EQU $LAST[6] "U3" $EQU $LAST[6] "U4" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Granted to " $LAST[6] "\n";

ECHO BOTH $IF $EQU $LAST[7] "UPDATE" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Privilege granted is " $LAST[7] "\n";

grant insert on SEC_TEST_4 to U1;
TABLEPRIVILEGES SEC_TEST_4;
ECHO BOTH $IF $EQU $ROWCNT 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " grants on SEC_TEST_4 after GRANT INSERT ON SEC_TEST_4 TO U1\n";

ECHO BOTH $IF $EQU $LAST[3] "SEC_TEST_4" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Granted on table " $LAST[3] "\n";

ECHO BOTH $IF $EQU $LAST[5] "U1" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Granted to " $LAST[5] "\n";

ECHO BOTH $IF $EQU $LAST[6] "SELECT" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Privilege granted is " $LAST[6] "\n";

ECHO BOTH $IF $EQU $LAST[7] "YES" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Privilege SELECT granted is " $LAST[6] "\n";

grant delete on SEC_TEST_4 to U1, U2;
TABLEPRIVILEGES SEC_TEST_4;
ECHO BOTH $IF $EQU $ROWCNT 8 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " grants on SEC_TEST_4 after GRANT DELETE ON SEC_TEST_4 TO U1, U2\n";

ECHO BOTH $IF $EQU $LAST[3] "SEC_TEST_4" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Granted on table " $LAST[3] "\n";

--
-- Note how $+ macro works like a logical OR shere, as either one of the
-- $EQU -clauses have to be non-zero that their sum were non-zero as well:
--
ECHO BOTH $IF $+ $EQU $LAST[5] "U1" $EQU $LAST[5] "U2" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Granted to " $LAST[5] "\n";

ECHO BOTH $IF $+ $EQU $LAST[6] "SELECT" $EQU $LAST[6] "DELETE" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Privilege granted is " $LAST[6] "\n";

--
-- Should produce: *** Error 42000: Incorrect old password in set password
--
set password "badpass" "dbapass";
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Changing dba's password with incorrect old password: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure secp_1 (in q integer) { return (11*q); };
create procedure secp_2 (in q integer) { return (22*q); };
grant execute on secp_1 to public;
grant execute on secp_2 to U1;

PROCEDURES SECP_%;
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " procedures with name like 'secp_%' found after two CREATE PROCEDURE statements\n";

ECHO BOTH $IF $EQU $LAST[2] "DBA" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Owner of the procedures: " $LAST[2] "\n";

--
-- The PROCEDURE_NAME in the last row has to be secp_2 because
-- SQLProcedures sorts its result rows in order of
-- Procedure Qualifier, Owner and Name
--
ECHO BOTH $IF $EQU $LAST[3] "SECP_2" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Name of the second procedure: " $LAST[3] "\n";


ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: " $ARGV[4] "  -- Initialization\n";


create view SEC_T1 as select * from T1;
grant select on SEC_T1 to U1;
delete from T1 where ROW_NO >= 120 or ROW_NO < 100;

grant select, insert, update (A, B), delete on T2 to U1;


create procedure pdba1 (in q integer){return q;};
create procedure pdba2 (in q integer){return pdba1 (q);};
grant execute on pdba2 to U1;

create user O;
create user R;
user_set_password ('R', 'W');

create user PI;
create user BI;
user_set_password ('BI', 'DO');

create user UFO;
create user MAN;
user_set_password ('MAN', 'LEN');

create user ZORO;
create user ZIPO;
user_set_password ('ZIPO', 'LIGHT');

create user ZAFIR;
create user TUNAR;
user_set_password ('TUNAR', 'SONAR');

create user ZUMOSO;
create user ZURANA;
user_set_password ('ZURANA', 'VINOTE');

create user ABALLAR;
create user ACHICAR;
user_set_password ('ACHICAR', 'ANIMOSO');

create user SCCTRIAL;
create user ACERILLO;
user_set_password ('ACERILLO', 'AMARIZAR');

create user ABATIDERO;
create user AMELONADA;
user_set_password ('AMELONADA', 'AMESNADOR');

create user ANTORCHERO;
create user ABANDERADO;
user_set_password ('ABANDERADO', 'ABALUARTAR');

create user BARBIRRUCIO;
create user BARBIBLANCA;
user_set_password ('BARBIBLANCA', 'ABAJAMIENTO');

create user ACABDILLADOR;
create user VIVIFICATIVO;
user_set_password ('VIVIFICATIVO', 'ZOROASTRISMO');

create user VICEALMIRANTE;
create user TRANSFORMANTE;
user_set_password ('TRANSFORMANTE', 'SIGNIFICATIVO');

create user ZARZAPARRILLAR;
create user SOBREALIMENTAR;
user_set_password ('SOBREALIMENTAR', 'RAQUIANESTESIA');

create user VICTORIOSAMENTE;
create user TRANSUBSTANCIAR;
user_set_password ('TRANSUBSTANCIAR', 'SONAR');

create user RESTRICTIVAMENTE;
create user PERCEPTIBLEMENTE;
user_set_password ('PERCEPTIBLEMENTE', 'PLENIPOTENCIARIA');

create user FIBROCARTILAGINOSO;
create user DESVERGONZADAMENTE;
user_set_password ('DESVERGONZADAMENTE', 'ABANDERADO');

create user CIRCUNFERENCIALMENTE;
create user DESENVERGONZADAMENTE;
user_set_password ('DESENVERGONZADAMENTE', 'REGLAMENTARIAMENTE');

create user BIENINTENCIONADAMENTE;
create user DESPROPORCIONADAMENTE;
user_set_password ('DESPROPORCIONADAMENTE', 'REGLAMENTARIAMENTE');

create user BIENINTENCIONADAMENTE;
create user DESPROPORCIONADAMENTE;
user_set_password ('DESPROPORCIONADAMENTE', 'REGLAMENTARIAMENTE');
