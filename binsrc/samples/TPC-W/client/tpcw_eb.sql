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

create function a_string(
    in x integer,
    in y integer) returns varchar
{
    declare length integer;
    declare i integer;
    declare ord integer;
    declare text varchar;
    length:=rnd(y-x+1)+x;
    i:=0;
    text := space(length);
    while (i<length)
    {
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

create function n_string(
    in x integer,
    in y integer) returns varchar
{
    declare length integer;
    declare i integer;
    declare ord integer;
    declare text varchar;
    length:=rnd(y-x+1)+x;
    i:=0;
    text := space(length);
    while (i<length)
    {
        ord:=rnd(10)+48;
        aset (text, i, ord);
        i:=i+1;
    }
    return text;
}

create function NURand (in A integer, in x integer, in y integer) returns numeric(10)
{
--  return ((rnd(A) | (x + rnd(y - x))) % (y - x + 1)) + x;
    return rnd(y-x+1) + x;
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
    syllable := 'BAOGALRIRESEATULINNG';
    D_string := cast(D as varchar);
    D_length := length(D_string);
    if ((N < D_length) and (N <> 0))
	signal('TPC-W', 'Assertion failed: (N<D_length) and (N<>0)');
    if (N > D_length)
    {
	_str := make_string(N-D_length);
	i:=0;
	while (i < (N - D_length))
	{
	    aset(_str, i, 48);
	    i := i + 1;
	}
	D_string:=concat(_str,D_string);
    }
    else if (N = 0)
	N := D_length;
    output_string := make_string(2 * N);
    i := 0;
    while (i < N)
    {
	j := 2 * (aref(D_string, i) - 48);
	aset(output_string, 2 * i, aref(syllable, j));
	aset(output_string, 2 * i + 1, aref(syllable, j + 1));
	i := i + 1;
    }
    return output_string;
}

create function get_A_items() returns integer
{
    declare num_items numeric(10);
    num_items := get_num_items();
    if (num_items <= 1000) return 63;
    else if(num_items <= 10000) return 511;
    else if(num_items <= 100000) return 4095;
    else if(num_items <= 1000000) return 32767;
    else return 524287;
} 

create function get_A_ebs() returns integer
{
    declare num_customers numeric(10);
    num_customers := get_num_ebs() * 2880;
    if (num_customers < 10000) return 1023;
    else if(num_customers < 40000) return 4095;
    else if(num_customers < 160000) return 16383;
    else if(num_customers < 640000) return 65535;
    else if(num_customers < 2560000) return 262143;
    else if(num_customers < 10240000) return 1048575;
    else if(num_customers < 40960000) return 4194303;
    else if(num_customers < 163840000) return 16777215;
    else return 67108863;
} 

create function _runURL(
    in page varchar,
    in request varchar) returns varchar
{
    declare header any;
    declare server, url, res varchar;    
    
    server := getURL();
    
    --server := 'http://duple:9301/tpcw/html/';
    dbg_printf('http query: %s?%s', cast(page as varchar),cast(request as varchar));
    url := concat(server, cast(page as varchar));
    res := http_get(url, header, 'POST', '', cast(request as varchar));
    if (aref (header, 0) not like '% 200%')
	result (sprintf('***FAILED: Failed to recieve: %s', cast(request as varchar)));
    return res;
}

create function _runAdminConfirm(
    in c_id varchar,
    in shopping_id varchar,
    in i_id varchar,
--    inout I_NEW_IMAGE varchar,
--    inout I_NEW_THUMB varchar,    
    in I_NEW_COST varchar)
{
    declare query, reply varchar;
    declare tmp1, tmp2 numeric(15,2);
    
    query := sprintf('C_ID=%U&Shopping_Id=%U&I_ID=%U&I_NEW_COST=%U', cast(c_id as varchar), cast(Shopping_Id as varchar),
	cast(I_ID as varchar), cast(I_NEW_COST as varchar));
    reply := _runURL('adminconfirm.vsp', query);
}

create function getRandomImage() returns varchar
{
    return concat(get_path(),'/html/imagegen/i_',cast(rnd(get_num_items())+1 as varchar),'.jpg');
}

create function getRandomThumb() returns varchar
{
    concat(get_path(),'/html/imagegen/t_',cast(rnd(get_num_items())+1 as varchar),'.jpg');
}

create function _runAdminRequest(
    in c_id varchar,
    in shopping_id varchar,
    in i_id varchar,
--    inout I_NEW_IMAGE varchar,
--    inout I_NEW_THUMB varchar,
    inout I_NEW_COST varchar)
{
    declare query, reply varchar;
    declare tmp1, tmp2 numeric(15,2);

    if (atoi(cast(i_id as varchar)) = 0)
	i_id := cast((rnd(get_num_items()) +1) as varchar);
    
    query := sprintf('C_ID=%U&Shopping_Id=%U&I_ID=%U', c_id, shopping_id, i_id);
    reply := _runURL('adminrequest.vsp', query);
--    I_NEW_IMAGE := getRandomImage();
--    I_NEW_THUMB := getRandomThumb();    
    tmp1 := (rnd(999900)+100)/100.0;
    tmp2 := tmp1 - rnd(6)/10.0*tmp1;
    I_NEW_COST := cast(tmp2 as varchar);
}

create function _runBestSellers(
    in c_id varchar,
    in shopping_id varchar,
    in subject varchar)
{
    declare query, reply varchar;
    
    query := sprintf('subject=%U&C_ID=%U&Shopping_Id=%U', SUBJECT, C_ID, Shopping_Id);
    reply := _runURL('bestsellers.vsp', query);
}

create function _runBuyConfirm(
    in C_ID varchar,
    in SHOPPING_ID varchar,
    in CCTYPE varchar,
    in CCNUMBER varchar,
    in CCNAME varchar,
    in CCDATE varchar,
    in SHIPPING varchar,
    in STREET1 varchar,
    in STREET2 varchar,
    in CITY varchar,
    in STATE varchar,
    in COUNTRY varchar,
    in ZIP varchar)
{
    declare query, reply varchar;
    
    query := concat('C_ID=%U&Shopping_Id=%U&cctype=%U&ccnum=%U&ccname=%U&ccdate=%U&shipmethod=%U&shipadd1=%U&shipadd2=%U&shipzip=%U&shipcity=%U&shipcountry=%U&shipstate=%U',
	C_ID, SHOPPING_ID, CCTYPE, CCNUMBER, CCNAME, CCDATE,
	SHIPPING, STREET1, STREET2, ZIP, CITY, COUNTRY, STATE);
    reply := _runURL('buyconfirm.vsp', query);
}

create function test() returns varchar
{
    declare c_id, shopping_id, username, pass,
     firstname,
    lastname,
    birthday,
    street1,
    street2,
    city,
    state,
    zip,
    country,
    phone,
    email,
    data,
    cctype,
    ccnumber,
    ccname,
    ccdate,
    shipping,
    add_flag,
    returning_flag varchar;
    
    c_id := '0';
    shopping_id := '0';
    add_flag := 'N';
    
    return _runBuyRequest(c_id, shopping_id, username, pass,
     firstname,
    lastname,
    birthday,
    street1,
    street2,
    city,
    state,
    zip,
    country,
    phone,
    email,
    data,
    cctype,
    ccnumber,
    ccname,
    ccdate,
    shipping,
    add_flag,
    returning_flag);
}

create function _runBuyRequest(
    inout c_id varchar,
    inout shopping_id varchar,
    inout username varchar,
    inout pass varchar,
    inout firstname varchar,
    inout lastname varchar,
    inout birthday varchar,
    inout street1 varchar,
    inout street2 varchar,
    inout city varchar,
    inout state varchar,
    inout zip varchar,
    inout country varchar,
    inout phone varchar,
    inout email varchar,
    inout data varchar,
    inout cctype varchar,
    inout ccnumber varchar,
    inout ccname varchar,
    inout ccdate varchar,
    inout shipping varchar,
    inout add_flag varchar,
    inout returning_flag varchar) returns varchar
{
    declare query, reply, countries, ship_methods, cctypes varchar;
    declare ccexpiry date;
    declare tree any;
    
    if (atoi(cast(c_id as varchar)) > 0)
    {
	username := DigSyl(c_id, 0);
	pass := lcase(DigSyl(c_id,0));
	country := '';
	firstname := '';
	lastname := '';
	street1 := '';
	street2 := '';
	city := '';
	state := '';
	zip := '';
	phone := '';
	email := '';
	birthday := '';
	data := '';
	returning_flag := 'Y';
    }
    else
    {
       firstname := a_string(8, 15);
       lastname := a_string(8, 15);
       street1 := a_string(15, 40);
       street2 := a_string(15, 40);
       city := a_string(4, 30);
       state := a_string(2, 20);
       zip := a_string(5, 10);
       phone := n_string(9, 16);
       email:= concat(firstname, '@', lastname, '.com');
       birthday := left(cast(dateadd('day',rnd(datediff('day',stringdate('1880.01.01'), now())+1),stringdate('1880.01.01')) as varchar), 10);
       data := a_string(100, 500);
       countries := vector('United States', 'United Kingdom', 'Canada','Germany',
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
	country := aref(countries, rnd(92));
       returning_flag := 'N';
    }

    if (RETURNING_FLAG = 'N')
	query := sprintf('C_ID=%U&Shopping_Id=%U&RETURNING_FLAG=N&birthday=%U&firstname=%U&lastname=%U&lastname=%U&address1=%U&address2=%U&city=%U&state=%U&zip=%U&country=%U&phone=%U&email=%U&data=%U',
	    C_ID, shopping_id, BIRTHDAY, FIRSTNAME, LASTNAME, LASTNAME, street1,
	    street2, CITY, STATE, ZIP, COUNTRY, PHONE,
	    EMAIL, DATA);
    else if (RETURNING_FLAG = 'Y')
	query := sprintf('C_ID=%U&Shopping_Id=%U&RETURNING_FLAG=Y&username=%U&password=%U',
	    C_ID, shopping_id, USERNAME, PASS);
    reply := _runURL('buyrequest.vsp', query);

    tree := xtree_doc(reply, 1, '', 'ISO');
    C_ID := xpath_eval('//input[@name="C_ID"]/@value', tree);
    cctypes := vector('VISA','MASTERCARD','DISCOVER','AMEX','DINERS');
    CCTYPE := aref(cctypes, rnd(5));
    CCNAME := concat(FIRSTNAME, ' ', LASTNAME);
    ccexpiry := dateadd('day', rnd(730)+1, now());
    CCDATE := left(cast(ccexpiry as varchar), 10);
    ship_methods := vector('AIR', 'UPS', 'FEDEX', 'SHIP', 'COURIER', 'MAIL');
    shipping := aref(ship_methods, rnd(6));
    CCNUMBER := n_string(16, 16);    
    add_flag := 'N';
    
    if (1+rnd(99) < 5)
    {
	street1 := a_string(15, 40);
	street2 := a_string(15, 40);
	CITY := a_string(4, 30);
	STATE := a_string(2, 20);
	ZIP := a_string(5, 10);
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
	COUNTRY := aref(countries, rnd(92));
    }
}

create function _runCustRegist(
    in c_id varchar,
    in shopping_id varchar) returns varchar
{
    declare query varchar;
    
    query := sprintf('C_ID=%U&Shopping_Id=%U', c_id, shopping_id);
    _runURL('customerregistration.vsp', query);
}

create function _runHome(
    in c_id varchar,
    in shopping_id varchar,
    inout subject varchar,
    inout add_flag varchar)
{
    declare query varchar;
    declare subjects varchar;
    
    query := sprintf('C_ID=%U&Shopping_Id=%U', cast(c_id as varchar), cast(shopping_id as varchar));
    _runURL('index.vsp', query);
    subjects := vector('ARTS','BIOGRAPHIES','BUSINESS','CHILDREN','COMPUTERS','COOKING','HEALTH','HISTORY','HOME','HUMOR','LITERATURE','MYSTERY','NON-FICTION','PARENTING','POLITICS','REFERENCE','RELIGION','ROMANCE','SELF-HELP','SCIENCE-NATURE','SCIENCE-FICTION','SPORTS','YOUTH','TRAVEL');
    subject := aref(subjects,rnd(24));
    add_flag := 'N';
}

create function _runNewProducts(
    in c_id varchar,
    in shopping_id varchar,
    in subject varchar)
{
    declare query varchar;
    
    query := sprintf('subject=%U&C_ID=%U&Shopping_Id=%U', cast(subject as varchar), cast(c_id as varchar), cast(shopping_id as varchar));
    _runURL('newproducts.vsp', query);
}

create function _runOrderDisplay(
    in c_id varchar,
    in shopping_id varchar,
    in uname varchar,
    in passwd varchar)
{
    declare query, reply varchar;
    
    query := sprintf('C_ID=%U&Shopping_Id=%U&username=%U&password=%U',
	 cast(C_ID as varchar),	cast(Shopping_Id as varchar), uname, passwd);
    _runURL('orderdisplay.vsp', query);
}

create function _runOrderInquiry(
    in c_id varchar,
    in shopping_id varchar,
    inout uname varchar,
    inout passwd varchar)
{
    declare query varchar;
    declare c_id1 integer;
    
    query := sprintf('C_ID=%U&Shopping_Id=%U', c_id, shopping_id);
    _runURL('orderinquiry.vsp', query);
    if (atoi(cast(c_id as varchar)) > 0)
    {
    	uname := DigSyl(c_id, 0);
	passwd := lcase(uname);
    }
    else
    {
	c_id1 := NuRand(get_A_ebs(), 1, get_num_ebs()*2880);
	uname := DigSyl(c_id1, 0);
	passwd := lcase(uname);
    }    
}

create function _runProductDetail(
    in c_id varchar,
    in shopping_id varchar,
    in i_id varchar,
    inout add_flag varchar)
{
    declare query varchar;
    
    if (atoi(cast(i_id as varchar)) = 0)
	i_id := cast((rnd(get_num_items()) +1) as varchar);
    
    query := sprintf('C_ID=%U&Shopping_Id=%U&BookInfo=%U',
	 cast(c_id as varchar), cast(shopping_id as varchar), cast(i_id as varchar));
    _runURL('productdetail.vsp', query);
    add_flag := 'Y';
}

create function _runSearchRequest(
    in c_id varchar,
    in shopping_id varchar,
    inout search_type varchar,
    inout search_string varchar,
    inout add_flag varchar)
{
    declare query, reply, search_types, subjects varchar;
    declare s integer;
    
    query := sprintf('C_ID=%U&Shopping_Id=%U', c_id, shopping_id);
    reply := _runURL('searchrequest.vsp', query);
    search_types := vector('AUTHOR', 'TITLE', 'SUBJECT');
    s := rnd(3);
    search_type := aref(search_types, s);
    if (s = 0)
	search_string := DigSyl(NuRand('A', 1, get_num_ebs()/10), 7);
    else if (s = 1)
	search_string := DigSyl(NuRand('A', 1, get_num_ebs()/5), 7);
    else if (s = 2)
    {
	subjects := vector ('ARTS','BIOGRAPHIES','BUSINESS','CHILDREN',
	    'COMPUTERS','COOKING','HEALTH','HISTORY',
	    'HOME','HUMOR','LITERATURE','MYSTERY',
	    'NON-FICTION','PARENTING','POLITICS','REFERENCE',
	    'RELIGION','ROMANCE','SELF-HELP','SCIENCE-NATURE',
	    'SCIENCE-FICTION','SPORTS','YOUTH','TRAVEL');
	search_string := aref(subjects, rnd(24));
    }
    add_flag := 'N';
}

create function _runSearchResult(
    in c_id varchar,
    in shopping_id varchar,
    in search_type varchar,
    in search_string varchar,
    inout i_id varchar,
    inout add_flag varchar)
{
    declare query, reply varchar;
    
    query := sprintf('C_ID=%U&Shopping_Id=%U&search=%U&title_field=%U',
	C_ID, Shopping_Id,
	search_type, search_string);
    reply := _runURL('searchresult.vsp', query);
    add_flag := 'N';
    i_id := cast((rnd(get_num_items()) +1) as varchar);
}

create function _runShoppingCart(
    in c_id varchar,
    in shopping_id varchar,
    in i_id varchar,
    in add_flag varchar,
    inout update_string varchar)
{
    declare query, reply varchar;
    declare par1, par2,tmp varchar;
    declare tree any;
    declare ind, rand integer;
    
    query := sprintf('C_ID=%U&Shopping_Id=%U&I_ID=%U&ADD_FLAG=%U',
	C_ID, Shopping_Id, i_id, add_flag);
    if (add_flag = 'N')
	query := concat(query, update_string);
    reply := _runURL('shoppingcart.vsp', query);
    tree := xtree_doc(reply, 1, '', 'ISO');
    ind := 1;
    tmp := '';
    while (par1<>0 and par2<>0)
    {
	par1 := xpath_eval('//input[@name[starts-with(.,"I_ID")]]/@value', tree, ind);
	par2 := xpath_eval('//input[@type="text"]/@value', tree, ind);
	rand := rnd(2);
	if (par1 <> 0 and par2<>0)
	{
	    tmp := concat(tmp, '&I_ID', cast(par1 as varchar), '=', cast(par1 as varchar),
		'&QTY', cast(par1 as varchar), '=');
	    if (rand=0)
		tmp := concat(tmp, cast(par2 as varchar));
	    else
		tmp := concat(tmp, rnd(11));
	}
	ind := ind + 1;
    }
    update_string := tmp;
    add_flag := 'N';
}

create function thinking()
{
    declare f_num double precision;
    declare time_to_sleep double precision;
    randomize(msec_time());
    f_num := rnd(1024.0)/1024.0;
    time_to_sleep := -log(f_num) * 7;
    dbg_printf('thinking %d secs....', time_to_sleep);
    delay(time_to_sleep);
    dbg_printf('wake up!');
}

create function _recalcAvg(in state integer, in duration integer)
{
    ;
}

create function _getNextRandom() returns integer
{
    declare i integer;
    i := 1 + rnd(9999);
    dbg_printf('generated next random state: %d', i);
    return i;
}	

create function _runShoppingScenario(
    inout _counter integer,
    inout _loops integer,
    inout _state integer,
    inout c_id varchar,
    inout shopping_id varchar,
    inout cctype varchar,
    inout ccnumber varchar,
    inout ccname varchar,
    inout ccdate varchar,
    inout shipping varchar,
    inout street1 varchar,
    inout street2 varchar,
    inout city varchar,
    inout state varchar,
    inout country varchar,
    inout zip varchar,
    inout subject varchar,
    inout returning_flag varchar,
    inout add_flag varchar,
    inout i_new_cost varchar,
    inout username varchar,
    inout pass varchar,
    inout firstname varchar,
    inout lastname varchar,
    inout phone varchar,
    inout email varchar,
    inout birthday varchar,
    inout data varchar,
    inout i_id varchar,
    inout search_type varchar,
    inout search_string varchar,
    inout update_string varchar) returns integer
{
    declare _ADMIN_CONFIRM, _ADMIN_REQUEST, _BEST_SELLERS, _BUY_REQUEST,
	_BUY_CONFIRM, _CUST_REGIST, _HOME, _NEW_PRODUCTS, _ORDER_DISPALY,
	_ORDER_INQUIRY, _PRODUCT_DETAIL, _SEARCH_REQUEST, _SEARCH_RESULT,
	_SHOPPING_CART, t1, t2, r integer;
    
    _ADMIN_CONFIRM := 1;
    _ADMIN_REQUEST := 2;
    _BEST_SELLERS := 3;
    _BUY_REQUEST := 4;
    _BUY_CONFIRM := 5;
    _CUST_REGIST := 6;
    _HOME := 7;
    _NEW_PRODUCTS := 8;
    _ORDER_DISPALY := 9;
    _ORDER_INQUIRY := 10;
    _PRODUCT_DETAIL := 11;
    _SEARCH_REQUEST := 12;
    _SEARCH_RESULT := 13;
    _SHOPPING_CART := 14;    
    t1 := 0;
    t2 := 0;
    _counter := _counter+1;
    if (_counter > _loops) return 0;
    r := _getNextRandom();
    
    if (_state = _ADMIN_CONFIRM)
    {
	dbg_printf('_ADMIN_CONFIRM: %s %s %s %s', c_id,  shopping_id, i_id, i_new_cost);
	t1 := msec_time();
        _runAdminConfirm(c_id, shopping_id, i_id, i_new_cost);	
	t2 := msec_time();
	result(sprintf('PASSED: ADMIN CONFIRMATION in %d msec', t2-t1));
        --addMessage("#:" + _counter + "\tAdminConfirm execution time: " + (t2-t1)/1000000.0);
        _recalcAvg(_state, (t2-t1));
        thinking();
        if (r <= 9952) _state := _HOME;
        else if (r <= 9999) _state := _SEARCH_REQUEST;
    }
    else if (_state = _ADMIN_REQUEST)
    {
	dbg_printf('_ADMIN_REQUEST: %s %s %s %s', c_id, shopping_id, i_id, i_new_cost);
	t1 := msec_time();
	_runAdminRequest(c_id, shopping_id, i_id, i_new_cost);
	t2 := msec_time();
	result(sprintf('PASSED: ADMIN REQUEST in %d msec', t2-t1));
	---addMessage("#:" + _counter + "\tAdminRequest execution time: " + (t2-t1)/1000000.0);
	_recalcAvg(_state, (t2-t1));
	thinking();
	if (r <= 8999) _state := _ADMIN_CONFIRM;
	else if (r <= 9999) _state := _HOME;
    }
    else if (_state = _BEST_SELLERS)
    {
	dbg_printf('_BEST_SELLERS: %s %s %s', c_id,  shopping_id, subject);
	t1 := msec_time();
	_runBestSellers(c_id, shopping_id, subject);
	i_id := '0';
	t2 := msec_time();
	result(sprintf('PASSED: BEST SELLERS in %d msec', t2-t1));
	--addMessage("#:" + _counter + "\tBestSellers execution time: " + (t2-t1)/1000000.0);
	_recalcAvg(_state, (t2-t1));
	thinking();
        if (r <= 167) _state := _HOME;
	else if (r <= 472) _state := _PRODUCT_DETAIL;
	else if (r <= 9927) _state := _SEARCH_REQUEST;
	else if (r <= 9999) _state := _SHOPPING_CART;
    }
    else if (_state = _BUY_CONFIRM)
    {
	dbg_printf('_BUY_CONFIRM: %s %s %s %s %s %s %s %s %s %s %s %s %s', c_id, shopping_id, cctype, ccnumber,  
	    ccname, ccdate, shipping,
	    street1, street2, city, state, country, zip);
	t1 := msec_time();
	_runBuyConfirm(c_id, shopping_id, cctype, ccnumber, ccname, ccdate, shipping,
	    street1, street2, city, state, country, zip);
        t2 := msec_time();
	result(sprintf('PASSED: BUY CONFIRMATION in %d msec', t2-t1));
	--addMessage("#:" + _counter + "\tBuyConfirm execution time: " + (t2-t1)/1000000.0);
	_recalcAvg(_state, (t2-t1));
	thinking();
        if (r <= 84) _state := _HOME;
	else if (r <= 9999) _state := _SEARCH_REQUEST;
    }
    else if (_state = _BUY_REQUEST)
    {
	dbg_printf('_BUY_REQUEST: %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s', c_id, shopping_id, username, pass, firstname, lastname,
	    birthday, street1, street2, city, state, zip, country, phone, email,
	    data, cctype, ccnumber, ccname, ccdate, shipping, add_flag, returning_flag);
	t1 := msec_time();
	_runBuyRequest(c_id, shopping_id, username, pass, firstname, lastname,
	    birthday, street1, street2, city, state, zip, country, phone, email,
	    data, cctype, ccnumber, ccname, ccdate, shipping, add_flag, returning_flag);
	t2 := msec_time();
	result(sprintf('PASSED: BUY REQUEST in %d msec', t2-t1));
	--addMessage("#:" + _counter + "\tBuyRequest execution time: " + (t2-t1)/1000000.0);
	_recalcAvg(_state, (t2-t1));
	thinking();
	if (r <= 4614) _state := _BUY_CONFIRM;
	else if (r <= 6546) _state := _HOME;
	else if (r <= 9999) _state := _SHOPPING_CART;
    }
    else if (_state = _CUST_REGIST)
    {
	dbg_printf('_CUST_REGIST: %s %s', c_id, shopping_id);
	t1 := msec_time();
	_runCustRegist(c_id, shopping_id);
	t2 := msec_time();
	result(sprintf('PASSED: CUSTOMER REGISTRATION in %d msec', t2-t1));
	--addMessage("#:" + _counter + "\tCustRegist execution time: " + (t2-t1)/1000000.0);
	_recalcAvg(_state, (t2-t1));
	thinking();
	if (r <= 8666) _state := _BUY_REQUEST;
	else if (r <= 6760) _state := _HOME;
	else if (r <= 9999) _state := _SEARCH_REQUEST;
    }
    else if (_state = _HOME)
    {
	dbg_printf('_HOME : %s %s %s %s', c_id, shopping_id, subject, add_flag);
	t1 := msec_time();
	_runHome(c_id, shopping_id, subject, add_flag);
	t2 := msec_time();
	result(sprintf('PASSED: HOME PAGE in %d msec', t2-t1));
	--addMessage("#:" + _counter + "\tHome execution time: " + (t2-t1)/1000000.0);
	_recalcAvg(_state, (t2-t1));
	thinking();
	if (r <= 3124) _state := _BEST_SELLERS;
	else if (r <= 6249) _state := _NEW_PRODUCTS;
	else if (r <= 6718) _state := _ORDER_INQUIRY;
	else if (r <= 7026) _state := _SEARCH_REQUEST;
	else if (r <= 9999) _state := _SHOPPING_CART;
    }
    else if (_state= _NEW_PRODUCTS)
    {
	dbg_printf('_NEW_PRODUCTS: %s %s %s', c_id, shopping_id, subject);
	t1 := msec_time();
	_runNewProducts(c_id, shopping_id, subject);
	t2 := msec_time();
	result(sprintf('PASSED: NEW PRODUCT in %d msec', t2-t1));
        --addMessage("#:" + _counter + "\tNewProducts execution time: " + (t2-t1)/1000000.0);
	_recalcAvg(_state, (t2-t1));
	i_id := '0';
	thinking();
	if(r <= 156) _state := _HOME;
	else if (r <= 9735) _state := _PRODUCT_DETAIL;
	else if (r <= 9784) _state := _SEARCH_REQUEST;
	else if (r <= 9999) _state := _SHOPPING_CART;
    }
    else if (_state = _ORDER_DISPALY)
    {
	dbg_printf('_ORDER_DISPLAY: %s %s %s %s', c_id, shopping_id, username, pass);
	t1 := msec_time();
	_runOrderDisplay(c_id, shopping_id, username, pass);
	t2 := msec_time();
	result(sprintf('PASSED: ORDER DISPLAY in %d msec', t2-t1));
	--addMessage("#:" + _counter + "\tOrderDisplay execution time: " + (t2-t1)/1000000.0);
	_recalcAvg(_state, (t2-t1));
	thinking();
	if (r <= 69) _state := _HOME;
	else if (r <= 9999) _state := _SEARCH_REQUEST;
    }
    else if (_state = _ORDER_INQUIRY)
    {
	dbg_printf('_ORDER_INQUIRY: %s %s %s %s', c_id, shopping_id, username, pass);
	t1 := msec_time();
	_runOrderInquiry(c_id, shopping_id, username, pass);
        t2 := msec_time();
	result(sprintf('PASSED: ORDER INQUIRY in %d msec', t2-t1));
        --addMessage("#:" + _counter + "\tOrderInquiry execution time: " + (t2-t1)/1000000.0);
        _recalcAvg(_state, (t2-t1));
        thinking();
        if (r <= 72) _state := _HOME;
        else if(r <= 8872) _state := _ORDER_DISPALY;
        else if(r <= 9999) _state := _SEARCH_REQUEST;
    }
    else if (_state = _PRODUCT_DETAIL)
    {
	dbg_printf('_PRODUCT_DETAIL: %s %s %s %s', c_id, shopping_id, i_id, add_flag);
	t1 := msec_time();
	_runProductDetail(c_id, shopping_id, i_id, add_flag);
        t2 := msec_time();
	result(sprintf('PASSED: PRODUCT DETAILS in %d msec', t2-t1));
	--addMessage("#:" + _counter + "\tProductDetail execution time: " + (t2-t1)/1000000.0);
        _recalcAvg(_state, (t2-t1));
        thinking();
	if (r <= 58) _state := _ADMIN_REQUEST;
        else if (r <= 832) _state := _HOME;
        else if (r <= 1288) _state := _PRODUCT_DETAIL;
        else if (r <= 8603) _state := _SEARCH_REQUEST;
        else if (r <= 9999) _state := _SHOPPING_CART;
    }
    else if (_state = _SEARCH_REQUEST)
    {
	dbg_printf('_SEARCH_REQUEST: %s %s %s %s %s', c_id, shopping_id, search_type, search_string, add_flag);
	t1 := msec_time();
        _runSearchRequest(c_id, shopping_id, search_type, search_string, add_flag);
	t2 := msec_time();
	result(sprintf('PASSED: SEARCH REQUEST in %d msec', t2-t1));
        --addMessage("#:" + _counter + "\tSearchRequest execution time: " + (t2-t1)/1000000.0);
        _recalcAvg(_state, (t2-t1));
	thinking();
        if (r <= 635) _state := _HOME;
	else if (r <= 9135) _state := _SEARCH_RESULT;
        else if (r <= 9999) _state := _SHOPPING_CART;
    }
    else if (_state = _SEARCH_RESULT)
    {
	dbg_printf('_SEARCH_RESULT: %s %s %s %s %s %s', c_id, shopping_id, search_type, search_string, i_id, add_flag);
	t1 := msec_time();
        _runSearchResult(c_id, shopping_id, search_type, search_string, i_id, add_flag);
	t2 := msec_time();
	result(sprintf('PASSED: SEARCH RESULT in %d msec', t2-t1));
        --addMessage("#:" + _counter + "\tSearchResult execution time: " + (t2-t1)/1000000.0);
	_recalcAvg(_state, (t2-t1));
        thinking();
	if (r <= 2637) _state := _HOME;
	else if (r <= 9294) _state := _PRODUCT_DETAIL;
	else if (r <= 9304) _state := _SEARCH_REQUEST;
	else if (r <= 9999) _state := _SHOPPING_CART;
    }
    else if (_state = _SHOPPING_CART)
    {
	dbg_printf('_SHOPPING_CART: %s %s %s %s %s', c_id, shopping_id, i_id, add_flag, update_string);
	t1 := msec_time();
	_runShoppingCart(c_id, shopping_id, i_id, add_flag, update_string);
        t2 := msec_time();
	result(sprintf('PASSED: SHOPPING CART in %d msec', t2-t1));
	--addMessage("#:" + _counter + "\tShoppingCart execution time: " + (t2-t1)/1000000.0);
        _recalcAvg(_state, (t2-t1));
	thinking();
        if (r <= 2585)
	{
	    _state := _CUST_REGIST;
	    update_string := '';
	}
        else if (r <= 9552)
	{
	    _state := _HOME;
	    update_string := '';
	}
        else if (r <= 9999) _state := _SHOPPING_CART;
    }
    else
    {
        return 0;
    }
    return _state;
}

create function runShopping(in numitems numeric(10), in numebs integer)
{
    declare _counter, _loops, _state, _start, i integer;
    declare c_id, shopping_id, cctype, ccnumber, ccname, ccdate, shipping, 
	street1, street2, city, state, country, zip, subject,
	returning_flag, add_flag, i_new_cost, username, pass,
	firstname, lastname, phone, email, birthday, data, i_id,
	search_type, search_string, update_string varchar;
    declare t1, t2, USMD integer;
    USMD := cast(-log(rnd(10000)/10000.0)*15.0*60.0*1000.0 as integer);
	
    c_id := '0';
    shopping_id := '0';
    cctype := '0';
    ccnumber := '0';    
    ccname := '0';    
    ccdate := '0';    
    shipping := '0';    
    street1 := '0';    
    street2 := '0';    
    city := '0';    
    state := '0';    
    country := '0';    
    zip := '0';    
    subject := '0';    
    returning_flag := '0';    
    add_flag := '0';    
    i_new_cost := '0';    
    username := '0';    
    pass := '0';    
    firstname := '0';    
    lastname := '0';    
    phone := '0';    
    email := '0';    
    birthday := '0';    
    data := '0';    
    i_id := '0';    
    search_type := '0';    
    search_string := '0';    
    update_string := '0';    
    
    dbg_printf('Started !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
	
    exec(concat('create function get_num_items () returns numeric(10) {return ',
         cast(numitems as varchar),';}'));
    exec(concat('create function get_num_ebs () returns integer {return ',
         cast(numebs as varchar),';}'));
    
    _loops := 1000;
    _start := msec_time();
    _counter := 0;
    _state := 7;
    i := 0;
    t1 := msec_time();
    t2 := msec_time();
    result (sprintf('PASSED: Shopping session started for %d msec', USMD));
    while (i < 10000)
    {
        _state := _runShoppingScenario(_counter, _loops, _state, c_id, shopping_id,
	    cctype, ccnumber, ccname, ccdate, shipping, street1, street2, city,
	    state, country, zip, subject, returning_flag, add_flag, i_new_cost,
	    username, pass, firstname, lastname, phone, email, birthday, data, i_id,
	    search_type, search_string, update_string);
	if (_state = 0)
	{
	    result ('***FAILED: Internal error in shopping emulator');
	    return;
	}
	t2 := msec_time();
	if ((_state = 7) and (USMD < (t2-t1)))
	{
	    result ('PASSES: Emulation finished by rules');
	    return;
	}
	i := i + 1;
    }
}

ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": TPC-W client emulation database is populated: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
