package FixMyStreet::Cobrand::Vecinoi;
use base 'FixMyStreet::Cobrand::Default';

use strict;
use warnings;

sub path_to_web_templates {
    my $self = shift;
    return [
        FixMyStreet->path_to( 'templates/web', $self->moniker )->stringify,
        FixMyStreet->path_to( 'templates/web/fixmystreet' )->stringify
    ];
}

sub country {
    return 'CL';
}

sub example_places {
    return ( 'Valdivia', 'Llanquihue' );
}

sub languages { [ 'es-cl,Castellano,es_CL', 'en-gb,English,en_GB' ] }

sub disambiguate_location {
    return {
        country => 'cl',
    };
}

1;

