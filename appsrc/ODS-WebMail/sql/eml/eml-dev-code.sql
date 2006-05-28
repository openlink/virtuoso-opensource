create procedure OMAIL.WA.omail_dev_receive()
{
  declare I integer;
  I := 0;
  while (I < 100)
  {
    OMAIL.WA.omail_welcome_msg(1, 2,'dav@domain.com');
    i := i + 1;
  };
}
;
OMAIL.WA.omail_dev_receive();
