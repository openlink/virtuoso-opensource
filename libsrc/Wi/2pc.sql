--
--  $Id$
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

create table _2PC.DBA.TRANSACTIONS (TRX_ID INTEGER, TRX_STATE VARCHAR)
;

create procedure _2PC.DBA._FFFF_GET_SEQ_NEXT (IN seqobj VARCHAR, IN _min INTEGER, IN _max INTEGER)
{
  DECLARE id INTEGER;
  id := sequence_next (seqobj);
  IF ((id < _min) OR (id > _max))
    {
    	sequence_set (seqobj, _min, 0);
	return _min;
    }
  return sequence_next (seqobj);
}
;

create procedure
_2PC.DBA._0001_ADD_ENTRY ()
{
  DECLARE _trx_id0 INTEGER;
  DECLARE _trx_id INTEGER;
  _trx_id0 := -1;
again:
  _trx_id := _2PC.DBA._FFFF_GET_SEQ_NEXT ('_2PC/TRANSACTIONS/_ID', 1, 10000);
  IF (_trx_id0 = -1)
  {
     _trx_id0 := _trx_id;
  } ELSE IF (_trx_id0 = _trx_id)
  {
     signal ('TP000', sprintf ('Not enough space in system table for new entry, try to empty _2PC.DBA.TRANSACTIONS table'));
     RETURN;
  }

WHENEVER SQLSTATE '23000' GOTO again;
  INSERT INTO _2PC.DBA.TRANSACTIONS (TRX_ID, TRX_STATE)
   VALUES (_trx_id, 'STARTED');
  RETURN _trx_id;
}
;

create procedure _2PC.DBA._FFFF_CHECK_TRX_ID ( IN _trx_id INTEGER)
{
  FOR SELECT TRX_ID FROM _2PC.DBA.TRANSACTIONS WHERE TRX_ID=_trx_id DO
  {
    RETURN;
  }
  signal ('TP000', sprintf ('No such transaction id [%lx]', _trx_id));
}
;


create procedure _2PC.DBA._0001_TRX_SSTATE ( IN _trx_id INTEGER, IN _state VARCHAR)
{
  _2PC.DBA._FFFF_CHECK_TRX_ID (_trx_id);

  IF ((_state = 'COMMITTED') OR (_state = 'ROLLBACKED'))
    {
	DELETE FROM _2PC.DBA.TRANSACTIONS WHERE TRX_ID=_trx_id;
	RETURN 0;
    }
  UPDATE _2PC.DBA.TRANSACTIONS SET TRX_STATE=_state WHERE TRX_ID=_trx_id;
  RETURN 0;
}
;

create procedure _2PC.DBA._0001_GET_TRX_STATE (IN _trx_id INTEGER)
{
  _2PC.DBA._FFFF_CHECK_TRX_ID (_trx_id);
  FOR SELECT TRX_STATE FROM _2PC.DBA.TRANSACTIONS WHERE TRX_ID=_trx_id DO
  {
-- See SQL_COMMIT define in sql.h
	IF (TRX_STATE='COMMIT_PENDING')
	  RETURN 0;
-- See SQL_ROLLBACK define in sql.h
	IF (TRX_STATE='ROLLBACK_PENDING')
	  RETURN 1;
	signal ('TP000', 'VirtDTC error - unexpected state [%s]', TRX_STATE);
	RETURN;
  }
}
;

create procedure _2PC.DBA.virt_tp_enlist_branch (IN trx_cookie VARCHAR)
{
  virt_tp_update_cli_001 (trx_cookie);
}
;

create procedure _2PC.DBA.XA_GET_ALL_XIDS_COUNT ()
{
  DECLARE xid VARCHAR;
  DECLARE c INTEGER;

  c := 0;

  get_rec_xid_beg ();
  xid := get_rec_xid ();
  WHILE (xid IS NOT NULL)
    {
      c := c + 1;
      xid := get_rec_xid ();
    }
  get_rec_xid_end();
  RETURN c;
}
;

create procedure _2PC.DBA.OLD_XA_GET_ALL_XIDS ()
{
  declare xid varchar;

  result_names (xid);

  get_rec_xid_beg ();
  xid := get_rec_xid ();
  while (xid is not null)
    {
      result (xid);
      xid := get_rec_xid ();
    }
  get_rec_xid_end();
  return NULL;
}
;

create procedure _2PC.DBA.XA_GET_ALL_XIDS ()
{
  declare xid varchar;

  result_names (xid);

  declare xids any;
  xids := txa_get_all_trx();
  if (xids is not null)
    {
      declare idx integer;
      idx := 0;
      while (idx < length (xids))
	{
 	  declare st varchar;
	  st := xids[idx][3]; --aref (aref (xids, idx), 3);
	  if (substring (st, 1, 3) = 'PRP')
	    {
	      result (txa_bin_encode (xids[idx][0])); --aref (aref (xids, idx), 3)));
	    }
	  idx := idx + 1;
	}
    }
  return NULL;
}
;


grant execute on "_2PC.DBA._0001_ADD_ENTRY" to public
;
grant execute on "_2PC.DBA._0001_TRX_SSTATE" to public
;
grant execute on "_2PC.DBA._0001_GET_TRX_STATE" to public
;
grant execute on "DB.DBA.XA_GET_ALL_XIDS_COUNT" to public
;
grant execute on "DB.DBA.XA_GET_ALL_XIDS" to public
;

