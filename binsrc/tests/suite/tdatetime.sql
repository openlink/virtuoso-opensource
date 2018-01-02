--
--  tdatetime.sql
--
--  $Id$
--
--  Test date and timestamp functions
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2018 OpenLink Software
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

create function TZL_TEST (in expn varchar, in tz0 varchar, in tz1 varchar, in tz2 varchar, in tz3 varchar, in tz4 varchar)
{
  declare stat,msg,rset,mdata any;
  declare res, right_res varchar;
  declare tzmode integer;
  tzmode := sys_stat('timezoneless_datetimes');
  stat := '00000';
  msg := '';
  exec (expn, stat, msg, vector(), 10, mdata, rset);
  res := case stat when '00000' then cast (rset[0][0] as varchar) else 'Error ' || stat end;
  right_res := case tzmode when 0 then tz0 when 1 then tz1 when 2 then tz2 when 3 then tz3 when 4 then tz4 else 'Weird TimezonelessDatetimes' || tzmode end;
  if (res = right_res)
    return 'PASSED: ' || expn || ' returns "' || res || '"' || case msg when '' then '' else ' (' || msg || ')' end || ' in mode ' || tzmode;
  else
    return '***FAILED: ' || expn || ' returns "' || res || '"' || case msg when '' then '' else ' (' || msg || ')' end || ' in mode ' || tzmode || ', not "' || right_res || '"';
}
;

-- SPARQL:
-- Dates													| 0				| 1			| 2			| 3			| 4
select TZL_TEST ('sparql select str(strdt("1999-12-31", xsd:date))	 		where {}'	, '1999-12-31+06:00'		, '1999-12-31'		, '1999-12-31'		, '1999-12-31+06:00'	, '1999-12-31Z'		);
select TZL_TEST ('sparql select str(strdt("1999-12-31+02:00", xsd:date))			where {}'	, '1999-12-31+02:00'		, '1999-12-31+02:00'	, '1999-12-31+02:00'	, '1999-12-31+02:00'	, '1999-12-31+02:00'	);
select TZL_TEST ('sparql select str(strdt("1999-12-31+00:00", xsd:date))			where {}'	, '1999-12-31Z'			, '1999-12-31Z'		, '1999-12-31Z'		, '1999-12-31Z'		, '1999-12-31Z'		);

-- Proper XSD dateTimes											| 0				| 1				| 2				| 3				| 4
select TZL_TEST ('sparql select str(strdt("1999-12-31", xsd:dateTime))			where {}'	, '1999-12-31T00:00:00+06:00'	, '1999-12-31T00:00:00+06:00'		, '1999-12-31T00:00:00'		, '1999-12-31T00:00:00+06:00'	, '1999-12-31T00:00:00Z'	);
select TZL_TEST ('sparql select str(strdt("1999-12-31+02:00", xsd:dateTime))		where {}'	, '1999-12-31T00:00:00+02:00'	, '1999-12-31T00:00:00+02:00'	, '1999-12-31T00:00:00+02:00'	, '1999-12-31T00:00:00+02:00'	, '1999-12-31T00:00:00+02:00'	);
select TZL_TEST ('sparql select str(strdt("1999-12-31+00:00", xsd:dateTime))		where {}'	, '1999-12-31T00:00:00Z'		, '1999-12-31T00:00:00Z'	, '1999-12-31T00:00:00Z'	, '1999-12-31T00:00:00Z'	, '1999-12-31T00:00:00Z'	);
select TZL_TEST ('sparql select str(strdt("1999-12-31T11:59", xsd:dateTime))		where {}'	, '1999-12-31T11:59:00'		, '1999-12-31T11:59:00'		, '1999-12-31T11:59:00'		, '1999-12-31T11:59:00'	, '1999-12-31T11:59:00'	);
select TZL_TEST ('sparql select str(strdt("1999-12-31T11:59+02:00", xsd:dateTime))	where {}'	, '1999-12-31T11:59:00+02:00'	, '1999-12-31T11:59:00+02:00'	, '1999-12-31T11:59:00+02:00'	, '1999-12-31T11:59:00+02:00'	, '1999-12-31T11:59:00+02:00'	);
select TZL_TEST ('sparql select str(strdt("1999-12-31T11:59+00:00", xsd:dateTime))	where {}'	, '1999-12-31T11:59:00Z'		, '1999-12-31T11:59:00Z'	, '1999-12-31T11:59:00Z'	, '1999-12-31T11:59:00Z'	, '1999-12-31T11:59:00Z'	);
select TZL_TEST ('sparql select str(strdt("1999-12-31T11:59-00:00", xsd:dateTime))	where {}'	, '1999-12-31T11:59:00'		, '1999-12-31T11:59:00'	, '1999-12-31T11:59:00'	, '1999-12-31T11:59:00'	, '1999-12-31T11:59:00'	);

-- Wrong XSD dateTimes											| 0				| 1				| 2				| 3				| 4
select TZL_TEST ('sparql select str(strdt("1999-12-31 11:59", xsd:dateTime))		where {}'	, '1999-12-31 11:59'		, '1999-12-31 11:59'		, '1999-12-31 11:59'		, '1999-12-31 11:59'		, '1999-12-31 11:59'		);
select TZL_TEST ('sparql select str(strdt("1999-12-31 11:59+02:00", xsd:dateTime))	where {}'	, '1999-12-31 11:59+02:00'	, '1999-12-31 11:59+02:00'	, '1999-12-31 11:59+02:00'	, '1999-12-31 11:59+02:00'	, '1999-12-31 11:59+02:00'	);
select TZL_TEST ('sparql select str(strdt("1999-12-31 11:59+00:00", xsd:dateTime))	where {}'	, '1999-12-31 11:59+00:00'	, '1999-12-31 11:59+00:00'	, '1999-12-31 11:59+00:00'	, '1999-12-31 11:59+00:00'	, '1999-12-31 11:59+00:00'	);

-- SQL:
-- Dates													| 0				| 1			| 2			| 3			| 4
select TZL_TEST ('select cast (cast (''1999-12-31'' as date) as varchar)				'	, '1999-12-31'			, '1999-12-31+06:00'		, '1999-12-31'		, '1999-12-31+06:00'	, '1999-12-31Z'		);
select TZL_TEST ('select cast (cast (''1999-12-31+02:00'' as date) as varchar)			'	, '1999-12-31'			, '1999-12-31+02:00'	, '1999-12-31+02:00'	, '1999-12-31+02:00'	, '1999-12-31+02:00'	);
select TZL_TEST ('select cast (cast (''1999-12-31+00:00'' as date) as varchar)			'	, '1999-12-31'			, '1999-12-31Z'		, '1999-12-31Z'		, '1999-12-31Z'		, '1999-12-31Z'		);

-- Proper dateTimes											| 0				| 1				| 2				| 3				| 4
select TZL_TEST ('select cast (cast (''1999-12-31'' as datetime) as varchar)			'	, '1999-12-31 00:00:00'		, '1999-12-31 00:00:00+06:00'		, '1999-12-31 00:00:00'		, '1999-12-31 00:00:00+06:00'	, '1999-12-31 00:00:00Z'	);
select TZL_TEST ('select cast (cast (''1999-12-31+02:00'' as datetime) as varchar)		'	, '1999-12-31 00:00:00'		, '1999-12-31 00:00:00+02:00'	, '1999-12-31 00:00:00+02:00'	, '1999-12-31 00:00:00+02:00'	, '1999-12-31 00:00:00+02:00'	);
select TZL_TEST ('select cast (cast (''1999-12-31+00:00'' as datetime) as varchar)		'	, '1999-12-31 00:00:00'		, '1999-12-31 00:00:00Z'		, '1999-12-31 00:00:00Z'		, '1999-12-31 00:00:00Z'		, '1999-12-31 00:00:00Z'	);
select TZL_TEST ('select cast (cast (''1999-12-31 11:59'' as datetime) as varchar)		'	, '1999-12-31 11:59:00'		, '1999-12-31 11:59:00+06:00'	, '1999-12-31 11:59:00'		, '1999-12-31 11:59:00+06:00'	, '1999-12-31 11:59:00Z'	);
select TZL_TEST ('select cast (cast (''1999-12-31 11:59+02:00'' as datetime) as varchar)		'	, '1999-12-31 11:59:00'		, '1999-12-31 11:59:00+02:00'	, '1999-12-31 11:59:00+02:00'	, '1999-12-31 11:59:00+02:00'	, '1999-12-31 11:59:00+02:00'	);
select TZL_TEST ('select cast (cast (''1999-12-31 11:59+00:00'' as datetime) as varchar)		'	, '1999-12-31 11:59:00'		, '1999-12-31 11:59:00Z'		, '1999-12-31 11:59:00Z'		, '1999-12-31 11:59:00Z'		, '1999-12-31 11:59:00Z'		);
select TZL_TEST ('select cast (cast (''1999-12-31 11:59-00:00'' as datetime) as varchar)		'	, '1999-12-31 11:59:00'		, '1999-12-31 11:59:00'		, '1999-12-31 11:59:00'		, '1999-12-31 11:59:00'		, '1999-12-31 11:59:00'		);


select TZL_TEST ('select cast (cast (''1999-12-31+2'' as datetime) as varchar)		'	, '1999-12-31 00:00:00'		, '1999-12-31 00:00:00+02:00'	, '1999-12-31 00:00:00+02:00'	, '1999-12-31 00:00:00+02:00'	, '1999-12-31 00:00:00+02:00'	);
select TZL_TEST ('select cast (cast (''1999-12-31+02'' as datetime) as varchar)		'	, '1999-12-31 00:00:00'		, '1999-12-31 00:00:00+02:00'	, '1999-12-31 00:00:00+02:00'	, '1999-12-31 00:00:00+02:00'	, '1999-12-31 00:00:00+02:00'	);
select TZL_TEST ('select cast (cast (''1999-12-31+200'' as datetime) as varchar)		'	, '1999-12-31 00:00:00'		, '1999-12-31 00:00:00+02:00'	, '1999-12-31 00:00:00+02:00'	, '1999-12-31 00:00:00+02:00'	, '1999-12-31 00:00:00+02:00'	);
select TZL_TEST ('select cast (cast (''1999-12-31+0200'' as datetime) as varchar)		'	, '1999-12-31 00:00:00'		, '1999-12-31 00:00:00+02:00'	, '1999-12-31 00:00:00+02:00'	, '1999-12-31 00:00:00+02:00'	, '1999-12-31 00:00:00+02:00'	);

select TZL_TEST ('select case when (is_timezoneless (cast (''1999-12-31 11:59'' as datetime))) then ''timezoneless'' else ''timezoned'' end'	, 'timezoned'		, 'timezoned'	, 'timezoneless'		, 'timezoned'	, 'timezoned'	);
select TZL_TEST ('select case when (is_timezoneless (cast (''1999-12-31 11:59+02:00'' as datetime))) then ''timezoneless'' else ''timezoned'' end'	, 'timezoned'		, 'timezoned'	, 'timezoned'	, 'timezoned'	, 'timezoned'	);
select TZL_TEST ('select case when (is_timezoneless (now())) then ''timezoneless'' else ''timezoned'' end'	, 'timezoned'		, 'timezoneless'	, 'timezoneless'	, 'timezoneless'	, 'timezoneless'	);

select TZL_TEST ('select cast (timezone (cast (''1999-12-31 11:59+02:00'' as datetime)) as varchar)		'	, '120'		, '120'	, '120'	, '120'	, '120'	);
select TZL_TEST ('select cast (forget_timezone (cast (''1999-12-31 11:59+02:00'' as datetime)) as varchar)		'	, 'Error 22023'		, '1999-12-31 11:59:00'	, '1999-12-31 11:59:00'	, '1999-12-31 11:59:00'	, '1999-12-31 11:59:00'	);
