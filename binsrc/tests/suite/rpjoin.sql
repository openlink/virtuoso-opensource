--  
--  $Id: rpjoin.sql,v 1.5.6.1.4.1 2013/01/02 16:14:53 source Exp $
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
DROP TABLE T_LOC;

CREATE TABLE T_LOC (S_DATE DATE, S_STATUS VARCHAR, S_NO VARCHAR);


echo both "Joins with remotes and proc views rpjoin.sql\n";

INSERT INTO T_LOC SELECT FDATE, substring (FS4, 1, 1), concat ('0102-', STRING1) FROM R1..T1 WHERE ROW_NO > 100 AND ROW_NO < 121;


CREATE PROCEDURE DELIVERY_PROCEDURE(IN S_NO VARCHAR )
{
    DECLARE CMD, MSG, STATE, S_STATUS, NULL_SHIPPING_NO VARCHAR;
    DECLARE METADATA, RESULT_ROWS, ROW ANY;
    DECLARE NDX INTEGER;
    DECLARE S_DATE DATETIME;
    NULL_SHIPPING_NO := S_NO;
    IF (NULL_SHIPPING_NO IS NULL)
      {
	signal('REQDPM', 'The column S_NO must be restricted in the where clause');
      }
    S_NO := cast(S_NO AS VARCHAR);
    RESULT_NAMES(S_NO, S_DATE, S_STATUS);
    CMD := sprintf('SELECT S_DATE, S_STATUS FROM T_LOC WHERE S_NO = ''%s''', S_NO);
    STATE := '00000'; exec (CMD, STATE, MSG, VECTOR (), 1000, METADATA, RESULT_ROWS);
    if (isarray(RESULT_ROWS))
      {
	NDX := 0;
	while (NDX < length(RESULT_ROWS))
	  {
	    ROW := aref(RESULT_ROWS, NDX);
	    if (length(ROW) >= 2)
	      {
		S_DATE := aref(ROW, 0);
		S_STATUS := aref(ROW, 1);
		result(S_NO, S_DATE, S_STATUS);
	      }
	    NDX := NDX + 1;
          }
    }
};

CREATE PROCEDURE GD_TRACKING_NO(IN TRACKING_NO VARCHAR)
{
   return (concat('0102-', TRACKING_NO));
};


DROP VIEW DELIVERY_VIEW;

CREATE PROCEDURE VIEW DELIVERY_VIEW AS DELIVERY_PROCEDURE(S_NO)(S_NO VARCHAR, S_DATE DATETIME,  S_STATUS VARCHAR);


SELECT CAST('GUARANTEED' AS VARCHAR), S.STRING1, S.STRING2, S.FDATE, G.S_STATUS, G.S_NO FROM
         R1..T1 S INNER JOIN DELIVERY_VIEW G ON ( GD_TRACKING_NO(S.STRING1) = G.S_NO );

ECHO BOTH $IF $EQU $ROWCNT 80 "PASSED" "***FAILED";
ECHO BOTH ": INNER JOIN on procedure view and remote table " $rowcnt " rows\n";


SELECT CAST('GUARANTEED' AS VARCHAR), S.STRING1, S.STRING2, S.FDATE, G.S_STATUS, G.S_NO FROM
         R1..T1 S, DELIVERY_VIEW G WHERE  GD_TRACKING_NO(S.STRING1) = G.S_NO option (order);
ECHO BOTH $IF $EQU $ROWCNT 80 "PASSED" "***FAILED";
ECHO BOTH ": JOIN comma syntax on procedure view and remote table " $rowcnt " rows\n";


SELECT CAST('GUARANTEED' AS VARCHAR), S.STRING1, S.STRING2, S.FDATE, G.S_STATUS, G.S_NO FROM
         R1..T1 S LEFT OUTER JOIN DELIVERY_VIEW G ON ( GD_TRACKING_NO(S.STRING1) = G.S_NO );
ECHO BOTH $IF $EQU $ROWCNT 1000 "PASSED" "***FAILED";
ECHO BOTH ": LEFT OUTER JOIN on procedure view and remote table " $rowcnt " rows\n";

SELECT CAST('GUARANTEED' AS VARCHAR), S.STRING1, S.STRING2, S.FDATE, G.S_STATUS, G.S_NO FROM
         R1..T1 S RIGHT OUTER JOIN DELIVERY_VIEW G ON ( GD_TRACKING_NO(S.STRING1) = G.S_NO );
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
ECHO BOTH ": RIGHT OUTER JOIN on procedure view and remote table " $rowcnt " rows\n";


SELECT CAST('GUARANTEED' AS VARCHAR), S.STRING1, S.STRING2, S.FDATE, G.S_STATUS, G.S_NO FROM
        DELIVERY_VIEW G  RIGHT OUTER JOIN R1..T1 S ON (G.S_NO = GD_TRACKING_NO(S.STRING1));
ECHO BOTH $IF $EQU $ROWCNT 1000 "PASSED" "***FAILED";
ECHO BOTH ": RIGHT OUTER JOIN on procedure view and remote table " $rowcnt " rows\n";

SELECT CAST('GUARANTEED' AS VARCHAR), S.STRING1, S.STRING2, S.FDATE, G.S_STATUS, G.S_NO FROM
        DELIVERY_VIEW G  LEFT OUTER JOIN R1..T1 S ON (G.S_NO = GD_TRACKING_NO(S.STRING1));
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
ECHO BOTH ": LEFT OUTER JOIN on procedure view and remote table " $rowcnt " rows\n";


