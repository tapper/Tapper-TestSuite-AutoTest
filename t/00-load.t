#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Tapper::TestSuite::AutoTest' );
}

diag( "Testing Tapper::TestSuite::AutoTest $Tapper::TestSuite::AutoTest::VERSION, Perl $], $^X" );
