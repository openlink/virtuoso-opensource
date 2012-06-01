
ECHO BOTH "Test for index usage with in predicate of exp list\n";



create table tinl  (k1 int, k2 int, d1 int, primary key (k1, k2));

insert into tinl values (1, 2, 3);
insert into tinl values (2, 4, 6);
insert into tinl values (3, 6, 9);


select * from tinl where k1 in (1, 1+1, 3, 4);
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
ECHO BOTH ": 1st key in list \n";

select * from tinl where k1 in (1, vector (1+1, 3), 4);
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
ECHO BOTH ": 1st key in list 2-d element is array \n";

select * from tinl where k1 in (1, 1+1, 3, 4) and k2 in (2, 4);
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": 1st and 2nd key in list\n";
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
ECHO BOTH ": 1st and 2nd key in list \n";



select k1 from tinl  where d1 in (2, 3,9);
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": dependent  in list\n";


select d1 from tinl where k2 in (2, 4);
ECHO BOTH $IF $EQU $LAST[1] 6 "PASSED" "***FAILED";
ECHO BOTH ": 2nd key in list\n";

select a.k1, b.k1 from tinl a, tinl b where b.k1 in (a.d1);
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
ECHO BOTH ":  in list join\n";

select count (*) from sys_users where u_name in (u_name);

drop table tin;
create table tin (id1 int primary key, id2 int, id3 int);
create index tinidx on tin (id2);

foreach integer between 1 10 insert into tin values (?, ?+1, ?+2);

select * from tin table option (index tin) where id1 in (1, 2, 3);
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
ECHO BOTH ": id1 IN on main index \n";
select * from tin table option (index tin) where id2 in (2, 3, 4);
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
ECHO BOTH ": id2 IN on main index \n";
select * from tin table option (index tin) where id3 in (3, 4, 5);
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
ECHO BOTH ": id3 IN on main index \n";

select * from tin table option (index tinidx) where id1 in (1, 2, 3);
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
ECHO BOTH ": id1 IN on secondary index \n";
select * from tin table option (index tinidx) where id2 in (2, 3, 4);
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
ECHO BOTH ": id1 IN on secondary index \n";
select * from tin table option (index tinidx) where id3 in (3, 4, 5);
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
ECHO BOTH ": id1 IN on secondary index \n";

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

ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
ECHO BOTH ": IN on non-key columns in after test \n";
