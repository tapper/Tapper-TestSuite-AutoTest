use Test::More;

use warnings;
use strict;
#use File::Temp qw/ tempdir /;
use Test::Deep;

use_ok('Tapper::TestSuite::AutoTest');

use Log::Log4perl;

# (XXX) need to find a way to include log4perl into tests to make sure
# no errors reported through this framework are missed. Till then we ignore
# the log messages. These are ok.
my $string = "
log4perl.rootLogger                               = FATAL, root
log4perl.appender.root                            = Log::Log4perl::Appender::Screen
log4perl.appender.root.layout                     = SimpleLayout";
Log::Log4perl->init(\$string);


#my $dir = tempdir( CLEANUP => 0 );
my $dir = '/tmp/tapper-testsuite-autotest-mirror/';

my $wrapper = Tapper::TestSuite::AutoTest->new();
isa_ok($wrapper, 'Tapper::TestSuite::AutoTest');
my $args;
@ARGV=('--test', 'first','-t','second','-t','third'); #, '-d', $dir);
$args = $wrapper->parse_args();
cmp_deeply($args, superhashof {
          #'target' => $dir,
          'subtests' => [
                          'first',
                          'second',
                          'third'
                        ]
        }, 'Parse args');

$wrapper->install($args);
ok(-d "$dir/LICENSE", 'Test suite installation');

done_testing();
