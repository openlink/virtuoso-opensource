--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2015 OpenLink Software
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

wa_exec_no_error('create table tag_rule_set
(
  trs_name varchar,
  trs_id integer identity,
  trs_owner integer references db.dba.sys_users (u_id) on delete cascade,
  trs_is_public integer,
  trs_apc_id int,
  trs_aps_id int,
  primary key (trs_id)
)');

wa_exec_no_error('create unique index trs_owner on tag_rule_set (trs_owner, trs_name)');

wa_exec_no_error('create table tag_rules
(
  rs_trs integer references tag_rule_set (trs_id) on delete cascade,
  rs_query varchar,
  rs_tag varchar,
  rs_is_phrase integer,
  primary key (rs_trs, rs_query, rs_tag)
)');

wa_exec_no_error('create table tag_user
(
  tu_u_id integer references db.dba.sys_users (u_id),
  tu_trs integer references tag_rule_set (trs_id) on delete cascade,
  tu_order integer,
  primary key (tu_u_id, tu_trs, tu_order)
)');


wa_exec_no_error('
create table WA_TAG_REL (
	TR_T1 varchar,
	TR_T2 varchar,
	TR_COUNT int,
	primary key (TR_T1, TR_T2)
)')
;

wa_exec_no_error('
create table WA_TAG_REL_INX (
	TR_T1 varchar,
	TR_T2 varchar,
	TR_COUNT int,
	primary key (TR_T1, TR_COUNT, TR_T2)
)')
;

wa_exec_no_error('
create unique index WA_TAG_REL_INX_REV on WA_TAG_REL_INX (TR_T2, TR_COUNT, TR_T1)
')
;

db.dba.wa_exec_ddl ('create table moat.DBA.moat_meanings
   (
     m_mid  integer identity,
     m_tag  varchar,
     m_inst int,
     m_id   int,
     m_iri  iri_id,
     m_uri  varchar,
     primary key (m_inst, m_id, m_tag, m_uri)
)');

db.dba.wa_exec_ddl ('create index moat_meanings_idx on moat.DBA.moat_meanings (m_tag, m_iri)');

db.dba.wa_add_col ('moat.DBA.moat_meanings', 'm_iri', 'iri_id');
db.dba.wa_add_col ('moat.DBA.moat_meanings', 'm_mid', 'integer identity');

db.dba.wa_exec_ddl (
'create table moat.DBA.moat_user_meanings
  (
    mu_id integer identity,
    mu_tag varchar,
    mu_trs_id int,
    mu_url varchar,
    primary key (mu_trs_id, mu_tag, mu_url)
  )
create unique index moat_user_meanings_id on moat.DBA.moat_user_meanings (mu_id)');


create trigger tag_rules_u after update on DB.DBA.tag_rules referencing old as O, new as N
{
  if (not exists (select 1 from moat.DBA.moat_user_meanings where mu_trs_id = O.rs_trs and mu_tag = N.rs_tag))
    update moat.DBA.moat_user_meanings set mu_tag = N.rs_tag where mu_trs_id = O.rs_trs and mu_tag = O.rs_tag;
}
;

create trigger tag_rules_d after delete on DB.DBA.tag_rules referencing old as O
{
  delete from moat.DBA.moat_user_meanings where mu_trs_id = O.rs_trs and mu_tag = O.rs_tag;
}
;

-- A dummy table is created for holding taggable content.  Then a text trigger is created on this table.  In fact the text trigger rules will be invoked without recourse to the table or its triggers.

wa_exec_no_error('create table tag_content (tc_id int identity primary key, tc_text long varchar)');

wa_exec_no_error('create text index on tag_content (tc_text) with key  tc_id encoding \'UTF-8\'');

wa_exec_no_error('create text trigger on tag_content (tc_text)');

wa_add_col ('db.dba.tag_content_tc_text_query', 'tt_tag_set', 'int');
wa_add_col ('db.dba.tag_content_tc_text_query', 'tt_is_phrase', 'int');


create trigger tag_rule_set_d after delete on tag_rule_set
{
  delete from sys_ann_phrase where AP_APS_ID = trs_id;
  delete from sys_ann_phrase_set where APS_ID = trs_id;
}
;

-- tt_cd contains the tag implied by the text condition.

create trigger tag_content_tc_text_query_i after insert on tag_content_tc_text_query
referencing new as N
{
  declare cd, id, word any;

  cd := deserialize (N.TT_CD);
  if (not isarray (cd) or length (cd) < 3)
    return;

  id := N.TT_ID;
  word := N.TT_WORD;
  update tag_content_tc_text_query set tt_cd = cd[1], tt_tag_set = cd[0], tt_is_phrase = cd[2]
      where tt_word = word and tt_id = id;
};

create trigger tag_content_i instead of insert on tag_content order 100
{
  --dbg_obj_print ('tc_id', tc_id);
  return;
}
;


create trigger tag_content_tc_text_words_i instead of insert on tag_content_tc_text_words
{
  return;
};


create trigger tag_content_tc_text_hit_i instead of insert on tag_content_tc_text_hit order 100
{
  return;
}
;


create procedure user_tag_rules (in u_id int) returns int array
{
  declare ret any;
  ret := vector ();
  for select trs_id, trs_aps_id from tag_rule_set, tag_user where tu_trs = trs_id and tu_u_id = u_id order by tu_order do
    {
      ret := vector_concat (ret, vector (vector (trs_id, trs_aps_id)));
    }
  return ret;
}
;

create procedure tag_phrase_eval (in trs_id int, in text varchar, inout tags any)
{
  declare ap, tag_inx, tag any;
  ap := ap_build_match_list (vector (trs_id), text, 'x-any', 0, 0);
  --dbg_obj_print ('ap[2]:', ap[2]);
  --dbg_obj_print ('ap[5]:', ap[5]);

  foreach (any ht in ap[5]) do
    {
      declare pos int;
      tag_inx := ht[2];
      tag := ap[2][tag_inx][3];
      pos := position (tag, tags);
      if (pos)
	{
	  tags[pos] := tags[pos] + 1;
	}
      else
	{
	  tags := vector_concat (tags, vector (tag, 1));
	}
    }

  return;
};

create procedure tag_tt_eval (in trs_id int, in text varchar, inout tags any)
{
  declare vtb, ids, invd any;
  declare d_id, pos int;

  vtb := vt_batch (1001);
  vt_batch_d_id (vtb, 1);
  vt_batch_feed (vtb, text, 0);
  invd := vt_batch_strings_array (vtb);
  for select rs_query, rs_tag from tag_rules where rs_is_phrase <> 1 and rs_trs = trs_id do
    {
      ids := vt_batch_match (vtb, rs_query);
      --dbg_obj_print ('ids=',ids, ' for=', rs_query);
      if (length (ids))
	{
	  pos := position (rs_tag, tags);
	  if (pos)
	    {
	      tags[pos] := tags[pos] + 1;
	    }
	  else
	    {
	      tags := vector_concat (tags, vector (rs_tag, 1));
	    }
	}
    }
  return;
};

create procedure tag_document (in text varchar, in top_n int, in rule_sets int array) returns any array
{
  declare tags, rc any;
  tags := vector ();
  foreach (any trs in rule_sets) do
    {
      tag_phrase_eval (trs[1], blob_to_string (text), tags);
      tag_tt_eval (trs[0], text, tags);
      if (top_n > 0 and (length (tags)/2) >= top_n)
	goto ret;
    }
  ret:
  return tags;
};

create procedure tag_html (in tags any array, in link_string varchar) returns varchar
{
  -- link string: <li><a href="app.domain.com/tag_query/%s">%s</a></li>
  declare s any;
  declare i int;

  s := string_output ();
  for (i := 0; i < length (tags); i := i + 2)
    {
      http (sprintf (link_string, tags[i], tags[i]), s);
    }
  return string_output_string (s);
}
;

-- with moat
create procedure tag_phrase_eval_moat (in trs_id int, in text varchar, inout tags any)
{
  declare ap, tag_inx, tag, moat any;
  ap := ap_build_match_list (vector (trs_id), text, 'x-any', 0, 0);
  --dbg_obj_print ('ap[2]:', ap[2]);
  --dbg_obj_print ('ap[5]:', ap[5]);

  foreach (any ht in ap[5]) do
    {
      declare pos int;
      tag_inx := ht[2];
      tag := ap[2][tag_inx][3];
      pos := position (tag, tags);
      if (not pos)
	{
	  moat := (select vector_agg (mu_url) from moat..moat_user_meanings where mu_tag = tag and mu_trs_id = trs_id);
	  tags := vector_concat (tags, vector (tag, moat));
	}
    }

  return;
};

create procedure tag_tt_eval_moat (in trs_id int, in text varchar, inout tags any)
{
  declare vtb, ids, invd any;
  declare d_id, pos int;
  declare moat any;

  vtb := vt_batch (1001);
  vt_batch_d_id (vtb, 1);
  vt_batch_feed (vtb, text, 0);
  invd := vt_batch_strings_array (vtb);
  for select rs_query, rs_tag from tag_rules where rs_is_phrase <> 1 and rs_trs = trs_id do
    {
      ids := vt_batch_match (vtb, rs_query);
      --dbg_obj_print ('ids=',ids, ' for=', rs_query);
      if (length (ids))
	{
	  pos := position (rs_tag, tags);
	  if (not pos)
	    {
	      moat := (select vector_agg (mu_url) from moat..moat_user_meanings where mu_tag = rs_tag and mu_trs_id = trs_id);
	      tags := vector_concat (tags, vector (rs_tag, moat));
	    }
	}
    }
  return;
};

create procedure tag_document_with_moat (in text varchar, in top_n int, in rule_sets int array) returns any array
{
  declare tags, rc any;
  tags := vector ();
  foreach (any trs in rule_sets) do
    {
      tag_phrase_eval_moat (trs[1], blob_to_string (text), tags);
      tag_tt_eval_moat (trs[0], text, tags);
      if (top_n > 0 and (length (tags)/2) >= top_n)
	goto ret;
    }
  ret:
  return tags;
};


wa_exec_no_error('
create table TF_REPORT_DELTA (
	TFD_ID int,
	TFD_TAG varchar,
	TFD_DELTA int,
	primary key (TFD_ID, TFD_TAG))');

wa_exec_no_error('
create table TF_REPORT (
	TF_ID int,
	TF_TAG varchar,
	TF_COUNT int,
        TF_COUNT_INX int,
	primary key (TF_ID, TF_TAG))');

wa_exec_no_error('
create table TF_REPORT_SET (
	TFS_USER int,
	TFS_TIME datetime,
	TFS_ID int,
	primary key (TFS_USER, TFS_TIME))');


create procedure wa_get_last_tf_id ()
{
  declare ret int;

  if (exists (select 1 from TF_REPORT))
    select top 1 TF_ID into ret from TF_REPORT order by TF_ID desc;
  else
    ret := 1;

  return ret;
}
;

create procedure wa_get_last_tfd_id ()
{
  declare ret int;

  if (exists (select 1 from TF_REPORT))
    select top 1 TF_ID into ret from TF_REPORT order by TF_ID desc;
  else
    ret := 1;

  return ret;
}
;

create procedure wa_collect_all_tags ()   -- TOP PROCEDURE
{
   declare _id int;

   _id := wa_get_last_tf_id ();
   _id := _id + 1;

   if (wa_check_package ('enews2'))
     wa_collect_enews_tags (_id);

   if (wa_check_package ('oDrive'))
     wa_collect_odrive_tags (_id);

--   if (wa_check_package ('webmail'))
--     collect_webmail_tags (_id);

   if (wa_check_package ('blog2'))
     wa_collect_blog_tags (_id);

   if (wa_check_package ('Bookmarks'))
     wa_collect_bmk_tags (_id);

--  delete from TF_REPORT where TF_COUNT = 0;
  update TF_REPORT set TF_COUNT_INX = TF_COUNT where TF_ID = _id;
  insert into TF_REPORT_SET (TFS_USER, TFS_TIME, TFS_ID) values (0, now (), _id);

  wa_tag_frecuency ();
  wa_collect_all_rel_tags ();

}
;



create procedure wa_add_tag_to_count (in tag_str varchar, in id int)
{

  declare tags_arr any;

  tags_arr := split_and_decode(trim(tag_str, ','), 0, '\0\0,');

  foreach (any tag in tags_arr) do
    {
      tag := trim (tag);
      if (exists (select 1 from TF_REPORT where TF_TAG = tag and TF_ID = id))
	update TF_REPORT set TF_COUNT = TF_COUNT + 1 where TF_TAG = tag and TF_ID =  id;
      else
	insert into TF_REPORT (TF_ID, TF_TAG, TF_COUNT) values (id, tag, 1);
    }

  commit work;
}
;


-- move to exec
wa_exec_no_error('
create procedure wa_collect_blog_tags (in id int)
{
   for (select BT_TAGS from BLOG..BLOG_TAG) do
	wa_add_tag_to_count (BT_TAGS, id);
}
');

-- CHECK FOR PUBLIC
wa_exec_no_error('
create procedure wa_collect_odrive_tags (in id int)
{
   for (select DT_TAGS from WS.WS.SYS_DAV_TAG) do
	wa_add_tag_to_count (DT_TAGS, id);
}
');


-- move to exec
wa_exec_no_error('
create procedure wa_collect_enews_tags (in id int)
{

  declare tags any;
  declare idx, len int;
  declare tag varchar;

  for (select EFI_ID,
   	    EFD_DOMAIN_ID,
   	    EFID_ACCOUNT_ID
          from ENEWS.WA.FEED_ITEM
            join ENEWS.WA.FEED on EF_ID = EFI_FEED_ID
              left join ENEWS.WA.FEED_ITEM_DATA on EFID_ITEM_ID = EFI_ID
                left join ENEWS.WA.FEED_DOMAIN on EFD_FEED_ID = EF_ID) do
    {
	tags := ENEWS.WA.tags_account_item_select(EFD_DOMAIN_ID, EFID_ACCOUNT_ID, EFI_ID);
	wa_add_tag_to_count (tags, id);
    }
  return;
}
');

wa_exec_no_error('
create procedure wa_collect_bmk_tags (in id int)
{
   for (select BD_TAGS from BMK.WA.BOOKMARK_DOMAIN) do
	wa_add_tag_to_count (BD_TAGS, id);
}
');


create procedure  wa_tag_frecuency ()
{
   declare new_id, old_id int;

   new_id := wa_get_last_tf_id ();
   old_id := new_id - 1;

   wa_tag_frecuency_int (new_id, old_id);

   -- delete from TF_REPORT where TF_ID := old_id - 1;
}
;

create procedure  wa_tag_frecuency_int (in new_id int, in old_id int)
{
   declare n_tf_id, o_tf_id, tfd_id int;
   declare n_tf_tag, o_tf_tag varchar;
   declare n_tf_count, o_tf_count int;

   --dbg_obj_print ('new_id = ', new_id);
   --dbg_obj_print ('old_id = ', old_id);
   tfd_id := wa_get_last_tfd_id ();

   declare new_tags cursor for select TF_ID, TF_TAG, TF_COUNT from TF_REPORT where TF_ID = new_id order by TF_TAG;
   declare old_tags cursor for select TF_ID, TF_TAG, TF_COUNT from TF_REPORT where TF_ID = old_id order by TF_TAG;

   open new_tags (exclusive);
   open old_tags (exclusive);

   whenever not found goto _end;

   fetch new_tags into n_tf_id, n_tf_tag, n_tf_count;
   fetch old_tags into o_tf_id, o_tf_tag, o_tf_count;

MAIN_LOOP:

   if (n_tf_tag = o_tf_tag)
     {
	insert into TF_REPORT_DELTA (TFD_ID, TFD_TAG, TFD_DELTA) values (tfd_id, n_tf_tag, n_tf_count - o_tf_count);
        fetch new_tags into n_tf_id, n_tf_tag, n_tf_count;
        fetch old_tags into o_tf_id, o_tf_tag, o_tf_count;
   --dbg_obj_print (' n_tf_tag = o_tf_tag ', n_tf_tag);
	goto MAIN_LOOP;
     }

   if (n_tf_tag < o_tf_tag)
     {
	insert into TF_REPORT_DELTA (TFD_ID, TFD_TAG, TFD_DELTA) values (tfd_id, n_tf_tag, n_tf_count);
   --dbg_obj_print (' n_tf_tag < o_tf_tag ', n_tf_tag , ' ', o_tf_tag);
        fetch new_tags into n_tf_id, n_tf_tag, n_tf_count;
	goto MAIN_LOOP;
     }

   --dbg_obj_print (' ELSE ', n_tf_tag, ' ', o_tf_tag);
   insert into TF_REPORT_DELTA (TFD_ID, TFD_TAG, TFD_DELTA) values (tfd_id, o_tf_tag, o_tf_count - n_tf_count);
   fetch old_tags into o_tf_id, o_tf_tag, o_tf_count;
   goto MAIN_LOOP;


_end:
   close new_tags;
   close old_tags;

}
;

insert soft DB.DBA.SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_SQL, SE_INTERVAL)
   values ('WA_COLLECT_SITE_TAGS', cast (stringtime ('0:0') as DATETIME), concat ('wa_collect_all_tags ()'), 60*24)
;


create procedure wa_collect_all_rel_tags ()   -- TOP PROCEDURE
{
   delete from WA_TAG_REL;

   if (wa_check_package ('enews2'))
     collect_enews_rel_tags ();

   if (wa_check_package ('oDrive'))
     collect_odrive_rel_tags ();

--   if (wa_check_package ('webmail'))
--     collect_webmail_rel_tags (_id);

   if (wa_check_package ('blog2'))
     collect_blog_rel_tags ();

  log_enable (0, 1);
  delete from WA_TAG_REL_INX;
  insert into WA_TAG_REL_INX (TR_T1, TR_T2, TR_COUNT) select TR_T1, TR_T2, TR_COUNT from WA_TAG_REL;
  log_enable (1);

}
;


create procedure wa_add_rel_tag (in tag_1 varchar, in tag_2 varchar)
{
   if (exists (select 1 from WA_TAG_REL where TR_T1 = tag_1 and TR_T2 = tag_2))
     update WA_TAG_REL set TR_COUNT = TR_COUNT + 1 where TR_T1 = tag_1 and TR_T2 = tag_2;
   else
     insert into WA_TAG_REL (TR_T1, TR_T2, TR_COUNT) values (tag_1, tag_2, 1);
}
;

create procedure add_tag_to_rel_count (in list any)
{
   declare idx, idx_2, len int;

   len := length(list) - 1;

   if (len < 1) return;

   for (idx := 0; idx < len; idx := idx + 1)
      {
	 for (idx_2 := idx + 1; idx_2 <= len; idx_2 := idx_2 + 1)
	     wa_add_rel_tag (list[idx], list [idx_2]);
      }
}
;


wa_exec_no_error('
create procedure collect_enews_rel_tags ()
{
  declare tags any;

  for (select EFI_ID,
   	    EFD_DOMAIN_ID,
   	    EFID_ACCOUNT_ID
          from ENEWS.WA.FEED_ITEM
            join ENEWS.WA.FEED on EF_ID = EFI_FEED_ID
              left join ENEWS.WA.FEED_ITEM_DATA on EFID_ITEM_ID = EFI_ID
                left join ENEWS.WA.FEED_DOMAIN on EFD_FEED_ID = EF_ID) do
    {
	tags := ENEWS.WA.tags_account_item_select(EFD_DOMAIN_ID, EFID_ACCOUNT_ID, EFI_ID);
	tags := ENEWS.WA.tags2vector (tags);
	if (tags is not NULL)
	  add_tag_to_rel_count (__vector_sort (tags));
    }

  return;
}
');

wa_exec_no_error('
create procedure collect_odrive_rel_tags ()
{
  declare tags any;

  for (select DT_TAGS from WS.WS.SYS_DAV_TAG where DT_U_ID = http_nobody_uid ()) do
     {
	tags := split_and_decode (DT_TAGS, 0, \'\\0\\0,\');
	add_tag_to_rel_count (__vector_sort (tags));
     }

  return;
}
');


wa_exec_no_error('
create procedure collect_blog_rel_tags ()
{
  declare tags any;

  for (select BT_TAGS from BLOG..BLOG_TAG) do
     {
	tags := split_and_decode (BT_TAGS, 0, \'\\0\\0,\');
	add_tag_to_rel_count (__vector_sort (tags));
     }

  return;
}
');


-------------------------------------------------------------------------------
--
create procedure ODS.WA.tag_style (
  inout tagCount integer,
  inout tagMinCount integer,
  inout tagMaxCount integer,
  in fontMinSize integer := 12,
  in fontMaxSize integer := 30)
{
  declare fontSize, fontPercent float;
  declare tagStyle any;

  if (tagMaxCount = tagMinCount) {
    fontPercent := 0;
  } else {
    fontPercent := (1.0 * tagCount - tagMinCount) / (tagMaxCount - tagMinCount);
  }
  fontSize := fontMinSize + ((fontMaxSize - fontMinSize) * fontPercent);
  tagStyle := sprintf ('font-size: %dpx;', fontSize);
  if (fontPercent > 0.6)
    tagStyle := tagStyle || ' font-weight: bold;';

  if (fontPercent > 0.8)
    tagStyle := tagStyle || ' color: #9900CC;';
  else if (fontPercent > 0.6)
    tagStyle := tagStyle || ' color: #339933;';
  else if (fontPercent > 0.4)
    tagStyle := tagStyle || ' color: #CC3333;';
  else if (fontPercent > 0.2)
    tagStyle := tagStyle || ' color: #66CC99;';
  return tagStyle;
}
;

--insert soft DB.DBA.SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_SQL, SE_INTERVAL)
--   values ('WA_COLLECT_SITE_REL_TAGS', stringtime ('1:0'), concat ('wa_collect_all_rel_tags ()'), 60*24)
--;

