--
--  $Id: dbev_login.sql,v 1.4.10.1 2013/01/02 16:14:39 source Exp $
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
--sample DBEV_LOGIN hook
-- called just before a client is authenticated to the virtuoso server
--
-- paramters:
--   user_name       :
--      IN : the user name from the login data
--     OUT : the user name used by Virtuoso for this connection
--   digest          : the password digest calculated by the client (or the password itslef for older clients)
--   session_random  : the random key used to calculate the digest
--
-- return value: the continuation code
--         -1 - continue with normal verification
--          0 - reject the login
--          1 - allow the login (the user returned should be a valid Virtuoso local user name

create procedure "DB"."DBA"."DBEV_LOGIN" (
    inout user_name varchar,
    in digest varchar,
    in session_random varchar)
{
  -- the hook runs as DBA
  dbg_obj_print ('user=', user);

  -- and is compiled as DBA
  declare uid_cnt integer;
  uid_cnt := 0;
  select count (*) into uid_cnt from SYS_USERS where U_NAME = user_name;
  dbg_printf ('%ld local users found with this name', uid_cnt);

  if (user_name = 'masterdba')
    {
      -- 'masterdba' is a valid remotely defined user
      -- it's password is 'masterdbapwd'
      -- we're going to check it's password and then map it to dba

      declare md5_ctx any;
      declare my_digest varchar;
      declare pwd varchar;

      -- this is our assumption for the user's password
      -- this can come from an external source as well
      pwd := 'masterdbapwd';

      -- calculate the MD5 digest for checking the password that the client supplied.
      -- note that it uses the 'masterdba'/'masterdbapwd' to calculate it since we
      -- assume that these are the data the client supplied as user id and password
      --
      -- The way to calcutale this is FIXED.
      -- The ONLY variables are the user id and the password

      -- START of the FIXED digest calculation sequence
      md5_ctx := md5_init();
      md5_ctx := md5_update(md5_ctx, session_random);
      md5_ctx := md5_update(md5_ctx, user_name);
      md5_ctx := md5_update(md5_ctx, pwd);
      -- the 0 parameter to the md5_final causes it to return the bytes
      -- instead of representing it as hexidecimal characters
      my_digest := md5_final (md5_ctx, 0);
      -- END of the FIXED digest calculation sequence

      -- now compare the calculated digest with the one supplied by the client
      -- note the OR here - some older clients MAY supply the password in plain text
      if (my_digest = digest or pwd = digest)
        {
	  -- the match says that the client indeed supplied 'masterdbapwd' as a password
          dbg_obj_print ('masterdba validated');

	  -- so map it to the local 'dba' user
	  user_name := 'dba';

          -- and skip further verification
          return 1;
	}
      else
	{
	  -- the password is not the one that we verify against
          dbg_obj_print ('masterdba pwd wrong');

          -- not allow the login at all
	  return 0;
	}
    }
  else if (user_name = 'nobody')
    {
      -- the hook can signal :
      -- this is equal to returning -1, but has the additional benefit of an error message printed into the log
      signal ('28000', 'we don''t map nobody');
    }
  else if (user_name = 'attacker')
    {
      -- that's a way to print a message to the log and reject the login
      log_message ('trying invalid user');
      return 0;
    }
  else
    {
      -- all local user_name/pwd are subject to normal verification
      dbg_obj_print (user_name);
      return -1;
    }
  -- note that not returning value causes the Virtuoso to print an appropriate message to the log
  -- and then continue with the normal verification
  -- same happends if the value returned is not 0, -1 or 1
};
