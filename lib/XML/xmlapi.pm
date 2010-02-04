package XML::xmlapi;

use warnings;
use strict;
use XML::Parser;

=head1 NAME

XML::xmlapi - The xmlapi was an expat wrapper library I wrote in 2000 in ANSI C; this is its Perl port.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

The xmlapi loads an XML file or string into a hash structure, and provides a lot of very C-like functions to access it.


    use XML::xmlapi;

    my $foo = XML::xmlapi->new();
    ...

=head1 BUILDING AND LOADING XML

Before manipulating XML, you have to have the structure.  These functions let you build that.

=head2 new($tag), create($tag)
These are synonomous.  At the moment, they just take the XML tag of the parent.
=cut

sub new { $_[0]->create($_[1]); }
sub create {
   my ($class, $name) = @_;
   
   bless ({
      name=>$name,
	  parent=>undef,
	  attrs=>[],
	  attrval=>{},
	  children=>[],
	  elements=>[]}, $class);
}

=head2 createtext($content)
A text element is used for non-tag content.  In <tag>This stuff</tag>, "This stuff" is the non-tag content.
=cut
sub createtext {
   my ($class, $text) = @_;
   
   bless ({
      name=>'',
	  content=>$text}, $class);
}

=head2 createinto ($tag)
Takes an existing xmlapi object and makes it a completely new XML tag.  You probably don't need this (it comes in handy in the parser, though).
=cut
sub createinto {
   my $ret = shift;
   $$ret{name} = shift;
   $$ret{parent} = '';
   $$ret{attrs} = [];
   $$ret{attrval} = {};
   $$ret{children} = [];
   $$ret{elements} = [];

   return $ret;
}

=head2 read($string), parse($string)
Synonomous functions that, given a string containing some XML, build an xmlapi object from it.
=cut
sub read { return parse (@_); }
sub parse {
   my ($whatever, $string) = @_;
   
   my $output = new XML::xmlapi;
   my $parser = XML::Parser->new (
      Handlers => {
	     Start => sub {
            my ($p, $el, %atts) = @_;
            my $elem;
            if ($p->{output}->is_element) {
               $elem = XML::xmlapi->create ($el);
               $p->{output}->append($elem);
            } else {
               $elem = $p->{output};
               $elem->createinto($el);
            }

            foreach my $attr (keys %atts) {
               $elem->set ($attr, $atts{$attr});
            }
            $p->{output} = $elem;
         },
		 End => sub {
		    my ($p, $el) = @_;
            my $parent = $p->{output}->parent;
            if ($parent and $parent->is_element) { $p->{output} = $parent; }
	     },
		 Char => sub {
            my ($p, $str) = @_;
            $p->{output}->append(XML::xmlapi->createtext ($str));
		 }});
   $parser->{output} = $output;
   $parser->parse ($string);
   return $output;
}

=head2 parse_from_file ($file)
Given a filename, loads its contents into an xmlapi structure.
=cut

sub parse_from_file {
   my ($whatever, $file) = @_;
   
   my $output = new XML::xmlapi;
   my $parser = new XML::Parser (
      Handlers => {
	     Start => sub {
            my ($p, $el, %atts) = @_;
            my $elem;
            if ($p->{output}->is_element) {
               $elem = XML::xmlapi->new ($el);
               $p->{output}->append($elem);
            } else {
               $elem = $p->{output};
               $elem->createinto($el);
            }

            foreach my $attr (keys %atts) {
               $elem->set ($attr, $atts{$attr});
            }
            $p->{output} = $elem;
         },
		 End => sub {
		    my ($p, $el) = @_;
            my $parent = $p->{output}->parent;
            if ($parent and $parent->is_element) { $p->{output} = $parent; }
	     },
		 Char => sub {
            my ($p, $str) = @_;
            $p->{output}->append(XML::xmlapi->createtext ($str));
		 }});
   $parser->{output} = $output;
   $parser->parsefile ($file);
   return $output;
}   

=head1 WRITING XML
Once you've got XML structures built, you'll eventually want to write them out somewhere (that's basically the point).  Here
are some methods to do that.
=cut

=head2 string()
Returns a string representation of the XML structure.  Quotes all characters appropriately for XML serialization.
=cut
sub string {
   my $xml = shift;
   return '' unless defined $xml;

   my $ret = '';

   return $xml->escape($$xml{content}) unless $xml->is_element;

   $ret .= "<$$xml{name}";
   foreach (@{$$xml{attrs}}) {
      $ret .= " $_=\"" . $xml->escape(${$$xml{attrval}}{$_}) . "\"";
   }
   if (!@{$$xml{children}}) {
      $ret .= "/>";
   } else {
      $ret .= ">";
      foreach (@{$$xml{children}}) {
         $ret .= $_->string;
      }
      $ret .= "</$$xml{name}>";
   }

   return $ret;
}

=head2 stringcontent()
Same as C<string>, except it doesn't include the enclosing tags; just gives you the content.
=cut

sub stringcontent {
   my $xml = shift;
   my $ret = '';

   return '' unless ref($xml) eq 'HASH';
   return $xml->escape ($$xml{content}) unless $xml->is_element;

   if (@{$$xml{children}}) {
      foreach (@{$$xml{children}}) {
         $ret .= $_->string;
      }
   }

   return $ret;
}

=head2 stringcontenthtml()
This might be a fossil.  The point is to write HTML-ish output given the XML input, but that isn't what's implemented
in this module.
=cut
sub stringcontenthtml { $_[0]->stringcontent->unescape; }

=head2 write($file)
Given a stream or a filename, writes the XML to said stream or file.
=cut
sub write {
   my ($xml, $f) = @_;
   
   my $file;
   if (ref $f eq '') {
      open $file, ">:utf8", $f;
   } else {
      $file = $f;
   }

   if ($$xml{name} eq '') {
      print $file $$xml{content};
      return;
   }

   print $file "<$$xml{name}";
   foreach (@{$$xml{attrs}}) {
      print $file " $_=\"${$$xml{attrval}}{$_}\"";
   }
   if (!@{$$xml{children}}) {
      print $file "/>";
   } else {
      print $file ">";
      foreach (@{$$xml{children}}) {
         $_->write ($file);
      }
      print $file "</$$xml{name}>";
   }
}

=head2 write_UCS2LE ($filename)
Given a filename, opens it with :raw:encoding(UCS-2LE):crlf:utf8 and writes an 0xFEFF byte order marker at the outset.
This is used by TRADOS TTX files, which is why it's here; it might be useful for other things, but if so, I have yet to discover them.
=cut

sub write_UCS2LE {
   my ($xml, $fname) = @_;

   open OUT, ">:raw:encoding(UCS-2LE):crlf:utf8", $fname;
   print OUT "\x{FEFF}";  # This is the byte order marker; Perl would do this for us, apparently, if we hadn't
                          # explicitly specified the UCS-2LE encoding.
   print OUT "<?xml version='1.0'?>\n";
   print OUT $xml->string;
   close OUT;
}

=head1 ATTRIBUTES
In XML, as I'm sure you know, each tag may have any number of attributes.  These functions allow you to set them and get their values.
XML::xmlapi remembers the order of attributes you write, in an attempt to be able to write files in the same way it found them.

=head2 set($attr, $value)
Sets a value for an attribute.
=cut
sub set {
   my $elem = shift;
   my $attr = shift;
   push @{$$elem{attrs}}, $attr if !grep {$_ eq $attr} @{$$elem{attrs}};
   ${$$elem{attrval}}{$attr} = shift;
}

=head2 get($attr), attrval($attr)
Synonomous functions to retrieve an attribute value.
=cut
sub attrval { $_[0]->get($_[1]); }
sub get {
   my ($elem, $attrname) = @_;
   if (!(defined ${$$elem{attrval}}{$attrname})) { return ''; }
   return ${$$elem{attrval}}{$attrname};
}

=head1 STRUCTURE
In addition to attributes, any XML tag may contain an arbitrary list of other tags and non-tag text content.  These methods
expose that stuff.

=head2 elements()
Returns a list of the elements (i.e. tags, not content) under the XML tag you give it.
=cut
sub elements {
   my $elem = shift;
   return () unless $elem->is_element;
   return @{$$elem{elements}};
}

=head2 children()
Returns the list of all children in order, i.e. tags and non-tag text.
=cut
sub children {
   my $elem = shift;
   return () unless $elem->is_element;
   return @{$$elem{children}};
}

=head2 parent()
Returns the parent of the current tag, if there is one.  This allows you to walk around in trees.
=cut
sub parent {
   my ($xml) = @_;
   return ($$xml{parent});
}

=head2 copy()
Makes a copy of a tag that is an independent tree, that is, has no parent.
=cut
sub copy {
   my $orig = shift;

   my $ret = XML::xmlapi->create ($$orig{name});
   foreach (@{$$orig{attrs}}) {
      $ret->set ($_, $orig->attrval ($_));
   }
   foreach (@{$$orig{children}}) {
      $ret->append ($_->copy());
   }

   return $ret;
}

=head2 append ($child), append_pretty ($child)
Adds a newly created tag at the end of the current tag's content list.  Don't do this with a tag that's already in another tree,
or the pointers will no longer match up (the other tree will still think it owns the appended child).

The C<append> method just slaps the tag into the parent; the C<append_pretty> method inserts newlines as needed to ensure that the
resulting XML structure is readable.
=cut
sub append {
   my ($parent, $child) = @_;

   $$child{parent} = $parent;
   push @{${$$child{parent}}{children}}, $child;
   push @{${$$child{parent}}{elements}}, $child if $$child{name} ne '';
}

sub append_pretty {
   my ($parent, $child) = @_;

   unless ($parent->elements) { $parent->append (XML::xmlapi->createtext ("\n")); }
   $parent->append ($child);
   $parent->append (XML::xmlapi->createtext ("\n"));
}

=head2 replace($child)
Given a new child, finds the first existing child with the same name (tag) and replaces that one with the new one.
=cut
sub replace {
   my ($parent, $child) = @_;

   $$child{parent} = $parent;
   foreach (@{$$parent{children}}) {
      if ($$_{name} eq $$child{name}) {
         $_ = $child;
         return;
      }
   }
   $parent->append ($child);
}

=head2 replacecontent($child)
Given a new child, removes all existing children from the current tag and replaces them all with the new child.  In
Perl, should probably take a list, but it doesn't, yet.
=cut
sub replacecontent {
   my ($parent, $child) = @_;
   
   $$child{parent} = $parent;
   $$parent{children} = [];
   $$parent{elements} = [];
   push @{${$$child{parent}}{children}}, $child;
   push @{${$$child{parent}}{elements}}, $child if $$child{name} ne '';
}

=head2 is($name)
Returns true if the tag is named $name.
=cut
sub is {
   my ($elem, $name) = @_;

   return ($$elem{name} eq $name);
}

=head2 is_element()
Returns true if the tag is an element, false if it's content.
=cut
sub is_element {
   my ($elem) = @_;

   my $name;
   eval { $name = $$elem{name}; };
   return 0 if $@;
   return 0 unless defined ($name);
   return 1 if $name ne '';
   return 0;
}

=head2 name()
Returns the current tag's tag.
=cut
sub name { $_[0]{name}; }

=head1 SEARCHING XML TREES
=head2 search ($element, $attribute, $value)
Does a (depth-first) search of the XML structure for an element named $element (if undef, the tag of the element
is ignored in the search) with an attribute $attribute with value $value (those two can also be undef if you don't
care about attributes).

Returns a list of all matches.
=cut
sub search {
   my ($xml, $element, $attr, $val) = @_;
   my @retlist = ();
   foreach my $elem ($xml->elements) {
      if ($elem->is($element)) {
         if (!defined($attr)) {
            push @retlist, $elem;
         } else {
            push @retlist, $elem if $elem->attrval ($attr) eq $val;
         }
      } else {
         push @retlist, $elem->search ($element, $attr, $val);
      }
   }
   return @retlist;
}

=head2 search_first ($element, $attribute, $value)
Does the same as C<search> but returns after finding the first match.
=cut
sub search_first {
   my ($xml, $element, $attr, $val) = @_;
   foreach my $elem ($xml->elements) {
      if ($elem->is($element)) {
         if (!defined ($attr) || !defined ($val)) { # TODO: these semantics seem fishy...
            return $elem;
         } else {
            return $elem if $elem->attrval ($attr) eq $val;
         }
      } else {
         my $ret = $elem->search_first ($element, $attr, $val);
         return $ret if $ret ne '';
      }
   }

   return '';
}

=head2 xmlobj_is_field, xmlobj_field, xmlobj_set, xmlobj_get, xmlobj_getkey
These are fossils right now, left over from extensive C code that I used between 2000 and about 2004.
If I see a need to reimplement them in Perl, I will document them then.  These implementations work, but
I frankly don't remember how well.
=cut
sub xmlobj_is_field {
   my ($xml, $list, $field) = @_;

   my $f = xml_search_first ($xml, $field, undef, undef);
   return $f if $f;
   $f = xml_search_first ($xml, 'field', 'id', $field);
   return $f if $f;

   return undef;
}

sub xmlobj_field {
   my ($xml, $list, $field) = @_;

}

sub xmlobj_set {
   my ($xml, $list, $field, $val) = @_;

}

sub xmlobj_get {
   my ($xml, $list, $field) = @_;

   my $fld = xmlobj_is_field ($xml, $list, $field);
   if (!defined ($fld)) { return ''; }
   my $val = xml_attrval ($fld, "value");
   return $val unless defined($val) && $val eq '';
   return xml_stringcontenthtml ($fld);
}

sub xmlobj_getkey {
   my ($xml, $list) = @_;

   return '';
}

=head2 escape($string), unescape($string)
XML-escape and unescape the string you give them.  Can also be called as a class method.
=cut
sub escape {
   my ($whatever, $str) = @_;

   $str =~ s/&/&amp;/g;
   $str =~ s/</&lt;/g;
   $str =~ s/>/&gt;/g;
   $str =~ s/\"/&quot;/g;
   return $str;
}
sub unescape {
   my ($whatever, $ret) = @_;
   
   $ret =~ s/&lt;/</g;
   $ret =~ s/&gt;/>/g;
   $ret =~ s/&quot;/"/g;
   $ret =~ s/&amp;/&/g;
   return $ret;
}



=head1 AUTHOR

Michael Roberts, C<< <michael at vivtek.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-xml-xmlapi at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=XML-xmlapi>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc XML::xmlapi


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=XML-xmlapi>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/XML-xmlapi>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/XML-xmlapi>

=item * Search CPAN

L<http://search.cpan.org/dist/XML-xmlapi/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2010 Michael Roberts.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of XML::xmlapi
