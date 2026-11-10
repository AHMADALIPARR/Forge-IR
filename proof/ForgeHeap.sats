(* ATS2 proof interface for the Forge heap transition system. *)

absvtype heap_vt (int)

absprop wf (int)
absprop live (int, int)
absprop fresh (int, int)
absprop has_desc (int, int)
absprop ptr_field (int, int, int)
absprop rooted (int, int, int)
absprop no_root (int, int)
absprop reachable (int, int)
absprop unreachable (int, int)
absprop epoch_open (int, int)
absprop marked (int, int, int)

(* Transition witnesses are produced only by the verifier implementation. *)
dataprop step (int, int) =
  | {s,s1,id,d:nat} AllocStep (s,s1) of
      (wf(s), fresh(s,id), has_desc(s,d), live(s1,id), wf(s1))
  | {s,s1,o,t,d,f:nat} StoreRefStep (s,s1) of
      (wf(s), live(s,o), live(s,t), ptr_field(s,d,f), wf(s1))
  | {s,s1,r,o:nat} RootAddStep (s,s1) of
      (wf(s), live(s,o), no_root(s,r), rooted(s1,r,o), wf(s1))
  | {s,s1,r,o:nat} RootRemoveStep (s,s1) of
      (wf(s), rooted(s,r,o), no_root(s1,r), wf(s1))
  | {s,s1,o:nat} ReleaseStep (s,s1) of
      (wf(s), live(s,o), unreachable(s,o), wf(s1))
  | {s,s1,e:nat} CollectStep (s,s1) of
      (wf(s), epoch_open(s,e), wf(s1))

fun heap_verify_alloc
  {s,s1:int} (pf: step(s,s1) | h: heap_vt(s)): heap_vt(s1)
fun heap_verify_store_ref
  {s,s1:int} (pf: step(s,s1) | h: heap_vt(s)): heap_vt(s1)
fun heap_verify_root_add
  {s,s1:int} (pf: step(s,s1) | h: heap_vt(s)): heap_vt(s1)
fun heap_verify_root_remove
  {s,s1:int} (pf: step(s,s1) | h: heap_vt(s)): heap_vt(s1)
fun heap_verify_release
  {s,s1:int} (pf: step(s,s1) | h: heap_vt(s)): heap_vt(s1)
fun heap_verify_collect
  {s,s1:int} (pf: step(s,s1) | h: heap_vt(s)): heap_vt(s1)
