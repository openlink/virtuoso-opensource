#
#  jso_metameta.awk
#
#  $Id$
#
#  Embeds SQL code into a C file
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2013 OpenLink Software
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

function c_esc (strg)
{
  return " \"" strg "\""
}

function ttl_iri (strg)
{
  return " <" strg ">"
}

function ttl_esc (strg)
{
  return " \"" strg "\""
}

function report_error(msg)
{
  if (error_reported > 3)
    exit -1
  print FILENAME "(" FNR ") : " msg
  print FILENAME "(" FNR ") : " msg >> /dev/stderr
  error_reported++
}

function write_standard_prefixes()
{
  print "@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> ."
  print "@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> ."
  print "@prefix owl: <http://www.w3.org/2002/07/owl#> ."
  print "@prefix xsd: <http://www.w3.org/2001/XMLSchema#> ."
  print "@prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#> ."
  print ""
}

function c_type_name (hjs_name)
{
  if (c_type_names[hjs_name])
    return c_type_names[hjs_name]
  report_error("Unknown type name '" hjs_name "', supported scalar types are ANY, BOOLEAN, BITMASK, DOUBLE, INTEGER, STRING and names declared in the file")
  return hjs_name
}

function ttl_type_iri (hjs_name)
{
  if (ttl_type_iris[hjs_name])
    return ttl_type_iris[hjs_name]
  report_error("Unknown type name '" hjs_name "', supported scalar types are ANY, BOOLEAN, BITMASK, DOUBLE, INTEGER, STRING and names declared in the file")
}


function top_h ()
{
  if (includes_printed == 0)
    {
      print "#include \"jso.h\""
      includes_printed = 1
    }
  if (post_init == "")
    {
      #init_name = FILENAME
      #gsub("[.]jso$","_jso_init",init_name)
      post_init = "\nextern void " init_name "_jso_init (void);"
    }
}

function write_array_h (c_name, type_ns, type_local, el_c_name, el_ns, el_local, mincount, maxcount, cmt)
{
  if (group_c_type == "")
    {
  top_h()
  print ""
  if (cmt != "")
    print "/*! " cmt " */"
  print "#define JSO_IRI_OF_" c_name " " c_esc(type_ns type_local)
  print "typedef " el_c_name " *" c_name "_t;"
    }
}

function write_const_h (ns, c_name, expn, cmt)
{
  top_h()
  if (cmt != "")
    cmt = "\t/*! " cmt " */"
  print "#define " c_name "\t" expn cmt
}

function write_group_begin_h (cmt)
{
  if (cmt != "")
    cmt = "\t/*! " cmt " */"
  print "  " group_c_type "_t " group_c_name ";" cmt
}

function write_group_end_h ()
{

}


function write_struct_begin_h (cmt)
{
  top_h()
  print ""
  if (cmt != "")
    print "/*! " cmt " */"
  print "#define JSO_IRI_OF_" struct_c_name " " c_esc(struct_type_ns struct_type_local)
  print "typedef struct " struct_c_name "_s"
  print "{"
}

function write_scalar_h (c_name, type, status, cmt)
{
  if (group_c_type == "")
  print "  " c_type_name(type) "\t" c_name ";\t/*!< " cmt " */"
}

function write_struct_end_h ()
{
  print "} " struct_c_name "_t;"
}


function top_c ()
{
  if (includes_printed == 0)
    {
      #header_name = FILENAME
      #gsub("[.]jso$","_jso.h",header_name)
      header_name = init_name "_jso.h"
      print "#include \"" header_name "\""
      includes_printed = 1
    }
  if (post_init == "")
    {
      #init_name = FILENAME
      #gsub("[.]jso$","_jso_init",init_name)
      post_init = "\nvoid\n" init_name "_jso_init (void)\n{"
    }
}

function write_array_c (c_name, type_ns, type_local, el_c_name, el_ns, el_local, mincount, maxcount, cmt)
{
  if (group_c_type == "")
    {
  top_c()
  print ""
  if (cmt != "")
    print "/*! JSO description of " cmt " */"
  print "jso_class_descr_t jso__" c_name " = {"
  print "  JSO_CAT_ARRAY, " c_esc("array of " el_c_name) ","
  print " " c_esc(type_ns type_local), ","
  print " " c_esc(type_ns), "," c_esc(type_local), ","
      print "  NULL /* jsocd_validation_cbk */, NULL /* jsocd_rttis */, {"
  print "    { 0, -1, NULL, NULL },"
  print "    { " c_esc(el_ns el_local), ", " mincount ", " maxcount "} } };"
  post_init = post_init "\n  jso_define_class(&jso__" c_name ");"
    }
}

function write_const_c (ns, c_name, expn, cmt)
{
  top_c()
  post_init = post_init "\n  jso_define_const(" c_esc(ns c_name) ", " c_name ");"
}

function write_group_begin_c (cmt)
{

}

function write_group_end_c ()
{

}

function write_struct_begin_c (cmt, header_name)
{
  top_c()
  print ""
  print "jso_field_descr_t jso_fields__" struct_c_name "[] = {"
}

function write_scalar_c (c_name, type, status, cmt)
{
  if (group_c_type == "")
  print "  { NULL\t," c_esc(c_name) "\t, " type "\t, JSO_" status "\t, JSO_FIELD_OFFSET(" struct_c_name "_t," c_name ")\t, NULL },"
  else
    print "  { NULL\t," c_esc(group_c_name "-" c_name) "\t, " type "\t, JSO_" status "\t, JSO_FIELD_OFFSET(" struct_c_name "_t," group_c_name "." c_name ")\t, NULL },"
}

function write_struct_end_c ()
{
  print "  { NULL\t, NULL\t, NULL\t,0xdeadce11\t,0xdeadce11\t,NULL } };"
  print ""
  if (cmt != "")
    print "/*! JSO description of " cmt " */"
  print "jso_class_descr_t jso__" struct_c_name " = {"
  print "  JSO_CAT_STRUCT, " c_esc("struct " struct_c_name "_s") ","
  print " " c_esc(struct_type_ns struct_type_local), ","
  print " " c_esc(struct_type_ns), "," c_esc(struct_type_local), ","
  print "  NULL /* jsocd_validation_cbk */, NULL /* jsocd_rttis */, {"
  print "    {"
  print "      sizeof (" struct_c_name "_t),"
  print "      -1, jso_fields__" struct_c_name ", NULL /* jsosd_field_hash */, NULL /* jsosd_fields_by_idx */ },"
  print "    { NULL, 0, 0} } };"
  post_init = post_init "\n  jso_define_class(&jso__" struct_c_name ");"
}


function write_array_ttl (c_name, type_ns, type_local, el_c_name, el_ns, el_local, mincount, maxcount, cmt)
{
  if (group_c_type == "")
    {
  print ttl_iri(type_ns type_local)
  print "\trdf:type rdfs:Class ;"
  if (cmt != "")
    print "\trdfs:comment " ttl_esc(cmt) " ;"
  print "\t."
    }
}

function write_const_ttl (ns, c_name, expn, cmt)
{
  print ttl_iri(ns c_name)
  print "\trdf:type virtrdf:CDefine ;"
  if (cmt != "")
    print "\trdfs:comment " ttl_esc(expn " -- " cmt) " ;"
  print "\t."
}

function write_group_begin_ttl (cmt)
{
}

function write_group_end_ttl ()
{
}

function write_struct_begin_ttl (cmt)
{
  print ttl_iri(struct_type_ns struct_type_local)
  print "\trdf:type rdfs:Class ;"
  if (cmt != "")
    print "\trdfs:comment " ttl_esc(cmt) " ;"
  print "\t."
}

function write_scalar_ttl (c_name, type, status, cmt)
{
  print ttl_iri(struct_type_ns group_prop_prefix c_name)
  print "\trdf:type rdf:Property ;"
  if (cmt != "")
    print "\trdfs:comment " ttl_esc(cmt) " ;"
  print "\trdfs:Domain " ttl_iri(struct_type_ns struct_type_local) " ;"
  print "\trdfs:Range " ttl_type_iri(type) " ;"
  print "\tvirtrdf:cardinality 'single' ;"
  print "\t."
}

function write_struct_end_ttl ()
{
  print "# end of description of " struct_c_name
  print ""
}

function write_group_begin_ttlsample (cmt)
{
}

function write_group_end_ttlsample ()
{
}

function write_struct_begin_ttlsample (cmt)
{
  print "@prefix ns" ns_idx ": " ttl_iri(struct_type_ns) " ."
  print ttl_iri("http://example.com/jso-samples#" struct_type_local "Sample")
  print "\trdf_type ns" ns_idx ":" struct_type_local " ;"
}

function write_scalar_ttlsample (c_name, type, status, cmt)
{
  print "\tns" ns_idx ":" c_name " '';\t# " type " " status " " cmt
}

function write_struct_end_ttlsample ()
{
  print "\t."
}


function write_array (c_name, type_ns, type_local, el_c_name, el_ns, el_local, mincount, maxcount, cmt)
{
  if (nsprefixes[type_ns])
    type_ns = nsprefixes[type_ns];
  if (nsprefixes[el_ns])
    el_ns = nsprefixes[el_ns];
  if ("MAX" == maxcount)
    maxcount = "(SMALLEST_POSSIBLE_POINTER-2)"
  if (c_type_names[el_c_name])
    {
#      print "typedef " c_type_names[el_c_name] " *" c_name "_t;"
      c_type_names[c_name] = c_type_names[el_c_name] " *"
      c_type_names["JSO_IRI_OF_" c_name] = c_type_names[el_c_name] " *"
    }
  else
    {
#      print "typedef void * " c_name "_t;"
      c_type_names[c_name] = c_name "_t"
      c_type_names["JSO_IRI_OF_" c_name] = c_name "_t"
    }
  ttl_type_iris["JSO_IRI_OF_" c_name] = ttl_iri(type_ns type_local);
  if (output_mode == "h")
    write_array_h(c_name, type_ns, type_local, el_c_name, el_ns, el_local, mincount, maxcount, cmt)
  if (output_mode == "c")
    write_array_c(c_name, type_ns, type_local, el_c_name, el_ns, el_local, mincount, maxcount, cmt)
  if (output_mode == "ttl")
    write_array_ttl(c_name, type_ns, type_local, el_c_name, el_ns, el_local, mincount, maxcount, cmt)
#  if (output_mode == "ttl-sample")
#    write_array_ttlsample(c_name, type_ns, type_local, el_c_name, el_ns, el_local, mincount, maxcount, cmt)
}

function write_const (ns, c_name, expn, cmt)
{
  if (nsprefixes[ns])
    ns = nsprefixes[ns];
  if (output_mode == "h")
    write_const_h(ns, c_name, expn, cmt)
  if (output_mode == "c")
    write_const_c(ns, c_name, expn, cmt)
  if (output_mode == "ttl")
    write_const_ttl(ns, c_name, expn, cmt)
}

function write_struct_begin (c_name, type_ns, type_local, cmt)
{
  if (struct_c_name != "")
    report_error("JSO_STRUCT_BEGIN without JSO_STRUCT_END of previous structure")
  if (nsprefixes[type_ns])
    type_ns = nsprefixes[type_ns];
  write_array(c_name "_array", type_ns, "array-of-" type_local, "struct " c_name "_s *", type_ns, type_local, "0", "MAX", "")
  struct_c_name = c_name
  struct_type_ns = type_ns
  struct_type_local = type_local
  c_type_names[c_name] = "struct " c_name "_s *";
  c_type_names["JSO_IRI_OF_" c_name] = "struct " c_name "_s *";
  ttl_type_iris["JSO_IRI_OF_" c_name] = ttl_iri(type_ns type_local)
  if (output_mode == "h")
    write_struct_begin_h(cmt)
  if (output_mode == "c")
    write_struct_begin_c(cmt)
  if (output_mode == "ttl")
    write_struct_begin_ttl(cmt)
  if (output_mode == "ttl-sample")
    write_struct_begin_ttlsample(cmt)
}

function write_group_begin (c_name, type_ns, c_type, cmt)
{
  if (group_c_name != "")
    report_error("JSO_GROUP_BEGIN without JSO_GROUP_END of previous group")
  if (struct_c_name == "")
    report_error("JSO_GROUP_BEGIN outside structure")
  if (nsprefixes[type_ns])
    type_ns = nsprefixes[type_ns];
  group_c_name = c_name
  group_type_ns = type_ns
  group_c_type = c_type
  group_prop_prefix = c_name "-"
  if (output_mode == "h")
    write_group_begin_h(cmt)
  if (output_mode == "c")
    write_group_begin_c(cmt)
  if (output_mode == "ttl")
    write_group_begin_ttl(cmt)
  if (output_mode == "ttl-sample")
    write_group_begin_ttlsample(cmt)
}

function write_scalar (c_name, type, status, cmt)
{
  if (struct_c_name == "")
    report_error("JSO_SCALAR outside JSO_STRUCT_BEGIN ... JSO_STRUCT_END")
  if (output_mode == "h")
    write_scalar_h(c_name, type, status, cmt)
  if (output_mode == "c")
    write_scalar_c(c_name, type, status, cmt)
  if (output_mode == "ttl")
    write_scalar_ttl(c_name, type, status, cmt)
  if (output_mode == "ttl-sample")
    write_scalar_ttlsample(c_name, type, status, cmt)
}


function write_struct_end ()
{
  if (struct_c_name == "")
    report_error("JSO_STRUCT_END without matching JSO_STRUCT_BEGIN")
  if (group_c_name != "")
    report_error("JSO_STRUCT_END without JSO_GROUP_END of previous group")
  if (output_mode == "h")
    write_struct_end_h()
  if (output_mode == "c")
    write_struct_end_c()
  if (output_mode == "ttl")
    write_struct_end_ttl()
  if (output_mode == "ttl-sample")
    write_struct_end_ttlsample()
  struct_c_name = ""
  struct_type_ns = ""
  struct_type_local = ""
}

function write_group_end ()
{
  if (group_c_name == "")
    report_error("JSO_GROUP_END without matching JSO_GROUP_BEGIN")
  if (output_mode == "h")
    write_group_end_h()
  if (output_mode == "c")
    write_group_end_c()
  if (output_mode == "ttl")
    write_group_end_ttl()
  if (output_mode == "ttl-sample")
    write_group_end_ttlsample()
  group_c_name = ""
  group_c_type = ""
  group_type_ns = ""
  group_type_local = ""
  group_prop_prefix = ""
}

function write_plain_comment (cmt)
{
  if ((output_mode == "h") || (output_mode == "c"))
    print "/* " cmt " */"
  if ((output_mode == "ttl") || (output_mode == "ttl-sample"))
    print "<!-- " cmt " -->"
}


BEGIN   {
  c_type_names["JSO_ANY"] = "ccaddr_t"
  c_type_names["JSO_ANY_array"] = "ccaddr_t *"
  c_type_names["JSO_ANY_URI"] = "ccaddr_t"
  c_type_names["JSO_BOOLEAN"] = "ptrlong"
  c_type_names["JSO_BITMASK"] = "ptrlong"
  c_type_names["JSO_DOUBLE"] = "double *"
  c_type_names["JSO_INTEGER"] = "ptrlong"
  c_type_names["JSO_INTEGER_array"] = "ptrlong *"
  c_type_names["JSO_STRING"] = "ccaddr_t"
  c_type_names["JSO_STRING_array"] = "ccaddr_t *"
  ttl_type_iris["JSO_ANY"] = "xsd:any"
  ttl_type_iris["JSO_ANY_array"] = "xsd:any"
  ttl_type_iris["JSO_ANY_URI"] = "xsd:anyURI"
  ttl_type_iris["JSO_BOOLEAN"] = "xsd:boolean"
  ttl_type_iris["JSO_BITMASK"] = "xsd:unsignedInteger"
  ttl_type_iris["JSO_DOUBLE"] = "xsd:double"
  ttl_type_iris["JSO_INTEGER"] = "xsd:integer"
  ttl_type_iris["JSO_INTEGER_array"] = "xsd:any"
  ttl_type_iris["JSO_STRING"] = "xsd:string"
  ttl_type_iris["JSO_STRING_array"] = "xsd:any"
  nsprefixes["virtrdf"] = "http://www.openlinksw.com/schemas/virtrdf#"
  struct_c_name = ""
  group_c_name = ""
  group_prop_prefix = ""
  error_reported = 0
  includes_printed = 0
  post_init = ""
  ns_idx = 0
  if ((output_mode == "h") && h_wrapper)
    {
      print "#ifndef " h_wrapper
      print "#define " h_wrapper
    }
  if ((output_mode != "h") && (output_mode != "c") && (output_mode != "ttl") && (output_mode != "ttl-sample"))
    report_error("output_mode variable should be set to 'h', 'c' or 'ttl-sample'.\nGAWK command line should be, say,\ngawk -f jso_reformat.awk -v output_mode=h mystructures.jso")
  if ((output_mode == "ttl") || (output_mode == "ttl-sample"))
    write_standard_prefixes()
  }


END 	{
  if (struct_c_name != "")
    report_error("Unterminated structure: JSO_STRUCT_BEGIN has no matching JSO_STRUCT_END")
  if (output_mode == "h")
    {
      print post_init
      if (h_wrapper)
        print "#endif"
    }
  if (output_mode == "c")
    {
      post_init = post_init "\n}"
      print post_init
    }
  }

#          1                      2---------------------- 3             4------------- 5             6-------------------- 7             8---------------------- 9             10------------ 11            12------------------- 13            14----- 15            16----------- 17                            18-------
match($0,"^(JSO_ARRAY[[:blank:]]+)([a-zA-Z_][a-zA-Z0-9_]*)([[:blank:]]+)([^[:blank:]]+)([[:blank:]]+)([a-zA-Z][a-zA-Z0-9]*)([[:blank:]]+)([a-zA-Z_][a-zA-Z0-9_]*)([[:blank:]]+)([^[:blank:]]+)([[:blank:]]+)([a-zA-Z][a-zA-Z0-9]*)([[:blank:]]+)([0-9]+)([[:blank:]]+)(([0-9]+)|MAX)([[:blank:]]*--!<[[:blank:]]*)([^\r\n]*)$",line)	{
  write_array(line[2], line[4], line[6], line[8], line[10], line[12], line[14], line[16], line[18])
  next
  }

#          1                      2---------------------- 3             4------------- 5             6-------------------- 7             8---------------------- 9             10------------ 11            12------------------- 13            14----- 15            16----------- 17
match($0,"^(JSO_ARRAY[[:blank:]]+)([a-zA-Z_][a-zA-Z0-9_]*)([[:blank:]]+)([^[:blank:]]+)([[:blank:]]+)([a-zA-Z][a-zA-Z0-9]*)([[:blank:]]+)([a-zA-Z_][a-zA-Z0-9_]*)([[:blank:]]+)([^[:blank:]]+)([[:blank:]]+)([a-zA-Z][a-zA-Z0-9]*)([[:blank:]]+)([0-9]+)([[:blank:]]+)(([0-9]+)|MAX)([[:blank:]]*)$",line)	{
  write_array(line[2], line[4], line[6], line[8], line[10], line[12], line[14], line[16], "")
  next
  }

match($0,"^JSO_ARRAY.*$",line)	{
  report_error("Invalid arguments of JSO_ARRAY")
  next
  }

#          1                      2------------- 3             4---------------------- 5             6-------------- 7                             8--------
match($0,"^(JSO_CONST[[:blank:]]+)([^[:blank:]]+)([[:blank:]]+)([a-zA-Z_][a-zA-Z0-9_]*)([[:blank:]]+)([-]?[^ \t\n-]+)([[:blank:]]*--!<[[:blank:]]*)([^\r\n]*)$",line)	{
  write_const(line[2], line[4], line[6], line[8])
  next
  }

#          1                      2------------- 3             4---------------------- 5             6-------------- 7
match($0,"^(JSO_CONST[[:blank:]]+)([^[:blank:]]+)([[:blank:]]+)([a-zA-Z_][a-zA-Z0-9_]*)([[:blank:]]+)([-]?[^ \t\n-]+)([[:blank:]]*)$",line)	{
  write_const(line[2], line[4], line[6], "")
  next
  }

match($0,"^JSO_CONST.*$",line)	{
  report_error("Invalid arguments of JSO_CONST")
  next
  }

#          1                             2---------------------- 3             4------------- 5             6--------------------- 7                             8--------
match($0,"^(JSO_GROUP_BEGIN[[:blank:]]+)([a-zA-Z_][a-zA-Z0-9_]*)([[:blank:]]+)([^[:blank:]]+)([[:blank:]]+)([a-zA-Z][a-zA-Z0-9_]*)([[:blank:]]*--!<[[:blank:]]*)([^\r\n]*)$",line)	{
  write_group_begin(line[2], line[4], line[6], line[8])
  next
  }

#          1                             2---------------------- 3             4------------- 5             6--------------------- 7
match($0,"^(JSO_GROUP_BEGIN[[:blank:]]+)([a-zA-Z_][a-zA-Z0-9_]*)([[:blank:]]+)([^[:blank:]]+)([[:blank:]]+)([a-zA-Z][a-zA-Z0-9_]*)([[:blank:]]*)$",line)	{
  write_group_begin(line[2], line[4], line[6], "")
  next
  }

match($0,"^JSO_GROUP_BEGIN.*$",line)	{
  report_error("Invalid arguments of JSO_GROUP_BEGIN")
  next
  }

match($0,"^JSO_GROUP_END([[:blank:]]*)$",line)	{
  write_group_end()
  next
  }

match($0,"^JSO_GROUP_END.*$",line)	{
  report_error("JSO_GROUP_END can not contain any arguments or comments")
  next
  }

#          1                          2---------------------- 3             4------------- 7
match($0,"^(JSO_NAMESPACE[[:blank:]]+)([a-zA-Z_][a-zA-Z0-9_]*)([[:blank:]]+)([^[:blank:]]+)(([[:blank:]])(+--!<[[:blank:]]*[^\r\n]*)?)$",line)	{
  nsprefixes[line[2]] = line[6]
  next
  }

#          1                          2---------------------- 3             4------------- 7
match($0,"^(JSO_NAMESPACE[[:blank:]]+)([a-zA-Z_][a-zA-Z0-9_]*)([[:blank:]]+)([^[:blank:]]+)(([[:blank:]])(+--!<[[:blank:]]*[^\r\n]*)?)$",line)	{
  nsprefixes[line[2]] = line[6]
  next
  }

match($0,"^JSO_NAMESPACE.*$",line)	{
  report_error("Invalid arguments of JSO_NAMESPACE")
  next
  }

#          1                             2---------------------- 3             4------------- 5             6-------------------- 7                             8--------
match($0,"^(JSO_STRUCT_BEGIN[[:blank:]]+)([a-zA-Z_][a-zA-Z0-9_]*)([[:blank:]]+)([^[:blank:]]+)([[:blank:]]+)([a-zA-Z][a-zA-Z0-9]*)([[:blank:]]*--!<[[:blank:]]*)([^\r\n]*)$",line)	{
  write_struct_begin(line[2], line[4], line[6], line[8])
  next
  }

#          1                             2---------------------- 3             4------------- 5             6-------------------- 7
match($0,"^(JSO_STRUCT_BEGIN[[:blank:]]+)([a-zA-Z_][a-zA-Z0-9_]*)([[:blank:]]+)([^[:blank:]]+)([[:blank:]]+)([a-zA-Z][a-zA-Z0-9]*)([[:blank:]]*)$",line)	{
  write_struct_begin(line[2], line[4], line[6], "")
  next
  }

match($0,"^JSO_STRUCT_BEGIN.*$",line)	{
  report_error("Invalid arguments of JSO_STRUCT_BEGIN")
  next
  }

#          1                       2---------------------- 3             4---------------------- 5             6------- 7                             8--------
match($0,"^(JSO_SCALAR[[:blank:]]+)([a-zA-Z_][a-zA-Z0-9_]*)([[:blank:]]+)([a-zA-Z_][a-zA-Z0-9_]*)([[:blank:]]+)([A-Z_]+)([[:blank:]]*--!<[[:blank:]]*)([^\r\n]*)$",line)	{
  write_scalar(line[2], "JSO_" line[4], line[6], line[8])
  next
  }

#          1                       2---------------------- 3             4---------------------- 5             6------- 7
match($0,"^(JSO_SCALAR[[:blank:]]+)([a-zA-Z_][a-zA-Z0-9_]*)([[:blank:]]+)([a-zA-Z_][a-zA-Z0-9_]*)([[:blank:]]+)([A-Z_]+)([[:blank:]]*)$",line)	{
  write_scalar(line[2], "JSO_" line[4], line[6], "")
  next
  }

match($0,"^JSO_SCALAR.*$",line)	{
  report_error("Invalid arguments of JSO_SCALAR")
  next
  }

#          1                        2---------------------- 3             4---------------------- 5             6------- 7                             8--------
match($0,"^(JSO_POINTER[[:blank:]]+)([a-zA-Z_][a-zA-Z0-9_]*)([[:blank:]]+)([a-zA-Z_][a-zA-Z0-9_]*)([[:blank:]]+)([A-Z_]+)([[:blank:]]*--!<[[:blank:]]*)([^\r\n]*)$",line)	{
  write_scalar(line[2], "JSO_IRI_OF_" line[4], line[6], line[8])
  next
  }

#          1                        2---------------------- 3             4---------------------- 5             6------- 7
match($0,"^(JSO_POINTER[[:blank:]]+)([a-zA-Z_][a-zA-Z0-9_]*)([[:blank:]]+)([a-zA-Z_][a-zA-Z0-9_]*)([[:blank:]]+)([A-Z_]+)([[:blank:]]*)$",line)	{
  write_scalar(line[2], "JSO_IRI_OF_" line[4], line[6], "")
  next
  }

match($0,"^JSO_POINTER.*$",line)	{
  report_error("Invalid arguments of JSO_POINTER")
  next
  }

match($0,"^JSO_STRUCT_END([[:blank:]]*)$",line)	{
  write_struct_end()
  next
  }

match($0,"^JSO_STRUCT_END.*$",line)	{
  report_error("JSO_STRUCT_END can not contain any arguments or comments")
  next
  }

match($0,"^([[:blank:]]*--!<[[:blank:]]*)([^\r\n]*)$",line)	{
  report_error("Special comments like '--!<...' can not appear on separate lines. Use plain '--...' comment instead")
  next
  }

#          1                           2
match($0,"^([[:blank:]]*--[[:blank:]]*)([^\r\n]*)$",line)	{
  write_plain_comment(line[2])
  next
  }

match($0,"^([[:blank:]]*)$",line)	{
  next
  }

/^(.*)$/	{
  report_error("Unrecognized string: " $1)
  }
