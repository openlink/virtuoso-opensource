--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2018 OpenLink Software
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

-- ---------------------------------------------------
-- OpenX 'MODULE_NAME' code generation file.
-- ---------------------------------------------------


CREATE PROCEDURE OMAIL.WA.res_resource_temp()
{
  DECLARE img,mp3,pdf,doc,win,zip,htm,cdr,cal,psd,txt,mpg VARCHAR;

  img := decode_base64('R0lGODlhEAAQALMAAAAAhAD//wCEhAD/AACEAIQAAP///8bGxoSEhAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAEAAAMALAAAAAAQABAAAARUcMhJawU4ZzuA+aCBAJYXfohBUuaJvAl7nvEEvDiS4LUEBMAgIdjrAAXABCGRZAUEB4GSsAwUAdCDVsm0shDaw3SpY4XDhfC1wG67r7NQMUGv2+kRADs=');
  mp3 := decode_base64('R0lGODlhEAAQAMQAAN7e3tbW1sbGxr29vbW1ta2trZycnJSUlIyMjHt7e3Nzc2tra2NjY1paWlJSUkpKSkJCQjk5OTExMSkpKSEhIRgYGBAQEAgICAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACwAAAAAEAAQAAAFfGAljmRZUlIERRJltg7ztFTdktPSRGZVj5EF7xShTESUyONUkch+FYhLJHEYH43FZOIqIg2ARSXSUES2yRElERBLEAfHtnIEKiCWBYEgd02RPg0DAgVSR1AjDgaDDFs8aWoMBnFFUj10RjVeEhKXPp01FhYXpKWioqQWFSEAOw==');
  pdf := decode_base64('R0lGODlhEAAQAKIAAAD/AP8xAN7e3sbGxrW1tYSEhAgICAAAACH5BAEAAAAALAAAAAAQABAAAANLCHrcfioeQSs1Ab4tcD5BKIqTYRrgOE7VxrWRYRGEJUCKXA2FjQM6CqFQg+UsBZ7lFxzUhjQCk8KLDguF3wRqozCvXW8MGxbnXI8EADs=');
  doc := decode_base64('R0lGODlhEAAQAKIAAAAA/wD/AP///8bGxoSEhAAAAAAAAAAAACH5BAEAAAEALAAAAAAQABAAAANRGErcrjAQQSslRYGyOy+XkIFWBVBF+nne4ApDuolnRw0wJ9RgEePAFG21A+Z4MQDO94r1eJRTJVmqMIOrrPSWWZRcza6kaolBCOB0WoxRud0JADs=');
  win := decode_base64('R0lGODlhEAAQALMAAAAA/wD/AACEAP//AP8AAP///8bGxoSEhAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAEAAAEALAAAAAAQABAAAARMMMhDq5U4nMI7N0emeZ5RhNhGckiLpGv5TnFnzCPRuR+uEgREUIAo3GAAo6ulhBUAAER0UDzSqkuss3Uw3Zq0GngktmoM6LTanG23IgA7');
  zip := decode_base64('R0lGODlhEAAQAMQAAJzO/2OczgBjnGPO/wCczgAxMTHOzgD/AM7OMf//nP//zv//986cAP/OMf/OY//OnP8AAP///wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAEAAAcALAAAAAAQABAAAAVo4CGOh2SeBQmtpUAQhjEE6QElj1OcvACkq6CQJQFIbJHIQoFzNBrH4hGiVDCdz6jRtrxioaUtZJlwfBHaKTP3fDLStma7wXiHp7y8yVcjSVwwMjQkfnl9hIQSBIiJAop/f4wHjo4EkCEAOw==');
  htm := decode_base64('R0lGODlhDwAPALMAAAAA/wAAhDXFcv//AISEAP///8bGxoSEhAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAEAAAIALAAAAAAPAA8AAARSUMhDa5VYnMJ7MUemeZ1RhNjGAQCHvAgWsEBQtJwRCwEx0LZSrPfjzIKfmI8GFBIMR5KTMAMYoDUnAFFlIZMCgACGUAklALNUl7q632wJeQ6LAAA7');
  cdr := decode_base64('R0lGODlhEAAQANUAAMYhQqUhQsYAQoQhQsZjhKUAQoQAQsZChGMAQqUAhIQhhEJChISE/8bG/wAh/yFC/0Jj/2OE/wAhhCFj/wBj/yGE/wBChCGl/2PG/yHG/0KEhEKlhGPGhGP/hAAhAKX/hKXGhMb/hEJjAMb/QqWlAP//QsbGQv//hGNjQsalQv/GQsaEAP+lAP+EAP+lQsaEQv9jAKVjQv9CAMZjQsYhAP8AAMYAAKUAAIQAAMZCQv+EhKWEhP///wAAAAAAAAAAACH5BAEAADwALAAAAAAQABAAAAaKQJ6Qx3hIFo7FYsjkQSiZyuQyoUiavAhm0+FwNxrLlcn5gEIh08lEEnlQQ9DopKKzTiwVawUXqkp0dnp6LS5DLn8qhC2FLC0pTC2OMDI0lTAwK00vlDk3NzQ3NjYzWDo1AJ8BnzdYQjMCBTgBOAOuQwQJBgYKt0wHCAi+TA07O8NDDTExyELKzFhBADs=');
  cal := decode_base64('R0lGODlhEAAQAKIAAAAAhDXFcoSGhMbHxoQAAP///wAAAAAAACH5BAEAAAEALAAAAAAQABAAAANEKLrcJiBK0NSbsopXyuifB3acaIbhM6zsSrzEWqIdUZPCaNoFr7YsWGww09EKxZPuB2wSc8po8pgyWK/YrCHA7Xq/gQQAOw==');
  psd := decode_base64('R0lGODlhEAAQAKIAADXFcoQAAP///8bGxoSEhAAAAAAAAAAAACH5BAEAAAAALAAAAAAQABAAAANICFrcXiqWQSstAb49cPZBKGadM55TtW0EcUnCEFdtCy10rd/AVA86m6QlCAIJvEKsqKMgYTmXCjazTBeCrJUiSGa/lW9y9UgAADs=');
  txt := decode_base64('R0lGODlhEAAQAKIAADXFcv///8bGxoSEhAAAAAAAAAAAAAAAACH5BAEAAAAALAAAAAAQABAAAANACErB3ioCNkK9MNbHM6hBKIoCoY1oUJ4N4TCqqYBpuM6hq8P3V5MyX2tnC9JqPdDOVWT9kr/mTECtWnuT5TKSAAA7');
  mpg := decode_base64('R0lGODlhEAAQALMAAAAAhAD//wCEhDXFcv8AAP///8bGxoSEhAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAEAAAMALAAAAAAQABAAAARYcMhxqrUzn8J7MUcmbR5nFKFWckiLqKuJCBMZG7MQCHwvcBWcoBUoIopDwQGBe7mOyCMOJ9EVr8MZ8zUQEIwBBABRaFEHz9aYLIPduKNYu2ao2+9wdHofAQA7');
  psd := decode_base64('R0lGODlhEAAQAKIAAAD/DIQAAP///8bGxoSEhAAAAAAAAAAAACH5BAEAAAAALAAAAAAQABAAAANICFrcXiqWQSstAb49cPZBKGadM55TtW0EcUnCEFdtCy10rd/AVA86m6QlCAIJvEKsqKMgYTmXCjazTBeCrJUiSGa/lW9y9UgAADs=');

  UPDATE OMAIL.WA.RES_MIME_TYPES SET ICON16=img WHERE ID IN (20100,20110,20120,20130,20140,20150,20160,20170,20180,20190,20200,20210,20220);
  UPDATE OMAIL.WA.RES_MIME_TYPES SET ICON16=cdr WHERE ID IN (20230);
  UPDATE OMAIL.WA.RES_MIME_TYPES SET ICON16=psd WHERE ID IN (20240);
  UPDATE OMAIL.WA.RES_MIME_TYPES SET ICON16=mp3 WHERE ID IN (40100,40110,40120,40130,40140,40150,40160);
  UPDATE OMAIL.WA.RES_MIME_TYPES SET ICON16=pdf WHERE ID IN (30170);
  UPDATE OMAIL.WA.RES_MIME_TYPES SET ICON16=doc WHERE ID IN (30140);
  UPDATE OMAIL.WA.RES_MIME_TYPES SET ICON16=win WHERE ID IN (30100);
  UPDATE OMAIL.WA.RES_MIME_TYPES SET ICON16=zip WHERE ID IN (30520,30530,30540);
  UPDATE OMAIL.WA.RES_MIME_TYPES SET ICON16=htm WHERE ID IN (10110);
  UPDATE OMAIL.WA.RES_MIME_TYPES SET ICON16=cal WHERE ID IN (10160);
  UPDATE OMAIL.WA.RES_MIME_TYPES SET ICON16=txt WHERE ID IN (10100,10120);
  UPDATE OMAIL.WA.RES_MIME_TYPES SET ICON16=mpg WHERE ID IN (50100,50110,50120,50130);

  return 1;
}
;


-- text - ID 10xxx
OMAIL.WA.res_mime_create(10100,'text/plain', '')
;
OMAIL.WA.res_mime_create(10110,'text/html', '')
;
OMAIL.WA.res_mime_create(10120,'text', '')
;
OMAIL.WA.res_mime_create(10125,'message/rfc822', '')
;
OMAIL.WA.res_mime_create(10150,'text/x-vcard', '')
;
OMAIL.WA.res_mime_create(10160,'text/calendar', '')
;
OMAIL.WA.res_mime_create(10170,'text/richtext', '')
;
OMAIL.WA.res_mime_create(10180,'text/rtf', '')
;
OMAIL.WA.res_mime_create(10190,'text/sgml', '')
;
OMAIL.WA.res_mime_create(10200,'text/tab-separated-values', '')
;
OMAIL.WA.res_mime_create(10210,'text/x-setext', '')
;
OMAIL.WA.res_mime_create(10220,'text/xml', '')
;
OMAIL.WA.res_mime_create(10230,'text/xsl','')
;
OMAIL.WA.res_mime_create(10240,'text/css', '')
;

-- image - ID 20xxx ------------------------------------------------------------
OMAIL.WA.res_mime_create(20100,'image/gif', '')
;
OMAIL.WA.res_mime_create(20110,'image/ief', '')
;
OMAIL.WA.res_mime_create(20120,'image/jpeg', '')
;
OMAIL.WA.res_mime_create(20130,'image/png', '')
;
OMAIL.WA.res_mime_create(20140,'image/tiff', '')
;
OMAIL.WA.res_mime_create(20150,'image/pjpeg', '')
;
OMAIL.WA.res_mime_create(20160,'image/x-portable-anymap', '')
;
OMAIL.WA.res_mime_create(20170,'image/x-portable-bitmap', '')
;
OMAIL.WA.res_mime_create(20180,'image/x-portable-graymap', '')
;
OMAIL.WA.res_mime_create(20190,'image/x-portable-pixmap', '')
;
OMAIL.WA.res_mime_create(20200,'image/x-rgb', '')
;
OMAIL.WA.res_mime_create(20210,'image/x-xbitmap', '')
;
OMAIL.WA.res_mime_create(20220,'image/x-xwindowdump', '')
;
OMAIL.WA.res_mime_create(20230,'image/cdr', 'Corel')
;
OMAIL.WA.res_mime_create(20240,'image/psd', 'Photoshop')
;
OMAIL.WA.res_mime_create(20250,'image/x-cmu-raster','')
;

-- application - ID 30xxx ------------------------------------------------------
OMAIL.WA.res_mime_create(30100,'application/octet-stream', '')
;
OMAIL.WA.res_mime_create(30110,'application/andrew-inset','')
;
OMAIL.WA.res_mime_create(30120,'application/mac-binhex40', '')
;
OMAIL.WA.res_mime_create(30130,'application/mac-compactpro', '')
;
OMAIL.WA.res_mime_create(30140,'application/msword', '')
;
OMAIL.WA.res_mime_create(30150,'application/octet-stream', '')
;
OMAIL.WA.res_mime_create(30160,'application/oda', '')
;
OMAIL.WA.res_mime_create(30170,'application/pdf', '')
;
OMAIL.WA.res_mime_create(30180,'application/postscript', '')
;
OMAIL.WA.res_mime_create(30190,'application/smil', '')
;
OMAIL.WA.res_mime_create(30200,'application/x-bcpio','')
;
OMAIL.WA.res_mime_create(30210,'application/x-cdlink','')
;
OMAIL.WA.res_mime_create(30220,'application/x-chess-pgn', '')
;
OMAIL.WA.res_mime_create(30230,'application/x-cpio','')
;
OMAIL.WA.res_mime_create(30240,'application/x-csh','')
;
OMAIL.WA.res_mime_create(30250,'application/x-director','')
;
OMAIL.WA.res_mime_create(30260,'application/x-dvi', '')
;
OMAIL.WA.res_mime_create(30270,'application/x-futuresplash','')
;
OMAIL.WA.res_mime_create(30280,'application/x-gtar','')
;
OMAIL.WA.res_mime_create(30290,'application/x-hdf','')
;
OMAIL.WA.res_mime_create(30300,'application/javascript', '')
;
OMAIL.WA.res_mime_create(30310,'application/x-koan', '')
;
OMAIL.WA.res_mime_create(30320,'application/x-latex', '')
;
OMAIL.WA.res_mime_create(30330,'application/x-netcdf', '')
;
OMAIL.WA.res_mime_create(30350,'application/x-rpm', '')
;
OMAIL.WA.res_mime_create(30360,'application/x-sh', '')
;
OMAIL.WA.res_mime_create(30370,'application/x-shar', '')
;
OMAIL.WA.res_mime_create(30380,'application/x-shockwave-flash', '')
;
OMAIL.WA.res_mime_create(30390,'application/x-stuffit', '')
;
OMAIL.WA.res_mime_create(30400,'application/x-sv4cpio', '')
;
OMAIL.WA.res_mime_create(30410,'application/x-sv4crc', '')
;
OMAIL.WA.res_mime_create(30420,'application/x-tar', '')
;
OMAIL.WA.res_mime_create(30430,'application/x-tcl', '')
;
OMAIL.WA.res_mime_create(30440,'application/x-tex', '')
;
OMAIL.WA.res_mime_create(30450,'application/x-texinfo', '')
;
OMAIL.WA.res_mime_create(30460,'application/x-troff', '')
;
OMAIL.WA.res_mime_create(30470,'application/x-troff-man', '')
;
OMAIL.WA.res_mime_create(30480,'application/x-troff-me', '')
;
OMAIL.WA.res_mime_create(30490,'application/x-troff-ms', '')
;
OMAIL.WA.res_mime_create(30500,'application/x-ustar', '')
;
OMAIL.WA.res_mime_create(30510,'application/x-wais-source', '')
;
OMAIL.WA.res_mime_create(30520,'application/zip', '')
;
OMAIL.WA.res_mime_create(30530,'application/x-rar-compressed', '')
;
OMAIL.WA.res_mime_create(30540,'application/x-zip-compressed', '')
;
OMAIL.WA.res_mime_create(30550,'application/x-gzip-compressed', '')
;
OMAIL.WA.res_mime_create(30560,'application/ics', '')
;

-- audio - ID 40xxx ------------------------------------------------------------
OMAIL.WA.res_mime_create(40100,'audio/basic', '')
;
OMAIL.WA.res_mime_create(40110,'audio/midi', '')
;
OMAIL.WA.res_mime_create(40120,'audio/mpeg', '')
;
OMAIL.WA.res_mime_create(40130,'audio/x-aiff', '')
;
OMAIL.WA.res_mime_create(40140,'audio/x-pn-realaudio', '')
;
OMAIL.WA.res_mime_create(40150,'audio/x-realaudio', '')
;
OMAIL.WA.res_mime_create(40160,'audio/x-wav', '')
;

-- video - ID 50xxx ------------------------------------------------------------
OMAIL.WA.res_mime_create(50100,'video/mpeg', '')
;
OMAIL.WA.res_mime_create(50110,'video/quicktime', '')
;
OMAIL.WA.res_mime_create(50120,'video/x-msvideo', '')
;
OMAIL.WA.res_mime_create(50130,'video/x-sgi-movie', '')
;


-- chemical 61xxx --------------------------------------------------------------
OMAIL.WA.res_mime_create(61100,'chemical/x-pdb', '')
;


-- x-conference 62xxx ----------------------------------------------------------
OMAIL.WA.res_mime_create(62100,'x-conference/x-cooltalk', '')
;

-- model 63xxx -----------------------------------------------------------------
OMAIL.WA.res_mime_create(63100,'model/iges', '')
;
OMAIL.WA.res_mime_create(63110,'model/mesh', '')
;
OMAIL.WA.res_mime_create(63120,'model/vrml', '')
;

--------------------------------------------------------------------------------

CALL OMAIL.WA.res_resource_temp()
;
DROP PROCEDURE OMAIL.WA.res_resource_temp
;


-- Create 'RESOURCES' temporary procedures
--
CREATE PROCEDURE OMAIL.WA.res_ext_temp()
{
  declare N integer;

  N := 1;
  for (select ID, T_EXT from WS.WS.SYS_DAV_RES_TYPES E, OMAIL.WA.RES_MIME_TYPES T where E.T_TYPE=T.MIME_TYPE option(loop)) do
  {
    INSERT REPLACING OMAIL.WA.RES_MIME_EXT(EXT_ID, MIME_ID, EXT_NAME) VALUES(N, ID, T_EXT);
    N := N + 1;
  };
  INSERT REPLACING OMAIL.WA.RES_MIME_EXT(EXT_ID, MIME_ID, EXT_NAME) VALUES(N, 20230, 'cdr');
  INSERT REPLACING OMAIL.WA.RES_MIME_EXT(EXT_ID, MIME_ID, EXT_NAME) VALUES(N+1, 20240, 'psd');
  INSERT REPLACING OMAIL.WA.RES_MIME_EXT(EXT_ID, MIME_ID, EXT_NAME) VALUES(N+2, 30100, 'win');
  INSERT REPLACING OMAIL.WA.RES_MIME_EXT(EXT_ID, MIME_ID, EXT_NAME) VALUES(N+3, 20150, 'jpg');
}
;

CALL OMAIL.WA.res_ext_temp()
;
DROP PROCEDURE OMAIL.WA.res_ext_temp
;
