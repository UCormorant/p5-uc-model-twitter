use strict;
use Test::More tests => 5;

use_ok $_ for qw(
    Uc::Model::Twitter
    Uc::Model::Twitter::Schema
    Uc::Model::Twitter::Util
    Uc::Model::Twitter::Util::MySQL
    Uc::Model::Twitter::Util::SQLite
);

done_testing;
