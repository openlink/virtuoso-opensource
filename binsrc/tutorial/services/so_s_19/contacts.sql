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
vhost_remove (lpath=>'/SOAP_SO_S_19');

vhost_define (lpath=>'/SOAP_SO_S_19', ppath=>'/SOAP/', soap_user=>'SOAP_SO_S_19');

create user SOAP_SO_S_19;

create procedure WS.SOAP.Contacts (in uri varchar)
returns any  __soap_type 'services.wsdl:ArrayOfcontacts4D'
{
  declare body, url varchar;
  declare hdr, ret, vtb, ses, xm any;
  declare lvl integer;
  url := uri;
  --dbg_obj_print ('WS.SOAP.Contacts : url : ' ,url);
  ret := vector ();
  body := http_get (url, hdr);
  if (not isstring (body))
    goto eof;
  -- substitutions for chars and tags
  body := replace (body, '\x94', '"');
  body := replace (body, '\x92', '''');
  body := replace (body, '\x93', '"');
  body := replace (body, '<b>', '');
  body := replace (body, '</b>', '');
  body := replace (body, '<i>', '');
  body := replace (body, '</i>', '');
  body := replace (body, '<strong>', '');
  body := replace (body, '</strong>', '');
  body := replace (body, '\n', '');
  body := replace (body, '\r', '');
  body := replace (body, '<p', '\n<p');
  body := replace (body, '<P', '\n<P');
  body := replace (body, '<h', '\n<h');
  body := replace (body, '<H', '\n<H');
  xm := xml_tree (body, 2);
  if (xm is not null)
    {
      xm := xml_tree_doc (xm);
      ses := string_output ();
      http_value (xm, null, ses);
      body := string_output_string (ses);
    }
  else
    {
      body := replace (body, '''', '&#39;');
      body := replace (body, '"', '&quot;');
    }
  lvl := 0;
  DB.DBA.extract_contacts (body, ret, lvl);
eof:
  ret := DB.DBA.find_address (ret);
  --dbg_obj_print ('WS.SOAP.Contacts:', ret);
  return ret;
}
;

create procedure WS.SOAP.StrContacts (in uri varchar)
{
  declare r, str, xt, xs, ses any;
  declare i, l int;
  ses := string_output ();
  r := WS.SOAP.Contacts (uri);
  l := length (r);
  --dbg_obj_print (r);
  http (sprintf ('<contacts ref="%V">', uri), ses);
  for (i := 0; i < l; i := i + 1)
    {
      declare elm any;
      elm := r[i];
      http (sprintf ('<contact>'), ses);
      http (sprintf ('<name>%V</name>', elm[0]), ses);
      http (sprintf ('<title>%V</title>', elm[1]), ses);
      http (sprintf ('<company>%V</company>' , elm[2]), ses);
      http (sprintf ('<email>%V</email>', elm[3]), ses);
      http (sprintf ('<web>%V</web>', elm[4]), ses);
      http (sprintf ('</contact>'), ses);
    }
  http (sprintf ('</contacts>'), ses);
  ses := string_output_string (ses);
  xt := xtree_doc (ses);
  xs := xslt (TUTORIAL_XSL_DIR() || '/tutorial/services/so_s_19/contact_moz.xsl', xt);
  ses := string_output ();
  http_value (xs, null, ses);
  return string_output_string (ses);
}
;

grant execute on DB.DBA.XML_URI_GET_STRING_OR_ENT to SOAP_SO_S_19;

create procedure WS.SOAP.ExContacts (in uri varchar)
returns any  __soap_type 'services.wsdl:ArrayOfstring'
{
  declare ret1, ret any;
  declare i, l integer;
  ret := vector ();
  ret1 := WS.SOAP.Contacts (uri);
  i := 0;
  l := length (ret1);
  while (i < l)
  {
    ret := vector_concat (ret, ret1[i]);
    i := i + 1;
  }
  return ret;
}
;

grant execute on WS.SOAP.Contacts to SOAP_SO_S_19
;

grant execute on WS.SOAP.StrContacts to SOAP_SO_S_19
;

grant execute on WS.SOAP.ExContacts to SOAP_SO_S_19
;

create procedure extract_contacts (in txt varchar, inout ret any, inout lvl integer)
{
  declare str, tmp, expr varchar;
  declare i, l, offs integer;
  expr := get_expr (lvl);
  if (expr is null or not isstring (txt))
    return 0;
  i := 0; l := length (expr);
  while (i<l)
    {
      tmp := txt;
      --if (lvl >= 1) dbg_obj_print ('before: ', expr[i], tmp);
      tmp := regexp_match (expr[i], tmp);
      --if (lvl >= 1) dbg_obj_print ('after: ', expr[i], tmp);
      if (tmp is not null and lvl > 0)
	{
	  ret := vector_concat (ret, vector (rtrim (tmp, ',.')));
          offs := strstr (txt, tmp);
          tmp := substring (txt, offs + length (tmp), length (txt));
          if (extract_contacts (ltrim (tmp, ' .,'), ret, lvl + 1))
	    {
	      return 1;
	    }
	  return 0;
	}
      while (tmp is not null)
	{
	  extract_contacts (tmp, ret, lvl + 1);
	  offs := strstr (txt, tmp);
	  tmp := substring (txt, offs + length (tmp), length (txt));
          --dbg_obj_print ('before: ', expr[i], tmp);
	  tmp := regexp_match (expr[i], tmp);
          --dbg_obj_print ('after: ', expr[i], tmp);
	}
      i := i+1;
    }
  return 0;
}
;

create procedure get_expr (in lvl integer)
{
  declare ret any;
  ret := vector (
   vector(
          '(&quot;)?[ \t\n\r,](&quot;)?[ \t]*(said|says|say)[ \t\n\r,]+([MDPB][a-z]+\.)*[^\.]+([A-Za-z\.]+\-based)?[^\.]*'
          ),
   vector (
           '[A-Z''][a-z'']+[ \t]+[A-Za-z'']+[ \t]?,',
           '[A-Z''][a-z'']+[ \t][A-Za-z'']+[ \t][A-Za-z'']+[ \t]?,',
	   '[A-Z''][a-z'']+[ \t]+([A-Z\.]|van|de)[ \t][A-Za-z'']+[ \t]?,',
           '[DMPB][a-z]+\.[ ]*[A-Z''][a-z'']+[ \t][A-Za-z'']+[ \t]?,',
           '[A-Z''][a-z'']+[ \t][A-Za-z'']+[ \t]?'
	   ),
   vector (
           '[A-Za-z ]+ of ([A-Za-z]+[ ]?)+,',
           '[A-Za-z0-9 ]+&#39;s ',
           '[A-Za-z&#;0-9\| ]+( at | for | from | of [^a-z])',
           '[A-Za-z ]+[\,][A-Za-z ]+[\,][ \t]?',
           '[A-Za-z&#;0-9\| ]+[\,][ ]?[^a-z]',
           '[A-Za-z]+[ ]+([A-Za-z]+[ ]+)?([Ss]ervices[ ]+)?'
	   ),
   vector (
           '[A-Za-z0-9\| &#;@\.''`-]+'
	  ),
            NULL
	   );
  if (lvl > length(ret) - 1)
    return NULL;
  return ret [lvl];
}
;

create procedure dict_1 (in txt varchar)
{
  declare tit any;
  declare i, l integer;
  tit := vector (' at ',' for ',' from ',' of ');
  l := length (tit);
  while (i < l)
    {
      if (strstr (txt, tit[i]) is not null)
	return 1;
      i := i + 1;
    }
  return 0;
}
;

create procedure make_srch_words (in txt1 any)
{
  declare res, txt any;
  txt := txt1;
  if (strstr (txt, '&#39;s') is null)
    return txt1;
  res := regexp_match (' [A-Za-z ]+&#39;s', txt);
  if (res is null)
    return txt1;
  res := substring (res, 1, length (res) - 6);
  --dbg_obj_print (res);
  return trim (res);
}
;

create procedure find_address (in arr any)
{
  declare i, l, j integer;
  declare ret, ret1, b, site any;
  declare webs varchar;
  i := 0; l := length (arr);
  ret := vector ();
  while (i < l)
    {
      declare uri varchar;
      declare comp, titl varchar;
      declare srch varchar;
      if (i+2 > l - 1)
	goto eof;
      if (dict_2 (arr[i+1]))
	{
           comp := arr[i+2];
	   titl := trim (arr[i+1], ' ,');
	}
      else
	{
           comp := arr[i+1];
	   titl := trim (arr[i+2], ' ,');
	}
      comp := trim_the_comp (comp);
      j := 0;
      ret1 := vector (arr[i], trim_the_title (titl), comp);
      srch := make_srch_words (comp);
      uri := sprintf ('http://www.google.com/search?hl=en&q=%U%s+%%22home+page%%22', srch,
	       case when comp not like '%s' then '' else '' end
	       );
again:
      --dbg_obj_print (uri);
      b := http_get (uri);
      site := xpath_eval ('//p/a/@href', (xml_tree_doc(xml_tree (b,2))));
      if (site is not null)
	{
          site := cast (site as varchar);
 	  if (site like '/search%' or (j < 2 and site not like 'http://%/'))
            site := NULL;
	}
      if (j = 0 and site is null)
	{
          uri := sprintf ('http://www.google.com/search?hl=en&q=%%22%U%%22', srch);
          j := 1;
	  goto again;
	}
      if (j = 1 and site is null)
	{
          uri := sprintf ('http://www.google.com/search?hl=en&q=%U%s+welcome', srch,
	       case when comp not like '%s' then '' else '' end
	       );
          j := 2;
	  goto again;
	}
      webs := site;
      site := make_e_mail (arr[i], site);
      ret1 := vector_concat (ret1, vector (site));
      ret1 := vector_concat (ret1, vector (webs));
      ret := vector_concat (ret, vector (ret1));
      i := i + 3;
    }
eof:
  return ret;
}
;


create procedure make_e_mail (in name varchar, in dom varchar)
{
  declare narr, dom1, dom2, narr1 any;
  declare l1, l2, i, j, k integer;
  declare res varchar;
  if (not isstring(name) or not isstring (dom))
    return NULL;
  name := trim (name);
  narr1 := split_and_decode (name, 0, '\0\0 ');
  narr := vector ();
  j := 0; k := length (narr1);
  while (j<k)
    {
      if (narr1[j] <> '')
	narr := vector_concat (narr, vector(narr1[j]));
      j := j + 1;
    }
  dom1 := WS.WS.PARSE_URI (dom);
  dom2 := split_and_decode (dom1[1], 0, '\0\0.');
  l1 := length (narr);
  if (l1 = 2)
    {
      res := sprintf ('%s.%s@', narr[0], narr[1]);
    }
  else if (l1 > 2)
    {
      res := sprintf ('%s.%s@', narr[0], narr[2]);
    }
  else
    return NULL;
  l2 := length (dom2);
  i := 1;
  if (l2 < 2)
    return NULL;
  else if (l2 = 2)
    i := 0;
  while (i < l2)
    {
      res := concat (res, dom2[i], '.');
      i := i + 1;
    }
  res := rtrim (res, '.');
  return res;
}
;

create procedure trim_the_comp (in comp varchar)
{
  declare c varchar;
  c := comp;
  if (regexp_match ('.*&#39;s[ \t]+\$', c) is not null)
    {
      declare offs integer;
      offs := strstr (comp, '&#39;s');
      comp := substring (comp, 1, offs);
    }
  return comp;
}
;

create procedure trim_the_title (in txt varchar)
{
  declare offs integer;
  if (txt like '% of _' or txt like '%, _')
    {
      declare how integer;
      how := case when txt like '% of _' then 4 else 3 end;
      return trim (substring (txt, 1, length (txt) - how));
    }
  else if (txt like '% at')
    {
      return trim (substring (txt, 1, length (txt) - 2));
    }
  else if (txt like '% for')
    {
      return trim (substring (txt, 1, length (txt) - 3));
    }
  if (txt[length(txt)-1] <> ascii (' '))
    return txt;
  if (not dict_1 (txt))
    return trim (txt);
  txt := trim (txt);
  offs := strrchr (txt, ' ');
  txt := substring (txt, 1, offs);
  return txt;
}
;

create procedure dict_2 (in txt varchar)
{
  declare t any;
  declare txt1 varchar;
  declare i, l integer;
  txt1 := txt;
  txt := lower (txt);
  t := vector (
	 'president', 1,
	 'vice', 1,
	 'CEO', 0,
	 'CTO', 0,
	 'COO', 0,
	 'director', 1,
	 'general', 1,
	 'technical', 1,
	 'senior', 1,
	 'developer', 1,
	 'analyst', 1,
	 'doctor', 1,
	 'proffessor', 1,
	 'programmer', 1,
	 'manager', 1,
	 'sales', 1,
	 'consultant', 1,
	 'market', 1,
	 'officer', 1,
	 'chief', 1,
	 'strategy', 1,
	 'IT', 0
	 );
  l := length (t);
  while (i<l)
    {
      if (t[i+1] and strstr (txt, t[i]) is not null)
	return 1;
      else if (strstr (txt1, t[i]) is not null)
	return 1;
      i := i + 2;
    }
  return 0;
}
;


soap_dt_define ('', t_file_to_string (concat (TUTORIAL_ROOT_DIR (), '/tutorial/services/so_s_19/array4d.xsd')))
;

