package Uc::Twitter::Schema::Result::User;

use common::sense;
use warnings qw(utf8);
use parent 'DBIx::Class::Core';

__PACKAGE__->table("user");
__PACKAGE__->resultset_class('Uc::Twitter::Schema::ResultSet::User');
__PACKAGE__->add_columns(
  "id",
  {
    data_type => "bigint",
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  "profile_id",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 32 },
  "screen_name",
  { data_type => "tinytext", is_nullable => 0 },
  "name",
  { data_type => "tinytext", is_nullable => 0 },
  "location",
  { data_type => "tinytext", is_nullable => 0 },
  "url",
  { data_type => "tinytext", is_nullable => 0 },
  "description",
  { data_type => "text", is_nullable => 0 },
  "lang",
  { data_type => "tinytext", is_nullable => 0 },
  "time_zone",
  { data_type => "tinytext", is_nullable => 0 },
  "utc_offset",
  { data_type => "mediumint", default_value => 0, is_nullable => 0 },
  "profile_image_url",
  { data_type => "text", is_nullable => 0 },
  "profile_image_url_https",
  { data_type => "text", is_nullable => 0 },
  "profile_background_image_url",
  { data_type => "text", is_nullable => 0 },
  "profile_background_image_url_https",
  { data_type => "text", is_nullable => 0 },
  "profile_text_color",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 8 },
  "profile_link_color",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 8 },
  "profile_background_color",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 8 },
  "profile_sidebar_fill_color",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 8 },
  "protected",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "geo_enabled",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "verified",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "is_translator",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "contributors_enabled",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "default_profile",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "default_profile_image",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "profile_use_background_image",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "profile_background_tile",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id", "profile_id");

__PACKAGE__->has_many( status => 'Uc::Twitter::Schema::Result::Status', {
    'foreign.user_id' => 'self.id',
    'foreign.profile_id' => 'self.profile_id',
}, { cascade_delete => 0 } );

__PACKAGE__->has_many( remark => 'Uc::Twitter::Schema::Result::Remark', {
    'foreign.user_id' => 'self.id',
}, { cascade_delete => 0 } );

1;
