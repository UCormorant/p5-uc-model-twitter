package Uc::Model::Twitter::Schema;

use 5.014;
use warnings;
use utf8;
use Teng::Schema::Declare;

use DBI qw(:sql_types);
use DateTime::Format::MySQL;

table {
    name "status";
    pk qw( id created_at );
    columns (
        { name => "id",                      type => SQL_BIGINT   },
        { name => "created_at",              type => SQL_DATETIME },
        { name => "user_id",                 type => SQL_BIGINT   },
        { name => "profile_id",              type => SQL_VARCHAR  },
        { name => "text",                    type => SQL_VARCHAR  },
        { name => "source",                  type => SQL_VARCHAR  },
        { name => "in_reply_to_status_id",   type => SQL_BIGINT   },
        { name => "in_reply_to_user_id",     type => SQL_BIGINT   },
        { name => "in_reply_to_screen_name", type => SQL_VARCHAR  },
        { name => "retweeted_status_id",     type => SQL_BIGINT   },
        { name => "protected",               type => SQL_BOOLEAN  },
        { name => "truncated",               type => SQL_BOOLEAN  },
        { name => "statuses_count",          type => SQL_INTEGER  },
        { name => "favourites_count",        type => SQL_INTEGER  },
        { name => "friends_count",           type => SQL_INTEGER  },
        { name => "followers_count",         type => SQL_INTEGER  },
        { name => "listed_count",            type => SQL_INTEGER  },
    );
    inflate 'created_at' => sub { DateTime::Format::MySQL->parse_datetime($_[0]) };
    deflate 'created_at' => sub { ref $_[0] ? DateTime::Format::MySQL->format_datetime($_[0]) : $_[0] };
};

table {
    name "user";
    pk qw( id profile_id );
    columns (
        { name => "id",                                 type => SQL_BIGINT  },
        { name => "profile_id",                         type => SQL_VARCHAR },
        { name => "screen_name",                        type => SQL_VARCHAR },
        { name => "name",                               type => SQL_VARCHAR },
        { name => "location",                           type => SQL_VARCHAR },
        { name => "url",                                type => SQL_VARCHAR },
        { name => "description",                        type => SQL_VARCHAR },
        { name => "lang",                               type => SQL_VARCHAR },
        { name => "time_zone",                          type => SQL_VARCHAR },
        { name => "utc_offset",                         type => SQL_INTEGER },
        { name => "profile_image_url",                  type => SQL_VARCHAR },
        { name => "profile_image_url_https",            type => SQL_VARCHAR },
        { name => "profile_background_image_url",       type => SQL_VARCHAR },
        { name => "profile_background_image_url_https", type => SQL_VARCHAR },
        { name => "profile_banner_url",                 type => SQL_VARCHAR },
        { name => "profile_text_color",                 type => SQL_VARCHAR },
        { name => "profile_link_color",                 type => SQL_VARCHAR },
        { name => "profile_background_color",           type => SQL_VARCHAR },
        { name => "profile_sidebar_fill_color",         type => SQL_VARCHAR },
        { name => "protected",                          type => SQL_BOOLEAN },
        { name => "geo_enabled",                        type => SQL_BOOLEAN },
        { name => "verified",                           type => SQL_BOOLEAN },
        { name => "is_translator",                      type => SQL_BOOLEAN },
        { name => "contributors_enabled",               type => SQL_BOOLEAN },
        { name => "default_profile",                    type => SQL_BOOLEAN },
        { name => "default_profile_image",              type => SQL_BOOLEAN },
        { name => "profile_use_background_image",       type => SQL_BOOLEAN },
        { name => "profile_background_tile",            type => SQL_BOOLEAN },
    );
};

table {
    name "remark";
    pk qw( id user_id );
    columns (
        { name => "id",        type => SQL_BIGINT  },
        { name => "user_id",   type => SQL_BIGINT  },
        { name => "favorited", type => SQL_BOOLEAN },
        { name => "retweeted", type => SQL_BOOLEAN },
    );
};

table {
    name "profile_image";
    pk qw( url );
    columns (
        { name => "url",   type => SQL_VARCHAR },
        { name => "image", type => SQL_BLOB    },
    );
};


package Uc::Model::Twitter::Row::Status;
use parent 'Teng::Row';

sub user { # belongs_to
    my $self = shift;
    $self->{_prv_umt_profile} //= $self->{teng}->single('user', { id => $self->user_id, profile_id => $self->profile_id });
}

sub remarks { # has_many
    my $self = shift;
    $self->{teng}->search('remark', { id => $self->id });
}


package Uc::Model::Twitter::Row::User;
use parent 'Teng::Row';

sub tweets { # has_many
    my $self = shift;
    $self->{teng}->search('status', { user_id => $self->id });
}

sub remarks { # has_many
    my $self = shift;
    $self->{teng}->search('remark', { user_id => $self->id });
}


package Uc::Model::Twitter::Row::Remark;
use parent 'Teng::Row';

sub tweet { # belongs_to
    my $self = shift;
    $self->{_prv_umt_tweet} //= $self->{teng}->single('status', { id => $self->id });
}

sub user { # belongs_to
    my $self = shift;
    $self->{_prv_umt_profile} //= $self->{teng}->single('user', { id => $self->user_id });
}


package Uc::Model::Twitter::Row::ProfileImage;
use parent 'Teng::Row';

1; # Magic true value required at end of module
