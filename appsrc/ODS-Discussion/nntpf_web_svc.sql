nntpf_exec_no_error(
'create table NNTPF_PING_REG
(
 NPR_HOST_ID int references ODS.DBA.SVC_HOST (SH_ID) on update cascade on delete cascade,
 NPR_NG_GROUP int references DB.DBA.NEWS_GROUPS (NG_GROUP) on update cascade on delete cascade,
 primary key (NPR_NG_GROUP, NPR_HOST_ID)
)');

nntpf_exec_no_error(
'create table NNTPF_PING_LOG
(
 NPL_HOST_ID int references ODS.DBA.SVC_HOST (SH_ID) on update cascade on delete cascade,
 NPL_NG_GROUP int references DB.DBA.NEWS_GROUPS (NG_GROUP) on update cascade on delete cascade,
 NPL_P_TITLE varchar default null,
 NPL_P_URL varchar default null,
 NPL_STAT int default 0, -- 1 sent, 2 error, 0 pending
 NPL_TS timestamp,
 NPL_SENT datetime,
 NPL_ERROR long varchar,
 NPL_SEQ integer identity,
 primary key (NPL_NG_GROUP, NPL_HOST_ID, NPL_STAT, NPL_SEQ)
)');

create procedure NNTPF_PING
  (
  in _ng_group int,
  in _post_title varchar := null,
  in _post_url varchar := null,
  in svc_name varchar := null
  )
{
  if (svc_name is null)
    {
      for select NPR_HOST_ID, NG_GROUP from NNTPF_PING_REG, DB.DBA.NEWS_GROUPS where NG_NAME = _ng_group do
  {
    if (not exists (select 1 from NNTPF_PING_LOG where NPL_NG_GROUP = NG_GROUP and NPL_HOST_ID = NPR_HOST_ID and NPL_STAT = 0))
      insert into NNTPF_PING_LOG (NPL_NG_GROUP, NPL_HOST_ID, NPL_STAT, NPL_P_TITLE, NPL_P_URL)
    values (NG_GROUP, NPR_HOST_ID, 0, _post_title, _post_url);
  }
    }
  else
    {
      declare s_id, _wai_id int;
      s_id := (select SH_ID from ODS.DBA.SVC_HOST where SH_NAME = svc_name);
      _ng_group := (select NG_GROUP from DB.DBA.NEWS_GROUPS where NG_GROUP = _ng_group);
      if (s_id is not null and _ng_group is not null and
          not exists (select 1 from NNTPF_PING_LOG where NPL_NG_GROUP = _ng_group and NPL_HOST_ID = s_id and NPL_STAT = 0)
         )
           insert into NNTPF_PING_LOG (NPL_NG_GROUP, NPL_HOST_ID, NPL_STAT, NPL_P_TITLE, nPL_P_URL)
                  values (_ng_group, s_id, 0, _post_title, _post_url);

    }
};
create procedure NNTPF_SVC_PROCESS_PINGS ()
{
  declare _host_id, _ng_group, dedl, seq int;
  declare nam, use_pings, _url, _title,_ng_url varchar;

  declare cr cursor for select NPL_HOST_ID, NPL_NG_GROUP, NG_DESC,  concat('/nntpf/nntpf_nthread_view.vspx?group=',NG_GROUP),NPL_P_TITLE, NPL_P_URL, NPL_SEQ from
      NNTPF_PING_LOG, DB.DBA.NEWS_GROUPS where NG_GROUP = NPL_NG_GROUP and NPL_STAT = 0;

  dedl := 0;

  declare exit handler for sqlstate '40001'
    {
      rollback work;
      close cr;
      dedl := dedl + 1;
      if (dedl < 5)
  goto again;
    };

again:
  whenever not found goto ret;
  open cr (prefetch 1);
  while (1)
  {
      fetch cr into _host_id, _ng_group, nam, _ng_url, _title, _url, seq;
      commit work;
      
      for select SH_URL, SH_PROTO, SH_METHOD from ODS.DBA.SVC_HOST where SH_ID = _host_id do
      {

      if (isstring (SH_PROTO) and SH_PROTO <> '' and _ng_url is not null)
        {
         declare url, rc varchar;
         rc := null;

         url := DB.DBA.WA_LINK (1, _url);

        if (length (_title))
          nam := _title;
        
        {
          declare exit handler for sqlstate '*' {
            rollback work;
            update NNTPF_PING_LOG set NPL_ERROR = __SQL_MESSAGE, NPL_STAT = 2, NPL_SENT = now ()
                 where NPL_NG_GROUP = _ng_group and NPL_HOST_ID = _host_id and NPL_STAT = 0 and NPL_SEQ = seq;
            commit work;
            goto next;
          };
        
          commit work;
--          dbg_printf ('[%s] [%s] [%s] [%s] [%s]', SH_PROTO, SH_URL, SH_METHOD, url, nam);
          if (SH_PROTO = 'soap')
            {
              rc := DB.DBA.SOAP_CLIENT (url=>SH_URL,
              operation=>'ping',
              parameters=>vector ('weblogname',nam,'weblogurl',url),
              soap_action=>'/weblogUpdates'
              );
            }
          else if (SH_PROTO = 'xml-rpc')
            {
              if (SH_METHOD = 'weblogUpdates.ping')
          {
            rc := DB.DBA.XMLRPC_CALL (SH_URL, 'weblogUpdates.ping', vector (nam, url));
          }
              else
          {
            rc := DB.DBA.XMLRPC_CALL (SH_URL, 'weblogUpdates.extendedPing',
            vector (nam, url, url, url || 'gems/rss.xml'));
          }
            }
          else if (SH_PROTO = 'REST')
            {
              declare hf, ping_url any;
              ping_url := sprintf ('%s%U', SH_URL, url);
              http_get (ping_url, hf);
              if (isarray (hf) and length (hf) and hf[0] not like 'HTTP/1._ 200 %')
          {
            rc := xml_tree (sprintf ('<response><flerror>1</flerror><message>%V</message></response>', hf[0]));
          }
            }
        }
        
        if (isarray(rc))
        {
          declare xt any;
          declare err, msg any;
          xt := xml_tree_doc (rc);
          err := cast (xpath_eval ('//flerror/text()', xml_cut(xt), 1) as varchar);
          msg := cast (xpath_eval ('//message/text()', xml_cut(xt), 1) as varchar);
          if (err <> '0')
          {
            update NNTPF_PING_LOG set NPL_ERROR = msg, NPL_STAT = 2, NPL_SENT = now ()
               where NPL_NG_GROUP = _ng_group and NPL_HOST_ID = _host_id and NPL_STAT = 0 and NPL_SEQ = seq;
            commit work;
            goto next;
          }
        }
        }
      }
      
      update NNTPF_PING_LOG set NPL_STAT = 1, NPL_SENT = now () where NPL_NG_GROUP = _ng_group and NPL_HOST_ID = _host_id and NPL_STAT = 0 and NPL_SEQ = seq;
      commit work;
      next:;
  }
  ret:
  close cr;
  return;
};


insert soft "DB"."DBA"."SYS_SCHEDULED_EVENT" (SE_INTERVAL, SE_LAST_COMPLETED, SE_NAME, SE_SQL, SE_START)
  values (10, NULL, 'NNTPF NOTIFICATIONS', 'DB.DBA.NNTPF_SVC_PROCESS_PINGS()', now());
