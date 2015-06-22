package FixMyStreet::Cobrand::BarriosEnAccion;
use base 'FixMyStreet::Cobrand::Default';

use strict;
use warnings;

sub country {
    return 'CL';
}

sub example_places {
    return ( 'Dominica, Recoleta', 'Pio Nono' );
}

sub languages { [ 'es-cl,Castellano,es_CL' ] }

sub disambiguate_location {
    return {
        country => 'cl',
        town => 'Santiago',
    };
}

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    #return 'green' if time() - $p->confirmed->epoch < 7 * 24 * 60 * 60;
    if ($context eq 'around' || $context eq 'reports' || $context eq 'report') {
        return 'yellow';
    }
    return $p->is_fixed ? 'green' : 'red';
}

sub path_to_pin_icons {
    return '/cobrands/barriosenaccion/images/pins/';
}


1;

