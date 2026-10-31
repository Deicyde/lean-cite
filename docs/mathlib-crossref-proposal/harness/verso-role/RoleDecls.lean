/-
Anne Baanen's alternative from the Zulip thread: a cross-reference as a Verso role in the docstring
text instead of an attribute. The role returns the link and records the tag, on whatever branch
elaborates the docstring.
-/
import Lean
import RoleExt

open Lean Doc Elab Term Lean.Doc

def stacks := ()

/-- Links to a Stacks tag and records it for the declaration being documented. -/
@[doc_role stacks]
meta def stacksRole (args : TSyntaxArray ``Parser.inline) : DocM (Inline ElabInline) := do
  let tag := (← onlyCode args).getVersoCode
  modifyEnv (tagsExt.addEntry · ((← getDeclName?).getD .anonymous, tag))
  return .link #[.text s!"Stacks Tag {tag}"] s!"https://stacks.math.columbia.edu/tag/{tag}"

set_option doc.verso true

/-- DOC {stacks}`00FN` -/
theorem roleThm : True := .intro

/-- DOC {stacks}`00FO` -/
def roleDef : Nat := 0

open Lean Elab Command in
run_cmd do
  logInfo m!"same-file roleThm: {repr (← findDocString? (← getEnv) ``roleThm)}"
  logInfo m!"same-file roleDef: {repr (← findDocString? (← getEnv) ``roleDef)}"
