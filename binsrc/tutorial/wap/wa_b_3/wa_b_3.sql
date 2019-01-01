--  
--  $Id$
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
create table wapfolders
(	wap_active INTEGER default 1,
	wap_folder VARCHAR (50),
	wap_folder_parent VARCHAR (50),
	wap_username VARCHAR (50),
	primary key (wap_username, wap_folder)
);


create table wapsetting
(	_country VARCHAR (50),
	_display_cols INTEGER default 0,
	_display_rows INTEGER default 0,
	_fname VARCHAR (50),
	_lname VARCHAR (50),
	_msg_size_to_read INTEGER default 500,
	_num_msg_to_list INTEGER default 10,
	_phone_model VARCHAR (50),
	_pop3_allowed INTEGER default 1,
	_return_email VARCHAR (50),
	_sign_up_date VARCHAR (50),
	_state VARCHAR (30),
	_tel VARCHAR (30),
	_username VARCHAR (50),
	primary key (_username)
);


create table wapsession
(
_sess_bm_folder VARCHAR,
_sess_err_msg VARCHAR,
_sess_folder VARCHAR,
_sess_list INTEGER,
_sess_msg_id INTEGER,
_sess_offset INTEGER,
_sess_page INTEGER ,
_time LONG VARCHAR,
_username VARCHAR,
_userpass VARCHAR,
_time_last_active varchar default '',
 sid VARCHAR, primary key (sid)
);


create table mailpwd
(
_enabled INTEGER default 1,
_username VARCHAR,
_userpass VARCHAR,
_allow_multiple_session integer default 0,
primary key (_username)
);


create table wappop3account
(	_pop_desc VARCHAR (30),
	_pop_id INTEGER default 1,
	_pop_login_name VARCHAR (50),
	_pop_password VARCHAR (30) ,
	_pop_port VARCHAR default '110',
	_pop_server VARCHAR (50),
	_username VARCHAR (50),
	primary key (_username, _pop_server, _pop_login_name)
);

create table MAIL_STAGING
(	ST_INDEX INTEGER default 1,
	ST_MM_BODY LONG VARCHAR,
	ST_MM_OWN VARCHAR (50),
	primary key (ST_MM_OWN, ST_INDEX)
);

create table wapaddresses
(	_email_address VARCHAR ,
	_email_desc VARCHAR,
	_username VARCHAR,
	primary key (_username, _email_address)
);

create procedure
split_string_return_array(in i_the_string varchar, in i_search_for varchar)
{
        declare   _the_string,  _search_for varchar;
        declare start_post, location integer;
        declare keep_going, str123 varchar;
        declare arr_1 any;
        start_post := 1;
        keep_going := 'YES';
        _the_string := i_the_string;
        _search_for := i_search_for;
        arr_1 := vector();
        if ((locate(_search_for, _the_string, 1)) > 0)
        {
                while(keep_going = 'YES')
                {
                        location := locate(_search_for, _the_string, start_post);
                        if (location > 0)
                        {
                                str123 := trim(substring(_the_string, start_post, (location - start_post)));
                                start_post := location + 1;
                                location := 0;
                                arr_1 := vector_concat(arr_1, vector(str123));
                        }
                        else
                        {
                                str123 := trim(substring(_the_string, start_post, length(_the_string)));
                                keep_going := 'NO';
                                arr_1 := vector_concat(arr_1, vector(str123));
                        }
                }
                return (arr_1);
        }else{
                return (vector(_the_string));
        }
};

