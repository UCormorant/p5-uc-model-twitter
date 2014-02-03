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
my $query   = scalar @ARGV ? shift : undef;
   $collect = 200    if !$collect or $collect < 1;
   $query   = '%I %' if !$query;
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

insert_tweets($umt_schema_sqlite);
insert_tweets($umt_schema_mysql);

$umt_schema_sqlite->search('status', { text => { like => $query } })->next or die "'$query' is not found";

undef $umt_schema_sqlite;
undef $umt_schema_mysql;

cmpthese(5 => {
    umt_sch_sq => get_these_umt($dbh_sqlite),
    umt_sch_my => get_these_umt($dbh_mysql),

    uts_sch_sq => get_these_uts($dbh_sqlite),
    uts_sch_my => get_these_uts($dbh_mysql),
}, 'auto');

END {
    undef $dbh_sqlite;
    undef $dbh_mysql;
    unlink $sqlite_db if -e $sqlite_db;
}

exit;

sub insert_tweets {
    my $umt_schema = shift;

    print $umt_schema->dbh->{Driver}{Name}." insert... ";
    my $txn = $umt_schema->txn_scope;
    $umt_schema->find_or_create_status($_) for @$tweets;
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

__END__
streamer starts to read... connected.
collect 200 tweets... done.
create table with SQLite... done.
create table with MySQL... done.
SQLite insert... done.
mysql insert... done.
Benchmark: timing 5 iterations of umt_sch_my, umt_sch_sq, uts_sch_my, uts_sch_sq...
umt_sch_my: 4.11039 wallclock secs ( 2.04 usr +  0.17 sys =  2.22 CPU) @  2.26/s (n=5)
umt_sch_sq: 2.36982 wallclock secs ( 1.95 usr +  0.36 sys =  2.31 CPU) @  2.17/s (n=5)
uts_sch_my: 3.51076 wallclock secs ( 2.59 usr +  0.05 sys =  2.64 CPU) @  1.90/s (n=5)
uts_sch_sq: 2.52695 wallclock secs ( 2.34 usr +  0.03 sys =  2.37 CPU) @  2.11/s (n=5)
             Rate uts_sch_my uts_sch_sq umt_sch_sq umt_sch_my
uts_sch_my 1.90/s         --       -10%       -12%       -16%
uts_sch_sq 2.11/s        11%         --        -3%        -7%
umt_sch_sq 2.17/s        14%         3%         --        -4%
umt_sch_my 2.26/s        19%         7%         4%         --
