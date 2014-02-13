BEGIN {
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2014 OpenLink Software
#  
#  This project is free software; you can redistribute it and/or modify it
#  under the terms of the GNU General Public License as published by the
#  Free Software Foundation; only version 2 of the License, dated June 1991.
#  
#  This program is distributed in the hope that it will be useful, but
#  WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#  General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License along
#  with this program; if not, write to the Free Software Foundation, Inc.,
#  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
#  
#  
  FS="~";
#  c_incl="oper_pars.incl"
#  print > c_incl;
  sql_incl="oper_pars.sql"
  print > sql_incl;
  sql_init="pars_init.sql"
  print > sql_init;

  print "create procedure \"VAD\".\"DBA\".\"RETRIEVE_HTTP_PARS\" ( in afrom any )\n{" >sql_init;
  print "  declare ato any;" 			>>sql_init;
  print "  ato := vector();" 			>>sql_init;
}

{
  if (length($5)) valid_proc=$5;
  else valid_proc="NULL";
  if (length($6)) out_proc=$6;
  else out_proc="NULL";
  if (length($7)) flaf=$7;
  else flaf="0";
#  printf("{\"%s\", NULL, %s, NULL, NULL, %s, %s, NULL, NULL, NULL},\n",$1,flaf,valid_proc,out_proc) >> c_incl;
  print "insert replacing \"VAD\".\"DBA\".\"VAD_HELP\" (\"name\",\"dflt\",\"short_help\",\"full_help\") values (" >> sql_incl;
  printf("'%s','%s','%s','%s')\n;\n",$1,$2,$3,$4) >>sql_incl;

  
  print " \"PUMP\".\"DBA\".\"__RETRIEVE_HTTP_PARS\" (afrom,ato,\'"$1"\',\'"$2"\'); " >>sql_init;
}

END {

  print "  return ato;" >>sql_init;
  print "\n}\n;\n" >>sql_init;

}

