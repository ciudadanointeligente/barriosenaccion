
package FixMyStreet::Cobrand::BarriosEnAccion;
use base 'FixMyStreet::Cobrand::Default';
use Unicode::Normalize;

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
# sub all_reports_single_body {
#     my $self = shift;
#     return { name => 'Municipalidad de Providencia' };
# }

use constant CATEGORY_PINS_AND_CLASSES => {
                                            "Mantencion del entorno" => "mantencion_del_entorno",
                                            "Basura y falta de higiene en el espacio publico" => "basura_y_falta_de_higiene_en_el_espacio_publico",
                                            "Espacios abandonados y escondites" => "espacios_abandonados_y_escondites",
                                            "Rayados" => "rayados",
                                            "Estado de los elementos del transito" => "estado_de_los_elementos_del_transito",
                                            "Flujo vehicular y peatonal" => "flujo_vehicular_y_peatonal",
                                            "Presencia de personas y/o vehiculos no autorizados" => "presencia_de_personas_y_vehiculos_no_autorizados",
                                            "Clandestinos" => "clandestinos",
                                            "Faltas a la Convivencia"  => "faltas_a_la_convivencia",
                                            "Ruidos Molestos" => "ruidos_molestos",
                                            "Congestion"  => "congestion",
                                            "Otros" => 'otros'
                                            # ,
                                            # "Basura en vereda o calzada" => "basura_y_falta_de_higiene_en_el_espacio_publico",
                                            # "Basura fuera de horario de retiro" => "basura_y_falta_de_higiene_en_el_espacio_publico",
                                            # "Calzadas o aceras en mal estado" => "vereda_o_calle_en_mal_estado",
                                            # "Clandestinos" => "clandestinos",
                                            # "Falta de señal o señal en mal estado" => "vereda_o_calle_en_mal_estado",
                                            # "Semáforo apagado o en mal estado" => "flujo_vehicular_y_peatonal",
                                            # "Vehículos mal estacionados" => "congestion"
                                        };

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    #return 'green' if time() - $p->confirmed->epoch < 7 * 24 * 60 * 60;
    if ($p->is_fixed) {
        return 'green';
    }
    if ($context eq 'around' || $context eq 'reports' || $context eq 'report') {

        my $decomposed = NFKD( $p->category );
        $decomposed =~ s/\p{NonspacingMark}//g;


        if ( grep( /^$decomposed$/, keys $self->CATEGORY_PINS_AND_CLASSES ) ) {
          return $self->CATEGORY_PINS_AND_CLASSES->{$decomposed};
        }
        else {
            return 'otros';
        }

    }
}
sub can_support_problems {
  return 1;
}

sub path_to_pin_icons {
    return '/cobrands/barriosenaccion/images/pins/';
}

use constant TWITTERS => {
    '1' => 'Muni_provi',
    '2' => 'Muni_recoleta',
    '5' => 'Muni_stgo'
};

sub municipalidad_twitter {
    my ( $self, $r ) = @_;
    my $bodies_str = $r->bodies_str;
    return $self->TWITTERS->{$bodies_str};
}

1;
