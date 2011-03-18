package Tapper::TestSuite::AutoTest;

use warnings;
use strict;

use Moose;
use Getopt::Long qw/GetOptions/;
use File::ShareDir 'module_dir';
use Sys::Hostname qw/hostname/;
use YAML::Syck;
use Archive::Tar;
use IO::Socket::INET;


extends 'Tapper::Base';

=head1 NAME

TestSuite::AutoTestWrapper - Wrap autotest for reporting in Tapper!

=cut

our $VERSION = '3.000001';


=head1 SYNOPSIS

This module wraps autotest to make its (sub) tests available for Tapper.

    use TestSuite::AutoTestWrapper;

    my $wrapper = TestSuite::AutoTestWrapper->new();
    my $args    = $wrapper->parse_args();
    $args       = $wrapper->install($args);
    $args       = $wrapper->run($args);
    $args       = $wrapper->send_results($args);


=head1 FUNCTIONS


=head2 install

Install the autotest framework into the given targe

@param hash ref - args

@return hash ref - args

=cut

sub install
{
        my ($self, $args) = @_;
        $args->{target} = '/usr/local/' if not $args->{target};
        my $target = $args->{target};

        $self->makedir($target);
        my ($error) = $self->log_and_exec("cp","-r",module_dir(__PACKAGE__)."/autotest", $target);
        $args->{target} .= '/autotest';
        return $args;
}


=head2 send_results

Send the test results to Tapper.

@param hash ref - args

@return hash ref - args

=cut

sub send_results
{
        my ($self, $args) = @_;
        my $report;


        my $tar  = Archive::Tar->new;
        my $result_dir = $args->{target}."/results/default/";
        my $hostname = hostname();
        my $report_meta = "
Version 13
1..1
# Tapper-Suite-Name: Tapper-TestSuite-AutoTest
# Tapper-Machine-Name: $hostname
# Tapper-Suite-Version: 3.000001
ok 1 - Getting hardware information
";

        my $meta = YAML::Syck::LoadFile("$result_dir/meta.yml");
        push @{$meta->{file_order}}, 'tapper-suite-meta.tap';
        $tar->read("$result_dir/tap.tar.gz");
        $tar->replace_content( 'meta.yml', YAML::Syck::Dump($meta) );
        $tar->add_data('tapper-suite-meta.tap',$report_meta);
        $tar->write("$result_dir/tap.tar.gz", COMPRESS_GZIP);

        my $gzipped_content;
        {
                open my $fh, "<", "$result_dir/tap.tar.gz";
                local $/;
                $gzipped_content = <$fh>;
                close $fh;
        }


        my $sock = IO::Socket::INET->new(PeerAddr => $args->{report_server},
                                         PeerPort => $args->{report_port},
                                         Proto    => 'tcp');
        unless ($sock) { die "Can't open connection to ", $args->{report_server}, ":$!" }

        $sock->print($gzipped_content);
        $sock->close();
        return $args;
}

=head2 parse_args

Parse command line arguments and Tapper ENV variables.

@return hash ref - args

=cut

sub parse_args
{
        my ($self) = @_;
        my @tests;
        my $dir;
        GetOptions ("test|t=s"  => \@tests,
                    "directory|d=s" => \$dir,
                   );



        my $args = {subtests        => \@tests,
                    target          => $dir,
                    report_server   => $ENV{TAPPER_REPORT_SERVER}   || 'tapper',
                    report_api_port => $ENV{TAPPER_REPORT_API_PORT} || 7358,
                    report_port     => $ENV{TAPPER_REPORT_PORT}     || 7357,
                   };

        return $args;

}


=head2 run

Run the requested autotest test(s), collect their results and report
them.

@param hash ref - args

@return hash ref - args

=cut

sub run
{
        my ($self, $args) = @_;
        my $target = $args->{target};
        my $autotest = "$target/bin/autotest";

        foreach my $test (@{$args->{subtests} || [] }) {
                my $test_path = "$target/tests/$test/control";
                $self->log_and_exec($autotest, "--tap", $test_path);
        }
        return $args;
}



=head1 BUGS

Please report any bugs or feature requests to C<bug-tapper-testsuite-autotest at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Tapper-TestSuite-AutoTest>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Tapper::TestSuite::AutoTest


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Tapper-TestSuite-AutoTest>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/TestSuite-AutoTestWrapper>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Tapper-TestSuite-AutoTest>

=item * Search CPAN

L<http://search.cpan.org/dist/Tapper-TestSuite-AutoTest/>

=back


=head1 AUTHOR

AMD OSRC Tapper Team, C<< <tapper at amd64.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008-2011 AMD OSRC Tapper Team, all rights reserved.

This program is released under the following license: freebsd


=cut

1; # End of TestSuite::AutoTestWrapper
