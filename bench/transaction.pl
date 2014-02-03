#!/usr/bin/env perl

use 5.014;
use File::Basename qw(dirname basename);
use File::Spec::Functions qw(catfile catdir);
use lib catdir(dirname(__FILE__), 'lib');
use lib catdir(dirname(__FILE__), '..', 'lib');
use lib catdir(dirname(__FILE__), '..', 'examples');

use lib::Util;

use autodie;
use Config::Pit qw(pit_get);
use Benchmark qw(:all :hireswallclock);

use Uc::Model::Twitter;
use Uc::Twitter::Schema;

local $| = 1;
my $collect = scalar @ARGV ? shift : undef;
   $collect = 500 if !$collect or $collect < 1;
my $conf_app  = pit_get('dev.twitter.com', require =>{
    consumer_key    => 'your twitter consumer_key',
    consumer_secret => 'your twitter consumer_secret',
});
my $conf_user = +{};
twitter_agent($conf_app, $conf_user);

my $sqlite_db = sprintf "%s.sqlite", basename(__FILE__) =~ s/\.\w+$//r;
   $sqlite_db = catfile(dirname(__FILE__), $sqlite_db);
#my $sqlite_db = undef;
my $mysql_db  = undef;
my $dbh_sqlite = setup_dbh('SQLite',$sqlite_db) or die "dbh_sqlite connect error";
my $dbh_mysql  = setup_dbh('mysql',$mysql_db) or die "dbh_mysql connect error";

my $tweets = sample_stream({
    consumer_key    => $conf_app->{consumer_key},
    consumer_secret => $conf_app->{consumer_secret},
    token           => $conf_user->{token},
    token_secret    => $conf_user->{token_secret},
}, $collect);

my ($umt_schema_sqlite, $umt_schema_mysql);
print "create table with SQLite... ";
$umt_schema_sqlite = Uc::Model::Twitter->new( dbh => $dbh_sqlite );
$umt_schema_sqlite->create_table(if_not_exists => 0);
say "done.";
print "create table with MySQL... ";
$umt_schema_mysql  = Uc::Model::Twitter->new( dbh => $dbh_mysql  );
$umt_schema_mysql->create_table(if_not_exists => 0);
say "done.";

undef $umt_schema_sqlite;
undef $umt_schema_mysql;

cmpthese(1 => {
    sq_not_txn => get_these_sqlite('dynamic',     \&bench_dynamic),
    sq_single  => get_these_sqlite('single',      \&bench_single),
    sq_inst    => get_these_sqlite('installment', \&bench_installment),

    my_not_txn => get_these_mysql( 'dynamic',     \&bench_dynamic),
    my_single  => get_these_mysql( 'single',      \&bench_single),
    my_inst    => get_these_mysql( 'installment', \&bench_installment),
}, 'auto');

END {
    undef $dbh_sqlite;
    undef $dbh_mysql;
    unlink $sqlite_db if -e $sqlite_db;
}

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
                $class->find_or_create_status($_) for @$tweets;
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
                $class->find_or_create_status($_) for @$tweets;
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
                $class->find_or_create_status(@{$tweets}[$_]) for $index..$index+$step-1;
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

__END__
streamer starts to read... connected.
collect 500 tweets... done.
create table with SQLite... done.
create table with MySQL... done.
Benchmark: timing 1 iterations of my_inst, my_not_txn, my_single, sq_inst, sq_not_txn, sq_single...

MySQL bencmark installment: db=test
Uc::Model::Twitter ->MySQL took: 19.2526 wallclock secs ( 8.06 usr +  0.53 sys =  8.59 CPU) @  5.82/s (n=50)
Uc::Twitter::Schema->MySQL took: 22.6301 wallclock secs (11.98 usr +  0.30 sys = 12.28 CPU) @  4.07/s (n=50)

   my_inst: 42.6189 wallclock secs (20.27 usr +  0.92 sys = 21.19 CPU) @  0.05/s (n=1)
            (warning: too few iterations for a reliable count)

MySQL bencmark dynamic: db=test
Uc::Model::Twitter ->MySQL took: 78.1256 wallclock secs ( 9.03 usr +  0.56 sys =  9.59 CPU) @  0.10/s (n=1)
Uc::Twitter::Schema->MySQL took: 79.041 wallclock secs (13.17 usr +  0.39 sys = 13.56 CPU) @  0.07/s (n=1)

my_not_txn: 157.874 wallclock secs (22.28 usr +  1.00 sys = 23.27 CPU) @  0.04/s (n=1)
            (warning: too few iterations for a reliable count)

MySQL bencmark single: db=test
Uc::Model::Twitter ->MySQL took: 16.4151 wallclock secs ( 7.96 usr +  0.50 sys =  8.45 CPU) @  0.12/s (n=1)
Uc::Twitter::Schema->MySQL took: 19.1812 wallclock secs (12.04 usr +  0.41 sys = 12.45 CPU) @  0.08/s (n=1)

 my_single: 36.0674 wallclock secs (20.06 usr +  0.92 sys = 20.98 CPU) @  0.05/s (n=1)
            (warning: too few iterations for a reliable count)

SQLite bencmark installment: db=bench\transaction.sqlite
Uc::Model::Twitter ->SQLite took: 37.064 wallclock secs ( 8.70 usr +  1.23 sys =  9.94 CPU) @  5.03/s (n=50)
Uc::Twitter::Schema->SQLite took: 36.7976 wallclock secs (12.34 usr +  0.39 sys = 12.73 CPU) @  3.93/s (n=50)

   sq_inst: 77.4699 wallclock secs (21.11 usr +  1.67 sys = 22.78 CPU) @  0.04/s (n=1)
            (warning: too few iterations for a reliable count)

SQLite bencmark dynamic: db=bench\transaction.sqlite
Uc::Model::Twitter ->SQLite took: 277.368 wallclock secs ( 9.48 usr +  5.18 sys = 14.66 CPU) @  0.07/s (n=1)
Uc::Twitter::Schema->SQLite took: 337.063 wallclock secs (13.85 usr +  5.15 sys = 19.00 CPU) @  0.05/s (n=1)

sq_not_txn: 616.626 wallclock secs (23.40 usr + 10.44 sys = 33.84 CPU) @  0.03/s (n=1)
            (warning: too few iterations for a reliable count)

SQLite bencmark single: db=bench\transaction.sqlite
Uc::Model::Twitter ->SQLite took: 10.7012 wallclock secs ( 8.84 usr +  0.87 sys =  9.72 CPU) @  0.10/s (n=1)
Uc::Twitter::Schema->SQLite took: 13.0361 wallclock secs (11.42 usr +  0.06 sys = 11.48 CPU) @  0.09/s (n=1)

 sq_single: 24.9558 wallclock secs (20.33 usr +  1.04 sys = 21.37 CPU) @  0.05/s (n=1)
            (warning: too few iterations for a reliable count)
           s/iter sq_not_txn my_not_txn    sq_inst sq_single   my_inst my_single
sq_not_txn   33.8         --       -31%       -33%      -37%      -37%      -38%
my_not_txn   23.3        45%         --        -2%       -8%       -9%      -10%
sq_inst      22.8        49%         2%         --       -6%       -7%       -8%
sq_single    21.4        58%         9%         7%        --       -1%       -2%
my_inst      21.2        60%        10%         8%        1%        --       -1%
my_single    21.0        61%        11%         9%        2%        1%        --
