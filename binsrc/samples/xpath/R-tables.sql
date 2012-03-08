--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2012 OpenLink Software
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
drop TABLE "Demo"."demo"."XPBids"; 
drop table "Demo"."demo"."XPItems";
drop table "Demo"."demo"."XPUsers";

CREATE TABLE "Demo"."demo"."XPUsers" (
       "UserID" varchar(5) NOT NULL PRIMARY KEY,
       "Name"  VARCHAR(50) NOT NULL,
       "Rating" CHAR NOT NULL);
GRANT SELECT ON "Demo"."demo"."XPUsers" TO PUBLIC;

INSERT INTO "Demo"."demo"."XPUsers" VALUES ('U01', 'Tom Jones', 'B'); 
INSERT INTO "Demo"."demo"."XPUsers" VALUES ('U02', 'Mary Doe', 'A');
INSERT INTO "Demo"."demo"."XPUsers" VALUES ('U03', 'Dee Linquent', 'D'); 
INSERT INTO "Demo"."demo"."XPUsers" VALUES ('U04', 'Roger Smith', 'C');
INSERT INTO "Demo"."demo"."XPUsers" VALUES ('U05', 'Jack Sprat', 'B'); 
INSERT INTO "Demo"."demo"."XPUsers" VALUES ('U06', 'Rip Van Winkle', 'B'); 

CREATE TABLE "Demo"."demo"."XPItems" (
       "Itemno" INTEGER NOT NULL PRIMARY KEY,
       "Description" VARCHAR(30) NOT NULL,
       "Offered_by"  VARCHAR(5) NOT NULL REFERENCES "Demo"."demo"."XPUsers"("UserID"),
       "Start_Date"  DATE NOT NULL,
       "End_Date"	   DATE NOT NULL,
       "Reserve_Price"	INTEGER NOT NULL);
GRANT SELECT ON "demo"."demo"."XPUsers" TO PUBLIC;

INSERT INTO "Demo"."demo"."XPItems" VALUES (1001, 'Red Bicycle', 'U01', stringdate('1999-01-05'), stringdate('1999-01-20'), 40 );
INSERT INTO "Demo"."demo"."XPItems" VALUES (1002, 'Motorcycle', 'U02', stringdate('1999-02-11'), stringdate('1999-03-15'), 500 );
INSERT INTO "Demo"."demo"."XPItems" VALUES (1003, 'Old Bicycle', 'U02', stringdate('1999-01-10'), stringdate('1999-02-20'), 25 );
INSERT INTO "Demo"."demo"."XPItems" VALUES (1004, 'Tricycle', 'U01', stringdate('1999-02-25'), stringdate('1999-03-08'), 15 );
INSERT INTO "Demo"."demo"."XPItems" VALUES (1005, 'Tennis Racket', 'U03', stringdate('1999-03-19'), stringdate('1999-04-30'), 20 );
INSERT INTO "Demo"."demo"."XPItems" VALUES (1006, 'Helicopter', 'U03', stringdate('1999-05-05'), stringdate('1999-05-25'), 50000 );
INSERT INTO "Demo"."demo"."XPItems" VALUES (1007, 'Racing Bicycle', 'U04', stringdate('1999-01-20'), stringdate('1999-02-20'), 200 );
INSERT INTO "Demo"."demo"."XPItems" VALUES (1008, 'Broken Bicycle', 'U01', stringdate('1999-02-05'), stringdate('1999-03-06'), 25 );

CREATE TABLE "Demo"."demo"."XPBids" (
--       "Bidno" INTEGER NOT NULL PRIMARY KEY,
       "UserID" VARCHAR(5) NOT NULL REFERENCES "Demo"."demo"."XPUsers"("UserID"),
       "Itemno" INTEGER NOT NULL REFERENCES "Demo"."demo"."XPItems"("Itemno"),
       "Bid"    INTEGER NOT NULL,
       "Bid_Date"	      DATE NOT NULL,
       CONSTRAINT ids_pk PRIMARY KEY
          (UserID, Itemno, Bid));
--);
GRANT SELECT ON "Demo"."demo"."XPBids" TO PUBLIC;

INSERT INTO "Demo"."demo"."XPBids" VALUES ('U02', 1001, 35, stringdate('1999-01-07') );
INSERT INTO "Demo"."demo"."XPBids" VALUES ('U04', 1001, 40, stringdate('1999-01-08') );
INSERT INTO "Demo"."demo"."XPBids" VALUES ('U02', 1001, 45, stringdate('1999-01-11') );
INSERT INTO "Demo"."demo"."XPBids" VALUES ('U04', 1001, 50, stringdate('1999-01-13') );
INSERT INTO "Demo"."demo"."XPBids" VALUES ('U02', 1001, 55, stringdate('1999-01-15') );
INSERT INTO "Demo"."demo"."XPBids" VALUES ('U01', 1002, 400, stringdate('1999-02-14') );
INSERT INTO "Demo"."demo"."XPBids" VALUES ('U02', 1002, 600, stringdate('1999-02-16') );
INSERT INTO "Demo"."demo"."XPBids" VALUES ('U03', 1002, 800, stringdate('1999-02-17') );
INSERT INTO "Demo"."demo"."XPBids" VALUES ('U04', 1002, 1000, stringdate('1999-02-25') );
INSERT INTO "Demo"."demo"."XPBids" VALUES ('U02', 1002, 1200, stringdate('1999-03-02') );
INSERT INTO "Demo"."demo"."XPBids" VALUES ('U04', 1003, 15, stringdate('1999-01-22') );
INSERT INTO "Demo"."demo"."XPBids" VALUES ('U05', 1003, 20, stringdate('1999-02-03') );
INSERT INTO "Demo"."demo"."XPBids" VALUES ('U01', 1004, 40, stringdate('1999-03-05') );
INSERT INTO "Demo"."demo"."XPBids" VALUES ('U03', 1007, 175, stringdate('1999-01-25') );
INSERT INTO "Demo"."demo"."XPBids" VALUES ('U05', 1007, 200, stringdate('1999-02-08') );
INSERT INTO "Demo"."demo"."XPBids" VALUES ('U04', 1007, 225, stringdate('1999-02-12') );
