# Cinder

[![Build Status](https://drone.harton.nz/api/badges/cinder/cinder/status.svg?ref=refs/heads/main)](https://drone.harton.nz/cinder/cinder)
[![Hippocratic License HL3-FULL](https://img.shields.io/static/v1?label=Hippocratic%20License&message=HL3-FULL&labelColor=5e2751&color=bc8c3d)](https://firstdonoharm.dev/version/3/0/full.html)

Cinder is a framework for building real-time web applications in Elixir with a
focus on isomorphism and developer experience.

## Status

Cinder is still very much in the experimental phase and should not be used by
anyone who wants to keep their job - except if their job is experimenting with
new and interesting ways to build apps.

At the moment documentation is severely lacking. You are welcome to contribute
some.

## Goals

Cinder has some lofty goals:

- Enable developers to build concurrent, real-time web applications without
  having to reason about traditional backend/frontend concerns or the
  request/response cycle.
- Provide a rich domain-specific language which allows the developer to express
  common domain concerns quickly and from which much of the application
  framework to be derived at compile time and introspected at runtime.

But probably more important are the non-goals:

- Cinder is not a replacement for Phoenix. Cinder does not provide many of the
  features of Phoenix and intentionally so. It does not care about building
  APIs, controllers or live-views. You can run Cinder _inside_ a Phoenix
  application if you need these features.
- Cinder is built using tools from the [Ash](https://ash-hq.org/) ecosystem,
  however Cinder is not designed to be used solely with Ash. Cinder's golden
  path may evolve towards recommending Ash to model your application layer, but
  it will always work without it.
- Avoid code-generation wherever possible. Just trust me on this.

## Installation

Cinder is not yet ready to be published to Hex, so in the mean time if you want
to try it you should install it directly from the repository:

```elixir
def deps do
  [
    {:cinder, git: "https://code.harton.nz/cinder/cinder", tag: "v0.9"}
  ]
end
```

Documentation is not yet published to Hexdocs, so you can access the latest
version [on my docs site](https://docs.harton.nz/cinder/cinder/readme.html).

## License

This software is licensed under the terms of the
[HL3-FULL](https://firstdonoharm.dev), see the `LICENSE.md` file included with
this package for the terms.

This license actively proscribes this software being used by and for some
industries, countries and activities. If your usage of this software doesn't
comply with the terms of this license, then [contact me](mailto:james@harton.nz)
with the details of your use-case to organise the purchase of a license - the
cost of which may include a donation to a suitable charity or NGO.
