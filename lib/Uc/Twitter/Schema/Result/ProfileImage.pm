package Uc::Twitter::Schema::Result::ProfileImage;

use common::sense;
use warnings qw(utf8);
use parent 'DBIx::Class::Core';

__PACKAGE__->table("profile_image");
__PACKAGE__->add_columns(
  "url",
  { data_type => "text", is_nullable => 0 },
  "image",
  { data_type => "mediumblob", is_nullable => 0 },
);

__PACKAGE__->set_primary_key("url");

1;
