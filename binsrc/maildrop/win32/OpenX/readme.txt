
		  MAIL SINK INSTALLATION FOR OPENX ON WIN32


OpenLink MailDrop Sink installation
===============================================================================
- Run the maildrop10.exe installer
  and follow it's instructions.

- Add a SYSTEM dsn (not a normal / file dsn) with odbcad32.exe
  Use the name 'Virtuoso' as the DSN name.
  Set it up so it connects to the Virtuoso instance running OpenX.
  Test the connection.
  If you want to use a different dsn name, change odbc_mail.ini to
  reflect the change in dsn name.
  Also, if you change the port to anything else as 1111, edit the odbc_mail.ini


Additional notes for testing
===============================================================================
- Verify that the machine name is valid and that SMTP is listening with the cmd:
  	telnet your.domain.com 25
  You should get the '220 your.domain.com .....' back.
  Now, type QUIT [return]

  Do the same test for localhost connections, to verify that the SMTP
  server will forward mail - this is required to send mail with OpenX.
  	telnet localhost 25
	reply: '220 your.domain.com .....'
	you: EHLO localhost
	reply: '250 your.domain.com Hello .....'
	you: MAIL FROM: Administrator@localhost
	reply: '250 ..'
	you: RCPT TO: pnieuw@openlinksw.com
	reply: '250 ..'
	you: QUIT

  If this fails, correct your settings in the SMTP or Exchange configuration.
  The standard SMTP installation will not forward for localhost, so you
  may have to change this. When Exchange is installed, you are probably
  OK out of the box.
  Otherwise:
    run: Programs, Adm.Tools, Internet Services Manager
    on 'Default SMTP server' right-click Properties
    select 'Access' tab
    'Connection' button - verify allowed hosts for connection here
    'Relay' button - verify allowed hosts for relaying here

- To verify the registered sink's parameters, run:
	cscript smtpreg.vbs /enum
  You should see the maildrop.dll registration

- You can verify the odbc_mail.ini setup by running
	odbc_mail +debug +local your_openx_account
	NOTE: do NOT include @domain here.
  If it connects, it'll tell you and you can type in a standard mime
  message (or hit ^C)

- That's it. try sending mails now to your_openx_account@your.domain.com
  If you cannot get it to work after performing the above tests, please let
  me know. I have a debugging version of the maildrop.dll around.


Features, Limitations & Bugs
===============================================================================
- The MailDrop Sink (maildrop.dll) invokes the odbc_mail.exe and feeds it
  the mail through a pipe, much like sendmail does with procmail.
  This means that odbc_mail.exe will be run as SYSTEM, which is a security
  risk. A future version will combine maildrop.dll with odbc_mail.exe.
  If you're using NTFS, you should probably adjust the directory permissions.

- Because there is no way to indicate temporary failures, mail will be
  bounced immediately if Virtuoso is down for a moment. If anybody has
  a clue, please help.

- Fallback delivery has been implemented and is functional, although
  not used at the moment. Contact me if you want to use my procmail.exe :-)

- Everything should work without Exchange installed as well.

- If the mail is received with multiple RCPT TO entries, the maildrop.dll
  will remove those recipients from the recipients list for which a
  successful delivery to the database was made.
  If all recipients are removed this way, the mail is prevented from being
  handled by next sinks in the chain.
