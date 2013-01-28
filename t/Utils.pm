package t::Utils;

use 5.014;
use warnings;
use utf8;
use autodie;
use JSON::PP;
use Clone;

sub import {
    strict->import;
    warnings->import;
    utf8->import;
}

sub clone { shift; Clone::clone(shift); }

sub setup_mysql_dbh {
    my $self = shift;
    my $db = shift || 'test';
    my $mysql_conf = $self->open_json_file('t/mysql_conf.json');
    DBI->connect('dbi:mysql:'.$db,$mysql_conf->{user},$mysql_conf->{pass},{RaiseError => 1, PrintError => 0, AutoCommit => 1});
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
