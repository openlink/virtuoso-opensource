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
vhost_remove (lpath=>'/SOAP_SO_S_11');

vhost_define (lpath=>'/SOAP_SO_S_11', ppath=>'/SOAP/', soap_user=>'SOAP_SO_S_11');

create procedure so_s_11_clean ()
  {
    declare stat, msg any;
    exec ('drop table countries', stat, msg);
    exec ('drop table provinces', stat, msg);
    exec ('drop table countries_xml', stat, msg);
    exec ('drop table provinces_xml', stat, msg);
    exec ('create user SOAP', stat, msg);
  }
;

so_s_11_clean ()
;

create user SOAP_SO_S_11;

create table countries (c_name varchar primary key, c_provinces long varchar, provinces_url varchar not null, c_id integer not null, c_info varchar);

create table countries_xml (c_name varchar primary key, c_provinces long varchar, provinces_url varchar not null, c_id integer not null, c_info varchar, c_lat real, c_lng real);

create unique index c_country_id on countries (c_id);

create table provinces (p_c_id integer not null, p_country varchar, p_name varchar);

sequence_set ('c_country_id',1,0);

create unique index c_country_id_xml on countries_xml (c_id);

create table provinces_xml (p_c_id integer not null, p_country varchar, p_name varchar);

sequence_set ('c_country_id_xml',1,0);

create procedure get_provinces (in prov_url varchar, in cname varchar)
{
   declare xe, cn any;
   declare cnt varchar;
   prov_url := concat ('http://www.cia.gov/cia/publications/factbook/', prov_url);
   cnt := http_get (prov_url);
   xe := xml_tree_doc (xml_tree (cnt,2));
   cn := xpath_eval ('//tr[td[1]/div/text()="Administrative divisions:"]/td[2]', xe, 1);
   cn := cast (cn as varchar);
   if (cn is NULL)
     cn := 'None';
   update countries set c_provinces = cn where  c_name = cname;
   return cn;
}
;

create procedure fill_provinces (in mask varchar)
{
  declare str, wrd, wrd1, str1, tmp, prov_url, prov_state varchar;
  declare num, id, comma integer;
  declare reg_exp1, reg_exp2 any;
  reg_exp1 := vector('[^,]+([,]|[\\r]|[\\n])', '[^;,]+([;,]|[\\r]|[\\n])');
  for select c_id, c_provinces, provinces_url, c_name from countries where c_name like mask do {
    comma := case when (c_name = 'Argentina') then 1
                  else 0 end;
    delete from provinces where p_c_id = c_id;
    str := c_provinces;
    if (str is NULL)
      str := get_provinces (provinces_url, mask);
    wrd := regexp_match ('([0-9]|[A-Za-z])+[^;:]*[;:]', str, 1);
    tmp := wrd;
    id := c_id;
    update countries set c_info = trim (replace (tmp, ';', '')) where c_id = id;
    while (wrd is not null)
      {
        wrd := regexp_match ('[^;:,]+([;,:]|(note:)|\$)', str, 1);
        str1 := trim(wrd); wrd1 := '';
        while (str1 is not null and not matches_like (str1, '%[0-9]%') and wrd1 is not null)
          {
            if (str1 = 'note:')
              goto _end;
            wrd1 := regexp_match(reg_exp1[comma], str1, 1);
            if (wrd1 is not null)
              {
                wrd1 := replace(wrd1, ';', '');
                if (comma = 0)
                  wrd1 := replace (wrd1, ',', '');
                wrd1 := trim(trim (wrd1, '\r\n'));
                tmp := wrd1;
                if (regexp_match ('^([A-Z]|[''][^\\ ])+', tmp))
                  {
		    declare p1, p2 integer;
                    p1 := strchr (wrd1, '*');
                    p2 := strrchr (wrd1, '*');
                    if (p1 is null or p1 = p2)
                      insert into provinces (p_c_id, p_name, p_country) values (c_id, trim(wrd1,'*'), c_name);
                  }
              }
          }
      }
      _end: ;
  }
};


create procedure fill_countries ()
{
   declare cnt, cname, prov_url varchar;
   declare hdr any;
   declare xe any;
   declare i, l integer;
   declare cn, cd any;
   cnt := http_get ('http://www.cia.gov/cia/publications/factbook/index.html', hdr);
   xe := xml_tree_doc (xml_tree (cnt,2));
   cn := xpath_eval ('/html/body/table/tr/td/form/select/option',xe,0);
   i := 1; l := length (cn);
   while (i < l)
     {
       cname := cast (cn[i] as varchar);
       prov_url := cast (xpath_eval ('/@value', xml_cut(cn[i]), 1) as varchar);
       if (not exists (select 1 from countries where c_name = cname))
         insert into countries (c_id, c_name, c_provinces, provinces_url)
         values (sequence_next('c_country_id'), cname, NULL, prov_url);
--     fill_provinces (cname);
       i := i + 1;
     };
};

fill_countries ();

create procedure WS.SOAP.administrative_divisions (in country varchar, in province varchar, in use_stored varchar := null)
{
  declare st any;
  declare orig_mask, prov_url, prov_state varchar;
  if (use_stored = 'on')
    select provinces_url, c_provinces into prov_url, prov_state from countries_xml where c_name = country;
  else
    {
      select provinces_url, c_provinces into prov_url, prov_state from countries where c_name = country;
      if (prov_state is NULL)
        fill_provinces (country);
    }
  st := string_output ();
  orig_mask := country;
  country := upper (country);
  http ('<?xml version="1.0" ?>\r\n',st);
  http ('<administrative_divisions>\r\n',st);
  if (use_stored = 'on')
    {
      if (exists (select 1 from db..provinces_xml b, db..countries_xml a where upper (a.c_name) like country and b.p_c_id = a.c_id))
	xml_auto ('select 1 as tag, null as parent, c_name as [country!1!name!element] , c_info as [country!1!info], null as [province!2!name!element] from db..countries_xml where upper (c_name) like ? union all select 2, 1, c_name, c_info, p_name from db..provinces_xml, db..countries_xml where upper (c_name) like ? and p_c_id = c_id order by [country!1!name] for xml explicit',
	  vector (country, country), st);
      else
	http (sprintf ('<noentries mask="%s"/>', orig_mask), st);
    }
  else
    {
      if (exists (select 1 from db..provinces b, db..countries a where upper (a.c_name) like country and b.p_c_id = a.c_id))
	xml_auto ('select 1 as tag, null as parent, c_name as [country!1!name!element] , c_info as [country!1!info], null as [province!2!name!element] from db..countries where upper (c_name) like ? union all select 2, 1, c_name, c_info, p_name from db..provinces, db..countries where upper (c_name) like ? and p_c_id = c_id order by [country!1!name] for xml explicit',
	  vector (country, country), st);
      else
	http (sprintf ('<noentries mask="%s"/>', orig_mask), st);
    }
  http ('</administrative_divisions>\r\n',st);
  return (string_output_string (st));
};

grant execute on DB.DBA.XML_URI_GET_STRING_OR_ENT to SOAP_SO_S_11;

create procedure WS.SOAP.get_provinces_for_country (in country varchar, in use_stored varchar := null)
{
  declare pr, xt, xs, ses any;
  ses := string_output ();
  pr := WS.SOAP.administrative_divisions (country, null, use_stored);
  xt := xtree_doc (pr);
  xs := xslt (TUTORIAL_XSL_DIR() || '/tutorial/services/so_s_11/moz.xsl', xt);
  http_value (xs, null, ses);
  return (string_output_string (ses));
}
;

create procedure WS.SOAP.countries (in ch integer)
{
  declare st any;
  declare sel varchar;
  st := string_output ();
  if (ch = 2)
    http ('<select name="country" id="country" onChange="adiv();">',st);
  else
    http ('<select name="country" id="country">',st);
  for select c_name from db..countries order by c_name do
    {
      if (upper(c_name) = 'UNITED STATES')
        sel := 'SELECTED';
      else
        sel := '';
      http (sprintf ('<option value="%s" %s>%s</option>', c_name, sel, c_name), st);
    }
  http ('</select>',st);
  return (string_output_string (st));
};

grant execute on WS.SOAP.administrative_divisions to SOAP_SO_S_11;

grant execute on WS.SOAP.get_provinces_for_country to SOAP_SO_S_11;

grant execute on WS.SOAP.countries to SOAP_SO_S_11;

grant select on db..provinces to SOAP_SO_S_11;

grant select on db..countries to SOAP_SO_S_11;

grant select on db..provinces_xml to SOAP_SO_S_11;

grant select on db..countries_xml to SOAP_SO_S_11;

grant select on WS.WS.SYS_DAV_RES to SOAP_SO_S_11;

insert soft DB.DBA.SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_INTERVAL, SE_SQL)
    values ('TUTORIAL_SERVICES_SO_S_11', now(), 3000, 'DB.DBA.fill_countries()');

soap_dt_define ('', t_file_to_string (TUTORIAL_ROOT_DIR() || '/tutorial/services/so_s_11/array2d.xsd'));


create procedure WS.SOAP.get_Divisions2D (in mask varchar, in use_stored varchar := null)
	returns any  __soap_type 'services.wsdl:ArrayOfdivisions2D'
{
  declare mask1 varchar;
  declare cnt integer;
  declare prov, ret any;
  mask1 := upper (mask);
  ret := NULL;
  if (use_stored = 'on')
    {
      for select c_id, c_name, c_provinces from db..countries_xml where upper (c_name) = mask1 do
	{
	   select count(*) into cnt from db..provinces_xml where p_c_id = c_id;
	   for select p_name from db..provinces_xml where p_c_id = c_id do
	     {
	       if (ret is null)
		 {
		   ret := vector ();
		   ret := vector_concat (ret, vector (vector (cast (cnt as varchar), p_name)));
		 }
	       else
		 ret := vector_concat (ret, vector (vector (null, p_name)));
	     }
	}
    }
  else
    {
      for select c_id, c_name, c_provinces from db..countries where upper (c_name) = mask1 do
	{
	   if (c_provinces is NULL)
	     fill_provinces (c_name);
	   select count(*) into cnt from db..provinces where p_c_id = c_id;
	   for select p_name from db..provinces where p_c_id = c_id do
	     {
	       if (ret is null)
		 {
		   ret := vector ();
		   ret := vector_concat (ret, vector (vector (cast (cnt as varchar), p_name)));
		 }
	       else
		 ret := vector_concat (ret, vector (vector (null, p_name)));
	     }
	}
    }
  if (ret is null)
    ret := vector (vector('0', null));
  return ret;
};

grant execute on WS.SOAP.get_Divisions2D to SOAP_SO_S_11;

soap_dt_define ('', t_file_to_string (TUTORIAL_ROOT_DIR() || '/tutorial/services/so_s_11/array_div.xsd'));

soap_dt_define ('', t_file_to_string (TUTORIAL_ROOT_DIR() || '/tutorial/services/so_s_11/division.xsd'));

create procedure WS.SOAP.get_arrayOfDivisions (in mask varchar)
	returns any  __soap_type 'services.wsdl:ArrayOfdivisions'
{
  declare mask1 varchar;
  declare cnt integer;
  declare prov, ret any;
  mask1 := upper (mask);
  ret := NULL;
  for select c_id, c_name from db..countries where upper (c_name) = mask1 do
    {
       select count(*) into cnt from db..provinces where p_c_id = c_id;
       for select p_name from db..provinces where p_c_id = c_id do
	 {
	   if (ret is null)
	     {
               ret := vector ();
               ret := vector_concat (ret, vector ( soap_box_structure ('count', cnt, 'name', p_name)));
	     }
	   else
             ret := vector_concat (ret, vector ( soap_box_structure ('count', 0, 'name', p_name)));
	 }
    }
  if (ret is null)
    ret := vector ( soap_box_structure ('count', 0, 'name', null));
  return ret;
};

soap_dt_define('','
<complexType name="ArrayOfstring" targetNamespace="services.wsdl"
   xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/"
   xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
   xmlns="http://www.w3.org/2001/XMLSchema"
   xmlns:tns="http://soapinterop.org/xsd">
  <complexContent>
     <restriction base="enc:Array">
	<sequence>
	   <element name="item" type="string" minOccurs="0" maxOccurs="unbounded" nillable="true"/>
	</sequence>
	<attributeGroup ref="enc:commonAttributes"/>
	<attribute ref="enc:arrayType" wsdl:arrayType="string[]"/>
     </restriction>
  </complexContent>
</complexType>');


create procedure WS.SOAP.get_ArrayOfcountries ()
	returns any  __soap_type 'services.wsdl:ArrayOfstring'
{
  declare st, ret any;
  ret := vector ();
  for select c_name from db..countries order by c_name do
    {
      ret := vector_concat (ret, vector(c_name));
    }
  return (ret);
};


create procedure
fill_cntrries_from_xml ()
{
  declare i, l int;
  declare cntr, tree any;
  {
  	declare continue handler for NOT FOUND {
  		-- if we don't have the file in dav get it from the one in this dir.
			tree := xml_tree_doc (t_file_to_string (TUTORIAL_ROOT_DIR() || '/tutorial/services/so_s_11/factbook.xml'));
  	};
  	select xml_tree_doc (blob_to_string (RES_CONTENT)) into tree from WS.WS.SYS_DAV_RES
		where RES_FULL_PATH = '/DAV/factbook/factbook.xml';
	}
  cntr := xpath_eval ('/factbook/record', tree, 0);
  l := length (cntr);
  while (i < l)
    {
      declare cname, prov, lat_lng, tlat, tlng varchar;
      declare lat, lng real;
      lat_lng := cast (xpath_eval ('string (.//geographic_coordinates)', cntr[i]) as varchar);
      cname := cast (xpath_eval ('string (country)', cntr[i]) as varchar);
      prov := xpath_eval ('translate(.//administrative_divisions, "\r\n", ",,")', cntr[i]);
      prov := cast (prov as varchar);
      lat_lng := regexp_match ('[0-9 ]+[A-Z][, ]+[0-9 ]+[A-Z]', lat_lng);
      if (lat_lng is not null)
	{
	  declare arr any;
          tlat := trim(regexp_match ('[0-9 ]+[A-Z]', lat_lng));
	  tlng := trim(regexp_match (',[ ]+[0-9 ]+[A-Z]', lat_lng), ', ');
	  arr := split_and_decode (tlat, 0, '\0\0 ');
	  lat := atoi(arr[0]) + (atoi(arr[1]) / 60.00);
	  if (arr[2] = 'S')
	    lat := lat * -1.0;
	  arr := split_and_decode (tlng, 0, '\0\0 ');
	  lng := atoi(arr[0]) + (atoi(arr[1]) / 60.00);
	  if (arr[2] = 'W')
	    lng := lng * -1.0;
	}
      insert into countries_xml (c_id, c_name, c_provinces, provinces_url, c_lat, c_lng)
	values (sequence_next('c_country_id_xml'), cname, prov, '', lat, lng);
      fill_provinces_1 (cname);
      i := i + 1;
    }
};


create procedure fill_provinces_1 (in mask varchar)
{
  declare str, wrd, wrd1, str1, tmp, prov_url, prov_state varchar;
  declare num, id, comma integer;
  declare reg_exp1, reg_exp2 any;
  reg_exp1 := vector('[^,]+([,]|\$)', '[^;,]+([;,]|\$)');
  for select c_id, c_provinces, provinces_url, c_name from countries_xml where c_name like mask do {
    comma := case when (c_name = 'Argentina') then 1
                  else 0 end;
    delete from provinces_xml where p_c_id = c_id;
    str := c_provinces;
    wrd := regexp_match ('([0-9]|[A-Za-z])+[^;:]*[;:]', str, 1);
    tmp := wrd;
    id := c_id;
    update countries_xml set c_info = trim (replace (tmp, ';', '')) where c_id = id;
    while (wrd is not null)
      {
        wrd := regexp_match ('[^;:,]+([;,:]|(note:)|(note\-)|(Dependent areas\-)|\$|\\n)', str, 1);
        str1 := trim(wrd); wrd1 := '';
        while (str1 is not null and not matches_like (str1, '%[0-9]%') and wrd1 is not null)
          {
            if (
                 matches_like (str1,'note[:\-]%') or
                 matches_like (str1,'Dependent areas-%')
               )
              goto _end;
            wrd1 := regexp_match(reg_exp1[comma], str1, 1);
            if (wrd1 is not null)
              {
                wrd1 := replace(wrd1, ';', '');
                if (comma = 0)
                  wrd1 := replace (wrd1, ',', '');
                wrd1 := trim(trim (wrd1, '\r\n'));
                tmp := wrd1;
                if (regexp_match ('^([A-Z]|[''][^\\ ])+', tmp))
                  {
		    declare p1, p2 integer;
                    p1 := strchr (wrd1, '*');
                    p2 := strrchr (wrd1, '*');
                    if (p1 is null or p1 = p2)
                      insert into provinces_xml (p_c_id, p_name, p_country) values (c_id, trim(wrd1,'*'), c_name);
                  }
              }
          }
      }
      _end: ;
  }
};

fill_cntrries_from_xml ();

grant execute on WS.SOAP.get_arrayOfDivisions to SOAP_SO_S_11;

grant execute on WS.SOAP.get_arrayOfcountries to SOAP_SO_S_11;

