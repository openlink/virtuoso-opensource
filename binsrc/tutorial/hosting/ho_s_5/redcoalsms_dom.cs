//  
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//  
//  Copyright (C) 1998-2016 OpenLink Software
//  
//  This project is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the
//  Free Software Foundation; only version 2 of the License, dated June 1991.
//  
//  This program is distributed in the hope that it will be useful, but
//  WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
//  General Public License for more details.
//  
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
//  
//  
using System;
using System.Xml;
using System.Net;
using System.Net.Sockets;
using System.IO;
using System.Text;

namespace redcoalsms_dom
{
  public class redcoalsmssvc
    {
      string ClientSerialNo, SMSKey, strSenderName, strSenderEmail;
      int canReply;

      static string [] error_responces = 
	{
	  "No Error",
	  "Feature Not Available", 
	  "Service Not Available",
	  "Too Many Wrong Passwords , Please contact support@redcoal.com",
	  "Invalid password",
	  "No Credits Left/ go to: http://www.redcoal.net/purchase.asp",
	  "Not Enough Credits Left",
	  "Binary File Not Found",
	  "One or more invalid destinations",
	  "Invalid Format (for binary and fax data)",
	  "Invalid Serial No",
	  "Invalid HTTP property",
	  "Daily Quota Reached",
	  "Destination not in restricted list",
	  "Invalid File",
	  "File too big",
	  "General Fault: E.g: no internet connection, can't connect to Redcoal XML server, can't get past the proxy firewall.",
	  "Can not read the specified file or don't have permission to read the file"
	};
      public redcoalsmssvc (string _ClientSerialNo, string _SMSKey, string _SenderName, string _SenderEmail)
	{
	  this.canReply = 0;
	  this.ClientSerialNo = _ClientSerialNo;
	  this.strSenderEmail = _SenderEmail;
	  this.strSenderName = _SenderName;
	  this.SMSKey = _SMSKey;
	}

      private static string RC_req_fmt = 
	  " <SOAP-ENV:Envelope " +
	  "   xmlns:SOAP-ENV='http://schemas.xmlsoap.org/soap/envelope/' " +
	  "   xmlns:SOAP-ENC='http://schemas.xmlsoap.org/soap/encoding/' " +
	  "   xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' " +
	  "   xmlns:xsd='http://www.w3.org/2001/XMLSchema' " +
	  "   SOAP-ENV:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/'>" +
	  "     <SOAP-ENV:Body>" +
	  "         <m:SendTextSMS " +
	  "           xmlns:m='urn:SOAPServerImpl-ISOAPServer'>" +
	  "             <strInSerialNo xsi:type='xsd:string'>{0}</strInSerialNo>" +
	  "             <strInSMSKey xsi:type='xsd:string'>{1}</strInSMSKey>" +
	  "             <strInRecipients xsi:type='xsd:string'>{2}</strInRecipients>" +
	  "             <strInReplyEmail xsi:type='xsd:string'>{3}</strInReplyEmail>" +
	  "             <strInOriginator xsi:type='xsd:string'>{4}</strInOriginator>" +
	  "             <strInMessageText xsi:type='xsd:string'>{5}</strInMessageText>" +
	  "             <iInType xsi:type='xsd:int'>{6}</iInType>" +
	  "		<strOutMessageIDs type='xsd:string'/>" +
	  "         </m:SendTextSMS>" +
	  "     </SOAP-ENV:Body>" +
	  " </SOAP-ENV:Envelope>";
      private static string req_uri = "http://xml.redcoal.com/soapserver.dll/soap/ISoapServer";
      private static string SoapAction = "\"urn:SOAPServerImpl-ISOAPServer#SendTextSMS\"";
      private static string SoapResp_uri = "urn:SOAPServerImpl-ISOAPServer";
      private static string SoapResp_name = "SendTextSMSResponse";
      private static string SoapResp_val = "return";

      private int SendTextSMS (string ClientSerialNo,
	  string SMSKey, 
	  string Recepient,
	  string strSenderEmail, 
	  string strSenderName,
	  string txtMsg,
	  int canReply)
	{
	  Object[] obj_params = { ClientSerialNo, SMSKey, Recepient, strSenderEmail, strSenderName, txtMsg, canReply };
	  WebHeaderCollection req_headers = new WebHeaderCollection();
	  string req_text = String.Format (RC_req_fmt, obj_params);
	  byte [] req_bytes = new UTF8Encoding().GetBytes (req_text);

	  req_text = null;
	  Uri _req_uri = new Uri (req_uri);
	  HttpWebRequest web_req = (HttpWebRequest) WebRequest.Create (_req_uri);
	  req_headers.Add ("SOAPAction", SoapAction);
	  web_req.Headers =  req_headers;
	  web_req.ContentType = "text/xml";
	  web_req.KeepAlive = false;
	  web_req.UserAgent = "Virtuoso SOAP sample";
	  web_req.Method = "POST";
	  web_req.ContentLength = req_bytes.Length;

	  Stream req_str = web_req.GetRequestStream ();
	  req_str.Write (req_bytes, 0, req_bytes.Length);
	  req_str.Flush();
	  req_bytes = null;

	  HttpWebResponse resp = (HttpWebResponse) web_req.GetResponse ();
	  Encoding enc = new UTF8Encoding ();

	  XmlDocument doc = new XmlDocument ();

	  long clen = resp.ContentLength;
	  Stream resp_stream = resp.GetResponseStream();
	  String content;
	  if (clen != -1)
	    {
	      byte [] bytes = new byte[clen];
	      long read = 0;
	      while (read < clen)
		{
		  read += resp_stream.Read (bytes, (int) read, (int) (clen - read));
		}
	      UTF8Encoding enc1 = new UTF8Encoding  (false, true);
	      content = new String (enc1.GetChars (bytes));
	    }
	  else if (typeof (NetworkStream).IsInstanceOfType (resp_stream))
	    {
	      NetworkStream nstr = resp_stream as NetworkStream;
	      byte [] bytes = new byte[10000];
	      long read = 0;
	      while (nstr.DataAvailable)
		{
		  read += nstr.Read (bytes, (int) read,  (int) (bytes.Length - read));
		}
	      UTF8Encoding enc1 = new UTF8Encoding  (false, true);
	      content = new String (enc1.GetChars (bytes, 0, (int) read));
	    }
	  else 
	    {
	      resp_stream.Close();
	      req_str.Close();
	      throw new Exception ("don't know how to read the stream");
	    }
	  resp_stream.Close();
	  req_str.Close();
	  doc.LoadXml (content);

	  XmlNode xml_env = doc.DocumentElement;
	  XmlNode xml_body = xml_env["Body", xml_env.NamespaceURI];
	  XmlNode xml_fault = xml_body["Fault", xml_env.NamespaceURI];
	  if (xml_fault != null)
	      throw new Exception (xml_fault.InnerText);

	  XmlNode xml_resp = xml_body[SoapResp_name, SoapResp_uri];
	  XmlNode result = xml_resp[SoapResp_val];
	  return Int32.Parse (result.InnerXml);
	}


      public string SendSms (string Recepient, string txtMsg)
	{
	  int resp = SendTextSMS (
	      ClientSerialNo, SMSKey, Recepient, 
	      strSenderEmail, "", txtMsg, canReply);
	  if (resp >= 0 && resp <= 17)
	    return error_responces[resp];
	  else
	    return "Unknown status code " + resp;
	}
    }
}
