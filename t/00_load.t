use strict;
use Test::UseAllModules;

BEGIN {
  all_uses_ok except =>
    ( $^O ne 'MSWin32' )
      ? qw(
          Win32::IEHistory::Cache
          Win32::IEHistory::Cookies
          Win32::IEHistory::History
        )
      : ();
}
