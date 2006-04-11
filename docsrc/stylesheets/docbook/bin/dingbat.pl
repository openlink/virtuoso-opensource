# -*- Perl -*-
# This is a chunk.pl library file

package dingbat;

use XML::DOM;

my %entityding = ('60' => 'lt',
		  '38' => 'amp');
my %textding = ();

sub init {
    my $root = shift;
    my $charmaps = $root->getElementsByTagName("character-mapping");

    for (my $count = 0; $count < $charmaps->getLength(); $count++) {
	my $map = $charmaps->item($count);
	my $dingbatlist = $map->getElementsByTagName('dingbat');
	for (my $dcount = 0; $dcount < $dingbatlist->getLength(); $dcount++) {
	    my $dingbat = $dingbatlist->item($dcount);
	    my $name = $dingbat->getAttribute('name');
	    my $entity = $dingbat->getAttribute('entity');

	    if ($entity) {
		$entityding{$name} = $entity;
#		print "Map $name to entity $entity\n";
	    } else {
		my $text = $dingbat->getFirstChild()->toString();
		$textding{$name} = $text;
#		print "Map $name to text $text\n";
	    }
	}
    }

    return 1;
}

sub applies {
    my $doc = shift;
    my $node = shift;
    my $parent = shift;

    return 0 if $node->getNodeType() != ELEMENT_NODE;
    return 0 if $node->getTagName() ne 'dingbat';
    return 1;
}

sub apply {
    my $doc = shift;
    my $node = shift;
    my $parent = shift;

    my $dingbat = $node->getAttribute('name');

    if ($entityding{$dingbat}) {
	my $entref = $doc->createEntityReference($entityding{$dingbat});
	$parent->insertBefore($entref, $node);
	$parent->removeChild($node);
    } else {
	if (!exists($textding{$dingbat})) {
	    warn "Warning: no dingbat mapping for '$dingbat'\n";
	}
	my $text = $textding{$dingbat} || "???";
	my $textnode = $doc->createTextNode($text);
	$parent->insertBefore($textnode, $node);
	$parent->removeChild($node);
    }
}

'dingbat';
