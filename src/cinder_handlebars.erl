-module(cinder_handlebars).
-export([parse/1,file/1]).
-define(p_anything,true).
-define(p_charclass,true).
-define(p_choose,true).
-define(p_label,true).
-define(p_not,true).
-define(p_one_or_more,true).
-define(p_optional,true).
-define(p_scan,true).
-define(p_seq,true).
-define(p_string,true).
-define(p_zero_or_more,true).



-spec file(file:name()) -> any().
file(Filename) -> case file:read_file(Filename) of {ok,Bin} -> parse(Bin); Err -> Err end.

-spec parse(binary() | list()) -> any().
parse(List) when is_list(List) -> parse(unicode:characters_to_binary(List));
parse(Input) when is_binary(Input) ->
  _ = setup_memo(),
  Result = case 'template'(Input,{{line,1},{column,1}}) of
             {AST, <<>>, _Index} -> AST;
             Any -> Any
           end,
  release_memo(), Result.

-spec 'template'(input(), index()) -> parse_result().
'template'(Input, Index) ->
  p(Input, Index, 'template', fun(I,D) -> (p_zero_or_more(fun 'template_content'/2))(I,D) end, fun(Node, Idx) ->transform('template', Node, Idx) end).

-spec 'template_content'(input(), index()) -> parse_result().
'template_content'(Input, Index) ->
  p(Input, Index, 'template_content', fun(I,D) -> (p_choose([fun 'doctype'/2, fun 'comment'/2, fun 'component'/2, fun 'tag'/2, fun 'handlebars'/2, fun 'text'/2]))(I,D) end, fun(Node, Idx) ->transform('template_content', Node, Idx) end).

-spec 'component'(input(), index()) -> parse_result().
'component'(Input, Index) ->
  p(Input, Index, 'component', fun(I,D) -> (p_choose([fun 'content_component'/2, fun 'void_component'/2]))(I,D) end, fun(Node, Idx) ->transform('component', Node, Idx) end).

-spec 'content_component'(input(), index()) -> parse_result().
'content_component'(Input, Index) ->
  p(Input, Index, 'content_component', fun(I,D) -> (p_seq([p_label('tag_start', fun 'component_tag_start'/2), p_label('content', p_optional(fun 'component_block'/2)), p_label('tag_end', fun 'component_tag_end'/2)]))(I,D) end, fun(Node, _Idx) ->
    {component_start, Name, Attributes} = proplists:get_value(tag_start, Node),
    {component_end, Name} = proplists:get_value(tag_end, Node),
    Content = proplists:get_value(content, Node),
    {component, Name, Attributes, Content}
   end).

-spec 'void_component'(input(), index()) -> parse_result().
'void_component'(Input, Index) ->
  p(Input, Index, 'void_component', fun(I,D) -> (p_seq([p_string(<<"<">>), p_optional(fun 'space'/2), fun 'component_alias'/2, p_optional(fun 'space'/2), p_optional(fun 'attributes'/2), p_optional(fun 'space'/2), p_string(<<"\/>">>)]))(I,D) end, fun(Node, _Idx) ->{component, lists:nth(3, Node), lists:nth(5, Node)} end).

-spec 'component_tag_start'(input(), index()) -> parse_result().
'component_tag_start'(Input, Index) ->
  p(Input, Index, 'component_tag_start', fun(I,D) -> (p_seq([p_string(<<"<">>), p_optional(fun 'space'/2), fun 'component_alias'/2, p_optional(fun 'space'/2), p_optional(fun 'attributes'/2), p_optional(fun 'space'/2), p_string(<<">">>)]))(I,D) end, fun(Node, _Idx) ->{component_start, lists:nth(3, Node), lists:nth(5, Node)} end).

-spec 'component_tag_end'(input(), index()) -> parse_result().
'component_tag_end'(Input, Index) ->
  p(Input, Index, 'component_tag_end', fun(I,D) -> (p_seq([p_string(<<"<\/">>), p_optional(fun 'space'/2), fun 'component_alias'/2, p_optional(fun 'space'/2), p_string(<<">">>)]))(I,D) end, fun(Node, _Idx) ->{component_end, lists:nth(3, Node)} end).

-spec 'component_alias'(input(), index()) -> parse_result().
'component_alias'(Input, Index) ->
  p(Input, Index, 'component_alias', fun(I,D) -> (p_seq([p_label('head', fun 'component_alias_segment'/2), p_label('tail', p_zero_or_more(p_seq([p_choose([p_string(<<".">>), p_string(<<"::">>)]), fun 'component_alias'/2])))]))(I,D) end, fun(Node, _Idx) ->
    Head = proplists:get_value(head, Node),
    Tail = lists:map(fun([_, E]) -> E end, proplists:get_value(tail, Node)),
    [Head | Tail]
   end).

-spec 'component_alias_segment'(input(), index()) -> parse_result().
'component_alias_segment'(Input, Index) ->
  p(Input, Index, 'component_alias_segment', fun(I,D) -> (p_seq([p_charclass(<<"[A-Z]">>), p_zero_or_more(p_charclass(<<"[a-zA-Z0-9_]">>))]))(I,D) end, fun(Node, _Idx) ->iolist_to_binary(Node) end).

-spec 'component_block'(input(), index()) -> parse_result().
'component_block'(Input, Index) ->
  p(Input, Index, 'component_block', fun(I,D) -> (p_one_or_more(p_choose([fun 'component_slot'/2, fun 'template_content'/2])))(I,D) end, fun(Node, Idx) ->transform('component_block', Node, Idx) end).

-spec 'component_slot'(input(), index()) -> parse_result().
'component_slot'(Input, Index) ->
  p(Input, Index, 'component_slot', fun(I,D) -> (p_seq([p_label('head', fun 'component_slot_start'/2), p_label('content', p_zero_or_more(fun 'template_content'/2)), p_label('tail', fun 'component_slot_end'/2)]))(I,D) end, fun(Node, _Idx) ->
    {slot_start, Name} = proplists:get_value(head, Node),
    {slot_end, Name} = proplists:get_value(tail, Node),
    Content = proplists:get_value(content, Node),
    {slot, Name, Content}
   end).

-spec 'component_slot_start'(input(), index()) -> parse_result().
'component_slot_start'(Input, Index) ->
  p(Input, Index, 'component_slot_start', fun(I,D) -> (p_seq([p_string(<<"<">>), p_optional(fun 'space'/2), p_string(<<":">>), p_optional(fun 'space'/2), fun 'ident'/2, p_optional(fun 'space'/2), p_string(<<">">>)]))(I,D) end, fun(Node, _Idx) ->{slot_start, lists:nth(5, Node)} end).

-spec 'component_slot_end'(input(), index()) -> parse_result().
'component_slot_end'(Input, Index) ->
  p(Input, Index, 'component_slot_end', fun(I,D) -> (p_seq([p_string(<<"<\/">>), p_optional(fun 'space'/2), p_string(<<":">>), p_optional(fun 'space'/2), fun 'ident'/2, p_optional(fun 'space'/2), p_string(<<">">>)]))(I,D) end, fun(Node, _Idx) ->{slot_end, lists:nth(5, Node)} end).

-spec 'tag'(input(), index()) -> parse_result().
'tag'(Input, Index) ->
  p(Input, Index, 'tag', fun(I,D) -> (p_choose([fun 'content_tag'/2, fun 'void_tag'/2]))(I,D) end, fun(Node, Idx) ->transform('tag', Node, Idx) end).

-spec 'content_tag'(input(), index()) -> parse_result().
'content_tag'(Input, Index) ->
  p(Input, Index, 'content_tag', fun(I,D) -> (p_seq([p_label('tag_start', fun 'content_tag_start'/2), p_label('content', p_optional(fun 'template'/2)), p_label('tag_end', fun 'content_tag_end'/2)]))(I,D) end, fun(Node, _Idx) ->
    {element_start, Name, Attributes} = proplists:get_value(tag_start, Node),
    Content = proplists:get_value(content, Node),
    {element_end, Name} = proplists:get_value(tag_end, Node),
    {element, Name, Attributes, Content}
   end).

-spec 'content_tag_start'(input(), index()) -> parse_result().
'content_tag_start'(Input, Index) ->
  p(Input, Index, 'content_tag_start', fun(I,D) -> (p_seq([p_string(<<"<">>), p_optional(fun 'space'/2), fun 'ident'/2, p_optional(fun 'space'/2), p_optional(fun 'attributes'/2), p_optional(fun 'space'/2), p_string(<<">">>)]))(I,D) end, fun(Node, _Idx) ->{element_start, lists:nth(3, Node), lists:nth(5, Node)} end).

-spec 'content_tag_end'(input(), index()) -> parse_result().
'content_tag_end'(Input, Index) ->
  p(Input, Index, 'content_tag_end', fun(I,D) -> (p_seq([p_string(<<"<\/">>), p_optional(fun 'space'/2), fun 'ident'/2, p_optional(fun 'space'/2), p_string(<<">">>)]))(I,D) end, fun(Node, _Idx) ->{element_end, lists:nth(3, Node)} end).

-spec 'void_tag'(input(), index()) -> parse_result().
'void_tag'(Input, Index) ->
  p(Input, Index, 'void_tag', fun(I,D) -> (p_seq([p_string(<<"<">>), p_optional(fun 'space'/2), fun 'ident'/2, p_optional(fun 'space'/2), p_optional(fun 'attributes'/2), p_optional(fun 'space'/2), p_string(<<"\/>">>)]))(I,D) end, fun(Node, _Idx) ->{element, lists:nth(3, Node), lists:nth(5, Node)} end).

-spec 'attributes'(input(), index()) -> parse_result().
'attributes'(Input, Index) ->
  p(Input, Index, 'attributes', fun(I,D) -> (p_seq([p_label('head', fun 'attribute'/2), p_label('tail', p_zero_or_more(p_seq([fun 'space'/2, fun 'attribute'/2])))]))(I,D) end, fun(Node, _Idx) ->
    Head = proplists:get_value(head, Node),
    Rest = lists:map(fun([_, A]) -> A end, proplists:get_value(tail, Node)),
    [Head | Rest]
   end).

-spec 'attribute'(input(), index()) -> parse_result().
'attribute'(Input, Index) ->
  p(Input, Index, 'attribute', fun(I,D) -> (p_choose([fun 'attribute_with_value'/2, fun 'attribute_simple'/2]))(I,D) end, fun(Node, Idx) ->transform('attribute', Node, Idx) end).

-spec 'attribute_with_value'(input(), index()) -> parse_result().
'attribute_with_value'(Input, Index) ->
  p(Input, Index, 'attribute_with_value', fun(I,D) -> (p_seq([p_label('name', fun 'ident'/2), p_optional(fun 'space'/2), p_string(<<"=">>), p_optional(fun 'space'/2), p_label('value', p_choose([fun 'string'/2, fun 'handlebars_expr'/2]))]))(I,D) end, fun(Node, _Idx) ->
    Name = proplists:get_value(name, Node),
    Value = proplists:get_value(value, Node),
    {Name, Value}
   end).

-spec 'attribute_simple'(input(), index()) -> parse_result().
'attribute_simple'(Input, Index) ->
  p(Input, Index, 'attribute_simple', fun(I,D) -> (fun 'ident'/2)(I,D) end, fun(Node, _Idx) ->iolist_to_binary(Node) end).

-spec 'doctype'(input(), index()) -> parse_result().
'doctype'(Input, Index) ->
  p(Input, Index, 'doctype', fun(I,D) -> (p_seq([p_choose([p_string(<<"<!doctype">>), p_string(<<"<!DOCTYPE">>)]), p_label('chars', p_zero_or_more(p_seq([p_not(p_string(<<">">>)), p_anything()]))), p_string(<<">">>)]))(I,D) end, fun(Node, _Idx) ->{doctype, iolist_to_binary(proplists:get_value(chars, Node))} end).

-spec 'comment'(input(), index()) -> parse_result().
'comment'(Input, Index) ->
  p(Input, Index, 'comment', fun(I,D) -> (p_seq([p_string(<<"<!--">>), p_label('chars', p_one_or_more(p_seq([p_not(p_string(<<"-->">>)), p_anything()]))), p_string(<<"-->">>)]))(I,D) end, fun(Node, _Idx) ->{comment, iolist_to_binary(proplists:get_value(chars, Node))} end).

-spec 'handlebars'(input(), index()) -> parse_result().
'handlebars'(Input, Index) ->
  p(Input, Index, 'handlebars', fun(I,D) -> (p_choose([fun 'handlebars_expr'/2, fun 'handlebars_safe_expr'/2, fun 'handlebars_comment'/2, fun 'handlebars_block'/2]))(I,D) end, fun(Node, Idx) ->transform('handlebars', Node, Idx) end).

-spec 'handlebars_expr'(input(), index()) -> parse_result().
'handlebars_expr'(Input, Index) ->
  p(Input, Index, 'handlebars_expr', fun(I,D) -> (p_seq([p_seq([p_not(p_choose([p_string(<<"{{!">>), p_string(<<"{{{">>), p_string(<<"{{#">>), p_string(<<"{{else}}">>)])), p_string(<<"{{">>)]), p_optional(fun 'space'/2), fun 'expr'/2, p_optional(fun 'space'/2), p_string(<<"}}">>)]))(I,D) end, fun(Node, _Idx) ->{expr, lists:nth(3, Node)} end).

-spec 'handlebars_safe_expr'(input(), index()) -> parse_result().
'handlebars_safe_expr'(Input, Index) ->
  p(Input, Index, 'handlebars_safe_expr', fun(I,D) -> (p_seq([p_string(<<"{{{">>), p_optional(fun 'space'/2), fun 'expr'/2, p_optional(fun 'space'/2), p_string(<<"}}}">>)]))(I,D) end, fun(Node, _Idx) ->{safe_expr, lists:nth(3, Node)} end).

-spec 'handlebars_comment'(input(), index()) -> parse_result().
'handlebars_comment'(Input, Index) ->
  p(Input, Index, 'handlebars_comment', fun(I,D) -> (p_choose([p_seq([p_string(<<"{{!--">>), p_zero_or_more(p_seq([p_not(p_string(<<"--}}">>)), p_anything()])), p_string(<<"--}}">>)]), p_seq([p_string(<<"{{!">>), p_zero_or_more(p_seq([p_not(p_string(<<"}}">>)), p_anything()])), p_string(<<"}}">>)])]))(I,D) end, fun(_Node, _Idx) ->comment end).

-spec 'handlebars_block'(input(), index()) -> parse_result().
'handlebars_block'(Input, Index) ->
  p(Input, Index, 'handlebars_block', fun(I,D) -> (p_seq([p_label('block_start', fun 'handlebars_block_start'/2), p_label('positive', fun 'template'/2), p_label('negative', p_optional(p_seq([p_string(<<"{{else}}">>), fun 'template'/2]))), p_label('block_end', fun 'handlebars_block_end'/2)]))(I,D) end, fun(Node, _Idx) ->
    {block_start, Name, Args, Params} = proplists:get_value(block_start, Node),
    {block_end, Name} = proplists:get_value(block_end, Node),
    Positive = proplists:get_value(positive, Node),
    Negative = proplists:get_value(negative, Node),
    case length(Negative) of
      0 -> {block, Name, Args, Positive, [], Params};
      _ -> {block, Name, Args, Positive, lists:nth(2, Negative), Params}
    end
   end).

-spec 'handlebars_block_start'(input(), index()) -> parse_result().
'handlebars_block_start'(Input, Index) ->
  p(Input, Index, 'handlebars_block_start', fun(I,D) -> (p_seq([p_string(<<"{{#">>), p_label('name', fun 'identifier'/2), p_label('args', p_zero_or_more(p_seq([fun 'space'/2, fun 'handlebars_block_arg'/2]))), p_label('params', p_optional(fun 'handlebars_block_params'/2)), p_optional(fun 'space'/2), p_string(<<"}}">>)]))(I,D) end, fun(Node, _Idx) ->
    Name = proplists:get_value(name, Node),
    Args = lists:map(fun([_, E]) -> E end, proplists:get_value(args, Node)),
    Params = proplists:get_value(params, Node),
    {block_start, Name, Args, Params}
   end).

-spec 'handlebars_block_arg'(input(), index()) -> parse_result().
'handlebars_block_arg'(Input, Index) ->
  p(Input, Index, 'handlebars_block_arg', fun(I,D) -> (p_seq([p_not(p_string(<<"as">>)), fun 'helper_arg'/2]))(I,D) end, fun(Node, _Idx) ->lists:nth(2, Node) end).

-spec 'handlebars_block_params'(input(), index()) -> parse_result().
'handlebars_block_params'(Input, Index) ->
  p(Input, Index, 'handlebars_block_params', fun(I,D) -> (p_seq([fun 'space'/2, p_string(<<"as">>), fun 'space'/2, p_string(<<"|">>), p_optional(fun 'space'/2), p_label('params', p_optional(p_seq([fun 'identifier'/2, p_zero_or_more(p_seq([fun 'space'/2, fun 'identifier'/2]))]))), p_optional(fun 'space'/2), p_string(<<"|">>)]))(I,D) end, fun(Node, _Idx) ->
    Params = lists:flatten(proplists:get_value(params, Node)),
    lists:filter(fun(E) -> is_atom(E) end, Params)
   end).

-spec 'handlebars_block_end'(input(), index()) -> parse_result().
'handlebars_block_end'(Input, Index) ->
  p(Input, Index, 'handlebars_block_end', fun(I,D) -> (p_seq([p_string(<<"{{\/">>), fun 'identifier'/2, p_string(<<"}}">>)]))(I,D) end, fun(Node, _Idx) ->{block_end, lists:nth(2, Node)} end).

-spec 'base_expr'(input(), index()) -> parse_result().
'base_expr'(Input, Index) ->
  p(Input, Index, 'base_expr', fun(I,D) -> (p_choose([fun 'literal'/2, fun 'path'/2, fun 'identifier'/2, fun 'sub_expr'/2, fun 'at_identifier'/2]))(I,D) end, fun(Node, Idx) ->transform('base_expr', Node, Idx) end).

-spec 'sub_expr'(input(), index()) -> parse_result().
'sub_expr'(Input, Index) ->
  p(Input, Index, 'sub_expr', fun(I,D) -> (p_seq([p_string(<<"(">>), p_optional(fun 'space'/2), fun 'expr'/2, p_optional(fun 'space'/2), p_string(<<")">>)]))(I,D) end, fun(Node, _Idx) ->{expr, lists:nth(3, Node)} end).

-spec 'expr'(input(), index()) -> parse_result().
'expr'(Input, Index) ->
  p(Input, Index, 'expr', fun(I,D) -> (p_choose([fun 'helper'/2, fun 'base_expr'/2]))(I,D) end, fun(Node, Idx) ->transform('expr', Node, Idx) end).

-spec 'helper'(input(), index()) -> parse_result().
'helper'(Input, Index) ->
  p(Input, Index, 'helper', fun(I,D) -> (p_seq([p_label('name', fun 'identifier'/2), p_label('args', p_one_or_more(p_seq([fun 'space'/2, fun 'helper_arg'/2])))]))(I,D) end, fun(Node, _Idx) ->
    Name = proplists:get_value(name, Node),
    Args = lists:map(fun([_, E]) -> E end, proplists:get_value(args, Node)),
    {Name, Args}
   end).

-spec 'helper_arg'(input(), index()) -> parse_result().
'helper_arg'(Input, Index) ->
  p(Input, Index, 'helper_arg', fun(I,D) -> (p_choose([fun 'helper_arg_hash'/2, fun 'helper_arg_plain'/2]))(I,D) end, fun(Node, Idx) ->transform('helper_arg', Node, Idx) end).

-spec 'helper_arg_plain'(input(), index()) -> parse_result().
'helper_arg_plain'(Input, Index) ->
  p(Input, Index, 'helper_arg_plain', fun(I,D) -> (fun 'base_expr'/2)(I,D) end, fun(Node, Idx) ->transform('helper_arg_plain', Node, Idx) end).

-spec 'helper_arg_hash'(input(), index()) -> parse_result().
'helper_arg_hash'(Input, Index) ->
  p(Input, Index, 'helper_arg_hash', fun(I,D) -> (p_seq([p_label('name', fun 'identifier'/2), p_string(<<"=">>), p_label('value', fun 'base_expr'/2)]))(I,D) end, fun(Node, _Idx) ->
    Name = proplists:get_value(name, Node),
    Value = proplists:get_value(value, Node),
    {'=', Name, Value}
   end).

-spec 'identifier'(input(), index()) -> parse_result().
'identifier'(Input, Index) ->
  p(Input, Index, 'identifier', fun(I,D) -> (fun 'ident'/2)(I,D) end, fun(Node, _Idx) ->binary_to_atom(Node) end).

-spec 'at_identifier'(input(), index()) -> parse_result().
'at_identifier'(Input, Index) ->
  p(Input, Index, 'at_identifier', fun(I,D) -> (p_seq([p_string(<<"@">>), fun 'identifier'/2]))(I,D) end, fun(Node, _Idx) ->{'@', lists:nth(2, Node)} end).

-spec 'path'(input(), index()) -> parse_result().
'path'(Input, Index) ->
  p(Input, Index, 'path', fun(I,D) -> (p_seq([p_label('head', p_choose([fun 'identifier'/2, fun 'at_identifier'/2])), p_label('tail', p_one_or_more(p_seq([p_choose([p_string(<<".">>), p_string(<<"\/">>)]), fun 'path_element'/2])))]))(I,D) end, fun(Node, _Idx) ->
    Head = proplists:get_value(head, Node),
    Tail = lists:map(fun([_, E]) -> E end, proplists:get_value(tail, Node)),

    {path, [Head | Tail]}
   end).

-spec 'path_element'(input(), index()) -> parse_result().
'path_element'(Input, Index) ->
  p(Input, Index, 'path_element', fun(I,D) -> (p_choose([fun 'identifier'/2, fun 'literal_segment'/2]))(I,D) end, fun(Node, Idx) ->transform('path_element', Node, Idx) end).

-spec 'literal_segment'(input(), index()) -> parse_result().
'literal_segment'(Input, Index) ->
  p(Input, Index, 'literal_segment', fun(I,D) -> (p_seq([p_string(<<"[">>), p_optional(fun 'space'/2), fun 'literal'/2, p_optional(fun 'space'/2), p_string(<<"]">>)]))(I,D) end, fun(Node, _Idx) ->lists:nth(3, Node) end).

-spec 'literal'(input(), index()) -> parse_result().
'literal'(Input, Index) ->
  p(Input, Index, 'literal', fun(I,D) -> (p_choose([fun 'boolean_true'/2, fun 'boolean_false'/2, fun 'float'/2, fun 'integer'/2, fun 'string'/2]))(I,D) end, fun(Node, Idx) ->transform('literal', Node, Idx) end).

-spec 'boolean_true'(input(), index()) -> parse_result().
'boolean_true'(Input, Index) ->
  p(Input, Index, 'boolean_true', fun(I,D) -> (p_string(<<"true">>))(I,D) end, fun(_Node, _Idx) ->true end).

-spec 'boolean_false'(input(), index()) -> parse_result().
'boolean_false'(Input, Index) ->
  p(Input, Index, 'boolean_false', fun(I,D) -> (p_string(<<"false">>))(I,D) end, fun(_Node, _Idx) ->false end).

-spec 'integer'(input(), index()) -> parse_result().
'integer'(Input, Index) ->
  p(Input, Index, 'integer', fun(I,D) -> (p_choose([p_string(<<"0">>), p_seq([p_charclass(<<"[1-9]">>), p_zero_or_more(p_charclass(<<"[0-9]">>))])]))(I,D) end, fun(Node, _Idx) ->
    Number = iolist_to_binary(Node),
    binary_to_integer(Number)
   end).

-spec 'float'(input(), index()) -> parse_result().
'float'(Input, Index) ->
  p(Input, Index, 'float', fun(I,D) -> (p_seq([p_one_or_more(p_charclass(<<"[0-9]">>)), p_string(<<".">>), p_one_or_more(p_charclass(<<"[0-9]">>))]))(I,D) end, fun(Node, _Idx) ->
    Number = iolist_to_binary(Node),
    binary_to_float(Number)
   end).

-spec 'string'(input(), index()) -> parse_result().
'string'(Input, Index) ->
  p(Input, Index, 'string', fun(I,D) -> (p_choose([fun 'string_double'/2, fun 'string_single'/2]))(I,D) end, fun(Node, Idx) ->transform('string', Node, Idx) end).

-spec 'string_double'(input(), index()) -> parse_result().
'string_double'(Input, Index) ->
  p(Input, Index, 'string_double', fun(I,D) -> (p_seq([p_string(<<"\"">>), p_label('chars', p_zero_or_more(p_seq([p_not(p_string(<<"\"">>)), p_choose([p_string(<<"\\\\">>), p_string(<<"\\\"">>), p_anything()])]))), p_string(<<"\"">>)]))(I,D) end, fun(Node, _Idx) ->iolist_to_binary(proplists:get_value(chars, Node)) end).

-spec 'string_single'(input(), index()) -> parse_result().
'string_single'(Input, Index) ->
  p(Input, Index, 'string_single', fun(I,D) -> (p_seq([p_string(<<"\'">>), p_label('chars', p_zero_or_more(p_seq([p_not(p_string(<<"\'">>)), p_choose([p_string(<<"\\\\">>), p_string(<<"\\\'">>), p_anything()])]))), p_string(<<"\'">>)]))(I,D) end, fun(Node, _Idx) ->iolist_to_binary(proplists:get_value(chars, Node)) end).

-spec 'text'(input(), index()) -> parse_result().
'text'(Input, Index) ->
  p(Input, Index, 'text', fun(I,D) -> (p_one_or_more(p_seq([p_not(p_choose([p_string(<<"<">>), p_string(<<"{{">>)])), p_anything()])))(I,D) end, fun(Node, _Idx) ->{text, lists:map(fun([_, T]) -> T end, Node)} end).

-spec 'ident'(input(), index()) -> parse_result().
'ident'(Input, Index) ->
  p(Input, Index, 'ident', fun(I,D) -> (p_seq([p_charclass(<<"[a-zA-Z]">>), p_zero_or_more(p_charclass(<<"[a-zA-Z0-9_-]">>))]))(I,D) end, fun(Node, _Idx) ->iolist_to_binary(Node) end).

-spec 'space'(input(), index()) -> parse_result().
'space'(Input, Index) ->
  p(Input, Index, 'space', fun(I,D) -> (p_zero_or_more(p_charclass(<<"[\s\t\n\s\r]">>)))(I,D) end, fun(Node, _Idx) ->Node end).


transform(_,Node,_Index) -> Node.
-file("peg_includes.hrl", 1).
-type index() :: {{line, pos_integer()}, {column, pos_integer()}}.
-type input() :: binary().
-type parse_failure() :: {fail, term()}.
-type parse_success() :: {term(), input(), index()}.
-type parse_result() :: parse_failure() | parse_success().
-type parse_fun() :: fun((input(), index()) -> parse_result()).
-type xform_fun() :: fun((input(), index()) -> term()).

-spec p(input(), index(), atom(), parse_fun(), xform_fun()) -> parse_result().
p(Inp, StartIndex, Name, ParseFun, TransformFun) ->
  case get_memo(StartIndex, Name) of      % See if the current reduction is memoized
    {ok, Memo} -> %Memo;                     % If it is, return the stored result
      Memo;
    _ ->                                        % If not, attempt to parse
      Result = case ParseFun(Inp, StartIndex) of
        {fail,_} = Failure ->                       % If it fails, memoize the failure
          Failure;
        {Match, InpRem, NewIndex} ->               % If it passes, transform and memoize the result.
          Transformed = TransformFun(Match, StartIndex),
          {Transformed, InpRem, NewIndex}
      end,
      memoize(StartIndex, Name, Result),
      Result
  end.

-spec setup_memo() -> ets:tid().
setup_memo() ->
  put({parse_memo_table, ?MODULE}, ets:new(?MODULE, [set])).

-spec release_memo() -> true.
release_memo() ->
  ets:delete(memo_table_name()).

-spec memoize(index(), atom(), parse_result()) -> true.
memoize(Index, Name, Result) ->
  Memo = case ets:lookup(memo_table_name(), Index) of
              [] -> [];
              [{Index, Plist}] -> Plist
         end,
  ets:insert(memo_table_name(), {Index, [{Name, Result}|Memo]}).

-spec get_memo(index(), atom()) -> {ok, term()} | {error, not_found}.
get_memo(Index, Name) ->
  case ets:lookup(memo_table_name(), Index) of
    [] -> {error, not_found};
    [{Index, Plist}] ->
      case proplists:lookup(Name, Plist) of
        {Name, Result}  -> {ok, Result};
        _  -> {error, not_found}
      end
    end.

-spec memo_table_name() -> ets:tid().
memo_table_name() ->
    get({parse_memo_table, ?MODULE}).

-ifdef(p_eof).
-spec p_eof() -> parse_fun().
p_eof() ->
  fun(<<>>, Index) -> {eof, [], Index};
     (_, Index) -> {fail, {expected, eof, Index}} end.
-endif.

-ifdef(p_optional).
-spec p_optional(parse_fun()) -> parse_fun().
p_optional(P) ->
  fun(Input, Index) ->
      case P(Input, Index) of
        {fail,_} -> {[], Input, Index};
        {_, _, _} = Success -> Success
      end
  end.
-endif.

-ifdef(p_not).
-spec p_not(parse_fun()) -> parse_fun().
p_not(P) ->
  fun(Input, Index)->
      case P(Input,Index) of
        {fail,_} ->
          {[], Input, Index};
        {Result, _, _} -> {fail, {expected, {no_match, Result},Index}}
      end
  end.
-endif.

-ifdef(p_assert).
-spec p_assert(parse_fun()) -> parse_fun().
p_assert(P) ->
  fun(Input,Index) ->
      case P(Input,Index) of
        {fail,_} = Failure-> Failure;
        _ -> {[], Input, Index}
      end
  end.
-endif.

-ifdef(p_seq).
-spec p_seq([parse_fun()]) -> parse_fun().
p_seq(P) ->
  fun(Input, Index) ->
      p_all(P, Input, Index, [])
  end.

-spec p_all([parse_fun()], input(), index(), [term()]) -> parse_result().
p_all([], Inp, Index, Accum ) -> {lists:reverse( Accum ), Inp, Index};
p_all([P|Parsers], Inp, Index, Accum) ->
  case P(Inp, Index) of
    {fail, _} = Failure -> Failure;
    {Result, InpRem, NewIndex} -> p_all(Parsers, InpRem, NewIndex, [Result|Accum])
  end.
-endif.

-ifdef(p_choose).
-spec p_choose([parse_fun()]) -> parse_fun().
p_choose(Parsers) ->
  fun(Input, Index) ->
      p_attempt(Parsers, Input, Index, none)
  end.

-spec p_attempt([parse_fun()], input(), index(), none | parse_failure()) -> parse_result().
p_attempt([], _Input, _Index, Failure) -> Failure;
p_attempt([P|Parsers], Input, Index, FirstFailure)->
  case P(Input, Index) of
    {fail, _} = Failure ->
      case FirstFailure of
        none -> p_attempt(Parsers, Input, Index, Failure);
        _ -> p_attempt(Parsers, Input, Index, FirstFailure)
      end;
    Result -> Result
  end.
-endif.

-ifdef(p_zero_or_more).
-spec p_zero_or_more(parse_fun()) -> parse_fun().
p_zero_or_more(P) ->
  fun(Input, Index) ->
      p_scan(P, Input, Index, [])
  end.
-endif.

-ifdef(p_one_or_more).
-spec p_one_or_more(parse_fun()) -> parse_fun().
p_one_or_more(P) ->
  fun(Input, Index)->
      Result = p_scan(P, Input, Index, []),
      case Result of
        {[_|_], _, _} ->
          Result;
        _ ->
          {fail, {expected, Failure, _}} = P(Input,Index),
          {fail, {expected, {at_least_one, Failure}, Index}}
      end
  end.
-endif.

-ifdef(p_label).
-spec p_label(atom(), parse_fun()) -> parse_fun().
p_label(Tag, P) ->
  fun(Input, Index) ->
      case P(Input, Index) of
        {fail,_} = Failure ->
           Failure;
        {Result, InpRem, NewIndex} ->
          {{Tag, Result}, InpRem, NewIndex}
      end
  end.
-endif.

-ifdef(p_scan).
-spec p_scan(parse_fun(), input(), index(), [term()]) -> {[term()], input(), index()}.
p_scan(_, <<>>, Index, Accum) -> {lists:reverse(Accum), <<>>, Index};
p_scan(P, Inp, Index, Accum) ->
  case P(Inp, Index) of
    {fail,_} -> {lists:reverse(Accum), Inp, Index};
    {Result, InpRem, NewIndex} -> p_scan(P, InpRem, NewIndex, [Result | Accum])
  end.
-endif.

-ifdef(p_string).
-spec p_string(binary()) -> parse_fun().
p_string(S) ->
    Length = erlang:byte_size(S),
    fun(Input, Index) ->
      try
          <<S:Length/binary, Rest/binary>> = Input,
          {S, Rest, p_advance_index(S, Index)}
      catch
          error:{badmatch,_} -> {fail, {expected, {string, S}, Index}}
      end
    end.
-endif.

-ifdef(p_anything).
-spec p_anything() -> parse_fun().
p_anything() ->
  fun(<<>>, Index) -> {fail, {expected, any_character, Index}};
     (Input, Index) when is_binary(Input) ->
          <<C/utf8, Rest/binary>> = Input,
          {<<C/utf8>>, Rest, p_advance_index(<<C/utf8>>, Index)}
  end.
-endif.

-ifdef(p_charclass).
-spec p_charclass(string() | binary()) -> parse_fun().
p_charclass(Class) ->
    {ok, RE} = re:compile(Class, [unicode, dotall]),
    fun(Inp, Index) ->
            case re:run(Inp, RE, [anchored]) of
                {match, [{0, Length}|_]} ->
                    {Head, Tail} = erlang:split_binary(Inp, Length),
                    {Head, Tail, p_advance_index(Head, Index)};
                _ -> {fail, {expected, {character_class, binary_to_list(Class)}, Index}}
            end
    end.
-endif.

-ifdef(p_regexp).
-spec p_regexp(binary()) -> parse_fun().
p_regexp(Regexp) ->
    {ok, RE} = re:compile(Regexp, [unicode, dotall, anchored]),
    fun(Inp, Index) ->
        case re:run(Inp, RE) of
            {match, [{0, Length}|_]} ->
                {Head, Tail} = erlang:split_binary(Inp, Length),
                {Head, Tail, p_advance_index(Head, Index)};
            _ -> {fail, {expected, {regexp, binary_to_list(Regexp)}, Index}}
        end
    end.
-endif.

-ifdef(line).
-spec line(index() | term()) -> pos_integer() | undefined.
line({{line,L},_}) -> L;
line(_) -> undefined.
-endif.

-ifdef(column).
-spec column(index() | term()) -> pos_integer() | undefined.
column({_,{column,C}}) -> C;
column(_) -> undefined.
-endif.

-spec p_advance_index(input() | unicode:charlist() | pos_integer(), index()) -> index().
p_advance_index(MatchedInput, Index) when is_list(MatchedInput) orelse is_binary(MatchedInput)-> % strings
  lists:foldl(fun p_advance_index/2, Index, unicode:characters_to_list(MatchedInput));
p_advance_index(MatchedInput, Index) when is_integer(MatchedInput) -> % single characters
  {{line, Line}, {column, Col}} = Index,
  case MatchedInput of
    $\n -> {{line, Line+1}, {column, 1}};
    _ -> {{line, Line}, {column, Col+1}}
  end.
