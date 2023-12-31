(* auxiliares *)

let rec lookup amb x  =
  match amb with
    [] -> None
  | (y, item) :: tl -> if (y=x) then Some item else lookup tl x

let rec update amb x item  =
  (x,item) :: amb


(* remove elementos repetidos de uma lista *)
let nub l =
  let ucons h t = if List.mem h t then t else h::t in
  List.fold_right ucons l []


(* calcula  l1 - l2 (como sets) *)
let diff (l1:'a list) (l2:'a list) : 'a list =
  List.filter (fun a -> not (List.mem a l2)) l1


(* tipos de L1 *)

type tipo =
    TyInt
  | TyBool
  | TyFn     of tipo * tipo
  | TyPair   of tipo * tipo
  | TyVar    of int   (* variáveis de tipo -- números *)

(* TRABALHO: NOVOS TIPOS *)
  | TyList of tipo
  | TyMaybe of tipo
  | TyEither of tipo * tipo

type politipo = (int list) * tipo


(* free type variables em um tipo *)

let rec ftv (tp:tipo) : int list =
  match tp with
    TyInt
  | TyBool -> []
  | TyFn(t1,t2)
  | TyPair(t1,t2) ->  (ftv t1) @ (ftv t2)
  | TyVar n      -> [n]



(* impressao legível de monotipos  *)

let rec tipo_str (tp:tipo) : string =
  match tp with
    TyInt           -> "int"
  | TyBool          -> "bool"
  | TyFn   (t1,t2)  -> "("  ^ (tipo_str t1) ^ "->" ^ (tipo_str t2) ^ ")"
  | TyPair (t1,t2)  -> "("  ^ (tipo_str t1) ^  "*" ^ (tipo_str t2) ^ ")"
  | TyVar  n        -> "X" ^ (string_of_int n)
(* TRABALHO: NOVAS IMPRESSÕES *)
  | TyList t        -> (tipo_str t) ^ " List"
  | TyMaybe t       -> (tipo_str t) ^ " Maybe"
  | TyEither (t1,t2) -> (tipo_str t1) ^ " | " ^ (tipo_str t2)



(* expressões de L1 sem anotações de tipo   *)

type ident = string

type bop = Sum | Sub | Mult | Eq | Gt | Lt | Geq | Leq

type expr  =
    Num    of int
  | Bool   of bool
  | Var    of ident
  | Binop  of bop * expr * expr
  | Pair   of expr * expr
  | Fst    of expr
  | Snd    of expr
  | If     of expr * expr * expr
  | Fn     of ident * expr
  | App    of expr * expr
  | Let    of ident * expr * expr
  | LetRec of ident * ident * expr * expr
(* TRABALHO: NOVAS EXPRESSÕES *)
  | Pipe of expr * expr
  | PipeRec of expr * expr
  | Nil
  | Cons of expr * expr
  | MatchList of expr * expr * expr
  | Nothing
  | Just of expr
  | MatchMaybe of expr * expr * expr
  | Left of expr
  | Right of expr
  | MatchEither of expr * expr * expr            


(* impressão legível de expressão *)

let rec expr_str (e:expr) : string  =
  match e with
    Num n   -> string_of_int  n
  | Bool b  -> string_of_bool b
  | Var x -> x
  | Binop (o,e1,e2) ->
      let s = (match o with
            Sum  -> "+"
          | Sub  -> "-"
          | Mult -> "*"
          | Leq  -> "<="
          | Geq  -> ">="
          | Eq   -> "="
          | Lt   -> "<"
          | Gt   -> ">") in
      "( " ^ (expr_str e1) ^ " " ^ s ^ " " ^ (expr_str e2) ^ " )"
  | Pair (e1,e2) ->  "(" ^ (expr_str e1) ^ "," ^ (expr_str e2) ^ ")"
  | Fst e1 -> "fst " ^ (expr_str e1)
  | Snd e1 -> "snd " ^ (expr_str e1)
  | If (e1,e2,e3) -> "(if " ^ (expr_str e1) ^ " then "
                     ^ (expr_str e2) ^ " else "
                     ^ (expr_str e3) ^ " )"
  | Fn (x,e1) -> "(fn " ^ x ^ " => " ^ (expr_str e1) ^ " )"
  | App (e1,e2) -> "(" ^ (expr_str e1) ^ " " ^ (expr_str e2) ^ ")"
  | Let (x,e1,e2) -> "(let " ^ x ^ "=" ^ (expr_str e1) ^ "\nin "
                     ^ (expr_str e2) ^ " )"
  | LetRec (f,x,e1,e2) -> "(let rec " ^ f ^ "= fn " ^ x ^ " => "
                          ^ (expr_str e1) ^ "\nin " ^ (expr_str e2) ^ " )"
(* TRABALHO: NOVAS IMPRESSÕES *)
  | Pipe (e1, e2) -> expr_str e1 ^ "|>" ^ expr_str e2
  | PipeRec (e1, e2) -> expr_str e1 ^ "|>^" ^ expr_str e2
  | Nil -> "[]"
  | Cons (e1,e2) -> (expr_str e1) ^ "::" ^ (expr_str e2)
  | MatchList (e1,e2,e3) -> "(match " ^ (expr_str e1) ^ " with [] => "
                        ^ (expr_str e2) ^ " | x::xs => " ^ (expr_str e3) ^ " )"
  | Nothing -> "nothing"
  | Just e1 -> "(just " ^ (expr_str e1) ^ " )"
  | MatchMaybe (e1,e2,e3) -> "(match " ^ (expr_str e1) ^ " with nothing => "
                        ^ (expr_str e2) ^ " | just x => " ^ (expr_str e3) ^ " )"
  | Left e1 -> "(left " ^ (expr_str e1) ^ " )"
  | Right e1 -> "(right " ^ (expr_str e1) ^ " )"
  | MatchEither (e1,e2,e3) -> "(match " ^ (expr_str e1) ^ " with left x => "
                        ^ (expr_str e2) ^ " | right y => " ^ (expr_str e3) ^ " )"



(* ambientes de tipo - modificados para polimorfismo *)

type tyenv = (ident * politipo) list


(* calcula todas as variáveis de tipo livres
do ambiente de tipos *)
let rec ftv_amb' (g:tyenv) : int list =
  match g with
    []           -> []
  | (x,(vars,tp))::t  -> (diff (ftv tp) vars)  @  (ftv_amb' t)


let ftv_amb (g:tyenv) : int list = nub (ftv_amb' g)



(* equações de tipo  *)

type equacoes_tipo = (tipo * tipo) list

(*
   a lista
       [ (t1,t2) ; (u1,u2) ]
representa o conjunto de equações de tipo
  { t1=t2, u1=u2 }
*)


(* imprime equações *)

let rec print_equacoes (c:equacoes_tipo) =
  match c with
    []       ->
      print_string "\n";
  | (a,b)::t ->
      print_string (tipo_str a);
      print_string " = ";
      print_string (tipo_str b);
      print_string "\n";
      print_equacoes t



(* código para geração de novas variáveis de tipo *)

let lastvar = ref 0

let newvar (u:unit) : int =
  let x = !lastvar
  in lastvar := (x+1) ; x

(* substituições de tipo *)

type subst = (int * tipo) list


(* imprime substituições  *)

let rec print_subst (s:subst) =
  match s with
    []       ->
      print_string "\n";
  | (a,b)::t ->
      print_string ("X" ^ (string_of_int a));
      print_string " |-> ";
      print_string (tipo_str b);
      print_string "\n";
      print_subst t


(* aplicação de substituição a tipo *)

let rec appsubs (s:subst) (tp:tipo) : tipo =
  match tp with
    TyInt             -> TyInt
  | TyBool            -> TyBool
  | TyFn     (t1,t2)  -> TyFn     (appsubs s t1, appsubs s t2)
  | TyPair   (t1,t2)  -> TyPair   (appsubs s t1, appsubs s t2)
  | TyVar  x        -> (match lookup s x with
        None        -> TyVar x
      | Some tp'    -> tp')
(* TRABALHO: NOVAS SUBSTITUIÇÕES *)
  | TyList t1       -> TyList (appsubs s t1)
  | TyMaybe t1      -> TyMaybe (appsubs s t1)
  | TyEither (t1,t2) -> TyEither (appsubs s t1, appsubs s t2)



(* aplicação de substituição a coleção de constraints *)
let rec appconstr (s:subst) (c:equacoes_tipo) : equacoes_tipo =
  List.map (fun (a,b) -> (appsubs s a,appsubs s b)) c



(* composição de substituições: s1 o s2  *)
let rec compose (s1:subst) (s2:subst) : subst =
  let r1 = List.map (fun (x,y) -> (x, appsubs s1 y))      s2 in
  let (vs,_) = List.split s2                                 in
  let r2 = List.filter (fun (x,y) -> not (List.mem x vs)) s1 in
  r1@r2


(* testa se variável de tipo ocorre em tipo *)

let rec var_in_tipo (v:int) (tp:tipo) : bool =
  match tp with
    TyInt             -> false
  | TyBool            -> false
  | TyFn     (t1,t2)  -> (var_in_tipo v t1) || (var_in_tipo v t2)
  | TyPair   (t1,t2)  -> (var_in_tipo v t1) || (var_in_tipo v t2)
  | TyVar  x          -> v=x
(* TRABALHO: NOVAS TESTAGENS DE OCORRÊNCIA DE VARIÁVEL *)
  | TyList t          -> var_in_tipo v t
  | TyMaybe t         -> var_in_tipo v t
  | TyEither (t1,t2)  -> (var_in_tipo v t1) || (var_in_tipo v t2)

(* cria novas variáveis para politipos quando estes são instanciados *)

let rec renamevars (pltp : politipo) : tipo =
  match pltp with
    ( []       ,tp)  -> tp
  | ((h::vars'),tp)  -> let h' = newvar() in
      appsubs [(h,TyVar h')] (renamevars (vars',tp))


(* unificação *)

exception UnifyFail of (tipo*tipo)

let rec unify (c:equacoes_tipo) : subst =
  match c with
    []                                    -> []
  | (TyInt,TyInt)  ::c'                   -> unify c'
  | (TyBool,TyBool)::c'                   -> unify c'
  | (TyFn(x1,y1),TyFn(x2,y2))::c'         -> unify ((x1,x2)::(y1,y2)::c')
  | (TyPair(x1,y1),TyPair(x2,y2))::c'     -> unify ((x1,x2)::(y1,y2)::c')
  | (TyVar x1, TyVar x2)::c' when x1=x2   -> unify c'
(* TRABALHO: NOVOS UNIFY *)
  | (TyList tp1,TyList tp2)::c'            -> unify ((tp1,tp2)::c')
  | (TyMaybe tp1,TyMaybe tp2)::c'          -> unify ((tp1,tp2)::c')
  | (TyEither (x1,y1),TyEither (x2,y2))::c' -> unify ((x1,x2)::(y1,y2)::c')
(* Os matchs adicionados tem que ocorrer antes dos matchs abaixo*)
  | (TyVar x1, tp2)::c'                  -> if var_in_tipo x1 tp2
      then raise (UnifyFail(TyVar x1, tp2))
      else compose
          (unify (appconstr [(x1,tp2)] c'))
          [(x1,tp2)]

  | (tp1,TyVar x2)::c'                  -> if var_in_tipo x2 tp1
      then raise (UnifyFail(tp1,TyVar x2))
      else compose
          (unify (appconstr [(x2,tp1)] c'))
          [(x2,tp1)]

  | (tp1,tp2)::c' -> raise (UnifyFail(tp1,tp2))





exception CollectFail of string


let rec collect (g:tyenv) (e:expr) : (equacoes_tipo * tipo)  =

  match e with
    Var x   ->
      (match lookup g x with
         None        -> raise (CollectFail x)
       | Some pltp -> ([],renamevars pltp))  (* instancia poli *)

  | Num n -> ([],TyInt)

  | Bool b  -> ([],TyBool)

  | Binop (o,e1,e2) ->
      if List.mem o [Sum;Sub;Mult]
      then
        let (c1,tp1) = collect g e1 in
        let (c2,tp2) = collect g e2 in
        (c1@c2@[(tp1,TyInt);(tp2,TyInt)] , TyInt)
      else
        let (c1,tp1) = collect g e1 in
        let (c2,tp2) = collect g e2 in
        (c1@c2@[(tp1,TyInt);(tp2,TyInt)] , TyBool)

  | Pair (e1,e2) ->
      let (c1,tp1) = collect g e1 in
      let (c2,tp2) = collect g e2 in
      (c1@c2, TyPair(tp1,tp2))

  | Fst e1 ->
      let tA = newvar() in
      let tB = newvar() in
      let (c1,tp1) = collect g e1 in
      (c1@[(tp1,TyPair(TyVar tA, TyVar tB))], TyVar tA)

  | Snd e1 ->
      let tA = newvar() in
      let tB = newvar() in
      let (c1,tp1) = collect g e1 in
      (c1@[(tp1,TyPair(TyVar tA,TyVar tB))], TyVar tB)

  | If (e1,e2,e3) ->
      let (c1,tp1) = collect g e1 in
      let (c2,tp2) = collect g e2 in
      let (c3,tp3) = collect g e3 in
      (c1@c2@c3@[(tp1,TyBool);(tp2,tp3)], tp2)

  | Fn (x,e1) ->
      let tA       = newvar()           in
      let g'       = (x,([],TyVar tA)):: g in
      let (c1,tp1) = collect g' e1      in
      (c1, TyFn(TyVar tA,tp1))

  | App (e1,e2) ->
      let (c1,tp1) = collect  g e1 in
      let (c2,tp2) = collect  g e2  in
      let tA       = newvar()       in
      (c1@c2@[(tp1,TyFn(tp2,TyVar tA))]
      , TyVar tA)


  | Let (x,e1,e2) ->
      let (c1,tp1) = collect  g e1                    in

      let s1       = unify c1                         in
      let tf1      = appsubs s1 tp1                   in
      let polivars = nub (diff (ftv tf1) (ftv_amb g)) in
      let g'       = (x,(polivars,tf1))::g            in

      let (c2,tp2) = collect  g' e2                   in
      (c1@c2, tp2)

  | LetRec (f,x,e1,e2) ->
      let tA = newvar() in
      let tB = newvar() in
      let g2 = (f,([],TyFn(TyVar tA,TyVar tB)))::g            in
      let g1 = (x,([],TyVar tA))::g2                          in
      let (c1,tp1) = collect g1 e1                          in

      let s1       = unify (c1@[(tp1,TyVar tB)])            in
      let tf1      = appsubs s1 (TyFn(TyVar tA,TyVar tB))   in
      let polivars = nub (diff (ftv tf1) (ftv_amb g))       in
      let g'       = (f,(polivars,tf1))::g                    in

      let (c2,tp2) = collect g' e2                          in
      (c1@[(tp1,TyVar tB)]@c2, tp2)

(* 
TRABALHO

  COLEÇÕES ADICIONAIS A PARTIR DAQUI
  VER SLIDE 167 PARA ALGUMAS REGRAS DE COLETA
*)

(* E1 |> E2 *)
  | Pipe (e1,e2) ->
      let (c1,tp1) = collect  g e1 in
      let (c2,tp2) = collect  g e2 in
      let tA = newvar() in
      (c1@c2@[(tp2, TyFn(tp1, TyVar tA))], TyVar tA) (* Tipo T2 deve ser igual a T1->X *)

  | PipeRec (e1,e2) ->
      let (c1,tp1) = collect  g e1 in
      let (c2,tp2) = collect  g e2  in
      let tA       = newvar()       in
      (c1@c2@[(tp1,TyFn(tp2,TyVar tA))]
      , TyVar tA)

(* NIL | E1::E2 *)
  | Nil ->
      let tA = newvar() in
      ([], TyList (TyVar tA))

  | Cons (e1,e2) ->
      let (c1,tp1) = collect g e1 in
      let (c2,tp2) = collect g e2 in
      (c1@c2@[(tp2,TyList tp1)], tp2)

  (* match e1 with [] => e2 | x::xs => e3 *)
  | MatchList (e1,e2,e3) ->
      let tA = newvar() in
      let (c1,tp1) = collect g e1 in
      let (c2,tp2) = collect g e2 in
      let (c3,tp3) = collect g e3 in
      (c1@c2@c3@[(tp1,TyList (TyVar tA));(tp2, tp3)], tp2)     

  (* nothing | just e *)
  | Nothing ->
      let tA = newvar() in
      ([], TyMaybe (TyVar tA))

  | Just e1 ->
      let (c1,tp1) = collect g e1 in
      (c1, TyMaybe tp1)

  | MatchMaybe (e1,e2,e3) ->
      let tA = newvar() in
      let (c1,tp1) = collect g e1 in
      let (c2,tp2) = collect g e2 in
      let (c3,tp3) = collect g e3 in
      (c1@c2@c3@[(tp1,TyMaybe (TyVar tA));(tp2, tp3)], tp2)

        (* match e1 with nothing => e2 | just x => e3 *)
        (* left e | right e *)
        (* match e1 with left x => e2 | right y => e3 *) 

  | Left e1 ->
    let tA = newvar() in
    let (c1,tp1) = collect g e1 in
    (c1, TyEither (tp1,TyVar tA))

  | Right e1 ->
    let tA = newvar() in
    let (c1,tp1) = collect g e1 in
    (c1, TyEither (TyVar tA,tp1))

  | MatchEither (e1,e2,e3) ->
    let tA = newvar() in
    let tB = newvar() in
    let (c1,tp1) = collect g e1 in
    let (c2,tp2) = collect g e2 in
    let (c3,tp3) = collect g e3 in
    (c1@c2@c3@[(tp1,TyEither (TyVar tA,TyVar tB));(tp2,tp3)],tp2)


(* INFERÊNCIA DE TIPOS - CHAMADA PRINCIPAL *)

let type_infer (e:expr) : unit =
  print_string "\nExpressão:\n";
  print_string (expr_str e);
  print_string "\n\n";
  try
    let (c,tp) = collect [] e  in
    print_string "\nEquações de tipo coletadas:\n";
    print_equacoes c;
    print_string "Tipo inferido: ";
    print_string (tipo_str tp);
    print_string "\n";
    let s      = unify c       in
    print_string "\nSubstituição produzida por unify:\n";
    print_subst s;
    let tf     = appsubs s tp  in
    print_string "Tipo inferido (após subs): ";
    print_string (tipo_str tf);
    print_string "\n\n"

  with

  | CollectFail x   ->
      print_string "Erro: variável ";
      print_string x;
      print_string "não declarada!\n\n"

  | UnifyFail (tp1,tp2) ->
      print_string "Erro: impossível unificar os tipos\n* ";
      print_string (tipo_str tp1);
      print_string "\n* ";
      print_string (tipo_str tp2);
      print_string "\n\n"


(*===============================================*)

type valor =
    VNum   of int
  | VBool  of bool
  | VPair  of valor * valor
  | VClos  of ident * expr * renv
  | VRclos of ident * ident * expr * renv
(* TRABALHO: NOVOS VALORES *)
  | VList of valor list
  | VMaybe of valor option
  (* | VEither of valor option * valor option *)
  | VJust of valor
  | VLeft of valor 
  | VRight of valor 
and
  renv = (ident * valor) list

exception BugTypeInfer
exception DivZero

let compute (oper: bop) (v1: valor) (v2: valor) : valor =
  match (oper, v1, v2) with
    (Sum, VNum(n1), VNum(n2)) -> VNum (n1 + n2)
  | (Sub, VNum(n1), VNum(n2)) -> VNum (n1 - n2)
  | (Mult, VNum(n1),VNum(n2)) -> VNum (n1 * n2)
  | (Eq, VNum(n1), VNum(n2))  -> VBool (n1 = n2)
  | (Gt, VNum(n1), VNum(n2))  -> VBool (n1 > n2)
  | (Lt, VNum(n1), VNum(n2))  -> VBool (n1 < n2)
  | (Geq, VNum(n1), VNum(n2)) -> VBool (n1 >= n2)
  | (Leq, VNum(n1), VNum(n2)) -> VBool (n1 <= n2)
  | _ -> raise BugTypeInfer


let rec eval (renv:renv) (e:expr) : valor =
  match e with
    Num n -> VNum n

  | Bool b -> VBool b

  | Var x ->
      (match lookup renv x with
         None -> raise BugTypeInfer
       | Some v -> v)

  | Binop(oper,e1,e2) ->
      let v1 = eval renv e1 in
      let v2 = eval renv e2 in
      compute oper v1 v2

  | Pair(e1,e2) ->
      let v1 = eval renv e1 in
      let v2 = eval renv e2
      in VPair(v1,v2)

  | Fst e ->
      (match eval renv e with
       | VPair(v1,_) -> v1
       | _ -> raise BugTypeInfer)

  | Snd e ->
      (match eval renv e with
       | VPair(_,v2) -> v2
       | _ -> raise BugTypeInfer)


  | If(e1,e2,e3) ->
      (match eval renv e1 with
         VBool true  -> eval renv e2
       | VBool false -> eval renv e3
       | _ -> raise BugTypeInfer )

  | Fn (x,e1) ->  VClos(x,e1,renv)

  | App(e1,e2) ->
      let v1 = eval renv e1 in
      let v2 = eval renv e2 in
      (match v1 with
         VClos(x,ebdy,renv') ->
           let renv'' = update renv' x v2
           in eval renv'' ebdy

       | VRclos(f,x,ebdy,renv') ->
           let renv''  = update renv' x v2 in
           let renv''' = update renv'' f v1
           in eval renv''' ebdy
       | _ -> raise BugTypeInfer)

  | Let(x,e1,e2) ->
      let v1 = eval renv e1
      in eval (update renv x v1) e2

  | LetRec(f,x,e1,e2)  ->
      let renv'= update renv f (VRclos(f,x,e1,renv))
      in eval renv' e2
(* TRABALHO: NOVAS AVALIAÇÕES *)
  | Pipe (e1, e2) ->
      eval renv (App(e2, e1))
  | PipeRec (e1, e2) ->
    let v1 = eval renv e1 in
    let v2 = eval renv e2 in
    (match v1 with
       VClos(x,ebdy,renv') ->
         let renv'' = update renv' x v2
         in eval renv'' ebdy

     | VRclos(f,x,ebdy,renv') ->
         let renv''  = update renv' x v2 in
         let renv''' = update renv'' f v1
         in eval renv''' ebdy
     | _ -> raise BugTypeInfer)
  | Nil ->
      VList []
  | Cons (e1, e2) ->
      let v1 = eval renv e1 in
      let v2 = eval renv e2 in
      VList (v1 :: v2 :: [])

  | MatchList (e1,e2,e3) ->
      (match eval renv e1 with
       | VList [] -> eval renv e2
       | VList (v1 :: v2 :: []) ->
           eval renv e3
       | _ -> raise BugTypeInfer)

  | Nothing ->
      VMaybe None

  | Just e1 ->
      let v1 = eval renv e1 in
      VMaybe (Some v1)

  | MatchMaybe (e1,e2,e3) ->
      (match eval renv e1 with
       | VMaybe None -> eval renv e2
       | VMaybe (Some v1) ->
            eval renv e3
       | _ -> raise BugTypeInfer)

  | Left e1 ->
      let v1 = eval renv e1 in
      VLeft (v1)

  | Right e1 ->
      let v1 = eval renv e1 in
      VRight (v1)

  | MatchEither (e1,e2,e3) ->
      (match eval renv e1 with
       | VLeft (va) -> eval renv e2
       | VRight (vb) -> eval renv e3
       | _ -> raise BugTypeInfer)

  



(* EXEMPLOS PARA TESTE *)
(* PIPE 
   O exemplo 1 de L1 implícita, com |> substituindo App
*)
(*   (y-1)              *)
let ys1 = Binop(Sub, Var "y", Num 1)

(*   pow x (y-1)        *)
let powapp  =   App(App(Var "pow", Var "x"), ys1)

(*   x*(pow x (y-1))    *)
let xp =   Binop(Mult, Var "x", powapp)


(*   if y=0 then 1 else x*(pow x (y-1))    *)
let ebdy =  Fn("y", If(Binop(Eq, Var "y", Num 0) , Num 1, xp))


(*  let rec pow = fn x => ... in (pow 3) 4 *)

let ex1 =
  LetRec("pow", "x", ebdy, Pipe(Num 4, Pipe(Num 3, Var "pow")))

  (* test nothing *)
let ex2 = LetRec("pow", "x", ebdy, Pipe(Num 4, Pipe(Num 3, Nothing)))

(* test just *)
let ex3 = LetRec("pow", "x", ebdy, Pipe(Num 4, Pipe(Num 3, Just (Num 2))))

(* test match *)
let ex4 = LetRec("pow", "x", ebdy, Pipe(Num 4, Pipe(Num 3, MatchList(Var "x", Num 0, Num 1))))

(* testing cons*)
(* eval [] (Cons( Num 1, (Cons (Num 2, (Cons (Num 3, Nil))))))
type_infer(Cons( Num 1, (Cons (Num 2, (Cons (Num 3, Nil)))))) *)

(* testing MatchWnil*)
(* eval [] (MatchList ((Cons( Num 1, (Cons (Num 2, (Cons (Num 3, Nil)))))), Num 0, Num 1))

eval [] (MatchList (Nil, Num 0, Num 1))

type_infer(MatchList ((Cons( Num 1, (Cons (Num 2, (Cons (Num 3, Nil)))))), Num 0, Num 1)) *)

(*testing Just*)
(* eval [] (Just (Num 1))
type_infer(Just (Num 1)) *)

(*testing Nothing*)
(* eval [] (Nothing)
type_infer(Nothing) *)


(* testinf MatchMaybe*)
(* eval [] (MatchMaybe (Nothing, Num 0, Num 1))
type_infer(MatchMaybe (Nothing, Num 0, Num 1)) *)

(* testing Left*)
(* eval [] (Left (Num 1)) *)
(* type_infer(Left (Num 1)) *)

(* testing Right*)
(* eval [] (Right (Num 1)) *)
(* type_infer(Right (Num 1)) *)

(* testing MatchEither*)
(* eval [] (MatchEither (Left (Num 1), Num 0, Num 1)) *)
(* type_infer(MatchEither (Left (Num 1), Num 0, Num 1)) *)

(*testing either with two different types*)
(* eval [] (MatchEither (Left (Bool True), Num 0, Num 1.0)) *)
