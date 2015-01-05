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

-- ---------------------------------------------------
-- OpenX 'MODULE_NAME' code generation file.
-- ---------------------------------------------------

-- Reconnect as application user
--
create procedure OMAIL.WA.res_get_mime_ext(
  IN _mime_id INTEGER,
  IN _ext_id  INTEGER)
{
  return coalesce((SELECT MIME_ID FROM OMAIL.WA.RES_MIME_EXT WHERE EXT_ID = _ext_id), _mime_id);
}
;

create procedure OMAIL.WA.res_get_mime_ext_id(
  IN _ext varchar)
{
  return coalesce((SELECT EXT_ID FROM OMAIL.WA.RES_MIME_EXT WHERE EXT_NAME = OMAIL.WA.res_mime_ext(_ext)), 0);
}
;

--
--
create procedure OMAIL.WA.res_image(
  inout path ANY,
  inout params ANY,
  inout lines ANY)
{
  DECLARE
    v_id,
    e_id,
    v_size,
    S ANY;

  v_id   := atoi(get_keyword('id', params, '0'));
  e_id   := atoi(get_keyword('ext', params, '0'));
  v_size := get_keyword('size', params, '');

  S := coalesce((SELECT ICON16 FROM OMAIL.WA.RES_MIME_TYPES WHERE ID=OMAIL.WA.res_get_mime_ext(v_id, e_id)), '');
  if (S = '')
    S := coalesce((SELECT ICON16 FROM OMAIL.WA.RES_MIME_TYPES WHERE ID = 30100), '');

  OMAIL.WA.utl_myhttp(S, null, 'image/gif', null, null, null);
  return;
}
;

create procedure OMAIL.WA.res_mime_create(
  IN p_id INTEGER,
  IN p_type VARCHAR,
  IN p_descr VARCHAR)
{
  DECLARE
    state VARCHAR;

  state := '00000';
  DECLARE EXIT HANDLER FOR SQLSTATE '*' {state := __SQL_MESSAGE; goto ERROR;};
  {
    INSERT REPLACING OMAIL.WA.RES_MIME_TYPES(ID, MIME_TYPE, DESCRIPTION)
      VALUES(p_id, p_type, p_descr);
  };
ERROR:
  return p_id;
}
;

create procedure OMAIL.WA.res_mime_edit(
  IN p_id INTEGER,
  IN p_ext VARCHAR,
  IN p_type VARCHAR,
  IN p_descr VARCHAR,
  IN p_icon16 VARCHAR,
  IN p_icon32 VARCHAR)
{
  DECLARE
    state VARCHAR;

  state := '00000';
  DECLARE EXIT HANDLER FOR SQLSTATE '*' {state := __SQL_MESSAGE; goto ERROR;};
  {
    UPDATE
      OMAIL.WA.RES_MIME_TYPES
    SET
      MIME_TYPE = p_type,
      DESCRIPTION = p_descr,
      ICON16 = p_icon16,
      ICON32 = p_icon32
    WHERE
      ID = p_id;
  };
ERROR:
  return p_id;
}
;

create procedure OMAIL.WA.res_mime_ext(
  IN p_name VARCHAR)
{
  DECLARE
    V ANY;

  if(not length(p_name)) return '';
  V := split_and_decode (p_name, 0, '\0\0.');
  return lcase(aref(V, length(V)-1));
}
;

create procedure OMAIL.WA.res_get_mimetype_id(
  IN _name VARCHAR,
  IN _default INTEGER := 30100)
{
  return coalesce((SELECT ID FROM OMAIL.WA.RES_MIME_TYPES WHERE MIME_TYPE = _name), _default);
}
;

