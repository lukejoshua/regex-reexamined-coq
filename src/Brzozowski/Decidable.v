Require Import List.
Import ListNotations.
Require Import Setoid.

Require Import Brzozowski.Alphabet.
Require Import Brzozowski.Language.
Require Import Brzozowski.Regex.

Require Import Lia.


Definition regex_is_decidable (r: regex) :=
    (forall s: str, s `elem` {{r}} \/ s `notelem` {{r}}).

Lemma length_zero_string_is_empty (s : str) :
  length s <= 0 -> s = [].
Proof.
  intros.
  assert (length s = 0).
  lia.
  rewrite length_zero_iff_nil in *.
  assumption.
Qed.

Lemma split_string_lemma (s : str) (n : nat):
  forall (s1 s2: str),
    length s1 = n ->
    s = s1 ++ s2 ->
    s1 = firstn n s /\
    s2 = skipn n s.
Proof.
  intros.
  set (s1' := firstn n s).
  set (s2' := skipn n s).
  subst.

  set (firstn_app (length s1) s1 s2) as Hfirst.
  replace (length s1 - length s1) with 0 in * by lia.
  replace (firstn 0 s2) with (nil : str) in * by (symmetry; apply firstn_O).
  rewrite app_nil_r in Hfirst.
  replace (firstn (length s1) s1) with s1 in Hfirst by (symmetry; apply firstn_all).

  set (skipn_app (length s1) s1 s2) as Hlast.
  replace (length s1 - length s1) with 0 in * by lia.
  replace (skipn (length s1) s1) with (nil: str) in Hlast by (symmetry; apply skipn_all).
  rewrite app_nil_l in Hlast.
  replace (skipn 0 s2) with s2 in Hlast by (apply skipn_O).

  split; auto.
Qed.

Lemma substrings_have_smaller_length (s s1 s2: str):
  s = s1 ++ s2 -> length s1 <= length s.
Proof.
  intro H.
  assert (length s1 + length s2 = length s).
  replace s with (s1 ++ s2) by assumption.
  symmetry.
  exact (app_length s1 s2).
  lia.
Qed.

Lemma denotation_concat_is_decidable_helper (p q: regex):
  regex_is_decidable p ->
  regex_is_decidable q ->
  (forall (s: str) (n : nat),
      (* prove that either all splittings don't match, or there is a match;
         but only consider a subset of all splttings
       *)
      (forall (s1 s2: str),
          s = s1 ++ s2 ->
          length s1 <= n ->
          (* does not match concat pairwise *)
          ((s1 `notelem` {{ p }} \/ s2 `notelem` {{ q }})))
      \/ (exists (s1 s2: str),
            s = s1 ++ s2 /\
            length s1 <= n /\
            (s1 `elem` {{ p }} /\ s2 `elem` {{ q }}))).
Proof.
  intros Hdecp Hdecq s n.
  induction n.
  - (* case that s1 is empty string *)
    destruct (Hdecp []) as [Hpmatches | Hpnomatch]; destruct (Hdecq s) as [Hqmatches | Hqnomatch].


    2,3,4: left; intros s1 s2 Hconcat Hlen';
      (* this could maybe use some refactoring.
         But in principle it is simple: I want to do exactly this
         for goals 2,3 and 4.
       *)
      (* now starts: we know what it is when it is split *)
      assert (s1 = []) by (apply length_zero_string_is_empty; assumption);
      assert (s2 = s) by (replace (s1 ++ s2) with s2 in Hconcat by (subst; auto);
                          symmetry;
                          assumption);
      clear Hconcat;
      clear Hlen';
      subst;
      try (now left);
      try (now right).

    + (* this is the case where in fact s matches q, [] matches p *)
      right.
      exists [].
      exists s.
      intros.
      auto.

  - (* induction step *)
    set (l1 := firstn (S n) s).
    set (l2 := skipn (S n) s).

    (* case distinction on the induction hyptohesis (which is an or) *)
    destruct IHn as [IHnAllNoMatch | IHnExistsMatch ].

    (* The case where there is already a match with a smaller split. *)
    2: {
    right.
    destruct IHnExistsMatch as [s1 IHn1].
    destruct IHn1 as [s2 IHn].
    exists s1. exists s2.
    destruct IHn as [H0 [H1 [H2 H3]]].
    repeat split; try assumption.
    lia. }


    (* If none of the earlier splits match. *)
    destruct (Hdecp l1) as [Hpmatch | Hpnomatch].
      destruct (Hdecq l2) as [Hqmatch | Hqnomatch ].

      2,3: left;
      intros s1 s2 Hconcat Hlen;
      assert (length s1 <= n \/ length s1 = S n) as Hlen' by lia;
      destruct Hlen' as [Hlen' | Hlen'];
      try (apply IHnAllNoMatch; assumption); (* case length s1 <= n *)
      try (
          destruct (split_string_lemma s (S n) s1 s2 Hlen' Hconcat) as [Hfoo Hbar];

          replace l1 with s1 in * by auto;
          replace l2 with s2 in * by auto;
          subst;
          try (left; assumption);
          try (right; assumption)).


    + right. exists l1. exists l2. intros.

      repeat split; try assumption.

      * symmetry. apply firstn_skipn.
      * apply firstn_le_length.


        (* The proof below is the proof for 2,3, but written with periods instead of semicolons...
           the periods are easier to step through, and it is also how I wrote it.
           But as I've said above, I don't know how to do that for 2 goals at the same time.

         *)
        (*
    +
      left.
      intros s1 s2 Hconcat Hlen.

      assert (length s1 <= n \/ length s1 = S n) as Hlen' by lia.
      destruct Hlen' as [Hlen' | Hlen'].

      * apply IHnAllNoMatch; assumption. (* case length s1 <= n *)
      * destruct (split_string_lemma s (S n) s1 s2 Hlen' Hconcat) as [Hfoo Hbar].

        replace l1 with s1 in * by auto.
        replace l2 with s2 in * by auto.
        subst.
        try (left; assumption).
        try (right; assumption).
*)

Qed.

Lemma denotation_concat_is_decidable (p q: regex):
  regex_is_decidable p ->
  regex_is_decidable q ->
  regex_is_decidable (concat p q).
Proof.
  intros Hdecp Hdecq.
  unfold regex_is_decidable.
  intro s.
  destruct (denotation_concat_is_decidable_helper p q Hdecp Hdecq s (length s))
  as [HAllDontMatch | HExistsMatch].

  - right.
    unfold not.
    intro HmatchContr.
    destruct HmatchContr as [s [s1 [s2 [Hconcat [Hmatchp Hmatchq]]]]].
    symmetry in Hconcat.

    set (Hlen := substrings_have_smaller_length s s1 s2 Hconcat).

    specialize HAllDontMatch with s1 s2.
    destruct (HAllDontMatch Hconcat Hlen); auto.

  - left.
    destruct HExistsMatch as [s1 [s2 [Hconcat [Hlen [Hmatchp Hmatchq]]]]].
    constructor.
    symmetry in Hconcat.
    exists s1. exists s2. exists Hconcat.
    split; assumption.
Qed.
