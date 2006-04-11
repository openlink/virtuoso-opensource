@rem = '--*-Perl-*--
@echo off
perl.exe %_batchname %$
goto endofperl
@rem ';

# I'm pretty sure the serializer doesn't handle attr values correctly yet

use strict;
use POSIX;
use Getopt::Long;
use XML::DOM;
use Time::Local;
use vars qw(%XMLHOOK $TEMPDIR $XSLPROC);

select(STDERR); $| = 1;
select(STDOUT); $| = 1;

%XMLHOOK = ();

$TEMPDIR = $ENV{'TMP'} || $ENV{'TEMP'} || "c:/";
$TEMPDIR =~ s/\\/\//sg;
chop($TEMPDIR) if $TEMPDIR =~ /\/$/;

$XSLPROC = "xt"; # FIX THIS!!!

my %ucodeentity = ();
my %ucodetext = ();
my %ucodeunmapped = ();

my $usage = "
Usage: $0 [options] file
Where options are:
--xmlfile xmlfile [--stylesheet xslfile] [--keep]
--ctrlfile ctrlfile
--library libraryfile
--transclude|--notransclude
--xslprocessor xslprocessor
--unchunked file.html
--verbose|--quiet
";

my %opt = ();
&GetOptions(\%opt,
	    'ctrlfile:s',
	    'library=s@',
	    'transclude!',
	    'xslprocessor:s',
	    'unchunked:s',
	    'verbose+',
	    'debug',
	    'quiet',
	    'keep',
	    'xmlfile:s',
	    'stylesheet:s') || die "Bad options.\n$usage";

my $ctrlfile = $opt{'ctrlfile'};
my $xmlfile = $opt{'xmlfile'};
my $keep = $opt{'keep'};
my $xslfile = $opt{'stylesheet'};
my $transclude = $opt{'transclude'};
my $debug = $opt{'debug'};
my $verbose = $opt{'verbose'};
my $unchunked = $opt{'unchunked'};
my $xslproc = $opt{'xslprocessor'} || $XSLPROC;

my $file = shift @ARGV || "$TEMPDIR/chunk.$$.xml";

# verbose is 1 by default, unless quiet
if (!defined($verbose)) {
    $verbose = 1 if !$opt{'quiet'};
} else {
    $verbose++;
}

# or debug
$verbose = 99 if $debug;

my $binpath = $0;
$binpath =~ s/\\/\//g; # normalize slashes
$binpath = $1 if $binpath =~ /^(.*)\/[^\/]+$/;

if (!$ctrlfile) {
    $ctrlfile = "dbchunk.xml";
}

$ctrlfile = "$binpath/$ctrlfile"
    if ! -f $ctrlfile && -f "$binpath/$ctrlfile";

die "No control file.\n$usage" if $ctrlfile eq '';

my @libraries = exists($opt{'library'}) ? @{$opt{'library'}} : ();
foreach my $libraryfile (@libraries) {
    print "Loading library $libraryfile...\n" if $verbose;
    require $libraryfile;
}

if ($xmlfile) {
    my $xsl = $xslfile || "n:/share/xsl/docbook/html/docbook.xsl";
    my $doc = $xmlfile;
    my $rc = 0;

    if ($ENV{'COMSPEC'}) {
	my $comspec = $ENV{'COMSPEC'};
	$rc = system("$comspec /c$xslproc $doc $xsl $file");
    } else {
	$rc = system("$xslproc $doc $xsl $file");
    }

    exit 1 if $rc;
}

my $parser = new XML::DOM::Parser (NoExpand => 0);

my $chunk_extension = ".html";
my %chunk_elements = ();
my %chunk_notfirst = ();
my %chunk_depth = ();
my %empty_elements = ();
my %chunk_renumber = ();
my %chunk_renumber_inv = ();
my %chunk_number = ();

my $public_id = "";
my $system_id = "";

print "Loading control file $ctrlfile..." if $verbose;
my $ctrl = $parser->parsefile($ctrlfile);
print "done.\n" if $verbose;

&parse_controlfile($ctrl);

print "Loading document $file..." if $verbose;
my $doc = $parser->parsefile($file);
print "done.\n" if $verbose;

#&xml_dump($doc->getDocumentElement());
#exit;

my $head = $doc->getElementsByTagName('head')->item(0);

my @chunklist = ();
my %chunkmap = ();
my @chunkfiles = ();
my $chunknum = 0;
my @chunkstack = ();
my %anchormap = ();
my %chunkidmap = ();
my @numberstack = ();

print "Analyzing document...\n" if $verbose;

&find_chunks($doc->getDocumentElement());

print "Converting XML constructs to HTML...\n" if $verbose;

&xml_to_html($doc->getDocumentElement());

if ($unchunked) {
    print "Writing unchunked file: $unchunked\n" if $verbose;
    &write_node_chunk($doc->getDocumentElement(), $unchunked, 1);
}

print "Writing chunks...\n" if $verbose;

&write_chunks($doc->getDocumentElement());

if ($xmlfile && !$keep) {
    unlink($file);
}

exit;

sub xml_dump {
    my $node = shift;
    my $depth = shift || 0;

    print " " x $depth;
    print $node;
    print "\n";

    my $child = $node->getFirstChild();
    while ($child) {
	&xml_dump($child, $depth+1);
	$child = $child->getNextSibling();
    }
}

sub find_chunks {
    my $root  = shift;
    my $depth = shift;
    my $ischunk = &chunk($root);
    my $filename = "";

    return if $root->getNodeType() != ELEMENT_NODE;

    if ($root->getTagName() eq 'div') {
	&enter_div($root);
    }

    if ($root->getAttribute('class')
	&& exists($chunk_elements{$root->getAttribute('class')})) {
	my $class = $root->getAttribute('class');
	my $number = &stack_number($class);

	$chunk_number{$root} = $number;
	$filename = &chunk_filename($root) if $ischunk;

	if ($verbose > 1) {
	    print " " x ($depth-1) if $depth > 1;
	    print "-->$class $number";
	    print " ($filename)" if $ischunk;
	    print "\n";
	}
    }

    $filename = &chunk_filename($root) if $ischunk && ($filename eq '');

    if ($ischunk) {
	my $class = $root->getAttribute('class');

	$chunklist[$chunknum] = $root;
	$chunkmap{$root} = $chunknum;
	$chunkfiles[$chunknum] = $filename;

#	print "\$chunkfiles[$chunknum]=$filename\n";

	if ($root->getAttribute('id')) {
	    my $id = $root->getAttribute('id');
	    $chunkidmap{$id} = $root;
	}

	push (@chunkstack, $chunknum);
	$chunknum++;
    }

    if (($root->getTagName() eq 'a' && $root->getAttribute('name'))) {
	my $parent = $root->getParentNode();
	while ($parent && !&chunk($parent)) {
	    $parent = $parent->getParentNode();
	}
	my $filename = $chunkfiles[$chunkmap{$parent}];

	$anchormap{$root->getAttribute('name')} = $chunkstack[$#chunkstack];
#	print "anchormap{", $root->getAttribute('name'),
#             "} = chunkstack[", $#chunkstack, "] ($filename)\n";
    }

    my $child = $root->getFirstChild();
    while ($child) {
	my $nextSibling = $child->getNextSibling();

	if ($child->getNodeType() != ELEMENT_NODE) {
	    $child = $nextSibling;
	    next;
	}

	&find_chunks($child, $depth+1);
	$child = $nextSibling;
    }

    pop (@chunkstack) if $ischunk;

    if ($root->getTagName() eq 'div') {
	&exit_div($root);
    }
}

sub xml_to_html {
    my $root  = shift;
    my $parent = shift;
    my $child = $root->getFirstChild();

    while ($child) {
	my $nextSibling = $child->getNextSibling();

	if ($child->getNodeType() != ELEMENT_NODE) {
	    $child = $nextSibling;
	    next;
	}

	&xml_to_html($child, $root);
	$child = $nextSibling;
    }

    foreach my $package (keys %XMLHOOK) {
	eval("${package}::apply(\$doc, \$root, \$parent)")
	    if eval("${package}::applies(\$doc, \$root, \$parent)");
    }
}

sub write_chunks {
    my $root  = shift;
    my $parent = shift;
    my $child = $root->getFirstChild();

    while ($child) {
	my $nextSibling = $child->getNextSibling();

	if ($child->getNodeType() != ELEMENT_NODE) {
	    $child = $nextSibling;
	    next;
	}

	&write_chunks($child, $root);
	$child = $nextSibling;
    }

    if ($root->getTagName() eq 'a') {
	my $href = $root->getAttribute('href');

	if ($href =~ /^\#(.+)$/) {
	    my $name = $1;
	    my $cnum = $anchormap{$name};
	    my $chunkfile = $chunkfiles[$cnum];

	    my $parent = $root->getParentNode();
	    while ($parent && !&chunk($parent)) {
		$parent = $parent->getParentNode();
	    }

#	    print "a href=#$name -> $cnum\n";

	    if ($chunkidmap{$name}) {
		$href = $chunkfile;
	    } else {
		$href = "$chunkfile#$name";
	    }

#	    print "Normalize for $name ($href)\n";
	    $href = &normalize_path($chunklist[$chunkmap{$parent}], $href);

	    $root->setAttribute('href', $href);
	}
    }

    if (exists($chunkmap{$root})) {
	my $chunknum = $chunkmap{$root};
	my $filename = $chunkfiles[$chunknum];

	&write_node_chunk($root, $filename);
	$parent->removeChild($root) if $parent;
    }
}

sub write_node_chunk {
    my $node = shift;
    my $filename = shift;
    my $suppress_navigation = shift;
    local *F;

    print "Writing $filename\n" if $verbose;

    my $dir = "";
    $dir = $1 if $filename =~ /^(.+)\/[^\/]+$/;
    &recursive_mkdir($dir) if ($dir ne "");

    open (F, ">$filename") || warn "Failed to open $filename\n";

    if ($public_id || $system_id) {
	print F "<!DOCTYPE html";
	print F " PUBLIC \"$public_id\"";
	print F " SYSTEM" if !$public_id;
	print F " \"$system_id\">\n";
    }

    print F "<html>\n<head>\n";
    &copy_head(*F, $node, $head);

    my $headlist = $ctrl->getElementsByTagName('ch:chunk-head');
    for (my $count = 0; $count < $headlist->getLength(); $count++) {
	my $head = $headlist->item($count);
	&html_print(*F, $node, $head);
    }

    print F "\n</head>\n";
    print F "<body ";

    my $bodylist = $ctrl->getElementsByTagName('ch:body-attributes');
    for (my $count = 0; $count < $bodylist->getLength(); $count++) {
	my $bodyatt = $bodylist->item($count);
	my $attrlist = $bodyatt->getElementsByTagName('attribute');
	for (my $acount = 0; $acount < $attrlist->getLength(); $acount++) {
	    my $attr  = $attrlist->item($acount);
	    my $name  = $attr->getAttribute('name');
	    my $value = $attr->getAttribute('value');
	    $value = &keyword_subst($node, $value);
	    $value = serialize($value);
	    if ($value =~ /\"/s) {
		print F "$name='$value' ";
	    } else {
		print F "$name=\"$value\" ";
	    }
	}
    }

    print F ">\n";

    if (!$suppress_navigation) {
	my $headnavlist = $ctrl->getElementsByTagName('ch:chunk-header-navigation');
	for (my $count = 0; $count < $headnavlist->getLength(); $count++) {
	    my $headnav = $headnavlist->item($count);
	    &html_print(*F, $node, $headnav);
	}
    }

    &html_print(*F, $node, $node, 1);

    if (!$suppress_navigation) {
	my $footnavlist = $ctrl->getElementsByTagName('ch:chunk-footer-navigation');
	for (my $count = 0; $count < $footnavlist->getLength(); $count++) {
	    my $footnav = $footnavlist->item($count);
	    &html_print(*F, $node, $footnav);
	}
    }

    print F "\n</BODY>\n</HTML>\n";
	close (F);
}

sub chunk {
    my $node = shift;
    my $ischunk = 1;

    return 0 if $node->getNodeType() != ELEMENT_NODE;

    my $class = $node->getAttribute('class');

    # it's not a chunk element
    $ischunk = 0 if !exists($chunk_elements{$class});

    # it's too deeply nested
    if (exists($chunk_depth{$class})) {
	my $parent = $node->getParentNode();
	my $depth = 1;
	while ($parent) {
	    $depth++ if ($parent->getNodeType == ELEMENT_NODE
			 && $parent->getTagName eq 'div'
			 && $parent->getAttribute('class') eq $class);
	    $parent = $parent->getParentNode();
	}
	$ischunk = 0 if $depth > $chunk_depth{$class};
    }

    # it's the first chunk and notfirst is true for this class
    $ischunk = 0 if ($chunk_notfirst{$class}
		     && &stack_number($class) == 0);

    # if any of its parents are chunk elements but they aren't chunks,
    # then this one isn't a chunk either
    my $pnode = $node->getParentNode();
    while ($ischunk && $pnode && $pnode->getNodeType() == ELEMENT_NODE) {
	my $name = $pnode->getAttribute('class');
	if ($chunk_elements{$name} && !exists($chunkmap{$pnode})) {
	    $ischunk = 0;
	}
	$pnode = $pnode->getParentNode();
    }

    return $ischunk;
}

sub increment {
    my $class = shift;
    my $top = $#numberstack;
    my $found = 0;

    # walk back down the numberstack; if we encounter $class before
    # we encounter an element that causes $class to be restarted,
    # increment it, otherwise add it.

    # numberstack[0] = XML::DOM::Element
    # numberstack[1] = "chapter=1"
    # ...

    while ($top >= 0) {
	if (ref $numberstack[$top] eq 'XML::DOM::Element') {
	    my $elemclass = $numberstack[$top]->getAttribute('class');
	    last if $chunk_renumber_inv{$class}->{$elemclass};
	    $top--;
	    next;
	}

	die if $numberstack[$top] !~ /^(.*)=(\d+)$/;
	my $stackclass = $1;
	my $stacknum = $2;

	if ($stackclass eq $class) {
	    $stacknum++;
	    $numberstack[$top] = "$class=$stacknum";
	    $found = 1;
	    last;
	}

	$top--;
    }

    if ($found) {
#	print "Incr: ", $numberstack[$top], "\n";
    }

    if (!$found) {
	push (@numberstack, "$class=1");
#	print "Incr: $class=1 [new]\n";
    }
}

sub stack_number {
    my $class = shift;
    my $top = $#numberstack;
    my $found = 0;

    while ($top >= 0) {
	if (ref $numberstack[$top] eq 'XML::DOM::Element') {
	    $top--;
	    next;
	}

	die if $numberstack[$top] !~ /^(.*)=(\d+)$/;
	my $stackclass = $1;
	my $stacknum = $2;

	return $stacknum if ($stackclass eq $class);
	$top--;
    }

    return 0;
}

sub show_stack {
    my $msg = shift;

    return if $debug < 5;

    print "numberstack ($msg):\n";
    for (my $top = 0; $top <= $#numberstack; $top++) {
	print "\t\t\t", $numberstack[$top];
	if (ref $numberstack[$top]) {
	    print " ", $numberstack[$top]->getAttribute('class');
	}
	print "\n";
    }
    print "\n";
}

sub enter_div {
    my $node = shift;
    my $class = $node->getAttribute('class');

    &increment($class);
    push(@numberstack, $node);

    &show_stack("enter $class") if $debug;
}

sub exit_div {
    my $node = shift;
    my $class = $node->getAttribute('class');
    my @localstack = ();
    my $top = 0;

    # walk through the numberstack, until we find the node
    while ($top <= $#numberstack) {
	last if (ref $numberstack[$top] eq 'XML::DOM::Element'
		 && $numberstack[$top] == $node);
	push (@localstack, $numberstack[$top]);
	$top++;
    }

    # ok, now walk through the rest of the numberstack, skipping
    # those elements that get renumbered at this level
    $top++; # skip the node
    while ($top <= $#numberstack) {
	if (ref $numberstack[$top] eq 'XML::DOM::Element') {
	    push (@localstack, $numberstack[$top]);
	    $top++;
	    next;
	}

	die if $numberstack[$top] !~ /^(.*)=(\d+)$/;
	my $stackclass = $1;

	push (@localstack, $numberstack[$top])
	    if !$chunk_renumber{$class}->{$stackclass};

	$top++;
    }

    @numberstack = @localstack;
    &show_stack("exit $class") if $debug;
}

sub parent_chunk {
    my $node = shift;
    my $parent = $node->getParentNode();

    while ($parent) {
	return $parent if &chunk($parent);
	$parent = $parent->getParentNode();
    }

    return undef;
}

sub chunk_filename {
    # note: this call is not idempotent!
    my $node = shift;
    my $filename = "";
    my $dir = "";

    return "" if !$node;
    return "" if $node->getNodeType() != ELEMENT_NODE;

#    print "Examining: $node ";
#    if ($node->getNodeType() == ELEMENT_NODE) {
#	print "(";
#	print $node->getTagName();
#	print ", ";
#	print $node->getAttribute('class');
#	print ", ";
#	print $node->getAttribute('id');
#	print ")";
#    }
#    print "\n";

    my $child = $node->getFirstChild();
    my $delnode;

    while ($child) {
#	print "\tChild: $child";
#	if ($child->getNodeType() == ELEMENT_NODE) {
#	    print "(";
#	    print $child->getTagName();
#	    print ", ";
#	    print $child->getAttribute('class');
#	    print ", ";
#	    print $child->getAttribute('id');
#	    print ")";
#	}
#
#	if ($child->getNodeType() == TEXT_NODE) {
#	    my $text = $child->toString();
#	    $text =~ s/^\s*//sg;
#	    $text =~ s/\s*$//sg;
#	    print "($text)";
#	}
#	print "\n";

	$delnode = undef;

	if ($child->getNodeType() == PROCESSING_INSTRUCTION_NODE) {
	    my $pi = $child->getTarget();
	    my $data = $child->getData();

#	    print "\t\tPI $pi, $data\n";

	    next if $pi ne 'dbhtml';

	    $delnode = $child;

	    $data = " $data"; # make the regex easier

	    $filename = $2 if $data =~ / filename=([\'\"])(.*?)\1/;
	    $dir = $2 if $data =~ / dir=([\'\"])(.*?)\1/;
	}
	$child = $child->getNextSibling();

	if ($delnode) {
#	    print "Removed PI node ($delnode) for $dir, $filename\n";
	    $node->removeChild($delnode)
	}
    }

    $filename = &recursive_chunk_filename($node) if $filename eq "";
    $dir .= "/" if ($dir ne "") && ($dir !~ /\/\\$/);

#    print "\tFilename is $dir$filename\n";

    return "$dir$filename";
}

sub recursive_chunk_filename {
    my $node = shift;
    my $recurse = shift;

    return "" if !$node;
    return "" if $node->getNodeType() != ELEMENT_NODE;

    my $parent = $node->getParentNode();
    while ($parent
	   && ($parent->getNodeType() != ELEMENT_NODE
	       || $parent->getTagName() ne 'div'
	       || !$parent->getAttribute('class')
	       || !exists($chunk_elements{$parent->getAttribute('class')}))) {
	$parent = $parent->getParentNode();
    }

    my $class  = $node->getAttribute('class');

    my $pname = &recursive_chunk_filename($parent, 1);
    my $lname = "";

    $lname = sprintf("%s%02d",
		     $chunk_elements{$class},
		     $chunk_number{$node})
	if $chunk_elements{$class} ne "";

    my $file  = $pname . $lname;

    if ($class eq 'book') {
	# only use the book prefix if the book is part of a set
	# and this isn't the "book" node.
	$file = "" if $parent || $recurse;
    }

    $file .= $chunk_extension if ($file ne "") && !$recurse;

    return $file;
}

sub parse_controlfile {
    my $ctrl = shift;
    my $root = $ctrl->getDocumentElement();

    $chunk_extension = $root->getAttribute('chunk-extension')
	if $root->getAttribute('chunk-extension');

    $transclude = 1
	if $root->getAttribute('transclude') && !defined($transclude);

    my $wrapperlist = $root->getElementsByTagName("chunk-library");
    for (my $count = 0; $count < $wrapperlist->getLength(); $count++) {
	my $wrapper = $wrapperlist->item($count);
	my $libraryfile = $wrapper->getAttribute('src');
	print "Loading library $libraryfile...\n" if $verbose;
	my $package = eval("require \"$libraryfile\"");
	$XMLHOOK{$package} = 1 if eval("${package}::init(\$root)");
    }

    my $wrapperlist = $root->getElementsByTagName("chunk-elements");
    for (my $count = 0; $count < $wrapperlist->getLength(); $count++) {
	my $wrapper = $wrapperlist->item($count);
	my $elementlist = $wrapper->getElementsByTagName("element");
	for (my $count = 0; $count < $elementlist->getLength(); $count++) {
	    my $element = $elementlist->item($count);
	    my $name = $element->getAttribute('name') || next;
	    my $abbr = $element->getAttribute('abbrev');
	    my $notfirst = $element->getAttribute('notfirst');
	    my $depth = $element->getAttribute('depth');

	    $chunk_elements{$name} = $abbr;
	    $chunk_notfirst{$name} = 1 if $notfirst;
	    $chunk_depth{$name} = $depth if $depth;
	}
    }

    my $wrapperlist = $root->getElementsByTagName("empty-elements");
    for (my $count = 0; $count < $wrapperlist->getLength(); $count++) {
	my $wrapper = $wrapperlist->item($count);
	my $elementlist = $wrapper->getElementsByTagName("element");
	for (my $count = 0; $count < $elementlist->getLength(); $count++) {
	    my $element = $elementlist->item($count);
	    my $name = $element->getAttribute('name') || next;
	    $empty_elements{$name} = 1;
	}
    }

    my $wrapperlist = $root->getElementsByTagName("chunk-enumeration-nesting");
    for (my $count = 0; $count < $wrapperlist->getLength(); $count++) {
	my $wrapper = $wrapperlist->item($count);
	my $nestresetlist = $wrapper->getElementsByTagName("nest-reset");
	for (my $count = 0; $count < $nestresetlist->getLength(); $count++) {
	    my $nestreset = $nestresetlist->item($count);
	    my $nestname = $nestreset->getAttribute('name');
	    my $elementlist = $nestreset->getElementsByTagName("element");
	    for (my $count = 0;
		 $count < $elementlist->getLength();
		 $count++) {
		my $element = $elementlist->item($count);
		my $name = $element->getAttribute('name') || next;
		$chunk_renumber{$nestname} = {}
		    if !exists($chunk_renumber{$nestname});
		$chunk_renumber{$nestname}->{$name} = 1;
		$chunk_renumber_inv{$name} = {}
		    if !exists($chunk_renumber_inv{$name});
		$chunk_renumber_inv{$name}->{$nestname} = 1;
	    }
	}
    }

    my $charmaps = $root->getElementsByTagName("character-mapping");

    for (my $count = 0; $count < $charmaps->getLength(); $count++) {
	my $map = $charmaps->item($count);
	my $unicodelist = $map->getElementsByTagName('unicode');
	for (my $dcount = 0; $dcount < $unicodelist->getLength(); $dcount++) {
	    my $unicode = $unicodelist->item($dcount);
	    my $char = $unicode->getAttribute('char');
	    my $entity = $unicode->getAttribute('entity');

	    if ($char =~ /^0x0*/) {
		if ($' eq '') {
		    $char = "0";
		} else {
		    $char = hex($');
		}
	    }

	    if ($entity) {
		$ucodeentity{$char} = $entity;
	    } else {
		my $text = $unicode->getFirstChild()->toString();
		$ucodetext{$char} = $text;
	    }
	}
    }

    my $wrapperlist = $root->getElementsByTagName("doctype");
    for (my $count = 0; $count < $wrapperlist->getLength(); $count++) {
	my $doctype = $wrapperlist->item($count);
	$public_id = $doctype->getAttribute('public-id')
	    if $doctype->getAttribute('public-id');
	$system_id = $doctype->getAttribute('system-id')
	    if $doctype->getAttribute('system-id');
    }
}

sub copy_head {
    local *F = shift;
    my $chunknode = shift;
    my $head = shift;
    my $child = $head->getFirstChild();

    while ($child) {
	my $header = $child;
	$child = $child->getNextSibling();
	next if $header->getNodeType() != ELEMENT_NODE;
	next if $header->getTagName() eq 'title';
	&html_print(*F, $chunknode, $header);
	print F "\n";
    }

    # If the stylesheet generates a <head> node, copy the contents of
    # that node to the output for this chunk.
    $head = $chunknode->getElementsByTagName('head');
    if ($head && $head->getLength() > 0) {
	$child = $head->item(0)->getFirstChild();
	while ($child) {
	    my $header = $child;
	    $child = $child->getNextSibling();
	    next if $header->getNodeType() != ELEMENT_NODE;
	    &html_print(*F, $chunknode, $header);
	    print F "\n";
	}
	$chunknode->removeChild($head->item(0));
    }
}

sub html_print {
    local *F = shift;
    my $chunknode = shift;
    my $node = shift;
    my $suppress_subst = shift;

    return "" if !$node;

    if ($node->getNodeType() == ELEMENT_NODE) {
	my $tagname = $node->getTagName();
	my $attlist = $node->getAttributes();
	my %attr = ();

	for (my $count = 0; $count < $attlist->getLength(); $count++) {
	    my $attr = $attlist->item($count);
	    my $name = $attr->getName();
	    my $value = $node->getAttribute($name);

	    $value = &keyword_subst($chunknode, $value) if !$suppress_subst;

	    $attr{$name} = $value;
	}

	if ($tagname eq 'ch:if') {
	    if ($attr{'ch:test'} ne "") {
		my $child = $node->getFirstChild();
		while ($child) {
		    &html_print(*F, $chunknode, $child, $suppress_subst);
		    $child = $child->getNextSibling();
		}
	    }
	} elsif ($tagname =~ /^ch:/) {
	    my $child = $node->getFirstChild();
	    while ($child) {
		&html_print(*F, $chunknode, $child, $suppress_subst);
		$child = $child->getNextSibling();
	    }
	} elsif ($transclude
		 && $tagname eq 'a'
		 && $attr{'xml:link'} eq 'simple'
		 && $attr{'show'} eq 'embed'
		 && $attr{'actuate'} eq 'auto') {
	    local *G;
	    my $file = $attr{'href'};
	    if (open (G, $attr{'href'})) {
		while (<G>) {
		    s/&/&amp;/g;
		    s/</&lt;/g;
		    print F $_;
		}
		close (G);
	    } else {
		print "Transclusion failed: $file\n";
	    }
	} else {
	    if ($verbose
		&& $tagname eq 'a'
		&& $attr{'xml:link'} eq 'simple'
		&& $attr{'show'} eq 'embed'
		&& $attr{'actuate'} eq 'auto') {
		print "Transclusion link ignored for ", $attr{'href'}, "\n";
	    }

	    print F "<$tagname";

	    foreach my $name (keys %attr) {
		my $value = serialize($attr{$name});
		my $quot = $value =~ /\"/ ? "'" : '"';
		print F " $name=$quot$value$quot";
	    }
	    print F ">";

	    my $child = $node->getFirstChild();
	    while ($child) {
		&html_print(*F, $chunknode, $child, $suppress_subst);
		$child = $child->getNextSibling();
	    }

	    print F "</$tagname>" if !$empty_elements{$tagname};
	}
    } elsif ($node->getNodeType() == TEXT_NODE) {
	my $text = $node->getData();
	$text = &keyword_subst($chunknode, $text) if !$suppress_subst;
	print F serialize($text);
    } elsif ($node->getNodeType() == ENTITY_REFERENCE_NODE) {
	print F $node->toString();;
    } else {
	# should the serializer be called here? No...I don't think so
	print F $node->toString();
    }
}

sub keyword_subst {
    my $node = shift;
    my $text = shift;
    my $result = "";
    my $chunknum = $chunkmap{$node};

    while ($text =~ /\{/s) {
	$result .= $`;
	$text = $';

	if ($text =~ /^\{/s) {
	    $text = $';
	    $result .= "{";
	    next;
	}

	if ($text =~ /^(.+?)\}/s) {
	    my $keyword = $1;
	    $text = $';

	    if ($keyword eq 'title') {
		$result .= &element_title_string($node);
	    } elsif ($keyword eq 'subtitle') {
		$result .= &element_title_string($node, 'subtitle');
	    } elsif ($keyword eq 'filename') {
		$result .= &normalize_path($node,
					   $chunkfiles[$chunkmap{$node}]);
	    } elsif ($keyword eq 'prevlink') {
		$result .= &normalize_path($node, $chunkfiles[$chunknum-1])
		    if $chunknum > 0;
	    } elsif ($keyword eq 'uplink') {
		my $parent = parent_chunk($node);
		$result .= &normalize_path($node,
					   $chunkfiles[$chunkmap{$parent}])
		    if $parent;
	    } elsif ($keyword eq 'nextlink') {
		$result .= &normalize_path($node, $chunkfiles[$chunknum+1])
		    if $chunknum < $#chunkfiles;
	    } elsif ($keyword eq 'homelink') {
		$result .= &normalize_path($node, $chunkfiles[0]);
	    } elsif ($keyword eq 'prevtitle') {
		$result .= &element_title_string($chunklist[$chunknum-1])
		    if $chunknum > 0;
	    } elsif ($keyword eq 'nexttitle') {
		$result .= &element_title_string($chunklist[$chunknum+1])
		    if $chunknum < $#chunklist;
	    } elsif ($keyword eq 'uptitle') {
		my $parent = parent_chunk($node);
		$result .= &element_title_string($parent) if $parent;
	    } elsif ($keyword eq 'hometitle') {
		$result .= &element_title_string($chunklist[0]);
	    } else {
		die "Unrecognized keyword: \"$keyword\"\n";
	    }
	} else {
	    die "Parse error in fragment: $text\n";
	}
    }

    return $result . $text;
}

sub element_title_string {
    my $node = shift;
    my $class = shift || "title";

    my $child = $node->getFirstChild();

    while ($child) {
	if ($child->getNodeType() != ELEMENT_NODE) {
	    $child = $child->getNextSibling();
	    next;
	}

	return &node_content($child) if
	    ($child->getTagName() =~ /^\h\d/
	     && $child->getAttribute('class') eq $class);

	if (($child->getTagName() eq 'div')
	    && ($child->getAttribute('class') eq 'titlepage')) {
	    return &element_title_string($child, $class);
	}

	$child = $child->getNextSibling();
    }

    return "&nbsp;";
}

sub node_content {
    my $node = shift;
    my $content = "";
    my $child = $node->getFirstChild();
    while ($child) {
	if ($child->getNodeType() == ELEMENT_NODE) {
	    $content .= &node_content($child);
	} elsif ($child->getNodeType() == TEXT_NODE) {
	    $content .= $child->toString();
	}
	$child = $child->getNextSibling();
    }
    return $content;
}

sub normalize_path {
    my $curnode = shift;
    my $path = shift;
    my $cnum = $chunkmap{$curnode};
    my $file = $chunkfiles[$cnum];
    my $test = 1;

    $file =~ s/\\/\//sg; # normalize slashes

#    print "here=$file, path=$path, result=" if $debug && $test;

    my @path = split(/\//, $file);

    if ($#path > 0) {
	$file = ("../" x $#path) . $path;
    } else {
	$file = $path;
    }

#    print "$file\n" if $debug && $test;

    return $file;
}

sub recursive_mkdir {
    my $path = shift;
    my @dirs = ();
    my $dir = "";

    $path =~ s/\\/\//g;
    @dirs = split(/\//, $path);

    $path = "";
    foreach $dir (@dirs) {
	$path .= "/" if $path ne "";
	$path .= $dir;
	mkdir($path, 755);
    }
}

sub serialize {
    my $text = shift;
    my $sertext = "";

    my $count = 0;
    while ($count < length($text)) {
	my $ch = substr($text, $count, 1);

	my $num = 0;
	if (ord($ch) >= 0xC0 && ord($ch) <= 0xDF) {
	    $num = Utf8Decode(substr($text, $count, 2));
	    $count += 1;
	} elsif (ord($ch) >= 0xE0 && ord($ch) <= 0xEF) {
	    $num = Utf8Decode(substr($text, $count, 3));
	    $count += 2;
	} elsif (ord($ch) >= 0xF0 && ord($ch) <= 0xFF) {
	    $num = Utf8Decode(substr($text, $count, 4));
	    $count += 3;
	} else {
	    $num = ord($ch);
	}

	if ($ucodeentity{"$num"}) {
	    $sertext .= "&" . $ucodeentity{"$num"} . ";";
	} elsif ($ucodetext{"$num"}) {
	    $sertext .= $ucodetext{"$num"};
	} elsif ($num > 127) {
	    $sertext .= sprintf("&#x%x;", $num);
	    if (!$ucodeunmapped{$num}) {
		print "Unmapped Unicode character '$num' encountered.\n";
		$ucodeunmapped{$num} = 1;
	    }
	} else {
	    $sertext .= $ch;
	}

	$count++;
    }

    return $sertext;
}

sub Utf8Decode {
    my $str = shift;
    my $len = length ($str);
    my $n;

#    print "UNICODE: ";
#    for (my $count = 0; $count < $len; $count++) {
#	my $ch = substr($str, $count, 1);
#	printf "%03d(%2x) ", ord($ch), ord($ch);
#    } 
#    print "\n";

    if ($len == 2) {
	my @n = unpack "C2", $str;
	$n = (($n[0] & 0x3f) << 6) + ($n[1] & 0x3f);
    } elsif ($len == 3) {
	my @n = unpack "C3", $str;
	$n = (($n[0] & 0x1f) << 12) + (($n[1] & 0x3f) << 6) + 
	    ($n[2] & 0x3f);
    } elsif ($len == 4) {
	my @n = unpack "C4", $str;
	$n = (($n[0] & 0x0f) << 18) + (($n[1] & 0x3f) << 12) + 
	    (($n[2] & 0x3f) << 6) + ($n[3] & 0x3f);
    } elsif ($len == 1)	{
	$n = ord ($str);
    } else {
	die "Bad UTF8 value: $str\n";
    }

    return $n;
}

__END__
:endofperl
