use strict;
use Test::More qw( no_plan );

BEGIN {
  use_ok('Win32::IEHistory');
  use_ok('Win32::FileTime');
  if ( $^O eq 'MSWin32' ) {
    use_ok('Win32::IEHistory::Cache');
    use_ok('Win32::IEHistory::Cookies');
    use_ok('Win32::IEHistory::History');
  }
}
