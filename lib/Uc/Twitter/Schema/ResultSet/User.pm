package Uc::Twitter::Schema::ResultSet::User;

use common::sense;
use warnings qw(utf8);
use parent qw(DBIx::Class::ResultSet);
use Uc::Twitter::Schema::ResultSetBaseModule;

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
        my $col_info = $result_source->column_info($col);
        $columns{$col} = $user->{$col} if exists $user->{$col};
        if (exists $columns{$col} && $col ~~ \@BOOLEAN_VALUE) {
            $columns{$col} = 1 if $columns{$col} =~ /^true$/i;
            $columns{$col} = 0 if $columns{$col} =~ /^false$/i;
        }
        elsif (not defined $columns{$col}) {
            if (!$col_info->{is_nullable}) {
                $columns{$col} = exists $col_info->{default_value} ? $col_info->{default_value} : '';
            }
        }
        $columns{$col} = inflate_datetime($columns{$col}, $col_info);
    }
    $columns{profile_id} = get_profile_id($user) if !$columns{profile_id};

    $columns{$_} = deflate_utf8($columns{$_}) for $result_source->columns;

    $self->find_or_create(\%columns);
}

1;
