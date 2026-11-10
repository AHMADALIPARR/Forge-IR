# ATS proof boundary

`ForgeHeap.sats` defines the abstract heap state, object/descriptor/root
predicates, and legal transition witnesses. It is the contract for the ATS
proof implementation and the Factor event replay boundary.

There is intentionally no `.dats` implementation in this source package yet.
A state-token incrementer or a runtime boolean checker would not prove the
allocation, pointer-store, root, release, or collection invariants. The next
proof implementation must supply a concrete finite-map heap model, define
reachability as a least fixed point from roots, and construct each transition
witness only after checking its preconditions. The collection theorem must
establish that every reachable object is marked and no marked object is swept.

Do not treat the `.sats` declarations as completed proofs.
