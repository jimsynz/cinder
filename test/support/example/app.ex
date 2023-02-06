defmodule Example.App do
  use Cinder

  @moduledoc false

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
      base_path(__ENV__.file |> Path.join("../templates") |> Path.expand())
    end

    secret_key_base(&Application.fetch_env(:cinder, &1))
    cookie_signing_salt("jfJAB1yNo/0ATHaAjggU1Q")
  end
end
