#!/usr/local/bin/perl

use 5.014;
use lib qw(lib ../example);
use lib::Utils;
use autodie;

use Benchmark qw(:all);

use Uc::Model::Twitter;
use Uc::Twitter::Schema;
use Getopt::Long;
use Config::Pit;

local $| = 1;

my ( $collect, $sqlite_db, $mysql_db, $help ) = ('') x 4;
my $result = GetOptions(
    "c|collect=i"       => \$collect,
    "sqlite-database=s" => \$sqlite_db,
    "mysql-database=s"  => \$mysql_db,
    "h|help|?"          => \$help,
);
$collect = 500 if !$collect or $collect/10 < 1;

say <<"_HELP_" and exit if scalar(@ARGV) < 2;
Usage: $0 -c 20 username password
    -c --collect:         tweet cllection count(min 10) default 500
       --sqlite-database: default ':memory:'
       --mysql-database:  default 'test'
_HELP_

my $my_conf = pit_get('mysql', require => {
    user => '',
    pass => '',
}) or die "pit_get('mysql') is failed";
my $dbh_sqlite = setup_dbh('SQLite',$sqlite_db) or die "dbh_sqlite connect error";
my $dbh_mysql  = setup_dbh('mysql',$mysql_db,$my_conf->{user},$my_conf->{pass}) or die "dbh_mysql connect error";

my $tweets = sample_stream($ARGV[0], $ARGV[1], $collect);

my ($umt_schema_sqlite, $umt_schema_mysql);
print "create table with SQLite... ";
$umt_schema_sqlite = Uc::Model::Twitter->new( dbh => $dbh_sqlite );
$umt_schema_sqlite->create_table();
say "done.";
print "create table with MySQL... ";
$umt_schema_mysql  = Uc::Model::Twitter->new( dbh => $dbh_mysql  );
$umt_schema_mysql->create_table();
say "done.";

cmpthese(timethese(1, {
    sq_not_txn => get_these_sqlite('dynamic',     \&bench_dynamic),
    sq_single  => get_these_sqlite('single',      \&bench_single),
    sq_inst    => get_these_sqlite('installment', \&bench_installment),

    my_not_txn => get_these_mysql( 'dynamic',     \&bench_dynamic),
    my_single  => get_these_mysql( 'single',      \&bench_single),
    my_inst    => get_these_mysql( 'installment', \&bench_installment),
}));

exit;

sub get_these_sqlite {
    my ($plan, $bench) = @_;
    return sub {
        say "";
        say "SQLite bencmark $plan: db=".$dbh_sqlite->{Name};

        my $t_sqlite = $bench->($dbh_sqlite);

        say "Uc::Model::Twitter ->SQLite took: ".timestr($t_sqlite->{umt});
        say "Uc::Twitter::Schema->SQLite took: ".timestr($t_sqlite->{uts});
        say "";
    };
}

sub get_these_mysql {
    my ($plan, $bench) = @_;
    return sub {
        say "";
        say "MySQL bencmark $plan: db=".$dbh_mysql->{Name};

        my $t_mysql = $bench->($dbh_mysql);

        say "Uc::Model::Twitter ->MySQL took: ".timestr($t_mysql->{umt});
        say "Uc::Twitter::Schema->MySQL took: ".timestr($t_mysql->{uts});
        say "";
    };
}

sub bench_dynamic {
    my $dbh = shift;
    my $umt_schema = Uc::Model::Twitter->new( dbh => $dbh );
    my $uts_schema = Uc::Twitter::Schema->connect( sub{ $dbh } );

    bench($umt_schema, $uts_schema, {
        umt => sub {
            my $class = shift;
            timeit(1, sub {
                $class->find_or_create_status_from_tweet($_) for @$tweets;
            });
        },
        uts => sub {
            my $class = shift;
            timeit(1, sub {
                $class->resultset('Status')->find_or_create_from_tweet($_) for @$tweets;
            });
        },
    });
}

sub bench_single {
    my $dbh = shift;
    my $umt_schema = Uc::Model::Twitter->new( dbh => $dbh );
    my $uts_schema = Uc::Twitter::Schema->connect( sub{ $dbh } );

    bench($umt_schema, $uts_schema, {
        umt => sub {
            my $class = shift;
            timeit(1, sub {
                my $txn = $class->txn_scope;
                $class->find_or_create_status_from_tweet($_) for @$tweets;
                $txn->commit;
            });
        },
        uts => sub {
            my $class = shift;
            timeit(1, sub {
                $class->txn_do(sub {
                    $class->resultset('Status')->find_or_create_from_tweet($_) for @$tweets;
                });
            });
        },
    });
}

sub bench_installment {
    my $dbh = shift;
    my $umt_schema = Uc::Model::Twitter->new( dbh => $dbh );
    my $uts_schema = Uc::Twitter::Schema->connect( sub{ $dbh } );

    bench($umt_schema, $uts_schema, {
        umt => sub {
            my $class = shift;
            my $index = 0;
            my $time  = $collect/10;
            my $step  = $collect/$time;
            timeit($time, sub {
                my $txn = $class->txn_scope;
                $class->find_or_create_status_from_tweet(@{$tweets}[$_]) for $index..$index+$step-1;
                $txn->commit;
                $index += $step;
            });
        },
        uts => sub {
            my $class = shift;
            my $index = 0;
            my $time  = $collect/10;
            my $step  = $collect/$time;
            timeit($time, sub {
                $class->txn_do(sub {
                    $class->resultset('Status')->find_or_create_from_tweet(@{$tweets}[$_]) for $index..$index+$step-1;
                    $index += $step;
                });
            });
        },
    });
}

sub bench {
    my ($umt_schema, $uts_schema, $subs) = @_;
    my ($t_umt_schema, $t_uts_schema);

    $t_uts_schema = $subs->{uts}($uts_schema);

    $umt_schema->delete('status');
    $umt_schema->delete('remark');
    $umt_schema->delete('user');
    $umt_schema->delete('profile_image');

    $t_umt_schema = $subs->{umt}($umt_schema);

    $umt_schema->delete('status');
    $umt_schema->delete('remark');
    $umt_schema->delete('user');
    $umt_schema->delete('profile_image');

    return { umt => $t_umt_schema, uts => $t_uts_schema };
}

1;
