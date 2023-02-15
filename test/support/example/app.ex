defmodule Example.App do
  use Cinder, otp_app: :cinder

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
      base_path Path.expand("./templates", __DIR__)
    end

    assets do
      source_path Path.expand("./assets", __DIR__)
      target_path Path.expand("./static", __DIR__)
    end

    secret_key_base &Application.fetch_env(:cinder, &1)
    cookie_signing_salt "jfJAB1yNo/0ATHaAjggU1Q"
  end
end
