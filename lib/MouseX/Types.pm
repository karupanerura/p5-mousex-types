package MouseX::Types;
use strict;
use warnings;
our $VERSION = '0.01';

use Mouse::Util::TypeConstraints ();

sub import {
    my($class, %args) = @_;

    my $type_class = caller;

    {
        no strict 'refs';
        *{$type_class . '::import'} = \&_do_import;
        push @{$type_class . '::ISA'}, 'MouseX::Types::Base';
    }

    if(my $declare = $args{-declare}){
        if(ref($declare) ne 'ARRAY'){
            Carp::croak("You must pass an ARRAY reference to -declare");
        }
        my $storage = $type_class->type_storage();
        for my $name (@{ $declare }) {
            my $fq_name = $storage->{$name} = $type_class . '::' . $name;

            my $type = sub {
                my $obj = Mouse::Util::TypeConstraints::find_type_constraint($fq_name);
                if($obj){
                    no strict 'refs';
                    no warnings 'redefine';
                    *{$fq_name} = _generate_type($obj);
                    goto &{$fq_name};
                 }
                 return $fq_name;
            };

            no strict;
            *{$fq_name} = $type;
        }
    }

    Mouse::Util::TypeConstraints->import({ into => $type_class });
}

sub _do_import {
    my $type_class = shift;
    my $into       = Mouse::Exporter::_get_caller_package(ref $_[0] ? shift : undef);

    my $storage = $type_class->type_storage;

    my %uniq;
    my @types = grep{ !$uniq{$_}++ } map{ $_ eq ':all' ?  keys(%{$storage}) : $_ } @_;

    for my $name (@types) {
        my $fq_name = $storage->{$name}
            || Carp::croak(qq{"$name" is not exported by $type_class});

        my $obj = Mouse::Util::TypeConstraints::find_type_constraint($fq_name)
            || Carp::croak(qq{"$name" is declared but not defined in $type_class});

        no strict 'refs';
        *{$into . '::' . $name} = _generate_type($obj);
    }
}

sub _generate_type {
    my($type_constraint) = @_;
    return sub {
        if(@_){ # parameterization
            my $param = shift;
            if(@_){
                Carp::croak("Syntax error in type definition");
            }
            if(!(ref($param) eq 'ARRAY' && @{$param} == 1)){
                Carp::croak("Syntax error in type definition (you must pass an ARRAY reference of a type)");
            }
            return $type_constraint->parameterize(@{$param});
        }
        else{
            return $type_constraint;
        }
    };
}

{
    package MouseX::Types::Base;
    my %storage;
    sub type_storage { # can be overriden
        return $storage{$_[0]} ||= +{}
    }

    sub type_names {
        my($class) = @_;
        return keys %{$class->type_storage};
    }
}

1;
__END__

=head1 NAME

MouseX::Types - Organize your Mouse types in libraries

=head1 SYNOPSIS

=head2 Library Definition

  package MyLibrary;

  # predeclare our own types
  use MouseX::Types 
    -declare => [qw(
        PositiveInt NegativeInt
    )];

  # import builtin types
  use MouseX::Types::Mouse 'Int';

  # type definition.
  subtype PositiveInt, 
      as Int, 
      where { $_ > 0 },
      message { "Int is not larger than 0" };
  
  subtype NegativeInt,
      as Int,
      where { $_ < 0 },
      message { "Int is not smaller than 0" };

  # type coercion
  coerce PositiveInt,
      from Int,
          via { 1 };

  1;

=head2 Usage

  package Foo;
  use Mouse;
  use MyLibrary qw( PositiveInt NegativeInt );

  # use the exported constants as type names
  has 'bar',
      isa    => PositiveInt,
      is     => 'rw';
  has 'baz',
      isa    => NegativeInt,
      is     => 'rw';

  sub quux {
      my ($self, $value);

      # test the value
      print "positive\n" if is_PositiveInt($value);
      print "negative\n" if is_NegativeInt($value);

      # coerce the value, NegativeInt doesn't have a coercion
      # helper, since it didn't define any coercions.
      $value = to_PositiveInt($value) or die "Cannot coerce";
  }

  1;

=head1 AUTHOR

Kazuhiro Osawa E<lt>yappo <at> shibuya <döt> plE<gt>

Shawn M Moore

tokuhirom

with plenty of code borrowed from L<MooseX::Types>

=head1 REPOSITORY

  git clone git://github.com/yappo/p5-mousex-types.git MouseX-Types

=head1 SEE ALSO

L<Mouse>

L<MooseX::Types>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
