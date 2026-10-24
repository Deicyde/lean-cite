module

public import Cite

/-! A file of the module system can declare sources and cite them. -/

cite_source modbook "A Book"

@[cite modbook "1"]
public theorem modThm : True := trivial

cite modbook "2" in
example : True := trivial
