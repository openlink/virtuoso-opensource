--
--  vt_text.sql
--
--  $Id$
--
--  Text triggers support.
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
--
--

create procedure DB.DBA.execstmt (in stmt varchar, out stat varchar, out msg varchar)
{
  stat := '00000';
  exec (stmt, stat, msg, vector (), 0, null, null);
  if (stat <> '00000')
    {
      return 1;
    }
  return 0;
}
;

create procedure DB.DBA.vt_create_ftt (in tb varchar, in id varchar, in dbcol varchar, in is_intr integer)
{
  declare stmt, stat, msg, verr varchar;
  declare tbn0, tbn1, tbn2, data_table_suffix, theuser varchar;
--  tb := complete_table_name (fix_identifier_case (tb), 1);
  verr := '';
  tb := complete_table_name ((tb), 1);
  tbn0 := name_part (tb, 0);
  tbn1 := name_part (tb, 1);
  tbn2 := name_part (tb, 2);
  data_table_suffix := concat (tbn0, '_', tbn1, '_', tbn2);
  data_table_suffix := DB.DBA.SYS_ALFANUM_NAME (replace (data_table_suffix, ' ', '_'));
  theuser := user;
  if (theuser = 'dba') theuser := 'DBA';

  if (not exists (select 1 from DB.DBA.SYS_VT_INDEX where 0 = casemode_strcmp (VI_TABLE,  tb)))
    {
      verr := 'FT035';
      stat := '42S02';
      msg := sprintf ('Text index should be enabled for the table "%s"', tb);
      goto err;
    }

  if (not isstring (id))
    select VI_ID_COL into id from DB.DBA.SYS_VT_INDEX where 0 = casemode_strcmp (VI_TABLE,  tb);

  if (not isstring (dbcol))
    select VI_COL into dbcol from DB.DBA.SYS_VT_INDEX where 0 = casemode_strcmp (VI_TABLE,  tb);

  if (not exists (select 1 from DB.DBA.SYS_COLS where "TABLE" = tb and "COLUMN" = id))
    {
      stat := '42S22';
      verr := 'FT036';
      msg := sprintf ('The id column "%s" does not exist in table "%s" definition', id, tb);
      goto err;
    }

  if (not exists (select 1 from DB.DBA.SYS_COLS where "TABLE" = tb and "COLUMN" = dbcol))
    {
      stat := '42S22';
      verr := 'FT037';
      msg := sprintf ('The data column "%s" does not exist in table "%s" definition', dbcol, tb);
      goto err;
    }

  -- prevent making of error messages if creation is internal
  if (is_intr = 2 and exists (select 1 from DB.DBA.SYS_KEYS
	where KEY_TABLE = sprintf ('%s.%s.%s_%s_QUERY', tbn0, tbn1, tbn2, dbcol)))
    return;

  -- Upgrade an old database
  if (not exists
      (select 1 from DB.DBA.SYS_PROCEDURES where P_NAME = sprintf ('%I.%I.VT_HITS_%I', tbn0, tbn1, tbn2)))
    {
      stmt := concat (
	  sprintf (
	    'create procedure "%I"."%I"."VT_BATCH_PROCESS_%s" (inout vtb any, in doc_id int) {\n',tbn0, tbn1, data_table_suffix),
	      'declare invd any;\n
	       invd := vt_batch_strings_array (vtb);\n
	       if (length (invd) < 1) return;\n',
	      sprintf ('"%I"."%I"."VT_HITS_%I" (vtb, invd);\n', tbn0, tbn1, tbn2),
	  sprintf (
	    'log_text (''"%I"."%I"."VT_BATCH_REAL_PROCESS_%s" (?, ?)'', invd, doc_id);\n', tbn0, tbn1, data_table_suffix),
	    'log_enable (0);\n',
	  sprintf (
	    '"%I"."%I"."VT_BATCH_REAL_PROCESS_%s" (invd, doc_id);\n',tbn0, tbn1, data_table_suffix),
	    'log_enable (1);}\n');
      DB.DBA.execstr (stmt);
    }

  -- Tables definition
  stmt := sprintf ('CREATE TABLE "%I"."%I"."%I"
	                     (TT_WORD VARCHAR, TT_ID INTEGER, TT_QUERY VARCHAR, TT_CD VARCHAR,
			      TT_COMMENT VARCHAR, TT_XPATH VARCHAR, TT_PREDICATE VARCHAR,
			     PRIMARY KEY (TT_WORD, TT_ID))',
		    tbn0, tbn1, concat (tbn2, '_', dbcol, '_QUERY'));
  if (DB.DBA.execstmt (stmt, stat, msg))
    goto err;
  stmt := sprintf ('CREATE TABLE "%I"."%I"."%I"
	                     (TTU_T_ID INTEGER, TTU_U_ID INTEGER, TTU_NOTIFY VARCHAR, TTU_COMMENT VARCHAR,
			     PRIMARY KEY (TTU_T_ID, TTU_U_ID))',
		    tbn0, tbn1, concat (tbn2, '_', dbcol, '_USER'));

  if (DB.DBA.execstmt (stmt, stat, msg))
    goto err;
  stmt := sprintf ('CREATE TABLE "%I"."%I"."%I"
	                     (TTH_U_ID INTEGER, TTH_D_ID any, TTH_T_ID INTEGER, TTH_TITLE VARCHAR,
			      TTH_URL VARCHAR, TTH_TS TIMESTAMP, TTH_NOTIFY VARCHAR,
			     PRIMARY KEY (TTH_U_ID, TTH_TS, TTH_D_ID, TTH_T_ID))',
		    tbn0, tbn1, concat (tbn2, '_', dbcol, '_HIT'));
  if (DB.DBA.execstmt (stmt, stat, msg))
    goto err;

  -- Trigger definition
  stmt := sprintf ('CREATE TRIGGER "%I_FTT_D" AFTER DELETE ON "%I"."%I"."%I" ORDER 3 %s
	            DELETE FROM "%I"."%I"."%I_%I_HIT" WHERE TTH_D_ID = "%I"; %s',
		        tbn2, tbn0, tbn1, tbn2, '{', tbn0, tbn1, tbn2, dbcol, id, '}');

  -- Procedures definition
  if (DB.DBA.execstmt (stmt, stat, msg))
    goto err;
  stmt := concat ( sprintf ('create procedure "%I"."%I"."VT_HITS_%I"', tbn0, tbn1, tbn2), '(inout vtb any, inout strs any)
	    {
	      declare tried, hits, doc_id, u_id integer;
	      declare len, inx int;
              inx := 0;len := length (strs);tried := 0;',
	      sprintf ('if (registry_get (''tt_%s_%s_%s'') = ''OFF'') return;', tbn0, tbn1, tbn2),
	      'while (inx < len)
		{
		  for select TT_ID, TT_QUERY, TT_COMMENT, TT_CD, TT_XPATH from ',
		  sprintf ('"%I"."%I"."%I"', tbn0, tbn1, concat(tbn2, '_', dbcol, '_QUERY')), '
		    where TT_WORD = aref (strs, inx) do
		      {
			declare ids, ntf, xp any;
			tried := tried + 1;
			declare ii, is_xp int;
                        is_xp := 0;
			if (TT_XPATH is not null and TT_XPATH <> '''')
			  {
			    xp := deserialize (TT_QUERY);
			    ids := vt_batch_match (vtb, xp);
                            is_xp := 1;
			  }
			else
			  ids := vt_batch_match (vtb, TT_QUERY);
			hits := hits + length (ids);
			ii := 0;',
			sprintf ('select TTU_NOTIFY, TTU_U_ID into ntf, u_id from "%I"."%I"."%I_%I_USER" where TTU_T_ID = TT_ID;', tbn0, tbn1, tbn2, dbcol),
			'while (ii < length (ids))
			{
			  doc_id := aref (ids, ii);
			  if (<INSERT_COND>)
			    {
			      ', sprintf ('if ((is_xp = 0)
				  or (is_xp = 1 and exists (select 1 from "%I"."%I"."%I"
				      where "%I" = doc_id and xpath_contains ("%I", TT_XPATH))))',
				  tbn0, tbn1, tbn2, id, dbcol),
			       sprintf ('insert soft "%I"."%I"."%I" (TTH_U_ID, TTH_T_ID, TTH_D_ID, TTH_NOTIFY)
			       select TTU_U_ID, TT_ID, doc_id, ntf from "%I"."%I"."%I" where TTU_T_ID = TT_ID;
			    }
			  ii := ii + 1;
			}
		      }
		  inx := inx + 2;
		}
	      --dbg_obj_print ('' batch '', length (strs) / 2, ''distinct tried '', tried, '' hits '', hits);
	  }',  tbn0, tbn1, concat (tbn2, '_', dbcol, '_HIT'),
	      tbn0, tbn1, concat (tbn2, '_', dbcol, '_USER')));
         -- for WebDAV resources display only if user have read access
	 if (0 <> casemode_strcmp (tb, 'WS.WS.SYS_DAV_RES'))
           stmt := replace (stmt, '<INSERT_COND>', '1 = 1');
	 else
           stmt := replace (stmt, '<INSERT_COND>', 'WS.WS.CHECK_READ_ACCESS (u_id, doc_id)');
--	 dbg_obj_print (stmt);
  if (DB.DBA.execstmt (stmt, stat, msg))
    goto err;
  stmt := sprintf (' create procedure "%I"."%I"."TT_WORD_FREQ_%I" (in w varchar)
		    {
		      declare l1, l2 integer;
		      l1 := 0; l2 := 0;
		      whenever not found goto none;
		      select sum (length (VT_DATA)),
		             sum (length (VT_LONG_DATA)) into l1, l2 from "%I"."%I"."%I_%I_WORDS"
			where VT_WORD = w;

		     none:
		      return (coalesce (l1, 0)  + coalesce (l2, 0));
		    }', tbn0, tbn1, tbn2, tbn0, tbn1, tbn2, dbcol);
  if (DB.DBA.execstmt (stmt, stat, msg))
    goto err;
  stmt := sprintf ('create procedure "%I"."%I"."TT_QUERY_%I" (in exp varchar, in u_id int, in comment varchar,
	             in notify varchar, in user_data varchar := null, in predicate varchar := null)
		    {
		      declare t_id, ix, len integer;
		      declare w any;
		      t_id := coalesce ((select top 1 TT_ID + 1 from "%I"."%I"."%I_%I_QUERY"
				order by TT_ID desc), 1);
                      w := "%I"."%I"."TT_QUERY_WORD_%I" (exp, 0);
                      len := length (w); ix := 0;
		      while (ix < len) {
		         insert into  "%I"."%I"."%I_%I_QUERY" (TT_ID, TT_QUERY, TT_WORD, TT_COMMENT, TT_CD, TT_PREDICATE)
			  values (t_id, exp, aref (w, ix), comment, user_data, predicate);
                         ix := ix + 1;
			}
		      insert soft "%I"."%I"."%I_%I_USER" (TTU_T_ID, TTU_U_ID, TTU_NOTIFY, TTU_COMMENT)
		             values (t_id, u_id, notify, comment);
		    }', tbn0, tbn1, tbn2,
		        tbn0, tbn1, tbn2, dbcol,
			tbn0, tbn1, tbn2,
			tbn0, tbn1, tbn2, dbcol,
			tbn0, tbn1, tbn2, dbcol);
  if (DB.DBA.execstmt (stmt, stat, msg))
    goto err;
-- XPATH search
  stmt := sprintf ('create procedure "%I"."%I"."TT_XPATH_QUERY_%I" (in exp varchar, in u_id int, in comment varchar,
	             in notify varchar, in user_data varchar := null, in predicate varchar := null)
		    {
		      declare t_id, ix, len integer;
		      declare w any;
		      declare xp any;
                      xp := xpath_text (exp);
		      t_id := coalesce ((select top 1 TT_ID + 1 from "%I"."%I"."%I_%I_QUERY"
				order by TT_ID desc), 1);
                      w := "%I"."%I"."TT_QUERY_WORD_%I" (xp, 1);
                      len := length (w); ix := 0;
		      while (ix < len) {
		         insert into  "%I"."%I"."%I_%I_QUERY" (TT_ID, TT_QUERY, TT_WORD, TT_COMMENT, TT_XPATH, TT_CD, TT_PREDICATE)
			  values (t_id, serialize (xp), aref (w, ix), comment, exp, user_data, predicate);
                         ix := ix + 1;
			}
		      insert soft "%I"."%I"."%I_%I_USER" (TTU_T_ID, TTU_U_ID, TTU_NOTIFY, TTU_COMMENT)
		             values (t_id, u_id, notify, comment);
		    }', tbn0, tbn1, tbn2,
		        tbn0, tbn1, tbn2, dbcol,
			tbn0, tbn1, tbn2,
			tbn0, tbn1, tbn2, dbcol,
			tbn0, tbn1, tbn2, dbcol);
  if (DB.DBA.execstmt (stmt, stat, msg))
    goto err;
-- end XPATH search

  declare pname varchar;
  pname := sprintf ('"%I"."%I"."TT_QUERY_WORD_1_%I"', tbn0, tbn1, tbn2);
  stmt := sprintf ('create procedure %s
	                 (in tree any, inout best_w varchar, inout score integer, in topop integer, inout words any)
			{
			  declare op integer;
			  if (isarray (tree))
			    {
			      op := aref (tree, 0);
			      if (op = 4 or op = 1210 or op = 1209)
				{
				  declare inx int;
				    inx := 0;
				  while (inx < length (tree))
				    {
				      %s (aref (tree, inx), best_w, score, op, words);
				      inx := inx + 1;
				    }
				}
			      else if (op = 1211)
				{
				  %s (aref (tree, 2), best_w, score, op, words);
				}
			      else if (op = 1)
				{
				  declare ct int;
				  declare searched_word varchar;
				  searched_word := aref (tree, 2);
				  if (strchr (searched_word, ''*'') is not null)
				    return;
				  ct := "%I"."%I"."TT_WORD_FREQ_%I" (searched_word);
				  if (ct < score and topop <> 3)
				    {
				      score := ct;
				      best_w := searched_word;
				    }
				  else if (topop = 3)
				    best_w := searched_word;
				}
			     else if (op = 3)
			       {
				 declare inx, sc1 int;
				 inx := 0;
				 while (inx < length (tree))
				   {
				     best_w := null;
				     sc1 := score;
				     score := 1000000000;
				     %s (aref (tree, inx), best_w, score, op, words);
				     if (words is null and best_w is not null)
				       words := vector (best_w);
				     else if (best_w is not null)
				       words := vector_concat (words, vector (best_w));
				     score := sc1;
				     best_w := null;
				     inx := inx + 1;
				   }
			       }
			    }
			}', pname, pname, pname, tbn0, tbn1, tbn2, pname);
  if (DB.DBA.execstmt (stmt, stat, msg))
    goto err;
  stmt := sprintf ('create procedure "%I"."%I"."TT_QUERY_WORD_%I" (in exp varchar, in is_xpath integer)
			{
			  declare tree, ws1 any;
			  declare w varchar;
			  declare sc int;
			  sc := 1000000000;
			  w := ''__'';
                          ws1 := null;
			  if (is_xpath = 0)
			    tree := vt_parse (exp);
			  else
			    tree := exp;
			  %s (tree, w, sc, 0, ws1);
			  if (w is not null)
			    return vector (w);
			  else if (isarray (ws1))
			    return ws1;
			  return vector (''__'');
			}', tbn0, tbn1, tbn2, pname);
  if (DB.DBA.execstmt (stmt, stat, msg))
    goto err;

  stmt := sprintf ('create procedure "%I"."%I"."TT_NOTIFY_%I" () {
		    declare stat, msg, ntf, comment varchar;
		    declare _u_id, _ts, _d_id, _t_id, rc_call any;

                    for select distinct TTH_NOTIFY as _tt_notify from  "%I"."%I"."%I_%I_HIT" where TTH_NOTIFY like ''%%@%%'' do
		       {
			 declare _message, _msg_tit varchar;
			 declare _cnt_hits integer;
			 declare _short_text varchar;
			 declare hits_data any;
                         _cnt_hits := 0;
                         _message := ''\\r\\nQuery/Hit Date/Document ID'';
                         hits_data := vector ();
		         for select TTH_U_ID, TTH_TS, TTH_D_ID, TTH_T_ID, TTH_NOTIFY
			    from  "%I"."%I"."%I_%I_HIT" where TTH_NOTIFY = _tt_notify
			    order by TTH_TS
			    do
			  {
			    whenever not found goto nfq;
			    select coalesce (TT_COMMENT, TT_QUERY) into comment from
			       "%I"."%I"."%I_%I_QUERY" where TT_ID = TTH_T_ID;
			    nfq:
			    if (comment is null)
			      comment := ''*** no query ***'';
                            _cnt_hits := _cnt_hits + 1;
                            hits_data := vector_concat (hits_data, vector (vector (comment, TTH_TS, TTH_D_ID)));
                            _message := concat (_message, ''\\r\\n'', comment, ''/'',
					    substring (datestring (TTH_TS), 1, 19), ''/'',
					    cast (TTH_D_ID as varchar));
			  }
			stat := ''00000'';
                       _msg_tit := concat (''Subject: Text trigger notification: New '',
				      cast (_cnt_hits as varchar) , '' hit(s) registered\\r\\n'');
                        _message := concat (_msg_tit, _message);

                        rc_call := 0;
			if (__proc_exists (''%s.%s.%s_INFO_TEXT''))
			  {
                            rc_call := call (''%s.%s.%s_INFO_TEXT'') (_tt_notify, hits_data);
			  }
			if (not rc_call)
			  {
			    exec (''smtp_send (null,?,?,?)'', stat, msg,
			      vector (_tt_notify, _tt_notify, _message));
			  }
			 update "%I"."%I"."%I_%I_HIT" set TTH_NOTIFY = '''' where TTH_NOTIFY = _tt_notify;
		       }
		 return;
	         }',
		 tbn0, tbn1, tbn2,
		 tbn0, tbn1, tbn2, dbcol,
		 tbn0, tbn1, tbn2, dbcol,
		 tbn0, tbn1, tbn2, dbcol,
		 tbn0, tbn1, tbn2,
		 tbn0, tbn1, tbn2,
		 tbn0, tbn1, tbn2, dbcol);

  --dbg_obj_print (stmt);

  if (DB.DBA.execstmt (stmt, stat, msg))
    goto err;


  insert into DB.DBA.SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_SQL, SE_INTERVAL)
      values (sprintf ('Notification for text hits on "%s.%s.%s"', tbn0, tbn1, tbn2), now (), sprintf ('"%I"."%I"."TT_NOTIFY_%I"()', tbn0, tbn1, tbn2), 10);

  return 0;

err:
  if (stat <> '42S01' and verr <> 'FT035' and verr <> 'FTT036' and  verr <> 'FT037')
    DB.DBA.vt_drop_ftt (tb, dbcol);
  if (is_intr <> 2 and verr <> '')
    {
      signal (stat, msg, verr);
    }
  else if (is_intr <> 2 and verr = '')
    {
      signal (stat, msg);
    }
}
;


create procedure DB.DBA.vt_drop_ftt (in tb varchar, in dbcol varchar)
{
  declare stmt, stat, msg varchar;
  declare tbn0, tbn1, tbn2 varchar;

--  tb := complete_table_name (fix_identifier_case (tb), 1);
  tb := complete_table_name ((tb), 1);
  tbn0 := name_part (tb, 0);
  tbn1 := name_part (tb, 1);
  tbn2 := name_part (tb, 2);

  if (not exists (select 1 from DB.DBA.SYS_VT_INDEX where 0 = casemode_strcmp (VI_TABLE,  tb)))
    signal ('42S02', sprintf ('Text index not defined for "%s"', tb), 'FT034');

  if (not isstring (dbcol))
    select VI_COL into dbcol from DB.DBA.SYS_VT_INDEX where 0 = casemode_strcmp (VI_TABLE,  tb);

  stmt := sprintf ('DROP TRIGGER "%I"."%I"."%I_FTT_D"', tbn0, tbn1, tbn2);
  DB.DBA.execstmt (stmt, stat, msg);
  stmt := sprintf ('DROP PROCEDURE "%I"."%I"."VT_HITS_%I"' , tbn0, tbn1, tbn2);
  DB.DBA.execstmt (stmt, stat, msg);
  stmt := sprintf ('DROP PROCEDURE "%I"."%I"."TT_WORD_FREQ_%I"', tbn0, tbn1, tbn2);
  DB.DBA.execstmt (stmt, stat, msg);
  stmt := sprintf ('DROP PROCEDURE "%I"."%I"."TT_QUERY_%I"', tbn0, tbn1, tbn2);
  DB.DBA.execstmt (stmt, stat, msg);
  stmt := sprintf ('DROP PROCEDURE "%I"."%I"."TT_XPATH_QUERY_%I"', tbn0, tbn1, tbn2);
  DB.DBA.execstmt (stmt, stat, msg);
  stmt := sprintf ('DROP PROCEDURE "%I"."%I"."TT_QUERY_WORD_1_%I"', tbn0, tbn1, tbn2);
  DB.DBA.execstmt (stmt, stat, msg);
  stmt := sprintf ('DROP PROCEDURE "%I"."%I"."TT_QUERY_WORD_%I"',tbn0, tbn1, tbn2);
  DB.DBA.execstmt (stmt, stat, msg);
  stmt := sprintf ('DROP PROCEDURE "%I"."%I"."TT_NOTIFY_%I"',tbn0, tbn1, tbn2);
  DB.DBA.execstmt (stmt, stat, msg);
  stmt := sprintf ('DROP TABLE "%I"."%I"."%I"', tbn0, tbn1, concat (tbn2, '_', dbcol,'_QUERY'));
  DB.DBA.execstmt (stmt, stat, msg);
  stmt := sprintf ('DROP TABLE "%I"."%I"."%I"', tbn0, tbn1, concat (tbn2, '_', dbcol, '_USER'));
  DB.DBA.execstmt (stmt, stat, msg);
  stmt := sprintf ('DROP TABLE "%I"."%I"."%I"', tbn0, tbn1, concat (tbn2, '_', dbcol, '_HIT'));
  -- make an empty procedure
  DB.DBA.execstmt (stmt, stat, msg);
  stmt := sprintf ('create procedure "%I"."%I"."VT_HITS_%I" (inout vtb any, inout strs any)
	    { return; }', tbn0, tbn1, tbn2 );
  DB.DBA.execstmt (stmt, stat, msg);

  delete from DB.DBA.SYS_SCHEDULED_EVENT where SE_NAME = sprintf ('Notification for text hits on "%s.%s.%s"', tbn0, tbn1, tbn2);
  return;
}
;

--#IF VER=5
--!AFTER
--#ENDIF
grant execute on DB.DBA.vt_create_text_index to public
;
