#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'XML::xmlapi' ) || print "Bail out!
";
}

diag( "Testing XML::xmlapi $XML::xmlapi::VERSION, Perl $], $^X" );
