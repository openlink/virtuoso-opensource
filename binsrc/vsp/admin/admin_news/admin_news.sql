--
--  $Id$
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


CREATE TABLE "DB"."DBA"."NEWS_GROUPS_AVAILABLE" (
	"NS_ID" INTEGER NOT NULL REFERENCES "DB"."DBA"."NEWS_SERVERS"("NS_ID") on delete cascade,
	"NG_ID" INTEGER IDENTITY,
	"NAME" VARCHAR NOT NULL,
	"DESCRIPTION" VARCHAR,
	"FIRST" INTEGER NOT NULL,
	"LAST" INTEGER NOT NULL,
	"POSTING" VARCHAR,
	"UPDATED" VARCHAR,
	PRIMARY KEY ("NS_ID", "NAME")
)
CREATE UNIQUE INDEX GROUPS_AVAILABLE ON DB.DBA.NEWS_GROUPS_AVAILABLE(NAME, NS_ID)
;

CREATE PROCEDURE DB.DBA.populate_groups_available (in _ns_id integer)
{
	declare _list, _row any;
	declare _name, _post, _server, _user, _pass varchar;
	declare idx, len, _port, _last, _first integer;

	if (_ns_id IS NULL) return -2; -- localhost not allowed
	_server := '';
	_user := '';
	_port := 119;
	_pass := '';

	SELECT "NS_SERVER", "NS_PORT", "NS_USER", "NS_PASS" INTO _server, _port, _user, _pass
		FROM "DB"."DBA"."NEWS_SERVERS" WHERE "NS_ID" = _ns_id;

	commit work;

	UPDATE "DB"."DBA"."NEWS_GROUPS_AVAILABLE" SET "UPDATED" = 'N' WHERE "NS_ID" = _ns_id;

	if (_server = '' or _server = 'localhost')
		return -1; -- localhost again??
	if (_user = '')
		_list := nntp_get (concat (_server, ':', cast (_port as varchar)), 'list');
	else
		_list := nntp_auth_get (concat (_server, ':', cast (_port as varchar)), _user, _pass, 'list');

	idx := 0;
	len := length (_list);
	while (idx < len)
	{
		_row   := aref (_list, idx);
		_name  := aref (_row, 0);
		_post  := aref (_row, 3);
		_last  := aref (_row, 1);
		_first := aref (_row, 2);

		if (EXISTS(SELECT 1 FROM "DB"."DBA"."NEWS_GROUPS_AVAILABLE" WHERE "NS_ID" = _ns_id AND "NAME" = _name))
			UPDATE "DB"."DBA"."NEWS_GROUPS_AVAILABLE"
				SET "DESCRIPTION" = '', "FIRST" = _first, "LAST" = _last, "POSTING" = _post, "UPDATED" = 'Y'
				WHERE "NS_ID" = _ns_id AND "NAME" = _name;
		else
			INSERT INTO "DB"."DBA"."NEWS_GROUPS_AVAILABLE"("NS_ID", "NAME", "DESCRIPTION", "FIRST", "LAST", "POSTING", "UPDATED")
				VALUES (_ns_id, _name, '', _first, _last, _post, 'Y');

		idx := idx + 1;
		commit work;
	}

	UPDATE "DB"."DBA"."NEWS_GROUPS_AVAILABLE" SET "UPDATED" = 'R' WHERE "NS_ID" = _ns_id AND "UPDATED" = 'N';
	return len;
}
;

CREATE TRIGGER GetGroups AFTER INSERT ON "DB"."DBA"."NEWS_SERVERS"
{
	INSERT INTO "DB"."DBA"."SYS_SCHEDULED_EVENT"(SE_NAME, SE_START, SE_SQL, SE_INTERVAL)
	VALUES(concat('UPD_Avail_Grps_', NS_SERVER), now(),
		concat('"DB"."DBA"."populate_groups_available"(', cast("NS_ID" as varchar), ')'), 100);

}
;

CREATE TRIGGER GetGroupsStop AFTER DELETE ON "DB"."DBA"."NEWS_SERVERS"
{
	delete from "DB"."DBA"."SYS_SCHEDULED_EVENT"
	where SE_NAME = concat('UPD_Avail_Grps_', NS_SERVER);

}
;

-- triggers for inserting and removing schedules
	-- available groups table
		-- on insert into news_servers insert "select populate_groups_available(ns_server)", concat("auto_nntp_pop_", ns_server) into schedule;
		-- on delete from news_servers delete from schedule where desc = concat("auto_nntp_pop_", ns_server)
	-- updating groups

-- fkeys and such for cascade deletes

