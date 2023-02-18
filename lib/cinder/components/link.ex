defmodule Cinder.Components.Link do
  @moduledoc """
  A component which generates an idiomatic anchor tag.

  ## Usage

  ```handlebars
  <Cinder::Components::Link to={{url_for @request, "app.posts.post[id]", id=123}}>
    Link to Post #123.
  </Cinder::Components::Link>
  ```
  """

  use Cinder.Component
  use Cinder.Template
  import Cinder.Component.Script

  component do
    prop :class, :css_class
    prop :to, :uri

    slot :default, required?: true

    event :click, ~j"""
      let uri = this.dataSet['to'];

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
    <a href={{@to}} class={{@class}} data-to={{@to}}>
      {{yield}}
    </a>
    """
  end
end
