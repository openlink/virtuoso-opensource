use WV;

create procedure API_INIT ()
{
  if (exists (select 1 from "DB"."DBA"."SYS_USERS" where U_NAME = 'ODS_WIKI_API'))
    return;
  DB.DBA.USER_CREATE ('ODS_WIKI_API', uuid(), vector ('DISABLED', 1, 'LOGIN_QUALIFIER', 'WV'));
}
;


API_INIT ();

DB.DBA.VHOST_REMOVE (lpath=>'/services/wiki');
DB.DBA.VHOST_DEFINE (lpath=>'/services/wiki', ppath=>'/SOAP/', soap_user=>'ODS_WIKI_API');


create procedure RENDER (in content varchar, in lexer varchar) returns varchar
{
  declare plugins any;
  declare lexer_no, lexer_name, res varchar;

  plugins := PLUGIN_NAMES ();
  plugins := vector_concat (vector (vector (0, 'oWiki')), plugins);
  lexer_no := 0;
  foreach (any elm in plugins) do
    {
      --dbg_obj_print (elm);
      if (elm[1] = lexer)
	lexer_no := elm[0];
    }
  --dbg_obj_print (lexer_no);
  lexer_name := PLUGIN_BY_ID (cast (lexer_no as varchar));
  if (__proc_exists (lexer_name, 2) is null)
    {
      lexer_name := PLUGIN_BY_ID (null);
    }
  res := call (lexer_name) (content || '\r\n', 'Cluster', 'Topic', 'Wiki', vector ('SYNTAX', lexer_name));
  return res;
}
;

grant execute on RENDER to ODS_WIKI_API;

use DB;
