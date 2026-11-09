# Rails and rswag

Verquest doesn't depend on Rails, so it ships no Rails integration. Its three locations map onto Rails request methods, though: `location :body` (the default) reads `request_parameters`, `location :query` reads `query_parameters`, and `location :path` reads `path_parameters`. This guide gives you two small pieces to copy into your app:

- a controller concern that processes all three from one declaration per class;
- an rswag shared context that documents query and path classes in your request specs.

## API version

Verquest picks the request version from `config.current_version`. With the version in the URL (`/2025-06/deals`), keep it in `Current` and read it from there:

```ruby
# config/routes.rb
scope "/:api_version", constraints: {api_version: /\d{4}-\d{2}/} do
  resources :deals, only: %i[index show update] do
    resource :win, only: :create, module: :deals
  end
end

# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  attribute :api_version
end

# config/initializers/verquest.rb
Verquest.configure do |config|
  config.current_version = -> { Current.api_version }
  # Released versions keep tolerating what they accepted before validation
  config.lenient_through = "2025-06"
end
```

## Controller concern

```ruby
# app/controllers/concerns/verquest_params.rb
module VerquestParams
  extend ActiveSupport::Concern

  included do
    before_action :process_verquest_params
    attr_reader :body_params, :query_params, :path_params

    # Keep JSON bodies as sent, without a copy under the controller's name
    wrap_parameters false
  end

  class_methods do
    # `param:` is the route key a path class's `id` comes from
    def verquest_params(request_class, param: :id, only: nil, except: nil)
      verquest_declarations << {class: request_class, param:, only: Array(only), except: Array(except)}
    end

    def verquest_declarations
      @verquest_declarations ||= []
    end
  end

  private

  def process_verquest_params
    declarations = self.class.verquest_declarations.select { |declaration| verquest_declaration_applies?(declaration) }
    by_location = declarations.group_by { |declaration| declaration[:class].location }

    # Every path class applies, so /deals/:deal_id/notes/:id can check both IDs
    @path_params = by_location.fetch(:path, []).to_h { |declaration| process_path_param(declaration) }
    # Unknown query keys (cache busters, tracking) are dropped instead of rejected. Add
    # `reject_other_version_keys: true` to reject keys from another version, such as a newer filter.
    # A lenient request (config.lenient_through) yields each value it corrected instead of rejecting.
    @query_params = by_location[:query]&.first&.dig(:class)&.process(request.query_parameters, remove_extra_root_keys: true) do |correction|
      Rails.logger.info("Corrected query param: #{correction.to_h.except(:from)}")
    end
    @body_params = by_location[:body]&.first&.dig(:class)&.process(request.request_parameters)
  end

  def process_path_param(declaration)
    param = declaration[:param]
    [param.to_s, declaration[:class].process({"id" => request.path_parameters[param]})["id"]]
  rescue Verquest::InvalidParamsError => e
    # Point errors at the route key (/deal_id), not the class's /id
    errors = e.errors.map { |error| error.merge(pointer: "/#{param}", message: error[:message].sub("`/id`", "`/#{param}`")) }
    raise Verquest::InvalidParamsError.new(e.message, errors:)
  end

  def verquest_declaration_applies?(declaration)
    action = action_name.to_sym
    (declaration[:only].empty? || declaration[:only].include?(action)) && declaration[:except].exclude?(action)
  end
end
```

The concern expects `config.validation_error_handling = :raise` (the default). Set the version and render errors once, in the base controller:

```ruby
class ApplicationController < ActionController::API
  # Declared before the include, so the version is set when the concern's before_action runs
  before_action { Current.api_version = params[:api_version] }
  include VerquestParams

  rescue_from Verquest::InvalidParamsError do |error|
    render json: {errors: error.errors}, status: :unprocessable_content
  end
end
```

Each path class validates one ID as `id`, so one class serves both the member route (`/deals/:id`) and nested routes (`/deals/:deal_id/win`):

```ruby
class DealPath < Verquest::Base
  location :path

  version "2025-06" do
    field :id, type: :string, required: true, pattern: "^deal_", description: "The ID of the deal"
  end
end
```

```ruby
class DealsController < ApplicationController
  verquest_params DealPath, only: %i[show update]
  verquest_params DealsIndexQuery, only: :index
  verquest_params DealUpdateRequest, only: :update

  def index
    render json: DealsIndexQuery.apply_filters(Deal.all, query_params)
  end

  def show
    render json: Deal.find_by!(public_id: path_params["id"])
  end
end

class Deals::WinsController < ApplicationController
  verquest_params DealPath, param: :deal_id # POST /deals/:deal_id/win
end
```

`GET /deals/con_123` then returns 422 with `{"pointer" => "/id", ...}`, and `POST /deals/con_123/win` with `{"pointer" => "/deal_id", ...}`.

`DealsIndexQuery` declares its filters with `filter` (see [Filters](../README.md#filters)). `apply_filters` takes the version from `config.current_version`, like `process`. `GET /2025-06/deals?site_id=site_1` lists every deal, because `site_id` is a `2025-08` filter and `process` drops it. With `reject_other_version_keys: true`, the same request returns 422 with `{"pointer" => "/site_id", "type" => "other_version", ...}`.

## rswag

A shared context documents a query or path class with `to_parameters`. `name:` renames a path class's parameter to the route key, and `description:` replaces its description:

```ruby
# spec/support/verquest.rb
RSpec.shared_context "verquest parameters" do |request_class, version:, name: nil, description: nil|
  request_class.to_parameters(version:).each do |attributes|
    parameter(attributes.merge({name:, description:}.compact))
  end
end
```

```ruby
path "/2025-06/deals/{deal_id}" do
  include_context "verquest parameters", DealPath, version: "2025-06", name: "deal_id"

  patch "Update a deal" do
    include_context "verquest parameters", ExpandQuery, version: "2025-06"
    parameter name: :payload, in: :body, schema: {"$ref" => DealUpdateRequest.to_ref}

    response "200", "deal updated" do
      let(:deal_id) { create(:deal).public_id }
      let(:payload) { {name: "New name"} }

      run_test!
    end
  end
end
```

rswag skips optional query parameters without a matching `let`, so specs only define the ones they send.

Body classes are registered as components in `swagger_helper.rb` (see [Component Generation for OpenAPI](../README.md#component-generation-for-openapi)):

```ruby
components: {
  schemas: [DealUpdateRequest].to_h { |request| [request.component_name, request.to_schema(version: "2025-06")] }
}
```
