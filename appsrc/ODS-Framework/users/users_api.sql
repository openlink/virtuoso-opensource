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
    http (sprintf ('<uid>%d</uid>', U_ID), pStream);
    http (sprintf ('<name>%V</name>', coalesce (U_NAME, '')), pStream);
    http (sprintf ('<mail>%V</mail>', coalesce (U_E_MAIL, '')), pStream);
    http (sprintf ('<title>%V</title>', coalesce (WAUI_TITLE, '')), pStream);
    http (sprintf ('<firstName>%V</firstName>', coalesce (WAUI_FIRST_NAME, '')), pStream);
    http (sprintf ('<lastName>%V</lastName>', coalesce (WAUI_LAST_NAME, '')), pStream);
    http (sprintf ('<fullName>%V</fullName>', coalesce (WAUI_FULL_NAME, '')), pStream);

    if (not pShort) {
      -- Contact
      http (sprintf ('<icq>%V</icq>', coalesce (WAUI_ICQ, '')), pStream);
      http (sprintf ('<skype>%V</skype>', coalesce (WAUI_SKYPE, '')), pStream);
      http (sprintf ('<yahoo>%V</yahoo>', coalesce (WAUI_AIM, '')), pStream);
      http (sprintf ('<aim>%V</aim>', coalesce (WAUI_YAHOO, '')), pStream);
      http (sprintf ('<msn>%V</msn>', coalesce (WAUI_MSN, '')), pStream);

      -- Home
      http (sprintf ('<homeCountry>%V</homeCountry>', coalesce (WAUI_HCOUNTRY, '')), pStream);
      http (sprintf ('<homeState>%V</homeState>', coalesce (WAUI_HSTATE, '')), pStream);
      http (sprintf ('<homeCity>%V</homeCity>', coalesce (WAUI_HCITY, '')), pStream);
      http (sprintf ('<homeCode>%V</homeCode>', coalesce (WAUI_HCODE, '')), pStream);
      http (sprintf ('<homeAddress1>%V</homeAddress1>', coalesce (WAUI_HADDRESS1, '')), pStream);
      http (sprintf ('<homeAddress2>%V</homeAddress2>', coalesce (WAUI_HADDRESS2, '')), pStream);

      -- Business
      http (sprintf ('<businessIndustry>%V</businessIndustry>', coalesce (WAUI_BINDUSTRY, '')), pStream);
      http (sprintf ('<businessOrganization>%V</businessOrganization>', coalesce (WAUI_BORG, '')), pStream);
      http (sprintf ('<businessJob>%V</businessJob>', coalesce (WAUI_BJOB, '')), pStream);
      http (sprintf ('<businessState>%V</businessState>', coalesce (WAUI_BSTATE, '')), pStream);
      http (sprintf ('<businessCity>%V</businessCity>', coalesce (WAUI_BCITY, '')), pStream);
      http (sprintf ('<businessCode>%V</businessCode>', coalesce (WAUI_BCODE, '')), pStream);
      http (sprintf ('<businessAddress1>%V</businessAddress1>', coalesce (WAUI_BADDRESS1, '')), pStream);
      http (sprintf ('<businessAddress2>%V</businessAddress2>', coalesce (WAUI_BADDRESS2, '')), pStream);
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
  in pDetail integer := 0
) returns varchar
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
  in pIcq varchar,
  in pSkype varchar,
  in pYahoo varchar,
  in pAim varchar,
  in pMsn varchar,
  in pHomeCountry varchar,
  in pHomeState varchar,
  in pHomeCity varchar,
  in pHomeCode varchar,
  in pHomeAddress1 varchar,
  in pHomeAddress2 varchar,
  in pBusinessIndustry varchar,
  in pBusinessOrganization varchar,
  in pBusinessJob varchar,
  in pBusinessCountry varchar,
  in pBusinessState varchar,
  in pBusinessCity varchar,
  in pBusinessCode varchar,
  in pBusinessAddress1 varchar,
  in pBusinessAddress2 varchar) returns varchar
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

    -- Contact
    WA_USER_EDIT (pUser, 'WAUI_ICQ', pIcq);
    WA_USER_EDIT (pUser, 'WAUI_SKYPE', pSkype);
    WA_USER_EDIT (pUser, 'WAUI_AIM', pYahoo);
    WA_USER_EDIT (pUser, 'WAUI_YAHOO', pAim);
    WA_USER_EDIT (pUser, 'WAUI_MSN', pMsn);

    -- Home
    WA_USER_EDIT (pUser, 'WAUI_HCOUNTRY', pHomeCountry);
    WA_USER_EDIT (pUser, 'WAUI_HSTATE', pHomeState);
    WA_USER_EDIT (pUser, 'WAUI_HCITY', pHomeCity);
    WA_USER_EDIT (pUser, 'WAUI_HCODE', pHomeCode);
    WA_USER_EDIT (pUser, 'WAUI_HADDRESS1', pHomeAddress1);
    WA_USER_EDIT (pUser, 'WAUI_HADDRESS2', pHomeAddress2);

    -- Business
    WA_USER_EDIT (pUser, 'WAUI_BINDUSTRY', pBusinessIndustry);
    WA_USER_EDIT (pUser, 'WAUI_BORG', pBusinessOrganization);
    WA_USER_EDIT (pUser, 'WAUI_BJOB', pBusinessJob);
    WA_USER_EDIT (pUser, 'WAUI_BCOUNTRY', pBusinessCountry);
    WA_USER_EDIT (pUser, 'WAUI_BSTATE', pBusinessState);
    WA_USER_EDIT (pUser, 'WAUI_BCITY', pBusinessCity);
    WA_USER_EDIT (pUser, 'WAUI_BCODE', pBusinessCode);
    WA_USER_EDIT (pUser, 'WAUI_BADDRESS1', pBusinessAddress1);
    WA_USER_EDIT (pUser, 'WAUI_BADDRESS2', pBusinessAddress2);

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
    http (sprintf ('<foaf>%s</foaf>', DB.DBA.WA_LINK (1, sprintf ('/dataspace/%s/about.rdf', pUser))), sStream);
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
grant execute on ODS_USER_LOGIN to GDATA_ODS;
grant execute on ODS_USER_LOGOUT to GDATA_ODS;
grant execute on ODS_USER_REGISTER to GDATA_ODS;
grant execute on ODS_USER_SELECT to GDATA_ODS;
grant execute on ODS_USER_UPDATE to GDATA_ODS;
grant execute on ODS_USER_UPDATE_PASSWORD to GDATA_ODS;
grant execute on ODS_USER_LINKS to GDATA_ODS;
grant execute on ODS_USER_LIST to GDATA_ODS;
