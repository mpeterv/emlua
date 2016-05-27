local src = [==[
local utils = {}

function utils.array_to_set(array)
   local set = {}

   for index, value in ipairs(array) do
      set[value] = index
   end

   return set
end

-- Lexer should support syntax of Lua 5.1, Lua 5.2, Lua 5.3 and LuaJIT(64bit and complex cdata literals).
local lexer = {}

local sbyte = string.byte
local ssub = string.sub
local schar = string.char
local sreverse = string.reverse
local tconcat = table.concat
local mfloor = math.floor

-- No point in inlining these, fetching a constant ~= fetching a local.
local BYTE_0, BYTE_9, BYTE_f, BYTE_F = sbyte("0"), sbyte("9"), sbyte("f"), sbyte("F")
local BYTE_x, BYTE_X, BYTE_i, BYTE_I = sbyte("x"), sbyte("X"), sbyte("i"), sbyte("I")
local BYTE_l, BYTE_L, BYTE_u, BYTE_U = sbyte("l"), sbyte("L"), sbyte("u"), sbyte("U")
local BYTE_e, BYTE_E, BYTE_p, BYTE_P = sbyte("e"), sbyte("E"), sbyte("p"), sbyte("P")
local BYTE_a, BYTE_z, BYTE_A, BYTE_Z = sbyte("a"), sbyte("z"), sbyte("A"), sbyte("Z")
local BYTE_DOT, BYTE_COLON = sbyte("."), sbyte(":")
local BYTE_OBRACK, BYTE_CBRACK = sbyte("["), sbyte("]")
local BYTE_OBRACE, BYTE_CBRACE = sbyte("{"), sbyte("}")
local BYTE_QUOTE, BYTE_DQUOTE = sbyte("'"), sbyte('"')
local BYTE_PLUS, BYTE_DASH, BYTE_LDASH = sbyte("+"), sbyte("-"), sbyte("_")
local BYTE_SLASH, BYTE_BSLASH = sbyte("/"), sbyte("\\")
local BYTE_EQ, BYTE_NE = sbyte("="), sbyte("~")
local BYTE_LT, BYTE_GT = sbyte("<"), sbyte(">")
local BYTE_LF, BYTE_CR = sbyte("\n"), sbyte("\r")
local BYTE_SPACE, BYTE_FF, BYTE_TAB, BYTE_VTAB = sbyte(" "), sbyte("\f"), sbyte("\t"), sbyte("\v")

local function to_hex(b)
   if BYTE_0 <= b and b <= BYTE_9 then
      return b-BYTE_0
   elseif BYTE_a <= b and b <= BYTE_f then
      return 10+b-BYTE_a
   elseif BYTE_A <= b and b <= BYTE_F then
      return 10+b-BYTE_A
   else
      return nil
   end
end

local function to_dec(b)
   if BYTE_0 <= b and b <= BYTE_9 then
      return b-BYTE_0
   else
      return nil
   end
end

local function to_utf(codepoint)
   if codepoint < 0x80 then  -- ASCII?
      return schar(codepoint)
   end

   local buf = {}
   local mfb = 0x3F

   repeat
      buf[#buf+1] = schar(codepoint % 0x40 + 0x80)
      codepoint = mfloor(codepoint / 0x40)
      mfb = mfloor(mfb / 2)
   until codepoint <= mfb

   buf[#buf+1] = schar(0xFE - mfb*2 + codepoint)
   return sreverse(tconcat(buf))
end

local function is_alpha(b)
   return (BYTE_a <= b and b <= BYTE_z) or
      (BYTE_A <= b and b <= BYTE_Z) or b == BYTE_LDASH
end

local function is_newline(b)
   return (b == BYTE_LF) or (b == BYTE_CR)
end

local function is_space(b)
   return (b == BYTE_SPACE) or (b == BYTE_FF) or
      (b == BYTE_TAB) or (b == BYTE_VTAB)
end

local keywords = utils.array_to_set({
   "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "goto", "if", "in",
   "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while"})

local simple_escapes = {
   [sbyte("a")] = sbyte("\a"),
   [sbyte("b")] = sbyte("\b"),
   [sbyte("f")] = sbyte("\f"),
   [sbyte("n")] = sbyte("\n"),
   [sbyte("r")] = sbyte("\r"),
   [sbyte("t")] = sbyte("\t"),
   [sbyte("v")] = sbyte("\v"),
   [BYTE_BSLASH] = BYTE_BSLASH,
   [BYTE_QUOTE] = BYTE_QUOTE,
   [BYTE_DQUOTE] = BYTE_DQUOTE
}

local function next_byte(state, inc)
   inc = inc or 1
   state.offset = state.offset+inc
   return sbyte(state.src, state.offset)
end

-- Skipping helpers.
-- Take the current character, skip something, return next character.

local function skip_newline(state, newline)
   local b = next_byte(state)

   if b ~= newline and is_newline(b) then
      b = next_byte(state)
   end

   state.line = state.line+1
   state.line_offset = state.offset
   return b
end

local function skip_till_newline(state, b)
   while not is_newline(b) and b ~= nil do 
      b = next_byte(state)
   end

   return b
end

local function skip_space(state, b)
   while is_space(b) or is_newline(b) do
      if is_newline(b) then
         b = skip_newline(state, b)
      else
         b = next_byte(state)
      end
   end

   return b
end

-- Skips "[=*" or "]=*". Returns next character and number of "="s.
local function skip_long_bracket(state)
   local start = state.offset
   local b = next_byte(state)

   while b == BYTE_EQ do
      b = next_byte(state)
   end

   return b, state.offset-start-1
end

-- Token handlers.

-- Called after the opening "[=*" has been skipped.
-- Takes number of "=" in the opening bracket and token type(comment or string).
local function lex_long_string(state, opening_long_bracket, token)
   local b = next_byte(state)

   if is_newline(b) then
      b = skip_newline(state, b)
   end

   local lines = {}
   local line_start = state.offset

   while true do
      if is_newline(b) then
         -- Add the finished line.
         lines[#lines+1] = ssub(state.src, line_start, state.offset-1)

         b = skip_newline(state, b)
         line_start = state.offset
      elseif b == BYTE_CBRACK then
         local long_bracket
         b, long_bracket = skip_long_bracket(state)

         if b == BYTE_CBRACK and long_bracket == opening_long_bracket then
            break
         end
      elseif b == nil then
         return nil, token == "string" and "unfinished long string" or "unfinished long comment"
      else
         b = next_byte(state)
      end
   end

   -- Add last line. 
   lines[#lines+1] = ssub(state.src, line_start, state.offset-opening_long_bracket-2)
   next_byte(state)
   return token, tconcat(lines, "\n")
end

local function lex_short_string(state, quote)
   local b = next_byte(state)
   local chunks  -- Buffer is only required when there are escape sequences.
   local chunk_start = state.offset

   while b ~= quote do
      if b == BYTE_BSLASH then
         -- Escape sequence.

         if not chunks then
            -- This is the first escape sequence, init buffer.
            chunks = {}
         end

         -- Put previous chunk into buffer.
         if chunk_start ~= state.offset then
            chunks[#chunks+1] = ssub(state.src, chunk_start, state.offset-1)
         end

         b = next_byte(state)

         -- The final string escape sequence evaluates to.
         local s

         local escape_byte = simple_escapes[b]

         if escape_byte then  -- Is it a simple escape sequence?
            b = next_byte(state)
            s = schar(escape_byte)
         elseif is_newline(b) then
            b = skip_newline(state, b)
            s = "\n"
         elseif b == BYTE_x then
            -- Hexadecimal escape.
            b = next_byte(state)  -- Skip "x".
            -- Exactly two hexadecimal digits.
            local c1, c2

            if b then
               c1 = to_hex(b)
            end

            if not c1 then
               return nil, "invalid hexadecimal escape sequence", -2
            end

            b = next_byte(state)

            if b then
               c2 = to_hex(b)
            end

            if not c2 then
               return nil, "invalid hexadecimal escape sequence", -3
            end

            b = next_byte(state)
            s = schar(c1*16 + c2)
         elseif b == BYTE_u then
            b = next_byte(state)  -- Skip "u".

            if b ~= BYTE_OBRACE then
               return nil, "invalid UTF-8 escape sequence", -2
            end

            b = next_byte(state)  -- Skip "{".

            local codepoint  -- There should be at least one digit.

            if b then
               codepoint = to_hex(b)
            end

            if not codepoint then
               return nil, "invalid UTF-8 escape sequence", -3
            end

            local hexdigits = 0

            while true do
               b = next_byte(state)
               local hex

               if b then
                  hex = to_hex(b)
               end

               if hex then
                  hexdigits = hexdigits + 1
                  codepoint = codepoint*16 + hex

                  if codepoint > 0x10FFFF then
                     -- UTF-8 value too large.
                     return nil, "invalid UTF-8 escape sequence", -hexdigits-3
                  end
               else
                  break
               end
            end

            if b ~= BYTE_CBRACE then
               return nil, "invalid UTF-8 escape sequence", -hexdigits-4
            end

            b = next_byte(state)  -- Skip "}".
            s = to_utf(codepoint)
         elseif b == BYTE_z then
            -- Zap following span of spaces.
            b = skip_space(state, next_byte(state))
         else
            -- Must be a decimal escape.
            local cb

            if b then
               cb = to_dec(b)
            end

            if not cb then
               return nil, "invalid escape sequence", -1
            end

            -- Up to three decimal digits.
            b = next_byte(state)

            if b then
               local c2 = to_dec(b)

               if c2 then
                  cb = 10*cb + c2
                  b = next_byte(state)

                  if b then
                     local c3 = to_dec(b)

                     if c3 then
                        cb = 10*cb + c3

                        if cb > 255 then
                           return nil, "invalid decimal escape sequence", -3
                        end

                        b = next_byte(state)
                     end
                  end
               end
            end

            s = schar(cb)
         end

         if s then
            chunks[#chunks+1] = s
         end

         -- Next chunk starts after escape sequence.
         chunk_start = state.offset
      elseif b == nil or is_newline(b) then
         return nil, "unfinished string"
      else
         b = next_byte(state)
      end
   end

   -- Offset now points at the closing quote.
   local string_value

   if chunks then
      -- Put last chunk into buffer.
      if chunk_start ~= state.offset then
         chunks[#chunks+1] = ssub(state.src, chunk_start, state.offset-1)
      end

      string_value = tconcat(chunks)
   else
      -- There were no escape sequences.
      string_value = ssub(state.src, chunk_start, state.offset-1)
   end

   next_byte(state)  -- Skip the closing quote.
   return "string", string_value
end

-- Payload for a number is simply a substring.
-- Luacheck is supposed to be forward-compatible with Lua 5.3 and LuaJIT syntax, so
--    parsing it into actual number may be problematic.
-- It is not needed currently anyway as Luacheck does not do static evaluation yet.
local function lex_number(state, b)
   local start = state.offset

   local exp_lower, exp_upper = BYTE_e, BYTE_E
   local is_digit = to_dec
   local has_digits = false
   local is_float = false

   if b == BYTE_0 then
      b = next_byte(state)

      if b == BYTE_x or b == BYTE_X then
         exp_lower, exp_upper = BYTE_p, BYTE_P
         is_digit = to_hex
         b = next_byte(state)
      else
         has_digits = true
      end
   end

   while b ~= nil and is_digit(b) do
      b = next_byte(state)
      has_digits = true
   end

   if b == BYTE_DOT then
      -- Fractional part.
      is_float = true
      b = next_byte(state)  -- Skip dot.

      while b ~= nil and is_digit(b) do
         b = next_byte(state)
         has_digits = true
      end
   end

   if b == exp_lower or b == exp_upper then
      -- Exponent part.
      is_float = true
      b = next_byte(state)

      -- Skip optional sign.
      if b == BYTE_PLUS or b == BYTE_DASH then
         b = next_byte(state)
      end

      -- Exponent consists of one or more decimal digits.
      if b == nil or not to_dec(b) then
         return nil, "malformed number"
      end

      repeat
         b = next_byte(state)
      until b == nil or not to_dec(b)
   end

   if not has_digits then
      return nil, "malformed number"
   end

   -- Is it cdata literal?
   if b == BYTE_i or b == BYTE_I then
      -- It is complex literal. Skip "i" or "I".
      next_byte(state)
   else
      -- uint64_t and int64_t literals can not be fractional.
      if not is_float then
         if b == BYTE_u or b == BYTE_U then
            -- It may be uint64_t literal.
            local b1, b2 = sbyte(state.src, state.offset+1, state.offset+2)

            if (b1 == BYTE_l or b1 == BYTE_L) and (b2 == BYTE_l or b2 == BYTE_L) then
               -- It is uint64_t literal.
               next_byte(state, 3)
            end
         elseif b == BYTE_l or b == BYTE_L then
            -- It may be uint64_t or int64_t literal.
            local b1, b2 = sbyte(state.src, state.offset+1, state.offset+2)

            if b1 == BYTE_l or b1 == BYTE_L then
               if b2 == BYTE_u or b2 == BYTE_U then
                  -- It is uint64_t literal.
                  next_byte(state, 3)
               else
                  -- It is int64_t literal.
                  next_byte(state, 2)
               end
            end
         end
      end
   end

   return "number", ssub(state.src, start, state.offset-1)
end

local function lex_ident(state)
   local start = state.offset
   local b = next_byte(state)

   while (b ~= nil) and (is_alpha(b) or to_dec(b)) do
      b = next_byte(state)
   end

   local ident = ssub(state.src, start, state.offset-1)

   if keywords[ident] then
      return ident
   else
      return "name", ident
   end
end

local function lex_dash(state)
   local b = next_byte(state)

   -- Is it "-" or comment?
   if b ~= BYTE_DASH then
      return "-"
   else
      -- It is a comment.
      b = next_byte(state)
      local start = state.offset

      -- Is it a long comment?
      if b == BYTE_OBRACK then
         local long_bracket
         b, long_bracket = skip_long_bracket(state)

         if b == BYTE_OBRACK then
            return lex_long_string(state, long_bracket, "comment")
         end
      end

      -- Short comment.
      b = skip_till_newline(state, b)
      local comment_value = ssub(state.src, start, state.offset-1)
      skip_newline(state, b)
      return "comment", comment_value
   end
end

local function lex_bracket(state)
   -- Is it "[" or long string?
   local b, long_bracket = skip_long_bracket(state)

   if b == BYTE_OBRACK then
      return lex_long_string(state, long_bracket, "string")
   elseif long_bracket == 0 then
      return "["
   else
      return nil, "invalid long string delimiter"
   end
end

local function lex_eq(state)
   local b = next_byte(state)

   if b == BYTE_EQ then
      next_byte(state)
      return "=="
   else
      return "="
   end
end

local function lex_lt(state)
   local b = next_byte(state)

   if b == BYTE_EQ then
      next_byte(state)
      return "<="
   elseif b == BYTE_LT then
      next_byte(state)
      return "<<"
   else
      return "<"
   end
end

local function lex_gt(state)
   local b = next_byte(state)

   if b == BYTE_EQ then
      next_byte(state)
      return ">="
   elseif b == BYTE_GT then
      next_byte(state)
      return ">>"
   else
      return ">"
   end
end

local function lex_div(state)
   local b = next_byte(state)

   if b == BYTE_SLASH then
      next_byte(state)
      return "//"
   else
      return "/"
   end
end

local function lex_ne(state)
   local b = next_byte(state)

   if b == BYTE_EQ then
      next_byte(state)
      return "~="
   else
      return "~"
   end
end

local function lex_colon(state)
   local b = next_byte(state)

   if b == BYTE_COLON then
      next_byte(state)
      return "::"
   else
      return ":"
   end
end

local function lex_dot(state)
   local b = next_byte(state)

   if b == BYTE_DOT then
      b = next_byte(state)

      if b == BYTE_DOT then
         next_byte(state)
         return "...", "..."
      else
         return ".."
      end
   elseif b and to_dec(b) then
      -- Backtrack to dot.
      return lex_number(state, next_byte(state, -1))
   else
      return "."
   end
end

local function lex_any(state, b)
   next_byte(state)
   return schar(b)
end

-- Maps first bytes of tokens to functions that handle them.
-- Each handler takes the first byte as an argument.
-- Each handler stops at the character after the token and returns the token and,
--    optionally, a value associated with the token.
-- On error handler returns nil, error message and, optionally, start of reported location as negative offset.
local byte_handlers = {
   [BYTE_DOT] = lex_dot,
   [BYTE_COLON] = lex_colon,
   [BYTE_OBRACK] = lex_bracket,
   [BYTE_QUOTE] = lex_short_string,
   [BYTE_DQUOTE] = lex_short_string,
   [BYTE_DASH] = lex_dash,
   [BYTE_SLASH] = lex_div,
   [BYTE_EQ] = lex_eq,
   [BYTE_NE] = lex_ne,
   [BYTE_LT] = lex_lt,
   [BYTE_GT] = lex_gt,
   [BYTE_LDASH] = lex_ident
}

for b=BYTE_0, BYTE_9 do
   byte_handlers[b] = lex_number
end

for b=BYTE_a, BYTE_z do
   byte_handlers[b] = lex_ident
end

for b=BYTE_A, BYTE_Z do
   byte_handlers[b] = lex_ident
end

local function decimal_escaper(char)
   return "\\" .. tostring(sbyte(char))
end

-- Returns quoted printable representation of s.
function lexer.quote(s)
   return "'" .. s:gsub("[^\32-\126]", decimal_escaper) .. "'"
end

-- Creates and returns lexer state for source.
function lexer.new_state(src)
   local state = {
      src = src,
      line = 1,
      line_offset = 1,
      offset = 1
   }

   if ssub(src, 1, 2) == "#!" then
      -- Skip shebang.
      skip_newline(state, skip_till_newline(state, next_byte(state, 2)))
   end

   return state
end

function lexer.syntax_error(location, end_column, msg)
   error({
      line = location.line,
      column = location.column,
      end_column = end_column,
      msg = msg})
end

-- Looks for next token starting from state.line, state.line_offset, state.offset.
-- Returns next token, its value and its location (line, column, offset).
-- Sets state.line, state.line_offset, state.offset to token end location + 1.
-- On error returns nil, error message, error location (line, column, offset), error end column.
function lexer.next_token(state)
   local b = skip_space(state, sbyte(state.src, state.offset))

   -- Save location of token start.
   local token_line = state.line
   local token_column = state.offset - state.line_offset + 1
   local token_offset = state.offset

   local token, token_value, err_offset, err_end_column

   if b == nil then
      token = "eof"
   else
      token, token_value, err_offset = (byte_handlers[b] or lex_any)(state, b)
   end

   if err_offset then
      local token_body = ssub(state.src, state.offset + err_offset, state.offset)
      token_value = token_value .. " " .. lexer.quote(token_body)
      token_line = state.line
      token_column = state.offset - state.line_offset + 1 + err_offset
      token_offset = state.offset + err_offset
      err_end_column = token_column + #token_body - 1
   end

   return token, token_value, token_line, token_column, token_offset, err_end_column or token_column
end

local function new_state(src)
   return {
      lexer = lexer.new_state(src),
      code_lines = {}, -- Set of line numbers containing code.
      comments = {}, -- Array of {comment = string, location = location}.
      hanging_semicolons = {} -- Array of locations of semicolons not following an expression or goto.
   }
end

local function location(state)
   return {
      line = state.line,
      column = state.column,
      offset = state.offset
   }
end

local function token_body_or_line(state)
   return state.lexer.src:sub(state.offset, state.lexer.offset - 1):match("^[^\r\n]*")
end

local function skip_token(state)
   while true do
      local err_end_column
      state.token, state.token_value, state.line, state.column, state.offset, err_end_column = lexer.next_token(state.lexer)

      if not state.token then
         lexer.syntax_error(state, err_end_column, state.token_value)
      elseif state.token == "comment" then
         state.comments[#state.comments+1] = {
            contents = state.token_value,
            location = location(state),
            end_column = state.column + #token_body_or_line(state) - 1
         }
      else
         state.code_lines[state.line] = true
         break
      end
   end
end

local function init_ast_node(node, loc, tag)
   node.location = loc
   node.tag = tag
   return node
end

local function new_ast_node(state, tag)
   return init_ast_node({}, location(state), tag)
end

local token_names = {
   eof = "<eof>",
   name = "identifier",
   ["do"] = "'do'",
   ["end"] = "'end'",
   ["then"] = "'then'",
   ["in"] = "'in'",
   ["until"] = "'until'",
   ["::"] = "'::'"
}

local function token_name(token)
   return token_names[token] or lexer.quote(token)
end

local function parse_error(state, msg)
   local token_repr, end_column

   if state.token == "eof" then
      token_repr = "<eof>"
      end_column = state.column
   else
      token_repr = token_body_or_line(state)
      end_column = state.column + #token_repr - 1
      token_repr = lexer.quote(token_repr)
   end

   lexer.syntax_error(state, end_column, msg .. " near " .. token_repr)
end

local function check_token(state, token)
   if state.token ~= token then
      parse_error(state, "expected " .. token_name(token))
   end
end

local function check_and_skip_token(state, token)
   check_token(state, token)
   skip_token(state)
end

local function test_and_skip_token(state, token)
   if state.token == token then
      skip_token(state)
      return true
   end
end

local function check_closing_token(state, opening_token, closing_token, opening_line)
   if state.token ~= closing_token then
      local err = "expected " .. token_name(closing_token)

      if opening_line ~= state.line then
         err = err .. " (to close " .. token_name(opening_token) .. " on line " .. tostring(opening_line) .. ")"
      end

      parse_error(state, err)
   end

   skip_token(state)
end

local function check_name(state)
   check_token(state, "name")
   return state.token_value
end

-- If needed, wraps last expression in expressions in "Paren" node.
local function opt_add_parens(expressions, is_inside_parentheses)
   if is_inside_parentheses then
      local last = expressions[#expressions]

      if last and last.tag == "Call" or last.tag == "Invoke" or last.tag == "Dots" then
         expressions[#expressions] = init_ast_node({last}, last.location, "Paren")
      end
   end
end

local parse_block, parse_expression

local function parse_expression_list(state)
   local list = {}
   local is_inside_parentheses

   repeat
      list[#list+1], is_inside_parentheses = parse_expression(state)
   until not test_and_skip_token(state, ",")

   opt_add_parens(list, is_inside_parentheses)
   return list
end

local function parse_id(state, tag)
   local ast_node = new_ast_node(state, tag or "Id")
   ast_node[1] = check_name(state)
   skip_token(state)  -- Skip name.
   return ast_node
end

local function atom(tag)
   return function(state)
      local ast_node = new_ast_node(state, tag)
      ast_node[1] = state.token_value
      skip_token(state)
      return ast_node
   end
end

local simple_expressions = {}

simple_expressions.number = atom("Number")
simple_expressions.string = atom("String")
simple_expressions["nil"] = atom("Nil")
simple_expressions["true"] = atom("True")
simple_expressions["false"] = atom("False")
simple_expressions["..."] = atom("Dots")

simple_expressions["{"] = function(state)
   local ast_node = new_ast_node(state, "Table")
   local start_line = state.line
   skip_token(state)
   local is_inside_parentheses = false

   repeat
      if state.token == "}" then
         break
      else
         local lhs, rhs
         local item_location = location(state)
         local first_key_token

         if state.token == "name" then
            local name = state.token_value
            skip_token(state)  -- Skip name.

            if test_and_skip_token(state, "=") then
               -- `name` = `expr`.
               first_key_token = name
               lhs = init_ast_node({name}, item_location, "String")
               rhs, is_inside_parentheses = parse_expression(state)
            else
               -- `name` is beginning of an expression in array part.
               -- Backtrack lexer to before name.
               state.lexer.line = item_location.line
               state.lexer.line_offset = item_location.offset-item_location.column+1
               state.lexer.offset = item_location.offset
               skip_token(state)  -- Load name again.
               rhs, is_inside_parentheses = parse_expression(state, nil, true)
            end
         elseif state.token == "[" then
            -- [ `expr` ] = `expr`.
            item_location = location(state)
            first_key_token = "["
            skip_token(state)
            lhs = parse_expression(state)
            check_closing_token(state, "[", "]", item_location.line)
            check_and_skip_token(state, "=")
            rhs = parse_expression(state)
         else
            -- Expression in array part.
            rhs, is_inside_parentheses = parse_expression(state, nil, true)
         end

         if lhs then
            -- Pair.
            ast_node[#ast_node+1] = init_ast_node({lhs, rhs, first_token = first_key_token}, item_location, "Pair")
         else
            -- Array part item.
            ast_node[#ast_node+1] = rhs
         end
      end
   until not (test_and_skip_token(state, ",") or test_and_skip_token(state, ";"))

   check_closing_token(state, "{", "}", start_line)
   opt_add_parens(ast_node, is_inside_parentheses)
   return ast_node
end

-- Parses argument list and the statements.
local function parse_function(state, func_location)
   local paren_line = state.line
   check_and_skip_token(state, "(")
   local args = {}

   if state.token ~= ")" then  -- Are there arguments?
      repeat
         if state.token == "name" then
            args[#args+1] = parse_id(state)
         elseif state.token == "..." then
            args[#args+1] = simple_expressions["..."](state)
            break
         else
            parse_error(state, "expected argument")
         end
      until not test_and_skip_token(state, ",")
   end

   check_closing_token(state, "(", ")", paren_line)
   local body = parse_block(state)
   local end_location = location(state)
   check_closing_token(state, "function", "end", func_location.line)
   return init_ast_node({args, body, end_location = end_location}, func_location, "Function")
end

simple_expressions["function"] = function(state)
   local function_location = location(state)
   skip_token(state)  -- Skip "function".
   return parse_function(state, function_location)
end

local calls = {}

calls["("] = function(state)
   local paren_line = state.line
   skip_token(state) -- Skip "(".
   local args = (state.token == ")") and {} or parse_expression_list(state)
   check_closing_token(state, "(", ")", paren_line)
   return args
end

calls["{"] = function(state)
   return {simple_expressions[state.token](state)}
end

calls.string = calls["{"]

local suffixes = {}

suffixes["."] = function(state, lhs)
   skip_token(state)  -- Skip ".".
   local rhs = parse_id(state, "String")
   return init_ast_node({lhs, rhs}, lhs.location, "Index")
end

suffixes["["] = function(state, lhs)
   local bracket_line = state.line
   skip_token(state)  -- Skip "[".
   local rhs = parse_expression(state)
   check_closing_token(state, "[", "]", bracket_line)
   return init_ast_node({lhs, rhs}, lhs.location, "Index")
end

suffixes[":"] = function(state, lhs)
   skip_token(state)  -- Skip ":".
   local method_name = parse_id(state, "String")
   local args = (calls[state.token] or parse_error)(state, "expected method arguments")
   table.insert(args, 1, lhs)
   table.insert(args, 2, method_name)
   return init_ast_node(args, lhs.location, "Invoke")
end

suffixes["("] = function(state, lhs)
   local args = calls[state.token](state)
   table.insert(args, 1, lhs)
   return init_ast_node(args, lhs.location, "Call")
end

suffixes["{"] = suffixes["("]
suffixes.string = suffixes["("]

-- Additionally returns whether the expression is inside parens and the first non-paren token.
local function parse_simple_expression(state, kind, no_literals)
   local expression, first_token
   local in_parens = false

   if state.token == "(" then
      in_parens = true
      local paren_line = state.line
      skip_token(state)
      local _
      expression, _, first_token = parse_expression(state)
      check_closing_token(state, "(", ")", paren_line)
   elseif state.token == "name" then
      expression = parse_id(state)
      first_token = expression[1]
   else
      local literal_handler = simple_expressions[state.token]

      if not literal_handler or no_literals then
         parse_error(state, "expected " .. (kind or "expression"))
      end

      first_token = token_body_or_line(state)
      return literal_handler(state), false, first_token
   end

   while true do
      local suffix_handler = suffixes[state.token]

      if suffix_handler then
         in_parens = false
         expression = suffix_handler(state, expression)
      else
         return expression, in_parens, first_token
      end
   end
end

local unary_operators = {
   ["not"] = "not",
   ["-"] = "unm",  -- Not mentioned in Metalua documentation.
   ["~"] = "bnot",
   ["#"] = "len"
}

local unary_priority = 12

local binary_operators = {
   ["+"] = "add", ["-"] = "sub",
   ["*"] = "mul", ["%"] = "mod",
   ["^"] = "pow",
   ["/"] = "div", ["//"] = "idiv",
   ["&"] = "band", ["|"] = "bor", ["~"] = "bxor",
   ["<<"] = "shl", [">>"] = "shr",
   [".."] = "concat",
   ["~="] = "ne", ["=="] = "eq",
   ["<"] = "lt", ["<="] = "le",
   [">"] = "gt", [">="] = "ge",
   ["and"] = "and", ["or"] = "or"
}

local left_priorities = {
   add = 10, sub = 10,
   mul = 11, mod = 11,
   pow = 14,
   div = 11, idiv = 11,
   band = 6, bor = 4, bxor = 5,
   shl = 7, shr = 7,
   concat = 9,
   ne = 3, eq = 3,
   lt = 3, le = 3,
   gt = 3, ge = 3,
   ["and"] = 2, ["or"] = 1
}

local right_priorities = {
   add = 10, sub = 10,
   mul = 11, mod = 11,
   pow = 13,
   div = 11, idiv = 11,
   band = 6, bor = 4, bxor = 5,
   shl = 7, shr = 7,
   concat = 8,
   ne = 3, eq = 3,
   lt = 3, le = 3,
   gt = 3, ge = 3,
   ["and"] = 2, ["or"] = 1
}

-- Additionally returns whether subexpression is inside parentheses, and its first non-paren token.
local function parse_subexpression(state, limit, kind)
   local expression
   local first_token
   local in_parens = false
   local unary_operator = unary_operators[state.token]

   if unary_operator then
      first_token = state.token
      local unary_location = location(state)
      skip_token(state)  -- Skip operator.
      local unary_operand = parse_subexpression(state, unary_priority)
      expression = init_ast_node({unary_operator, unary_operand}, unary_location, "Op")
   else
      expression, in_parens, first_token = parse_simple_expression(state, kind)
   end

   -- Expand while operators have priorities higher than `limit`.
   while true do
      local binary_operator = binary_operators[state.token]

      if not binary_operator or left_priorities[binary_operator] <= limit then
         break
      end

      in_parens = false
      skip_token(state)  -- Skip operator.
      -- Read subexpression with higher priority.
      local subexpression = parse_subexpression(state, right_priorities[binary_operator])
      expression = init_ast_node({binary_operator, expression, subexpression}, expression.location, "Op")
   end

   return expression, in_parens, first_token
end

-- Additionally returns whether expression is inside parentheses and the first non-paren token.
function parse_expression(state, kind, save_first_token)
   local expression, in_parens, first_token = parse_subexpression(state, 0, kind)
   expression.first_token = save_first_token and first_token
   return expression, in_parens, first_token
end

local statements = {}

statements["if"] = function(state, loc)
   local start_line, start_token
   local next_line, next_token = loc.line, "if"
   local ast_node = init_ast_node({}, loc, "If")

   repeat
      ast_node[#ast_node+1] = parse_expression(state, "condition", true)
      local branch_location = location(state)
      check_and_skip_token(state, "then")
      ast_node[#ast_node+1] = parse_block(state, branch_location)
      start_line, start_token = next_line, next_token
      next_line, next_token = state.line, state.token
   until not test_and_skip_token(state, "elseif")

   if state.token == "else" then
      start_line, start_token = next_line, next_token
      local branch_location = location(state)
      skip_token(state)
      ast_node[#ast_node+1] = parse_block(state, branch_location)
   end

   check_closing_token(state, start_token, "end", start_line)
   return ast_node
end

statements["while"] = function(state, loc)
   local condition = parse_expression(state, "condition")
   check_and_skip_token(state, "do")
   local block = parse_block(state)
   check_closing_token(state, "while", "end", loc.line)
   return init_ast_node({condition, block}, loc, "While")
end

statements["do"] = function(state, loc)
   local ast_node = init_ast_node(parse_block(state), loc, "Do")
   check_closing_token(state, "do", "end", loc.line)
   return ast_node
end

statements["for"] = function(state, loc)
   local ast_node = init_ast_node({}, loc)  -- Will set ast_node.tag later.
   local first_var = parse_id(state)

   if state.token == "=" then
      -- Numeric "for" loop.
      ast_node.tag = "Fornum"
      skip_token(state)
      ast_node[1] = first_var
      ast_node[2] = parse_expression(state)
      check_and_skip_token(state, ",")
      ast_node[3] = parse_expression(state)

      if test_and_skip_token(state, ",") then
         ast_node[4] = parse_expression(state)
      end

      check_and_skip_token(state, "do")
      ast_node[#ast_node+1] = parse_block(state)
   elseif state.token == "," or state.token == "in" then
      -- Generic "for" loop.
      ast_node.tag = "Forin"

      local iter_vars = {first_var}
      while test_and_skip_token(state, ",") do
         iter_vars[#iter_vars+1] = parse_id(state)
      end

      ast_node[1] = iter_vars
      check_and_skip_token(state, "in")
      ast_node[2] = parse_expression_list(state)
      check_and_skip_token(state, "do")
      ast_node[3] = parse_block(state)
   else
      parse_error(state, "expected '=', ',' or 'in'")
   end

   check_closing_token(state, "for", "end", loc.line)
   return ast_node
end

statements["repeat"] = function(state, loc)
   local block = parse_block(state)
   check_closing_token(state, "repeat", "until", loc.line)
   local condition = parse_expression(state, "condition", true)
   return init_ast_node({block, condition}, loc, "Repeat")
end

statements["function"] = function(state, loc)
   local lhs_location = location(state)
   local lhs = parse_id(state)
   local self_location

   while (not self_location) and (state.token == "." or state.token == ":") do
      self_location = state.token == ":" and location(state)
      skip_token(state)  -- Skip "." or ":".
      lhs = init_ast_node({lhs, parse_id(state, "String")}, lhs_location, "Index")
   end

   local function_node = parse_function(state, loc)

   if self_location then
      -- Insert implicit "self" argument.
      local self_arg = init_ast_node({"self", implicit = true}, self_location, "Id")
      table.insert(function_node[1], 1, self_arg)
   end

   return init_ast_node({{lhs}, {function_node}}, loc, "Set")
end

statements["local"] = function(state, loc)
   if state.token == "function" then
      -- Localrec
      local function_location = location(state)
      skip_token(state)  -- Skip "function".
      local var = parse_id(state)
      local function_node = parse_function(state, function_location)
      -- Metalua would return {{var}, {function}} for some reason.
      return init_ast_node({var, function_node}, loc, "Localrec")
   end

   local lhs = {}
   local rhs

   repeat
      lhs[#lhs+1] = parse_id(state)
   until not test_and_skip_token(state, ",")

   local equals_location = location(state)

   if test_and_skip_token(state, "=") then
      rhs = parse_expression_list(state)
   end

   -- According to Metalua spec, {lhs} should be returned if there is no rhs.
   -- Metalua does not follow the spec itself and returns {lhs, {}}.
   return init_ast_node({lhs, rhs, equals_location = rhs and equals_location}, loc, "Local")
end

statements["::"] = function(state, loc)
   local end_column = loc.column + 1
   local name = check_name(state)

   if state.line == loc.line then
      -- Label name on the same line as opening `::`, pull token end to name end.
      end_column = state.column + #state.token_value - 1
   end

   skip_token(state)  -- Skip label name.

   if state.line == loc.line then
      -- Whole label is on one line, pull token end to closing `::` end.
      end_column = state.column + 1
   end

   check_and_skip_token(state, "::")
   return init_ast_node({name, end_column = end_column}, loc, "Label")
end

local closing_tokens = utils.array_to_set({
   "end", "eof", "else", "elseif", "until"})

statements["return"] = function(state, loc)
   if closing_tokens[state.token] or state.token == ";" then
      -- No return values.
      return init_ast_node({}, loc, "Return")
   else
      return init_ast_node(parse_expression_list(state), loc, "Return")
   end
end

statements["break"] = function(_, loc)
   return init_ast_node({}, loc, "Break")
end

statements["goto"] = function(state, loc)
   local name = check_name(state)
   skip_token(state)  -- Skip label name.
   return init_ast_node({name}, loc, "Goto")
end

local function parse_expression_statement(state, loc)
   local lhs

   repeat
      local first_loc = lhs and location(state) or loc
      local expected = lhs and "identifier or field" or "statement"
      local primary_expression, in_parens = parse_simple_expression(state, expected, true)

      if in_parens then
         -- (expr) is invalid.
         lexer.syntax_error(first_loc, first_loc.column, "expected " .. expected .. " near '('")
      end

      if primary_expression.tag == "Call" or primary_expression.tag == "Invoke" then
         if lhs then
            -- This is an assingment, and a call is not a valid lvalue.
            parse_error(state, "expected call or indexing")
         else
            -- It is a call.
            primary_expression.location = loc
            return primary_expression
         end
      end

      -- This is an assignment.
      lhs = lhs or {}
      lhs[#lhs+1] = primary_expression
   until not test_and_skip_token(state, ",")

   local equals_location = location(state)
   check_and_skip_token(state, "=")
   local rhs = parse_expression_list(state)
   return init_ast_node({lhs, rhs, equals_location = equals_location}, loc, "Set")
end

local function parse_statement(state)
   local loc = location(state)
   local statement_parser = statements[state.token]

   if statement_parser then
      skip_token(state)
      return statement_parser(state, loc)
   else
      return parse_expression_statement(state, loc)
   end
end

function parse_block(state, loc)
   local block = {location = loc}
   local after_statement = false

   while not closing_tokens[state.token] do
      local first_token = state.token

      if first_token == ";" then
         if not after_statement then
            table.insert(state.hanging_semicolons, location(state))
         end

         skip_token(state)
         -- Do not allow several semicolons in a row, even if the first one is valid.
         after_statement = false
      else
         first_token = state.token_value or first_token
         local statement = parse_statement(state)
         after_statement = true
         statement.first_token = first_token
         block[#block+1] = statement

         if first_token == "return" then
            -- "return" must be the last statement.
            -- However, one ";" after it is allowed.
            test_and_skip_token(state, ";")
            
            if not closing_tokens[state.token] then
               parse_error(state, "expected end of block")
            end
         end
      end
   end

   return block
end

-- Parses source string.
-- Returns AST (in almost MetaLua format), array of comments - tables {comment = string, location = location},
-- set of line numbers containing code, and array of locations of empty statements (semicolons).
-- On error throws {line = line, column = column, end_column = end_column, msg = msg}
local function parse(src)
   local state = new_state(src)
   skip_token(state)
   local ast = parse_block(state)
   check_token(state, "eof")
   return ast, state.comments, state.code_lines, state.hanging_semicolons
end

return parse
]==]

local parse = (loadstring or load)(src)()
print(parse(src))
