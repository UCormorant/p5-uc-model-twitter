package Uc::Twitter::Schema::ResultSet::User;

use common::sense;
use warnings qw(utf8);
use base 'DBIx::Class::ResultSet';

use Encode qw(encode_utf8);
use Digest::MD5 qw(md5_hex);

our @USER_VALUE_FOR_DIGEST = qw(
    screen_name
    name
    location
    url
    description
    lang
    time_zone
    utc_offset

    profile_image_url
    profile_image_url_https
    profile_background_image_url
    profile_background_image_url_https

    profile_text_color
    profile_link_color
    profile_background_color
    profile_sidebar_fill_color

    protected
    geo_enabled
    verified
    is_translator
    contributors_enabled

    default_profile
    default_profile_image
    profile_use_background_image
    profile_background_tile
);

our @INTEGER_VALUE = qw(
    utc_offset

    protected
    geo_enabled
    verified
    is_translator
    contributors_enabled

    default_profile
    default_profile_image
    profile_use_background_image
    profile_background_tile
);

our @BOOLEAN_VALUE = qw(
    protected
    geo_enabled
    verified
    is_translator
    contributors_enabled

    default_profile
    default_profile_image
    profile_use_background_image
    profile_background_tile
);

sub find_or_create_from_user {
    my ($self, $user, $attr) = @_;
    my $result_source = $self->result_source;

    my %columns;
    for my $col ($result_source->columns) {
        $columns{$col} = $user->{$col} if exists $user->{$col};
        if (exists $columns{$col} && $col ~~ \@BOOLEAN_VALUE) {
            $columns{$col} = 1 if $columns{$col} =~ /^true$/i;
            $columns{$col} = 0 if $columns{$col} =~ /^false$/i;
        }
        elsif (not defined $columns{$col}) {
            my $col_info = $result_source->column_info($col);
            if (!$col_info->{is_nullable}) {
                $columns{$col} = exists $col_info->{default_value} ? $col_info->{default_value} : '';
            }
        }
    }
    $columns{profile_id} = _get_profile_id($user) if !$columns{profile_id};

    for my $col ($result_source->columns) {
        $columns{$col} = encode_utf8($columns{$col}) if exists $columns{$col} && utf8::is_utf8($columns{$col});
    }
    $self->find_or_create(\%columns);
}

sub _get_profile_id {
    return md5_hex encode_utf8( join '', @{_set_default_value(shift)}{@USER_VALUE_FOR_DIGEST} );
}

sub _set_default_value {
    my $user = {%{+shift}};
    for my $key (@USER_VALUE_FOR_DIGEST) {
        my $default = "";
        given ($key) { when (\@INTEGER_VALUE) { $default = 0; } }
        $user->{$key} = $default if not defined $user->{$key};
    }
    return $user;
}

1;
