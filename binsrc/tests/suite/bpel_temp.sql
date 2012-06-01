vhost_define (vhost=>'*ini*', lhost=>'*ini*', lpath=>'/SRC/', ppath=>'/', vsp_user=>'BPEL');
ECHO BOTH $IF $EQU $STATE 'OK' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": source vhost STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
