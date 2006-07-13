DB.DBA.VHOST_REMOVE (lpath=>'/sparql_demo/')
;
DB.DBA.VHOST_REMOVE (lpath=>'/sparql_demo')
;
--DB.DBA.VHOST_DEFINE (lpath=>'/sparql_demo/', ppath=>'/DAV/sparql_demo/', vsp_user=>'RQ', is_dav=>1)
--;
DB.DBA.VHOST_DEFINE (lpath=>'/sparql_demo/', ppath=>'/sparql_demo/', vsp_user=>'RQ')
;
