package Uc::Twitter::Schema::Result::Remark;

use common::sense;
use warnings qw(utf8);
use base 'DBIx::Class::Core';

__PACKAGE__->table("remark");
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "bigint",
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  "user_id",
  {
    data_type => "bigint",
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  "favorited",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "retweeted",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
);

__PACKAGE__->set_primary_key("id", "user_id");

__PACKAGE__->belongs_to( status => 'Uc::Twitter::Schema::Result::Status', {
    'foreign.id' => 'self.id',
} );

__PACKAGE__->belongs_to( user => 'Uc::Twitter::Schema::Result::User', {
    'foreign.user_id' => 'self.user_id',
} );

1;
