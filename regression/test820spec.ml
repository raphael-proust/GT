open GT

type 'a maybe = Just of 'a | Nothing [@@deriving gt ~options: { show } ]

module P = struct
  type t = (int -> string) maybe
  [@@deriving gt ~options:{ show={ _1 = (fun _ -> "<fun>")  } }]
end

let () =
  Printf.printf "%s\n%!" @@ P.show_t @@  Just (fun x -> "?")

module O = struct
  type t = { a:int; b:(string [@opaque]) } [@@deriving gt ~options: { show } ]
end

let () =
  Printf.printf "%s\n%!" @@ O.show_t { O.a = 5; O.b = "asdf" }