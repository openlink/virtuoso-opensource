--
--  $Id: tregexp.sql,v 1.5.10.1 2013/01/02 16:15:20 source Exp $
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
echo BOTH "STARTED: regexp " $U{N} "varchar tests\n";

SET ARGV[0] 0;
SET ARGV[1] 0;

echo "U{N}=[" $U{N} "]\n";

ECHO "PARK=" $U{michigan_park} "\n";
ECHO "PARK=" $U{michigan_park_c} "\n";

DROP TABLE $U{michigan_park};
DROP TABLE michigan_park;
DROP TABLE N_michigan_park;

CREATE TABLE $U{michigan_park} (
    park_name VARCHAR (40),
    park_phone VARCHAR (15),
    description $U{N}VARCHAR (500)
);

INSERT INTO $U{michigan_park} VALUES (
    'Mackinac Island State Park', '(231) 436-4100',
    $U{N}'Michigan''s first state park encompasses approximately 1800 acres
of Mackinac Island. The centerpiece is Fort Mackinac, built in 1780 by
the British to protect the Great Lakes Fur Trade. For information by
phone, dial 800-44-PARKS or 517-373-1214.');

INSERT INTO $U{michigan_park} VALUES (
    'Fort Wilkens State Park', '(906) 289-4215',
    $U{N}'Located almost at the very tip of the Keewenaw Penninsula,
Fort Wilkens is a restored army fort built during the copper rush.
Camping is available. For the modern campground, phone (800) 447-2757. For
group-camping, phone 906.289.4215. For information on canoe, kayak, and
other boat rentals, call the concession office at (906) 289-4210.');

INSERT INTO $U{michigan_park} VALUES (
    'Laughing Whitefish Falls Scenic Site', '(906) 863-9747',
    $U{N}'This scenic site is centered around an impressive waterfall.
A rustic, picnic area with waterpump is available.');

INSERT INTO $U{michigan_park} VALUES (
    'Muskallonge Lake State Park', '(906) 658-3338',
    $U{N}'A 217-acre park located on the site of an old lumber town, Deer Park.
Shower and toilet facilities are available, as are campsites with
electricity.');

INSERT INTO $U{michigan_park} VALUES ('Porcupine Mountains State Park',
    '(906) 885-5275',
    $U{N}'Michigan''s largest state park consists of some 60,000 acres
of mostly virgin timber. Over 90 miles of trails are available
to backpackers and hikers. Downhill skiing is available in winter.
Rustic cabins are available. To reserve a cabin, call (906) 885-5275.');

INSERT INTO $U{michigan_park} VALUES ('Tahquamenon Falls State Park',
    NULL, $U{N}'One of the largest waterfalls east of the Mississippi is found
within this park''s 40,000+ acres. Upper Tahquamenon Falls is some 50 feet
high, 200 feet across, and supports a flow that has been known to reach
50,000 gallons/second. The park phone is 906.492.3415.');

CREATE INDEX $U{michigan_park}_name
ON $U{michigan_park} (park_name);

--CREATE INDEX michigan_park_acres
--ON michigan_park (TO_NUMBER(REPLACE(REGEXP_SUBSTR(
--    REGEXP_SUBSTR(description,'[^ ]+[- ]acres?',1,1,'i'),
--    '[0-9,]+'),',','')));

--ANALYZE TABLE michigan_park
--    COMPUTE STATISTICS
--        FOR TABLE
--        FOR ALL INDEXED COLUMNS
--        FOR ALL INDEXES;

DROP TABLE $U{michigan_park_c};
DROP TABLE michigan_park_c;
DROP TABLE N_michigan_park_c;

CREATE TABLE $U{michigan_park_c} (
    park_name VARCHAR (40),
    park_phone VARCHAR (15),
    description VARCHAR (500)
);


ALTER TABLE $U{michigan_park_c}
ADD CONSTRAINT phone_number_format
     CHECK (REGEXP_LIKE(park_phone,
     '^\\([[:digit:]]{3}\\) [[:digit:]]{3}-[[:digit:]]{4}\$'));

set MACRO_SUBSTITUTION on;
set NO_CHAR_C_ESCAPE = 0;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ADD CONSTRAINT phone_number_format STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--COMMIT;

/* This file contains the text of the regular expression queries
   used in the article. I've also added several other, interesting,
   queries that didn't make the final article.
*/

/* Listing 1: Finding phone numbers in the park descriptions
*/

--Set some column formats used in both Listing 1 and Listing 2
--SET PAGESIZE 0
--COLUMN description FOLD_BEFORE

--The query
SELECT park_name, description FROM $U{michigan_park} WHERE REGEXP_LIKE(description, $U{N}'...-....');

ECHO BOTH $IF $EQU $ROWCNT 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q1 returned " $ROWCNT " rows\n";

/* Listing 2: Increasing the constraints on the phone number pattern
*/

--Following is one solution to specifying the three-dash-four pattern:
SELECT park_name, description
FROM $U{michigan_park}
WHERE REGEXP_LIKE(description, $U{N}'[0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]');

ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q2 returned " $ROWCNT " rows\n";

--Save typing by use the {min,max} syntax to specify repeat counts:
SELECT park_name, description
FROM $U{michigan_park}
WHERE REGEXP_LIKE(description, $U{N}'[0-9]{3}-[0-9]{4,4}');

ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q3 returned " $ROWCNT " rows\n";

--Allow for a period between digit groups. Tahquamenon Falls
--illustrates this case:
SELECT park_name, description
FROM $U{michigan_park}
WHERE REGEXP_LIKE(description, $U{N}'[0-9]{3}[-.][0-9]{4,4}');

ECHO BOTH $IF $EQU $ROWCNT 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q4 returned " $ROWCNT " rows\n";

/* Listing 3: Constraining the phone number column
*/

--Following is the command to add the constraint. However, the
--constraint has already been created by the RegexSampleData.sql
--script.
--
--ALTER TABLE michigan_park
--ADD (CONSTRAINT phone_number_format
--     CHECK (REGEXP_LIKE(park_phone,
--     '^\([[:digit:]]{3}\) [[:digit:]]{3}-[[:digit:]]{4}$')));

--The following INSERT statements test the constraint. The
--first three fail, while the fourth succeeds. Notice that
--leading and trailing spaces are not allowed. This is because the
--carot(^) and dollar-sign($) characters anchor the pattern to
--beginning and end of the column value. There's no room in the
--pattern for leading or trailing spaces.

delete from $U{michigan_park_c};

INSERT INTO $U{michigan_park_c} (park_name, park_phone)
   VALUES ('Warren Dunes State Park','616.426.4013');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Constr violate 1 STATE= " $STATE " MESSAGE=" $MESSAGE "\n";

INSERT INTO $U{michigan_park_c} (park_name, park_phone)
   VALUES ('Warren Dunes State Park','(616) 426-4013 ');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Constr violate 2 STATE= " $STATE " MESSAGE=" $MESSAGE "\n";

INSERT INTO $U{michigan_park_c} (park_name, park_phone)
   VALUES ('Warren Dunes State Park',' (616) 426-4013');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Constr violate 3 STATE= " $STATE " MESSAGE=" $MESSAGE "\n";

INSERT INTO $U{michigan_park_c} (park_name, park_phone)
   VALUES ('Warren Dunes State Park','(616) 426-4013');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Constr violate 4 STATE= " $STATE " MESSAGE=" $MESSAGE "\n";

/* Listing 4: Regularizing the format of the phone numbers
*/

--I used the following query to test my REGEXP_REPLACE call
--before unleashing it in an UPDATE statement:

SELECT REGEXP_REPLACE($U{N}'800-44-PARKS or 517-373-1214',
    $U{N}'([[:digit:]]{3})[-.]([[:digit:]]{3})[-.]([[:digit:]]{4})',
    $U{N}'(\\1) \\2-\\3');
ECHO BOTH $IF $EQU $LAST[1] '800-44-PARKS or (517) 373-1214' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": REGEXP_REPLACE returned {" $LAST[1] "}\n";


--Following is the UPDATE statement:
--UPDATE michigan_park
--SET description = REGEXP_REPLACE(description,
--    '([[:digit:]]{3})[-.]([[:digit:]]{3})[-.]([[:digit:]]{4})',
--    '(\1) \2-\3');

--To verify the results:
--SET PAGESIZE 0
--COLUMN description FOLD_BEFORE

--SELECT park_name, description
--FROM michigan_park;

/* Listing 5: Finding the acreage for each park
*/
SELECT REGEXP_INSTR(description, $U{N}'[[:digit:]]* acres'), description from $U{michigan_park}  WHERE REGEXP_LIKE(description, $U{N}'[[:digit:]]* acres');
--I went through several iterations to get this expression right.
--First I tried the following, but it returned "000 acres" instead
--of "60,000 acres".
SELECT park_name, SUBSTRING(description,
    REGEXP_INSTR(description, $U{N}'[[:digit:]]* acres',1,1,0),
    REGEXP_INSTR(description, $U{N}'[[:digit:]]* acres',1,1,1)
    - REGEXP_INSTR(description, $U{N}'[[:digit:]]* acres',1,1,0))
FROM $U{michigan_park}
WHERE REGEXP_LIKE(description, $U{N}'[[:digit:]]* acres');

ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": regexp_instr q1 returned " $ROWCNT " rows\n";

--Next, I added a comma to the list of characters I would accept.
--[:digit:] gave me all digits, and the comma that follows gave
--me the comma. Results were better, but I still didn't get
--the "40,000+" value for Tahquamenon Falls State Park.
SELECT park_name, SUBSTRING(description,
    REGEXP_INSTR(description,$U{N}'[[:digit:],]* acres',1,1,0),
    REGEXP_INSTR(description,$U{N}'[[:digit:],]* acres',1,1,1)
    - REGEXP_INSTR(description,$U{N}'[[:digit:],]* acres',1,1,0))
FROM $U{michigan_park}
WHERE REGEXP_LIKE(description, $U{N}'[[:digit:],]* [Aa]cres');
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": regexp_instr q2 returned " $ROWCNT " rows\n";

--I decided to look for a word of any sort in front of the
--word "acres".
SELECT park_name, SUBSTRING(description,
    REGEXP_INSTR(description,$U{N}'[^ ]+ acres',1,1,0),
    REGEXP_INSTR(description,$U{N}'[^ ]+ acres',1,1,1)
    - REGEXP_INSTR(description,$U{N}'[^ ]+ acres',1,1,0))
FROM $U{michigan_park}
WHERE REGEXP_LIKE(description, $U{N}'[^ ]+ acres');
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": regexp_instr q3 returned " $ROWCNT " rows\n";

--The last problem to solve was that of Muskallonge Lake State Park,
--which contained the wording "217-acre" instead of "217 acres".
SELECT park_name, SUBSTRING(description,
    REGEXP_INSTR(description,$U{N}'[^ ]+[- ]acres?',1,1,0),
    REGEXP_INSTR(description,$U{N}'[^ ]+[- ]acres?',1,1,1)
    - REGEXP_INSTR(description,$U{N}'[^ ]+[- ]acres?',1,1,0))
FROM $U{michigan_park}
WHERE REGEXP_LIKE(description, $U{N}'[^ ]+[- ]acres?');
ECHO BOTH $IF $EQU $ROWCNT 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": regexp_instr q4 returned " $ROWCNT " rows\n";

--To show the "or" operator in the article, I used the following
--query for Listing 5:
SELECT park_name, SUBSTRING(description,
    REGEXP_INSTR(description, $U{N}'[^ ]+ acres|[^ ]+-acre',1,1,0),
    REGEXP_INSTR(description, $U{N}'[^ ]+ acres|[^ ]+-acre',1,1,1)
    - REGEXP_INSTR(description, $U{N}'[^ ]+ acres|[^ ]+-acre',1,1,0)) acres
FROM $U{michigan_park}
WHERE REGEXP_LIKE(description, $U{N}'[^ ]+ acres|[^ ]+-acre');
ECHO BOTH $IF $EQU $ROWCNT 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": regexp_instr q5 returned " $ROWCNT " rows\n";


/* Listing 6: Using REGEXP_SUBSTR to extract acreage information
*/
SELECT park_name,
       REGEXP_SUBSTR($U{N}'[^ ]+[- ]acres?',description,0) acres
FROM $U{michigan_park}
WHERE REGEXP_LIKE(description, $U{N}'[^ ]+[- ]acres?');
ECHO BOTH $IF $EQU $ROWCNT 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": regexp_substr q1 returned " $ROWCNT " rows\n";

/* Listing 7: Functional indexes can speed regular expression queries
*/

--The following index will have been created by the
--RegexSampleData.sql script. That script will also
--have analyzed the table and index. The ANALYZE
--is important!
--CREATE INDEX michigan_park_acres
--ON michigan_park (TO_NUMBER(REPLACE(REGEXP_SUBSTR(
--    REGEXP_SUBSTR(description,'[^ ]+[- ]acres?',1,1,'i'),
--    '[0-9,]+'),',','')));

--The following settings did not appear to be necessary for me,
--but my contact at Oracle suggested them.

--You may wish to execute SET AUTOTRACE ON EXPLAIN prior
--to executing the following query, so that you can
--easily view the resulting execution plan.

SELECT park_name
FROM $U{michigan_park}
WHERE cast (REPLACE(REGEXP_SUBSTR($U{N}'[0-9,]+',
    coalesce (REGEXP_SUBSTR($U{N}'[^ ]+[- ]acres?', description,0), $U{N}''),
    0),$U{N}',',$U{N}'') as numeric) > 10000;
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": regexp_substr q2 returned " $ROWCNT " rows\n";

select regexp_replace ($U{N}'<a href="gogo.html" />', $U{N}'(href[[:space:]]*=[[:space:]]*")(([a-zA-Z]*://)?([a-zA-Z0-9-_/#%=~&;:\\.\\?\\+]*))', $U{N}'found [\\3]');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 6425 : returned STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: regexp " $U{N} "varchar tests\n";
