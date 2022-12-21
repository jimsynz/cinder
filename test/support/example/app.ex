defmodule Example.App do
  use Cinder

  @moduledoc """
  activities for /posts/123/comments:

  1. match all segments and build route hierarchy
  2. enter each route in sequence passing params as accumulated
  3. reactively render appropriate content for each route based on state.

  ie:

  1. initialize empty posts route
  2. enter posts route
  3. (reactively) render correct template for posts state (ie loading, active or error)
  4. once posts are active, enter post route
  5. (reactively) render correct template for post state
  6. enter comments route
  7. (reactively) render correct template for comments state

  +--------------------------+
  |    posts                 |
  |    +--------------+      |
  |    | post         |      |
  |    |              |      |
  |    | +----------+ |      |
  |    | | comments | |      |
  |    | +----------+ |      |
  |    +--------------+      |
  |                          |
  +--------------------------+

  """

  cinder do
    router do
      route Posts, "/posts" do
        route Post, "/:id" do
          route Comments, "/comments" do
            route Comment, "/:id"
          end
        end
      end

      route Fruit, "/fruits/:id"
      route Stuck, "/stuck"
      route Slow, "/slow"
    end

    templates do
      # base_path(__ENV__.file |> Path.join("../templates") |> Path.expand())
    end

    secret_key_base(&Application.fetch_env(:cinder, &1))
    cookie_signing_salt("jfJAB1yNo/0ATHaAjggU1Q")
  end
end
