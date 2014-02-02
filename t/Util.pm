package t::Util;

use 5.014;
use warnings;
use utf8;

use File::Basename qw(dirname);
use File::Spec::Functions qw(catdir);
use lib catdir(dirname(__FILE__), '..', 'lib');

use autodie;
use JSON::PP qw();
use Storable qw(dclone);

my $MYSQLD;
my $JSON = JSON::PP->new->utf8->allow_bignum;

sub import {
    strict->import;
    warnings->import;
    utf8->import;
}

sub clone { shift; dclone(shift); }

sub setup_mysql_dbh {
    shift;
    my $db = shift || 'test';
    my $dsn = '';
    eval "use Test::mysqld";
    unless ($@) {
        $SIG{INT} = sub { CORE::exit 1 };
        if (not defined $MYSQLD) {
            if (my $json = $ENV{TEST_MYSQLD}) {
                my $obj = $JSON->decode($json);
                $MYSQLD = bless $obj, 'Test::mysqld';
            }
            else {
                $MYSQLD = Test::mysqld->new(my_cnf => {
                    'skip-networking' => '',
                });
                warn $Test::mysqld::errstr;
            }
        }
        if ($MYSQLD) {
            $ENV{TEST_MYSQLD} = $JSON->encode(+{ %$MYSQLD });
            $dsn = $MYSQLD->dsn;
        }
    }
    if (!$dsn) {
        eval "use DBD::mysql";
        die $@ if $@;
        $dsn = 'dbi:mysql:test';
    }

    DBI->connect($dsn,undef,undef,{RaiseError => 1, PrintError => 0, AutoCommit => 1});
}

sub setup_sqlite_dbh {
    shift;
    my $file = shift || ':memory:';
    DBI->connect('dbi:SQLite:'.$file,undef,undef,{RaiseError => 1, PrintError => 0, AutoCommit => 1});
}

sub open_json_file {
    shift;
    $JSON->decode(do { local $/; open my $fh, '<:utf8', shift; $fh->getline; });
}

1;
