#!/usr/bin/env python
"""
Run the pyRdfa package on string containing the RDFa markup.
"""
import sys, getopt, platform, StringIO

from pyRdfa import processFile, processURI, parseRDFa, RDFaError, Options, _open_URI
from pyRdfa.transform.MetaName              	import meta_transform
from pyRdfa.transform.OpenID                	import OpenID_transform
from pyRdfa.transform.DublinCore            	import DC_transform
from pyRdfa.transform.Prefix		 	import set_prefixes, handle_vars
from pyRdfa.Options				import Options, DIST_NS, _add_to_comment_graph, ERROR, GENERIC_XML, XHTML_RDFA, HTML5_RDFA
from rdflib.Graph				import Graph

import xml.dom.minidom

__switch = {
	("http://www.w3.org/1999/xhtml","html") : XHTML_RDFA,
	("http://www.w3.org/2000/svg","svg")    : GENERIC_XML
}

def _processString(str, outputFormat, options, base, rdfOutput) :
	def __register_XML_serializer(formatstring) :
		"""The default XML Serializer of RDFlib is buggy, mainly when handling lists.
		An L{own version<serializers.PrettyXMLSerializer>} is 
		registered in RDFlib and used in the rest of the package.
		@param formatstring: the string to identify this serializer with.
		"""
		from rdflib.plugin import register
		from rdflib.syntax import serializer, serializers
		register(formatstring, serializers.Serializer, "pyRdfa.serializers.PrettyXMLSerializer", "PrettyXMLSerializer")

	def __register_Turtle_serializer(formatstring) :
		"""The default Turtle Serializers of RDFlib is buggy and not very nice as far as the output is concerned. 
		An L{own version<serializers.TurtleSerializer>} is registered in RDFLib and used in the rest of the package.
		@param formatstring: the string to identify this serializer with.
		"""
		from rdflib.plugin import register
		from rdflib.syntax import serializer, serializers
		register(formatstring, serializers.Serializer, "pyRdfa.serializers.TurtleSerializer", "TurtleSerializer")

	# Exchaning the pretty xml serializer agaist the version stored with this package
	if outputFormat == "pretty-xml"  :
		outputFormat = "my-xml"
		__register_XML_serializer(outputFormat)
	elif outputFormat == "turtle" or outputFormat == "n3" :
		outputFormat = "my-turtle"
		__register_Turtle_serializer(outputFormat)
		
	graph = Graph()
	msg = ""
	parse = xml.dom.minidom.parse
	stream = StringIO.StringIO (str)
	try :
		dom = parse(stream)
		# Try to second-guess the input type
		# This is _not_ really kosher, but the minidom is not really namespace aware...
		# In practice the goal is to have the system recognize svg content automatically
		# First see if there is a default namespace defined for the document:
		top = dom.documentElement
		if top.hasAttribute("xmlns") :
			key = (top.getAttribute("xmlns"),top.nodeName)
			if key in __switch :
				options.host_language = __switch[key]
	except :
		# XML Parsing error in the input
		(type,value,traceback) = sys.exc_info()
		if options.host_language == GENERIC_XML or options.lax == False :
			msg = 'Parsing error in input file: "%s"' % value
			raise RDFaError, msg
		else :
			# XML Parsing error in the input
			msg = 'XHTML Parsing error in input file: %s. Falling back on the HTML5 parser' % value
			
			if options != None and options.warnings : options.comment_graph.add_warning(msg)
			
			# note that if a urllib is used, the input has to be closed and reopened...
			# Now try to see if and HTML5 parser is an alternative...
			try :
				import html5lib
			except :
				# no alternative to the XHTML error, because HTML5 parser not available...
				msg2 = 'XHTML Parsing error in input file. Though parsing is lax, HTML5 parser not available' 
				raise RDFaError, msg2
				
			from html5lib import treebuilders
			parser = html5lib.HTMLParser(tree=treebuilders.getTreeBuilder("dom"))
			parse = parser.parse
			try :
				dom = parse(stream)
				# The host language has changed
				options.host_language = HTML5_RDFA
			except :
				# Well, even the HTML5 parser could not do anything with this...
				(type,value,traceback) = sys.exc_info()
				msg2 = 'Parsing error in input file as HTML5: "%s"' % value
				msg3 = msg + '/n' + msg2
				raise RDFaError, msg3
	
	if base == "" :
		sbase = ""
	else :
		sbase = base
	parseRDFa(dom, sbase, graph, options)
	
	# Got all the graphs, serialize them
	
	try :
		if options.comment_graph.graph != None :
			# Add the content of the comment graph to the output
			graph.bind("dist",DIST_NS)
			for t in options.comment_graph.graph : graph.add(t)
		return graph.serialize(format=outputFormat)
	except :
		(type,value,traceback) = sys.exc_info()

		if rdfOutput :
			if base == "" : base = input
			return create_exception_graph("%s" % value, base, outputFormat, http=False)
		else :
			# re-raise the exception and let the caller deal with it...
			raise RDFaError("%s" % value)

		
def processString (file, base = "") :
    extras         = []
    warnings       = False
    space_preserve = True
    xhtml	   = True
    lax	           = True
    options = Options(warnings=warnings,
				  space_preserve=space_preserve,
				  transformers=extras,
				  xhtml=xhtml,
				  lax=lax)
    return _processString(file, "xml", options, base, False)
