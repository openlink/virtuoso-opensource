--  
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2006 OpenLink Software
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

--  tpcw.sql
--create function get_path () returns varchar
--{
--    declare path varchar;
--    path:= '/mnt/hde1/home_aziz/virtdev/binsrc/samples/TPC-W/';
--    return path;
--}

create procedure ini_base (in numitems numeric(10), in numebs integer)
{
    fill_COUNTRY();
    fill_ADDRESS(2880*numebs);
    fill_AUTHOR(numitems, numitems/4, numitems);
    fill_CUSTOMER(numebs);
    fill_ITEM(numitems,numitems/4,numitems);
    fill_ORDERS(numebs, numitems);
    exec(concat('create function get_num_items () returns numeric(10) {return ',
         cast(numitems as varchar),';}'));        
    exec(concat('create function get_num_ebs () returns integer {return ',
         cast(numebs as varchar),';}'));
    result('PASSED: ini_base');
}
create function NURand (in A integer, in x integer, in y integer) returns numeric(10)
{
--  return ((rnd(A) | (x + rnd(y - x))) % (y - x + 1)) + x;
    return rnd(y-x+1) + x;
}
create function get_A_ebs() returns integer
{
      declare num_customers numeric(10);
      num_customers:= get_num_ebs()*2880;
      if(num_customers < 10000) return 1023;
      else if(num_customers < 40000) return 4095;
      else if(num_customers < 160000) return 16383;
      else if(num_customers < 640000) return 65535;
      else if(num_customers < 2560000) return 262143;
      else if(num_customers < 10240000) return 1048575;
      else if(num_customers < 40960000) return 4194303;
      else if(num_customers < 163840000) return 16777215;
      else return 67108863;
}
create function get_A_items() returns integer
{
      declare num_items numeric(10);
      num_items:= get_num_items();
      if(num_items <= 1000) return 63;
      else if(num_items <= 10000) return 511;
      else if(num_items <= 100000) return 4095;
      else if(num_items <= 1000000) return 32767;
      else return 524287;
}

create function a_string (in x integer, in y integer)  returns varchar
{
  declare length integer;
  declare i integer;
  declare ord integer;
  declare text varchar;
  length:=rnd(y-x+1)+x;
  i:=0;
  text := space(length);
  while (i<length) {
	ord:=rnd(89)+32;
	if (ord=34) {ord:=121;}
	else if (ord=39) {ord:=122;}
	else if (ord=60) {ord:=123;}
	else if (ord=62) {ord:=124;}
	else if (ord=92) {ord:=125;}
	else if (ord=96) {ord:=126;}
	aset (text, i, ord);
	i:=i+1;
  }
  return text;
}

create function n_string (in x integer, in y integer)  returns varchar
{
  declare length integer;
  declare i integer;
  declare ord integer;
  declare text varchar;
  length:=rnd(y-x+1)+x;
  i:=0;
  text := space(length);
  while (i<length) {
	ord:=rnd(10)+48;
	aset (text, i, ord);
	i:=i+1;
  }
  return text;
}

create function DigSyl (in D numeric(10), in N integer) returns varchar
{
  declare i integer;
  declare j integer;
  declare _str varchar;
  declare D_length integer;
  declare D_string varchar;
  declare syllable varchar;
  declare output_string varchar;
  syllable:= 'BAOGALRIRESEATULINNG';
  D_string:= cast(D as varchar);
  D_length:=length(D_string);
  if ((N<D_length) and (N<>0)) signal('TPC-W', 'Assertion failed: (N<D_length) and (N<>0)');
  if (N>D_length) {
     _str := make_string(N-D_length);
     i:=0;
     while (i< (N-D_length)) {
       aset(_str, i, 48);
       i := i + 1;
     }
     D_string:=concat(_str,D_string);
  }
  else if (N=0) N:=D_length;
  output_string:=make_string(2*N);
  i:=0;
  while (i<N) {
       j:=2*(aref(D_string,i)-48);
       aset (output_string, 2*i, aref(syllable,j));
       aset (output_string, 2*i+1, aref(syllable,j+1));
       i:=i+1;
  }
  return output_string;
}  

create function rnd_ORDER_LINE (in _O_ID numeric(10)) returns integer
{
    declare key1 integer;
    declare oldkey integer;
    key1:=rnd(100)+1;
    select count(OL_ID) into oldkey from ORDER_LINE 
	where (OL_O_ID=_O_ID)and (OL_ID=key1);
    if (oldkey <>0) return rnd_ORDER_LINE(_O_ID);	
    else return key1;
}

create procedure fill_ITEM (
    in NUM_ITEMS numeric(10),
    in a integer,
    in i integer)
{
    declare _I_ID		numeric(10); 
    declare _I_TITLE		varchar (60);
    declare _I_A_ID		numeric(10);
    declare _I_PUB_DATE		date;
    declare _I_PUBLISHER	varchar (60);
    declare _I_SUBJECT		varchar (60);
    declare _I_DESC		varchar (500);
    declare _I_RELATED1         numeric(10);
    declare _I_RELATED2         numeric(10);
    declare _I_RELATED3         numeric(10);
    declare _I_RELATED4         numeric(10);
    declare _I_RELATED5         numeric(10);
    declare _I_THUMBNAIL        long varbinary;
    declare _I_IMAGE            long varbinary;
    declare _I_SRP              numeric(15,2);
    declare _I_COST             numeric(15,2);
    declare _I_AVAIL            date;
    declare _I_STOCK            integer;
    declare _I_ISBN             character(13);
    declare _I_PAGE             integer;
    declare _I_BACKING          varchar (15);
    declare _I_DIMENSIONS       varchar (25);
    declare _items varchar;
    declare field_ any;
    declare j,commit_ctr integer;
    declare subjects varchar;
    declare backings any;
    declare size integer; --size of images
    subjects:=vector ('ARTS','BIOGRAPHIES','BUSINESS','CHILDREN',
		      'COMPUTERS','COOKING','HEALTH','HISTORY',
		      'HOME','HUMOR','LITERATURE','MYSTERY',
		      'NON-FICTION','PARENTING','POLITICS','REFERENCE',
		      'RELIGION','ROMANCE','SELF-HELP','SCIENCE-NATURE',
		      'SCIENCE-FICTION','SPORTS','YOUTH','TRAVEL');
    backings:=vector('HARDBACK','PAPERBACK','USED','AUDIO','LIMITED-EDITION');
    system (concat(get_path(),'tpcw -s',cast(NUM_ITEMS as varchar),' -a',cast(a as varchar),
	' -i',cast(i as varchar),' -d',get_path(),'grammar.tpcw -m0 >', get_path(),'field.txt'));
    _items:=file_to_string(concat(get_path(),'field.txt'));
    field_:=split_and_decode(_items,0,'\0\0\n');
    j:=1; commit_ctr := 1;
    while (j <= NUM_ITEMS)  {
        _I_ID:=j;
        _I_TITLE:= aref(field_,j-1);
        if (j<=NUM_ITEMS/4) _I_A_ID:=j;
        else _I_A_ID:=rnd(NUM_ITEMS/4)+1; --I_A_ID  author
        _I_PUB_DATE:=dateadd('day',rnd(datediff('day',stringdate('1930.01.01'),now())+1),
				stringdate('1930.01.01')); --I_PUB_DATE  random date between January 1, 1930 and current date
        _I_PUBLISHER:= a_string(14,60);--I_PUBLISHER  random a-string [14 .. 60]
	_I_SUBJECT:=aref (subjects,rnd(24));
        _I_DESC:=a_string(100,500);--I_DESC random a-string [100 .. 500]
	system (concat(get_path(),'tpcwIMG 5 ',get_path(),'html/imagegen/t_',cast(_I_ID as varchar),'.jpg'));
	_I_THUMBNAIL:=file_to_string(concat(get_path(),'html/imagegen/t_',cast(_I_ID as varchar),'.jpg')); --graphic object, generated according to Clause 4.6.2.13
	size:=rnd(100);
        if (size=0) size:=250;
	else if (size<=4) size:=100;
	else if (size<20) size:=50;
	else if (size<55) size:=10;
	else size:=5;
	system (concat(get_path(),'tpcwIMG ',cast(size as varchar),' ',get_path(),'html/imagegen/i_',cast(_I_ID as varchar),'.jpg'));
	_I_IMAGE:=file_to_string(concat(get_path(),'html/imagegen/i_',cast(_I_ID as varchar),'.jpg')); --graphic object, generated according to Clause 4.6.2.13
	_I_SRP:=(rnd(999900)+100)/100.0; --I_SRP random within [1.00 .. 9,999.99]
	_I_COST:=_I_SRP-rnd(6)/10.0*_I_SRP; --I_COST generated as I_SRP - (random within [(0 .. 0.5) * I_SRP])
	_I_AVAIL:= dateadd('day', rnd(30)+1,_I_PUB_DATE);--I_AVAIL generated as I_PUB_DATE + (random within [1 .. 30] days)
	_I_STOCK:=rnd(21)+10; --I_STOCK random within [10 .. 30]
        _I_ISBN:=a_string(13,13);--I_ISBN random a-string of 13 characters
	_I_PAGE:=rnd(9980)+20;--I_PAGE random within [20 .. 9,999]
	_I_BACKING:=aref (subjects,rnd(5));--I_BACKING, variable size text, generated according to Clause 4.6.2.16
	_I_DIMENSIONS:=concat(cast((rnd(9999)+1)/100.0 as varchar), ' x ',
		cast((rnd(9999)+1)/100.0 as varchar), ' x ', 
		cast((rnd(9999)+1)/100.0 as varchar)); --I_DIMENSIONS (length x width x height of the book), concatenation of 3 random numeric values within  [0.01..99.99],  separated by an "x".

	insert into ITEM(I_ID,I_TITLE,I_A_ID,I_PUB_DATE,I_PUBLISHER,
			I_SUBJECT,I_DESC,
			I_RELATED1,I_RELATED2,I_RELATED3,I_RELATED4,I_RELATED5,
			I_THUMBNAIL,I_IMAGE,I_SRP,I_COST,I_AVAIL,I_STOCK,
			I_ISBN,I_PAGE,I_BACKING,I_DIMENSIONS) 
        values(_I_ID,_I_TITLE,_I_A_ID,_I_PUB_DATE,_I_PUBLISHER,
			_I_SUBJECT,_I_DESC,
--			_I_RELATED1,_I_RELATED2,_I_RELATED3,_I_RELATED4,_I_RELATED5,
			0,0,0,0,0,
			_I_THUMBNAIL,_I_IMAGE,_I_SRP,_I_COST,_I_AVAIL,_I_STOCK,
			_I_ISBN,_I_PAGE,_I_BACKING,_I_DIMENSIONS);
	commit_ctr := commit_ctr+1;
	if (commit_ctr = 1000)
	  {
	    commit work;
	    commit_ctr := 0;
	  }
	j:=j+1;
  }
    j:=1; commit_ctr := 1;
    while (j <= NUM_ITEMS)  {
	_I_RELATED1:=rnd(NUM_ITEMS)+1; --I_RELATED1 to I_RELATED5 generated as 5 random and unique I_ID's
	_I_RELATED2:=rnd(NUM_ITEMS)+1;
	while (_I_RELATED1=_I_RELATED2) {
		_I_RELATED2:=rnd(NUM_ITEMS)+1;
        }
	_I_RELATED3:=rnd(NUM_ITEMS)+1;
	while ((_I_RELATED1=_I_RELATED3) or (_I_RELATED2=_I_RELATED3)) {
		_I_RELATED3:=rnd(NUM_ITEMS)+1;
        }
	_I_RELATED4:=rnd(NUM_ITEMS)+1;
	while ((_I_RELATED1=_I_RELATED4) or (_I_RELATED2=_I_RELATED4) or (_I_RELATED3=_I_RELATED4)) {
		_I_RELATED4:=rnd(NUM_ITEMS)+1;
        }
	_I_RELATED5:=rnd(NUM_ITEMS)+1;
	while ((_I_RELATED1=_I_RELATED5) or (_I_RELATED2=_I_RELATED5) or (_I_RELATED3=_I_RELATED5)or (_I_RELATED4=_I_RELATED5)) {
		_I_RELATED5:=rnd(NUM_ITEMS)+1;
        }
	update ITEM set I_RELATED1 = _I_RELATED1, I_RELATED2 = _I_RELATED2, I_RELATED3 = _I_RELATED3, I_RELATED4 = _I_RELATED4, I_RELATED5 = _I_RELATED5
	  where I_ID = j;
	commit_ctr := commit_ctr+1;
	if (commit_ctr = 1000)
	  {
	    commit work;
	    commit_ctr := 0;
	  }
	j:=j+1;
  }
  result('PASSED: fill_ITEM');
}



create procedure fill_COUNTRY ()
{
	declare i integer;
	declare countries any;
	declare exchanges any;
	declare currencies any;
	declare _CO_ID       integer;
	declare _CO_NAME     varchar (50);
	declare _CO_EXCHANGE numeric(6,6);
	declare _CO_CURRENCY varchar (18);
        countries:=vector('United States', 'United Kingdom', 'Canada','Germany',
			'France','Japan','Netherlands','Italy',
			'Switzerland','Australia','Algeria','Argentina',
			'Armenia','Austria','Azerbaijan','Bahamas',
			'Bahrain','Bangla Desh','Barbados','Belarus',
			'Belgium','Bermuda','Bolivia','Botswana',
			'Brazil','Bulgaria','Cayman Islands','Chad',
			'Chile','China','Renmimbi Christmas Island','Colombia',
			'Croatia','Cuba','Cyprus','Czech Republic',
			'Denmark','Dominican Republic','Eastern Caribbean','Ecuador',
			'Egypt','El Salvador','Estonia','Ethiopia',
			'Falkland Island','Faroe Island','Fiji','Finland',
			'Gabon','Gibraltar','Greece','Guam',
			'Hong Kong','Hungary','Iceland','India',
			'Indonesia','Iran','Iraq','Ireland',
			'Israel','Jamaica','Jordan','Kazakhstan',
			'Kuwait','Lebanon','Luxembourg','Malaysia',
			'Mexico','Mauritius','New Zealand','Norway',
			'Pakistan','Philippines','Poland','Portugal',
			'Romania','Russia','Saudi Arabia','Singapore',
			'Slovakia','South Africa','South Korea','Spain',
			'Sudan','Sweden','Taiwan','Thailand',
			'Trinidad','Turkey','Venezuela','Zambia');
        exchanges:=vector(1, 0.625461, 1.46712, 1.86125, 6.24238, 121.907, 2.09715,
			1842.64, 1.51645, 1.54208, 65.3851, 0.998, 540.92, 13.0949,
			3977, 1, 0.3757, 48.65, 2, 248000, 38.3892,
			1, 5.74, 4.7304, 1.71, 1846, 0.8282 ,627.1999,
			494.2, 8.278, 1.5391, 1677, 7.3044, 23, 0.543,
			36.0127, 7.0707, 15.8, 2.7, 9600, 3.33771, 8.7,
			14.9912, 7.7, 0.6255, 7.124, 1.9724, 5.65822, 627.1999,
			0.6255, 309.214, 1, 7.75473, 237.23, 74.147, 42.75,
			8100, 3000, 0.3083, 0.749481, 4.12, 37.4, 0.708,
			150, 0.3062, 1502, 38.3892, 3.8, 9.6287, 25.245, 1.87539,
			7.83101, 52, 37.8501, 3.9525, 190.788, 15180.2, 24.43,
			3.7501, 1.72929, 43.9642, 6.25845, 1190.15, 158.34, 5.282,
			8.54477, 32.77, 37.1414, 6.1764, 401500, 596, 2447.7);
        currencies:= vector('Dollars', 'Pounds', 'Dollars', 'Deutsche Marks',
			 'Francs', 'Yen', 'Guilders', 'Lira',
			 'Francs', 'Dollars', 'Dinars', 'Pesos',
			 'Dram', 'Schillings', 'Manat', 'Dollars',
			 'Dinar', 'Taka', 'Dollars', 'Rouble',
			 'Francs', 'Dollars', 'Boliviano', 'Pula',
			 'Real', 'Lev', 'Dollars', 'Franc',
			 'Pesos', 'Yuan', 'Dollars', 'Pesos',
			 'Kuna', 'Pesos', 'Pounds', 'Koruna',
			 'Kroner', 'Pesos', 'Dollars', 'Sucre',
			 'Pounds', 'Colon', 'Kroon', 'Birr',
			 'Pound', 'Krone', 'Dollars', 'Markka',
			 'Franc', 'Pound', 'Drachmas', 'Dollars',
			 'Dollars', 'Forint', 'Krona', 'Rupees',
			 'Rupiah', 'Rial', 'Dinar', 'Punt',
			 'Shekels', 'Dollars', 'Dinar', 'Tenge',
			 'Dinar', 'Pounds', 'Francs', 'Ringgit',
			 'Pesos', 'Rupees', 'Dollars', 'Kroner',
			 'Rupees', 'Pesos', 'Zloty', 'Escudo',
			 'Leu', 'Rubles', 'Riyal', 'Dollars',
			 'Koruna', 'Rand', 'Won', 'Pesetas',
			 'Dinar', 'Krona', 'Dollars', 'Baht',
			 'Dollars', 'Lira', 'Bolivar', 'Kwacha');

  i:=1;
dbg_obj_print('fill_COUNTRY');
  while (i <=92)  {
	insert into COUNTRY(CO_ID,CO_NAME,CO_EXCHANGE, CO_CURRENCY ) 
		values(i,aref(countries,i-1),aref(exchanges,i-1),
			aref(currencies,i-1));
	i:=i+1;
  }
    result('PASSED: fill_COUNTRY');
}

--	(NUM_ITEMS / 4) rows in the AUTHOR table with:
--	A_ID unique within [1 .. (NUM_ITEMS/4)]
--	A_FNAME random a-string [3 .. 20]
--	A_MNAME random a-string [1 .. 20]
--	A_LNAME generated using the TPC-W DBGEN utility described in Appendix H
--	A_BIO random a-string [125 .. 500]

create procedure fill_AUTHOR (
    in NUM_ITEMS numeric(10),
    in a integer,
    in i integer)
{
  declare NUM_AUTHOR integer;
  declare author_name varchar;
  declare _LNAME any;
  declare j integer;
  declare _A_FNAME varchar(20);
  declare _A_MNAME varchar(20);
  declare _A_DOB   date;
  declare _A_BIO   varchar(500);
  NUM_AUTHOR:=NUM_ITEMS/4;
  system (concat(get_path(),'tpcw -s',cast(NUM_AUTHOR as varchar),
        ' -a',cast(NUM_AUTHOR as varchar),
	' -i',cast(i as varchar),' -d',get_path(),'grammar.tpcw -m1 >',get_path(),'lname.txt'));
  author_name:=file_to_string(concat(get_path(),'lname.txt'));
  _LNAME:=split_and_decode(author_name,0,'\0\0\n');
  j:=1;
  dbg_obj_print('fill_AUTHOR');
  while (j <= NUM_AUTHOR)  {
	_A_FNAME:=a_string(3,20);
	_A_MNAME:=a_string(1,20);
--A_DOB random date between January 1, 1800 and January 1, 1990
        _A_DOB:=dateadd('day',rnd(datediff('day',stringdate('1800.01.01'),
				stringdate('1990.01.01'))+1),
			stringdate('1800.01.01'));
	_A_BIO:=a_string(125,500);
	insert into AUTHOR(A_ID,A_FNAME,A_LNAME,A_MNAME,A_DOB,A_BIO) 
		values(j,_A_FNAME, aref(_LNAME,j-1),_A_MNAME,_A_DOB,_A_BIO);
		j:=j+1;
  }
  result('PASSED: fill_AUTHOR');
}


create procedure fill_CUSTOMER (in num_EBs numeric(10))
{
  declare i numeric(10);
  declare _C_ID numeric(10); --unique within [1 .. 2880 * # EB's]
  declare _C_UNAME varchar (20);--generated according to Clause 4.6.2.10
  declare _C_PASSWD varchar (20);--generated according to Clause 4.6.2.11
  declare _C_FNAME varchar (15);--random a-string [8 .. 15]
  declare _C_LNAME varchar (15);--random a-string [8 .. 15]
  declare _C_ADDR_ID numeric(15,2);--random within [1 .. 2 * 2880 * # EB's]
  declare _C_PHONE varchar (16);--random n-string [9 .. 16]
  declare _C_EMAIL varchar (50);--generated according to Clause 4.6.2.14
  declare _C_SINCE date;--generated as current date - random within [1 .. 730] days
  declare _C_LAST_VISIT date;--generated as C_SINCE + random within [0 .. 60] days, but not exceeding the current date
  declare _C_LOGIN datetime;--date/time given by the operating system when the table was populated
  declare _C_EXPIRATION datetime;--generated as C_LOGIN + 2 hours
  declare _C_DISCOUNT numeric(3,2);--random within [0.00 .. 0.50]
  declare _C_BALANCE numeric(15,2);--= 0.00
  declare _C_YTD_PMT numeric(15,2);--random within [0.00 .. 999.99]
  declare _C_BIRTHDATE date;--random date between January 1, 1880 and current date
  declare _C_DATA varchar (500);--random a-string [100 .. 500]
  i:=1;
dbg_obj_print('fill_CUSTOMER');
  while (i <= 2880*num_EBs)  {
    _C_ID:=i;
    _C_UNAME:= DigSyl(_C_ID, 0);
    _C_PASSWD:= lcase(_C_UNAME);
    _C_FNAME:= a_string(8,15);
    _C_LNAME:= a_string(8,15);
    _C_ADDR_ID:=rnd(2*2880*num_EBs)+1;
    _C_PHONE:=n_string(9,16);
    _C_EMAIL:=concat(_C_UNAME,'@',a_string(2,9),'.com');
    _C_SINCE:= dateadd('day', -(rnd(730)+1),now());
    _C_LAST_VISIT:=dateadd('day', rnd(61),_C_SINCE);
    _C_LOGIN:= now();
    _C_EXPIRATION:= dateadd('hour',2,_C_LOGIN);
    _C_DISCOUNT:=rnd(51)/100.0;
    _C_BALANCE:=0.0;
    _C_YTD_PMT:= rnd(100000)/100.0;
    _C_BIRTHDATE:= dateadd('day',rnd(datediff('day',stringdate('1880.01.01'),now())+1),
			stringdate('1880.01.01'));
    _C_DATA:= a_string(100,500);
    insert into CUSTOMER(C_ID,C_UNAME,C_PASSWD,C_FNAME,C_LNAME,C_ADDR_ID,
			C_PHONE,C_EMAIL,C_SINCE,C_LAST_VISIT,C_LOGIN,
			C_EXPIRATION,C_DISCOUNT,C_BALANCE,C_YTD_PMT,
			C_BIRTHDATE,C_DATA) 
		values(_C_ID,_C_UNAME,_C_PASSWD,_C_FNAME,_C_LNAME,_C_ADDR_ID,
			_C_PHONE,_C_EMAIL,_C_SINCE,_C_LAST_VISIT,_C_LOGIN,
			_C_EXPIRATION,_C_DISCOUNT,_C_BALANCE,_C_YTD_PMT,
			_C_BIRTHDATE,_C_DATA);
		i:=i+1;
  }
  result('PASSED: fill_CUSTOMER');
}	
  
create procedure fill_ORDERS (in num_EBs numeric(10), in NUM_ITEMS numeric(10))
{
  declare i numeric(10);
  declare NUM_CUSTOMERS numeric(10);
  declare _O_ID            numeric(10);
  declare _O_C_ID          numeric(10);
  declare _O_DATE          datetime;
  declare _O_SUB_TOTAL     numeric(15,2);
  declare _O_TAX           numeric(15,2);
  declare _O_TOTAL         numeric(15,2);
  declare _O_SHIP_TYPE     varchar (10);
  declare _O_SHIP_DATE     datetime;
  declare _O_BILL_ADDR_ID  numeric(10);
  declare _O_SHIP_ADDR_ID  numeric(10);
  declare _O_STATUS        varchar (15);
  declare shiptypes any;
  declare statuses any;
  shiptypes:=vector('AIR','UPS','FEDEX','SHIP','COURIER','MAIL');
  statuses:=('PROCESSING','SHIPPED','PENDING','DENIED');
  i:=1;
  NUM_CUSTOMERS:=2880*num_EBs;
dbg_obj_print('fill_ORDER');
  while (i <= 288*9*num_EBs)  {
    _O_ID:= i; -- unique within [1 .. (0.9 * NUM_CUSTOMERS)]
    _O_C_ID:= rnd(NUM_CUSTOMERS)+1; -- random within [1 .. NUM_CUSTOMERS]
    _O_DATE:= dateadd('day', -(rnd(60)+1),now()); -- generated as current date and time - random within [1 .. 60] days
    _O_SUB_TOTAL:= (rnd(999000)+1000)/100.0; -- random within [10.00 .. 9999.99]
    _O_TAX:= _O_SUB_TOTAL*0.0825; -- generated as O_SUB_TOTAL * 0.0825
    _O_TOTAL:= _O_SUB_TOTAL+_O_TAX+ 3.00; -- generated as O_SUB_TOTAL + O_TAX + 3.00 + (1.00 * count_of_items_in_order, last item is added in ORDER_LINE 
--    fill_ORDER_LINE (_O_ID, NUM_ITEMS, _O_TOTAL );
    _O_SHIP_TYPE:= aref(shiptypes,rnd(length(shiptypes))); -- selected at random from the following:AIR, UPS, FEDEX, SHIP, COURIER, MAIL 
    _O_SHIP_DATE:= dateadd('day', rnd(8),_O_DATE); -- generated as O_DATE + random within [0 .. 7] days
    _O_BILL_ADDR_ID:= rnd(2*NUM_CUSTOMERS)+1; -- = random within [1 .. (2 * NUM_CUSTOMERS)]
    _O_SHIP_ADDR_ID:= rnd(2*NUM_CUSTOMERS)+1; -- = random within [1 .. (2 * NUM_CUSTOMERS)]
    _O_STATUS:= aref(shiptypes,rnd(length(statuses))); -- selected at random from the following:PROCESSING, SHIPPED, PENDING, DENIED 
--    fill_CC_XACTS (_O_ID,_O_TOTAL _O_SHIP_DATE );
    insert into ORDERS(O_ID,O_C_ID,O_DATE,O_SUB_TOTAL,O_TAX,
			O_SHIP_TYPE,O_SHIP_DATE,O_BILL_ADDR_ID,O_SHIP_ADDR_ID,
			O_STATUS)
		values(_O_ID,_O_C_ID,_O_DATE,_O_SUB_TOTAL,_O_TAX,
			_O_SHIP_TYPE,_O_SHIP_DATE,_O_BILL_ADDR_ID,_O_SHIP_ADDR_ID,
			_O_STATUS);
    fill_ORDER_LINE (_O_ID, NUM_ITEMS, _O_TOTAL );
    fill_CC_XACTS (_O_ID,_O_TOTAL, _O_SHIP_DATE );
    i:=i+1;
  }
  result('PASSED: fill_ORDERS');
}

create procedure fill_ORDER_LINE (in _O_ID numeric(10), in NUM_ITEMS numeric(10), inout _O_TOTAL numeric(15,2) )
{
    declare num_order integer; -- For each row in the ORDERS table, num_oreder is a number of rows in the ORDER_LINE table 
    declare i integer;
    declare _OL_ID        numeric(3);
    declare _OL_O_ID      numeric(10);
    declare _OL_I_ID      numeric(10);
    declare _OL_QTY       numeric(3);
    declare _OL_DISCOUNT  numeric(3,2);
    declare _OL_COMMENTS  varchar(100);
    declare num_ordered_items integer; -- all ordered items for O_ID 
    num_order:=rnd(5)+1;
    num_ordered_items:=0;
	--'DB.DBA.db.dba.ORDER_LINE._OL_ID'
    i:=1;
    while (i <= num_order)  {
       	_OL_ID:= rnd_ORDER_LINE (_O_ID); --unique within [1 .. 100]
	_OL_O_ID:= _O_ID;  --= O_ID 
	_OL_I_ID:= rnd(NUM_ITEMS)+1;  --random within [1 .. NUM_ITEMS]
	_OL_QTY:= rnd(300)+1;  --random within [1 .. 300]
	_OL_DISCOUNT:= rnd(4)/100.0;  --random within [0.00 .. 0.03]
	_OL_COMMENTS:=a_string(20,80);   --random a-string [20 .. 100]
	num_ordered_items:=num_ordered_items+_OL_QTY;
    	insert into ORDER_LINE(OL_ID,OL_O_ID,OL_I_ID, OL_QTY,OL_DISCOUNT,OL_COMMENTS)
		values(_OL_ID,_OL_O_ID,_OL_I_ID, _OL_QTY,_OL_DISCOUNT,_OL_COMMENTS);
	i:=i+1;
    }
    _O_TOTAL:=_O_TOTAL+num_ordered_items;
    update ORDERS set O_TOTAL=_O_TOTAL where (O_ID=_O_ID);
}

create procedure fill_CC_XACTS (in _O_ID numeric(10), 
				in _O_TOTAL numeric(15,2), 
				in _O_SHIP_DATE datetime ) -- (1 * NUM_ORDERS) rows in the CC_XACTS table
{
    declare _CX_O_ID            numeric(10);
    declare _CX_TYPE            varchar(10);
    declare _CX_NUM             numeric(16);
    declare _CX_NAME            varchar(31);
    declare _CX_EXPIRY          date;
    declare _CX_AUTH_ID         character(15);
    declare _CX_XACT_AMT        numeric(15,2);
    declare _CX_XACT_DATE       datetime;
    declare _CX_CO_ID           numeric(4);
    declare card_type any;
    card_type:= vector('VISA','MASTERCARD','DISCOVER','AMEX','DINERS');
    _CX_O_ID:= _O_ID;
    _CX_TYPE:= aref(card_type, rnd(length(card_type)));  --selected at random from the following:VISA, MASTERCARD, DISCOVER, AMEX, DINERS
    _CX_NUM:= n_string(16,16);  --random n-string of 16 digits
    _CX_NAME:= a_string(14,30);  --random a-string [14 .. 30]
    _CX_EXPIRY:=dateadd('day',rnd(721)+10,now());   --current date + random within [10 .. 730] days
    _CX_AUTH_ID:= a_string(15,15);  --random a-string of 15 characters
    _CX_XACT_AMT:= _O_TOTAL;  --= O_TOTAL
    _CX_XACT_DATE:= _O_SHIP_DATE;  --= O_SHIP_DATE
    _CX_CO_ID:= rnd(92)+1;  --random within [1 .. 92]
    insert into CC_XACTS(CX_O_ID,CX_TYPE,CX_NUM,CX_NAME,CX_EXPIRY,
			CX_AUTH_ID,CX_XACT_AMT,CX_XACT_DATE,CX_CO_ID)
		values(_CX_O_ID,_CX_TYPE,_CX_NUM,_CX_NAME,_CX_EXPIRY,
			_CX_AUTH_ID,_CX_XACT_AMT,_CX_XACT_DATE,_CX_CO_ID);
}

create procedure fill_ADDRESS (in NUM_CUSTOMERS numeric(10) ) 
{
    declare i  numeric(10);
    declare _ADDR_ID            numeric(10);
    declare _ADDR_STREET1       varchar(40);
    declare _ADDR_STREET2       varchar(40);
    declare _ADDR_CITY          varchar(30);
    declare _ADDR_STATE         varchar(20);
    declare _ADDR_ZIP           varchar(10);
    declare _ADDR_CO_ID         numeric(4);
    i:=1;
dbg_obj_print('fill_ADDRESS');
    while (i <= 2*NUM_CUSTOMERS)  {
	_ADDR_ID:= i;   -- unique within [1 .. (2 * NUM_CUSTOMERS)]
	_ADDR_STREET1:= a_string(15,40);  -- random a-string [15 .. 40]
	_ADDR_STREET2:= a_string(15,40); -- random a-string [15 .. 40]
	_ADDR_CITY:= a_string(4,30);  -- random a-string [4 .. 30]
	_ADDR_STATE:= a_string(2,20); -- random a-string [2 .. 20]
	_ADDR_ZIP:= a_string(5,10);   -- random a-string [5 .. 10]
	_ADDR_CO_ID:= rnd(92)+1;   -- random within [1 .. 92]
    	insert into ADDRESS(ADDR_ID,ADDR_STREET1,ADDR_STREET2,ADDR_CITY,
			ADDR_STATE,ADDR_ZIP,ADDR_CO_ID)
		values(_ADDR_ID,_ADDR_STREET1,_ADDR_STREET2,_ADDR_CITY,
			_ADDR_STATE,_ADDR_ZIP,_ADDR_CO_ID);
	i:=i+1;
    }
    result('PASSED: fill_ADDRESS');
}

--Create procedure update_item (in iid numeric(10), in
	
