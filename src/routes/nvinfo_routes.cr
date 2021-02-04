require "./_route_utils"
require "../filedb/marked"

module CV::Server
  get "/api/nvinfos" do |env|
    matched = NvTokens.glob(env.params.query)
    RouteUtils.books_res(env, matched)
  end

  get "/api/nvinfos/:bslug" do |env|
    unless bhash = Nvinfo.find_by_slug(env.params.url["bslug"])
      halt env, status_code: 404, response: "Book not found!"
    end

    nvinfo = Nvinfo.load(bhash)

    u_power = env.session.int?("u_power") || 0
    nvinfo.bump_access! if u_power > 0

    RouteUtils.json_res(env, cached: nvinfo._utime) do |res|
      JSON.build(res) { |json| nvinfo.to_json(json, true) }
    end
  end
end
