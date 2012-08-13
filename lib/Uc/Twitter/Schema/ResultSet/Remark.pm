package Uc::Twitter::Schema::ResultSet::Remark;

use common::sense;
use warnings qw(utf8);
use parent 'DBIx::Class::ResultSet';

use Carp qw(croak);

our @BOOLEAN_VALUE = qw(
    favorited
    retweeted
);

sub update_or_create_with_retweet {
    my ($self, $update, $attr) = @_;
    my $result_source = $self->result_source;
    my $schema = $result_source->schema;

    my %columns;
    for my $col ($result_source->columns) {
        $columns{$col} = $update->{$col} if exists $update->{$col};
        if (exists $columns{$col} && $col ~~ \@BOOLEAN_VALUE) {
            $columns{$col} = 1 if $columns{$col} =~ /^true$/i;
            $columns{$col} = 0 if $columns{$col} =~ /^false$/i;
        }
        elsif (not defined $columns{$col}) {
            my $col_info = $result_source->column_info($col);
            if (!$col_info->{is_nullable}) {
                if (exists $col_info->{default_value}) {
                    $columns{$col} = $col_info->{default_value};
                }
                else {
                    croak "first argument must be included id and user_id";
                    return;
                }
            }
        }
    }

    my $retweeted_status_id = undef;
    if (ref $attr->{retweeted_status}) {
        $retweeted_status_id = $attr->{retweeted_status}{id};
    }
    else {
        my $tweet = $schema->resultset('Status')->search({ id => $update->{id} })->first;
        if (ref $tweet and $tweet->retweeted_status_id != '') {
            $retweeted_status_id = $tweet->retweeted_status_id;
        }
    }
    if ($retweeted_status_id) {
        my %retweet_update = %$update;
        $retweet_update{id} = $retweeted_status_id;
        $self->update_or_create(\%retweet_update);
    }

    $self->update_or_create($update);
}

1;
