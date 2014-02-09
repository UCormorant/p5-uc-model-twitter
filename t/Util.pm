package t::Util;

use 5.014;
use warnings;
use utf8;

use File::Basename qw(dirname basename);
use File::Spec::Functions qw(catdir catfile);
use lib catdir(dirname(__FILE__), '..', 'lib');

use autodie;
use DBI;
use JSON::PP qw();
use File::Temp qw(tempdir);
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
                $MYSQLD = Test::mysqld->new(my_cnf => +{
                    'skip-networking' => '',
                });
                warn $Test::mysqld::errstr unless $MYSQLD;
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

    DBI->connect($dsn,undef,undef,+{RaiseError => 1, PrintError => 0, AutoCommit => 1});
}

sub setup_sqlite_dbh {
    shift;
    my $file = shift || ':memory:';
    DBI->connect('dbi:SQLite:'.$file,undef,undef,+{RaiseError => 1, PrintError => 0, AutoCommit => 1});
}

sub open_json_file {
    shift;
    my ($file, $abs) = @_;
    $file = catfile(dirname(__FILE__), $file) if not $abs;
    $JSON->decode(do { local $/; open my $fh, '<:utf8', $file; $fh->getline; });
}

sub slurp {
    shift;
    my ($file, $abs) = @_;
    $file = catfile(dirname(__FILE__), $file) if not $abs;
    local $/;
    open my($fh), '<:encoding(utf8)', $file;
    my $line = <$fh>;
    close $fh;
    $line;
}

sub store {
    shift;
    my ($file, $data, $abs) = @_;
    $file = catfile(dirname(__FILE__), $file) if not $abs;
    open my($fh), '>:encoding(utf8)', $file;
    print $fh $data;
    close $fh;
}

sub tempfolder {
    shift;
    tempdir(CLEANUP => 1);
}

1;
