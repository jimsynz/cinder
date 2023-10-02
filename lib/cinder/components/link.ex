defmodule Cinder.Components.Link do
  @moduledoc """
  A component which generates an idiomatic anchor tag.

  ## Usage

  ```handlebars
  <Cinder::Components::Link to={{url_for @request "app.posts.post[id]" id=123}}>
    Link to Post #123.
  </Cinder::Components::Link>
  ```
  """

  use Cinder.Component
  import Cinder.Template.Helpers.Route

  component do
    prop :class, :css_class

    prop :to, :uri

    slot :default do
      required? true
    end

    event :click, ~t"""
      let uri = this.getAttribute('href');

      if (uri?.startsWith("/")) {
        event.preventDefault();
        cinder.transitionTo(uri);
      }
    """
  end

  @doc false
  @spec render :: Cinder.Template.Render.t()
  def render do
    ~B"""
    <a href={{@to}} class={{@class}} aria-current={{aria_current @request @to}}>{{yield}}</a>
    """
  end

  defp aria_current(request, to) do
    current_route_id = current_route_id(request)
    url = url_for(request, current_route_id, Enum.to_list(request.current_params))

    if to_string(url) == to_string(to) do
      "page"
    else
      false
    end
  end
end
