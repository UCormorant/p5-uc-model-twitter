package Uc::Twitter::Schema::Result::Status;

use common::sense;
use warnings qw(utf8);
use parent 'DBIx::Class::Core';

__PACKAGE__->table("status");
__PACKAGE__->resultset_class('Uc::Twitter::Schema::ResultSet::Status');
__PACKAGE__->load_components(qw/InflateColumn::DateTime/);
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "bigint",
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  "created_at",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    default_value => "0000-00-00 00:00:00",
    is_nullable => 0,
  },
  "user_id",
  {
    data_type => "bigint",
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  "profile_id",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 32 },
  "text",
  { data_type => "text", is_nullable => 0 },
  "source",
  { data_type => "text", is_nullable => 1 },
  "in_reply_to_status_id",
  { data_type => "bigint", extra => { unsigned => 1 }, is_nullable => 1 },
  "in_reply_to_user_id",
  { data_type => "bigint", extra => { unsigned => 1 }, is_nullable => 1 },
  "in_reply_to_screen_name",
  { data_type => "tinytext", is_nullable => 1 },
  "retweeted_status_id",
  { data_type => "bigint", extra => { unsigned => 1 }, is_nullable => 1 },
  "protected",
  { data_type => "tinyint", is_nullable => 1 },
  "truncated",
  { data_type => "tinyint", is_nullable => 1 },
  "statuses_count",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "favourites_count",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "friends_count",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "followers_count",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "listed_count",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id", "created_at");

__PACKAGE__->belongs_to( user => 'Uc::Twitter::Schema::Result::User', {
    'foreign.id' => 'self.user_id',
    'foreign.profile_id' => 'self.profile_id',
} );

__PACKAGE__->has_many( remark => 'Uc::Twitter::Schema::Result::Remark', {
    'foreign.id' => 'self.id',
}, { cascade_delete => 0 } );

1;
