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

create procedure rq_s_3_create_dsn(){
	declare _driver varchar;
	declare _dsn varchar;
	declare _address varchar;
	declare _userid varchar;
	declare _pass varchar;
	declare _attrib varchar;
	result_names('res1','res2');

	_driver := null;

	foreach(varchar _drv in sql_get_installed_drivers ())do{
		if (upper(_drv) like 'OPENLINK VIRTUOSO%' or upper(_drv) like 'VIRTUOSO%'){
			_driver := _drv;
			goto drv_fin;
		};
	};
	drv_fin:;

	if (isnull(_driver))
	  signal('RQS3','Can''t find virtuoso driver.');

	_dsn := 'LocalVirtuosoTutorialRQS3';
	_address := 'localhost:' || cfg_item_value (virtuoso_ini_path(),'Parameters', 'ServerPort');
	_userid := 'demo';
	_pass := 'demo';

        --declare state, message, meta, result any;
        --exec('USER_GRANT_ROLE (''demo'', ''SPARQL_SELECT'')', state, message, vector(), 0, meta, result);
        --USER_GRANT_ROLE ('demo', 'SPARQL_SELECT');


	_attrib := '';
	_attrib := _attrib || 'DSN=' || _dsn || ';';
	_attrib := _attrib || 'Address=' || _address || ';';
	_attrib := _attrib || 'UserID=' || _userid || ';';
	_attrib := _attrib || 'Password=' || _pass || ';';
	_attrib := _attrib || 'Description=Created for RQ-S-3 tutorial;';

	sql_config_data_sources(_driver,'user',_attrib);

};

rq_s_3_create_dsn();
