-- IDEAS:
-- find the number on the number line, with a power up to run faster (to go by 10s or hundreds)
-- clean up the layout and timings a bit more so that the existing lessons are more structured
-- make toad float down from the top
-- work on the boo animations
-- get rid of the extra coins
-- work on the add with carry intro timing

function mergo(a, b)
  c = {}
  for k,v in pairs(a) do c[k] = v end
  for k,v in pairs(b) do c[k] = v end
  return c
end

function sorted_pairs(t)
  local a = {}
  for n in pairs(t) do table.insert(a, n) end
  table.sort(a)
  local i = 0
  return function ()
    i = i + 1
    if a[i] == nil then return nil
    else return a[i], t[a[i]]
    end
  end
end

function dump(o)
  if type(o) == 'table' then
     local s = '{'
     local cm = ''
     for k,v in pairs(o) do
        -- if type(k) ~= 'number' then k = '"'..k..'"' end
        -- s = s .. '['..k..']=' .. dump(v) .. ','
        s = s .. cm .. k .. '=' .. dump(v)
        cm = ','
      end
     return s .. '}'
  elseif type(o) == 'thread' then
    return 'X'
  else
     return tostring(o)
  end
end

function dump_list(l)
  local s = ''
  for k,v in pairs(l) do
    s = s .. k .. ': ' .. dump(v) .. '\n'
  end
  return s
end

function dump_threads()
  local s = ""
  for k, t in sorted_pairs(eq.threads) do
    s = s..t.id..">".." "
    local tb = debug.traceback(t.co)
    for l, f in string.gmatch(tb, ":(%d+): in function '([^\n]+)'") do
      s = s..f.."."..l.." "
    end
    s = s.."\n"
  end
  return s
end


function mrect(x, y, w, h, v)
  for i=x,x+w-1 do
    for j=y,y+h-1 do
      mset(i, j, v)
    end
  end
end

function mblit(x, y, sx, sy, w, h)
  for i=x,x+w-1 do
    for j=y,y+h-1 do
      local t = mget(sx-x+i, sy-y+j)
      if t > 0 then
        mset(i, j, t)
      end
    end
  end
end

function minit(w, h)
  eq.mapsz = {w = w, h = h}
  mrect(0, 0, w, h, 0)
  mrect(0, 0, w, 1, 1)
  mrect(0, 0, 1, h, 1)
  mrect(0, h-1, w, 1, 1)
  mrect(w-1, 0, 1, h, 1)
end

function minit_space(w, h)
  eq.mapsz = {w = w, h = h}
  mrect(0, 0, w, h, 0)
  mrect(0, 0, w, 1, 4)
  mrect(0, 0, 1, h, 4)
  mrect(0, h-1, w, 1, 4)
  mrect(w-1, 0, 1, h, 4)
end

function init_eq(kind)
  eq = {
    kind = kind,
    hint = "",
    threads = {governor = governor},
    signals = {},
    syms = {},
    ops = {},
    mapsz = {w = 30, h = 22},
    next_id = 1
  }
  init_player()
end

function add_thread(id, fn, fields)
  eq.threads[id] = mergo({
    id = id,
    co = coroutine.create(fn),
    wait = 0
  }, fields or {})
end

function update_threads(id, fn)
  for k,t in sorted_pairs(eq.threads) do
    if t.wait > 0 then
      t.wait = t.wait - 1
    else
      local status, r = coroutine.resume(t.co, table.unpack(t.args or {}))
      if not status then
        trace("thread " .. k .. " died:\n" .. r)
        eq.threads[k] = nil
      else
        if r ~= nil then
          t.wait = r
        else
          eq.threads[k] = nil
        end
      end
    end
  end
end

function wait_frames(delay)
  coroutine.yield(delay)
end

function wait_signal(signals)
  if type(signals) == "string" then
    signals = {signals}
  end
  while true do
    for k, sig in pairs(signals) do
      if eq.signals[sig] ~= nil then
        eq.signals[sig] = nil
        return sig
      end
    end
    coroutine.yield(1)
  end
end

function set_signal(signal)
  eq.signals[signal] = true
end

function add_sym(id, x, y, fields)
  local s = mergo({x = x, y = y, kind = "number", visible = true, layer = "above_map"}, fields or {})
  eq.syms[id] = s
  return s
end

function del_sym(id)
  eq.syms[id] = nil
end

function sym(id)
  if eq.syms[id] ~= nil then
    return eq.syms[id]
  else
    return {}
  end
end

function add_op(id, x, y, chars)
  eq.ops[id] = {x = x, y = y, chars = chars}
  add_sym(id, x, y, {kind = "op", sprite = 217, chars = chars, layer = "ovr_above_player"})
  mrect(x, y, #chars, 1, 3)
end

function restore_op(id)
  local s = sym(id)
  s.visible = true
  mrect(s.x, s.y, #s.chars, 1, 3)
end

function hit_op(id)
  add_thread("hit" .. id, function()
    -- up and down animation
    local s = sym(id)
    s.y = s.y - 1/8
    wait_frames(3)
    s.y = s.y + 1/8
    wait_frames(3)
    -- signal waiters
    eq.signals[id] = true
    -- remove op
    mrect(eq.ops[id].x, eq.ops[id].y, #s.chars, 1, 0)
    s.visible = false
  end)
end

function boo_say(text)
  for i=1,#text do
    eq.hint = text:sub(1,i)
    wait_frames(1)
  end
  set_signal("boo_spoke")
end

function boo_float()
  add_sym("boo", 4.3, 0.8, {kind = "toad", frame = 0, layer = "ovr_above_player", coords = "screen"})
  boo_appear()
  while true do
    wait_frames(100)
    sym("boo").y = 0.9
    wait_frames(20)
    sym("boo").y = 0.8
  end
end

function boo_appear()
  for i=4,0,-1 do
    sym("boo").frame = i
    wait_frames(3)
  end
end

function boo_disappear()
  for i=0,4 do
    sym("boo").frame = i
    wait_frames(3)
  end
  eq.hint = ""
end

function spinning_coin(x, y)
  local id = "coin" .. eq.next_id
  eq.next_id = eq.next_id + 1
  add_sym(id, x, y, {kind = "coin", frame = 0})
  add_thread(id, function() 
    while true do
      sym(id).frame = (sym(id).frame + 1) % 6
      wait_frames(2)
      if math.abs(p.cx - x) < 1 and math.abs(p.cy - y) < 1 then
        sym(id).visible = false
        break
      end
    end
  end)
end

function rising_coin(x, y)
  local id = "coin" .. eq.next_id
  eq.next_id = eq.next_id + 1
  local s = add_sym(id, x, y, {kind = "coin", frame = 0})
  for i=1,12 do
    wait_frames(1)
    s.frame = (s.frame + 1) % 6
    s.y = s.y - 0.5
  end
  s.visible = false
end

function fading_boo(x, y)
  local id = "boo" .. eq.next_id
  eq.next_id = eq.next_id + 1
  local s = add_sym(id, x, y, {kind = "boo", frame = 0})
  for i=4,0,-1 do
    s.frame = i
    wait_frames(3)
  end
  wait_frames(30)
  for i=0,4 do
    s.frame = i
    wait_frames(3)
  end
end

function walk_to(x)
  if p.cx > x then
    while p.cx > x do
      p.auto.left = true
      wait_frames(1)
    end
    p.auto.left = false
  else
    while p.cx < x do
      p.auto.right = true
      wait_frames(1)
    end
    p.auto.right = false
  end
  p.x = x - 0.1
end

function fade_in()
  eq.lights_off = 1
  while eq.lights_off > 0 do
    eq.lights_off = eq.lights_off - 0.1
    eq.ovr_lights_off = eq.lights_off
    wait_frames(1)
  end
end

function fade_out()
  eq.lights_off = 0
  while eq.lights_off < 1 do
    eq.lights_off = eq.lights_off + 0.1
    eq.ovr_lights_off = eq.lights_off
    wait_frames(1)
  end
end

function add_in_pipe()
  add_sym("pipe", 1, -1, {kind = "pipe", layer = "ovr_above_player"})
  p.auto.sink = true
  p.x = 2.5
  p.y = 1.5
end

function in_pipe()
  for i=1,20 do
    p.x = 2.5
    p.y = 1.5+i/10
    wait_frames(1)
  end
  p.auto.sink = false
end

function out_pipe(x, y)
  if p.cx > x-1 then
    walk_to(x-1)
  end

  add_sym("pipe", x, y, {kind = "pipe", layer = "below_map"})
  mrect(x, y+1, 3, 3, 4)

  for i=1,30 do
    sym("pipe").y = y+4 - i*3/30.0
    wait_frames(1)
  end
  sym("pipe").layer = "ovr_above_player"

  while not (p.on.pipe and p.input.go_down) do
    wait_frames(1)
  end

  walk_to(x+1.5)

  p.auto.sink = true
  setanim(p, "stand")
  p.frame = 1
  for i=1,16 do
    p.y = p.y + 1.0/8.0
    wait_frames(1)
  end

  p.auto.sink = false
  mrect(x, y+1, 3, 3, 0)

  fade_out()
end

function add_with_carry(a, b)
  init_eq("add_with_carry")

  spinning_coin(3, 19)
  spinning_coin(4, 19)

  local lay = { r = 19, a = 10, b = 13, f = 17, carry = 9 }

  minit(30, 22)
  mrect(8, 16, 13, 1, 2)

  add_sym("plus", 9, 15, {small = true, n = 10})

  local an, bn, carry, x, d = a, b, 0, lay.r, 1
  while an > 0 or bn > 0 do
    local a_digit, b_digit = an % 10, bn % 10
    if an > 0 then add_sym("a" .. d, x, 10, {n = a_digit, nn = an}) end
    if bn > 0 then add_sym("b" .. d, x, 13, {n = b_digit, nn = bn}) end
    an = math.floor(an / 10)
    bn = math.floor(bn / 10)
    x = x - 3
    d = d + 1
  end

  add_in_pipe()

  fade_in()
  in_pipe()
  wait_frames(60)
  
  add_thread("boo_float", boo_float)

  add_thread("boo_sum_digits", function()
    local sum_exclaims = { "good! ", "hee hee! ", "ya ha! ", "wow! " , "" , "" , "" } 
    local carry_exclaims = { "", "well carried! ", "carry-ific! ", "carry-tastic! ", "...? " , "...? " , "...? " , "...? " } 
    local places = {"1s", "10s", "100s", "1000s", "10000s", "100000s", "millions"}
  
    local n_carried = 0
    local d = 1
    local exclaim = "hint: "
    
    while true do
      -- todo: maybe watch for "op" creation to reduce the amount of comms?
      --       would have to gauge impact on timing
      local sig = wait_signal({"boo_next_digit", "boo_carry", "boo_finished"})

      if sig == "boo_next_digit" then
        boo_say(exclaim .. "hit the box to add the " .. places[d])
        exclaim = sum_exclaims[d]
        d = d + 1

      elseif sig == "boo_finished" then
        boo_say("and now you have your answer. hee hee!")
        wait_frames(180)
        boo_disappear()

        break

      elseif sig == "boo_carry" then
        if n_carried == 0 then
          boo_say("ya ha! the sum of the " .. places[d - 1] .. " is ten or greater")
        else
          boo_say("wha?! the sum of the " .. places[d - 1] .. " is ALSO ten or greater")
        end
        n_carried = n_carried + 1
        exclaim = carry_exclaims[d]
      end
    end

  end)

  d = 1

  while true do

    local x = lay.r - 3 * (d-1)

    add_op("add", x + 1, lay.f, "+")
    set_signal("boo_next_digit")
    wait_signal("add")

    -- get the player out of the way
    local cx = x + 1.5
    if math.abs(p.cx - cx) < 2 then
      if p.cx < cx then
        add_thread("ootw", walk_to, {args = {cx - 2}})
      else
        add_thread("ootw", walk_to, {args = {cx + 2}})
      end
    end

    -- sum up the numbers in a visually strking way
    -- todo: sometimes have them answer the sum themselves
    eq.lights_off = .75
    wait_signal("boo_spoke")
    wait_frames(30)

    if eq.syms["carry" .. d] ~= nil then
      sym("carry" .. d).layer = "ovr_above_player"
      wait_frames(30)
    end
    if eq.syms["a" .. d] ~= nil then
      sym("a" .. d).layer = "ovr_above_player"
      wait_frames(30)
    end
    if eq.syms["b" .. d] ~= nil then
      sym("b" .. d).layer = "ovr_above_player"
      wait_frames(30)
    end

    local sum = (sym("a" .. d).n or 0) + (sym("b" .. d).n or 0) + (sym("carry" .. d).n or 0)

    add_sym("answer" .. d, x, lay.f, {n = sum % 10, layer = "ovr_below_player"})
    wait_frames(30)

    if sum < 10 then -- sums to less than 10, setup the next place

      eq.lights_off = 0

      if math.max(sym("a" .. d + 1).n or 0, sym("b" .. d + 1).n or 0, sym("carry" .. d + 1).n or 0) == 0 then
        set_signal("boo_finished")
        wait_signal("boo_spoke")
        break
      end

    else -- sums to 10 or more, setup carry

      eq.lights_off = 0

      add_op("carry", lay.r - 3 * d + 1, lay.carry - 1, "u")
      set_signal("boo_carry")
      wait_signal("carry")
      add_sym("carry" .. d + 1, lay.r - 3 * d + 1, lay.carry, {small = true, n = math.floor(sum / 10)})
      wait_signal("boo_spoke")

    end

    sym("carry" .. d).layer = "above_map"
    sym("a" .. d).layer = "above_map"
    sym("b" .. d).layer = "above_map"
    sym("answer" .. d).layer = "above_map"

    d = d + 1
  end

  out_pipe(24, 17)

  eq.lights_off = 0

end

function subtract_with_borrow(a, b)
  init_eq("subtract_with_borrow")

  spinning_coin(3, 19)
  spinning_coin(4, 19)

  local lay = { r = 19, a = 10, b = 13, f = 17, carry = 9 }

  minit(30, 22)
  mrect(8, 16, 13, 1, 2)

  add_sym("minus", 9, 15, {small = true, n = 11})

  local an, bn, carry, x, d = a, b, 0, lay.r, 1
  while an > 0 or bn > 0 do
    local a_digit, b_digit = an % 10, bn % 10
    if an > 0 then add_sym("a" .. d, x, 10, {n = a_digit, nn = an}) end
    if bn > 0 then add_sym("b" .. d, x, 13, {n = b_digit, nn = bn}) end
    an = math.floor(an / 10)
    bn = math.floor(bn / 10)
    x = x - 3
    d = d + 1
  end

  add_in_pipe()

  fade_in()
  in_pipe()
  wait_frames(60)
  
  add_thread("boo_float", boo_float)

  add_thread("boo_subtract_digits", function()
    local sum_exclaims = { "good! ", "hee hee! ", "ya ha! ", "wow! " , "" , "" , "" } 
    local carry_exclaims = { "", "borrow-wow! ", "borrow-sauce! ", "borrow-what?! ", "...? " , "...? " , "...? " , "...? " } 
    local places = {"1s", "10s", "100s", "1000s", "10000s", "100000s", "millions"}
  
    local n_carried = 0
    local d = 1
    local exclaim = "hint: "
    
    while true do
      local sig = wait_signal({"boo_next_digit", "boo_borrow", "boo_borrow_2", "boo_final_subtract", "boo_finished"})

      if sig == "boo_next_digit" then
        boo_say(exclaim .. "hit the box to subtract the " .. places[d])
        exclaim = sum_exclaims[d]
        d = d + 1

      elseif sig == "boo_finished" then
        boo_say("and now you have your answer. hee hee!")
        wait_frames(180)
        boo_disappear()

        break

      elseif sig == "boo_borrow" then
        boo_say("ya ha! you need to borrow from the " .. places[d] .. "!")
        n_carried = n_carried + 1
        exclaim = carry_exclaims[d]

      elseif sig == "boo_borrow_2" then
        boo_say("okay, add that " .. places[d] .. " to the " .. places[d - 1] ..  "!")
        n_carried = n_carried + 1
        exclaim = carry_exclaims[d]

      elseif sig == "boo_final_subtract" then
        boo_say("great, time for the final subtraction!")
        n_carried = n_carried + 1
        exclaim = carry_exclaims[d]

      end
    end

  end)

  d = 1

  while true do

    local x = lay.r - 3 * (d-1)

    add_op("subtract", x + 1, lay.f, "-")
    set_signal("boo_next_digit")
    wait_signal("subtract")

    -- get the player out of the way
    local cx = x + 1.5
    if math.abs(p.cx - cx) < 2 then
      if p.cx < cx then
        add_thread("ootw", walk_to, {args = {cx - 2}})
      else
        add_thread("ootw", walk_to, {args = {cx + 2}})
      end
    end

    -- sum up the numbers in a visually strking way
    -- todo: sometimes have them answer the sum themselves
    eq.lights_off = .75
    wait_signal("boo_spoke")
    wait_frames(30)

    if eq.syms["a" .. d] ~= nil then
      sym("a" .. d).layer = "ovr_above_player"
      wait_frames(30)
    end
    if eq.syms["b" .. d] ~= nil then
      sym("b" .. d).layer = "ovr_above_player"
      wait_frames(30)
    end

    local a_number = (sym("a" .. d).n or 0)
    local b_number = (sym("b" .. d).n or 0)

    if a_number < b_number then

      next_digit = sym("a" .. d + 1).n

      add_op("borrow", lay.r - 3 * d + 1, lay.carry - 1, "u")
      set_signal("boo_borrow")
      wait_signal("borrow")
      wait_signal("boo_spoke")

      eq.lights_off = .75
      sym("a" .. d + 1).layer = "ovr_above_player"
      sym("b" .. d).layer = "above_map"

      wait_frames(60)
      add_sym("xxxxxx_1" .. d, lay.r - 3 * d, lay.carry + 1, {kind = 'x', layer = "ovr_above_player"})
      wait_frames(10)
      add_sym("borrow_1" .. d, lay.r - 3 * d + 1, lay.carry, {small = true, n = next_digit - 1, layer = "ovr_above_player"})
      wait_frames(30)

      add_op("borrow", lay.r - 3 * (d - 1) + 1, lay.carry - 1, "u")
      set_signal("boo_borrow_2")
      wait_signal("borrow")
      wait_signal("boo_spoke")
      wait_frames(60)

      -- borrow from the 10s column
      new_a_number = a_number + 10

      add_sym("xxxxxx_2" .. d, lay.r - 3 * (d - 1), lay.carry + 1, {kind = 'x', layer = "ovr_above_player"})
      wait_frames(10)
      add_sym("borrow_2_1" .. d, lay.r - 3 * (d - 1)    , lay.carry, {small = true, n = 1, layer = "ovr_above_player" })
      add_sym("borrow_2_2" .. d, lay.r - 3 * (d - 1) + 1, lay.carry, {small = true, n = new_a_number % 10, layer = "ovr_above_player" })

      wait_frames(60)

      add_op("subtract", x + 1, lay.f, "-")
      set_signal("boo_final_subtract")
      wait_signal("subtract")

      sym("xxxxxx_1" .. d).layer = "above_map"
      sym("xxxxxx_2" .. d).layer = "above_map"
      sym("borrow_1" .. d).layer = "above_map"
      sym("borrow_2_1" .. d).layer = "above_map"
      sym("borrow_2_2" .. d).layer = "above_map"
      sym("a" .. d).layer = "above_map"
      sym("a" .. d + 1).layer = "above_map"
      wait_frames(30)

      sym("borrow_2_1" .. d).layer = "ovr_below_player"
      sym("borrow_2_2" .. d).layer = "ovr_below_player"

      wait_frames(30)

      sym("b" .. d).layer = "ovr_below_player"

      wait_frames(60)

      eq.lights_off = 0

      local dif = a_number - b_number

      add_sym("answer" .. d, x, lay.f, {n = dif % 10, layer = "ovr_below_player"})
      wait_frames(30)
  
      if math.max(sym("a" .. d + 1).n or 0, sym("b" .. d + 1).n or 0, sym("carry" .. d + 1).n or 0) == 0 then
        set_signal("boo_finished")
        wait_signal("boo_spoke")
        break
      end
  
      sym("carry" .. d).layer = "above_map"
      sym("a" .. d).layer = "above_map"
      sym("b" .. d).layer = "above_map"
      sym("answer" .. d).layer = "above_map"
  
    else

      local dif = a_number - b_number

      add_sym("answer" .. d, x, lay.f, {n = dif % 10, layer = "ovr_below_player"})
      wait_frames(30)
  
      if math.max(sym("a" .. d + 1).n or 0, sym("b" .. d + 1).n or 0, sym("carry" .. d + 1).n or 0) == 0 then
        set_signal("boo_finished")
        wait_signal("boo_spoke")
        break
      end
  
      sym("carry" .. d).layer = "above_map"
      sym("a" .. d).layer = "above_map"
      sym("b" .. d).layer = "above_map"
      sym("answer" .. d).layer = "above_map"
        
    end

    d = d + 1
  end

  out_pipe(24, 17)

  eq.lights_off = 0

end

function pluralize(n, s)
  if n == 1 then
    return n .. " " .. s
  else
    return n .. " " .. s .."s"
  end
end

function skip_counting(count_from, skip_by, count_to)

  init_eq("skip_counting")

  minit(240, 17)

  local x = 4
  local count_dir = count_from < count_to and 1 or -1

  for i=count_from,count_to,count_dir do
    local xt = x
    local it = i
    local cx = i < 10 and 0.5 or 1

    add_op("n" .. i, xt, 12, "" .. i)

    add_thread("n" .. i, function() 
      while true do
        wait_signal("n" .. i)
        if it % skip_by == 0 then
          set_signal("right_number")
          rising_coin(xt + cx, 12.5) 
        else
          set_signal("wrong_number")
          fading_boo(xt + cx - 1, 11.5) 
          wait_frames(10)
          for ri=count_from,count_to,count_dir do
            local s = sym("n"..ri)
            if not s.visible then
              add_thread("restore_n"..ri, function()
                wait_frames(ri * 3)
                restore_op("n"..ri)
                for t=0,3 do
                  sym("n"..ri).sprite = 208 + 3 * t
                  wait_frames(3)
                end
              end)
            end
          end
        end
      end
    end)

    x = x + (i < 10 and 3 or 4)
  end

  x = x + 7
  mrect(0, 0, 1, 19, 1)
  mrect(x, 0, 1, 19, 1)
  eq.mapsz = { w = x + 1, h = 17 }

  add_in_pipe()

  fade_in()
  in_pipe()

  wait_frames(60)
  add_thread("boo_float", boo_float)
  add_thread("boo_hint", function()
    wait_frames(30)
    if count_from < count_to then
      local first = math.ceil(count_from / skip_by) * skip_by
      boo_say("skip count by "..skip_by.."! start with "..first.." and ...")
    else
      local first = math.floor(count_from / skip_by) * skip_by
      boo_say("skip count backwards by "..skip_by.."! start with "..first.." and ...")
    end
    while true do
      local s = wait_signal({"right_number", "wrong_number"})
      if s == "right_number" then
        eq.hint = ""
      else
        boo_say("oh no, a boo undid your work!")
        wait_frames(120)
        boo_say("make sure you skip over " .. pluralize(skip_by - 1, " block") .. " each time!")
      end
    end
  end)

  local all_clear = false
  while not all_clear do
    all_clear = true
    for i=skip_by,math.max(count_from, count_to),skip_by do
      if sym("n"..i).visible then
        all_clear = false
      end
    end
    wait_frames(1)
  end

  out_pipe(x - 6, 12)

end

function stars()
  add_sym("astars", 0, 0, {kind = "starfield", layer = "below_map", scroll = 0})
  while true do
    sym("astars").scroll = sym("astars").scroll + .01
    wait_frames(1)
  end
end

function on_the_imaginater()
  init_eq("on_the_imaginater")

  minit_space(30, 26)
  mblit(1, 4, 0, 51, 30, 22)

  add_in_pipe()

  add_thread("stars", stars)
  
  fade_in()
  in_pipe()

  out_pipe(19, 15)
end

function imaginer_transition(skip_by, total)

  init_eq("imaginer_transition")

  minit_space(30, 17)

  eq.mapsz = { w = 1, h = 1 }

  add_thread("stars", stars)

  add_sym("ima", -1, 13, {kind = "imaginer", frame = 0})
  add_sym("ody", -6, 13, {kind = "odyssey", frame = 0})

  p.auto.sink = true
  p.x = -10
  p.y = -10

  eq.lights_off = 1

  while true do
    local s = sym("ody")
    s.x = s.x + 2/8
    s.frame = s.frame + 1

    local i = sym("ima")
    i.x = i.x + 2.5/8
    i.frame = s.frame + 1

    if s.x > 240/8 then
      eq.lights_off = (eq.lights_off or 0) + 0.05
      if eq.lights_off > 1 then
        break
      end
    else
      if eq.lights_off > 0 then
        eq.lights_off = eq.lights_off - 0.05
      end
    end

    wait_frames(1)
  end

  wait_frames(30)

end

function do_governor()
  while true do
    -- subtract_with_borrow(572, 438)
    -- add_with_carry(math.random(0, 999), math.random(0, 999))
    -- skip_counting(21, 3, 1)
    imaginer_transition()
    -- on_the_imaginater()
    -- skip_counting(1, 3, 21)
    -- skip_counting(1, 2, 20)
  end
end

function init_governor()
  eq = {threads = {}, mapsz = {w = 1, h = 1}}
  add_thread("governor", do_governor)
  governor = eq.threads.governor
end

function do_op(tile)
  for id, op in pairs(eq.ops) do
    for i=1,#op.chars do
      if tile.x == op.x+i-1 and tile.y == op.y then
        hit_op(id)
      end
    end
  end
end

function mid(x, y, z)
  if y < x then
    return x
  end
  if y > z then
    return z
  end
  return y
end

function animate(e)
  if not e.on.ground then
    setanim(e, "jump")
  elseif e.vel.x ~= 0 then
    setanim(e, "walk")
  else
    setanim(e, "stand")
  end

  e.animframes = e.animframes + 1
  e.frame = (math.floor(e.animframes / 3) % #e.anim) + 1

  if e.vel.x < 0 then
    e.mirror = 1
  elseif e.vel.x > 0 then
    e.mirror = 0
  end
end

function setanim(e, name)
  if e.anim ~= e.anims[name] then
    e.anim = e.anims[name]
    e.animframes = 0
  end
end

function jump(e)
  e.on.ground = false
  e.jump = true
  e.curjumpvel = jumpvel
  jumpframes = jumpbuffer + 1
end

function applyphysics(e)
  local vel = e.vel

  if e.jump or vel.y < 0 then
    if e.jump then
      e.curjumpvel = e.curjumpvel - jumpvel / 20
    else
      e.curjumpvel = 0
    end

    vel.y = -e.curjumpvel

    if e.curjumpvel <= 0 then
      e.jump = false
    end
  else
    vel.y = math.min(maxgrav, vel.y + grav)
  end

  e.on.ground = false
  e.on.line = false
  e.on.pipe = false

  local steps = 1
  local highestvel = math.max(math.abs(vel.x), math.abs(vel.y))
  if highestvel >= 0.25 then
    steps = math.ceil(highestvel / 0.25)
  end

  for i = 1, steps do
    e.x = e.x + vel.x / steps
    e.y = e.y + vel.y / steps

    updatecolbox(e)
    for tile in gettiles(e.col.box["horz"]) do
      f_solid = fget(tile.sprite, 0)
      if f_solid then
        if e.x < tile.x + 0.5 then
          e.x = tile.x - e.col.size.horz.w / 2
        else
          e.x = tile.x + 1 + e.col.size.horz.w / 2
        end
      end
    end
    updatecolbox(e)
    if vel.y > 0 then
      for tile in gettiles(e.col.box["floor"]) do
        f_solid = fget(tile.sprite, 0)
        f_line = tile.sprite == 2 and p.line_fall == 0
        f_pipe = fget(tile.sprite, 1)
        if f_line or f_solid then
          vel.y = 0
          e.y = tile.y
          e.on.ground = true
          e.on.line = f_line
          e.on.pipe = f_pipe
          e.jump = false
          fallframes = 0
        end
      end
    end
    updatecolbox(e)
    for tile in gettiles(e.col.box["ceiling"]) do
      f_solid = fget(tile.sprite, 0)
      if f_solid then
        vel.y = 0
        e.y = tile.y + 1 + e.col.size.vert.h
        e.jump = false
        if tile.sprite == 3 then
          do_op(tile)
        end
      end
    end
  end
end

function gettiles(box)
  local l, t, r, b = math.floor(box.l), math.floor(box.t), math.floor(box.r), math.floor(box.b)
  local x, y = l, t

  return function()
    if y > b then
      return nil
    end

    local sprite = mget(x, y)
    local ret = {sprite = sprite, x = x, y = y}

    x = x + 1
    if x > r then
      x = l
      y = y + 1
    end

    return ret
  end
end

function updatecolbox(e)
  local size = e.col.size

  e.col.box = {
    horz = {
      l = e.x - size.horz.w / 2,
      t = e.y - size.vert.h + (size.vert.h - size.horz.h) / 2,
      r = e.x + size.horz.w / 2,
      b = e.y - (size.vert.h - size.horz.h) / 2
    },
    floor = {
      l = e.x - size.vert.w / 2,
      t = e.y - size.vert.h / 8,
      r = e.x + size.vert.w / 2,
      b = e.y
    },
    ceiling = {
      l = e.x - size.vert.w / 2,
      t = e.y - size.vert.h,
      r = e.x + size.vert.w / 2,
      b = e.y - size.vert.h / 2
    }
  }
end

function update_player()
  p.vel.x = 0

  if p.auto.sink then
    return
  end

  jumpframes = math.min(jumpbuffer + 1, jumpframes + 1)
  fallframes = math.min(jumpgrace + 1, fallframes + 1)

  p.input.go_down = btn(1)
  p.input.go_left = btn(2)
  p.input.go_right = btn(3)
  p.input.do_jump = btn(4)

  go_down = p.input.go_down
  go_left = p.input.go_left
  go_right = p.input.go_right
  do_jump = p.input.do_jump

  if p.auto.left or p.auto.right then
    go_left = p.auto.left
    go_right = p.auto.right
    do_jump = false
    go_down = false
  end

  if go_left then
    p.vel.x = p.vel.x - movvel
  end
  if go_right then
    p.vel.x = p.vel.x + movvel
  end

  if (do_jump and not wasjumppressed) then
    jumpframes = 0
  end

  if p.line_fall > 0 then
    p.line_fall = p.line_fall - 1
  end
  if p.on.line and go_down then
    p.line_fall = 15
  end

  if p.on.ground or fallframes <= jumpgrace then
    if jumpframes <= jumpbuffer then
      jump(p)
    end
  else
    if p.jump and not do_jump then
      p.jump = false
    end
  end

  applyphysics(p)
  animate(p)

  wasjumppressed = do_jump

  p.cx = p.x + 0.1 -- center location for testing
  p.cy = p.y - 1
end

function update_camera()
  local screenx, screeny = p.x * 8 - cam.x, p.y * 8 - cam.y

  if screenx < camerasnap.l then
    cam.x = cam.x + (screenx - camerasnap.l)
  elseif screenx > camerasnap.r then
    cam.x = cam.x + (screenx - camerasnap.r)
  else
    local center = p.x * 8 - screensz.w / 2
    cam.x = cam.x + (center - cam.x) / 6
  end

  if screeny < camerasnap.t then
    cam.y = cam.y + (screeny - camerasnap.t)
  elseif screeny > camerasnap.b then
    cam.y = cam.y + (screeny - camerasnap.b)
  elseif p.on.ground then
    local center = p.y * 8 - screensz.h / 2
    cam.y = cam.y + (center - cam.y) / 6
  end

  local maxcamx, maxcamy = math.max(0, eq.mapsz.w * 8 - screensz.w), math.max(0, eq.mapsz.h * 8 - screensz.h)

  cam.x = mid(0, cam.x, maxcamx)
  cam.y = mid(0, cam.y, maxcamy)
end

function init_player()
  p = {x = 6, y = 12, cx = 0, cy = 0}
  p.on = {
    ground = false,
    line = false,
    pipe = false
  }
  p.line_fall = 0
  p.vel = {x = 0, y = 0}
  p.col = {
    size = {
      horz = {
        w = 10 / 8,
        h = 9 / 8
      },
      vert = {
        w = 6 / 8,
        h = 13 / 8
      }
    }
  }
  p.input = {go_left = false, go_right = false, go_down = false, do_jump = false}
  p.auto = {left = false, right = false, sink = false}
  p.anims = {
    stand = {256},
    jump = {258},
    walk = {288, 290, 292, 294, 296, 298, 300, 302}
  }

  updatecolbox(p)

  screensz = {
    w = 240,
    h = 136
  }

  grav = 0.2 / 8
  maxgrav = 2.5 / 8
  movvel = 1 / 8

  jumpvel = 5 / 8
  jumpbuffer = 3
  jumpframes = jumpbuffer + 1
  wasjumppressed = false

  jumpgrace = 3 -- number of frames allowed after being on the ground to still jump
  fallframes = jumpgrace + 1

  setanim(p, "stand")
  p.frame = 1
end

function init_camera()
  camerasnap = {l = 40, t = 16, r = screensz.w - 40, b = screensz.h - 48}
  cam = {x = 0, y = 0}
end

function init()
  sheet = {
    add = 18,
    carry = 23
  }

  init_player()
  init_camera()
  init_governor()
end

function update()
  update_player()
  update_camera()
  update_threads()
end

function draw_eq(layer)
  for k, n in sorted_pairs(eq.syms) do
    if n.visible then
      if n.layer == layer then

        if n.kind == "number" then

          if n.small then
            spr(144 + n.n, n.x * 8 - cam.x, n.y * 8 - cam.y, 0, 1, 0, 0, 1, 1)
          else
            if n.n < 5 then
              sprite = 48 + 3 * n.n
            else
              sprite = 96 + 3 * (n.n - 5)
            end
            spr(sprite, n.x * 8 - cam.x, n.y * 8 - cam.y, 0, 1, 0, 0, 3, 3)
          end

        elseif n.kind == 'x' then

          spr(160, n.x * 8 - cam.x, n.y * 8 - cam.y, 0, 1, 0, 0, 3, 3)

        elseif n.kind == "boo" then

          local x = n.x * 8
          local y = n.y * 8
          if n.coords ~= "screen" then
            x = x - cam.x
            y = y - cam.y
          end

          if n.frame <= 3 then
            spr(320 + n.frame * 2, x, y, 0, 1, 0, 0, 2, 2)
          end

          -- toad:
          -- spr(330, x, y, 0, 1, 0, 0, 2, 2)

        elseif n.kind == "toad" then

          local x = n.x * 8
          local y = n.y * 8

          spr(330, x, y, 0, 1, 0, 0, 2, 2)

        elseif n.kind == "odyssey" then

          local x = n.x * 8 - cam.x
          local y = n.y * 8 - cam.y

          spr(448, x, y, 0, 1, 0, 0, 3, 4)

          local a1 = math.floor((math.sin(n.frame/3))+0.5)
          local a2 = math.floor((math.sin((9+n.frame)/3))+0.5)
          local a3 = math.floor((math.sin((12+n.frame)/3))+0.5)

          rect(x+6, y+29+a1, 3, 1, 3)
          rect(x+10, y+29+a2, 3, 1, 3)
          rect(x+14, y+29+a3, 2, 1, 3)

          local gl = {8, 9, 10, 9}
          pix(x+2, y+19, gl[1+math.floor(1+n.frame/8)%#gl])
          pix(x+3, y+19, gl[1+math.floor(2+n.frame/8)%#gl])
          pix(x+2, y+20, gl[1+math.floor(2+n.frame/8)%#gl])
          pix(x+3, y+20, gl[1+math.floor(3+n.frame/8)%#gl])
          pix(x+2, y+21, gl[1+math.floor(1+n.frame/8)%#gl])
          pix(x+3, y+21, gl[1+math.floor(2+n.frame/8)%#gl])

        elseif n.kind == "imaginer" then

          local x = n.x * 8 - cam.x
          local y = n.y * 8 - cam.y

          spr(451, x, y-40, 0, 2, 0, 0, 4, 4)

        elseif n.kind == "starfield" then

          local x = n.x * 8 - cam.x
          local y = n.y * 8 - cam.y

          math.randomseed(9092013)
          for i=1,100 do
            local px = math.random()*2-1
            local py = math.random()*2-1
            local pz = math.random()*3+0.1
            px = (px - n.scroll) / pz
            py = py / pz
            px = math.fmod(1000000 + 120 + (0.5+px) * 240*2, 1000)
            py = 70 + py * 70*2
            pix(px, py, math.random(12,15))
          end
          math.randomseed(time())

        elseif n.kind == "coin" then

          local x = n.x * 8
          local y = n.y * 8
          if n.coords ~= "screen" then
            x = x - cam.x
            y = y - cam.y
          end

          spr(368 + n.frame, x-4, y-4, 0, 1, 0, 0, 1, 1)

        elseif n.kind == "op" then

          local x = n.x * 8 - cam.x
          local y = n.y * 8 - cam.y

          local b = n.sprite
          spr(b, x-8, y-8, 0, 1, 0, 0, 1, 3)
          for i=1,#n.chars do
            spr(b+1, x+8*i-8, y-8, 0, 1, 0, 0, 1, 3)
          end
          spr(b+2, x+#n.chars*8, y-8, 0, 1, 0, 0, 1, 3)

          sprite_map = {
            ["0"] = 144, ["1"] = 145, ["2"] = 146, ["3"] = 147, ["4"] = 148, 
            ["5"] = 149, ["6"] = 150, ["7"] = 151, ["8"] = 152, ["9"] = 153, 
            ["+"] = 154, ["-"] = 155, ["x"] = 156, ["/"] = 157, ["u"] = 158, ["n"] = 159
          }
          for i=1,#n.chars do
            spr(sprite_map[n.chars:sub(i,i)], x+i*8-8, y, 0, 1, 0, 0, 1, 1)
          end

        elseif n.kind == "pipe" then

          local x = n.x * 8 - cam.x
          local y = n.y * 8 - cam.y
          local w = n.width or 1

          spr(12, x, y, 0, 1, 0, 0, 3, 3)

        end

      end
    end
  end
end

function draw()
  cls(0)

  draw_eq("below_map")

  map(0, 0, 240, 136, -cam.x, -cam.y, 0)

  draw_eq("above_map")
end

init()

PALETTE_ADDR=0x03FC0
PALETTE = {
  0x1a,0x1c,0x2c, 0x5d,0x27,0x5d, 0xb1,0x3e,0x53, 0xef,0x7d,0x57,
  0xff,0xcd,0x75, 0xa7,0xf0,0x70, 0x38,0xb7,0x64, 0x25,0x71,0x79,
  0x29,0x36,0x6f, 0x3b,0x5d,0xc9, 0x41,0xa6,0xf6, 0x73,0xef,0xf7,
  0xf4,0xf4,0xf4, 0x94,0xb0,0xc2, 0x56,0x6c,0x86, 0x33,0x3c,0x57
}


function SCN(line)
  if eq.lights_off ~= nil and line == 0 then
    local l = math.max(0, math.min(1, 1-eq.lights_off))
    for i=1,48 do
      poke(PALETTE_ADDR+i-1, math.floor(l*PALETTE[i]))
    end
  end
end

function OVR()
  draw_eq("ovr_below_player")

  spr(p.anim[p.frame], p.x * 8 - cam.x - 8, p.y * 8 - cam.y - 16, 14, 1, p.mirror, 0, 2, 2)

  draw_eq("ovr_above_player")

  print(eq.hint,55,11,15,false,1,true)
  print(eq.hint,54,10,13,false,1,true)

  -- debug: draw the center point (for coin pickup etc)
  -- pix(p.cx * 8 - cam.x, p.cy * 8 - cam.y, 14)

  -- debug: draw collision rectangle
  -- rectb(
  --   p.col.box.floor.l * 8 - cam.x, 
  --   p.col.box.floor.t * 8 - cam.y, 
  --   (p.col.box.floor.r - p.col.box.floor.l) * 8, 
  --   (p.col.box.floor.b - p.col.box.floor.t) * 8, 14)

  -- debug: draw all threads
  -- local dbg = dump_threads()
  -- print(dbg,0,-1,0,false,1,true)
  -- print(dbg,-1,0,0,false,1,true)
  -- print(dbg,1,0,0,false,1,true)
  -- print(dbg,0,1,0,false,1,true)
  -- print(dbg,0,0,3,false,1,true)

  -- debug: draw player x
  -- print(p.x,0,0,3,false,1,true)

end

function TIC()
  update()
  draw()
  if eq.ovr_lights_off ~= nil then
    local l = math.max(0, math.min(1, 1-eq.ovr_lights_off))
    for i=1,48 do
      poke(PALETTE_ADDR+i-1, math.floor(l*PALETTE[i]))
    end
  else
    for i=1,48 do
      poke(PALETTE_ADDR+i-1, PALETTE[i])
    end
  end
end

-- <TILES>
-- 001:dddddddddeeeeeefdeeeeeefdeeeeeefdeeeeeefdeeeeeefdeeeeeefffffffff
-- 002:0000000000000000cccccccc0000000000000000000000000000000000000000
-- 003:0ff00ff0f00f0f0ff00f0f0ff00f0ffff00f0f00f00f0f00f00f0f000ff00f00
-- 012:fffffffff8888989f8888899f8888989f8888899ffff8889000f8888000f8888
-- 013:ffffffff999999999999999999999999999999998999999b989999998999999b
-- 014:ffffffff9b9a9aaf99b9aaaf9b9a9aaf99b9aaaf9b9affffb9aaf0009aaaf000
-- 016:3444444432222224322222243222222432222224322222243222222433333333
-- 017:3ccccccc3444444c3444444c3444444c3444444c3444444c3444444c33333333
-- 018:44444445caaaaaa5caaaaaa5caaaaaa5caaaaaa5caaaaaa5caaaaaa5c5555555
-- 019:3333333333333333333333333333333333333333333333333333333322222222
-- 020:33ffff333f4444f33f4444f33f4444f33f4444f33f4444f33f4444f333ffff33
-- 021:3333333333333333333333333e333e3333333333333333333333333333333333
-- 022:3333333333333333333333cc3333cc44333cc4443333cc44333333cc33333333
-- 023:2fee3333c3fee333433fee334433fee34443fee34433fee3433fee33c3fee333
-- 024:3332000033320000332000003320000032000000320000002000000020000000
-- 025:3333333233333332333333203333332033333200333332003333200033332000
-- 026:3333333333333333333333333333333333333322333322003322000022000000
-- 027:3333332233332200332200002200000000000000000000000000000000000000
-- 028:000f8888000f8888000f8888000f8888000f8888000f8888000f8888000f8888
-- 029:989999998999999b989999998999999b989999998999999b989999998999999b
-- 030:b9aaf0009aaaf000b9aaf0009aaaf000b9aaf0009aaaf000b9aaf0009aaaf000
-- 032:3333333333333333333333333333333333333333333333333333333333333333
-- 033:4444444433333333333333333333333333333333333333333333333333333333
-- 034:4000000034000000334000003334000033334000333334003333334033333334
-- 035:0000000400000043000004330000433300043333004333330433333343333333
-- 036:3333333233333320333332003333200033320000332000003200000020000000
-- 037:2333333302333333002333330002333300002333000002330000002300000002
-- 038:33333333333333333eeeeeeeefffffffefffffff3ddddddd3333333333333333
-- 039:3333333333333333eeeeeeeeffffffffffffffffdddddddd3333333333333333
-- 040:3333333333333333eeeeeee3fffffffefffffffeddddddd33333333333333333
-- 044:000f8888000f8888000f8888000f8888000f8888000f8888000f8888000fffff
-- 045:989999998999999b989999998999999b989999998999999b98999999ffffffff
-- 046:b9aaf0009aaaf000b9aaf0009aaaf000b9aaf0009aaaf000b9aaf000fffff000
-- 048:00000000000000000000000c000000c000000cc00000c000000cc000000c0000
-- 049:000000000cccc000c0000c0000000cc0000000cc0000000c0000000c00000000
-- 050:00000000000000000000000000000000000000000000000000000000c0000000
-- 051:00000000000000000000000000000000000000000000000c0000000000000000
-- 052:00000000000c000000cc00000ccc0000cc0c0000c00c0000000c0000000c0000
-- 055:00000000ccccc000c000cc0000000ccc0000000c0000000c0000000c0000000c
-- 057:00000000000000000000000000000000000000cc00000cc00000000000000000
-- 058:000000000000000000ccccc0ccc0000cc0000000000000000000000000000000
-- 059:000000000000000000000000c0000000cc0000000c0000000c0000000c000000
-- 060:00000000000000000000c0000000c0000000c0000000c0000000c0000000c000
-- 062:00000000c0000000c0000000c0000000c0000000c0000000c0000000c0000000
-- 064:00cc000000c0000000c0000000c0000000c0000000c0000000c0000000cc0000
-- 065:0000000000000000000000000000000000000000000000000000000c0000000c
-- 066:c0000000c0000000c0000000c0000000c0000000c0000000c000000000000000
-- 068:000c0000000c0000000c0000000c0000000c0000000c0000000c0000000c0000
-- 071:0000000c0000000c000000cc000000c000000cc000000c000000cc000000c000
-- 074:000000000000000c000000cc00000cc0000cccc0000000cc0000000c00000000
-- 075:cc000000c000000000000000000000000000000000000000c0000000c0000000
-- 076:0000c0000000cc0000000c0000000c0000000c0000000c000000cccc00000000
-- 077:000000000000000000000000000000000000000c00cccccccc00000c00000000
-- 078:c0000000c0000000c0000000c0000000c0000000c0000000c0000000c0000000
-- 080:000cc0000000cc0000000cc00000000c00000000000000000000000000000000
-- 081:0000000c000000cc00000cc0cccccc0000000000000000000000000000000000
-- 083:00000000000000000000000000000000000000000000000c0000000000000000
-- 084:000c0000000c0000000c0000000c000000ccc000cccccccc0000000000000000
-- 086:000000000000000000000000000000cc0000cccc000000000000000000000000
-- 087:000c00000cc00000cc00000000000000cccccc0000000ccc0000000000000000
-- 088:0000000000000000000000000000000000000000ccc000000000000000000000
-- 089:00000000000000000000000000000cc0000000cc000000000000000000000000
-- 090:00000000000000000000000c00000ccccccccc00000000000000000000000000
-- 091:cc000000cc000000c00000000000000000000000000000000000000000000000
-- 094:c0000000c0000000c0000000c0000000c0000000000000000000000000000000
-- 096:0000000000000ccc00000c0000000c0000000c0000000c0000000c0000000c00
-- 097:00000000cccccccc0000000c0000000000000000000000000000000000000000
-- 098:0000000000000000c00000000000000000000000000000000000000000000000
-- 099:00000000000000000000000c000000cc00000cc000000c0000000c000000c000
-- 100:000000000ccccccccc0000000000000000000000000000000000000000000000
-- 102:000000000000ccc0000000cc0000000000000000000000000000000000000000
-- 103:0000000000000000cccccccc000000000000000000000000000000000000000c
-- 104:0000000000000000ccc0000000c000000cc000000c000000cc000000c0000000
-- 105:0000000000000000000000cc000000c000000cc0000000cc0000000c00000000
-- 106:000000000ccccc00cc000ccc000000000000000000000000c0000000cc00000c
-- 107:0000000000000000c0000000cc0000000c0000000c000000cc000000c0000000
-- 108:00000000000000cc0000cc00000cc00000cc000000c0000000c0000000c00000
-- 109:00000000cccc00000000ccc0000000c00000000c0000000c0000000c000000cc
-- 112:00000ccc00000cc0000000000000000000000000000000000000000000000000
-- 113:cccccccc00000000000000000000000000000000000000000000000000000000
-- 114:c0000000cc0000000c0000000c0000000c0000000c000000cc000000c0000000
-- 115:0000c0000000c0cc0000ccc00000c0000000c0000000c0000000cc0000000c00
-- 116:00000000cccccc00000000cc0000000c00000000000000000000000000000000
-- 117:000000000000000000000000cc0000000cc0000000c00000000c0000000c0000
-- 119:0000000c000000cc000000c000000c000000cc00000cc00000cc000000c00000
-- 121:00000000000000000000000000000000000000000000000c000000cc000000c0
-- 122:0cc000cc000cccc00000cc0000cc0ccccc00000cc00000000000000000000000
-- 123:00000000000000000000000000000000c0000000cc0000000cc0000000cc0000
-- 124:00cc0000000ccccc0000000c0000000000000000000000000000000000000000
-- 125:00000ccc000cc00ccccc00000000000000000000000000000000000000000000
-- 126:00000000c0000000c0000000c0000000c0000000c0000000c0000000c0000000
-- 128:00000000000000000000ccc0000000cc00000000000000000000000000000000
-- 129:0000000c0000000c000000c0cc00ccc00cccc000000000000000000000000000
-- 130:c000000000000000000000000000000000000000000000000000000000000000
-- 131:00000cc0000000cc0000000c0000000000000000000000000000000000000000
-- 132:0000000000000000cccc0000000ccccc00000000000000000000000000000000
-- 133:00cc00000cc00000cc000000c000000000000000000000000000000000000000
-- 134:00000000000000000000000c0000000c00000000000000000000000000000000
-- 135:0cc00000cc000000c00000000000000000000000000000000000000000000000
-- 137:000000c0000000c0000000cc0000000c00000000000000000000000000000000
-- 138:000000000000000000000000c0000000cc00000c00ccccc00000000000000000
-- 139:000c0000000c000000cc0000ccc00000c0000000000000000000000000000000
-- 141:000000000000000000000000000000000000000c000000cc0000000000000000
-- 142:c0000000c0000000c0000000c000000000000000000000000000000000000000
-- 144:0000cc000ccc0cc00c00000cc000000cc000000cc0000cc00ccccc0000000000
-- 145:0000c000000cc0000000c0000000c0000000c0000000c000000ccc0000000000
-- 146:00ccc0000c000c0000000c0000000c0000000c0000000c000000c0000cccccc0
-- 147:00ccccc0000000c000000cc0000ccc000000cc0000000c000cc00c0000cccc00
-- 148:0c000c000c000c000c000c000c000c000ccccc0000000c0000000c0000000c00
-- 149:00ccccc00cc000000c0000000cccc0000000cc0000000c000ccccc0000000000
-- 150:000ccc0000cc00000cc000000ccccc000cc00c0000c00c0000cccc0000000000
-- 151:00ccccc000000cc0000cc000000c000000cc000000c0000000c0000000000000
-- 152:00cccc0000c00c00000c0c00000ccc000cccc0000c000c000cc00c0000cccc00
-- 153:00cccc000cc00cc00c000cc00cc0cc0000cccc0000000c0000000c0000000c00
-- 154:00000000000cc000000cc0000cccccc00cccccc0000cc000000cc00000000000
-- 155:0000000000000000000000000cccccc00cccccc0000000000000000000000000
-- 156:00000000000000000cc00cc000cccc00000cc00000cccc000cc00cc000000000
-- 157:00000000000cc000000000000cccccc00cccccc000000000000cc00000000000
-- 158:00000000000cc00000cccc000cccccc0000cc000000cc000000cc00000000000
-- 159:0000000000000000000000000000ccc000000000000000000000000000000000
-- 160:0000000000000000000220000002220000002220000002240000002200000002
-- 161:000000000000000f00000002000000f200000222300002224300222222422222
-- 162:00000000000000002f000000200000002f0000002f000000f000000000000000
-- 176:0000000000000000000000000000000200000022000002220002222000022200
-- 177:222222ff02222fff22224f302232244320032224000032220000002200000002
-- 178:0000000000000000000000000000000000000000400000002000000020000000
-- 192:0002200000000000000000000000000000000000000000000000000000000000
-- 208:0000000000000000000000000000000000000000000000ff00000f0000000f00
-- 209:0000000000000000000000000000000000000000ffffffff0000000000000000
-- 210:0000000000000000000000000000000000000000ff00000000f0000000f00000
-- 211:0000000000000000000000000000000000000000000000dd00000d0e00000dee
-- 212:0000000000000000000000000000000000000000ddddddddeeeeeeeeeeeeeeee
-- 213:0000000000000000000000000000000000000000de000000e0f00000eef00000
-- 214:000000000000000000000000000000000000000000000fcc00000cfd00000cdd
-- 215:0000000000000000000000000000000000000000ccccccccdddddddddddddddd
-- 216:0000000000000000000000000000000000000000cef00000dfe00000dde00000
-- 217:0000000000000000000000000000000000000000000001440000041300000433
-- 218:0000000000000000000000000000000000000000444444443333333333333333
-- 219:0000000000000000000000000000000000000000421000003120000033200000
-- 224:00000f0000000f0000000f0000000f0000000f0000000f0000000f0000000f00
-- 226:00f0000000f0000000f0000000f0000000f0000000f0000000f0000000f00000
-- 227:00000dee00000dee00000dee00000dee00000dee00000dee00000dee00000dee
-- 228:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 229:eef00000eef00000eef00000eef00000eef00000eef00000eef00000eef00000
-- 230:00000cdd00000cdd00000cdd00000cdd00000cdd00000cdd00000cdd00000cdd
-- 231:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
-- 232:dde00000dde00000dde00000dde00000dde00000dde00000dde00000dde00000
-- 233:0000043300000433000004330000043300000433000004330000043300000433
-- 234:3333333333333333333333333333333333333333333333333333333333333333
-- 235:3320000033200000332000003320000033200000332000003320000033200000
-- 240:00000f0000000f00000000ff0000000000000000000000000000000000000000
-- 241:0000000000000000ffffffff0000000000000000000000000000000000000000
-- 242:00f0000000f00000ff0000000000000000000000000000000000000000000000
-- 243:00000dee00000d0e000000df0000000000000000000000000000000000000000
-- 244:eeeeeeeeeeeeeeeeffffffff0000000000000000000000000000000000000000
-- 245:eef00000e0f00000ff0000000000000000000000000000000000000000000000
-- 246:00000cdd00000cfd00000fce0000000000000000000000000000000000000000
-- 247:ddddddddddddddddeeeeeeee0000000000000000000000000000000000000000
-- 248:dde00000dfe00000eef000000000000000000000000000000000000000000000
-- 249:0000043300000413000001420000000000000000000000000000000000000000
-- 250:3333333333333333222222220000000000000000000000000000000000000000
-- 251:3320000031200000221000000000000000000000000000000000000000000000
-- </TILES>

-- <SPRITES>
-- 000:eeeeeeeeeeeeeeeeeeeeeeeeeeeeee00eeee0044eee04444eee04444ee044440
-- 001:eeeeeeeeeeeeeeeeeeeeeeee00eeeeee4400eeee44440eee44440eee440440ee
-- 002:eeeeeeeeeeeeeeeeeeeeeeeee000ee00011100440111044401110444e0004440
-- 003:eeeeeeeeeeeeeeeeeeeeeeee00ee000e4400111044440110444401104404400e
-- 004:eeee2222eee22222eee33344ee343444ee343344ee334444eeee4444eee22922
-- 005:2eeeeeee2222eeee04eeeeee0444eeee40444eee0000eeee444eeeee2eeeeeee
-- 006:eeeee222eeee2222eeee3334eee34344eee34334eee33444eeeee444ee222299
-- 007:22eeeeee22222eee404eeeee40444eee440444ee40000eee4444eeee22eeeeee
-- 008:eeeeeeeeeeeeee22eeeee222eeeee333eeee3434eeee3433eeee3344eeeeee44
-- 009:eeeeeeee222eeeee222222ee4404eeee440444ee4440444e440000ee444444ee
-- 011:0000000000000000000000000000000000000000000000000000000200000020
-- 016:e0004440011104440111044001110444e0004444eee00004ee022220ee022220
-- 017:4404400e4444401000044010004401104444000e440020ee0022220ee022220e
-- 018:ee044440ee044444ee044440eee04444ee000044e0222204e0222200eeeeeeee
-- 019:440440ee444440ee000440ee004400ee4444020e4400222000022220eeeeeeee
-- 020:ee222922e2222999ecc29499eccc9999ecc99999eee999eeee333eeee3333eee
-- 021:9222eeee92222eee492cceee99ccceee999cceee999eeeeee333eeeee3333eee
-- 022:cc222299ccce2294ccee9999eee99999ee999999e33999eee333eeeeee333eee
-- 023:9222ccce99922cce999ee3ee999933ee999933eee99933eeeeeeeeeeeeeeeeee
-- 024:eeeee222eeeec222eeecc922eee33999eee39999ee33999eee3eeeeeeeeeeeee
-- 025:2292ecee2222ccce2222ccee99999eee99999eeee999eeee333eeeee3333eeee
-- 026:0022222902222222cc222222ccc099290c039999003339990333999903009999
-- 027:2222920092222903999999039499493399999933999999339990000000000000
-- 032:eeeeeeeeeeeeeeeeeeeeeeeeeeeeee00eeee0044eee04444eee04444ee044444
-- 033:eeeeeeeeeeeeeeeeeeeeeeee00eeeeee4400eeee44440eee44440eee044040ee
-- 034:eeeeeeeeeeeeeeeeeeeeeeeeeeeeee00eeee0044eee04444eee04444ee044444
-- 035:eeeeeeeeeeeeeeeeeeeeeeee00eeeeee4400eeee44440eee44440eee404400ee
-- 036:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee00eeee0044eee04444eee04444
-- 037:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee00eeeeee4400eeee44440eee44440eee
-- 038:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee00eeee0044eee04444eee04444
-- 039:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee00eeeeee4400eeee44440eee44440eee
-- 040:eeeeeeeeeeeeeeeeeeeeeeeeeeeeee00eeee0044eee04444eee04444ee044444
-- 041:eeeeeeeeeeeeeeeeeeeeeeee00eeeeee4400eeee44440eee44440eee044040ee
-- 042:eeeeeeeeeeeeeeeeeeeeeeeeeeeeee00eeee0044eee04444eee04444ee044444
-- 043:eeeeeeeeeeeeeeeeeeeeeeee00eeeeee4400eeee44440eee44440eee044040ee
-- 044:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee00eeee0044eee04444eee04444
-- 045:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee00eeeeee4400eeee44440eee44440eee
-- 046:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee00eeee0044eee04444eee04444
-- 047:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee00eeeeee4400eeee44440eee44440eee
-- 048:ee044444ee000444e0111044e0111044e0111044ee000000eee02222eee02222
-- 049:044040ee444440ee0000400e4004010e4444010e440000ee002220ee022220ee
-- 050:ee044444ee040004ee001110eee01110eee01110eeee0000eeeee022eeeee022
-- 051:404400ee444440ee400000ee44000eee44440eee0000eeee22020eee22020eee
-- 052:ee044444ee044444ee044400ee044011eee04011eee04011eee00000eee02200
-- 053:440440ee440440ee044440ee100000ee10400eee10440eee00000eee022220ee
-- 054:ee044444ee044444ee040004ee001110eee01110eee01110eee00000eeeeee02
-- 055:404400ee404400ee444440ee400000ee44000eee44440eee0000eeee2220eeee
-- 056:ee044444ee000444e0111044e0111044e0111044ee000000eee02222eee02222
-- 057:044040ee444440ee0000400e4004010e4444010e440000ee002220ee022220ee
-- 058:ee044444e0004444011104440111044401110444e0000004ee022220ee022220
-- 059:044040ee4444400e0000401040040110444400104400220e0022220eeeeeeeee
-- 060:ee044440ee044440e0004444011104400111044401110044e0002204e0222200
-- 061:440440ee440440ee4444400e0004401000440110444401104400000e0022220e
-- 062:ee044444ee044444e0004444011104440111044401110000e0002222eee02222
-- 063:044040ee044040ee4444400e0000401040040110444401100400000e00220eee
-- 064:00000000000000ee0000eecc000ecccc00eccccc00eccccf0ecccccceeeeeccc
-- 065:00000000ee000000ccee0000cccce000ccccceeefcffcececccccce0cccccce0
-- 066:00000000000000ee0000eedd000edddd00eddddd00eddddf0eddddddeeeeeddd
-- 067:00000000ee000000ddee0000dddde000dddddeeefdffdededddddde0dddddde0
-- 068:00000000000000ee0000eeff000effff00efffff00effffe0effffffeeeeefff
-- 069:00000000ee000000ffee0000ffffe000fffffeeeefeefedeffffffe0ffffffe0
-- 070:00000000000000ee0000ee00000e000000e0000000e000010e000000eeeee000
-- 071:00000000ee00000000ee00000000e00000000eee10110ede000000e0000000e0
-- 072:0000033000003303000030330003333300333000033303330333033333330333
-- 073:0033000003030000033300003333300030033000033033000333033003330330
-- 074:0000000000000ccc000ccccc00ccccc2002ccc22022ccc22022cccc2002ccccc
-- 075:00000000ccc00000ccccc0002ccccc0022ccc20022ccc2202cccc220ccccc200
-- 080:eecccccc0eeccccc00eeeccc00eceecc0ecccccceecccecc0eeee0ee00000000
-- 081:22222ce02222cce02222ce00c22cce00cccce000ccee0000ee00000000000000
-- 082:eedddddd0eeddddd00eeeddd00edeedd0eddddddeedddedd0eeee0ee00000000
-- 083:22222de02222dde02222de00d22dde00dddde000ddee0000ee00000000000000
-- 084:eeffffff0eefffff00eeefff00efeeff0effffffeefffeff0eeee0ee00000000
-- 085:22222fe02222ffe02222fe00f22ffe00ffffe000ffee0000ee00000000000000
-- 086:ee0000000ee0000000eee00000e0ee000e000000ee000e000eeee0ee00000000
-- 087:111110e0111100e011110e0001100e000000e00000ee0000ee00000000000000
-- 088:33030cc033330ccc303333333033333403330344003333430003333400000333
-- 089:0c0c03300ccc0303223333032243333333443030443433303343330033333000
-- 090:00ccccc4000cc34400000440000004440000044304400aaa0444aa990040a999
-- 091:4ccccc00443cc000404000004440000034400000aaa0044099aa4440999a0400
-- 096:00cccc000c444440c4444444c4444443c4444443444444430444443000333300
-- 097:00cccc0000c444000c4444400c4444300c444430044444300044430000333300
-- 098:000cc00000c4440000c4440000c4440000444300004443000044430000033000
-- 099:000cc000000c4000000c4000000c400000043000000430000004300000033000
-- 100:000cc00000c4440000c4440000c4440000444300004443000044430000033000
-- 101:00cccc0000c444000c4444400c4444300c444430044444300044430000333300
-- 112:00cccc000c444440c4433444c4433443c4433443444334430444443000333300
-- 113:00cccc0000c444000c4434400c4434300c443430044434300044430000333300
-- 114:000cc00000c4440000c4440000c4340000443300004443000044430000033000
-- 115:000cc000000c4000000c4000000c400000043000000430000004300000033000
-- 116:000cc00000c4440000c4440000c3440000434300004443000044430000033000
-- 117:00cccc0000c444000c4344400c4344300c434430044344300044430000333300
-- 128:00cccc000c444440c4433444c43ffc43c43ffc43444cc4430444443000333300
-- 129:00cccc0000c444000c4434400c43c4300c43c430044c44300044430000333300
-- 130:000cc00000c4440000c4440000c3c4000043c300004443000044430000033000
-- 131:000cc000000c4000000c4000000c400000043000000430000004300000033000
-- 132:000cc00000c4440000c4440000c3c4000043c300004443000044430000033000
-- 133:00cccc0000c444000c4434400c43c4300c43c430044c44300044430000333300
-- 192:0000000000000033000003440000034400003443000034430000034300000344
-- 193:3333330043443433344443443444434444444434444444344444443434444344
-- 194:0000000000000000300000003000000043000000430000003000000030000000
-- 195:000000000000000000000000000000000000000f0000000f000000f4000000f4
-- 196:0000ffff00ff44440f444444f444444444444444444444444444444444444444
-- 197:fff00000444f00004444f00044444f00444444f0444444f04444444f4444444f
-- 208:0000003400000034000000030000000000000000000000000000000000000002
-- 209:3444434343443443434434303333330000440000043340000044000022222222
-- 211:000000f4000000f4000000f4000000f4000000040000000f0000000000000000
-- 212:444444444444444444444444444444444444444444444444f44444440f444444
-- 213:4444444f4444444f4444444f4444444f444444f0444444f044444f004444f000
-- 224:000000220000002200000022003be022004ab0cc003be0cc000400cc02222222
-- 225:22222222222222222222222222224422ccc4224ccccc2dcccccc22cc22222222
-- 226:20000000200000002000000020000000c0002300c0023c00c023dc0022222200
-- 227:0000000000000000000000000003400400332332033333330033333300033333
-- 228:00ff44440000ffff000003330000033340000333400003333400033333443333
-- 229:44ff0000ff000000400000004000000040000000400000004000000034444444
-- 230:0000000000000000000000000000000000000000000000000000000044444444
-- 240:0ccccccc02222222002222220000000400000004000000040000000400000000
-- 241:cccccccc22222222222222220004004000040040000400400004004000040000
-- 242:cccccc0022222200222220000000000000000000000000000000000000000000
-- 243:0000323300003323000033230033323303333333033223220233333300000000
-- 244:2332332332332323323332332333232333333333333333333332000032000000
-- 245:33333333f3c3f3f3333333333332323333332323223333330000000000000000
-- 246:33333330c3c3c200333330003333200033330000333000000000000000000000
-- </SPRITES>

-- <MAP>
-- 052:000000000000000021212121000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 053:000000000000002121111121210000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 054:000000000000211111111111112100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 055:000000000021111111111111111121000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 056:000000002111111111111111111111210000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 057:000000002111111111111111111111210000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 058:000000211111111111111111111111112100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 059:000000211111111111111111111111112100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 060:000000002111111111111111111111210000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 061:000000002111111111111111111111210000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 062:000000000021111111111111111121000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 063:000000000000212111111111212100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 064:321212220000000021010121000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 065:526171512200000000010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 066:005202020222003222010132121212121212121212220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 067:000052025102125102020251024102410241024102510202020202a1b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 068:000000520202020202510202020202020202020202020202020291000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 069:000000320202510202020202020202020202020202020202020281000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 070:000032025102025102020202026171515102617151020202024200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 071:321251510251510202510251020202020202020202510202420000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 072:52313131313131313131313131313131313131313131a1b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- </MAP>

-- <WAVES>
-- 000:00000000ffffffff00000000ffffffff
-- 001:0123456789abcdeffedcba9876543210
-- 002:0123456789abcdef0123456789abcdef
-- </WAVES>

-- <SFX>
-- 000:000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000304000000000
-- </SFX>

-- <FLAGS>
-- 000:00100010300000000000000030303010000000101010101010101010303030001010101010101010101010103030300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- </FLAGS>

-- <PALETTE>
-- 000:1a1c2c5d275db13e53ef7d57ffcd75a7f07038b76425717929366f3b5dc941a6f673eff7f4f4f494b0c2566c86333c57
-- </PALETTE>

