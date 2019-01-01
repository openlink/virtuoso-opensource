--
--  $Id: testtext.sql,v 1.14.6.2.4.1 2013/01/02 16:15:07 source Exp $
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2019 OpenLink Software
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
set U{pk} = $IF $EQU $U{haspk} "yes" "primary key" " ";
set U{datafield} = $IF $EQU $U{testupper} "yes" "data" "DATA";
set U{keyfield} = $IF $NEQ $U{idtype} "integer" "null" $IF $EQU $U{haspk} "yes" "'ID'" "null";

ECHO BOTH "STARTED: freetext tests for table " $U{table} " ID type " $U{idtype} " primary key : " $U{haspk} "\n";

drop table $U{table};

create table $U{table} (ID $U{idtype} not null $U{pk}, DATA long varchar)
alter index $U{table} on $U{table} partition (ID $U{idtype});
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": creating freetext table " $U{table} " with ID type " $U{idtype} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

vt_create_text_index ('$U{table}', '$U{datafield}', null, 0, 0, null, null, null);
vt_batch_update ('$U{table}', 'ON', NULL);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": vt_create_text_index (null key_id) on table " $U{table} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

set U{brace} = $IF $EQU $U{idtype} "varchar" "\'" " ";

INSERT INTO $U{table} (ID, DATA) values ($U{brace}1$U{brace}, 'Education includes a BA in psychology from Colorado State University in 1970.  She also completed "The Art of the Cold Call."  Nancy is a member of Toastmasters International.');

INSERT INTO $U{table} (ID, DATA) VALUES($U{brace}2$U{brace}, 'Andrew received his BTS commercial in 1974 and a Ph.D. in international marketing from the University of Dallas in 1981.  He is fluent in French and Italian and reads German.  He joined the company as a sales representative, was promoted to sales manager in January 1992 and to vice president of sales in March 1993.  An drew is a member of the Sales Management Roundtable, the Seattle Chamber of Commerce, and the Pacific Rim Importers Association.');

INSERT INTO $U{table} (ID, DATA) VALUES($U{brace}3$U{brace},'Janet has a BS degree in chemistry from Boston College (1984).  She has also completed a certificate program in food retailing management.  Janet was hired as a sales associate in 1991 and promoted to sales representative in February 1992.');

INSERT INTO $U{table} (ID, DATA) VALUES($U{brace}4$U{brace},'Margaret holds a BA in English literature from Concordia College (1958) and an MA from the American Institute of Culinary Arts (1966).  She was assigned to the London office temporarily from July through November 1992.');

INSERT INTO $U{table} (ID, DATA) VALUES($U{brace}5$U{brace},'Steven Buchanan graduated from St. Andrews University, Scotland, with a BSC degree in 1976.  Upon joining the company as a sales representative in 1992, he spent 6 months in an orientation program at the Seattle office and then returned to his permanent post in London.  He was promoted to sales manager in March 1993.  Mr. Buchanan has completed the courses "Successful Telemarketing" and "International Sales Management."  He is fluent in French.');

INSERT INTO $U{table} (ID, DATA) VALUES($U{brace}6$U{brace},'Michael is a graduate of Sussex University (MA, economics, 1983) and the University of California at Los Angeles (MBA, marketing, 1986).  He has also taken the courses "Multi-Cultural Selling" and "Time Management for the Sales Professional."  He is fluent in Japanese and can read and write French, Portuguese, and Spanish.');

INSERT INTO $U{table} (ID, DATA) VALUES($U{brace}7$U{brace},'Robert King served in the Peace Corps and traveled extensively before completing his degree in English at the University of Michigan in 1992, the year he joined the company.  After completing a course entitled "Selling in Europe," he was transferred to the London office in March 1993.');

INSERT INTO $U{table} (ID, DATA) VALUES($U{brace}8$U{brace},'Laura received a BA in psychology from the University of Washington.  She has also completed a course in business French.  She reads and writes French.');

INSERT INTO $U{table} (ID, DATA) VALUES($U{brace}9$U{brace},'Anne has a BA degree in English from St. Lawrence College.  She is fluent in French and German.');

select ID, DATA from $U{table};
ECHO BOTH $IF $EQU $ROWCNT 9 "PASSED" "*** FAILED";
ECHO BOTH ": " $ROWCNT " rows inserted into " $U{table} "\n";

select DMLTYPE, VT_GZ_WORDUMP from VTLOG_DB_DBA_$U{table} where DMLTYPE = 'I' and VT_GZ_WORDUMP is null;
ECHO BOTH $IF $EQU $ROWCNT 9 "PASSED" "*** FAILED";
ECHO BOTH ": freetext update log VTLOG_DB_DBA_" $U{table} " populated correctly\n";

vt_inc_index_DB_DBA_$U{table} ();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": incrementally re-indexing table " $U{table} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DMLTYPE, VT_GZ_WORDUMP from VTLOG_DB_DBA_$U{table};
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "*** FAILED";
ECHO BOTH ": freetext update log VTLOG_DB_DBA_" $U{table} " empty\n";

select distinct VT_WORD from $U{table}_DATA_WORDS;
ECHO BOTH $IF $EQU $ROWCNT 171 "PASSED" "*** FAILED";
ECHO BOTH ": " $ROWCNT " rows in " $U{table} "_DATA_WORDS table\n";

select distinct VT_WORD from $U{table}_DATA_WORDS where length(VT_WORD) > 1;
ECHO BOTH $IF $EQU $ROWCNT 169 "PASSED" "*** FAILED";
ECHO BOTH ": " $ROWCNT " words that are longer than 1 char in " $U{table} "_DATA_WORDS table\n";

select ID from $U{table} where contains (DATA, 'international');
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "*** FAILED";
ECHO BOTH ": " $ROWCNT " rows containing international\n";
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "*** FAILED";
ECHO BOTH ": ID=" $LAST[1] " is last row containing international\n";

vt_index_DB_DBA_$U{table} (1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": clearing the fulltext index of " $U{table} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select ID from $U{table} where contains (DATA, 'international');
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "*** FAILED";
ECHO BOTH ": " $ROWCNT " rows containing international\n";

vt_index_DB_DBA_$U{table} (0);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": non-incremental reindexing of " $U{table} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select ID from $U{table} where contains (DATA, 'international');
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "*** FAILED";
ECHO BOTH ": " $ROWCNT " rows containing international\n";
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "*** FAILED";
ECHO BOTH ": ID=" $LAST[1] " is last row containing international\n";

delete from $U{table} where ID = $U{brace}1$U{brace};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": deleting row 1 from " $U{table} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into $U{table} (ID, DATA) values ($U{brace}1$U{brace}, 'abracadabra');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": inserting abracadabra as row 1 in " $U{table} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

vt_inc_index_DB_DBA_$U{table} ();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": incrementally re-indexing table " $U{table} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select ID from $U{table} where contains (DATA, 'international');
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "*** FAILED";
ECHO BOTH ": " $ROWCNT " rows containing international\n";
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "*** FAILED";
ECHO BOTH ": ID=" $LAST[1] " is last row containing international\n";

select ID from $U{table} where contains (DATA, 'abracadabra');
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "*** FAILED";
ECHO BOTH ": " $ROWCNT " rows containing abracadabra\n";
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "*** FAILED";
ECHO BOTH ": ID=" $LAST[1] " is last row containing abracadabra\n";

drop table VTLOG_DB_DBA_$U{table};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": dropping table VTLOG_DB_DBA_" $U{table} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select P_NAME from SYS_PROCEDURES where lower (P_NAME) = lower ('db.dba.vt_inc_index_db_dba_$U{table}');
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "*** FAILED";
ECHO BOTH ": cleanup of the helper procedures for VTLOG_DB_DBA_" $U{table} "\n";

drop table $U{table}_DATA_WORDS;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": dropping table " $U{table} "_DATA_WORDS STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select P_NAME from SYS_PROCEDURES where lower (P_NAME) like lower('%vt%$U{table}');
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "*** FAILED";
ECHO BOTH ": cleanup of the helper procedures for " $U{table} "_DATA_WORDS\n";

vt_create_text_index ('$U{table}', '$U{datafield}', $U{keyfield}, 0, 0, null, null, null);
vt_batch_update ('$U{table}', 'ON', NULL);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": vt_create_text_index freetext index (key_id = " $U{keyfield} ") on table " $U{table} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO "***** after the text index\n";
select * from $U{table};

select ID from $U{table} where contains (DATA, 'abracadabra');
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "*** FAILED";
ECHO BOTH ": " $ROWCNT " rows containing abracadabra\n";
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "*** FAILED";
ECHO BOTH ": ID=" $LAST[1] " is last row containing abracadabra\n";

drop table $U{table};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": dropping table " $U{table} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select P_NAME from SYS_PROCEDURES where lower (P_NAME) like lower('%vt%$U{table}');
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "*** FAILED";
ECHO BOTH ": cleanup of the helper procedures for " $U{table} "\n";

create table $U{table} (ID $U{idtype} not null $U{pk}, DATA long varchar);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": creating freetext table " $U{table} " with ID type " $U{idtype} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
delete from $U{table};
vt_create_text_index ('$U{table}', '$U{datafield}', null, 1, 0, null, null, null);
vt_batch_update ('$U{table}', 'ON', NULL);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": vt_create_text_index for XML on table " $U{table} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

set U{brace} = $IF $EQU $U{idtype} "varchar" "\'" " ";

INSERT INTO $U{table} (ID, DATA) values ($U{brace}1$U{brace}, '<nonclosed>Education includes a BA in psychology from Colorado State University in 1970.  She also completed "The Art of the Cold Call."  Nancy is a member of Toastmasters International.');
ECHO BOTH $IF $EQU $STATE OK "*** FAILED" "PASSED";
ECHO BOTH ": inserting invalid XML in table " $U{table} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

INSERT INTO $U{table} (ID, DATA) values ($U{brace}1$U{brace}, '<Test><subtag/>data</Test>');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": inserting valid XML in table " $U{table} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update $U{table} set DATA = '<simplyinvalid' where ID = $U{brace}1$U{brace};
ECHO BOTH $IF $EQU $STATE OK "*** FAILED" "PASSED";
ECHO BOTH ": updating data with invalid XML in table " $U{table} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update $U{table} set DATA = '<Test><subtag/>data</Test>' where ID = $U{brace}1$U{brace};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": updating DATA with valid XML in table " $U{table} " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH "COMPLETED: freetext compression test for table " $U{table} " ID type " $U{idtype} "\n";
