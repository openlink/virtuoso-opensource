# -*- Perl -*-
# This is a chunk.pl library file

package removexmlns;

use XML::DOM;

sub init {
    return 1;
}

sub applies {
    my $doc = shift;
    my $node = shift;
    my $parent = shift;

    return ($node->getNodeType() == ELEMENT_NODE);
}

sub apply {
    my $doc = shift;
    my $node = shift;
    my $parent = shift;

    my $attlist = $node->getAttributes();
    for (my $count = 0; $count < $attlist->getLength(); $count++) {
	my $attr = $attlist->item($count);
	if ($attr->getName() eq 'xmlns'
	    || $attr->getName() =~ /^xmlns:/) {
	    $node->removeAttribute($attr->getName());
	}
    }
}

'removexmlns';

