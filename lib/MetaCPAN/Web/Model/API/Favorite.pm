package MetaCPAN::Web::Model::API::Favorite;
use Moose;
use namespace::autoclean;

extends 'MetaCPAN::Web::Model::API';

use List::MoreUtils qw(uniq);

sub get {
    my ( $self, $user, @distributions ) = @_;
    @distributions = uniq @distributions;
    my $cv = $self->cv;
    $self->request(
        '/favorite/_search',
        {   size  => 0,
            query => {
                filtered => {
                    query  => { match_all => {} },
                    filter => {
                        or => [
                            map {
                                { term => { 'favorite.distribution' => $_ } }
                                } @distributions
                        ]
                    }
                }
            },
            facets => {
                favorites => {
                    terms => {
                        field => 'favorite.distribution',
                        size  => scalar @distributions,
                    },
                },
                $user
                ? ( myfavorites => {
                        terms => { field => 'favorite.distribution', },
                        facet_filter =>
                            { term => { 'favorite.user' => $user } }
                    }
                    )
                : (),
            }
        }
        )->(
        sub {
            my $data = shift->recv;
            $cv->send(
                {   took      => $data->{took},
                    favorites => {
                        map { $_->{term} => $_->{count} }
                            @{ $data->{facets}->{favorites}->{terms} }
                    },
                    myfavorites => $user
                    ? { map { $_->{term} => $_->{count} }
                            @{ $data->{facets}->{myfavorites}->{terms} }
                        }
                    : {},
                }
            );
        }
        );
    return $cv;
}

__PACKAGE__->meta->make_immutable;
