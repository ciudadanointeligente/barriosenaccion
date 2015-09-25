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
                                            "Otros" => 'otros',
                                            "Basura en vereda o calzada" => "basura_y_falta_de_higiene_en_el_espacio_publico",
                                            "Basura fuera de horario de retiro" => "basura_fuera_de_horario_de_retiro",
                                            "Calzadas o aceras en mal estado" => "calzadas_o_aceras_en_mal_estado",
                                            "Casa abandonada / sitio eriazo" => "casa_abandonada_/_sitio_eriazo",
                                            "Clandestinos" => "clandestinos",
                                            "Cobro incorrecto de parquímetro" => "cobro_incorrecto_de_parquímetro",
                                            "Comercio ambulante" => "comercio_ambulante",
                                            "Falta de señal o señal en mal estado" => "falta_de_señal_o_señal_en_mal_estado",
                                            "Luminarias apagadas o en mal estado" => "luminarias_apagadas_o_en_mal_estado",
                                            "Mobiliario urbano en mal estado" => "mobiliario_urbano_en_mal_estado",
                                            "Obstrucción del espacio público" => "obstrucción_del_espacio_público",
                                            "Presencia de escombros" => "presencia_de_escombros",
                                            "Ruidos Molestos" => "ruidos_molestos",
                                            "Semáforo apagado o en mal estado" => "semáforo_apagado_o_en_mal_estado",
                                            "Trabajos fuera de horario" => "trabajos_fuera_de_horario",
                                            "Vehículos mal estacionados" => "vehículos_mal_estacionados"
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
            return 'default';
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
