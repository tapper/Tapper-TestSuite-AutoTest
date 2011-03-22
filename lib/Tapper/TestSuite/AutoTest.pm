package Tapper::TestSuite::AutoTest;

use warnings;
use strict;
use 5.010;

use Moose;
use Getopt::Long qw/GetOptions/;
use Sys::Hostname qw/hostname/;
use YAML::Syck;
use Archive::Tar;
use IO::Socket::INET;
use File::Slurp qw/slurp/;
use File::Spec::Functions 'tmpdir';

extends 'Tapper::Base';

=head1 NAME

Tapper::TestSuite::AutoTest - Tapper - Complete OS testing in a box via autotest

=cut

our $VERSION = '3.000001';


=head1 SYNOPSIS

This module wraps autotest to make its (sub) tests available for Tapper.

    use Tapper::TestSuite::AutoTest;

    my $wrapper = Tapper::TestSuite::AutoTest->new();
    my $args    = $wrapper->parse_args();
    $args       = $wrapper->install($args);
    $args       = $wrapper->run($args);


=head1 FUNCTIONS


=head2 install

Install the autotest framework from a given source into a given target

@param hash ref - args

@return hash ref - args

=cut

sub install
{
        my ($self, $args) = @_;
        my $error;
        my $output;

        my $target = $args->{target} || tmpdir.'/tapper-testsuite-autotest-mirror/';
        my $source = $args->{source};

        my $downloaddir = "/tmp/";
        $self->makedir($target);

        if (! -d "$target/tests") {
                if ($source =~ m|github.com/.*tarball|) {
                        my $downloadfile = "$downloaddir/autotest-from-github.tgz";
                        if (! -e $downloadfile) {
                                ($error, $output) = $self->log_and_exec('wget', "--no-check-certificate",
                                                                        $source, "-O", $downloadfile);
                                die $output if $error;
                        }
                        ($error, $output) = $self->log_and_exec("tar",
                                                                "-xzf", $downloadfile,
                                                                "-C", $downloaddir);
                        die $output if $error;
                        ($error, $output) = $self->log_and_exec("rsync",
                                                                "-a",
                                                                "$downloaddir/*-autotest-*/client/",
                                                                "$target/");
                        die $output if $error;
                }
         }

        return $args;
}


=head2 report_away

Send the actual report to reports receiver framework.

@param hash ref - args

@return success - int - report id
@return error   - die()

=cut

sub report_away
{
        my ($self, $args) = @_;
        my $result_dir   = $args->{result_dir};
        my $gzipped_content = slurp("$result_dir/tap.tar.gz");

        my $sock = IO::Socket::INET->new(PeerAddr => $args->{report_server},
                                         PeerPort => $args->{report_port},
                                         Proto    => 'tcp');
        unless ($sock) { die "Can't open connection to ", $args->{report_server}, ":$!" }

        my $report_id = <$sock>;
        ($report_id) = $report_id =~ /(\d+)$/;
        $sock->print($gzipped_content);
        $sock->close();
        return $report_id;
}

=head2 upload_stats

Upload the stats file to reports framework.

@param int       - report id
@param hash ref - args

=cut

sub upload_stats
{
        my ($self, $report_id, $args) = @_;

        my $host = $args->{reportserver};
        my $port = $args->{reportport};

        my $file    = $args->{result_dir}."/status";
        my $cmdline = "#! upload $report_id status plain\n";
        my $content = slurp($file);


        my $sock = IO::Socket::INET->new(PeerAddr => $args->{report_server},
                                         PeerPort => $args->{report_api_port},
                                         Proto    => 'tcp');
        unless ($sock) { die "Can't open connection to ", $args->{report_server}, ":$!" }

        $sock->print($cmdline);
        $sock->print($content);
        $sock->close();

        return;
}

=head2 send_results

Send the test results to Tapper.

@param hash ref - args

@return hash ref - args

=cut

sub send_results
{
        my ($self, $test, $args) = @_;
        my $report;


        my $tar             = Archive::Tar->new;
        $args->{result_dir} = $args->{target}."/results/default/";
        my $result_dir      = $args->{result_dir};
        my $hostname        = hostname();
        my $testrun_id      = $args->{testrun_id};

        my $report_group    = $args->{report_group};

        my $report_meta = "
          Version 13
            1..1
              # Tapper-Suite-Name: Autotest-$test
              # Tapper-Machine-Name: $hostname
              # Tapper-Suite-Version: $VERSION
              ok 1 - Tapper metainfo
                ";
        $report_meta .= $testrun_id   ? "# Tapper-Reportgroup-Testrun: $testrun_id\n"     : '';
                $report_meta .= $report_group ? "# Tapper-Reportgroup-Arbitrary: $report_group\n" : '';

                my $meta = YAML::Syck::LoadFile("$result_dir/meta.yml");
                push @{$meta->{file_order}}, 'tapper-suite-meta.tap';
                $tar->read("$result_dir/tap.tar.gz");
                $tar->replace_content( 'meta.yml', YAML::Syck::Dump($meta) );
                $tar->add_data('tapper-suite-meta.tap',$report_meta);
                $tar->write("$result_dir/tap.tar.gz", COMPRESS_GZIP);

                my $report_id = $self->report_away($args);
                $self->upload_stats($report_id, $args);
                return $args;
        }


=head2 print_help

Print help and die.

=cut

sub print_help
{
        my ($self) = @_;
        say "$0 --test=s@ [ --directory=s ] [--remote-name]";
        say "\t--test|t\t\tName of a subtest, REQUIRED, may be given multple times";
        say "\t--directory|d\t\tDirectory to copy autotest to";
        say "\t--source_url|s\t\tURL to get autotest from";
        say "\t--remote-name|O\t\tPrint out the name of result files";
        say "\t--help|h\t\tPrint this help text and exit";


        exit;
}

=head2 parse_args

Parse command line arguments and Tapper ENV variables.

@return hash ref - args

=cut

sub parse_args
{
        my ($self) = @_;
        my @tests;
        my ($dir, $remote_name, $help, $source);

        GetOptions ("test|t=s"  => \@tests,
                    "directory|d=s" => \$dir,
                    "remote-name|O" => \$remote_name,
                    "source_url|s"  => \$source,
                    "help|h"        => \$help,
                   );
        $self->print_help() if $help;
        if (not @tests) {
                print "No subtest requested provided. Please name at least one subtest you want to run\n\n.";
                $self->print_help();
        }

        my $args = {subtests        => \@tests,
                    target          => $dir,
                    source          => $source || 'http://github.com/renormalist/autotest/tarball/master',
                    report_server   => $ENV{TAPPER_REPORT_SERVER}   || 'tapper',
                    report_api_port => $ENV{TAPPER_REPORT_API_PORT} || 7358,
                    report_port     => $ENV{TAPPER_REPORT_PORT}     || 7357,
                    testrun_id      => $ENV{TAPPER_TESTRUN}         || '',
                    report_group    => $ENV{TAPPER_REPORT_GROUP}    || '',
                    remote_name     => $remote_name,
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
                $self->send_results($test, $args);
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

L<http://annocpan.org/dist/Tapper-TestSuite-AutoTest>

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

1; # End of Tapper::TestSuite::AutoTest
