//  
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//  
//  Copyright (C) 1998-2012 OpenLink Software
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

namespace redcoalsms
{
	public class redcoalsmssvc
	{
		net.redcoal.xml.ISOAPServerservice server;
		string ClientSerialNo, SMSKey, strSenderName, strSenderEmail;
		bool canReply;
	
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
			server = new net.redcoal.xml.ISOAPServerservice ();
			this.canReply = false;
			this.ClientSerialNo = _ClientSerialNo;
			this.strSenderEmail = _SenderEmail;
			this.strSenderName = _SenderName;
			this.SMSKey = _SMSKey;
		}
		public string SendSms (string Recepient, string txtMsg)
		{
			String ms = "";
				int resp = server.SendTextSMS (
					ClientSerialNo, SMSKey, Recepient, 
					txtMsg, strSenderEmail, "", 0, ref ms);
				if (resp >= 0 && resp <= 17)
					return error_responces[resp];
				else
					return "Unknown status code " + resp;
		}
	}
}
