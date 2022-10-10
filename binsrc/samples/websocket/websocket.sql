--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2022 OpenLink Software
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
create procedure DB.DBA.WEBSOCKET_WRITE_MESSAGE (in sid int, in message varchar)
{
  declare ses, data any;
  -- get cached
  ses := http_recall_session (sid, 0);
  -- write something
  ses_write (DB.DBA.WEBSOCKET_ENCODE_MESSAGE (message), ses);
  -- put back in cache 
  http_keep_session (ses, sid);
}
;

create procedure WSOCK_ECHO (in message varchar, in args any)
{
  return message;
}
;

create procedure DB.DBA.WEBSOCKET_ONMESSAGE_CALLBACK (inout ses any, inout cd any)
{
  declare data any;
  declare service_hook, args, reponse any;
  if (isvector (cd) and length (cd) > 1)
    {
      service_hook := aref (cd, 0);
      args := aref (cd, 1);
    }
  else
    {
      return;
    }
  -- input is there, read a line
  data := ses_read (ses, 2);
  if (0 <> data)
    {
      declare mask, unmaskedPayload, tmp, reply, request any;
      declare firstByte, secondByte, opcode, is_masked, payload_len, i integer;
      declare result varchar;

      firstByte  := data[0];
      secondByte := data[1];
      opcode := bit_and (firstByte, 15);
      is_masked :=  case when (bit_and (secondByte, 128) = 128) then 1 else 0 end;
      payload_len := bit_and (secondByte, 127);

      if (not is_masked) -- client message must be masked
        signal ('22023', 'Request must be masked.');
      if (opcode <> 1 and opcode <> 8) -- not text or close
        signal ('22023', 'Only 1 frame text supported.');

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
      mask := ses_read (ses, 4);
      result := make_string (payload_len);
      request := ses_read (ses, payload_len);
      for (i := 0; i < payload_len; i := i + 1)
        {
          result[i] := bit_xor(request[i], mask[mod(i, 4)]);
        }
      if (opcode = 8)
        return;
      -- simply echo back
      reponse := call (service_hook) (result, args);
      reply := DB.DBA.WEBSOCKET_ENCODE_MESSAGE (reponse);
      -- write a reply (optional)
      ses_write(reply, ses);
    }
  -- set recv handler back
  http_on_message (ses, 'DB.DBA.WEBSOCKET_ONMESSAGE_CALLBACK', cd);
}
;

create procedure DB.DBA.WEBSOCKET_ENCODE_MESSAGE (in message any, in domask int := 0) returns any
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

create procedure DB.DBA.WEBSOCKET_BUILD_SERVER_PARTIAL_KEY (
  in key_str varchar) returns any
{
  -- dbg_obj_princ ('DB.DBA.WEBSOCKET_BUILD_SERVER_PARTIAL_KEY (', key_str, ')');
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


create procedure WSOCK.WSOCK."websockets" () __SOAP_HTTP 'text/plain'
{
  declare upgrade, host, x, connection, content, sec_websocket_key, service_name, sec_websocket_version, origin, sec_websocket_protocol, s any;
  declare sec_websocket_extensions any;
  declare sec_websocket_accept, header any;
  declare ses any;
  declare sid int;
  declare lines, params, opts any;
  declare func varchar;

  lines := http_request_header ();
  params := http_param ();
  opts := http_map_get ('options');

  func := get_keyword_ucase ('websocket_service_call', opts, null);
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
  sid := atoi(get_keyword ('sid', params, '1'));

  if (http_client_session_cached (sid))
    {
      http_status_set (400);
      return;
    }

  if (upgrade = 'websocket' and sec_websocket_version = '13')
   {
     -- set callback for recv
     http_on_message (null, 'DB.DBA.WEBSOCKET_ONMESSAGE_CALLBACK', vector (func, sid));
     -- cache session and send http status
     http_keep_session (null, sid, 0);

     sec_websocket_accept := sha1_digest (concat (sec_websocket_key, '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'));
     header := sprintf ('Upgrade: %s\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: %s\r\n', upgrade, sec_websocket_accept);
     if (sec_websocket_protocol is not null)
       header := sprintf ('%sSec-WebSocket-Protocol: %s\r\n', header, sec_websocket_protocol);

     http_status_set (101);
     http_header (header);
   }
  else
   {
     http_status_set (400);
   }
 return '';
}
;
