--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2025 OpenLink Software
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
create procedure WSOCK.DBA.WEBSOCKET_WRITE_MESSAGE (in sid int, in message varchar, in encode int default 0)
{
  declare ses, data, payload any;
  payload := WSOCK.DBA.WEBSOCKET_ENCODE_MESSAGE (message, encode);
  -- get cached
  ses := http_recall_session (sid, 0);
  -- write something
  ses_write (payload, ses);
  -- put back in cache 
  http_keep_session (ses, sid);
}
;

create procedure WSOCK.DBA.WEBSOCKET_CLOSE_MESSAGE (in sid int, in code int, in message varchar, in encode int default 0)
{
  declare c, ses, payload any;
  message := subseq (message, 0, 125 - 2); -- only short errors
  if (code <> bit_and (code, 0hex7fff))
    signal ('22023', 'Only short int is allowed for code');
  c := '00';
  c := short_set (c, 0, code);
  payload := WSOCK.DBA.WEBSOCKET_ENCODE_MESSAGE (concat (c,message), encode);
  aset(payload, 0, 136);

  ses := http_recall_session (sid, 0);
  ses_write (payload, ses);
  http_keep_session (ses, sid);
  return;
}
;

create procedure WSOCK.DBA.SEND_PING (in sid bigint, in message varchar := null, in encode int default 0)
{
  declare ping varchar;
  declare ses any;
  message := subseq (message, 0, 125);
  ping := WSOCK.DBA.WEBSOCKET_ENCODE_MESSAGE(message, encode);
  aset (ping, 0, 137);
  ses := http_recall_session (sid, 0);
  ses_write (ping, ses);
  http_keep_session (ses, sid);
}
;

create procedure WSOCK.DBA.WEBSOCKET_ECHO (in message varchar, in args any)
{
  return message;
}
;

create procedure WSOCK.DBA.WEBSOCKET_ONMESSAGE_CALLBACK (inout ses any, inout cd any)
{
  return WSOCK.DBA.WEBSOCKET_CALLBACK (ses, cd, 1);
}
;

create procedure WSOCK.DBA.WEBSOCKET_ON_SERVER_MESSAGE_CALLBACK (inout ses any, inout cd any)
{
  return WSOCK.DBA.WEBSOCKET_CALLBACK (ses, cd, 0);
}
;

create procedure WSOCK.DBA.WEBSOCKET_CALLBACK (inout ses any, inout cd any, in server int)
{
  declare data any;
  declare service_hook, args, response, payload any;
  declare mask_message int;
  declare callback_name varchar;
  if (isvector (cd) and length (cd) > 1)
    {
      service_hook := aref (cd, 0);
      args := aref (cd, 1);
      payload := aref_set_0 (cd, 2);
    }
  else
    {
      return;
    }
  if (server)
    {
      callback_name := 'WSOCK.DBA.WEBSOCKET_ONMESSAGE_CALLBACK';
      mask_message := 0;
    }
  else
    {
      callback_name := 'WSOCK.DBA.WEBSOCKET_ON_SERVER_MESSAGE_CALLBACK';
      mask_message := 1;
    }
  -- input is there, read a line
  data := ses_read (ses, 2);
  if (0 <> data)
    {
      declare mask, unmaskedPayload, tmp, reply, request any;
      declare firstByte, secondByte, opcode, is_masked, payload_len, i, fin integer;
      declare result varchar;

      firstByte  := data[0];
      secondByte := data[1];
      opcode := bit_and (firstByte, 15);
      fin := bit_shift (firstByte, -7);
      is_masked :=  case when (bit_and (secondByte, 128) = 128) then 1 else 0 end;
      payload_len := bit_and (secondByte, 127);
      if (not is_masked and server) -- client message must be masked
        signal ('22023', 'Request must be masked.');
      if (is_masked and not server) -- client message must be masked
        signal ('22023', 'Request must NOT be masked.');
      if (opcode <> 1 and opcode <> 2 and opcode <> 8 and opcode <> 0 and opcode <> 9 and opcode <> 10) -- supported: text, binary, close, ping, pong, frame
        signal ('22023', sprintf ('A frame of type %d is not supported.', opcode));

      if (opcode = 0 and payload is null)
        signal ('22023', 'Continuation frame w/o preceeding message');

      if (payload_len = 127) -- 64bit length
        {
          tmp := ses_read (ses, 8);
          payload_len := (long_ref(tmp,0) * 0hex100000000) + long_ref(tmp,1);
        }
      else if (payload_len = 126) -- 16bit length
        {
          tmp := ses_read (ses, 2);
          payload_len := tmp[1] + 256 * tmp[0];
        }
      if (server)
        {
          mask := ses_read (ses, 4);
          result := make_string (payload_len);
          request := ses_read (ses, payload_len);
          for (i := 0; i < payload_len; i := i + 1)
            {
              result[i] := bit_xor(request[i], mask[mod(i, 4)]);
            }
        }
      else
        {
          result := ses_read (ses, payload_len);
        }
      if (opcode = 8)
        return;
      payload := concat (payload, result);

      if (opcode = 9) -- ping, send pong
        {
          reply := WSOCK.DBA.WEBSOCKET_ENCODE_MESSAGE(payload, mask_message);
          aset (reply, 0, 138);
          ses_write(reply, ses);
          payload := null;
          fin := 0; -- do not call service hook
        }

      if (opcode = 10) -- pong, do nothing
        {
          payload := null;
          fin := 0;
        }

      if (fin = 1)
        {
          response := call (service_hook) (payload, args);
          aset (cd, 2, null);
        }
      else
        {
          aset (cd, 2, payload);
          response := null;
        } 
      -- simply echo back
      if (response = 0)
        return;
      if (response is not null)
        {
          -- write a reply (optional)
          reply := WSOCK.DBA.WEBSOCKET_ENCODE_MESSAGE (response, mask_message);
          ses_write(reply, ses);
        }
    }
  -- set recv handler back
  http_on_message (ses, callback_name, cd, 0);
}
;

create procedure WSOCK.DBA.WEBSOCKET_ENCODE_MESSAGE (in message any, in domask int := 0) returns any
{
  declare header, ret, mask any;
  declare i, len, first_byte, second_byte integer;

  first_byte := 129;
  len := length (message);
  if (len <= 125)
  {
    header := make_string(2);
    header[0] := first_byte;
    header[1] := len;
  }
  else if (len <= 65535)
  {
    header := make_string(4);
    header[0] := first_byte;
    header[1] := 126;
    header[2] := bit_and (bit_shift (len, -8), 255);
    header[3] := bit_and (len, 255);
  }
  else
  {
    header := make_string(10);
    header[0] := first_byte;
    header[1] := 127;
    header[2] := bit_and (bit_shift (len, -56), 255);
    header[3] := bit_and (bit_shift (len, -48), 255);
    header[4] := bit_and (bit_shift (len, -40), 255);
    header[5] := bit_and (bit_shift (len, -32), 255);
    header[6] := bit_and (bit_shift (len, -24), 255);
    header[7] := bit_and (bit_shift (len, -16), 255);
    header[8] := bit_and (bit_shift (len, -8), 255);
    header[9] := bit_and (len, 255);
  }
  if (domask)
    {
      second_byte := bit_or (header[1], 128);
      header[1] := second_byte;
      mask := cast (xenc_rand_bytes (4,0) as varchar);
      for (i := 0; i < len; i := i + 1)
         message[i] := bit_xor (message[i], mask[mod(i, 4)]);
       ret := concat (header, mask, message);
    }
  else
    {
      ret := concat (header, message);
    }
  return ret;
}
;

create procedure WSOCK.DBA.WEBSOCKET_BUILD_SERVER_PARTIAL_KEY (
  in key_str varchar) returns any
{
  -- dbg_obj_princ ('WSOCK.DBA.WEBSOCKET_BUILD_SERVER_PARTIAL_KEY (', key_str, ')');
  declare i, key_length, spaceNumber, res integer;
  declare partialServerKey, cur, num64 varchar;
  declare bytesFormatted any;

  key_length := length (key_str);
  partialServerKey := '';
  spaceNumber := 0;
  for (i := 0; i < key_length; i := i + 1)
  {
    cur := chr (key_str[i]);
    if (strcontains ('0123456789', cur))
      partialServerKey := partialServerKey || cur;

    if (cur = ' ')
      spaceNumber := spaceNumber + 1;
  }
  num64 := cast ((cast (partialServerKey as numeric) / spaceNumber) as integer);
  bytesFormatted := make_string(4);
  bytesFormatted[0] := bit_and (bit_shift (num64, -24), 255);
  bytesFormatted[1] := bit_and (bit_shift (num64, -16), 255);
  bytesFormatted[2] := bit_and (bit_shift (num64, -8), 255);
  bytesFormatted[3] := bit_and (num64, 255);

  return bytesFormatted;
}
;


create procedure WSOCK.DBA."websockets" () __SOAP_HTTP 'text/plain'
{
  declare upgrade, host, x, connection, content, sec_websocket_key, service_name, sec_websocket_version, origin, sec_websocket_protocol, s any;
  declare sec_websocket_extensions any;
  declare sec_websocket_accept, header any;
  declare ses any;
  declare sid int;
  declare lines, params, opts any;
  declare func, connect_func varchar;

  lines := http_request_header ();
  params := http_param ();
  opts := http_map_get ('options');

  func := get_keyword_ucase ('websocket_service_call', opts, null);
  connect_func := get_keyword_ucase ('websocket_service_connect', opts, null);
  if (func is null or not __proc_exists (func))
    {
      http_status_set (400);
      return;
    }

  host := http_request_header (lines, 'Host', null, null);
  upgrade := http_request_header (lines, 'Upgrade', null, null);
  connection := http_request_header (lines, 'Connection', null, null);
  sec_websocket_key := http_request_header (lines, 'Sec-WebSocket-Key', null, null);
  sec_websocket_version := http_request_header (lines, 'Sec-WebSocket-Version', null, null);
  sec_websocket_extensions := http_request_header (lines, 'Sec-WebSocket-Extensions', null, null);
  origin := http_request_header (lines, 'Origin', null, null);
  sec_websocket_protocol := http_request_header (lines, 'Sec-WebSocket-Protocol', null, null);
  sid := get_keyword ('sid', params);
  if (sid is null)
    sid := long_ref (xenc_rand_bytes (4,0),0);
  else
    sid := atoi (sid);

  if (http_client_session_cached (sid))
    {
      http_status_set (400);
      return;
    }

  if (upgrade = 'websocket' and sec_websocket_version = '13')
   {
     -- set callback for recv
     http_on_message (null, 'WSOCK.DBA.WEBSOCKET_ONMESSAGE_CALLBACK', vector (func, sid, null));
     -- cache session and send http status
     http_keep_session (null, sid, 0);

     sec_websocket_accept := sha1_digest (concat (sec_websocket_key, '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'));
     header := sprintf ('Upgrade: %s\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: %s\r\n', upgrade, sec_websocket_accept);
     if (sec_websocket_protocol is not null)
       header := sprintf ('%sSec-WebSocket-Protocol: %s\r\n', header, sec_websocket_protocol);

     http_status_set (101);
     http_header (header);
     if (connect_func is not null and __proc_exists (connect_func))
       call (connect_func) (sid);
   }
  else
   {
     http_status_set (400);
   }
 return '';
}
;

create procedure WSOCK.DBA.WEBSOCKET_CONNECT(in url varchar, in headers varchar default null, in sid bigint default null,
    in callback varchar default null, in args any default null)
{
  declare resp, conn any;
  declare token, sec varchar;
  token := encode_base64(xenc_rand_bytes(16,0));
  if (sid is null)
    sid := long_ref (xenc_rand_bytes (4,0),0);
  if (headers is not null)
    headers := concat(rtrim(headers, '\r\n'), '\r\n');
  headers := concat (headers, 'Sec-WebSocket-Version: 13\r\n',
    'Sec-WebSocket-Key: ', token, '\r\n',
    'Connection: Upgrade\r\n',
    'Upgrade: websocket\r\n');
  conn := HTTP_CLIENT_EXT(url, http_method=>'GET', http_headers=>headers, headers=>resp);
  sec := http_request_header (resp, 'Sec-WebSocket-Accept', null, null);
  if (sec <> sha1_digest (concat (token, '258EAFA5-E914-47DA-95CA-C5AB0DC85B11')))
    signal('37000', 'Can not connect to websocket');
  if (__tag(conn) = 241)
    {
      http_on_message (conn, 'WSOCK.DBA.WEBSOCKET_ON_SERVER_MESSAGE_CALLBACK', vector (callback, args, null), 1, 1);
      http_keep_session(conn, sid, 0);
    }
  return sid;
}
;
