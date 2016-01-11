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
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('text/xml','wsdl');
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('text/xml','bpel') ;
select http_mime_type_add (T_EXT, T_TYPE)  from WS.WS.SYS_DAV_RES_TYPES where T_EXT in ('bpel','wsdl') ;

DB.DBA.USER_CREATE ('BPWSI', uuid(), vector ('DISABLED', 1));
EXEC ('grant all privileges to BPWSI');
user_set_qualifier ('BPWSI', 'BPWSI');

-- drop tables
drop table BPWSI..products;
drop table BPWSI..tests;
drop table BPWSI..test_source;
drop table BPWSI..test_link;

-- create tables statements

-- Products
create table BPWSI..products
	(
	 pr_id int identity,
         pr_name varchar, -- name
         pr_version varchar, -- version
         pr_platf varchar default '', -- platform
         pr_manifactor varchar, -- organization
	 primary key (pr_name,pr_version)
)
;
insert into BPWSI..products (pr_name, pr_version, pr_manifactor) values ('Virtuoso', '3.5', 'OpenLink');

-- Tests
create table BPWSI..tests
	(
         tt_id int identity,
         tt_name varchar,
         tt_info varchar,
	 primary key (tt_name)
)
;

--delete from BPWSI..tests;
insert into BPWSI..tests (tt_name, tt_info) values ('Echo', 'Echo test');
insert into BPWSI..tests (tt_name, tt_info) values ('AEcho', 'AEcho test');
insert into BPWSI..tests (tt_name, tt_info) values ('Echo using WS-Security', 'Echo using WS-Security test');
insert into BPWSI..tests (tt_name, tt_info) values ('Echo using WS-RM', 'Echo using WS-RM test');
insert into BPWSI..tests (tt_name, tt_info) values ('LoanFlow Using WS-Security', 'LoanFlow Using WS-Security test');
insert into BPWSI..tests (tt_name, tt_info) values ('LoanFlow Using WS-RM', 'LoanFlow Using WS-RM test');
insert into BPWSI..tests (tt_name, tt_info) values ('LoanFlow Using WS-Security and WS-RM', 'LoanFlow Using WS-Security and WS-RM test');
--insert into BPWSI..tests (tt_name, tt_info) values ('TPCC', 'TPCC test');



-- Test sources
create table BPWSI..test_source
	(
         ts_id int identity,
         ts_text varchar default null, -- short description
	 ts_test_id int, --  fk to tt_id of tests table.
	 primary key (ts_id)
)
;

create table BPWSI..test_queue
	(
	 tq_id int identity primary key,
	 tq_ts timestamp,
	 tq_msg long varchar,
	 tq_test int,
	 tq_ip varchar
	 );

insert soft DB.DBA.SYS_SCHEDULED_EVENT (SE_INTERVAL, SE_LAST_COMPLETED, SE_NAME, SE_SQL, SE_START)
    values (10, NULL, 'BPEL_INTEROP_TEST_QUEUE_CLEAN',
		'delete from BPWSI..test_queue where dateadd (\'minute\', 30, tq_ts) < now ()',
	    	now());

--delete from BPWSI..test_source;
-- Echo
insert into BPWSI..test_source (ts_text, ts_test_id) values ('Echo bpel file', 1);
insert into BPWSI..test_source (ts_text, ts_test_id) values ('Echo wsdl file', 1);
-- AEcho
insert into BPWSI..test_source (ts_text, ts_test_id) values ('AEcho bpel file', 2);
insert into BPWSI..test_source (ts_text, ts_test_id) values ('AEcho wsdl file', 2);
-- Echo WS-Security
insert into BPWSI..test_source (ts_text, ts_test_id) values ('Echo using WS-Security bpel file', 3);
insert into BPWSI..test_source (ts_text, ts_test_id) values ('Echo using WS-Security wsdl file', 3);
-- Echo WS-RM
insert into BPWSI..test_source (ts_text, ts_test_id) values ('Echo using WS-RM bpel file', 4);
insert into BPWSI..test_source (ts_text, ts_test_id) values ('Echo using WS-RM wsdl file', 4);

-- LoanFlow WS-Security
insert into BPWSI..test_source (ts_text, ts_test_id) values ('LoanFlow using WS-Security bpel file', 5);
insert into BPWSI..test_source (ts_text, ts_test_id) values ('LoanFlow using WS-Security wsdl file', 5);
insert into BPWSI..test_source (ts_text, ts_test_id) values ('CreaditRating wsdl file', 5);
insert into BPWSI..test_source (ts_text, ts_test_id) values ('UnitedLoan wsdl file', 5);
insert into BPWSI..test_source (ts_text, ts_test_id) values ('StarLoan wsdl file', 5);
-- LoanFlow WS-RM
insert into BPWSI..test_source (ts_text, ts_test_id) values ('LoanFlow using WS-RM bpel file', 6);
insert into BPWSI..test_source (ts_text, ts_test_id) values ('LoanFlow using WS-RM wsdl file', 6);
insert into BPWSI..test_source (ts_text, ts_test_id) values ('CreaditRating wsdl file', 6);
insert into BPWSI..test_source (ts_text, ts_test_id) values ('UnitedLoan wsdl file', 6);
insert into BPWSI..test_source (ts_text, ts_test_id) values ('StarLoan wsdl file', 6);
-- LoanFlow WS-Security and WS-RM
insert into BPWSI..test_source (ts_text, ts_test_id) values ('LoanFlow using WS-Security and WS-RM bpel file', 7);
insert into BPWSI..test_source (ts_text, ts_test_id) values ('LoanFlow using WS-Security and WS-RM wsdl file', 7);
insert into BPWSI..test_source (ts_text, ts_test_id) values ('CreaditRating wsdl file', 7);
insert into BPWSI..test_source (ts_text, ts_test_id) values ('UnitedLoan wsdl file', 7);
insert into BPWSI..test_source (ts_text, ts_test_id) values ('StarLoan wsdl file', 7);
-- TPCC
--insert into BPWSI..test_source (ts_text, ts_test_id) values ('TPCC bpel file', 8);
--insert into BPWSI..test_source (ts_text, ts_test_id) values ('TPCC wsdl file', 8);
--insert into BPWSI..test_source (ts_text, ts_test_id) values ('DBDRiver wsdl file', 8);
--insert into BPWSI..test_source (ts_text, ts_test_id) values ('TestDriver wsdl file', 8);


-- Urls
create table BPWSI..test_link
	(
         tl_pr_id int, --  fk to pr_id of product table.
	 tl_tt_id int, --  fk to tt_id of tests table.
         tl_ts_id int, --  fk to ts_id of test_source table
         tl_url varchar default null,
	 primary key (tl_pr_id,tl_tt_id,tl_ts_id)
)
;

--delete from BPWSI..test_link;
-- Echo
insert into BPWSI..test_link (tl_pr_id, tl_tt_id, tl_ts_id, tl_url) values (1, 1, 1, '/echo/echo.bpel');
insert into BPWSI..test_link (tl_pr_id, tl_tt_id, tl_ts_id, tl_url) values (1, 1, 2, '/echo/echo.wsdl');
-- AEcho
insert into BPWSI..test_link (tl_pr_id, tl_tt_id, tl_ts_id, tl_url) values (1, 2, 3, '/Aecho/echo.bpel');
insert into BPWSI..test_link (tl_pr_id, tl_tt_id, tl_ts_id, tl_url) values (1, 2, 4, '/Aecho/echo.wsdl');
-- Echo WS-Security
insert into BPWSI..test_link (tl_pr_id, tl_tt_id, tl_ts_id, tl_url) values (1, 3, 5, '/SecAecho/echo.bpel');
insert into BPWSI..test_link (tl_pr_id, tl_tt_id, tl_ts_id, tl_url) values (1, 3, 6, '/SecAecho/echo.wsdl');
-- Echo WS-RM
insert into BPWSI..test_link (tl_pr_id, tl_tt_id, tl_ts_id, tl_url) values (1, 4, 7, '/RMecho/echo.bpel');
insert into BPWSI..test_link (tl_pr_id, tl_tt_id, tl_ts_id, tl_url) values (1, 4, 8, '/RMecho/echo.wsdl');

-- LoanFlow WS-Security
insert into BPWSI..test_link (tl_pr_id, tl_tt_id, tl_ts_id, tl_url) values (1, 5, 9, '/SecLoanFlowSrc/LoanFlow.bpel');
insert into BPWSI..test_link (tl_pr_id, tl_tt_id, tl_ts_id, tl_url) values (1, 5, 10, '/SecLoanFlowSrc/LoanFlow.wsdl');
insert into BPWSI..test_link (tl_pr_id, tl_tt_id, tl_ts_id, tl_url) values (1, 5, 11, '/SecLoanFlowSrc/CreditRating.vsp');
insert into BPWSI..test_link (tl_pr_id, tl_tt_id, tl_ts_id, tl_url) values (1, 5, 12, '/SecLoanFlowSrc/UnitedLoan.vsp');
insert into BPWSI..test_link (tl_pr_id, tl_tt_id, tl_ts_id, tl_url) values (1, 5, 13, '/SecLoanFlowSrc/StarLoan.vsp');
-- LoanFlow WS-RM
insert into BPWSI..test_link (tl_pr_id, tl_tt_id, tl_ts_id, tl_url) values (1, 6, 14, '/RMLoanFlowSrc/LoanFlow.bpel');
insert into BPWSI..test_link (tl_pr_id, tl_tt_id, tl_ts_id, tl_url) values (1, 6, 15, '/RMLoanFlowSrc/LoanFlow.wsdl');
insert into BPWSI..test_link (tl_pr_id, tl_tt_id, tl_ts_id, tl_url) values (1, 6, 16, '/RMLoanFlowSrc/CreditRating.vsp');
insert into BPWSI..test_link (tl_pr_id, tl_tt_id, tl_ts_id, tl_url) values (1, 6, 17, '/RMLoanFlowSrc/UnitedLoan.vsp');
insert into BPWSI..test_link (tl_pr_id, tl_tt_id, tl_ts_id, tl_url) values (1, 6, 18, '/RMLoanFlowSrc/StarLoan.vsp');
-- LoanFlow WS-Security and WS-RM
insert into BPWSI..test_link (tl_pr_id, tl_tt_id, tl_ts_id, tl_url) values (1, 7, 19, '/SecRMLoanFlowSrc/LoanFlow.bpel');
insert into BPWSI..test_link (tl_pr_id, tl_tt_id, tl_ts_id, tl_url) values (1, 7, 20, '/SecRMLoanFlowSrc/LoanFlow.wsdl');
insert into BPWSI..test_link (tl_pr_id, tl_tt_id, tl_ts_id, tl_url) values (1, 7, 21, '/SecRMLoanFlowSrc/CreditRating.vsp');
insert into BPWSI..test_link (tl_pr_id, tl_tt_id, tl_ts_id, tl_url) values (1, 7, 22, '/SecRMLoanFlowSrc/UnitedLoan.vsp');
insert into BPWSI..test_link (tl_pr_id, tl_tt_id, tl_ts_id, tl_url) values (1, 7, 23, '/SecRMLoanFlowSrc/StarLoan.vsp');
-- TPCC
--insert into BPWSI..test_link (tl_pr_id, tl_tt_id, tl_ts_id, tl_url) values (1, 8, 24, 'To be changed: TPCC bpel url');
--insert into BPWSI..test_link (tl_pr_id, tl_tt_id, tl_ts_id, tl_url) values (1, 8, 25, 'To be changed: TPCC wsdl url');
--insert into BPWSI..test_link (tl_pr_id, tl_tt_id, tl_ts_id, tl_url) values (1, 8, 26, 'To be changed: DBDRiver wsdl url');
--insert into BPWSI..test_link (tl_pr_id, tl_tt_id, tl_ts_id, tl_url) values (1, 8, 27, 'To be changed: TestDriver wsdl url');
