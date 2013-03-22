--  
--  $Id: ttext.sql,v 1.4.10.1 2013/01/02 16:15:30 source Exp $
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2013 OpenLink Software
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




drop table tt;
create table tt (tt_id integer not null primary key, tt_file varchar, tt_text long varchar);
create text index on tt (tt_text) with key tt_id;


create procedure tt_load (in f varchar)
{
  if (exists (select 1 from tt where tt_file = f))
    update tt set tt_text = file_to_string (f) where tt_file = f;
  else
    insert into tt (tt_id, tt_file, tt_text) 
      values (sequence_next ('tt'), f, file_to_string (f));
}



select *, score from tt where contains (tt_text, 'snaap');
select *, score from tt where contains (tt_text, 'snaap');
explain ('select *, score from tt where contains (tt_text, ''snaap'')');


select count (*) from ttt_test where contains (text, 'html');
select count (*) from ttt_test where contains (text, 'body');

select count (*) from ttt_test where contains (text, '"html  body"');
select count (*) from ttt_test where contains (text, '"html  body" and "body html"');
select count (*) from ttt_test where contains (text, '"html  body" or "body html"');
select count (*) from ttt_test where contains (text, 'html and not body');
select count (*) from ttt_test where contains (text, 'html and not "html body"');

select count (*) from ttt_test where contains (text, 'graphics near user near interface');

select count (*) from ttt_test where contains (text, 'user near interface near graphical');
select count (*) from ttt_test where contains (text, 'user  near interface');
select count (*) from ttt_test where contains (text, '"user interface"');
select count (*) from ttt_test where contains (text, 'graphical and "user interface"');
select count (*) from ttt_test where contains (text, 'graphical and user near interface');
select count (*) from ttt_test where contains (text, 'graphical and user and interface');


select count (*) from ttt_test where contains (text, '"inf*"');
select count (*) from ttt_test where contains (text, '"con*"');
select count (*) from ttt_test where contains (text, '"co*"');
select count (*) from ttt_test where contains (text, '"xxxcon*"');

select count (*) from ttt_test where contains (text, '"htm*" and "bod*"', 1111);
select count (*) from ttt_test where contains (text, '"html" and "body"', 1111);

select count (*) from ttt_test where contains (text, '"con*ion"');

select count (*) from ttt_test where contains (text, '"con*ion" and not "conf*"', 1111);

