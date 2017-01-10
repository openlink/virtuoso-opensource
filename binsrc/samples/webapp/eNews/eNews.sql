--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2017 OpenLink Software
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
CREATE TABLE eNews.eNews.newsCategories(CatID INTEGER IDENTITY,ChID INTEGER,Category VARCHAR(200),XML_IDX VARCHAR(1024), PRIMARY KEY(CatID));

CREATE TABLE eNews.eNews.newsChannels(ChID INTEGER IDENTITY,Channel VARCHAR(100),PRIMARY KEY(ChID));

CREATE TABLE eNews.eNews.newsxslsheet(xslviewsheet INTEGER,sheet LONG VARCHAR,sheetname VARCHAR(30),css LONG VARCHAR,PRIMARY KEY(xslviewsheet));

CREATE TABLE eNews.eNews.registry(First VARCHAR(50),Last VARCHAR(50), Email VARCHAR(200),Pwd VARCHAR(50),UID INTEGER IDENTITY, xslviewsheet INTEGER, Last_Viewed INTEGER, PRIMARY KEY(Email));

CREATE TABLE eNews.eNews.tempCats(Category VARCHAR(200),CatID INTEGER);

CREATE TABLE eNews.eNews.UserNews(CatID INTEGER,UID INTEGER,PRIMARY KEY(CatID,UID));

create view eNews.dba.newsInfo(UID, CatID, Category, ChID, Channel) as
 select t1.UID, t2.CatID, t2.Category, t3.ChID, t3.Channel
 from eNews.eNews.registry t1,
      eNews.eNews.newsCategories t2,
      eNews.eNews.newsChannels t3,
      eNews.eNews.UserNews t4
 where t1.UID = t4.UID and t4.CatID = t2.CatID and t2.ChID = t3.ChID;

create procedure WS.WS.get_dav_col_id (in _col varchar)
{
  declare _path_v any;
  declare _cname varchar;
  declare _lp, _pid, _cid, ix, _flg integer;

  if (aref(_col, 0) = ascii('/'))
    _col := "right"(_col, length(_col) - 1);
  if (length(_col) <> 0)
    if (aref(_col, length(_col) - 1)  = ascii('/'))
      _col := "left"(_col, length(_col) - 1);
  _path_v := split_and_decode(_col, 0, '\0\0/');
  _path_v := WS.WS.FIXPATH (_path_v);
  _lp := length(_path_v);
  if (_lp < 1)
    return -1;
  if (aref(_path_v, 0) <> 'DAV')
    return -11;
  while (ix < _lp)
  {
    if (aref(_path_v, ix) = '')
      return -1;
    ix := ix + 1;
  }
  ix := 0;
  _pid := (select min(COL_PARENT) from WS.WS.SYS_DAV_COL);

  while (ix < _lp)
  {
    _cname := aref(_path_v, ix);
    _pid := (select COL_ID from WS.WS.SYS_DAV_COL
                      where COL_PARENT = _pid and COL_NAME = _cname);

    ix := ix + 1;
  }
  if (_pid is null)
    return -1;
  return _pid;
}
;

create procedure eNews.eNews.update_news_list()
{
  declare _list varchar;
  declare _fields, _lines any;
  declare _chid integer;

  if (not exists(select 1 from DB.DBA.SYS_SCHEDULED_EVENT where SE_NAME = 'Update eNews List'))
  {
    insert into DB.DBA.SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_SQL, SE_LAST_COMPLETED, SE_INTERVAL)
	    values ('Update eNews List', curdatetime(), 'eNews.eNews.update_news_list', curdatetime(), 40320);
  }

  if (WS.WS.get_dav_col_id('/DAV/MoreoverNewsfeeds/') = -1)
  {
    declare dav_id, dav_grp_id integer;
    dav_id := (select U_ID from WS.WS.SYS_DAV_USER where U_NAME = 'dav');
    dav_grp_id := (select U_GROUP from WS.WS.SYS_DAV_USER where U_NAME = 'dav');
    create_dav_col ('/DAV/MoreoverNewsfeeds', dav_id, dav_grp_id, '110100100N');
  }

  _list := http_get('http://w.moreover.com/categories/category_list_pctsv.tsv');
  _list := trim(_list, '\r\n');
  _lines := split_and_decode(_list, 0, '\0\0\n');

  declare i integer;
  while (i < length(_lines))
  {
    _fields := split_and_decode(trim(_lines[i], '\r\n'), 0, '\0\0\t');
    if (_fields[0] <> '' )
    {
      if (not exists(select 1 from eNews..newsChannels where Channel = _fields[3]))
        insert into eNews..newsChannels(Channel) values(_fields[3]);

      if (not exists(select 1 from eNews..newsCategories where Category = _fields[1]))
      {
        _chid := (select ChID from eNews..newsChannels where Channel = _fields[3]);
        insert into eNews..newsCategories(ChID, Category, XML_IDX) values(_chid, _fields[1], _fields[0]);
      }
     insert into eNews..tempCats(Category, CatID)
       values(_fields[1], (select CatID from eNews..newsCategories where Category = _fields[1]));
    }
    i := i + 1;
  }
  if ((select count (*) from eNews..tempCats)  > 0)
  {
    declare _cid integer;
    for (select CatID from eNews..newscategories where Category not in (select Category from eNews..tempCats)) do
    {
      _cid := CatID;
      delete from eNews..UserNews where CatID = _cid;
      delete from eNews..newsCategories where CatID = _cid;
    }
    delete from eNews..tempCats;
    delete from eNews..newsChannels where ChID not in (select ChID from eNews..newsCategories);
  }
}
;

create procedure eNews.eNews.show_headlines(in _catid integer, in _xsl varchar)
{
  declare _dav_col_id, _dav_usr, _dav_grp, _flag integer;
  declare _dav_col, _xml, _xml_name, _full_xml_name varchar;
  declare _str, _content any;

  _dav_col := '/DAV/MoreoverNewsfeeds/';
  _dav_col_id := WS.WS.get_dav_col_id(_dav_col);
  _dav_usr := (select COL_OWNER from WS.WS.SYS_DAV_COL where COL_ID = _dav_col_id);
  _dav_grp := (select COL_GROUP from WS.WS.SYS_DAV_COL where COL_ID = _dav_col_id);

  _xml := (select XML_IDX from eNews..newsCategories where CatID = _catid);
  _xml_name := concat(_xml, '.xml');
  _full_xml_name := concat(_dav_col, _xml_name);
  _flag := 0;
  if (not exists(select 1 from WS.WS.SYS_DAV_RES where RES_FULL_PATH = _full_xml_name))
    _flag := 1;
  else if (datediff('minute', (select RES_MOD_TIME from WS.WS.SYS_DAV_RES where RES_FULL_PATH = _full_xml_name), curdatetime()) > 90)
    _flag := 2;

  if (_flag > 0)
  {
    _content := http_get(concat('http://www.moreover.com/cgi-local/page?', _xml, '+xml'));
    create_dav_file(_content, _xml_name, _dav_usr, _dav_grp, '110100100N', _dav_col_id, _flag - 1, '');
  }
  else
    _content := XML_URI_GET(concat('virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:', _dav_col), _xml_name);

  _str := string_output();
  http_value(xslt(concat('file:', _xsl), xml_tree_doc(xml_tree(_content)), vector('xml_url', _full_xml_name)), 0, _str);
  return string_output_string(_str);
}
;

create procedure eNews.eNews.eNews_Params()
{
  declare ini varchar;
  declare iniany any;
  declare x integer;
  ini := XML_URI_GET(null, 'file:/eNews/enews.ini');
  ini := replace(ini, '\r\n', '\n');
  ini := replace(ini, '\n', '&');
  iniany := split_and_decode(ini);
  while (x < length(iniany))
  {
    aset(iniany, x, trim(aref(iniany, x)));
    x := x+1;
  }
  return iniany;
}
;

VHOST_DEFINE (lpath=>'/eNews', ppath=>'/eNews/', vsp_user=>'dba', def_page=>'newslogin.vsp');

create procedure eNews.eNews.make_enews_folrder ()
{
  if (WS.WS.get_dav_col_id('/DAV/MoreoverNewsfeeds/') = -1)
  {
    declare dav_id, dav_grp_id integer;
    dav_id := (select U_ID from WS.WS.SYS_DAV_USER where U_NAME = 'dav');
    dav_grp_id := (select U_GROUP from WS.WS.SYS_DAV_USER where U_NAME = 'dav');
    create_dav_col ('/DAV/MoreoverNewsfeeds', dav_id, dav_grp_id, '110100100N');
  }
}

insert into DB.DBA.SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_SQL, SE_LAST_COMPLETED, SE_INTERVAL)
    values ('Update eNews List', curdatetime(), 'eNews.eNews.update_news_list', curdatetime(), 40320);

eNews.eNews.make_enews_folrder ();

FOREACH BLOB INSERT INTO eNews.eNews.newsxslsheet(xslviewsheet,sheet,sheetname,css) VALUES(0,?,'Scrolling',?);
/eNews/stylesheets/scroll.xsl\c
BLOB
/eNews/css/one.css\c
END
FOREACH BLOB INSERT INTO eNews.eNews.newsxslsheet(xslviewsheet,sheet,sheetname,css) VALUES(1,?,'Block',?);
/eNews/stylesheets/block.xsl\c
BLOB
/eNews/css/one.css\c
END
FOREACH BLOB INSERT INTO eNews.eNews.newsxslsheet(xslviewsheet,sheet,sheetname,css) VALUES(2,?,'Grid',?);
/eNews/stylesheets/grid.xsl\c
BLOB
/eNews/css/one.css\c
END
FOREACH BLOB INSERT INTO eNews.eNews.newsxslsheet(xslviewsheet,sheet,sheetname,css) VALUES(3,?,'Multi-Scrolling',?);
/eNews/stylesheets/multi-scroll.xsl\c
BLOB
/eNews/css/two.css\c
END

INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(1,1,'3M news','index_3m');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(2,2,'IPO news','index_IPO');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(3,3,'Accounting news','index_accounting');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(4,4,'Advertising industry news','index_advertising');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(5,3,'Aerospace and defense industry news','index_aerospace');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(6,5,'Africa news','index_africa');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(7,3,'Agriculture news','index_agriculture');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(8,3,'Airline industry news','index_airlines');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(9,1,'Alcoa news','index_alcoa');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(10,1,'American Express news','index_americanexpress');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(11,6,'Sports: American football news','index_americanfootball');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(12,5,'Argentina news','index_argentina');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(13,7,'Arts and culture news','index_artsandculture');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(14,8,'Asia-Pacific latest','index_asiapacific');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(15,9,'ASP news','index_asp');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(16,10,'Atlanta news','index_atlanta');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(17,1,'AT&amp;T news','index_att');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(18,5,'Australia news','index_australia');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(19,5,'Austria news','index_austria');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(20,3,'Automotive industry news','index_automotive');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(21,5,'Balkans news','index_balkans');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(22,2,'Banking news','index_banking');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(23,6,'Sports: baseball news','index_baseball');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(24,6,'Sports: basketball news','index_basketball');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(25,10,'Bay Area news','index_bayarea');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(26,5,'Benelux news','index_benelux');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(27,3,'Biotech news','index_biotech');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(28,11,'Black interest news','index_blackinterest');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(29,1,'Boeing news','index_boeing');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(30,4,'Book publishing news','index_bookpublishing');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(31,7,'Consumer: book reviews','index_bookreviews');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(32,10,'Boston news','index_boston');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(33,6,'Sports: boxing news','index_boxing');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(34,5,'Brazil news','index_brazil');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(35,4,'Broadcasting industry news','index_broadcasting');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(36,8,'Business features','index_businessfeatures');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(37,4,'Cable industry news','index_cableindustry');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(38,5,'Canada news','index_canada');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(39,12,'Cancer news','index_cancer');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(40,1,'Caterpillar Inc news','index_caterpillar');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(41,5,'Caucasus news','index_caucasus');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(42,5,'Central Asia news','index_centralasia');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(43,11,'Charities news','index_charities');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(44,3,'Chemicals industry news','index_chemicals');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(45,10,'Chicago news','index_chicago');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(46,5,'China news','index_china');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(47,1,'Citigroup news','index_citigroup');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(48,10,'Cleveland-Akron news','index_clevelandakron');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(49,3,'Clothing industry news','index_clothing');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(50,1,'Coca-Cola news','index_cocacola');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(51,2,'Commodities news','index_commodities');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(52,9,'Communications equipment news','index_commsequipment');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(53,9,'Computer games news','index_computergames');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(54,9,'Computer security news','index_computersecurity');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(55,9,'Computer services news','index_computerservices');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(56,3,'Construction news','index_construction');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(57,3,'Consumer electronics news','index_consumerelectronics');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(58,13,'Consumer: fashion news','index_consumerfashion');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(59,3,'Consumer durables news','index_consumergoods');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(60,3,'Consumer non-durables news','index_consumernondurables');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(61,13,'Consumer: travel news','index_consumertravel');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(62,14,'Cool sites','index_coolsites');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(63,2,'Corporate finance news','index_corporatefinance');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(64,6,'Sports: cricket news','index_cricket');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(65,11,'Crime and punishment news','index_crimepunishment');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(66,15,'CRM news','index_crm');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(67,14,'Cyberculture news','index_cyberculture');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(68,6,'Sports: cycling news','index_cycling');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(69,5,'Czech Republic and Slovakia news','index_czechandslovakia');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(70,10,'Dallas-Fort Worth news','index_dallasfortworth');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(71,9,'Database industry news','index_databaseindustry');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(72,10,'DC area news','index_dcarea');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(73,10,'Denver-Boulder news','index_denverboulder');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(74,2,'Derivatives news','index_derivatives');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(75,10,'Detroit news','index_detroit');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(76,9,'Developer news','index_developer');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(77,4,'Digital television news','index_digitaltelevision');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(78,14,'Domain name news','index_domainname');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(79,14,'Dot com doom news','index_dotcomdoom');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(80,3,'Drinks and beverages industry news','index_drinks');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(81,1,'DuPont news','index_dupont');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(82,14,'E-commerce news','index_e-commerce');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(83,5,'Eastern Europe news','index_easterneurope');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(84,1,'Eastman Kodak news','index_eastmankodak');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(85,11,'Economics news','index_economics');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(86,2,'Emerging markets news','index_emergingmarkets');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(87,3,'Engineering news','index_engineering');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(88,9,'Enterprise computing news','index_enterprisecomputing');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(89,7,'Entertainment: film previews','index_entertainmentfilmpreviews');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(90,7,'Entertainment: general news','index_entertainmentgeneral');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(91,7,'Entertainment: gossip','index_entertainmentgossip');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(92,7,'Entertainment: TV shows news','index_entertainmenttvshows');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(93,15,'Entrepreneur news','index_entrepreneur');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(94,12,'Environment news','index_environment');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(95,2,'Equity markets news','index_equity');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(96,5,'Europe news','index_europe');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(97,5,'European business news','index_europeanbusiness');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(98,5,'EU integration news','index_europeanintegration');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(99,1,'Exxon Mobil news','index_exxon');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(100,2,'Fed watch','index_fedwatch');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(101,8,'Finance features','index_financefeatures');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(102,3,'Firearms industry news','index_firearms');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(103,13,'Consumer: fitness news','index_fitness');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(104,2,'Fixed income news','index_fixedincome');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(105,3,'Food industry news','index_food');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(106,13,'Consumer: food and drink news','index_foodanddrink');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(107,8,'International relations news','index_foreignpolicy');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(108,2,'Forex markets news','index_forex');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(109,5,'France news','index_france');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(110,2,'Fund management news','index_fundmanagement');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(111,3,'Gaming news','index_gaming');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(112,11,'Gay news','index_gay');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(113,1,'General Electric Company news','index_gec');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(114,1,'General Motors news','index_generalmotors');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(115,12,'Genetics news','index_genetics');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(116,5,'Germany news','index_germany');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(117,6,'Sports: golf news','index_golf');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(118,9,'Graphics industry news','index_graphics');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(119,5,'Greece news','index_greece');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(120,9,'Handhelds news','index_handhelds');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(121,13,'Consumer: health news','index_health');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(122,3,'Healthcare management news','index_healthcaremanagement');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(123,1,'Hewlett-Packard news','index_hewlettpackard');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(124,13,'Consumer: home and garden news','index_homeandgarden');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(125,1,'Home Depot news','index_homedepot');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(126,1,'Honeywell International news','index_honeywell');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(127,6,'Sports: horse racing news','index_horseracing');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(128,3,'Hospitality industry news','index_hospitalityindustry');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(129,10,'Houston news','index_houston');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(130,15,'Human resources news','index_humanresources');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(131,11,'Human rights news','index_humanrights');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(132,5,'Hungary news','index_hungary');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(133,1,'IBM news','index_ibm');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(134,6,'Sports: ice hockey news','index_icehockey');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(135,9,'Imaging equipment news','index_imagingequipment');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(136,5,'India news','index_india');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(137,5,'Indian subcontinent news','index_indiansubcontinent');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(138,5,'Indonesia news','index_indonesia');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(139,3,'Insurance industry news','index_insurance');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(140,1,'Intel news','index_intel');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(141,11,'International development news','index_internationaldev');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(142,1,'International Paper Company news','index_internationalpaper');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(143,14,'Internet consultancies news','index_internetconsult');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(144,14,'Internet Europe news','index_interneteurope');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(145,8,'Internet features','index_internetfeatures');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(146,14,'Internet Germany news','index_internetgermany');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(147,14,'Internet: international news','index_internetinternational');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(148,14,'Internet Latin America news','index_internetlatinamerica');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(149,8,'International relations features','index_intrelfeatures');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(150,15,'IP and patents news','index_ipandpatents');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(151,5,'Iran news','index_iran');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(152,5,'Ireland news','index_ireland');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(153,5,'Israel news','index_israel');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(154,5,'Italy news','index_italy');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(155,5,'Japan news','index_japan');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(156,9,'Java news','index_java');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(157,11,'Jewish news','index_jewish');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(158,15,'Job markets news','index_jobmarkets');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(159,1,'Johnson &amp; Johnson news','index_johnsonandjohnson');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(160,7,'Jokes','index_jokes');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(161,4,'Journalism news','index_journalism');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(162,1,'JP Morgan news','index_jpmorgan');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(163,9,'Knowledge management news','index_knowledgemanagement');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(164,5,'Korea news','index_korea');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(165,10,'LA news','index_la');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(166,5,'Latin America news','index_latinamerica');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(167,11,'Latino news','index_latino');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(168,15,'Law news','index_law');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(169,3,'Leisure goods news','index_leisuregoods');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(170,9,'Linux news','index_linux');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(171,3,'Logistics news','index_logistics');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(172,5,'London news','index_london');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(173,6,'Sports: major league soccer news','index_majorleaguesoccer');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(174,15,'Management news','index_management');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(175,15,'Marketing news','index_marketing');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(176,1,'McDonalds news','index_mcdonalds');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(177,4,'Media: Europe news','index_mediaeurope');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(178,8,'Media features','index_mediafeatures');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(179,12,'Medical news','index_medical');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(180,1,'Merck &amp; Co news','index_merck');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(181,2,'Mergers and acquisitions news','index_mergersacquisitions');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(182,3,'Metals industry news','index_metals');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(183,5,'Mexico news','index_mexico');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(184,10,'Miami-Fort Lauderdale news','index_miamifortlauderdale');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(185,1,'Microsoft news','index_microsoft');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(186,5,'Mideast news','index_mideast');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(187,3,'Mining and metals news','index_miningandmetals');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(188,10,'Minneapolis-St Paul news','index_minneapolisstpaul');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(189,3,'Mortgage industry news','index_mortgage');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(190,6,'Sports: motor sports news','index_motorsports');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(191,4,'Movie business news','index_moviebiz');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(192,7,'Entertainment: movie reviews','index_moviereviews');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(193,7,'MP3 news','index_mp3');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(194,4,'Music business news','index_musicbiz');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(195,2,'Mutual funds news','index_mutualfunds');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(196,13,'Consumer: natural health news','index_naturalhealth');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(197,4,'Newspaper publishing news','index_newspapers');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(198,10,'New York City news','index_newyork');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(199,5,'New Zealand news','index_newzealand');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(200,5,'North Africa news','index_northafrica');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(201,11,'Obituaries','index_obituaries');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(202,11,'Offbeat news','index_offbeat');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(203,3,'Oil and gas news','index_oilandgas');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(204,6,'Sports: Olympic sports news','index_olympics');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(205,14,'Online access news','index_onlineaccess');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(206,14,'Online auction news','index_onlineauction');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(207,2,'Online banking news','index_onlinebanking');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(208,2,'Online broker news','index_onlinebroker');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(209,14,'Online content news','index_onlinecontent');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(210,7,'Online games','index_onlinegames');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(211,14,'Online information news','index_onlineinformation');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(212,14,'Online legal issues news','index_onlinelegalissues');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(213,14,'Online marketing news','index_onlinemarketing');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(214,14,'Online portals news','index_onlineportals');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(215,9,'Open source news','index_opensource');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(216,9,'OS news','index_os');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(217,13,'Consumer: outdoor recreation news','index_outdoorrecreation');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(218,3,'Packaging and paper news','index_packagingpaper');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(219,5,'Pakistan news','index_pakistan');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(220,13,'Consumer: parenting news','index_parenting');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(221,9,'PC industry news','index_pcindustry');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(222,9,'PC software news','index_pcsoftware');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(223,11,'Personal data privacy news','index_personaldataprivacy');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(224,2,'Personal finance news','index_personalfinance');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(225,9,'Personal technology news','index_personaltech');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(226,3,'Pharma industry news','index_pharma');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(227,10,'Philadelphia news','index_philadelphia');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(228,1,'Philip Morris news','index_philipmorris');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(229,5,'Philippines news','index_philippines');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(230,10,'Phoenix news','index_phoenix');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(231,10,'Pittsburgh news','index_pittsburgh');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(232,3,'Plastics industry news','index_plastics');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(233,5,'Poland news','index_poland');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(234,7,'Pop music news','index_popmusic');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(235,7,'Pop music reviews','index_popmusicreviews');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(236,10,'Portland-Salem news','index_portlandsalem');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(237,1,'Procter &amp; Gamble news','index_procterandgamble');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(238,12,'Public health news','index_publichealth');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(239,3,'Real estate news','index_realestate');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(240,11,'Religion news','index_religion');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(241,3,'Retail sector news','index_retail');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(242,2,'Retail investor news','index_retailinvestor');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(243,9,'Robotics news','index_robotics');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(244,6,'Sports: rugby news','index_rugby');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(245,5,'Russia news','index_russia');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(246,10,'San Diego news','index_sandiego');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(247,1,'SBC Communications news','index_sbccommunications');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(248,5,'Scandinavia news','index_scandinavia');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(249,12,'Science news','index_science');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(250,12,'Science: biological sciences news','index_sciencebiological');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(251,12,'Science: human sciences news','index_sciencehuman');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(252,12,'Science: physical sciences news','index_sciencephysical');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(253,14,'Online search engines news','index_searchengines');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(254,10,'Seattle-Tacoma news','index_seattletacoma');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(255,2,'Securities industry news','index_securitiesindustry');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(256,9,'Semiconductor industry news','index_semiconductorindustry');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(257,13,'Consumer: seniors news','index_seniors');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(258,3,'Shipping industry news','index_shipping');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(259,10,'Silicon Valley news','index_siliconvalley');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(260,15,'Small business news','index_smallbusiness');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(261,6,'Sports: soccer news','index_soccer');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(262,14,'Software downloads','index_softwaredownloads');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(263,5,'South Africa news','index_southafrica');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(264,5,'Southeast Asia news','index_southeastasia');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(265,12,'Space science news','index_spacescience');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(266,5,'Spain news','index_spain');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(267,3,'Sports business news','index_sportsbusiness');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(268,3,'Steelmaking news','index_steelmaking');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(269,10,'St Louis news','index_stlouis');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(270,2,'Stock Exchanges news','index_stockexchanges');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(271,2,'Stockwatch','index_stockwatch');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(272,5,'Taiwan news','index_taiwan');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(273,10,'Tampa-St Petersburg news','index_tampastpetersburg');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(274,9,'Tech events','index_techevents');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(275,8,'Technology features','index_techfeatures');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(276,8,'Tech latest','index_techlatest');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(277,9,'Tech policy news','index_techpolicy');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(278,2,'Tech stocks news','index_techstocks');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(279,9,'Telecom news','index_telecom');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(280,6,'Sports: tennis news','index_tennis');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(281,3,'Textiles news','index_textiles');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(282,3,'Tobacco industry news','index_tobacco');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(283,8,'Top Asia-Pacific stories','index_topasia');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(284,8,'Top business stories','index_topbusiness');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(285,8,'Consumer: top stories','index_topconsumer');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(286,8,'Top finance stories','index_topfinance');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(287,8,'Top internet stories','index_topinternet');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(288,8,'Top media stories','index_topmedia');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(289,8,'Sports: top stories','index_topsports');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(290,8,'Top stories','index_topstories');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(291,8,'Top technology stories','index_toptechnology');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(292,8,'Top US stories','index_topus');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(293,11,'Trade news','index_trade');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(294,3,'Transportation industry news','index_transportation');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(295,3,'Travel industry news','index_travelindustry');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(296,5,'Turkey news','index_turkey');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(297,11,'UK black interest news','index_ukblackinterest');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(298,15,'UK business news','index_ukbusiness');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(299,11,'UK education news','index_ukeducation');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(300,15,'UK law news','index_uklaw');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(301,4,'UK media news','index_ukmedia');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(302,12,'UK medical news','index_ukmedical');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(303,5,'UK news','index_uknews');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(304,11,'UK politics news','index_ukpolitics');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(305,7,'UK tabloid news','index_uktabloid');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(306,1,'United Technologies news','index_unitedtechnologies');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(307,2,'US banking news','index_usbanking');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(308,11,'US education news','index_useducation');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(309,11,'US immigration news','index_usimmigration');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(310,11,'Police news','index_uspolice');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(311,11,'US political columnists','index_uspoliticalcol');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(312,11,'US politics news','index_uspolitics');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(313,11,'US security news','index_ussecurity');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(314,11,'US social policy news','index_ussocialpolicy');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(315,3,'Utilities news','index_utilities');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(316,2,'Venture capital news','index_venturecapital');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(317,14,'Vertical portals news','index_verticalportals');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(318,7,'Videogame news','index_videogame');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(319,9,'Virus warnings','index_viruswarning');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(320,1,'Wal-Mart Stores news','index_walmart');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(321,1,'Walt Disney news','index_waltdisney');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(322,9,'WAP and 3G news','index_wap');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(323,14,'Web developer news','index_webdeveloper');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(324,14,'Webmaster tips','index_webmastertips');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(325,14,'Website owner news','index_websiteowner');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(326,9,'Windows 2000 news','index_windows');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(327,9,'Wireless sector news','index_wireless');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(328,13,'Consumer: womens news','index_womens');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(329,11,'Womens rights news','index_womensrights');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(330,6,'Sports: wrestling news','index_wrestling');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(331,14,'XML and metadata news','index_xml');
INSERT INTO eNews.eNews.newsCategories(CatID,ChID,Category,XML_IDX) VALUES(332,6,'Sports: yachting news','index_yachting');


INSERT INTO eNews.eNews.newsChannels(ChID,Channel) VALUES(1,'Companies');
INSERT INTO eNews.eNews.newsChannels(ChID,Channel) VALUES(2,'Finance');
INSERT INTO eNews.eNews.newsChannels(ChID,Channel) VALUES(3,'Industry');
INSERT INTO eNews.eNews.newsChannels(ChID,Channel) VALUES(4,'Business: media');
INSERT INTO eNews.eNews.newsChannels(ChID,Channel) VALUES(5,'Regional');
INSERT INTO eNews.eNews.newsChannels(ChID,Channel) VALUES(6,'Sports');
INSERT INTO eNews.eNews.newsChannels(ChID,Channel) VALUES(7,'Entertainment');
INSERT INTO eNews.eNews.newsChannels(ChID,Channel) VALUES(8,'Top stories');
INSERT INTO eNews.eNews.newsChannels(ChID,Channel) VALUES(9,'Technology');
INSERT INTO eNews.eNews.newsChannels(ChID,Channel) VALUES(10,'US regional');
INSERT INTO eNews.eNews.newsChannels(ChID,Channel) VALUES(11,'Society');
INSERT INTO eNews.eNews.newsChannels(ChID,Channel) VALUES(12,'Science');
INSERT INTO eNews.eNews.newsChannels(ChID,Channel) VALUES(13,'Lifestyle');
INSERT INTO eNews.eNews.newsChannels(ChID,Channel) VALUES(14,'Internet');
INSERT INTO eNews.eNews.newsChannels(ChID,Channel) VALUES(15,'Business: general');
