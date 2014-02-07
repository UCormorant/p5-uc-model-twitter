package lib::Util;

use 5.014;
use warnings;
use utf8;
use parent qw(Exporter);

use File::Basename qw(dirname);
use File::Spec::Functions qw(catdir);
use lib catdir(dirname(__FILE__));
require 'twitter_agent.pl';

use autodie;
use Encode::Locale qw(decode_argv);
use Net::Twitter::Lite::WithAPIv1_1;
use AnyEvent::Twitter::Stream;

our @EXPORT = qw(twitter_agent setup_dbh sample_stream);

if (-t) {
    STDIN->binmode(":encoding(console_in)");
    STDOUT->binmode(":encoding(console_out)");
    STDERR->binmode(":encoding(console_out)");
    decode_argv();
}

sub import {
    strict->import;
    warnings->import;
    utf8->import;

    lib::Util->export_to_level(1, @_);
}

sub setup_dbh {
    my $driver_name = lc shift;
    if ($driver_name eq 'sqlite') { return setup_dbh_sqlite(@_);  }
    if ($driver_name eq 'mysql' ) { return setup_dbh_mysql(@_);   }
    else                          { die "'$_' is not supported."; }
}

sub setup_dbh_sqlite {
    my $file = shift || ':memory:';
    DBI->connect('dbi:SQLite:'.$file,'','',{RaiseError => 1, PrintError => 0, AutoCommit => 1, sqlite_unicode => 1});
}

sub setup_dbh_mysql {
    my $db = shift || 'test';
    my $user = shift;
    my $pass = shift;
    my $dbh = DBI->connect('dbi:mysql:'.$db,$user,$pass,{RaiseError => 1, PrintError => 0, AutoCommit => 1,  mysql_enable_utf8 => 1});
    $dbh->do('SET NAMES utf8mb4');
    $dbh;
}

sub sample_stream {
    my ($config, $count) = @_;
    my @tweets;
    $count = 100 if $count < 1;
    print "streamer starts to read... ";

    my $cv = AE::cv;
    my $streamer = AnyEvent::Twitter::Stream->new(
        method   => 'sample',

        on_connect => sub {
            say "connected.";
            print "collect $count tweets... ";
        },
        on_tweet => sub {
            my $tweet = shift;
            if (!$tweet->{user} or $tweet->{text} eq '') { return; }
            push @tweets, $tweet;
            $cv->send if scalar @tweets == $count;
        },
        on_event => sub {},
        on_error => sub {
            die "error: $_[0]";
        },
        on_eof => $cv,

        %$config,
    );
    $cv->recv;

    say "done.";
    return \@tweets;
}

1;
