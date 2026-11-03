--
--  tdatecol.sql
--
--  A DATE column holds a date
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2026 OpenLink Software
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
-- A datetime stored into a DATE column must become the date that
-- cast (... as date) gives: no time, typed as a date.  The vectored insert
-- stored a datetime as it came, with its time and typed as a dateTime, so
-- WHERE D = <the date> missed the row and an RDF view wrote the column as
-- xsd:dateTime.  The same through insert ... select, and through an update of
-- a column-store table.  Run once per TimezonelessDatetimes mode; the dates
-- are in January, away from daylight saving changes, so that a datetime and
-- the midnight of its day have the same local offset.
--

select sys_stat ('timezoneless_datetimes');
ECHO BOTH "tdatecol.sql, TimezonelessDatetimes " $LAST[1] "\n";

create table TDC_SRC (ID integer primary key, DT datetime, T time);
insert into TDC_SRC values (1, cast ('2026-01-19 10:11:12' as datetime), cast ('10:11:12' as time));
insert into TDC_SRC values (2, stringdate ('2026-01-20'), cast ('10:11:12' as time));

create table TDC_ROW (ID integer primary key, D date);
create table TDC_COL (ID integer, D date, primary key (ID) column);

-- 1 a date, 2 a string, 3 stringdate (), 4 a datetime with a time,
-- 6 stringdate () with a time (typed as a date, the time kept),
-- 11 and 12 the same through insert ... select, 5 set by an update
create procedure TDC_FILL (in t varchar)
{
  exec (sprintf ('insert into %s values (1, cast (''2026-01-12'' as date))', t));
  exec (sprintf ('insert into %s values (2, ''2026-01-13'')', t));
  exec (sprintf ('insert into %s values (3, stringdate (''2026-01-14''))', t));
  exec (sprintf ('insert into %s values (4, cast (''2026-01-15 10:11:12'' as datetime))', t));
  exec (sprintf ('insert into %s values (6, stringdate (''2026-01-18 10:11:12''))', t));
  exec (sprintf ('insert into %s (ID, D) select ID + 10, DT from TDC_SRC', t));
  exec (sprintf ('insert into %s values (5, ''2026-01-16'')', t));
  exec (sprintf ('update %s set D = cast (''2026-01-17 08:09:10'' as datetime) where ID = 5', t));
}
;

TDC_FILL ('TDC_ROW');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": dates, a string, stringdate () and datetimes stored into a row-store DATE column STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

TDC_FILL ('TDC_COL');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": the same stored into a column-store DATE column STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from TDC_ROW where __xsd_type (D) = 'http://www.w3.org/2001/XMLSchema#date';
ECHO BOTH $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";
ECHO BOTH ": all 8 values of the row-store DATE column are dates, got " $LAST[1] "\n";

select count (*) from TDC_COL where __xsd_type (D) = 'http://www.w3.org/2001/XMLSchema#date';
ECHO BOTH $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";
ECHO BOTH ": all 8 values of the column-store DATE column are dates, got " $LAST[1] "\n";

select count (*) from TDC_ROW where D = cast ('2026-01-15' as date);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": a datetime stored into a row-store DATE column is found by its date, got " $LAST[1] "\n";

select count (*) from TDC_COL where D = cast ('2026-01-15' as date);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": a datetime stored into a column-store DATE column is found by its date, got " $LAST[1] "\n";

select count (*) from TDC_ROW where D = cast ('2026-01-14' as date);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": stringdate () stored into a row-store DATE column is found by its date, got " $LAST[1] "\n";

select count (*) from TDC_ROW where D = cast ('2026-01-19' as date);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": a datetime column copied by insert ... select into a row-store DATE column is found by its date, got " $LAST[1] "\n";

select count (*) from TDC_COL where D = cast ('2026-01-19' as date);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": a datetime column copied by insert ... select into a column-store DATE column is found by its date, got " $LAST[1] "\n";

select count (*) from TDC_ROW where D = cast ('2026-01-17' as date);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": a row-store DATE column updated with a datetime is found by its date, got " $LAST[1] "\n";

select count (*) from TDC_COL where D = cast ('2026-01-17' as date);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": a column-store DATE column updated with a datetime is found by its date, got " $LAST[1] "\n";

select count (*) from TDC_ROW where D = cast ('2026-01-18' as date);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": stringdate () with a time stored into a row-store DATE column is found by its date, got " $LAST[1] "\n";

select count (*) from TDC_COL where D = cast ('2026-01-18' as date);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": stringdate () with a time stored into a column-store DATE column is found by its date, got " $LAST[1] "\n";

-- A datetime stored into a TIME column must become the time with the zero
-- day and typed as a time, as a single row insert makes it.  The vectored
-- insert ... select and the update of a column-store table stored it as it
-- came, with its day, so WHERE T = <the time> missed the row.
create table TTC_ROW (ID integer primary key, T time);
create table TTC_COL (ID integer, T time, primary key (ID) column);

-- 1 a time, 2 a datetime, 11 and 12 through insert ... select, 3 set by an update
create procedure TTC_FILL (in t varchar)
{
  exec (sprintf ('insert into %s values (1, cast (''10:11:12'' as time))', t));
  exec (sprintf ('insert into %s values (2, cast (''2026-01-15 10:11:12'' as datetime))', t));
  exec (sprintf ('insert into %s (ID, T) select ID + 10, DT from TDC_SRC where ID = 1', t));
  exec (sprintf ('insert into %s values (3, cast (''09:00:00'' as time))', t));
  exec (sprintf ('update %s set T = cast (''2026-01-17 10:11:12'' as datetime) where ID = 3', t));
}
;

TTC_FILL ('TTC_ROW');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": times and datetimes stored into a row-store TIME column STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

TTC_FILL ('TTC_COL');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": the same stored into a column-store TIME column STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from TTC_ROW where __xsd_type (T) = 'http://www.w3.org/2001/XMLSchema#time';
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": all 4 values of the row-store TIME column are times, got " $LAST[1] "\n";

select count (*) from TTC_COL where __xsd_type (T) = 'http://www.w3.org/2001/XMLSchema#time';
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": all 4 values of the column-store TIME column are times, got " $LAST[1] "\n";

select count (*) from TTC_ROW where T = cast ('10:11:12' as time);
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": datetimes stored into a row-store TIME column are found by their time, got " $LAST[1] "\n";

select count (*) from TTC_COL where T = cast ('10:11:12' as time);
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": datetimes stored into a column-store TIME column are found by their time, got " $LAST[1] "\n";

select count (*) from TTC_ROW where T = cast (cast ('2026-01-15 10:11:12' as datetime) as time);
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": the time cast of a datetime finds the times of a row-store TIME column, got " $LAST[1] "\n";

select count (*) from TTC_COL where T = cast (cast ('2026-01-15 10:11:12' as datetime) as time);
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": the time cast of a datetime finds the times of a column-store TIME column, got " $LAST[1] "\n";

drop table TTC_COL;
drop table TTC_ROW;

-- guards: a DATETIME and a TIME column keep their time
select minute (DT) * 100 + second (DT) from TDC_SRC where ID = 1;
ECHO BOTH $IF $EQU $LAST[1] 1112 "PASSED" "***FAILED";
ECHO BOTH ": a DATETIME column keeps its time, got " $LAST[1] "\n";

select minute (T) * 100 + second (T) from TDC_SRC where ID = 1;
ECHO BOTH $IF $EQU $LAST[1] 1112 "PASSED" "***FAILED";
ECHO BOTH ": a TIME column keeps its time, got " $LAST[1] "\n";

-- an RDF view of the column writes each value as an xsd:date
SPARQL
create iri class <urn:tdc:row_iri> "urn:tdc:row/%d" (in id integer not null) .
;

SPARQL
alter quad storage virtrdf:DefaultQuadStorage
  from DB.DBA.TDC_COL as tdc_col
  {
    create <urn:tdc:qm> as graph <urn:tdc:g>
      {
        <urn:tdc:row_iri> (tdc_col.ID) <urn:tdc:d> tdc_col.D .
      }
  }
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": an RDF view of the column-store DATE column STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from (sparql select (str (datatype (?o)) as ?dt) from <urn:tdc:g> where { ?s <urn:tdc:d> ?o }) x
  where "dt" = 'http://www.w3.org/2001/XMLSchema#date';
ECHO BOTH $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";
ECHO BOTH ": the RDF view writes all 8 values of the DATE column as xsd:date, got " $LAST[1] "\n";

SPARQL drop quad map <urn:tdc:qm>;
SPARQL drop iri class <urn:tdc:row_iri>;
drop table TDC_COL;
drop table TDC_ROW;
drop table TDC_SRC;
