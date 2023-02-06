defmodule CinderHandlebarsTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import ParseHelper

  describe "HTML directives" do
    it_parses("<!doctype html>", [{:doctype, " html"}])
    it_parses("<!DOCTYPE html>", [{:doctype, " html"}])
    it_parses("<!-- comment -->", [{:comment, " comment "}])
  end

  describe "HTML elements" do
    it_parses("<div class=\"hero\">Marty</div>", [
      {:element, "div", [{"class", "hero"}], [text: ~w[M a r t y]]}
    ])

    it_parses(
      "<img src=\"./hill_valley.jpg\" />",
      [{:element, "img", [{"src", "./hill_valley.jpg"}]}]
    )

    it_parses("<img src={{assetPath hillValleyPhoto}} />", [
      {:element, "img", [{"src", {:expr, {:assetPath, [:hillValleyPhoto]}}}]}
    ])

    it_parses("<deeply><nested><tags /></nested></deeply>", [
      {:element, "deeply", [], [{:element, "nested", [], [{:element, "tags", []}]}]}
    ])
  end

  describe "Handlebars expressions" do
    it_parses("{{simpleIdentifier}}", [{:expr, :simpleIdentifier}])
    it_parses("{{12345}}", [{:expr, 12_345}])
    it_parses("{{123.45}}", [{:expr, 123.45}])
    it_parses(~s|{{"Hello, World!"}}|, [{:expr, "Hello, World!"}])
    it_parses("{{multiple.segment.path}}", [{:expr, {:path, [:multiple, :segment, :path]}}])
    it_parses(~s|{{literal.["segment"].path}}|, [{:expr, {:path, [:literal, "segment", :path]}}])
    it_parses("{{helper withArg}}", [{:expr, {:helper, [:withArg]}}])
    it_parses("{{helper with multiple args}}", [{:expr, {:helper, [:with, :multiple, :args]}}])

    it_parses("{{helper with=hash args=true}}", [
      {:expr, {:helper, [{:=, :with, :hash}, {:=, :args, true}]}}
    ])

    it_parses("{{helper with both kinds of=args}}", [
      {:expr, {:helper, [:with, :both, :kinds, {:=, :of, :args}]}}
    ])

    it_parses("{{outer-helper (inner-helper 'abc') 'def'}}", [
      {:expr, {:"outer-helper", [{:expr, {:"inner-helper", ["abc"]}}, "def"]}}
    ])

    it_parses("{{@index}}", [{:expr, {:@, :index}}])
  end

  describe "Handlebars comments" do
    it_parses("{{! example }}", [:comment])
    it_parses("{{!-- }} --}}", [:comment])
  end

  describe "Handlebars blocks" do
    it_parses("{{#if itIsTrue}}it's true{{/if}}", [
      {:block, :if, [:itIsTrue], [text: ["i", "t", "'", "s", " ", "t", "r", "u", "e"]], [], []}
    ])

    it_parses("{{#if itIsTrue}}it's true{{else}}it's false{{/if}}", [
      {:block, :if, [:itIsTrue], [text: ["i", "t", "'", "s", " ", "t", "r", "u", "e"]],
       [text: ["i", "t", "'", "s", " ", "f", "a", "l", "s", "e"]], []}
    ])

    it_parses(
      "{{#each users as |userId email|}} {{/each}}",
      [{:block, :each, [:users], [text: [" "]], [], [:userId, :email]}]
    )
  end
end
