use inc::Module::Install;

name     'Tapper-TestSuite-AutoTest';
all_from 'lib/Tapper/TestSuite/AutoTest.pm';
author   'AMD OSRC Tapper Team <tapper@amd64.org>';
license  'freebsd';


build_requires 'Test::More';
build_requires 'File::Temp';
build_requires 'Test::Deep';

requires 'Moose';
requires 'Getopt::Long';
requires 'File::ShareDir';
requires 'File::Spec::Functions';
requires 'Tapper::Base';
requires 'Sys::Hostname';
requires 'YAML::Syck';
requires 'Archive::Tar';
requires 'IO::Socket::INET';
requires 'File::Slurp';

auto_install;

install_script glob('bin/*');


WriteAll;

