use WV;

create procedure ADD_ERROR(in code varchar, in message varchar)
{
  declare _id varchar;
again:
  _id := uuid();
  if (exists (select 1 from ERRORS where E_ID = _id))
    goto again;
  insert into ERRORS(E_ID, E_DT, E_CODE, E_MESSAGE)
    values (_id, now(), code, message);
  return _id;
}
;


create procedure WIPE_OLD_ERRORS(in days int)
{
  delete from ERRORS where datediff ('day', E_DT, now()) >= days;
}
;

create procedure SEND_NOTIFICATION(in eid varchar)
{
  declare smtp, dav_email  varchar;
  smtp := cfg_item_value(virtuoso_ini_path(), 'HTTPServer', 'DefaultMailServer');
  dav_email := (select U_E_MAIL from DB.DBA.SYS_USERS where U_ID = http_dav_uid());
  if (smtp is null or dav_email is null)
    return '';
  smtp_send(smtp, dav_email, dav_email, 
  	sprintf ('Date: %s\r\n' || 
		 'Subject: Application registration notification\r\nContent-Type: text/plain; charset=UTF-8\r\n' ||
		 'New error has been reported: %s/error.vspx?id=%s',  db.dba.date_rfc1123 (now ()), RESOURCE_PATH(), eid));

}
;


use DB;
