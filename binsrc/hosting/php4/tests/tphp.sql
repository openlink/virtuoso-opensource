--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2006 OpenLink Software
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

create procedure p3 ()
{
  string_to_file ('php_test_temp.php', '<?php echo abs (-1) ?>)', -2);
}
;

--select p3 ();
--echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
--echo both ": Simple POST Method test \n";


create procedure p4 ()
{
  declare res, _t any;

  res := http_get ('http://localhost:6666/p4.php', '', 'POST', 'Content-Type: application/x-www-form-urlencoded', 'a=Hello+World&b=Hello+Again+World&c=Hi+Mom');

  dbg_obj_print ('res p4 =', res);

  if (not strstr (res, 'Hello World Hello Again World Hi Mom') is NULL)
    return 1;

  return 0;

}
;

--select php_str ('<?php echo abs (-1) ?>');
--echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
--echo both ": php_str \n";

--select __http_handler_php ('php_test_temp.php');
--echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
--echo both ": __http_handler_php \n";

create procedure
get_part (in _all varchar, in m1 varchar, in m2 varchar)
{
  declare pos1, pos2 integer;

  pos1 := strstr (_all, m1);
  pos2 := strstr (_all, m2);

  if (pos2 is NULL and m1 = '--EXPECT--')
    return subseq (_all, pos1 + length (m1) + 1);

  if ((pos1 is NULL) or (pos2 is NULL))
    return 'ERR get_part';

  return subseq (_all, pos1 + length (m1) + 1, pos2);
}
;


create procedure
_get (in _all varchar, in part varchar)
{
  if (part = 'FILE')
    return get_part (_all, '--FILE--', '--EXPECT--');

  if (part = 'EXPECT')
    return get_part (_all, '--EXPECT--', NULL);

  if (part = 'TEST')
    return get_part (_all, '--TEST--', '--POST--');

  if (part = 'POST')
    return get_part (_all, '--POST--', '--GET--');

  if (part = 'GET')
    return get_part (_all, '--GET--', '--FILE--');

  return 'ERR _get (bad file)';
}
;


create procedure
main (in file_name varchar, in _mode integer)
{
  declare metod, name varchar;
  declare res integer;
  declare _to_file any;
  declare res_php any;
  declare res_exp any;
  declare _name any;
  declare _file any;
  declare _err any;
  declare post any;
  declare get any;
  declare query any;

  _file := file_to_string (file_name);
  _to_file := _get (_file, 'FILE');
  _name := _get (_file, 'TEST');

  if (_mode)
    {
      string_to_file ('php_test_temp.php', _to_file, -2);
      dbg_obj_print ('FILE   - - -');
    }

  metod := 'GET';

  post := _get (_file, 'POST');
  dbg_obj_print ('Content: ', post);
  query := _get (_file, 'GET');
  query := trim (query, '\r\n');
  dbg_obj_print ('Query: ', query);

  dbg_obj_print ('PHP_PORT =\n' , '$U{HTTPPORT}');

  if (post <> '')
    {
       metod := 'POST';
       dbg_obj_print ('metod is POST');
    }

--res_php := http_get (concat ('http://localhost:6666/', 'php_test_temp.php'), _err, metod,
--	     'Content-Type: application/x-www-form-urlencoded', post);

  if (_mode)
    {
      res_php := http_get (sprintf ('http://localhost:$U{HTTPPORT}/php_test_temp.php%s',
		     case query when '' then '' else concat ('?', query) end)
		, _err, metod,
	       'Content-Type: application/x-www-form-urlencoded', post);
    }
  else
    res_php := php_str (_to_file, post);

  res_exp := _get (_file, 'EXPECT');

--res_php := subseq (res_php, length (res_php) - 1);
  res_php := replace (res_php, '\n', '');
  res_exp := replace (res_exp, '\n', '');

  res_php := replace (res_php, '\t', '');
  res_exp := replace (res_exp, '\t', '');

  if (sys_stat('st_build_opsys_id') = 'Win32')
    {
       res_php := replace (res_php, chr (13), '');
       res_exp := replace (res_exp, chr (13), '');
    }

  res_php := trim (res_php);
  res_exp := trim (res_exp);


  RESULT_NAMES (res, name);

  _name := trim (_name, '\r\n');

  if (trim (res_php) = trim (res_exp))
    {
      RESULT (1, _name);
      END_RESULT ();
      return 1;
    }

  dbg_obj_print ('PHP_RES =\n' , res_php);
  dbg_obj_print ('PHP_EXPECT =\n' , res_exp);

  RESULT (0, _name);
  END_RESULT ();

  return 0;
}
;


select main ('php_tests/funk/001.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": funk/001 - string " $last[2] "\n";

select main ('php_tests/funk/001.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": funk/001 - file   " $last[2] "\n";


select main ('php_tests/funk/002.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": funk/002 - string " $last[2] "\n";

select main ('php_tests/funk/002.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": funk/002 - file   " $last[2] "\n";


select main ('php_tests/funk/003.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": funk/003 - string " $last[2] "\n";

select main ('php_tests/funk/003.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": funk/003 - file   " $last[2] "\n";


select main ('php_tests/funk/004.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": funk/004 - string " $last[2] "\n";

select main ('php_tests/funk/004.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": funk/004 - file   " $last[2] "\n";


--select main ('php_tests/funk/005.phpt', 0);
--echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
--echo both ": funk/005 - string " $last[2] "\n";

--select main ('php_tests/funk/005.phpt', 1);
--echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
--echo both ": funk/005 - file   " $last[2] "\n";



select main ('php_tests/basic/001.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": basic/001 - string " $last[2] "\n";

select main ('php_tests/basic/001.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": basic/001 - file   " $last[2] "\n";


select main ('php_tests/basic/002.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": basic/002 - string " $last[2] "\n";

select main ('php_tests/basic/002.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": basic/002 - file   " $last[2] "\n";


--select main ('php_tests/basic/003.phpt', 0);
--echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
--echo both ": basic/003 - string " $last[2] "\n";

select main ('php_tests/basic/003.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": basic/003 - file   " $last[2] "\n";


select main ('php_tests/basic/004.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": basic/004 - string " $last[2] "\n";

select main ('php_tests/basic/004.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": basic/004 - file   " $last[2] "\n";


select main ('php_tests/basic/005.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": basic/005 - string " $last[2] "\n";

select main ('php_tests/basic/005.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": basic/005 - file   " $last[2] "\n";


select main ('php_tests/basic/006.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": basic/006 - string " $last[2] "\n";

select main ('php_tests/basic/006.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": basic/006 - file   " $last[2] "\n";


select main ('php_tests/basic/007.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": basic/007 - string " $last[2] "\n";

select main ('php_tests/basic/007.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": basic/007 - file   " $last[2] "\n";


select main ('php_tests/basic/008.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": basic/008 - string " $last[2] "\n";

select main ('php_tests/basic/008.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": basic/008 - file   " $last[2] "\n";


select main ('php_tests/basic/009.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": basic/009 - string " $last[2] "\n";

select main ('php_tests/basic/009.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": basic/009 - file   " $last[2] "\n";


select main ('php_tests/basic/010.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": basic/010 - string " $last[2] "\n";

select main ('php_tests/basic/010.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": basic/010 - file   " $last[2] "\n";


--select main ('php_tests/basic/011.phpt', 0);
--echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
--echo both ": basic/011 - string " $last[2] "\n";

--select main ('php_tests/basic/011.phpt', 1);
--echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
--echo both ": basic/011 - file   " $last[2] "\n";




select main ('php_tests/lang/001.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/001 - string " $last[2] "\n";

select main ('php_tests/lang/001.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/001 - file   " $last[2] "\n";


select main ('php_tests/lang/002.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/002 - string " $last[2] "\n";

select main ('php_tests/lang/002.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/002 - file   " $last[2] "\n";


select main ('php_tests/lang/003.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/003 - string " $last[2] "\n";

select main ('php_tests/lang/003.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/003 - file   " $last[2] "\n";


select main ('php_tests/lang/004.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/004 - string " $last[2] "\n";

select main ('php_tests/lang/004.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/004 - file   " $last[2] "\n";


select main ('php_tests/lang/005.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/005 - string " $last[2] "\n";

select main ('php_tests/lang/005.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/005 - file   " $last[2] "\n";


select main ('php_tests/lang/006.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/006 - string " $last[2] "\n";

select main ('php_tests/lang/006.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/006 - file   " $last[2] "\n";


select main ('php_tests/lang/007.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/007 - string " $last[2] "\n";

select main ('php_tests/lang/007.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/007 - file   " $last[2] "\n";


select main ('php_tests/lang/008.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/008 - string " $last[2] "\n";

select main ('php_tests/lang/008.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/008 - file   " $last[2] "\n";


select main ('php_tests/lang/009.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/009 - string " $last[2] "\n";

select main ('php_tests/lang/009.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/009 - file   " $last[2] "\n";


select main ('php_tests/lang/010.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/010 - string " $last[2] "\n";

select main ('php_tests/lang/010.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/010 - file   " $last[2] "\n";


select main ('php_tests/lang/011.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/011 - string " $last[2] "\n";

select main ('php_tests/lang/011.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/011 - file   " $last[2] "\n";


select main ('php_tests/lang/012.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/012 - string " $last[2] "\n";

select main ('php_tests/lang/012.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/012 - file   " $last[2] "\n";


select main ('php_tests/lang/013.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/013 - string " $last[2] "\n";

select main ('php_tests/lang/013.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/013 - file   " $last[2] "\n";


select main ('php_tests/lang/014.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/014 - string " $last[2] "\n";

select main ('php_tests/lang/014.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/014 - file   " $last[2] "\n";


--select main ('php_tests/lang/015.phpt', 0);
--echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
--echo both ": lang/015 - string " $last[2] "\n";

select main ('php_tests/lang/015.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/015 - file   " $last[2] "\n";


--select main ('php_tests/lang/016.phpt', 0);
--echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
--echo both ": lang/016 - string " $last[2] "\n";

select main ('php_tests/lang/016.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/016 - file   " $last[2] "\n";


select main ('php_tests/lang/017.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/017 - string " $last[2] "\n";

select main ('php_tests/lang/017.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/017 - file   " $last[2] "\n";


select main ('php_tests/lang/018.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/018 - string " $last[2] "\n";

select main ('php_tests/lang/018.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/018 - file   " $last[2] "\n";


select main ('php_tests/lang/019.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/019 - string " $last[2] "\n";

select main ('php_tests/lang/019.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/019 - file   " $last[2] "\n";


select main ('php_tests/lang/020.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/020 - string " $last[2] "\n";

select main ('php_tests/lang/020.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/020 - file   " $last[2] "\n";


select main ('php_tests/lang/021.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/021 - string " $last[2] "\n";

select main ('php_tests/lang/021.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/021 - file   " $last[2] "\n";


select main ('php_tests/lang/022.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/022 - string " $last[2] "\n";

select main ('php_tests/lang/022.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/022 - file   " $last[2] "\n";


--select main ('php_tests/lang/023.phpt', 0);
--echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
--echo both ": lang/023 - string " $last[2] "\n";

select main ('php_tests/lang/023.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/023 - file   " $last[2] "\n";


--select main ('php_tests/lang/024.phpt', 0);
--echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
--echo both ": lang/024 - string " $last[2] "\n";

select main ('php_tests/lang/024.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/024 - file   " $last[2] "\n";


select main ('php_tests/lang/025.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/025 - string " $last[2] "\n";

select main ('php_tests/lang/025.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/025 - file   " $last[2] "\n";


select main ('php_tests/lang/026.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/026 - string " $last[2] "\n";

select main ('php_tests/lang/026.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/026 - file   " $last[2] "\n";


select main ('php_tests/lang/027.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/027 - string " $last[2] "\n";

select main ('php_tests/lang/027.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/027 - file   " $last[2] "\n";


select main ('php_tests/lang/028.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/028 - string " $last[2] "\n";

select main ('php_tests/lang/028.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/028 - file   " $last[2] "\n";


--select main ('php_tests/lang/029.phpt', 0);
--echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
--echo both ": lang/029 - string " $last[2] "\n";

--select main ('php_tests/lang/029.phpt', 1);
--echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
--echo both ": lang/029 - file   " $last[2] "\n";


select main ('php_tests/lang/030.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/030 - string " $last[2] "\n";

select main ('php_tests/lang/030.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": lang/030 - file   " $last[2] "\n";




select main ('php_tests/classes/class_example.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": classes/class_example  - string " $last[2] "\n";

select main ('php_tests/classes/class_example.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": classes/class_example  - file   " $last[2] "\n";


select main ('php_tests/classes/inheritance.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": classes/inheritance  - string " $last[2] "\n";

select main ('php_tests/classes/inheritance.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": classes/inheritance - file   " $last[2] "\n";



select main ('php_tests/strings/001.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": strings/001 - string " $last[2] "\n";

select main ('php_tests/strings/001.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": strings/001 - file   " $last[2] "\n";


select main ('php_tests/strings/002.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": strings/002 - string " $last[2] "\n";

select main ('php_tests/strings/002.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": strings/002 - file   " $last[2] "\n";


select main ('php_tests/strings/003.phpt', 0);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": strings/003 - string " $last[2] "\n";

select main ('php_tests/strings/003.phpt', 1);
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": strings/003 - file   " $last[2] "\n";
