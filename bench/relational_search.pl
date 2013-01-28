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

my ( $collect, $time, $query, $sqlite_db, $mysql_db, $help ) = ('') x 5;
my $result = GetOptions(
    "c|collect=i"       => \$collect,
    "t|time=i"          => \$time,
    "q|query=s"         => \$query,
    "sqlite-database=s" => \$sqlite_db,
    "mysql-database=s"  => \$mysql_db,
    "h|help|?"          => \$help,
);
$collect = 200    if !$collect or $collect < 1;
$time    = 5      if !$time    or $time    < 1;
$query   = '%I %' if !$query;

say <<"_HELP_" and exit if scalar(@ARGV) < 2;
Usage: $0 -c 20 username password
    -c --collect:         tweet cllection count(min 1) default 200
    -t --time:            bench loop times. default 5
    -q --query:           search query. default '%I %'
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
insert_tweets($umt_schema_sqlite);
insert_tweets($umt_schema_mysql);

$umt_schema_sqlite->search('status', { text => { like => $query } })->next or die "'$query' is not found";

cmpthese(timethese($time, {
    umt_sch_sq => get_these_umt($dbh_sqlite),
    umt_sch_my => get_these_umt($dbh_mysql),

    uts_sch_sq => get_these_uts($dbh_sqlite),
    uts_sch_my => get_these_uts($dbh_mysql),
}));

exit;

sub insert_tweets {
    my $umt_schema = shift;

    print $umt_schema->dbh->{Driver}{Name}." insert... ";
    my $txn = $umt_schema->txn_scope;
    $umt_schema->find_or_create_status_from_tweet($_) for @$tweets;
    $txn->commit;
    say "done.";
}

sub get_these_umt {
    my $dbh = shift;
    my $umt_schema = Uc::Model::Twitter->new( dbh => $dbh );
    return sub {
        my $iter = $umt_schema->search('status', { text => { like => $query } });
        while (my $row = $iter->next) {
            $row->user->name;
            $row->user->screen_name;
            $row->user->tweets->next->remarks;
        }
    };
}

sub get_these_uts {
    my $dbh = shift;
    my $uts_schema = Uc::Twitter::Schema->connect( sub { $dbh } );
    return sub {
        my $iter = $uts_schema->resultset('Status')->search({ 'me.text' => { like => $query } }, { prefetch => 'user' });
        while (my $row = $iter->next) {
            $row->user->name;
            $row->user->screen_name;
            $row->user->status->first->remark;
        }
    };
}

1;
