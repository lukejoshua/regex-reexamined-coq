(*
listerine: A mouthwash for every type of list.

listerine automatically figures out which combination of a lot of theorems for lists to apply.
It consists of:
  - a combination of theorems for empty lists
  - a combination of theorems for singleton lists
  - (x :: xs) = (y :: ys) -> (x = y) /\ (xs = ys)
  - xs ++ ys = xs ++ zs -> ys = zs
  - splitting lists into possible combinations for type: ys ++ zs = x :: xs
  - taking a step for not equal lists if a hypothesis is hinting that some elements aren't equal
*)

(*
TODO: Help Wanted
Some of these tactics complete the proof and others simply step forward.
This seems like two goals that can be separated.
Let `auto` handle the completion of proofs and
let `listerine` handle stepping forward.
Once `listerine` is more widely used in the code base,
remove stuff from `listerine` that could be handled by auto.
Then `listerine` becomes `repeat listerine_step; auto 10`.
*)

(*
TODO: Good First Issue
Inside the cases of match goal sometimes a tactic is applied
and other times a theorem is applied.
Find places where a theorem would be more surgical,
create those theorems and replace the tactics.
Example:

Local Ltac list_cons_eq :=
match goal with
  | [H: (cons ?X ?XS) = (cons ?Y ?YS) |- _ ] =>
    inversion H; clear H; subst
    (* (x :: xs) = (y :: ys) -> (x = y) /\ (xs = ys) *)
  | [H: ?XS ++ [?X] = ?YS ++ [?Y] |- _ ] =>
    apply app_inj_tail in H
    (* xs ++ [x] = ys ++ [y] -> 
       xs = ys /\ x = y. *)
end.

replace `inversion H; clear H; subst` with a theorem `apply NewTheorem in H`.
*)

Require Import List.
Import ListNotations.

(* list_empty:
   finds empty lists in the hypotheses and the goal and tries to apply an appropriate tactic:
   - xs ++ ys = [] -> xs = [] /\ ys = []
   - [] = cons _ _ -> False
   - cons _ _ = [] -> False
   - [] = xs ++ y :: ys -> False
   - [] ++ xs -> xs
   - xs ++ [] -> xs
*)
Local Ltac list_empty :=
(* [] = cons _ _ -> False *)
(* cons _ _ = [] -> False *)
(* [] = x :: xs -> False *)
(* x :: xs = [] -> False *)
   discriminate
|| match goal with
| [ |- [] <> ?X ++ (?Y :: ?YS) ] =>
  apply app_cons_not_nil
  (* [] = xs ++ y :: ys -> False *)
| [ H: ?XS ++ ?YS = [] |- _ ] =>
  let H0 := fresh "H0" in
  let H1 := fresh "H1" in
  apply app_eq_nil in H;
  destruct H as [H0 H1];
  try rewrite H0 in *;
  try rewrite H1 in *
  (* xs ++ ys = [] -> 
        xs = [] 
     /\ ys = []
  *)
| [ H: [] = ?XS ++ ?YS |- _ ] =>
  let H0 := fresh "H0" in
  let H1 := fresh "H1" in
  symmetry in H;
  apply app_eq_nil in H;
  destruct H as [H0 H1];
  try rewrite H0 in *;
  try rewrite H1 in *
  (* [] = xs ++ ys -> 
       xs = [] 
    /\ ys = []
  *)
| [ H: context [[] ++ _] |- _ ] =>
  rewrite app_nil_l in H
  (* [] ++ xs = xs *)
| [ |- context [[] ++ _] ] =>
  rewrite app_nil_l
  (* [] ++ xs = xs *)
| [ H: context [_ ++ []] |- _ ] =>
  rewrite app_nil_r in H
  (* xs ++ [] = xs *)
| [ |- context [_ ++ []] ] =>
  rewrite app_nil_r
  (* xs ++ [] = xs *)
| [ |- [] = [] ] =>
  reflexivity
  (* [] = [] *)
end.

Example example_list_empty_neq_cons_r: forall {A: Type} (x: A) (xs: list A) ,
  [] <> x :: xs.
Proof.
intros.
list_empty.
Qed.

Example example_list_empty_neq_cons_l: forall {A: Type} (x: A),
  [] <> [x].
Proof.
intros.
list_empty.
Qed.

Example example_list_empty_eq_app: forall {A: Type} (xs: list A) (ys: list A),
  xs ++ ys = [] -> xs = [].
Proof.
intros.
list_empty.
reflexivity.
Qed.

Example example_list_empty_eq_app_easy: forall {A: Type} (xs: list A) (ys: list A),
  xs ++ ys = [] -> xs = [].
Proof.
intros.
list_empty.
easy.
Qed.

Example example_list_empty_eq_app_now: forall {A: Type} (xs: list A) (ys: list A),
  xs ++ ys = [] -> xs = [].
Proof.
intros.
now list_empty.
Qed.

Example example_list_empty_neq_unit_hyp_r: forall {A: Type} (x: A),
  [] <> [x].
Proof.
intros.
unfold not.
intros.
list_empty.
Qed.

Example example_list_empty_neq_unit_hyp_l: forall {A: Type} (x: A),
  [x] <> [].
Proof.
intros.
unfold not.
intros.
list_empty.
Qed.

Example example_list_empty_neq_app_cons: forall {A: Type} (xs: list A) (ys: list A) (y: A),
  [] <> xs ++ (y :: ys).
Proof.
intros.
list_empty.
Qed.

Example example_list_empty_app_l: forall {A: Type} (xs: list A),
  [] ++ xs = xs.
Proof.
intros.
list_empty.
reflexivity.
Qed.

Example example_list_empty_app_r: forall {A: Type} (xs: list A),
  xs ++ [] = xs.
Proof.
intros.
list_empty.
reflexivity.
Qed.

(* list_single:
   finds hypotheses with singleton lists and tries to apply an appropriate tactic.
   - xs ++ ys = [x] -> 
         (xs = [] /\ ys = [x])
      \/ (xs = [x] /\ ys = [])
   Sometimes it is needed to group singleton lists for other tactics to be applicable.
   - xs ++ ys ++ [y] ->
         (xs ++ ys) ++ [y]
   - (x :: xs) ++ ys -> 
         x :: (xs ++ ys)
*)
Local Ltac list_single :=
match goal with
  | [ H: ?XS ++ ?YS = [?X] |- _ ] =>
    let H0 := fresh "H0"
    in apply app_eq_unit in H; 
       destruct H as [H0 | H0]; destruct H0; subst
    (* xs ++ ys = [x] -> 
           (xs = [] /\ ys = [x])
        \/ (xs = [x] /\ ys = [])
    *)
  | [ H: [?X] = ?XS ++ ?YS  |- _ ] =>
    symmetry in H;
    let H0 := fresh "H0"
    in apply app_eq_unit in H; 
       destruct H as [H0 | H0]; destruct H0; subst
    (* xs ++ ys = [x] -> 
           (xs = [] /\ ys = [x])
        \/ (xs = [x] /\ ys = [])
    *)
  | [H: context [?XS ++ ?YS ++ [?Y]] |- _ ] =>
    rewrite app_assoc in H
    (* xs ++ ys ++ [y] -> 
      (xs ++ ys) ++ [y] *)
  | [H: context [(?X :: ?XS) ++ ?YS] |- _ ] =>
    (* (x :: xs) ++ ys -> 
       x :: (xs ++ ys) *)
    rewrite <- app_comm_cons in H
  | [ |- context [(?X :: ?XS) ++ ?YS] ] =>
    (* (x :: xs) ++ ys -> 
       x :: (xs ++ ys) *)
    rewrite <- app_comm_cons
end.

Example example_list_single_app_eq_unit: forall {A: Type} (xs ys:list A) (x:A),
  xs ++ ys = [x] -> xs = [] /\ ys = [x] \/ xs = [x] /\ ys = [].
Proof.
intros.
list_single.
- left. constructor; reflexivity.
- right. constructor; reflexivity.
Qed.

Example example_list_single_app_eq_unit_auto: forall {A: Type} (xs ys:list A) (x:A),
  xs ++ ys = [x] -> xs = [] /\ ys = [x] \/ xs = [x] /\ ys = [].
Proof.
intros.
list_single; auto.
Qed.

(* list_cons_eq:
   Finds an equality between lists in the hypotheses,
   with a head or tail element that can be deconstructed.
   (x :: xs) = (y :: ys) -> (x = y) /\ (xs = ys)
   xs ++ [x] = ys ++ [y] -> xs = ys /\ x = y.
*)
Local Ltac list_cons_eq :=
match goal with
  | [H: (cons ?X ?XS) = (cons ?Y ?YS) |- _ ] =>
    inversion H; clear H; subst
    (* (x :: xs) = (y :: ys) -> (x = y) /\ (xs = ys) *)
  | [H: ?XS ++ [?X] = ?YS ++ [?Y] |- _ ] =>
    apply app_inj_tail in H
    (* xs ++ [x] = ys ++ [y] -> 
       xs = ys /\ x = y. *)
end.

Example example_list_cons_eq: forall {A: Type} (x y: A) (xs ys: list A),
  (x :: xs) = (y :: ys) -> x = y.
Proof.
intros.
list_cons_eq.
reflexivity.
Qed.

Example example_list_app_assoc_app_inj_tail: forall {A: Type} (xs ys zs:list A) (y z:A),
  xs ++ ys ++ [y] = zs ++ [z] -> y = z.
Proof.
intros.
list_single.
list_cons_eq.
inversion H.
assumption.
Qed.

Example example_list_app_assoc_app_inj_tail_easy: forall {A: Type} (xs ys zs:list A) (y z:A),
  xs ++ ys ++ [y] = zs ++ [z] -> y = z.
Proof.
intros.
list_single.
list_cons_eq.
easy.
Qed.

(* list_app_eq:
   Finds an equality between lists in the hypotheses,
   with a common prefix or suffix:
   - xs ++ ys = xs ++ zs -> ys = zs.
   - xs ++ zs = ys ++ zs -> xs = ys.
*)
Local Ltac list_app_eq :=
match goal with
  | [H: ?XS ++ ?YS = ?XS ++ ?ZS |- _ ] =>
    apply app_inv_head in H
    (* xs ++ ys = xs ++ zs -> ys = zs *)
  | [H: (?XS ++ ?ZS) = (?YS ++ ?ZS) |- _ ] =>
    apply app_inv_tail in H
    (* xs ++ zs = ys ++ zs -> xs = ys*)
end.

Example example_list_app_eq_prefix: forall {A: Type} (xs ys zs: list A),
  xs ++ ys = xs ++ zs -> ys = zs.
Proof.
intros.
list_app_eq.
assumption.
Qed.

Example example_list_app_eq_suffix: forall {A: Type} (xs ys zs: list A),
  ys ++ xs = zs ++ xs -> ys = zs.
Proof.
intros.
list_app_eq.
assumption.
Qed.

(* list_app_uncons is used in a tactic below to deconstruct
   ys ++ zs = x :: xs
   into the possible combinations
   ys = [] /\ zs = x :: xs
   \/ ...
*)
Lemma list_app_uncons: forall {A: Type} (x: A) (xs ys zs: list A),
  ys ++ zs = x :: xs ->
  (ys = [] /\ zs = x :: xs)
  \/ (exists 
     (ys': list A)
     (pys: ys = x :: ys'),
     ys' ++ zs = xs
  ).
Proof.
intros.
destruct ys.
- list_empty.
  left.
  constructor.
  + reflexivity.
  + assumption.
- right.
  list_single.
  list_cons_eq.
  exists ys.
  exists eq_refl.
  reflexivity.
Qed.

(* list_app_uncons:
   Finds an hypotheses that it can deconstruct using the list_app_cons lemma:
   ys ++ zs = x :: xs
   into the two goals, which consist of the possible combinations, as in:
   - ys = [] /\ zs = x :: xs
   - ...
*)
Local Ltac list_app_uncons :=
  match goal with
  | [ H: ?YS ++ ?ZS = cons ?X ?XS |- _ ] =>
    let C := fresh "C"
    in let E := fresh "E"
    in let L := fresh "L"
    in let E0 := fresh "E0"
    in apply list_app_uncons in H;
       destruct H as [C | E];
       [inversion_clear C; subst
       | inversion_clear E as [L E0]; inversion_clear E0; subst]
  end.

Example example_list_app_uncons_double: 
  forall {A: Type} (xs ys: list A) (x y: A),
  xs ++ ys = [x;y] ->
  (xs = [] /\ ys = [x;y])
  \/ (xs = [x] /\ ys = [y])
  \/ (xs = [x;y] /\ ys = []).
Proof.
intros.
list_app_uncons.
- left. constructor; reflexivity.
- list_single.
  + right. left. constructor; reflexivity.
  + right. right. constructor; reflexivity.
Qed.

(*
list_cons_neq:
  Searches for hypotheses with `x <> y`,
  where `x` and/or `y` also occur in the goal as part lists that are also not equal:
  - x <> y -> x :: _ <> y :: _
  - x <> y -> _ <> x :: _ -> (x <> y -> ... -> False)
  - x <> y -> x :: _ <> _ -> (x <> y -> ... -> False)
  - y <> x -> _ <> x :: _ -> (y <> x -> ... -> False)
  - y <> x -> x :: _ <> _ -> (y <> x -> ... -> False)
*)
Local Ltac list_cons_neq :=
  match goal with
  | [ H: ?X <> ?Y |- cons ?X _ <> cons ?Y _ ] =>
    unfold not; intros; list_cons_eq; contradiction
    (* x <> y -> x :: _ <> y :: _ *)
   | [ H0: ?X <> ?Y, H1: context [?YS] |- cons ?X _ <> ?YS ] =>
    let N := fresh "N"
    in unfold not; intro N; rewrite <- N in *
    (* x <> y -> _ <> x :: _ -> (x <> y -> ... -> False) *)
  | [ H0: ?X <> ?Y, H1: context [?YS] |- ?YS <> cons ?X _ ] =>
    let N := fresh "N"
    in unfold not; intro N; rewrite N in *
    (* x <> y -> x :: _ <> _ -> (x <> y -> ... -> False) *)
  | [ H0: ?X <> ?Y, H1: context [?YS] |- cons ?Y _ <> ?YS ] =>
    let N := fresh "N"
    in unfold not; intro N; rewrite <- N in *
    (* y <> x -> _ <> x :: _ -> (y <> x -> ... -> False) *)
  | [ H0: ?X <> ?Y, H1: context [?YS] |- ?YS <> cons ?Y _ ] =>
    let N := fresh "N"
    in unfold not; intro N; rewrite N in *
    (* y <> x -> x :: _ <> _ -> (y <> x -> ... -> False) *)
  | [ H0: ?X <> ?Y |- cons ?X _ <> ?YS ] =>
    let N := fresh "N"
    in unfold not; intro N
    (* x <> y -> _ <> x :: _ -> (x <> y -> ... -> False) *)
  | [ H0: ?X <> ?Y |- ?YS <> cons ?X _ ] =>
    let N := fresh "N"
    in unfold not; intro N
    (* x <> y -> x :: _ <> _ -> (x <> y -> ... -> False) *)
  | [ H0: ?X <> ?Y |- cons ?Y _ <> ?YS ] =>
    let N := fresh "N"
    in unfold not; intro N
    (* y <> x -> _ <> x :: _ -> (y <> x -> ... -> False) *)
  | [ H0: ?X <> ?Y |- ?YS <> cons ?Y _ ] =>
    let N := fresh "N"
    in unfold not; intro N
    (* y <> x -> x :: _ <> _ -> (y <> x -> ... -> False) *)
  end.

Example example_list_cons_neq: forall (A: Type) (x: A) (y: A) (xs ys zs: list A),
  x <> y ->
  xs ++ ys = x :: zs ->
  xs <> [y].
Proof.
intros.
list_app_uncons.
- discriminate.
- list_cons_neq.
Qed.

Ltac listerine_step :=
     list_empty 
  || list_single
  || list_cons_eq
  || list_app_eq
  || list_app_uncons
  || list_cons_neq
  .

Ltac listerine := repeat listerine_step.

(* Lots of list theorems have been added to the auto database named: datatypes 
   Here is an example of using `auto with datatypes`.
*)
Example example_auto_with_datatypes: forall 
    {A: Type} (x y:list A) (a:A), 
    [] <> x ++ a :: y.
Proof.
intros.
auto with datatypes.
Qed.

(* `listerine` sometimes competes with `auto with datatypes`. *)
Example example_auto_with_datatypes_now_with_listerine: forall 
    {A: Type} (x y:list A) (a:A), 
    [] <> x ++ a :: y.
Proof.
intros.
listerine. (* `auto with datatypes.` also would have worked *)
Qed.

Example example_app_eq_unit:
forall {A: Type} (x y:list A) (a:A),
  x ++ y = [a] -> x = [] /\ y = [a] \/ x = [a] /\ y = [].
Proof.
intros.
listerine.
- left. constructor; reflexivity.
- right; constructor; reflexivity.
Qed.

Example example_list_app_eq_double: 
  forall {A: Type} (xs ys: list A) (x y: A),
  xs ++ ys = [x;y] ->
  (xs = [] /\ ys = [x;y])
  \/ (xs = [x] /\ ys = [y])
  \/ (xs = [x;y] /\ ys = []).
Proof.
intros.
listerine.
- left. constructor; reflexivity.
- right. left. constructor; reflexivity.
- right. right. constructor; reflexivity.
Qed.

Example example_list_app_eq_double_with_auto: 
  forall {A: Type} (xs ys: list A) (x y: A),
  xs ++ ys = [x;y] ->
  (xs = [] /\ ys = [x;y])
  \/ (xs = [x] /\ ys = [y])
  \/ (xs = [x;y] /\ ys = []).
Proof.
intros.
listerine; auto.
Qed.

Example example_list_app_eq_triple: forall (A: Type) (x y: A) (xs ys: list A),
    xs ++ ys = [x;x;y] ->
    (xs = [] /\ ys = [x;x;y])
    \/ (xs = [x] /\ ys = [x;y])
    \/ (xs = [x;x] /\ ys = [y])
    \/ (xs = [x;x;y] /\ ys = []).
Proof.
intros.
listerine; auto.
Qed.

Example example_app_eq_quad: forall (A: Type) (x y: A) (xs ys: list A),
    xs ++ ys = [x;x;x;y] ->
    (xs = [] /\ ys = [x;x;x;y])
    \/ (xs = [x] /\ ys = [x;x;y])
    \/ (xs = [x;x] /\ ys = [x;y])
    \/ (xs = [x;x;x] /\ ys = [y])
    \/ (xs = [x;x;x;y] /\ ys = []).
Proof.
intros.
listerine; auto 10.
Qed.

Example example_list_eq_head: forall (A: Type) (x: A) (y: A) (xs: list A) (ys: list A),
    x :: xs = [y] ++ ys ->
    x = y /\ xs = ys.
Proof.
intros.
listerine.
constructor; reflexivity.
Qed.

Example example_list_extract_init: forall (A: Type) (x y z: A),
    [x; y; z] = [x; y] ++ [z].
Proof.
intros.
listerine.
reflexivity.
Qed.

Example example_neq_tail: forall (A: Type) (x y: A) (xs ys zs xs': list A),
    x <> y ->
    xs ++ ys ++ zs = xs' ++ [x] ->
    zs <> [y].
Proof.
intros.
listerine.
inversion_clear H0; subst.
contradiction.
Qed.

Example example_list_neq_swap_suffix: 
  forall {A: Type} (x y: A) (xy: x <> y) (xs: list A),
  xs ++ [x] ++ [y] <> [y] ++ [x].
Proof.
intros.
listerine.
contradiction.
Qed.

Example example_list_neq_longer_suffix: 
  forall {A: Type} (x y: A) (xy: x <> y) (xs: list A),
  xs ++ [x] ++ [y] <> [y] ++ [y] ++ [y] ++ [x].
Proof.
intros.
listerine.
contradiction.
Qed.

Example example_list_neq_longer_prefix: 
  forall {A: Type} (x y: A) (xy: x <> y) (xs: list A),
  [y] ++ [y] ++ xs <> [x].
Proof.
intros.
listerine.
Qed.

