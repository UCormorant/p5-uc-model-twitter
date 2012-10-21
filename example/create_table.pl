#!/usr/local/bin/perl

use lib qw(lib ../lib);
use DBICx::Deploy;

DBICx::Deploy->deploy('Uc::Twitter::Schema' => 'DBI:MySQL:twitter', shift, shift);

1;
