#!/bin/sh

echo "select 'WV.WIKI.SILENT_EXEC(''' || 'drop procedure ' || p_name || ''');' from sys_procedures where p_name like 'WV.%.%' and p_name not like 'WV.%.SILENT_EXEC'; " | isql $PORT dba dba | grep drop  > drop_proc.sql
echo "drop procedure WV.WIKI.SILENT_EXEC;" >>  drop_proc.sql
