import CiteTest.ClashA
import CiteTest.ClashB

/-- error: the source `dup` is declared in several modules: CiteTest.ClashA, CiteTest.ClashB -/
#guard_msgs in
@[cite dup "1"] theorem clashing : True := trivial
