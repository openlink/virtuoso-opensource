#
# sql_to_c.awk
#
# $Id$
#
#  Embeds SQL code into a C file
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2017 OpenLink Software
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

function strip_comments(text, pl_stats, arr)
{
  #print "***IN_STRIP***" text "***"
  output = ""
  inx = 1
  first_line = -1
  nlines = split (text, lines, "\n")
  while (inx <= nlines)
   {
     curline = lines[inx]
     res_line = ""
     had_comment = 0
     #print "***LINE " inx "***" curline "***"
     comm_start = index (curline, "--")
     #print "***COM_START=" comm_start "***"
     special_comment = index (curline, "--!AWK")
     special_comment2 = index (curline, "--!AFTER")
     if_comment = index (curline, "--#IF VER=")
     endif_comment = index (curline, "--#ENDIF")
     if (in_if && endif_comment > 0)
       {
	 in_if = 0
       }	

     if (if_comment > 0)
       {
	 match (curline, /[0-9]+/, arr)
	 ver = arr[0] + 0
	 if (ver == srv_ver)
	   {
	      inx = inx + 1
	      continue
	   }
	 else
	   in_if = 1
       }	

     if (in_if)
       {
	 inx = inx + 1
	 continue
       }
     else if (special_comment > 0)
       {
	 res_line = substr (curline, special_comment + 3) "@"
       }
     else if (special_comment2 > 0)
       {
	 res_line = substr (curline, special_comment2 + 3) "@"
	 print AFTER
       }
     else
       {
	 while (comm_start > 0)
	   {
	     before_comment = substr (curline, 1, comm_start - 1)
	     #print "***BEFORE_COMMENT=" before_comment "***"

	     after_comment = substr (curline, comm_start + 2)
	     # print "***AFTER_COMMENT=" after_comment "***"

	     n_sk = split (before_comment, dummy, "'") - 1
	     # print "***N_SK=" n_sk "***"

	     res_line = res_line before_comment
	     if (n_sk % 2 > 0)
	       { # have open single quotes
		 res_line = res_line "--"
		 curline = after_comment
	       }
	     else
	       {
		 # This was = 1, but for PL stats we need lines to be preserved
		 if (pl_stats == "PLDBG")
		   had_comment = 0
		 else
		   had_comment = 1
		 curline = ""
	       }
	     comm_start = index (curline, "--")
	   }
	 gsub (/[\t\n\r\ ]+$/, "", res_line)
	 if (inx < nlines)
	   res_line = res_line curline "\n"
	 else
	   res_line = res_line curline
       }

     if (first_line == -1 && length (res_line) > 2 && special_comment == 0 && special_comment2 == 0)
       {
         first_line = inx - 1
       }
     if (match (res_line, /[^\t\n\r\ ]/) > 0 || had_comment == 0)
       {
         output = output res_line
       }
     else
       while (inx < nlines && length (lines[inx + 1]) == 0)
	 {
           inx = inx + 1
	 }
     inx = inx + 1
   }
  #print "***END_STRIP***" text "***"
  arr[0] = output
  arr[1] = first_line
#return (arr)
}


function get_awk_macro_defines (awk_command)
{
  np = split (awk_command, p, "[ \t\n]+")
  if (toupper (p[1]) != "AWK")
    return ("")

  if (np > 1)
    p[2] = toupper (p[2])
  text = "/* AWK macro " awk_command "*/"
  if (np > 4 && p[2] == "UPGRADE" && toupper (p[3]) == "TABLE")
    {
      tb_name = p[4]
      col_name = p[5]

      text = "\n  macro_tb = sch_name_to_table (isp_schema(NULL), \"" tb_name "\");"
      text = text "\n  if (macro_tb && !tb_name_to_column (macro_tb, \"" col_name "\"))  "
      text = text "\n    ddl_ensure_table (\"drop dead\", \"drop table " tb_name "\");  "
      n_upgraded_tables = n_upgraded_tables + 1
    }
  if (np > 1 && p[2] == "PUBLIC")
    {
      text = " "
      define_proc_macro = "DEFINE_PUBLIC_PROC"
    }
  else if (np > 1 && p[2] == "OVERWRITE")
    {
      text = " "
      define_proc_macro = "DEFINE_OVERWRITE_PROC"
    }
  else if (np > 1 && p[2] == "STORED")
    {
      text = " "
      define_proc_macro = "DEFINE_STORED_PROC"
      stored_proc = 1
      if (np > 2 && p[3] == "AFTER")
        {
          _defines = defines_arfw
          after_rfw = 1
	}
    }
  else if (np > 2 && p[2] == "PLBIF")
    {
      bif_text = bif_text "\n  pl_bif_name_define (\"" p[3] "\");"
      define_proc_macro = "DEFINE_PUBLIC_PROC"
    }


  return (text)
}

BEGIN   {
          while (getline < "sqlver.h" > 0)
	  {
	     if(match ($0, /^#define DBMS_SRV_VER_ONLY/))
	       {	
	         res = match ($0, /[0-9]+/, arr)
		 srv_ver = arr[0] + 0
                 break	
	       }
	  }
	  close ("sqlver.h")
	  defines = ""
	  defines_arfw = ""
	  nproc = 0
	  ntable = 0
	  nview = 0
	  nindexes = 0
	  ntriggers = 0
	  nother = 0
	  nalter = 0
	  nudt = 0
	  nalterudt = 0
	  stored_proc = 0
	  bif_text = ""
	  RS = "\n;\n"
	  print "/* This file is automatically generated by sql_to_c.awk */\n"
	  print "#include \"sqlnode.h\"\n#include \"sqlfn.h\"\n#include \"sqltype.h\"\n"
	  filename = FILENAME
	  nfiles = 1
	  end_name = ""
	  qualifier = "DB"
	  n_upgraded_tables = 0
	  n_upgraded_tables_arfw = 0
	  define_proc_macro = "DEFINE_PROC"
	  has_qualifier = 0
	  has_qualifier_arfw = 0
	  cur_line_no = 1
	  in_xsl_mode = 0
	  first_xsl_rec = 1
	  in_xsd_mode = 0
	  first_xsd_rec = 1
	  n_xslts = 0
	  n_xsds = 0
	  in_if = 0
	}

	{
	        if (filename != FILENAME)
		  {
#		    print "/*  processing file " FILENAME " */"
		    if (in_xsl_mode > 0)
		      {
			#print "\"'))\";\n"
			print ",\n NULL };\n"
			in_xsl_mode = 0
		      }
		    if (in_xsd_mode > 0)
		      {
			#print "\"')\";\n"
			print ",\n NULL };\n"
			in_xsd_mode = 0
		      }
		    cur_line_no = 1
		    n = split (FILENAME, path_parts_array, "/")
		    print "/* " path_parts_array[n] " */\n"
		    end_name = path_parts_array[n]
		    if (filename != "")
		      {
			n = split (filename, path_parts_array, "/")
			if (length (defines) > 0)
			  {
			    if (qualifier != "DB")
			      {
				has_qualifier = 1
				files[nfiles] = \
				  "  /* " path_parts_array[n] " */\n" \
				  "  bootstrap_cli->cli_qualifier = box_string (\"" qualifier "\");\n" \
				  defines "\n\n" \
				  "  dk_free_box (bootstrap_cli->cli_qualifier);\n" \
				  "  bootstrap_cli->cli_qualifier =  saved_qualifier;"
			      }
			    else
				files[nfiles] = "  /* " path_parts_array[n] " */\n" defines
			  }
		        if (length (defines_arfw) > 0)
			  {
			    if (qualifier != "DB")
			      {
				has_qualifier_arfw = 1
				files_arfw[nfiles] = \
				  "  /* " path_parts_array[n] " */\n" \
				  "  bootstrap_cli->cli_qualifier = box_string (\"" qualifier "\");\n" \
				  defines_arfw "\n\n" \
				  "  dk_free_box (bootstrap_cli->cli_qualifier);\n" \
				  "  bootstrap_cli->cli_qualifier =  saved_qualifier;"
			      }
			    else
				files_arfw[nfiles] = "  /* " path_parts_array[n] " */\n" defines_arfw
			  }

			defines = ""
			defines_arfw = ""
			qualifier = "DB"
			nfiles = nfiles + 1
		      }
		    if (0 < match (FILENAME, /.*\.xsl/))
		      {
		        n2 = split (FILENAME, path_parts_array2, "/")
			stylesheet_name = substr (path_parts_array2[n2], 0, index (path_parts_array2[n2], ".") - 1)
#			stylesheet_name = path_parts_array2[n]
#			print "static const char *xsl" nfiles "= \"xslt_sheet ('__" stylesheet_name "', xml_tree_doc ('\""
			print "static const char *xsl" nfiles "[]= {"
			in_xsl_mode = 1
			first_xsl_rec = 1
			n_xslts = n_xslts + 1
#			defines = \
#			  defines "\n ddl_ensure_table (\"do this always\", xsl" nfiles ");"
			defines = \
			  defines "\n  XSLT_DEFINE (\"http://local.virt/" stylesheet_name  "\", xsl" nfiles ");"
		      }
		    if (0 < match (FILENAME, /.*\.xsd/))
		      {
		        n2 = split (FILENAME, path_parts_array2, "/")
			schema_name = substr (path_parts_array2[n], 0, index (path_parts_array2[n], ".") - 1)
#			schema_name = path_parts_array2[n]
#			print "static const char *xsd" nfiles "= \"xml_reload_schema_decl ('http://local.virt/" schema_name ".xsd', 'http://local.virt/" schema_name ".xsd', 'UTF-8', 'x-any', '\""
			print "static const char *xsd" nfiles "[]= {"
			in_xsd_mode = 1
			first_xsd_rec = 1
			n_xsds = n_xsds + 1
#			defines = \
#			  defines "\n ddl_ensure_table (\"do this always\", xsd" nfiles ");"
			defines = \
			  defines "\n  XSD_DEFINE (\"http://local.virt/" schema_name  ".xsd\", xsd" nfiles ");"
		      }
		    filename = FILENAME
		  }
		last_line_no = cur_line_no
		cur_line_no = cur_line_no + split ($0, tmp_lines, "\n") + 1

                #print "/*\n" $0 "\n*/\n"

                # trims the comments
                #gsub (/--[^\n]*[\n]+/, "")
		if (in_xsl_mode == 0 && in_xsd_mode == 0)
		  {
		    strip_comments($0, pl_stats, arr)
		    $0 = arr[0]
		    line_begin_no = (arr[1] + last_line_no - 1)

		    # trims the leading space
		    sub (/^[\t\n\r\ ]+/, "")
		    if (length() < 2)
		      next
		  }

                # does escape the symbols
		fun = $0
		gsub ("\\\\", "&&", fun)

		# remove whitespace except when there is just a semicolon
		if ((in_xsl_mode == 0) && (in_xsd_mode == 0))
  		  {
		    gsub (/\n[\t\ ]+/, "\n", fun)
		    gsub (/\n;\n/, "\n ;\n", fun)
		  }
		if ((in_xsl_mode == 0) && (in_xsd_mode == 0))
	          gsub ( /'/, "\\'", fun)
		#else
                  #gsub ( /'/, "''", fun)

	        gsub ( /"/, "\\\"", fun)
		if ((in_xsl_mode == 0) && (in_xsd_mode == 0))
	          gsub ( /[^\n]*/, "\"&\\n\"", fun)
		else
	          gsub ( /[^\n]*/, "\"&\\n\"", fun)

		if (in_xsl_mode == 1)
		  {
	            if (first_xsl_rec == 0)
		      print "\";\\n\", "
                    else
  		      first_xsl_rec = 0
		    print fun
		    next
		  }
		if (in_xsd_mode == 1)
		  {
	            if (first_xsd_rec == 0)
		      print "\";\\n\", "
                    else
  		      first_xsd_rec = 0
		    print fun
		    next
		  }
		_pre_code = ""
		_defines = defines
		after_rfw = 0
		after_and_before_rfw = 0
		npieces = split ($0, pieces, "[ \t\n(]+")

		if (index ($0, "@") > 0)
		  {
		    sp_comment_start = index ($0, "@")
	            sp_comment = substr ($0, 0, sp_comment_start - 1)
		    n_deps = split (sp_comment, _deps, "[ \t\n]+")
		  }
                else
                  n_deps = 0

		if (npieces)
		  pieces[1] = toupper (pieces[1])
		if (npieces > 1 && pieces[1] == "USE")
		  {
		    qualifier = pieces[2]
	            next
		  }
		else if (npieces > 2 && substr (pieces[1], 1, 3) == "AWK" && index ($0, "@") > 0)
		  {
		    null_at_inx = index ($0, "@")
		    fun_at_inx = index (fun, "@")
		    macro_command = substr ($0, 0, null_at_inx - 1)
		    $0 = substr ($0, null_at_inx + 1, length ($0))
		    fun = "\" " substr (fun, fun_at_inx + 1, length (fun))
		    npieces = split ($0, pieces, "[ \t\n]+")
		    if (npieces)
		      pieces[1] = toupper (pieces[1])

	            new_define = get_awk_macro_defines(macro_command)
		    if (length (new_define) > 0)
		      _defines = _defines new_define
		    else
	              next
		  }
		else if (substr (pieces[1], 1, 16) == "AFTER_AND_BEFORE" && index ($0, "@") > 0)
		  {
		    if (npieces > 2)
		      {
			dep_tb = pieces[2]
		        dep_col = pieces[3]
			_text = "\n  macro_tb = sch_name_to_table (isp_schema(NULL), \"" dep_tb "\");"
			_text = _text "\n  if (macro_tb && tb_name_to_column (macro_tb, \"" dep_col "\"))  "
			n_upgraded_tables = n_upgraded_tables + 1
			_pre_code = _text
		      }
		    null_at_inx = index ($0, "@")
		    fun_at_inx = index (fun, "@")
		    macro_command = substr ($0, 0, null_at_inx - 1)
		    $0 = substr ($0, null_at_inx + 1, length ($0))
		    fun = "\" " substr (fun, fun_at_inx + 1, length (fun))
		    npieces = split ($0, pieces, "[ \t\n]+")
		    if (npieces)
		      pieces[1] = toupper (pieces[1])
	            _defines = defines_arfw
		    after_and_before_rfw = 1
		  }
		else if (substr (pieces[1], 1, 5) == "AFTER" && index ($0, "@") > 0)
		  {
		    if (n_deps > 2)
		      {
			dep_tb = _deps[2]
		        dep_col = _deps[3]
			if (dep_tb == "__PROCEDURE__")
			  {
			    _text = "\n if (sch_proc_def_exists (bootstrap_cli, \"" dep_col "\", 0))"
			  }
			else
			  {
			    _text = "\n  macro_tb = sch_name_to_table (isp_schema (db_main_tree->it_commit_space), \"" dep_tb "\");"
		 	    _text = _text "\n  if (macro_tb && tb_name_to_column (macro_tb, \"" dep_col "\"))  "
			  }
			_pre_code = _text
		      }
		    null_at_inx = index ($0, "@")
		    fun_at_inx = index (fun, "@")
		    macro_command = substr ($0, 0, null_at_inx - 1)
		    $0 = substr ($0, null_at_inx + 1, length ($0))
		    fun = "\" " substr (fun, fun_at_inx + 1, length (fun))
		    npieces = split ($0, pieces, "[ \t\n]+")
		    if (npieces)
		      pieces[1] = toupper (pieces[1])
	            _defines = defines_arfw
		    after_rfw = 1
		  }
                # adds the definition in the appropriate branch
		_defines1 = ""
		if (npieces > 2 && pieces[1] == "CREATE")
		  {
		    is_escaped = 0
		    pieces[2] = toupper (pieces[2])
	            three_part = toupper (pieces[3])
		    if (index (pieces[3], "\"") > 0)
		      is_escaped = 1
		    gsub (/\"/, "", pieces[3])
		    if ((pieces[2] == "PROCEDURE" || pieces[2] == "FUNCTION") &&  three_part != "VIEW" )
		      {
			_defines1 = "\n  " define_proc_macro " (\"" pieces[3] "\", proc" nproc ");"
			print "static const char *proc" nproc " = \n\"#line " line_begin_no+1 " \\\"[executable]/" end_name "\\\"\\n\"\n" fun
                        # Here is a debug comment code
			if (pl_stats == "PLDBG")
			  print "\"--src " end_name ":" line_begin_no-1 "\\n\";\n"
			else
			  print ";\n"
			nproc = nproc + 1
		      }
	            else if (pieces[2] == "TYPE")
		      {
			if (is_escaped == 0 && toupper (pieces[3]) != pieces[3])
 			  _defines1 = "\n  DEFINE_UDT (case_mode == CM_UPPER ? \"" toupper (pieces[3]) "\" : \"" pieces[3] "\", udt" nudt ");"
			else
 			  _defines1 = "\n  DEFINE_UDT (\"" pieces[3] "\", udt" nudt ");"
		        print "static const char *udt" nudt " = \n" fun ";\n"
	                nudt = nudt + 1
		      }
		    else if (pieces[2] == "TRIGGER")
		      {
			_defines1 = "\n  ddl_std_proc (trig" ntriggers ", 0x0);"
			print "static const char *trig" ntriggers " = \n\"#line " line_begin_no+1 " \\\"[executable]/" end_name "\\\"\\n\"\n" fun
			if (pl_stats == "PLDBG")
			  print "\"--src " end_name ":" line_begin_no-1 "\\n\";\n"
			else
			  print ";\n"
			ntriggers = ntriggers + 1
		      }
		    else if (pieces[2] == "INDEX")
		      {
		        _defines1 = "\n  ddl_ensure_table (\"do this always\", inx" nindexes ");"
		        print "static const char *inx" nindexes " = \n" fun ";\n"
			nindexes = nindexes + 1
		      }
		    else if (pieces[2] == "TABLE")
		      {
			tablename = pieces[3]
		        if (index (tablename, ".") == 0)
		          tablename = "DB.DBA." tablename
		        _defines1 = "\n  ddl_ensure_table (\"" tablename "\", tbl" ntable ");"
		        print "static const char *tbl" ntable " = \n" fun ";\n"
		        ntable = ntable + 1
		      }
		    else if (pieces[2] == "VIEW" || (pieces[2] == "PROCEDURE" && three_part == "VIEW"))
		      {
			if (three_part == "VIEW")
			  tablename = toupper(pieces[4])
			else
			  tablename = pieces[3]
		        if (index (tablename, ".") == 0)
		          tablename = "DB.DBA." tablename
		        _defines1 = "\n  ddl_ensure_table (\"" tablename "\", view" nview ");"
		        print "static const char *view" nview " = \n" fun ";\n"
		        nview = nview + 1
		      }
		    else
		      {
		        _defines1 = "\n  ddl_ensure_table (\"do this always\", other" nother ");"
		        print "static const char *other" nother " = \n" fun ";\n"
		        nother = nother + 1
		      }
		  }
		else if (npieces > 5 && pieces[1] == "ALTER" && toupper (pieces[2]) == "TABLE" && toupper (pieces[4]) != "MODIFY")
		  {
		    is_drop = 0
	            if (toupper (pieces[4]) == "DROP")
		      is_drop = 1
		    _defines1 = "\n  ddl_ensure_column (\"" pieces[3] "\", \"" pieces[5] "\", alter" nalter ", " is_drop ");"
		    print "static const char *alter" nalter " = \n" fun ";\n"
		    nalter = nalter + 1
		  }
		else if (npieces > 5 && pieces[1] == "ALTER" && toupper (pieces[2]) == "TYPE" && toupper (pieces[4]) == "ADD" && toupper (pieces[5]) == "ATTRIBUTE")
		  {
		    udt_name = pieces[3]
                    gsub (/\"/, "", udt_name)
		    _defines1 = "\n  udt_ensure_attribute (\"" udt_name "\", \"" pieces[6] "\", alter" nalter ");"
		    print "static const char *alter" nalter " = \n" fun ";\n"
		    nalter = nalter + 1
		    nalterudt = nalterudt + 1
		  }
		else
		  {
		    _defines1 = "\n  ddl_ensure_table (\"do this always\", other" nother ");"
		    print "static const char *other" nother " = \n" fun ";"
		    nother = nother + 1
		  }
		if (after_rfw)
		  defines_arfw = _defines _pre_code _defines1
		else if (after_and_before_rfw)
		  {
		    defines = defines _pre_code _defines1
		    defines_arfw = defines_arfw _defines1
		  }
		else
		  defines = _defines _defines1

	    define_proc_macro = "DEFINE_PROC"
	}

END 	{
	    if (in_xsl_mode)
	      {
		#print "\"'))\";\n"
		print ",\n NULL };\n"
		in_xsl_mode = 0

	      }
	    if (pass_bootstrap_cli != 0)
	      {
	       print "#undef isp_schema\n#define isp_schema(x) isp_schema_1(x)\n"
	      }
	    if (n_xslts > 0)
	      {
		print "static const char * xslt_define = \"xslt_sheet (?, xtree_doc (?, 128, ?, 'LATIN-1', 'x-any', 'BuildStandalone=ENABLE'))\";"
		print "static query_t *xslt_define_qr;"
		print ""


		print "#define XSLT_DEFINE(name, text1) \\"
		print "  { \\"
		print "    caddr_t text = NULL;\\"
		print "    static const char *elm;\\"
		print "    int inx, len = 0;\\"
		print "    for (inx = 0; ; inx++) { \\"
		print "        elm = text1[inx];\\"
		print "        if (!elm) break;\\"
		print "        len += (int) strlen (elm);\\"
		print "      }\\"
		print "    text = dk_alloc_box (len + 1, DV_STRING);\\"
		print "    text[0] = 0;\\"
		print "    for (inx = 0; ; inx++) { \\"
		print "        elm = text1[inx];\\"
		print "        if (!elm) break;\\"
		print "        strcat_box_ck (text, elm);\\"
		print "      }\\"
		print "    \\"
		print "    if (!xslt_define_qr) \\"
		print "      xslt_define_qr = sql_compile (xslt_define, bootstrap_cli, NULL, SQLC_DEFAULT); \\"
		print "    if (xslt_define_qr) \\"
		print "      { \\"
		print "        caddr_t err = NULL; \\"
		print "        err = qr_quick_exec (xslt_define_qr, bootstrap_cli, NULL, NULL, 3, \\"
		print "               \":0\", name, QRP_STR, \":1\", text, QRP_STR, \":2\", name, QRP_STR); \\"
		print "        if (err) { \\"
		print "          log_error (\"Error executing a server init statement : %s: %s -- %.50s\", \\"
		print "          ((caddr_t *) err)[QC_ERRNO], ((caddr_t *) err)[QC_ERROR_STRING], \\"
		print "                      text); \\"
		print "          dk_free_tree (err); \\"
		print "	    } \\"
		print "	  local_commit (bootstrap_cli); \\"
		print "      } \\"
		print "    dk_free_box (text);\\"
		print "  }"
		print ""
	    }

	    if (in_xsd_mode)
	      {
		#print "\"')\";\n"
		print ",\n NULL };\n"
		in_xsd_mode = 0

	      }
	    if (n_xsds > 0)
	      {
		print "static const char * xsd_define = \"xml_reload_schema_decl (?, ?, 'UTF-8', 'x-any', ?)\";"
		print "static query_t *xsd_define_qr;"
		print ""


		print "#define XSD_DEFINE(name, text1) \\"
		print "  { \\"
		print "    caddr_t text = NULL;\\"
		print "    static const char *elm;\\"
		print "    int inx, len = 0;\\"
		print "    for (inx = 0; ; inx++) { \\"
		print "        elm = text1[inx];\\"
		print "        if (!elm) break;\\"
		print "        len += strlen (elm);\\"
		print "      }\\"
		print "    text = dk_alloc_box (len + 1, DV_STRING);\\"
		print "    text[0] = 0;\\"
		print "    for (inx = 0; ; inx++) { \\"
		print "        elm = text1[inx];\\"
		print "        if (!elm) break;\\"
		print "        strcat_box_ck (text, elm);\\"
		print "      }\\"
		print "    \\"
		print "    if (!xsd_define_qr) \\"
		print "      xsd_define_qr = sql_compile (xsd_define, bootstrap_cli, NULL, SQLC_DEFAULT); \\"
		print "    if (xsd_define_qr) \\"
		print "      { \\"
		print "        caddr_t err = NULL; \\"
		print "        err = qr_quick_exec (xsd_define_qr, bootstrap_cli, NULL, NULL, 3, \\"
		print "               \":0\", name, QRP_STR, \":1\", name, QRP_STR, \":2\", text, QRP_STR); \\"
		print "        if (err) { \\"
		print "          log_error (\"Error executing a server init statement : %s: %s -- %.50s\", \\"
		print "          ((caddr_t *) err)[QC_ERRNO], ((caddr_t *) err)[QC_ERROR_STRING], \\"
		print "                      text); \\"
		print "          dk_free_tree (err); \\"
		print "	    } \\"
		print "	  local_commit (bootstrap_cli); \\"
		print "      } \\"
		print "    dk_free_box (text);\\"
		print "  }"
		print ""
	    }

           print "static int\nsch_proc_def_exists (client_connection_t *cli, const char *proc_name, const int report)\n{"
	   print "  query_t *proc = NULL;"
	   print "  char *full_name = sch_full_proc_name (isp_schema(NULL), proc_name,"
	   print "	cli->cli_qualifier, CLI_OWNER (cli));"
	   print "  if (full_name)"
	   print "    proc = sch_proc_def (isp_schema(NULL), full_name);"
	   print "  if (report && proc != NULL)"
	   print "     log_debug (\"built-in procedure \\\"%s\\\" overruled by the RDBMS\", proc_name);"
	   print "  return (proc != NULL);"
	   print "}\n"

	   print "#define DEFINE_PROC(name, proc) \\"
	   print "   if (!sch_proc_def_exists (bootstrap_cli, (name), log_proc_overwrite)) \\"
	   print "     ddl_std_proc_1 (proc, 0x0, 1)\n\n"

	   print "#define DEFINE_PUBLIC_PROC(name, proc) \\"
	   print "   if (!sch_proc_def_exists (bootstrap_cli, (name), log_proc_overwrite)) \\"
	   print "     ddl_std_proc_1 (proc, 0x1, 1)\n\n"

	   print "#define DEFINE_OVERWRITE_PROC(name, proc) \\"
	   print "   ddl_std_proc_1 (proc, 0x1, 1)\n\n"
	   if (stored_proc > 0)
	   {
	   print "#define DEFINE_STORED_PROC(name, proc) \\"
	   print "   if (!sch_proc_def_exists (bootstrap_cli, (name), log_proc_overwrite)) \\"
           print "     ddl_ensure_table (\"do this always\", proc);\n\n"
	   }
           if (nudt > 0)
	   {
	   print "static int\nsch_udt_def_exists (client_connection_t *cli, const char *udt_name)\n{"
	   print "  sql_class_t *udt = sch_name_to_type (isp_schema (NULL), udt_name);"
	   print "  if (udt &&  UDT_IS_INSTANTIABLE(udt))"
	   print "    {"
	   #print "      log_error (\"Built-in User Defined Type already exists: %s\\n\", udt_name);"
	   print "      return 1;"
	   print "    }"
	   print "  return 0;"
	   print "}\n"

           print "#define DEFINE_UDT(name, udt) \\"
           print "   if (!sch_udt_def_exists (bootstrap_cli, (name))) \\"
           print "     ddl_ensure_table (\"do this always\", udt);\n\n"
	   }
	   if (nalterudt > 0)
           {
	     print "static void"
	     print "udt_ensure_attribute (const char * udt_name, const char * attr, const char * text)"
	     print "{"
	     print "  sql_class_t *udt = sch_name_to_type (isp_schema (NULL), udt_name);"
	     print "  if (udt &&  UDT_IS_INSTANTIABLE(udt))"
	     print "    {"
	     print "      caddr_t attr1 = sqlp_box_id_upcase (attr);"
	     print "      if (-1 == udt_find_field (udt->scl_member_map, attr1))"
             print "        ddl_ensure_table (\"do this always\", text);"
	     print "      dk_free_box (attr1);"
	     print "    }"
	     print "}"
	   }

	   if (pass_bootstrap_cli != 0)
	     print "void\nsqls_define" init_name " (client_connection_t *bootstrap_cli)\n{"
           else
	     print "void\nsqls_define" init_name " (void)\n{"

	   if (has_qualifier > 0 || (length (defines) > 0 && qualifier != "DB"))
	     print "  caddr_t saved_qualifier = bootstrap_cli->cli_qualifier;\n"
	   if (n_upgraded_tables > 0)
	     print "  dbe_table_t *macro_tb;\n"
	   for (i = 1; i <= nfiles; i++)
	     if (length (files[i]) > 0)
	       print files[i] "\n"

           if (length (defines) > 0)
	     {
	       if (qualifier != "DB")
		 {
		   print \
		     "  /* " end_name " */\n" \
		     "  bootstrap_cli->cli_qualifier = box_string (\"" qualifier "\");\n" \
		     defines "\n\n" \
		     "  dk_free_box (bootstrap_cli->cli_qualifier);\n" \
		     "  bootstrap_cli->cli_qualifier =  saved_qualifier;"
		 }
	       else
		 print "  /* " end_name " */\n" defines
	     }

	   print"}"

	   print "\n\nvoid\nsqls_arfw_define" init_name " (void)\n{"

	   if (has_qualifier_arfw > 0 || (length (defines_arfw) > 0 && qualifier != "DB"))
	     print "  caddr_t saved_qualifier = bootstrap_cli->cli_qualifier;\n"
	   if (n_upgraded_tables_arfw > 0)
	     print "  dbe_table_t *macro_tb;\n"
	   for (i = 1; i <= nfiles; i++)
	     if (length (files_arfw[i]) > 0)
	       print files_arfw[i] "\n"

	   if (length (defines_arfw) > 0)
	     {
	       if (qualifier != "DB")
		 {
		   print \
		     "  /* " filename " */\n" \
		     "  bootstrap_cli->cli_qualifier = box_string (\"" qualifier "\");\n" \
		     defines_arfw "\n\n" \
		     "  dk_free_box (bootstrap_cli->cli_qualifier);\n" \
		     "  bootstrap_cli->cli_qualifier =  saved_qualifier;"
		 }
	       else
		 print "  /* " filename " */\n" defines_arfw
	     }
	   print"}"

	   if (length (bif_text) > 0)
	   {
	       print "\n\nvoid\nsqls_bif_init" init_name " (void)\n{"
               print  bif_text
	       print"}"
	   }
        }
