#!/usr/bin/env perl

use 5.014;
use File::Basename qw(dirname basename);
use File::Spec::Functions qw(catdir);
use lib catdir(dirname(__FILE__));
use lib catdir(dirname(__FILE__), '..', 'lib');

use lib::Util;
use Uc::Model::Twitter;

use autodie;
use Getopt::Long;
use Config::Pit;

local $| = 1;

my ( $driver, $database, $or_search, $ignore_retweet, $help ) = ('') x 5;
my ( @text, @name, @screen_name, @status_id, @user_id, @datetime );
my $result = GetOptions(
    "d|driver=s"       => \$driver,
    "db|database=s"    => \$database,
    "h|help|?"         => \$help,

    "t|text=s"         => \@text,
    "n|name=s"         => \@name,
    "sn|screen-name=s" => \@screen_name,
    "date|datetime=s"  => \@datetime,
    "sid|status-id=i"  => \@status_id,
    "uid|user-id=i"    => \@user_id,

    "or-search"        => \$or_search,
    "i|ignore-retweet" => \$ignore_retweet,
);
$driver ||= 'sqlite';

my $defined; $defined ||= scalar @{$_} for \(@text, @name, @screen_name, @datetime, @status_id, @user_id);
say <<"_HELP_" and exit if $help || not $defined;
Usage: $0 -db ./twitter.db --text '%t.co%'
    -d  --driver:   DBI Driver. SQLite or mysql. default driver is 'SQLite'.
    -db --database: Database name. if it is not set, SQLite uses ':memory:' and mysql uses 'test'.

英語がわからなくて死ぬのでここから日本語
    -t    --text:           Tweetから --text にマッチするものを検索。
                            %は0文字以上の任意の文字にマッチ。複数指定でAND検索
          --or-search:      TweetをOR検索にする。
    -i    --ignore-retweet: リツイートを検索対象としない。
    -n    --name:           ユーザの名前を検索。%使用可。複数指定でOR検索。
    -sn   --screen_name:    ユーザのアカウント名。%使用可。 OR検索。
    -date --datetime:       日付(文字列として評価)。%使用可。OR検索。
    -sid  --status-id:      Tweetのstatus id (完全一致) OR検索。
    -uid  --user-id:        ユーザの数値ID (完全一致) OR検索。
_HELP_

my $db_user = '';
my $db_pass = '';
if ($driver eq 'mysql') {
    my $mysql_conf = pit_get($driver, require => {
        user => 'mysql database user',
        pass => 'mysql user password',
    });
    $db_user = $mysql_conf->{user};
    $db_pass = $mysql_conf->{pass};
}

my $schema = Uc::Model::Twitter->new( dbh => setup_dbh($driver, $database, $db_user, $db_pass) );
my $spacer = 0;
my $count  = 0;

my $com_where = sub {
    my $where;
    my ($cond, $and_search) = @_;
    if ($and_search) { $where = ["-and", map { { like => $_ } } @$cond]; }
    else             { $where = [        map { { like => $_ } } @$cond]; }
    return $where;
};

my @profile_id;
if (scalar @user_id || scalar @name || scalar @screen_name) {
    my %where;
    $where{id}          = \@user_id                   if scalar @user_id;
    $where{name}        = $com_where->(\@name)        if scalar @name;
    $where{screen_name} = $com_where->(\@screen_name) if scalar @screen_name;

    my $result = $schema->search('user', \%where);
    while ( my $row = $result->next ) {
        push @profile_id, $row->profile_id;
    }
}

my @tweet;
if (scalar @status_id || scalar @profile_id || scalar @datetime || scalar @text) {
    my %where;
    my $and_search = $or_search ? 0 : 1;
    $where{id}         = \@status_id                       if scalar @status_id;
    $where{profile_id} = \@profile_id                      if scalar @profile_id;
    $where{created_at} = $com_where->(\@datetime)          if scalar @datetime;
    $where{text}       = $com_where->(\@text, $and_search) if scalar @text;

    $where{retweeted_status_id} = undef if $ignore_retweet;

    my $result = $schema->search('status', \%where, { order_by => 'id DESC' });
    while ( my $row = $result->next ) {
        my $len = length $row->user->screen_name;
        $spacer = $len if $len > $spacer;

        $count++;
        push @tweet, [$row->id, $row->created_at, $row->user->screen_name, $row->text];
    }
}

say sprintf "%s %${spacer}s: %s", @{$_}[1,2,3] for sort { $b->[0] <=> $a->[0] } @tweet;
say "$count tweets.";

exit;
