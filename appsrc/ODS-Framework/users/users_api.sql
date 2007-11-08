-------------------------------------------------------------------------------
--
-- ODS API
--
-------------------------------------------------------------------------------
create procedure ODS_ERROR_XML (
  inout pStream any,
  in pCode varchar,
  in pMessage varchar)
{
  http ('<error>', pStream);
  http (sprintf ('<code>%s</code>', pCode), pStream);
  http (sprintf ('<message>%s</message>', pMessage), pStream);
  http ('</error>', pStream);
}
;

create procedure ODS_USER_XML_ITEM (
  in pTag varchar,
  in pValue any,
  inout pStream any)
{
  if (not DB.DBA.is_empty_or_null (pValue))
    http (sprintf ('<%s>%V</%s>', pTag, cast (pValue as varchar), pTag), pStream);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS_USER_XML (
  inout pStream any,
  in pUID varchar,
  in pShort integer := 1)
{
  for (select * from DB.DBA.SYS_USERS, DB.DBA.WA_USER_INFO where WAUI_U_ID = U_ID and U_ID = pUID) do {
    http ('<user>', pStream);

    -- Personel
    ODS_USER_XML_ITEM ('uid',       U_ID,            pStream);
    ODS_USER_XML_ITEM ('name',      U_NAME,          pStream);
    ODS_USER_XML_ITEM ('mail',      U_E_MAIL,        pStream);
    ODS_USER_XML_ITEM ('title',     WAUI_TITLE,      pStream);
    ODS_USER_XML_ITEM ('firstName', WAUI_FIRST_NAME, pStream);
    ODS_USER_XML_ITEM ('lastName',  WAUI_LAST_NAME,  pStream);
    ODS_USER_XML_ITEM ('fullName',  WAUI_FULL_NAME,  pStream);

    if (not pShort) {
      -- Personel
      ODS_USER_XML_ITEM ('gender',                 WAUI_GENDER,       pStream);
      if (not isnull(WAUI_BIRTHDAY)) {
        ODS_USER_XML_ITEM ('birthdayDay',          dayofmonth(WAUI_BIRTHDAY), pStream);
        ODS_USER_XML_ITEM ('birthdayMonth',        month(WAUI_BIRTHDAY),      pStream);
        ODS_USER_XML_ITEM ('birthdayYear',         year(WAUI_BIRTHDAY),       pStream);
      }

      -- Contact
      ODS_USER_XML_ITEM ('icq',                    WAUI_ICQ,          pStream);
      ODS_USER_XML_ITEM ('skype',                  WAUI_SKYPE,        pStream);
      ODS_USER_XML_ITEM ('yahoo',                  WAUI_YAHOO,        pStream);
      ODS_USER_XML_ITEM ('aim',                    WAUI_AIM,          pStream);
      ODS_USER_XML_ITEM ('msn',                    WAUI_MSN,          pStream);

      ODS_USER_XML_ITEM ('defaultMapLocation',     WAUI_LATLNG_HBDEF, pStream);
      -- Home
      ODS_USER_XML_ITEM ('homeCountry',            WAUI_HCOUNTRY,     pStream);
      ODS_USER_XML_ITEM ('homeState',              WAUI_HSTATE,       pStream);
      ODS_USER_XML_ITEM ('homeCity',               WAUI_HCITY,        pStream);
      ODS_USER_XML_ITEM ('homeCode',               WAUI_HCODE,        pStream);
      ODS_USER_XML_ITEM ('homeAddress1',           WAUI_HADDRESS1,    pStream);
      ODS_USER_XML_ITEM ('homeAddress2',           WAUI_HADDRESS2,    pStream);
      ODS_USER_XML_ITEM ('homeTimezone',           WAUI_HTZONE,       pStream);
      ODS_USER_XML_ITEM ('homeLatitude',           WAUI_LAT,          pStream);
      ODS_USER_XML_ITEM ('homeLongitude',          WAUI_LNG,          pStream);
      ODS_USER_XML_ITEM ('homePhone',              WAUI_HPHONE,       pStream);
      ODS_USER_XML_ITEM ('homeMobile',             WAUI_HMOBILE,      pStream);

      -- Business
      ODS_USER_XML_ITEM ('businessIndustry',       WAUI_BINDUSTRY,    pStream);
      ODS_USER_XML_ITEM ('businessOrganization',   WAUI_BORG,         pStream);
      ODS_USER_XML_ITEM ('businessHomePage',       WAUI_BORG_HOMEPAGE,pStream);
      ODS_USER_XML_ITEM ('businessJob',            WAUI_BJOB,         pStream);
      ODS_USER_XML_ITEM ('businessCountry',        WAUI_BCOUNTRY,     pStream);
      ODS_USER_XML_ITEM ('businessState',          WAUI_BSTATE,       pStream);
      ODS_USER_XML_ITEM ('businessCity',           WAUI_BCITY,        pStream);
      ODS_USER_XML_ITEM ('businessCode',           WAUI_BCODE,        pStream);
      ODS_USER_XML_ITEM ('businessAddress1',       WAUI_BADDRESS1,    pStream);
      ODS_USER_XML_ITEM ('businessAddress2',       WAUI_BADDRESS2,    pStream);
      ODS_USER_XML_ITEM ('businessTimezone',       WAUI_BTZONE,       pStream);
      ODS_USER_XML_ITEM ('businessLatitude',       WAUI_BLAT,         pStream);
      ODS_USER_XML_ITEM ('businessLongitude',      WAUI_BLNG,         pStream);
      ODS_USER_XML_ITEM ('businessPhone',          WAUI_BPHONE,       pStream);
      ODS_USER_XML_ITEM ('businessMobile',         WAUI_BMOBILE,      pStream);
      ODS_USER_XML_ITEM ('businessRegNo',          WAUI_BREGNO,       pStream);
      ODS_USER_XML_ITEM ('businessCareer',         WAUI_BCAREER,      pStream);
      ODS_USER_XML_ITEM ('businessEmployees',      WAUI_BEMPTOTAL,    pStream);
      ODS_USER_XML_ITEM ('businessVendor',         WAUI_BVENDOR,      pStream);
      ODS_USER_XML_ITEM ('businessService',        WAUI_BSERVICE,     pStream);
      ODS_USER_XML_ITEM ('businessOther',          WAUI_BOTHER,       pStream);
      ODS_USER_XML_ITEM ('businessNetwork',        WAUI_BNETWORK,     pStream);
      ODS_USER_XML_ITEM ('businessResume',         WAUI_RESUME,       pStream);

      -- Security
      ODS_USER_XML_ITEM ('securitySecretQuestion', WAUI_SEC_QUESTION, pStream);
      ODS_USER_XML_ITEM ('securitySecretAnswer',   WAUI_SEC_ANSWER,   pStream);
      ODS_USER_XML_ITEM ('securitySiocLimit',      USER_GET_OPTION (U_NAME, 'SIOC_POSTS_QUERY_LIMIT'), pStream);
    }
    http ('</user>', pStream);
  }
}
;

-------------------------------------------------------------------------------
--
create procedure ODS_SESSION_XML (
  inout pStream any,
  in sid varchar,
  in realm varchar)
{
  http ('<session>', pStream);
  http (sprintf ('<sid>%U</sid>', sid), pStream);
  http (sprintf ('<realm>%U</realm>', realm), pStream);
  http ('</session>', pStream);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS_SESSION_CHECK (
  in pSid varchar,
  in pRealm varchar,
  inout pUID integer,
  inout pUser varchar)
{
  for (select U.U_ID,
              U.U_NAME
         from DB.DBA.VSPX_SESSION S,
              WS.WS.SYS_DAV_USER U
        where S.VS_REALM = pRealm
          and S.VS_SID   = pSid
          and S.VS_UID   = U.U_NAME) do
  {
    pUID := U_ID;
    pUser := U_NAME;
    return 1;
  }
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure ODS_USER_LOGIN (
  in pUser varchar,
  in pPassword varchar,
  in pOpenID varchar := '',
  in pDetail integer := 0
) returns varchar
{
  declare sid, realm varchar;
  declare sStream any;

  sStream := string_output();
  http ('<root>', sStream);

  if (trim (pOpenID) <> '') {
    pUser := (select U_NAME from WA_USER_INFO, SYS_USERS where WAUI_U_ID = U_ID and WAUI_OPENID_URL = pOpenID);
    if (isnull (pUser))
      DB.DBA.ODS_ERROR_XML (sStream, 'BAD_LOGIN', 'Bad OpenID!');
  } else {
    pUser := (select U_NAME from DB.DBA.SYS_USERS where U_NAME = pUser and pwd_magic_calc (U_NAME, U_PASSWORD, 1) = pPassword);
    if (isnull (pUser))
      DB.DBA.ODS_ERROR_XML (sStream, 'BAD_LOGIN', 'Bad username and/or password!');
  }
  if (not isnull (pUser)) {
    sid := vspx_sid_generate ();
    realm := 'wa';
    insert into DB.DBA.VSPX_SESSION (VS_REALM, VS_SID, VS_UID, VS_STATE, VS_EXPIRY)
      values (realm, sid, pUser, serialize ( vector ('vspx_user', pUser)), now());
    DB.DBA.ODS_ERROR_XML (sStream, 'OK', 'OK');
    DB.DBA.ODS_SESSION_XML (sStream, sid, realm);
    if (pDetail) {
      declare pUID integer;
      pUID := (select U_ID from DB.DBA.SYS_USERS where U_NAME = pUser);
      DB.DBA.ODS_USER_XML (sStream, pUID);
    }
  }

  http ('</root>', sStream);
  return string_output_string(sStream);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS_USER_LOGOUT (
  in pSid varchar,
  in pRealm varchar) returns varchar
{
  declare sStream any;

  sStream := string_output();
  http ('<root>', sStream);

  delete from DB.DBA.VSPX_SESSION where VS_REALM = pRealm and VS_SID = pSid;
  ODS_ERROR_XML (sStream, 'OK', 'OK');

  http ('</root>', sStream);
  return string_output_string(sStream);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS_USER_REGISTER (
  in pUser varchar,
  in pPassword varchar,
  in pMail varchar,
  in oid_identity varchar := '',
  in oid_fullname varchar := '',
  in oid_birthday varchar := '',
  in oid_gender varchar := '',
  in oid_postcode varchar := '',
  in oid_country varchar := '',
  in oid_tz varchar := '',
  in pDetail integer := 0) returns varchar
{
  declare uid integer;
  declare sStream any;

  sStream := string_output();
  http ('<root>', sStream);

  declare exit handler for sqlstate '*' {
    ODS_ERROR_XML (sStream, __SQL_STATE, __SQL_MESSAGE);
    goto _end;
  };

  if (exists (select 1 from DB.DBA.SYS_USERS where U_NAME = pUser)) {
    ODS_ERROR_XML (sStream, 'BAD_REGISTER', 'Login name already in use!');
  } else {
    uid := ODS_CREATE_USER (pUser, pPassword, pMail);
    if (length (oid_birthday))
      WA_USER_EDIT (pUser, 'WAUI_BIRTHDAY', oid_birthday);
    if (length (oid_fullname))
      WA_USER_EDIT (pUser, 'WAUI_FULL_NAME', oid_fullname);
    if (length (oid_gender))
      WA_USER_EDIT (pUser, 'WAUI_GENDER', case oid_gender when 'M' then 'male' when 'F' then 'female' else null end);
    if (length (oid_postcode))
      WA_USER_EDIT (pUser, 'WAUI_HCODE', oid_postcode);
    if (length (oid_country))
      WA_USER_EDIT (pUser, 'WAUI_HCOUNTRY', (select WC_NAME from WA_COUNTRY where WC_ISO_CODE = upper (oid_country)));
    if (length (oid_tz))
      WA_USER_EDIT (pUser, 'WAUI_HTZONE', oid_tz);
    if (length (oid_identity))
      update WA_USER_INFO set WAUI_OPENID_URL = oid_identity where WAUI_U_ID = uid;
    return ODS_USER_LOGIN (pUser, pPassword, oid_identity, pDetail);
  }

_end:;
  http ('</root>', sStream);
  return string_output_string(sStream);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS_USER_SELECT (
  in pSid varchar,
  in pRealm varchar,
  in pShort integer := 1) returns varchar
{
  declare pUID integer;
  declare pUser varchar;
  declare sStream any;

  sStream := string_output();
  http ('<root>', sStream);

  if (ODS_SESSION_CHECK (pSid, pRealm, pUID, pUser)) {
    ODS_ERROR_XML (sStream, 'OK', 'OK');
    ODS_USER_XML (sStream, pUID, pShort);
  } else {
    ODS_ERROR_XML (sStream, 'BAD_SESSION', 'Invalid session!');
  }

  http ('</root>', sStream);
  return string_output_string(sStream);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS_USER_UPDATE (
  in pSid varchar,
  in pRealm varchar,
  in pMail varchar,
  in pTitle varchar,
  in pFirstName varchar,
  in pLastName varchar,
  in pFullName varchar,
  in pGender varchar,
  in pBirthdayDay varchar,
  in pBirthdayMonth varchar,
  in pBirthdayYear varchar,
  in pIcq varchar,
  in pSkype varchar,
  in pYahoo varchar,
  in pAim varchar,
  in pMsn varchar,
  in pDefaultMapLocation varchar,
  in pHomeCountry varchar,
  in pHomeState varchar,
  in pHomeCity varchar,
  in pHomeCode varchar,
  in pHomeAddress1 varchar,
  in pHomeAddress2 varchar,
  in pHomeTimeZone varchar,
  in pHomeLatitude varchar,
  in pHomeLongitude varchar,
  in pHomePhone varchar,
  in pHomeMobile varchar,
  in pBusinessIndustry varchar,
  in pBusinessOrganization varchar,
  in pBusinessHomePage varchar,
  in pBusinessJob varchar,
  in pBusinessCountry varchar,
  in pBusinessState varchar,
  in pBusinessCity varchar,
  in pBusinessCode varchar,
  in pBusinessAddress1 varchar,
  in pBusinessAddress2 varchar,
  in pBusinessTimeZone varchar,
  in pBusinessLatitude varchar,
  in pBusinessLongitude varchar,
  in pBusinessPhone varchar,
  in pBusinessMobile varchar,
  in pBusinessRegNo varchar,
  in pBusinessCareer varchar,
  in pBusinessEmployees varchar,
  in pBusinessVendor varchar,
  in pBusinessService varchar,
  in pBusinessOther varchar,
  in pBusinessNetwork varchar,
  in pBusinessResume varchar,
  in pSecuritySecretQuestion varchar,
  in pSecuritySecretAnswer varchar,
  in pSecuritySiocLimit varchar) returns varchar
{
  declare pUID integer;
  declare pUser varchar;
  declare sStream any;

  sStream := string_output();
  http ('<root>', sStream);

  declare exit handler for sqlstate '*' {
    ODS_ERROR_XML (sStream, __SQL_STATE, __SQL_MESSAGE);
    goto _end;
  };

  if (ODS_SESSION_CHECK (pSid, pRealm, pUID, pUser)) {
    -- Personel
    WA_USER_EDIT (pUser, 'E_MAIL', pMail);
    WA_USER_EDIT (pUser, 'WAUI_TITLE', pTitle);
    WA_USER_EDIT (pUser, 'WAUI_FIRST_NAME', pFirstName);
    WA_USER_EDIT (pUser, 'WAUI_LAST_NAME', pLastName);
    WA_USER_EDIT (pUser, 'WAUI_FULL_NAME', pFullName);
    WA_USER_EDIT (pUser, 'WAUI_GENDER', pGender);
    {
      declare dt any;

      declare continue handler for sqlstate '*'
		  {
		    goto _skip;
			};
      dt := stringdate (sprintf ('%s-%s-%s', pBirthdayYear, pBirthdayMonth, pBirthdayDay));
      WA_USER_EDIT (pUser, 'WAUI_BIRTHDAY', dt);
    _skip:;
		}

    -- Contact
    WA_USER_EDIT (pUser, 'WAUI_ICQ', pIcq);
    WA_USER_EDIT (pUser, 'WAUI_SKYPE', pSkype);
    WA_USER_EDIT (pUser, 'WAUI_AIM', pYahoo);
    WA_USER_EDIT (pUser, 'WAUI_YAHOO', pAim);
    WA_USER_EDIT (pUser, 'WAUI_MSN', pMsn);

    WA_USER_EDIT (pUser, 'WAUI_LATLNG_HBDEF', pDefaultMapLocation);
    -- Home
    WA_USER_EDIT (pUser, 'WAUI_HCOUNTRY', pHomeCountry);
    WA_USER_EDIT (pUser, 'WAUI_HSTATE', pHomeState);
    WA_USER_EDIT (pUser, 'WAUI_HCITY', pHomeCity);
    WA_USER_EDIT (pUser, 'WAUI_HCODE', pHomeCode);
    WA_USER_EDIT (pUser, 'WAUI_HADDRESS1', pHomeAddress1);
    WA_USER_EDIT (pUser, 'WAUI_HADDRESS2', pHomeAddress2);
    WA_USER_EDIT (pUser, 'WAUI_HTZONE', pHomeTimeZone);
    WA_USER_EDIT (pUser, 'WAUI_LAT', pHomeLatitude);
    WA_USER_EDIT (pUser, 'WAUI_LNG', pHomeLongitude);
    WA_USER_EDIT (pUser, 'WAUI_HPHONE', pHomePhone);
    WA_USER_EDIT (pUser, 'WAUI_HMOBILE', pHomeMobile);

    -- Business
    WA_USER_EDIT (pUser, 'WAUI_BINDUSTRY', pBusinessIndustry);
    WA_USER_EDIT (pUser, 'WAUI_BORG', pBusinessOrganization);
    WA_USER_EDIT (pUser, 'WAUI_BORG_HOMEPAGE', pBusinessHomePage);
    WA_USER_EDIT (pUser, 'WAUI_BJOB', pBusinessJob);
    WA_USER_EDIT (pUser, 'WAUI_BCOUNTRY', pBusinessCountry);
    WA_USER_EDIT (pUser, 'WAUI_BSTATE', pBusinessState);
    WA_USER_EDIT (pUser, 'WAUI_BCITY', pBusinessCity);
    WA_USER_EDIT (pUser, 'WAUI_BCODE', pBusinessCode);
    WA_USER_EDIT (pUser, 'WAUI_BADDRESS1', pBusinessAddress1);
    WA_USER_EDIT (pUser, 'WAUI_BADDRESS2', pBusinessAddress2);
    WA_USER_EDIT (pUser, 'WAUI_BTZONE', pBusinessTimeZone);
    WA_USER_EDIT (pUser, 'WAUI_BLAT', pBusinessLatitude);
    WA_USER_EDIT (pUser, 'WAUI_BLNG', pBusinessLongitude);
    WA_USER_EDIT (pUser, 'WAUI_BPHONE', pBusinessPhone);
    WA_USER_EDIT (pUser, 'WAUI_BMOBILE', pBusinessMobile);
    WA_USER_EDIT (pUser, 'WAUI_BREGNO', pBusinessRegNo);
    WA_USER_EDIT (pUser, 'WAUI_BCAREER', pBusinessCareer);
    WA_USER_EDIT (pUser, 'WAUI_BEMPTOTAL', pBusinessEmployees);
    WA_USER_EDIT (pUser, 'WAUI_BVENDOR', pBusinessVendor);
    WA_USER_EDIT (pUser, 'WAUI_BSERVICE', pBusinessService);
    WA_USER_EDIT (pUser, 'WAUI_BOTHER', pBusinessOther);
    WA_USER_EDIT (pUser, 'WAUI_BNETWORK', pBusinessNetwork);
    WA_USER_EDIT (pUser, 'WAUI_RESUME', pBusinessResume);

    -- Security
    WA_USER_EDIT (pUser, 'SEC_QUESTION', pSecuritySecretQuestion);
    WA_USER_EDIT (pUser, 'SEC_ANSWER', pSecuritySecretAnswer);
    USER_SET_OPTION (pUser, 'SIOC_POSTS_QUERY_LIMIT', atoi (pSecuritySiocLimit));

    ODS_ERROR_XML (sStream, 'OK', 'OK');
  } else {
    ODS_ERROR_XML (sStream, 'BAD_SESSION', 'Invalid session!');
  }

_end:;
  http ('</root>', sStream);
  return string_output_string(sStream);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS_USER_UPDATE_PASSWORD (
  in pSid varchar,
  in pRealm varchar,
  in pOldPassword varchar,
  in pNewPassword varchar) returns varchar
{
  declare pUID integer;
  declare pUser varchar;
  declare sStream any;

  sStream := string_output();
  http ('<root>', sStream);

  declare exit handler for sqlstate '*' {
    ODS_ERROR_XML (sStream, __SQL_STATE, __SQL_MESSAGE);
    goto _end;
  };

  if (ODS_SESSION_CHECK (pSid, pRealm, pUID, pUser)) {
    -- Security
    USER_CHANGE_PASSWORD (pUser, pOldPassword, pNewPassword);

    ODS_ERROR_XML (sStream, 'OK', 'OK');
    ODS_USER_XML (sStream, pUID);
  } else {
    ODS_ERROR_XML (sStream, 'BAD_SESSION', 'Invalid session!');
  }

_end:;
  http ('</root>', sStream);
  return string_output_string(sStream);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS_USER_LINKS (
  in pSid varchar,
  in pRealm varchar) returns varchar
{
  declare pUID integer;
  declare pUser varchar;
  declare sStream any;

  sStream := string_output();
  http ('<root>', sStream);

  if (ODS_SESSION_CHECK (pSid, pRealm, pUID, pUser)) {
    ODS_ERROR_XML (sStream, 'OK', 'OK');
    http (sprintf ('<foaf>%s</foaf>', DB.DBA.WA_LINK (1, sprintf ('/dataspace/person/%s/foaf.rdf', pUser))), sStream);
  } else {
    ODS_ERROR_XML (sStream, 'BAD_SESSION', 'Invalid session!');
  }

  http ('</root>', sStream);
  return string_output_string(sStream);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS_USER_LIST (
  in pSid varchar,
  in pRealm varchar,
  in pList varchar,
  in pParam varchar := '') returns varchar
{
  declare pUID integer;
  declare pUser varchar;
  declare sStream any;

  sStream := string_output();
  http ('<root>', sStream);

  if (ODS_SESSION_CHECK (pSid, pRealm, pUID, pUser)) {
    ODS_ERROR_XML (sStream, 'OK', 'OK');
    if (pList = 'Industry') {
      http ('<items>', sStream);
      for (select WI_NAME from DB.DBA.WA_INDUSTRY order by WI_NAME) do {
        http (sprintf ('<item>%s</item>', WI_NAME), sStream);
      }
      http ('</items>', sStream);
    }
    if (pList = 'Country') {
      http ('<items>', sStream);
      for (select WC_NAME from DB.DBA.WA_COUNTRY order by WC_NAME) do {
        http (sprintf ('<item>%s</item>', WC_NAME), sStream);
      }
      http ('</items>', sStream);
    }
    if (pList = 'Province') {
      http ('<items>', sStream);
      for (select WP_PROVINCE from DB.DBA.WA_PROVINCE where WP_COUNTRY = pParam and WP_COUNTRY <> '' order by WP_PROVINCE) do {
        http (sprintf ('<item>%s</item>', WP_PROVINCE), sStream);
      }
      http ('</items>', sStream);
    }
  } else {
    ODS_ERROR_XML (sStream, 'BAD_SESSION', 'Invalid session!');
  }

  http ('</root>', sStream);
  return string_output_string(sStream);
}
;


-------------------------------------------------------------------------------
--
create procedure ODS_GET_LOCATION (
  in pCountry varchar,
  in pState varchar,
  in pCity varchar,
  in pCode varchar,
  in pAddress1 varchar,
  in pAddress2 varchar) returns varchar
{
  declare latitude, longitude double precision;
  declare sStream any;

  sStream := string_output();
  http ('<root>', sStream);

	if (0 <> DB.DBA.WA_MAPS_ADDR_TO_COORDS (pAddress1, pAddress2, pCity, pState, pCode, pCountry, latitude, longitude)) {
    ODS_ERROR_XML (sStream, 'OK', 'OK');
    http ('<location>', sStream);
    http (sprintf ('<latitude>%s</latitude>', cast (latitude as varchar)), sStream);
    http (sprintf ('<longitude>%s</longitude>', cast (longitude as varchar)), sStream);
    http ('</location>', sStream);
	} else {
    ODS_ERROR_XML (sStream, 'BAD_ADDRESS', 'Invalid address data!');
	}
  http ('</root>', sStream);
  return string_output_string(sStream);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS_CREATE_DSN ()
{
	declare S varchar;
	declare _driver varchar;
	declare _dsn varchar;
	declare _address varchar;
	declare _user varchar;
	declare _pass varchar;
	declare _attrib varchar;

	_dsn := 'LocalVirtuosoDemo';
	_address := 'localhost:' || cfg_item_value (virtuoso_ini_path (), 'Parameters', 'ServerPort');
	_user := 'dba';
	_pass := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = 'dba');

  if ((sys_stat('st_build_opsys_id') = 'Win32') and (sys_stat('st_has_vdb') = 1)) {
	_driver := null;
	foreach (varchar _drv in sql_get_installed_drivers ()) do {
		if (upper(_drv) like 'OPENLINK VIRTUOSO%' or upper(_drv) like 'VIRTUOSO%') {
			_driver := _drv;
			goto _exit;
		}
	}
_exit:;
    if (not isnull (_driver)) {
  	_attrib := '';
  	_attrib := _attrib || 'DSN=' || _dsn || ';';
  	_attrib := _attrib || 'Address=' || _address || ';';
  	_attrib := _attrib || 'UserID=' || _user || ';';
  	_attrib := _attrib || 'Password=' || _pass || ';';
  	_attrib := _attrib || 'Description=Local Virtuoso Demo DSN for ODS Users;';

  	sql_config_data_sources(_driver, 'system', _attrib);
  }
  }

  -- create PHP dsn file
	S := '<?php \n' ||
	     '  \$_dsn = "%s"; \n' ||
	     '  \$_user = "%s"; \n' ||
	     '  \$_pass = "%s"; \n' ||
	     '?> \n';
	S := sprintf (S, _dsn, _user, _pass);
	DB.DBA.DAV_RES_UPLOAD_STRSES_INT ('/DAV/VAD/wa/users/users_dsn.php', S, 'text/html', '111101101RR', http_dav_uid (), http_dav_uid () + 1, null, null, 0);

  -- create JSP dsn file
	S := '<%%@ page import="java.sql.*" %%>\n' ||
       '<%%@ page import="java.io.*" %%>\n' ||
       '<%%!\n' ||
       '  Connection getConnection ()\n' ||
       '    throws ClassNotFoundException, SQLException\n' ||
       '  {\n' ||
       '    Class.forName("virtuoso.jdbc3.Driver");\n' ||
       '    return DriverManager.getConnection("jdbc:virtuoso://%s", "%s", "%s");\n' ||
       '  }\n' ||
       '\n' ||
       '%%>';
	S := sprintf (S, _address, _user, _pass);
	DB.DBA.DAV_RES_UPLOAD_STRSES_INT ('/DAV/VAD/wa/users/users_dsn.jsp', S, 'application/octet-stream', '110100100RR', http_dav_uid (), http_dav_uid () + 1, null, null, 0);
}
;

ODS_CREATE_DSN ();

-------------------------------------------------------------------------------
--
grant execute on ODS_USER_LOGIN to GDATA_ODS;
grant execute on ODS_USER_LOGOUT to GDATA_ODS;
grant execute on ODS_USER_REGISTER to GDATA_ODS;
grant execute on ODS_USER_SELECT to GDATA_ODS;
grant execute on ODS_USER_UPDATE to GDATA_ODS;
grant execute on ODS_USER_UPDATE_PASSWORD to GDATA_ODS;
grant execute on ODS_USER_LINKS to GDATA_ODS;
grant execute on ODS_USER_LIST to GDATA_ODS;
grant execute on ODS_GET_LOCATION to GDATA_ODS;
