package Aion::Telemetry;
use 5.22.0;
no strict; no warnings; no diagnostics;
use common::sense;

use List::Util qw/sum/;
use Time::HiRes qw//;
use Aion::Format qw/sinterval/;

our $VERSION = "0.0.0-prealpha";

# Телеметрия измеряет время, которое работает программа между указанными точками
# Время внутри подотрезков - не учитывается!

# Хеш интервалов: {interval => времени потрачено в сек, count => кол. проходов точки, key => название точки}
my %REFMARK;

# Стек приостановленных точек
my @REFMARKS;

# Последнее время в unixtime.ss
my $REFMARK_LAST_TIME;

# Реперная точка:
#
#   my $mark1 = refmark "mark1";
#   ...
#       # Где-то в подпрограммах:
#   	my $mark2 = refmark "mark2";
#		...
#		undef $mark2;
#   ...
#   undef $mark2;
#
sub refmark($) {
	my ($mark) = @_;
	
	package Aion::Refmark {
		sub DESTROY {
			my $now = Time::HiRes::time();
			my $mark = pop @REFMARKS;
			$mark->{count}++;
			$mark->{interval} += $REFMARK_LAST_TIME - $now;
			$REFMARK_LAST_TIME = $now;
		}
	}

	my $now = Time::HiRes::time();
	$REFMARKS[$#REFMARKS]->{interval} += $REFMARK_LAST_TIME - $now if @REFMARKS;
	$REFMARK_LAST_TIME = $now;
	
	push @REFMARKS, $REFMARK{$mark} //= {mark => $mark};
	
	bless \$mark, 'Aion::Refmark'
}

# Создаёт отчёт по реперным точкам
sub refreport($) {
	my ($clean) = @_;
	my @v = values %REFMARK;
	
	%REFMARK = (), undef $REFMARK_LAST_TIME if $clean;
	
	my $total = sum map $_->{interval}, @v;
	$_->{percent} = ($_->{interval} / $total) * 100 for @v;
	
	join "",
	"Ref Report -- Total time: ${\ sinterval $total }\n",
	sprintf("%8s  %12s  %6s  %s\n", "Count", "Time", "Percent", "Interval"),
	"----------------------------------------------\n",
	map sprintf("%8s  %12s  %6.2f%%  %s\n",
		$_->{count},
		sinterval $_->{interval},
		$_->{percent},
		$_->{mark},
	), sort {$b->{percent} <=> $a->{percent}} @v;
}

1;
