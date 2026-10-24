module

import CiteTest.Module

/--
error: `#cite_export` needs a file that does not start with `module`, which sees every declaration whole
-/
#guard_msgs in
#cite_export ".lake/never.json" CiteTest
