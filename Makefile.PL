use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
  NAME           => 'Win32::IEHistory',
  AUTHOR         => 'Kenichi Ishigaki <ishigaki@cpan.org>',
  VERSION_FROM   => 'lib/Win32/IEHistory.pm',
  ABSTRACT_FROM  => 'lib/Win32/IEHistory.pm',
  PREREQ_PM => {
    'Class::Accessor::Fast' => 0,
    'DateTime'              => 0,
    'Math::BigInt'          => 0,
    ( $^O eq 'MSWin32'
      ? ( 'Win32::TieRegistry' => 0 )
      : ()
    ),
  },
  ($ExtUtils::MakeMaker::VERSION >= 6.31
    ? (LICENSE => 'perl')
    : ()
  ),
);
