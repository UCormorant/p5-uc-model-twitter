package t::Utils;

use 5.014;
use warnings;
use utf8;
use lib __FILE__."/../lib";
use autodie;
use JSON::PP;
use Clone;

our $mysqld;

sub import {
    strict->import;
    warnings->import;
    utf8->import;
}

sub clone { shift; Clone::clone(shift); }

sub setup_mysql_dbh {
    my $self = shift;
    my $db = shift || 'test';
    my $dsn = '';
    my ($user, $pass) = '' x 2;
    eval "use Test::MyApp::mysqld";
    unless ($@) {
        $SIG{INT} = sub { CORE::exit 1 };
        $mysqld = Test::MyApp::mysqld->setup;
        $ENV{TEST_MYSQLD} = encode_json +{ %$mysqld };
        $dsn = $mysqld->dsn;
    }
    else {
        eval "use DBD::mysql";
        die $@ if $@;
        my $mysql_conf = $self->open_json_file('t/mysql_conf.json');
        $dsn = 'dbi:mysql:test';
        ($user, $pass) = @{$mysql_conf}{qw(user pass)};
    }

    DBI->connect($dsn,$user,$pass,{RaiseError => 1, PrintError => 0, AutoCommit => 1});
}

sub setup_sqlite_dbh {
    shift;
    my $file = shift || ':memory:';
    DBI->connect('dbi:SQLite:'.$file,,,{RaiseError => 1, PrintError => 0, AutoCommit => 1});
}

our $JSON;
sub open_json_file {
    shift;
    $JSON //= JSON::PP->new->utf8->allow_bignum;
    $JSON->decode(do { local $/; open my $fh, '<:utf8', shift; $fh->getline; });
}

1;
