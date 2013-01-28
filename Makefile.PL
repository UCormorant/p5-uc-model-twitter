use strict;
use warnings;

# plagiarized by http://unknownplace.org/memo/2012/08/31/1/
BEGIN {
    my @devmods = qw(
        Module::Install::AuthorTests
        Module::Install::ReadmeMarkdownFromPod
        Module::Install::Repository
    );
    my @not_available;

    {
        select my $LOCALOUT;
        # use inc::Module::Install 0.69; # for configure_requires
        eval qq{use inc::Module::Install 0.69; 1;} or push @not_available, 'inc::Module::Install';
        select STDOUT;
    }

    for my $mod (@devmods) {
        eval qq{require $mod} or push @not_available, $mod;
    }
    if (@not_available) {
        print qq{# The following modules are not available.\n};
        print qq{# `$^X $0 | cpanm` will install them:\n};
        print $_, "\n" for @not_available;
        print "\n";
        exit -1;
    }
}

name 'Uc-Model-Twitter';
reference_module 'lib/Uc/Model/Twitter.pm';
auto_set_repository;

test_requires 'Test::More' => '0.94'; # for subtest

requires 'Teng';
requires 'Uc::Teng::Plugin' => '1.000';
requires 'DateTime::Format::MySQL';
requires 'DateTime::Format::HTTP';

tests_recursive;
recursive_author_tests 'xt';

WriteAll;
