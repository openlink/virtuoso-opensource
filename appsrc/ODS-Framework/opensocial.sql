use OPEN_SOCIAL;

-- /feeds/people/userID/friends?
DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'os_people', 1,
      '/feeds/people/([^/]*)/?(friends)?',
      vector ('uid', 'friends'),
      2,
      '/feeds/people?uid=%U&friends=%U',
      vector ('uid', 'friends'),
      NULL,
      NULL,
      2,
      NULL,
      NULL
      );

-- /activities/feeds/activities/user/userID/source/sourceID
DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'os_activities', 1,
      '/activities/feeds/activities/user/([^/]*)/?(source/)?([^/]*)?',
      vector ('userID', 'dummy', 'sourceID'),
      2,
      '/activities/activities?userID=%U&sourceID=%U',
      vector ('userID', 'sourceID'),
      NULL,
      NULL,
      2,
      NULL,
      NULL
      );


DB.DBA.URLREWRITE_CREATE_RULELIST ('os_rule_list_ot', 1, vector ('os_people'));
DB.DBA.URLREWRITE_CREATE_RULELIST ('os_rule_list_act', 1, vector ('os_activities'));


-- moved to ods_define_common_vd
--DB.DBA.VHOST_REMOVE (lpath=>'/feeds');
--DB.DBA.VHOST_REMOVE (lpath=>'/activities');
--DB.DBA.VHOST_DEFINE (lpath=>'/feeds', ppath=>'/SOAP/Http', soap_user=>'GDATA_ODS', opts=>vector ('url_rewrite', 'os_rule_list_ot'));
--DB.DBA.VHOST_DEFINE (lpath=>'/activities', ppath=>'/SOAP/Http', soap_user=>'GDATA_ODS', opts=>vector ('url_rewrite', 'os_rule_list_act'));


create procedure is_visible (in flags varchar, in fld int, in mode int)
{
  declare r any;
  if (length (flags) <= fld)
    return 0;
  r := atoi (chr (flags[fld]));
  if (r = 1 or (mode = 1 and r = 2))
    return 1;
  return 0;
}
;

create procedure serialize_user (in uid varchar, inout ses any, in auth int)
{
  declare cname any;
  cname := DB.DBA.WA_CNAME ();
  for select U_FULL_NAME, WAUI_VISIBLE, WAUI_PHOTO_URL, WAUI_LAT, WAUI_LNG, WAUI_JOIN_DATE,
    WAUI_HADDRESS1, WAUI_HADDRESS2, WAUI_HCODE, WAUI_HCITY, WAUI_HSTATE, WAUI_HCOUNTRY, WAUI_HPHONE, WAUI_HMOBILE,
	WAUI_BPHONE, WAUI_BMOBILE,
	WAUI_BADDRESS1, WAUI_BADDRESS2, WAUI_BCODE, WAUI_BCITY, WAUI_BSTATE, WAUI_BCOUNTRY
    from DB.DBA.WA_USER_INFO, DB.DBA.SYS_USERS where WAUI_U_ID = U_ID and U_NAME = uid do
    {
      http ('<entry xmlns="http://www.w3.org/2005/Atom" xmlns:georss="http://www.georss.org/georss" xmlns:gd="http://schemas.google.com/g/2005">\n', ses);
      http (sprintf ('<id>http://%s/feeds/people/%U</id>\n', cname, uid), ses);
      http (sprintf ('<updated>%s</updated>\n', DB.DBA.date_iso8601 (WAUI_JOIN_DATE)), ses);
      http (sprintf ('<title>%V</title>\n', U_FULL_NAME), ses);
      if (length (WAUI_PHOTO_URL) and is_visible (WAUI_VISIBLE, 37, auth))
      http (sprintf ('<link rel="thumbnail" type="image/*" href="%s"/>\n', WAUI_PHOTO_URL), ses);
      http (sprintf ('<link rel="alternate" type="text/html" href="http://%s/dataspace/%s/%U"/>\n', cname,
	    DB.DBA.wa_identity_dstype(uid),uid), ses);
      http (sprintf ('<link rel="self" type="application/atom+xml" href="http://%s/feeds/people/%U"/>\n', cname, uid), ses);
      http (sprintf ('<georss:where>\n'), ses);
      http (sprintf ('<gml:Point xmlns:gml="http://www.opengis.net/gml">\n'), ses);
      if (WAUI_LAT is not null and WAUI_LNG is not null and is_visible (WAUI_VISIBLE, 41, auth))
        http (sprintf ('<gml:pos>%.6f %.6f</gml:pos>\n', WAUI_LAT, WAUI_LNG), ses);
      http (sprintf ('</gml:Point>\n'), ses);
      http (sprintf ('</georss:where>\n'), ses);
      http (sprintf ('<gd:extendedProperty name="lang" value="en-US"/>\n'), ses);
      http (sprintf ('<gd:postalAddress label="Home"><![CDATA[\n'), ses);
      if (length (WAUI_HADDRESS1) and is_visible (WAUI_VISIBLE, 15, auth))
        http (WAUI_HADDRESS1 || '\n', ses);
      if (length (WAUI_HADDRESS2) and is_visible (WAUI_VISIBLE, 15, auth))
	http (WAUI_HADDRESS2 || '\n', ses);
      if (length (WAUI_HCITY) and is_visible (WAUI_VISIBLE, 16, auth))
	http (WAUI_HCITY || ', ', ses);
      if (length (WAUI_HCODE) and is_visible (WAUI_VISIBLE, 15, auth))
	http (WAUI_HCODE|| ', ', ses);
      if (length (WAUI_HSTATE)and is_visible (WAUI_VISIBLE, 16, auth))
	http (WAUI_HSTATE, ses);
      if ((length (WAUI_HCITY) + length (WAUI_HCODE) + length (WAUI_HSTATE)) and is_visible (WAUI_VISIBLE, 16, auth))
	http ('\n', ses);
      if (length (WAUI_HCOUNTRY) and is_visible (WAUI_VISIBLE, 16, auth))
	http (WAUI_HCOUNTRY || '\n', ses);
      http (sprintf (']]></gd:postalAddress>\n'), ses);
      http (sprintf ('<gd:postalAddress label="Work"><![CDATA[\n'), ses);
      if (length (WAUI_BADDRESS1) and is_visible (WAUI_VISIBLE, 22, auth))
        http (WAUI_BADDRESS1 || '\n', ses);
      if (length (WAUI_BADDRESS2) and is_visible (WAUI_VISIBLE, 22, auth))
	http (WAUI_BADDRESS2 || '\n', ses);
      if (length (WAUI_BCITY) and is_visible (WAUI_VISIBLE, 23, auth))
	http (WAUI_BCITY || ', ', ses);
      if (length (WAUI_BCODE) and is_visible (WAUI_VISIBLE, 22, auth))
	http (WAUI_BCODE|| ', ', ses);
      if (length (WAUI_BSTATE) and is_visible (WAUI_VISIBLE, 23, auth))
	http (WAUI_BSTATE, ses);
      if ((length (WAUI_BCITY) + length (WAUI_BCODE) + length (WAUI_BSTATE)) and is_visible (WAUI_VISIBLE, 22, auth))
	http ('\n', ses);
      if (length (WAUI_BCOUNTRY) and is_visible (WAUI_VISIBLE, 23, auth))
	http (WAUI_BCOUNTRY || '\n', ses);
      http (sprintf (']]></gd:postalAddress>\n'), ses);
      if (length (WAUI_HMOBILE) and is_visible (WAUI_VISIBLE, 18, auth))
      http (sprintf ('<gd:phoneNumber label="Private" rel="http://schemas.google.com/g/2005#mobile">%V</gd:phoneNumber>\n', WAUI_HMOBILE), ses);
      if (length (WAUI_BMOBILE) and is_visible (WAUI_VISIBLE, 25, auth))
      http (sprintf ('<gd:phoneNumber label="Work" rel="http://schemas.google.com/g/2005#mobile">%V</gd:phoneNumber>\n', WAUI_BMOBILE), ses);
      if (length (WAUI_HPHONE) and is_visible (WAUI_VISIBLE, 18, auth))
      http (sprintf ('<gd:phoneNumber rel="http://schemas.google.com/g/2005#home">%V</gd:phoneNumber>\n', WAUI_HPHONE), ses);
      if (length (WAUI_BPHONE) and is_visible (WAUI_VISIBLE, 25, auth))
      http (sprintf ('<gd:phoneNumber rel="http://schemas.google.com/g/2005#work">%V</gd:phoneNumber>\n', WAUI_BPHONE), ses);
      http ('</entry>\n', ses);
   }
}
;

create procedure feed_pers_head (in uid varchar, inout ses any)
{
  declare cname, fname any;
  cname := DB.DBA.WA_CNAME ();
  fname := (select U_FULL_NAME from DB.DBA.SYS_USERS where U_NAME = uid);
  http ('<feed xmlns="http://www.w3.org/2005/Atom" xmlns:openSearch="http://a9.com/-/spec/opensearchrss/1.0/" xmlns:georss="http://www.georss.org/georss" xmlns:gd="http://schemas.google.com/g/2005">\n', ses);
  http (sprintf ('<id>http://%s/feeds/people/%s/friends</id>\n', cname, uid), ses);
  http (sprintf ('<updated>%s</updated>\n', DB.DBA.date_iso8601 (now ())), ses);
  http (sprintf ('<title>%V\'s Friends</title>\n', fname), ses);
  http (sprintf ('<link rel="http://schemas.google.com/g/2005#feed" type="application/atom+xml" href="http://%s/feeds/people/%s/friends"/>\n', cname, uid), ses);
  http (sprintf ('<link rel="self" type="application/atom+xml" href="http://%s/feeds/people/%s/friends"/>\n', cname, uid), ses);
  http (sprintf ('<author><name>%s</name></author>\n', fname), ses);
}
;

create procedure feed_tail (inout ses any)
{
   http ('</feed>', ses);
}
;

create procedure auth_check (in uid varchar, in lines any)
{
  declare sid, fld, arr, ret, _u_name any;

  fld := http_request_header_full (lines, 'Authorization', null);
  if (fld is null)
    return 0;
  arr := split_and_decode (fld, 0, '\0\0 =');
  if (length (arr) < 3)
    return 0;
  sid := arr[3];
--  dbg_obj_print (arr, sid);
  whenever not found goto no_auth;
  select VS_UID into _u_name from DB.DBA.VSPX_SESSION where VS_REALM = 'wa' and VS_SID = sid with (prefetch 1);
--  select U_ID into ret from DB.DBA.SYS_USERS where U_ACCOUNT_DISABLED = 0 and U_NAME = _u_name with (prefetch 1);
  if (uid = _u_name)
    return 1;
no_auth:;
  return 0;
}
;

create procedure people (in uid varchar, in friends varchar := null) __SOAP_HTTP 'application/atom+xml'
{
  declare ses any;
  declare rc int;
  set isolation='committed';
  rc := auth_check (uid, http_request_header_full ());
--  dbg_obj_print (rc);
  ses := string_output ();
  if (not length (friends))
    {
      serialize_user (uid, ses, rc);
    }
  else
    {
      declare id int;
      id := (select sne_id from DB.DBA.sn_person where sne_name = uid);
      feed_pers_head (uid, ses);
      for select sne_name from DB.DBA.sn_person, DB.DBA.sn_related where snr_from = sne_id and snr_to = id
	union select sne_name from DB.DBA.sn_person, DB.DBA.sn_related where snr_to = sne_id and snr_from = id do
	  {
	    serialize_user (sne_name, ses, rc);
	  }
      feed_tail (ses);
    }
  http (ses);
  return '';
};

create procedure login (in Uname varchar, in Passwd varchar, in service varchar := null, in source varchar := null) __SOAP_HTTP 'text/plain'
{
  declare sid varchar;
  sid := DB.DBA.VSPX_USER_LOGIN ('wa', Uname, Passwd, 'DB.DBA.web_user_password_check');
  if (sid is null)
    {
      http_status_set (403);
      return 'Error=BadAuthentication';
    }
  return sprintf ('auth=%s\n', sid);
}
;

create procedure serialize_act (in _u_id int, in act_id int, inout ses any)
{
  declare cname varchar;
  cname := DB.DBA.WA_CNAME ();
--  dbg_obj_print (_u_id, act_id);
  for select WA_ID, WA_U_ID, WA_SRC_ID, WA_TS, WA_ACTIVITY, WA_ACTIVITY_TYPE, U_NAME from DB.DBA.WA_ACTIVITIES, DB.DBA.SYS_USERS
    where WA_U_ID = _u_id and WA_ID = act_id and WA_U_ID = U_ID do
    {
      declare url varchar;
      url := sprintf ('http://%s/activities/feeds/activities/user/%s/source/%d/%d', cname, U_NAME, WA_SRC_ID, act_id);
      http ('<entry xmlns="http://www.w3.org/2005/Atom">\n', ses);
      http (sprintf ('<id>%V</id>\n', url), ses);
      http (sprintf ('<updated>%s</updated>\n', DB.DBA.date_iso8601 (WA_TS)), ses);
      http ('<category scheme="http://schemas.google.com/g/2005#kind" term="http://schemas.google.com/activities/2007#activity"/>\n',
	  ses);
      http (sprintf ('<title><![CDATA[%s]]></title>\n', WA_ACTIVITY), ses);
      http (sprintf ('<link rel="self" type="application/atom+xml" href="%V"/>\n', url), ses);
      http (sprintf ('<link rel="edit" type="application/atom+xml" href="%V"/>\n', url), ses);
      http (sprintf ('<received>%s</received>\n', DB.DBA.date_iso8601 (now ())), ses);
      if (length (WA_ACTIVITY_TYPE))
	http (sprintf ('<dc:type xmlns:dc="http://purl.org/dc/elements/1.1">%s</dc:type>\n', WA_ACTIVITY_TYPE), ses);
      http ('</entry>\n', ses);
    }
}
;

create procedure feed_act_head (in uid varchar, in srcId int, inout ses any)
{
  declare cname, fname, url any;
  cname := DB.DBA.WA_CNAME ();
  url := sprintf ('http://%s/activities/feeds/activities/user/%s/source/%d', cname, uid, srcId);
  fname := (select U_FULL_NAME from DB.DBA.SYS_USERS where U_NAME = uid);
  http ('<feed xmlns="http://www.w3.org/2005/Atom" xmlns:openSearch="http://a9.com/-/spec/opensearchrss/1.0/" xmlns:georss="http://www.georss.org/georss" xmlns:gd="http://schemas.google.com/g/2005" xmlns:dc="http://purl.org/dc/elements/1.1"> \n', ses);
  http (sprintf ('<id>%s</id>\n', url), ses);
  http('<category scheme="http://schemas.google.com/g/2005#kind" term="http://schemas.google.com/activities/2007#activity"/>', ses);
  http (sprintf ('<updated>%s</updated>\n', DB.DBA.date_iso8601 (now ())), ses);
  http (sprintf ('<title>%V\'s Activities</title>\n', fname), ses);
  http (sprintf ('<link rel="http://schemas.google.com/g/2005#feed" type="application/atom+xml" href="%s"/>\n', url), ses);
  http (sprintf ('<link rel="http://schemas.google.com/g/2005#post" type="application/atom+xml" href="%s"/>\n', url), ses);
-- no alternate for now
-- http (sprintf ('<link rel="alternate" type="text/html" href="%s"/>\n', url), ses);
  http (sprintf ('<link rel="self" type="application/atom+xml" href="%s"/>\n', url), ses);
  http (sprintf ('<author><name>%s</name></author>\n', fname), ses);
}
;

create procedure activities (in userID varchar, in sourceID varchar := null, in actID int := null) __SOAP_HTTP 'application/atom+xml'
{
  declare cont, xt any;
  declare hstat, _u_id, rc int;
  declare meth, act, ovr_meth varchar;
  declare ses any;

--  dbg_obj_print (userID, sourceID);
  meth := http_request_get ('REQUEST_METHOD');
  ovr_meth := http_request_header (http_request_header (), 'X-HTTP-Method-Override', null, null);
  if (ovr_meth in ('GET', 'PUT', 'POST', 'DELETE'))
    meth := ovr_meth;
--  dbg_obj_print ('method=', meth);
  hstat := 200;
  declare exit handler for not found {
    http_status_set (404);
    return '';
  };

  select U_ID into _u_id from DB.DBA.SYS_USERS where U_NAME = userID with (prefetch 1);
  rc := auth_check (userID, http_request_header_full ());
  ses := string_output ();
  if (meth <> 'GET')
    {
      cont := http_body_read ();
      if (rc = 0)
	{
	  http_status_set (403);
	  return '';
	}
      xt := xtree_doc (cont);
      act := xpath_eval ('[ xmlns:a="http://www.w3.org/2005/Atom" ] string (/a:entry/a:title)', xt);
      if (not length (act))
	signal ('22023', 'Empty activity title');
      if (meth = 'PUT' or meth = 'DELETE')
	{
	  declare tmp, arr any;
	  actID := xpath_eval ('[ xmlns:a="http://www.w3.org/2005/Atom" ] string (/a:entry/a:id)', xt);
	  tmp := cast (actID as varchar);
	  arr := sprintf_inverse (tmp, 'http://%s/activities/feeds/activities/user/%s/source/%s/%s', 0);
	  if (length (arr) > 3)
	    actID := cast (arr[3] as integer);
          else
	    actID := null;
	}
--      dbg_obj_print (actID);
      if (actID is null and meth = 'POST')
	{
          insert into DB.DBA.WA_ACTIVITIES (WA_U_ID, WA_SRC_ID, WA_ACTIVITY) values (_u_id, sourceID, act);
	  actID := identity_value ();
	  hstat := 201;
	}
      else if (meth = 'PUT')
        {
	  update DB.DBA.WA_ACTIVITIES set WA_ACTIVITY = act where WA_ID = actID and WA_U_ID = _u_id;
	  if (row_count () = 0)
	    hstat := 404;
	}
      else if (meth = 'DELETE')
	{
	  delete from DB.DBA.WA_ACTIVITIES where WA_ID = actID and WA_U_ID = _u_id;
	  if (row_count () = 0)
	    hstat := 404;
	}
      else
	signal ('22023', 'Invalid HTTP request');
      if (meth <> 'DELETE')
        serialize_act (_u_id, actID, ses);
    }
  else if (meth = 'GET')
    {
      sourceID := cast (sourceID as int);
      feed_act_head (userID, sourceID, ses);

      if(sourceID=0)
      {
        for select WA_ID from DB.DBA.WA_ACTIVITIES where WA_U_ID = _u_id do
        {
	       serialize_act (_u_id, WA_ID, ses);
	      }
      }
      else
      {
        for select WA_ID from DB.DBA.WA_ACTIVITIES where WA_U_ID = _u_id and WA_SRC_ID = sourceID do
        {
	       serialize_act (_u_id, WA_ID, ses);
	      }
	    }
      feed_tail (ses);
    }
  http_status_set (hstat);
  http (ses);
  return '';
}
;

grant execute on OPEN_SOCIAL.DBA.people to GDATA_ODS;
grant execute on OPEN_SOCIAL.DBA.login to GDATA_ODS;
grant execute on OPEN_SOCIAL.DBA.activities to GDATA_ODS;

create procedure add_ods_activity (
       in userID any,
       in sourceID any,
       in act varchar,
       in actTYPE varchar := null,
       in actACTION varchar := null,
       in objTYPE varchar := null,
       in objURI varchar := null)
{

    declare actID integer;
    actID:=0;

    declare exit handler for sqlstate '*' {goto _err;};

    if(isstring(userID))
      userID:=(select U_ID from DB.DBA.SYS_USERS where U_NAME=userID);
    else if(isinteger(userID))
      userID:=(select U_ID from DB.DBA.SYS_USERS where U_ID=userID);
    else
      goto _err;

    if(isstring(sourceID))
      sourceID:=(select WAI_ID from DB.DBA.WA_INSTANCE where WAI_NAME=sourceID);
    else if(isinteger(sourceID))
    {
      if(sourceID>0)
         sourceID:=(select WAI_ID from DB.DBA.WA_INSTANCE where WAI_ID=sourceID);
    }else
      goto _err;

    if(act is null or length(act)=0 )
       goto _err;

    insert into DB.DBA.WA_ACTIVITIES (WA_U_ID, WA_SRC_ID, WA_ACTIVITY,WA_ACTIVITY_TYPE,WA_ACTIVITY_ACTION,WA_OBJ_TYPE,WA_OBJ_URI)
         values (userID, sourceID, act, actTYPE, actACTION, objTYPE, objURI);


	  actID := identity_value ();

  return actID;

_err:
  return 0;
}
;


create trigger sn_related_opensocial_I after insert on DB.DBA.sn_related referencing new as N
{
  declare _from_uid, _to_uid integer;


  _from_uid := (select sne_org_id from DB.DBA.sn_entity where sne_id=N.snr_from);
  _to_uid   := (select sne_org_id from DB.DBA.sn_entity where sne_id=N.snr_to);

  if(_from_uid is not null and _to_uid is not null)
  {
      declare exit handler for sqlstate '*' {
--        log_message (__SQL_MESSAGE);
        return;
      };


   declare _act,_inst_type varchar;

  _act:=sprintf('<a href="http://%s">%s</a> and <a href="http://%s" >%s</a> are now connected.',
                  DB.DBA.WA_CNAME ()||DB.DBA.WA_USER_DATASPACE(_from_uid),DB.DBA.WA_USER_FULLNAME(_from_uid),
                  DB.DBA.WA_CNAME ()||DB.DBA.WA_USER_DATASPACE(_to_uid),DB.DBA.WA_USER_FULLNAME(_to_uid));

  OPEN_SOCIAL.DBA.add_ods_activity(_from_uid,0,_act,'social_network','add','connection',DB.DBA.WA_CNAME ()||DB.DBA.WA_USER_DATASPACE(_to_uid));

  _act:=sprintf('<a href="http://%s">%s</a> and <a href="http://%s" >%s</a> are now connected.',
                  DB.DBA.WA_CNAME ()||DB.DBA.WA_USER_DATASPACE(_to_uid),DB.DBA.WA_USER_FULLNAME(_to_uid),
                  DB.DBA.WA_CNAME ()||DB.DBA.WA_USER_DATASPACE(_from_uid),DB.DBA.WA_USER_FULLNAME(_from_uid));

  OPEN_SOCIAL.DBA.add_ods_activity(_to_uid,0,_act,'social_network','add','connection',DB.DBA.WA_CNAME ()||DB.DBA.WA_USER_DATASPACE(_from_uid));


  }


  return;
}
;

create trigger sn_related_opensocial_D after delete on DB.DBA.sn_related referencing old as O
{
  declare _from_uid, _to_uid integer;


  _from_uid := (select sne_org_id from DB.DBA.sn_entity where sne_id=O.snr_from);
  _to_uid   := (select sne_org_id from DB.DBA.sn_entity where sne_id=O.snr_to);

  if(_from_uid is not null and _to_uid is not null)
  {
      declare exit handler for sqlstate '*' {
--        log_message (__SQL_MESSAGE);
        return;
      };


   declare _act,_inst_type varchar;

  _act:=sprintf('<a href="http://%s">%s</a> and <a href="http://%s" >%s</a> are not connected any more.',
                  DB.DBA.WA_CNAME ()||DB.DBA.WA_USER_DATASPACE(_from_uid),DB.DBA.WA_USER_FULLNAME(_from_uid),
                  DB.DBA.WA_CNAME ()||DB.DBA.WA_USER_DATASPACE(_to_uid),DB.DBA.WA_USER_FULLNAME(_to_uid));

  OPEN_SOCIAL.DBA.add_ods_activity(_from_uid,0,_act,'social_network','remove','connection',DB.DBA.WA_CNAME ()||DB.DBA.WA_USER_DATASPACE(_to_uid));

  _act:=sprintf('<a href="http://%s">%s</a> and <a href="http://%s" >%s</a> are not connected any more.',
                  DB.DBA.WA_CNAME ()||DB.DBA.WA_USER_DATASPACE(_to_uid),DB.DBA.WA_USER_FULLNAME(_to_uid),
                  DB.DBA.WA_CNAME ()||DB.DBA.WA_USER_DATASPACE(_from_uid),DB.DBA.WA_USER_FULLNAME(_from_uid));

  OPEN_SOCIAL.DBA.add_ods_activity(_to_uid,0,_act,'social_network','remove','connection',DB.DBA.WA_CNAME ()||DB.DBA.WA_USER_DATASPACE(_from_uid));


  }


  return;
}
;
