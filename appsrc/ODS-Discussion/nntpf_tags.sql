--
--  $Id$
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

create procedure discussions_dropinvalid_tagstable()
{
    declare c_count integer;

  c_count := 0;
    SELECT count(c."COLUMN") into c_count from  "SYS_COLS" c where c."TABLE"='DB.DBA.NNTPF_TAG';
    if(c_count>2)
       nntpf_exec_no_error ('drop table NNTPF_TAG');

}
;
nntpf_exec_no_error ('discussions_dropinvalid_tagstable()')
;
nntpf_exec_no_error ('drop procedure discussions_dropinvalid_tagstable')
;

nntpf_exec_no_error (
'create table NNTPF_TAG (
                        NT_TAGS varchar,
                        NT_COUNT integer,

   primary key (NT_TAGS)
 )
')
;

create procedure discussions_dropinvalid_ngroup_post_tags_table()
{
    if(not exists(select 1 from SYS_COLS c where "TABLE"='DB.DBA.NNTPF_NGROUP_POST_TAGS' and "COLUMN"='NNPT_UID'))
       nntpf_exec_no_error ('drop table NNTPF_NGROUP_POST_TAGS');

}
;

nntpf_exec_no_error ('discussions_dropinvalid_ngroup_post_tags_table()')
;
nntpf_exec_no_error ('drop procedure discussions_dropinvalid_ngroup_post_tags_table')
;

nntpf_exec_no_error (
'create table NNTPF_NGROUP_POST_TAGS (
                        NNPT_NGROUP_ID integer,
                        NNPT_POST_ID varchar,
                        NNPT_ID integer identity,
                        NNPT_UID integer,
                        NNPT_TAGS varchar,

                      constraint FK_NNTPF_TAG_GROUPS FOREIGN KEY (NNPT_NGROUP_ID) references DB.DBA.NEWS_GROUPS (NG_GROUP) on delete cascade,
   primary key (NNPT_NGROUP_ID, NNPT_POST_ID,NNPT_UID)
 )
')
;

nntpf_exec_no_error ('create index NNTPF_TAG_POST_ID on NNTPF_NGROUP_POST_TAGS (NNPT_POST_ID)')
;


create procedure NNTPF_NGROUP_POST_TAGS_NNPT_TAGS_INDEX_HOOK(inout vtb any, inout d_id any)
{
  declare _uid any;

  declare exit handler for not found { goto nf;};
  select NNPT_UID
    into _uid
    from NNTPF_NGROUP_POST_TAGS
   where NNPT_ID = d_id;

  if (_uid is null)
    goto nf;

  vt_batch_feed(vtb, sprintf('^UID%d',_uid), 0);
  nf:
  return 0;
}
;

create procedure NNTPF_NGROUP_POST_TAGS_NNPT_TAGS_UNINDEX_HOOK(inout vtb any, inout d_id any)
{
  declare _uid any;

  declare exit handler for not found { goto nf;};
  select NNPT_UID
    into _uid
    from NNTPF_NGROUP_POST_TAGS
   where NNPT_ID = d_id;

  if(_uid is null)
    goto nf;

  vt_batch_feed(vtb, sprintf('^UID%d',_uid), 1);
  nf:
  return 0;
}
;

nntpf_exec_no_error ('CREATE TEXT INDEX ON NNTPF_NGROUP_POST_TAGS (NNPT_TAGS) WITH KEY NNPT_ID CLUSTERED WITH (NNPT_ID) USING FUNCTION LANGUAGE \'x-ViDoc\' ENCODING \'UTF-8\'');

create trigger NEWS_MULTI_MSG_D_NGROUP_POST_TAGS after delete on NEWS_MULTI_MSG referencing old as O
{
  declare exit handler for sqlstate '*' {return;};
  delete from NNTPF_NGROUP_POST_TAGS where NNPT_NGROUP_ID = O.NM_GROUP and NNPT_POST_ID = O.NM_KEY_ID;
  return;
}
;

create procedure discussions_dotag(in ngroup_id varchar, in post_id varchar, in tag varchar, in do_action varchar, in user_name varchar, in user_pass varchar )
{
  declare _uid integer;

  declare exit handler for not found { goto nf;};
  select U_ID into _uid from SYS_USERS where U_NAME=user_name and md5(U_PASSWORD)=user_pass and U_ACCOUNT_DISABLED = 0;
  discussions_dotag_int (ngroup_id,post_id,tag,do_action,_uid);

nf:
  return;
};

create procedure discussions_decode_post_id (in post_id varchar)
{
  if (not isnull (post_id))
{
    declare V any;

    V := split_and_decode (post_id);
    if (isarray (V) and length (V) > 0)
      post_id := V[0];
  }
  return decode_base64(post_id);
}
;

create procedure discussions_dotag_int (in ngroup_id varchar, in post_id varchar, in tag varchar, in do_action varchar, in _uid integer )
{
  post_id := discussions_decode_post_id (post_id);

  declare _ngroup_id integer;
  _ngroup_id:=cast(ngroup_id as integer);

  if(do_action='add')
  {
    declare inc_stat,i integer;
    declare _tags_arr any;

    inc_stat := 0;
    _tags_arr:=split_and_decode (tag, 0, '\0\0 ');

    if(not exists( select 1 from NNTPF_TAG where NT_TAGS=tag ))
       insert into NNTPF_TAG(NT_TAGS,NT_COUNT) values(tag,1);
    else
       inc_stat:=1;

    if(exists (select 1 from NNTPF_NGROUP_POST_TAGS where NNPT_NGROUP_ID=_ngroup_id and NNPT_POST_ID=post_id and NNPT_UID=_uid))
    {
      declare new_tag_cont varchar;
      declare curr_tags_arr any;
      select NNPT_TAGS into new_tag_cont from NNTPF_NGROUP_POST_TAGS where NNPT_NGROUP_ID=_ngroup_id and NNPT_POST_ID=post_id and NNPT_UID=_uid;

      curr_tags_arr:=split_and_decode (new_tag_cont, 0, '\0\0,');

      for (i := 0; i<length(_tags_arr); i := i+1)
      {
        declare _elm_pos integer;
        _elm_pos:=0;

        if( curr_tags_arr is not null)
           _elm_pos:=position (_tags_arr[i],curr_tags_arr);

        if(_elm_pos<>0 or length(trim(_tags_arr[i]))=0)
        {
             inc_stat:=0;
        } else {
             if (length(trim(new_tag_cont))=0)
                 new_tag_cont:=_tags_arr[i];
             else
                 new_tag_cont:=new_tag_cont||','||_tags_arr[i];

             update NNTPF_NGROUP_POST_TAGS set NNPT_TAGS=new_tag_cont where NNPT_NGROUP_ID=_ngroup_id and NNPT_POST_ID=post_id and NNPT_UID=_uid;
             inc_stat:=1;
        }
        if(inc_stat)
         update NNTPF_TAG set NT_COUNT=NT_COUNT+1 where NT_TAGS=_tags_arr[i];
      }
    } else {
      insert into NNTPF_NGROUP_POST_TAGS(NNPT_NGROUP_ID,NNPT_POST_ID,NNPT_UID,NNPT_TAGS) values (_ngroup_id,post_id,_uid,nntpf_implode(_tags_arr,','));
      for (i := 0; i<length(_tags_arr); i := i+1)
      update NNTPF_TAG set NT_COUNT=NT_COUNT+1 where NT_TAGS=_tags_arr[i];
      }
    }
  else if (do_action='del')
  {
    declare dec_stat integer;
    dec_stat:=0;

    if(exists(select 1 from NNTPF_NGROUP_POST_TAGS where NNPT_NGROUP_ID=_ngroup_id and NNPT_POST_ID=post_id and NNPT_UID=_uid))
    {
      declare new_tag_cont varchar;
      select NNPT_TAGS into new_tag_cont from NNTPF_NGROUP_POST_TAGS where NNPT_NGROUP_ID=_ngroup_id and NNPT_POST_ID=post_id and NNPT_UID=_uid;

      declare curr_tags_arr any;
      curr_tags_arr:=split_and_decode (new_tag_cont, 0, '\0\0,');
      declare _elm_pos integer;
      _elm_pos:=position (tag,curr_tags_arr);
      if(_elm_pos<>0)
      {
           dec_stat:=1;

           curr_tags_arr:=vector_concat(subseq(curr_tags_arr,0,_elm_pos-1),subseq(curr_tags_arr,_elm_pos ));

           new_tag_cont:=nntpf_implode(curr_tags_arr,',');

           update NNTPF_NGROUP_POST_TAGS set NNPT_TAGS=new_tag_cont where NNPT_NGROUP_ID=_ngroup_id and NNPT_POST_ID=post_id and NNPT_UID=_uid;
           dec_stat:=1;
      }
    }

    if(dec_stat)
       update NNTPF_TAG set NT_COUNT=NT_COUNT-1 where NT_TAGS=tag and NT_COUNT>0;

  }


  return;

}
;

create procedure discussions_taglist(in ngroup_id varchar, in post_id varchar, in u_id integer)
{
  post_id := discussions_decode_post_id (post_id);

    declare _ngroup_id integer;
    _ngroup_id:=cast(ngroup_id as integer);

    declare _tags varchar;
    _tags:='';

    declare exit handler for not found { goto _end; };
    select NNPT_TAGS into _tags from NNTPF_NGROUP_POST_TAGS where NNPT_NGROUP_ID=_ngroup_id and NNPT_POST_ID=post_id and NNPT_UID=u_id;

    _end:
    
      _tags:=vector(_tags,',###,',discussions_admin_taglist(ngroup_id,post_id,u_id));
    return _tags;
}
;
create procedure discussions_admin_taglist(in ngroup_id varchar, in post_id varchar, in exclude_user_id integer :=-1)
{
    declare _ngroup_id integer;
    _ngroup_id:=cast(ngroup_id as integer);

  post_id := discussions_decode_post_id (post_id);

    declare _tags,_admin_tags varchar;
    _tags:='';
  for (select NNPT_TAGS
         from NNTPF_NGROUP_POST_TAGS
        where NNPT_NGROUP_ID=_ngroup_id
          and NNPT_POST_ID=post_id
          and NNPT_UID in (select U_ID from SYS_USERS where U_GROUP in (0,3) and U_ID<> exclude_user_id)) do
    {
      if(length(NNPT_TAGS))
      {
         if(not length(_tags))
           _tags:=NNPT_TAGS;
         else
           _tags:=_tags||','||NNPT_TAGS;
      }
    }

    return _tags;
}
;


create procedure discussions_tagscount(in ngroup_id varchar, in post_id varchar, in u_id integer )
{
    declare _ngroup_id integer;

    _ngroup_id:=cast(ngroup_id as integer);

    declare tags,_tags_arr,_admin_tags_arr any;

    tags := discussions_taglist(ngroup_id,post_id,u_id);
    _tags_arr := split_and_decode (tags[0], 0, '\0\0,');
    _admin_tags_arr:=split_and_decode (tags[2], 0, '\0\0,');

    if(length(_tags_arr) or length(_admin_tags_arr))
       return length(_tags_arr)+length(_admin_tags_arr);
      return 0;
}
;

grant execute on discussions_dotag to GDATA_ODS;
grant execute on discussions_taglist to GDATA_ODS;
grant execute on discussions_tagscount to GDATA_ODS;

