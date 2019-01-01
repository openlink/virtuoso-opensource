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

echo both "Test for index usage with in predicate of exp list\n";



create table tinl  (k1 int, k2 int, d1 int, primary key (k1, k2));

insert into tinl values (1, 2, 3);
insert into tinl values (2, 4, 6);
insert into tinl values (3, 6, 9);


select * from tinl where k1 in (1, 1+1, 3, 4);
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ": 1st key in list \n";

select * from tinl where k1 in (1, vector (1+1, 3), 4);
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ": 1st key in list 2-d element is array \n";

select * from tinl where k1 in (1, 1+1, 3, 4) and k2 in (2, 4);
echo both $if $equ $last[1] 2 "PASSED" "***FAILED";
echo both ": 1st and 2nd key in list\n";
echo both $if $equ $rowcnt 2 "PASSED" "***FAILED";
echo both ": 1st and 2nd key in list \n";



select k1 from tinl  where d1 in (2, 3,9);
echo both $if $equ $last[1] 3 "PASSED" "***FAILED";
echo both ": dependent  in list\n";


select d1 from tinl where k2 in (2, 4);
echo both $if $equ $last[1] 6 "PASSED" "***FAILED";
echo both ": 2nd key in list\n";

select a.k1, b.k1 from tinl a, tinl b where b.k1 in (a.d1);
echo both $if $equ $rowcnt 1 "PASSED" "***FAILED";
echo both ":  in list join\n";

select count (*) from sys_users where u_name in (u_name);

drop table tin;
create table tin (id1 int primary key, id2 int not null, id3 int not null);
create index tinidx on tin (id2);

foreach integer between 1 10 insert into tin values (?, ?+1, ?+2);

select * from tin table option (index tin) where id1 in (1, 2, 3);
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ": id1 IN on main index \n";
select * from tin table option (index tin) where id2 in (2, 3, 4);
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ": id2 IN on main index \n";
select * from tin table option (index tin) where id3 in (3, 4, 5);
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ": id3 IN on main index \n";

select * from tin table option (index tinidx) where id1 in (1, 2, 3);
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ": id1 IN on secondary index \n";
select * from tin table option (index tinidx) where id2 in (2, 3, 4);
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ": id1 IN on secondary index \n";
select * from tin table option (index tinidx) where id3 in (3, 4, 5);
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ": id1 IN on secondary index \n";

DROP TABLE BB_topics;
DROP TABLE BB_topics_posted;
DROP TABLE BB_topics_track;

CREATE TABLE BB_topics (
	topic_id INTEGER,
	forum_id INTEGER,
	topic_type INTEGER,
	PRIMARY KEY (topic_id)
);

CREATE TABLE BB_topics_posted (
	user_id INTEGER,
	topic_id INTEGER,
	topic_posted INTEGER,
	PRIMARY KEY (user_id, topic_id)
);

CREATE TABLE BB_topics_track (
	user_id INTEGER,
	topic_id INTEGER,
	forum_id INTEGER,
	PRIMARY KEY (user_id, topic_id)
);

insert into BB_topics (topic_id, forum_id, topic_type) values (3, 6, 0);
insert into BB_topics_posted (user_id, topic_id, topic_posted) values (2, 3, 1);
insert into BB_topics_track (user_id, topic_id, forum_id) values (-1, -1, -1);

SELECT t.forum_id, t.topic_type FROM BB_topics t
  LEFT JOIN BB_topics_posted tp ON (tp.topic_id = t.topic_id AND tp.user_id = 2)
  LEFT JOIN BB_topics_track tt ON (tt.topic_id = t.topic_id AND tt.user_id = 2)
  WHERE (t.forum_id IN (6, 0) AND t.topic_type in (2,3));

echo both $if $equ $rowcnt 0 "PASSED" "***FAILED";
echo both ": IN on non-key columns in after test \n";
