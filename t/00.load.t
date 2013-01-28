use Test::More tests => 3;

BEGIN {
use_ok( 'Uc::Model::Twitter' );
use_ok( 'Uc::Model::Twitter::Schema' );
use_ok( 'Uc::Model::Twitter::Util' );
}

diag( "Testing Uc::Model::Twitter ".Uc::Model::Twitter->VERSION );
