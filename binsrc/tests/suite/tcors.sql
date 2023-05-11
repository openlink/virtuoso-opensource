ECHO BOTH "STARTED: CORS tests\n";
VHOST_REMOVE (lpath=>'/cors-a');
VHOST_REMOVE (lpath=>'/cors-l');
VHOST_REMOVE (lpath=>'/cors-s');
VHOST_REMOVE (lpath=>'/DAV/cors-l');
VHOST_REMOVE (lpath=>'/DAV/cors-s');

DAV_COL_CREATE_INT ('/DAV/cors-l/', '111110110R', 'dav', 'administrators', 'dav', null, 1, 0, 0);
DAV_COL_CREATE_INT ('/DAV/cors-s/', '111110110R', 'dav', 'administrators', 'dav', null, 1, 0, 0);

-- *,X-Allowed,!X-Denied is contradiction, it is reduced to star, kept to detect double free
VHOST_DEFINE (lpath=>'/cors-a', ppath=>'/', vsp_user=>'dba', opts=>vector ('cors','*','cors_allow_headers','*,X-Allowed,!X-Denied'));
VHOST_DEFINE (lpath=>'/cors-l', ppath=>'/', vsp_user=>'dba', opts=>vector ('cors','*','cors_allow_headers','X-Allowed,!X-Denied'));
VHOST_DEFINE (lpath=>'/cors-s', ppath=>'/', vsp_user=>'dba', opts=>vector ('cors','*','cors_allow_headers','X-Allowed,!ALL'));

VHOST_DEFINE (lpath=>'/DAV/cors-l', ppath=>'/DAV/home/cors-l/', is_dav=>1,
    vsp_user=>'dba', opts=>vector ('cors','*','cors_allow_headers','X-Allowed,!X-Denied'));
VHOST_DEFINE (lpath=>'/DAV/cors-s', ppath=>'/DAV/home/cors-s/', is_dav=>1,
    vsp_user=>'dba', opts=>vector ('cors','*','cors_allow_headers','X-Allowed,!ALL'));

create procedure split_header_response (in h any)
{
  declare arr any;
  declare i int;
  arr := split_and_decode (h,0,'\0\0,');
  for (i := 0; i < length (arr); i := i + 1)
    arr[i] := trim (upper(arr[i]));
  return arr;
};

create procedure tcors_allowed_try (in meth varchar, in path varchar, in header varchar, in is_expected int)
{
  declare url, cli_headers varchar;
  declare headers_ret, resp any;
  declare code, message varchar;
  result_names (code, message);
  message := sprintf ('%s %s %s', meth, path, header);
  url := sprintf ('http://localhost:%s%s', server_http_port(), path);
  cli_headers := sprintf ('Origin:http://localhost:%s\r\n', server_http_port());
  if (upper (meth) = 'OPTIONS')
    cli_headers := cli_headers || 'Access-Control-Request-Headers:'||header;
  HTTP_CLIENT_EXT (url=>url, http_method=>upper(meth), http_headers=>cli_headers, headers=>headers_ret);
  resp := http_request_header (headers_ret, 'Access-Control-Allow-Headers');
  resp := split_header_response (resp);
  if (is_expected and position (upper(header), resp))
    {
      result ('PASSED', message);
      return;
    }
  if (is_expected = 0 and 0 = position (upper(header), resp))
    {
      result ('PASSED', message);
      return;
    }
  result ('***FAILED', message);
};


tcors_allowed_try ('OPTIONS', '/cors-a', 'X-Any', 1);
ECHO BOTH $LAST[1] ": " $LAST[2] "\n";
tcors_allowed_try ('OPTIONS', '/cors-a', 'X-Allowed', 1);
ECHO BOTH $LAST[1] ": " $LAST[2] "\n";
tcors_allowed_try ('OPTIONS', '/cors-a', 'X-Denied', 1);
ECHO BOTH $LAST[1] ": " $LAST[2] "\n";


tcors_allowed_try ('OPTIONS', '/cors-l', 'X-Any', 1);
ECHO BOTH $LAST[1] ": " $LAST[2] "\n";
tcors_allowed_try ('OPTIONS', '/cors-l', 'X-Allowed', 1);
ECHO BOTH $LAST[1] ": " $LAST[2] "\n";
tcors_allowed_try ('OPTIONS', '/cors-l', 'X-Denied', 0);
ECHO BOTH $LAST[1] ": " $LAST[2] "\n";


tcors_allowed_try ('OPTIONS', '/cors-s', 'X-Any', 0);
ECHO BOTH $LAST[1] ": " $LAST[2] "\n";
tcors_allowed_try ('OPTIONS', '/cors-s', 'X-Allowed', 1);
ECHO BOTH $LAST[1] ": " $LAST[2] "\n";
tcors_allowed_try ('OPTIONS', '/cors-s', 'X-Denied', 0);
ECHO BOTH $LAST[1] ": " $LAST[2] "\n";


tcors_allowed_try ('OPTIONS', '/DAV/cors-l', 'X-Any', 1);
ECHO BOTH $LAST[1] ": " $LAST[2] "\n";
tcors_allowed_try ('OPTIONS', '/DAV/cors-l', 'X-Allowed', 1);
ECHO BOTH $LAST[1] ": " $LAST[2] "\n";
tcors_allowed_try ('OPTIONS', '/DAV/cors-l', 'X-Denied', 0);
ECHO BOTH $LAST[1] ": " $LAST[2] "\n";


tcors_allowed_try ('OPTIONS', '/DAV/cors-s', 'X-Any', 0);
ECHO BOTH $LAST[1] ": " $LAST[2] "\n";
tcors_allowed_try ('OPTIONS', '/DAV/cors-s', 'X-Allowed', 1);
ECHO BOTH $LAST[1] ": " $LAST[2] "\n";
tcors_allowed_try ('OPTIONS', '/DAV/cors-s', 'X-Denied', 0);
ECHO BOTH $LAST[1] ": " $LAST[2] "\n";


tcors_allowed_try ('GET', '/cors-l', 'X-Any', 0);
ECHO BOTH $LAST[1] ": " $LAST[2] "\n";
tcors_allowed_try ('GET', '/cors-l', 'X-Allowed', 1);
ECHO BOTH $LAST[1] ": " $LAST[2] "\n";
tcors_allowed_try ('GET', '/cors-l', 'X-Denied', 0);
ECHO BOTH $LAST[1] ": " $LAST[2] "\n";


tcors_allowed_try ('GET', '/cors-s', 'X-Any', 0);
ECHO BOTH $LAST[1] ": " $LAST[2] "\n";
tcors_allowed_try ('GET', '/cors-s', 'X-Allowed', 1);
ECHO BOTH $LAST[1] ": " $LAST[2] "\n";
tcors_allowed_try ('GET', '/cors-s', 'X-Denied', 0);
ECHO BOTH $LAST[1] ": " $LAST[2] "\n";

ECHO BOTH "COMPLETED CORS tests\n";
