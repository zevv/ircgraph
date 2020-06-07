
import npeg, tables, hashes, math, strutils, strformat

type

  Id = int

  IdPair = object
    id1, id2: Id

var nickToId: Table[string, Id]
var talk: Table[Id, int]
var dialogue: Table[IdPair, float]
var ping: Table[IdPair, bool]
var mention: Table[IdPair, bool]
var talkMax: int
var dialogueMax: float

proc hash(p: IdPair): Hash = 
  hash(p.id1) !& hash(p.id2)

var
  idSeq, id, pid: Id
  pt: int


proc mkColor(r, g, b: float): string = 
  let (ri, gi, bi) = (int(r * 255.99), int(g*255.99), int(b * 255.99))
  &"#{ri:02x}{gi:02x}{bi:02x}"


proc mkIdPair(id1, id2: Id): IdPair =
  if id1.int <= id2.int:
    IdPair(id1: id1, id2: id2)
  else:
    IdPair(id1: id2, id2: id1)


proc log(nick: string, t: int, msg: string) =

  if nick.find('"') != -1:
    return

  if nick notin nickToId:
    nickToId[nick] = idSeq
    inc idSeq
  
  id = nickToId[nick]

  if id notin talk:
    talk[id] = 0

  inc talk[id]
  talkMax = max(talkMax, talk[id])

  let words = peg words:
    word <- >?'@' * >+(1 - space) * >?':':
      let nick = $2
      if nick in nickToId:
        let id2 = nickToId[nick]
        let p = mkIdPair(id, id2)
        if len($1) > 0 or len($3) > 0:
          ping[p] = true
        else:
          mention[p] = true

    space <- ' ' | ',' | '.' | '!' | '?'
    words <- *(word * +space)

  discard words.match(msg)

  if id != pid:

    var p = mkIdPair(id, pid)
    if p notin dialogue:
      dialogue[p] = 0.0

    let dt = t - pt
    let t = 1.0 / float(dt + 1)
    dialogue[p] += t
    dialogueMax = max(dialogueMax, dialogue[p])
  
  pid = id
  pt = t


#
# Parse log lines
#

let p = peg nim:
  nim <- time * " #nim: " * ?bridge * '<' * *' ' * >nick * '>' * ' ' * >*1:
    let (h, m, nick, msg) = (parseInt($1), parseInt($2), $3, $4)
    let t = h * 60 + m
    log(nick, t, msg)

  bridge <- "< FromDiscord> " | "< FromGitter> "
  time <- >(Digit * Digit) * ':' * >(Digit * Digit)
  nick <- * +(1-'>')

for l in lines(stdin):
  let r = p.match(l)


#
# Generate dot graph
#

echo """
graph dialogue {
  start = 0;
  bgcolor = "#202020";
  overlap = false;
  node [ shape=rectangle, style="filled,rounded", width=0, height=0, fontname=Helvetica ];
"""

var seen: Table[Id, bool]

for p, t in dialogue:
  let tRel = t / dialogueMax
  if tRel > 0.07: # Ignore bottom 10%
    let width = sqrt(tRel) * 5

    let color =
      if p in ping:       mkcolor(0.0, 0.7, 0.0)
      elif p in mention:  mkcolor(0.7, 0.7, 0.4)
      else:               mkcolor(0.7, 0.7, 0.7)

    echo &"""  n{p.id1} -- n{p.id2} [ penwidth={width:.1f} color="{color}" ];"""
    seen[p.id1] = true
    seen[p.id2] = true

for nick, id in nickToId:
  if id in seen:
    let f = (talk[id] / talkMax) * 0.3 + 0.5
    let color = mkColor(f, f, f)
    let fontsize = int(8 + (talk[id] / talkMax) * 4)
    echo &"""  n{id} [ label="{nick}", fillcolor="{color}", color="#777777", fontsize={fontsize} ];"""

echo "}"

