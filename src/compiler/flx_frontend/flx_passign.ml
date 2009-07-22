open Flx_util
open Flx_ast
open Flx_types
open Flx_print
open Flx_set
open Flx_mtypes2
open Flx_typing
open Flx_mbind
open List
open Flx_unify
open Flx_treg
open Flx_generic
open Flx_maps
open Flx_exceptions
open Flx_use
open Flx_child
open Flx_call

type aentry_t =
  int *
  (string * btypecode_t * tbexpr_t * IntSet.t)


(* Parallel Assignment algorithm.
   Given a set of assignments, xi = ei,
   we need a sequence of assignments of xi, ei, tj,
   where tj are fresh variables, xi on left, ei on
   right, and tj on either side, such that no RHS
   term depends on a prior LHS term.

   A pair x1 = e1, x2 = e2 which are mutually dependent
   can always by resolved as

   t1 = e1; x2 = e2; x1 = t1

   Here e1 doesn't depend on a prior term, vaccuously,
   e2 can't depend on t1 since it is fresh, and
   t1 can't depend on anything, since it just a fresh variable

   Let's start by taking the equations, and making
   two lists -- a head list and a tail list.
   Head assignments are done first, tails last,
   the head list is in reverse order.

   Any equations setting variables no one depends on
   can be moved into the head list, they can safely
   be done first.

   Any equations whose RHS depend on nothing are
   moved into the tail list, its safe to do them last.

   Any dependencies on variables set by equations
   moved into the tail list can now be removed
   from the remaining equations, since it is determined
   now that these variables will be changed after
   any of the remaining assignments are one.

   Repeat until the set of remaining equations is fixed.

   We can now pick (somehow!!) an equation, and break
   it into two using a fresh temporary. The temporary
   assignment goes on the head list, the variable
   assignment from the temporary on the tail list,
   and as above, any dependencies on the variable
   can now be removed from the remaining equations.

   Repeat everything until the set of remaining
   equations is empty, the result is the reverse
   of the heap list plus the tail list.

   This process is certain to terminate, since
   each outer step removes one equation,
   and it is certain to be correct (obvious).

   What is NOT clear is that the result is minimal.
   And it is NOT clear how to best 'choose' which
   equation to split.
*)


(* Parallel Assignment Algorithm *)

(* input: a list of equations of the form
  x = expr

Represented by:

    i,(name,t,e,u)

where

  i = the LHS target
  name = the LHS target name for debug purpose
  t = the LHS type
  e = the RHS expression
  u = an IntSet of all the symbols used in e
      being a subset of the set of all the LHS variables
      but including any indirect use!

Output:

  A sequence of assignments minimising temporary usage
  IN REVERSE ORDER

*)

let passign syms bbdfns (pinits:aentry_t list) ts' sr =
  let parameters = ref [] in
  (* strip trivial assignments like x = x *)
  let pinits =
    filter
    (fun (i,(name,t,e,u)) ->
      match e with
      | BEXPR_name (j,_),_ when i = j -> false
      | _ -> true
    )
    pinits
  in
  let fixdeps pinits =
    let vars = fold_left (fun s (i,_) -> IntSet.add i s) IntSet.empty pinits in
    map
    (fun (i,(name,t,e,u)) ->
      let u = IntSet.remove i (IntSet.inter u vars) in
      i,(name,t,e,u)
    )
    pinits
  in
  (*
  iter
  (fun (i,(name,t,e,u)) ->
    print_endline ("ASG " ^ name ^ "<"^si i ^ "> = " ^ sbe syms.dfns bbdfns e);
    print_string "  Depends: ";
      IntSet.iter (fun i -> print_string (si i ^ ", ")) u;
    print_endline "";
  )
  pinits;
  *)
  (* this function measures if the expression assigning i
  depends on the old value of j
  *)
  let depend pinits i j =
     let u = match assoc i pinits with _,_,_,u -> u in
     IntSet.mem j u
  in
  (* return true if an assignment in inits depends on j *)
  let used j inits =
    fold_left (fun r (i,_)-> r or depend inits i j) false inits
  in
  let rec aux ((head, middle, tail) as arg) = function
    | [] -> arg
    | (i,(name,ty,e,u)) as h :: ta ->
      if IntSet.cardinal u = 0 then
        aux (head,middle,h::tail) ta
      else if not (used i (middle @ ta)) then
        aux (h::head, middle, tail) ta
      else
        aux (head,h::middle,tail) ta
  in

  let printem (h,m,t) =
    print_endline "HEAD:";
    iter
    (fun (i,(name,t,e,u)) ->
      print_endline ("ASG " ^ name ^ "<"^si i ^ "> = " ^ sbe syms.dfns bbdfns e)
    )
    h;

    print_endline "MIDDLE:";
    iter
    (fun (i,(name,t,e,u)) ->
      print_endline ("ASG " ^ name ^ "<"^si i ^ "> = " ^ sbe syms.dfns bbdfns e)
    )
    m;

    print_endline "TAIL:";
    iter
    (fun (i,(name,t,e,u)) ->
      print_endline ("ASG " ^ name ^ "<"^si i ^ "> = " ^ sbe syms.dfns bbdfns e)
    )
    t
  in

  let rec aux2 (hh,mm,tt) =
    let h,m,t = aux ([],[],[]) (fixdeps mm) in
    (* printem (h,m,t); *)
    (* reached a fixpoint? *)
    if length h = 0 && length t = 0 then hh,m,tt (* m = mm *)
    else begin
      (*
      print_endline "Recursing on MIDDLE";
      *)
      aux2 (h @ hh, m, t @ tt)
    end
  in
  let tmplist = ref [] in
  let rec aux3 (hh,mm,tt) =
    let h,m,t = aux2 (hh,mm,tt) in
    (*
    print_endline "SPLIT STEP result:";
    printem(h,m,t);
    *)
    match m with
    | [] -> rev h @ t
    | [_] -> assert false
    | (i,(name,ty,e,u)) :: ta ->
      let k = !(syms.counter) in incr syms.counter;
      let name2 = "_tmp_" ^ name in
      parameters := (ty,k) :: !parameters;
      tmplist := k :: !tmplist;
      let h' = k,(name2,ty,e,IntSet.empty) in
      let e' = BEXPR_name (k,ts'),ty in
      let t' = i,(name,ty,e',IntSet.empty) in
      aux3 (h' :: h, ta, t' :: t)
  in
  let m = aux3 ([],pinits,[]) in
  (*
  print_endline "FINAL SPLIT UP:";
  iter
  (fun (i,(name,t,e,u)) ->
    print_endline ("ASG " ^ name ^ "<"^si i ^ "> = " ^ sbe syms.dfns bbdfns e)
  )
  m;
  *)
  let result = ref [] in
  result :=  `BEXE_comment (sr,"parallel assignment") :: !result;
  iter
  (fun (i,(name,ty,e,_)) ->
    if mem i !tmplist then
      result := `BEXE_begin :: !result;
    result := `BEXE_init (sr,i,e) :: !result;
  )
  m;
  while length !tmplist > 0 do
    result := `BEXE_end :: !result;
    tmplist := tl !tmplist
  done;
  !parameters, !result
