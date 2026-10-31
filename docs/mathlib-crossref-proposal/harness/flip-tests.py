p='Mathlib/Tactic/CrossRefAttribute.lean'
s=open(p).read()
a=s.index("\n\nTODO: due to the docstring extension being")
b=s.index("-/\ndef addCrossRefDoc",a)
s=s[:a]+" "+s[b:]
open(p,'w').write(s)
p='MathlibTest/CrossRefAttribute.lean'
s=open(p).read()
old1='''-- Known issue: due to async elaboration, the stacks / kerodon tags get overwritten by
-- the declaration's own docstring.
/--
info: some (This docstring should appear before any Stacks or Kerodon references.)
-/
'''
new1='''/--
info: some (This docstring should appear before any Stacks or Kerodon references.

[Stacks Tag A04Q](https://stacks.math.columbia.edu/tag/A04Q) (A comment)

[Kerodon Tag B15R](https://kerodon.net/tag/B15R) (Also a comment))
-/
'''
old2='''-- Known issue: due to async elaboration, the stacks / kerodon tags get overwritten by
-- the declaration's own docstring.
/--
info: some (This docstring should appear before any Stacks or Kerodon references. )
-/
'''
new2='''/--
info: some (This docstring should appear before any Stacks or Kerodon references. 

[Stacks Tag A04Q](https://stacks.math.columbia.edu/tag/A04Q) \\(A comment\\)

[Kerodon Tag B15R](https://kerodon.net/tag/B15R) \\(Also a comment\\))
-/
'''
assert old1 in s and old2 in s
s=s.replace(old1,new1).replace(old2,new2)
open(p,'w').write(s)
