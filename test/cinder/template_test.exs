defmodule Cinder.TemplateTest do
  use ExUnit.Case, async: true

  alias Cinder.Errors.{
    Template.IndexError,
    Template.UnknownAssignError,
    Template.UnknownLocalError
  }

  alias Cinder.Template.{
    Assigns,
    Render
  }

  use Cinder.Template

  describe "sigil_B/2" do
    defmodule SigilTemplate do
      @moduledoc false
      use Cinder.Template

      def render do
        ~B"""
        <div id="example-template">
          <h1 class={{@class_assign}}>
            {{@heading_assign}}
          </h1>
          {{#contrived_example @yes}}
            YES
          {{else}}
            NO
          {{/contrived_example}}
        </div>
        """
      end

      def contrived_example(arg) do
        ~B"""
        <div>
          {{#if arg}}
            {{yield "positive"}}
          {{else}}
            {{yield "negative"}}
          {{/if}}
        </div>
        """
      end
    end

    test "it renders" do
      rendered = SigilTemplate.render()

      assigns =
        assigns(class_assign: "bigly", heading_assign: "THIS IS A LARGE HEADING", yes: true)

      result =
        rendered
        |> execute(assigns)

      assert result =~ "<h1 class=\"bigly\">"
      assert result =~ "THIS IS A LARGE HEADING"
      assert result =~ "YES"

      assigns = Assigns.push(assigns, :yes, false)

      result =
        rendered
        |> execute(assigns)

      assert result =~ "NO"
    end
  end

  describe "compile_file/1" do
    @describetag skip: true
    defmodule FileTemplate do
      @moduledoc false
      use Cinder.Template

      @template_path :cinder
                     |> :code.priv_dir()
                     |> to_string()
                     |> Path.join("templates/default_layout.hbs")

      def render do
        compile_file(@template_path)
      end
    end

    test "it renders" do
      rendered = FileTemplate.render()

      assigns = assigns()
      slots = assigns(default: [])

      result =
        rendered
        |> execute(assigns, slots)

      assert result == :wat
    end
  end

  describe "expressions" do
    test "when an assign is present, it is interpreted into the template" do
      assert execute(~B"{{@whom}}", assigns(whom: "Marty McFly")) =~ ~r/Marty\ McFly/
    end

    test "when an assign is missing, it raises a template error" do
      assert_raise(UnknownAssignError, fn ->
        execute(~B"{{@whom}}")
      end)
    end

    test "when the expression contains potential XSS it is escaped" do
      assert execute(~B"{{@whom}}", assigns(whom: "<h1>Marty McFly</h1>")) =~
               "&lt;h1&gt;Marty McFly&lt;/h1&gt;"
    end

    test "expressions in attributes are escaped" do
      assert execute(~B"<h1 class={{@class}}>Marty</h1>", assigns(class: "<bigly>")) =~
               "<h1 class=\"&lt;bigly&gt;\">Marty</h1>"
    end

    test "when the expression contains XSS but is in a triple-stash, it is not escaped" do
      assert execute(~B"{{{@whom}}}", assigns(whom: "<h1>Marty McFly</h1>")) =~
               "<h1>Marty McFly</h1>"
    end

    test "when an local is present, it is interpreted into the template" do
      assert execute(~B"{{whom}}", assigns(), assigns(), assigns(whom: "Marty McFly")) =~
               ~r/Marty\ McFly/
    end

    test "when a local is missing, it raises a template error" do
      assert_raise(UnknownLocalError, fn ->
        execute(~B"{{whom}}")
      end)
    end

    test "paths with assigns at the root can be traversed" do
      assert execute(~B"{{@who.are.you}}", assigns(who: %{are: %{you: "Marty McFly"}})) =~
               ~r/Marty\ McFly/
    end

    test "paths with locals at the root can be traversed" do
      assert execute(
               ~B"{{who.are.you}}",
               assigns(),
               assigns(),
               assigns(who: %{are: %{you: "Marty McFly"}})
             ) =~
               ~r/Marty\ McFly/
    end

    test "paths with missing intermediaries raise an error" do
      assert_raise(IndexError, fn -> execute(~B"{{@who.are.you}}", assigns(who: %{})) end)
    end

    test "paths with integer indexes can be traversed" do
      assert execute(~B"{{@who.[1].name}}", assigns(who: [%{name: "Marty"}, %{name: "Doc"}])) =~
               ~r/Doc/
    end

    test "paths with string indexes can be traversed" do
      assert execute(
               ~B'{{@who.[1].["name"]}}',
               assigns(who: [%{"name" => "Marty"}, %{"name" => "Doc"}])
             ) =~
               ~r/Doc/
    end

    test "literals" do
      result =
        execute(~B"""
        {{123}}
        {{456.789}}
        {{true}}
        {{false}}
        null{{null}}/null
        undefined{{undefined}}/undefined
        """)

      assert result =~ ~r/123/
      assert result =~ ~r/456.789/
      assert result =~ ~r/true/
      assert result =~ ~r/false/
      assert result =~ ~r/null\/null/
      assert result =~ ~r/undefined\/undefined/
    end
  end

  describe "built-in block helpers" do
    test "the `if` built in block helper works when the expression is true" do
      assert execute(~B"{{#if true}}TRUE{{else}}FALSE{{/if}}") =~ ~r/TRUE/
    end

    test "the `if` built in block helper works when the expression is truthy" do
      assert execute(~B"{{#if 'true'}}TRUE{{else}}FALSE{{/if}}") =~ ~r/TRUE/
    end

    test "the `if` built in block helper works when the expression is null" do
      assert execute(~B"{{#if null}}TRUE{{else}}FALSE{{/if}}") =~ ~r/FALSE/
    end

    test "the `if` built in block helper works when the expression is undefined" do
      assert execute(~B"{{#if undefined}}TRUE{{else}}FALSE{{/if}}") =~ ~r/FALSE/
    end

    test "the `if` built in block helper works when the expression is false" do
      assert execute(~B"{{#if false}}TRUE{{else}}FALSE{{/if}}") =~ ~r/FALSE/
    end

    test "the `if` built in block helper works when the expression is an empty string" do
      assert execute(~B"{{#if ''}}TRUE{{else}}FALSE{{/if}}") =~ ~r/FALSE/
    end

    test "the `if` built in block helper works when the expression is an empty array" do
      assert execute(~B"{{#if @empty}}TRUE{{else}}FALSE{{/if}}", assigns(empty: [])) =~ ~r/FALSE/
    end

    test "the `if` built in block helper works when the expression is a 0" do
      assert execute(~B"{{#if 0}}TRUE{{else}}FALSE{{/if}}") =~ ~r/FALSE/
    end

    test "the `if` built in block helper works when the expression is a 0 and includeZero is set to true" do
      assert execute(~B"{{#if 0 includeZero=true}}TRUE{{else}}FALSE{{/if}}") =~ ~r/TRUE/
    end

    test "the `unless` built in block helper works when the expression is true" do
      assert execute(~B"{{#unless true}}TRUE{{else}}FALSE{{/unless}}") =~ ~r/FALSE/
    end

    test "the `unless` built in block helper works when the expression is truthy" do
      assert execute(~B"{{#unless 'true'}}TRUE{{else}}FALSE{{/unless}}") =~ ~r/FALSE/
    end

    test "the `unless` built in block helper works when the expression is null" do
      assert execute(~B"{{#unless null}}TRUE{{else}}FALSE{{/unless}}") =~ ~r/TRUE/
    end

    test "the `unless` built in block helper works when the expression is undefined" do
      assert execute(~B"{{#unless undefined}}TRUE{{else}}FALSE{{/unless}}") =~ ~r/TRUE/
    end

    test "the `unless` built in block helper works when the expression is false" do
      assert execute(~B"{{#unless false}}TRUE{{else}}FALSE{{/unless}}") =~ ~r/TRUE/
    end

    test "the `each` built in helper renders the nested block" do
      assert execute(~B"{{#each @count}}{{this}},{{/each}}", assigns(count: [1, 2, 3])) =~
               ~r/1,2,3/
    end

    test "the `each` built in helper can use a named binding" do
      assert execute(
               ~B"{{#each @count as |count|}}{{count}},{{/each}}",
               assigns(count: [1, 2, 3])
             ) =~
               ~r/1,2,3/
    end
  end

  describe "components" do
    defmodule BasicVoidComponent do
      @moduledoc false
      use Cinder.Component

      def render do
        ~B"""
        {{#if (has_slot "default")}}
          {{yield "default"}}
        {{else}}
          Basic void component
        {{/if}}
        """
      end
    end

    test "void components with no arguments" do
      assert execute(~B"<BasicVoidComponent />") =~ ~r/Basic void component/
    end

    test "component with no contents" do
      assert execute(~B"<BasicVoidComponent></BasicVoidComponent>") =~ ~r/Basic void component/
    end

    test "component with named slot" do
      assert execute(~B"<BasicVoidComponent><:default>Named slot</:default></BasicVoidComponent>") =~
               ~r/Named slot/
    end

    test "component with implicit slot" do
      assert execute(~B"<BasicVoidComponent>Implicit slot</BasicVoidComponent>") =~
               ~r/Implicit slot/
    end
  end

  defp assigns(opts \\ []) do
    Assigns.init()
    |> Assigns.assign(opts)
  end

  defp execute(template, assigns \\ assigns(), slots \\ assigns(), locals \\ assigns()) do
    template
    |> Render.execute(assigns, slots, locals)
    |> IO.iodata_to_binary()
  end
end
