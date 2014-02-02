use t::Util;
use Test::More tests => 6;

use_ok $_ for qw(
    Uc::Model::Twitter
    Uc::Model::Twitter::Crawler
    Uc::Model::Twitter::Schema
    Uc::Model::Twitter::Util
    Uc::Model::Twitter::Util::MySQL
    Uc::Model::Twitter::Util::SQLite
);

done_testing;
