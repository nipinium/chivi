require "kemal"

require "./engine"
require "./kernel"

def parse_page(input, limit = 20)
  page = parse_int(input)

  offset = (page - 1) * limit
  offset = 0 if offset < 0

  {limit, offset}
end

def parse_int(str)
  str.to_i
rescue
  0
end

module Server
  Kemal.config.port = 5110

  serve_static false

  before_all do |env|
    env.response.content_type = "application/json"
    if Kemal.config.env == "production"
      user = "guest"
    else
      user = "admin"
    end

    env.set("user", user)
  end

  get "/api" do |env|
    {msg: "ok"}.to_json env.response
  end

  get "/api/lookup" do |env|
    line = env.params.query.fetch("line", "")
    from = env.params.query.fetch("from", "0").to_i
    udic = env.params.query["udic"]?
    user = env.get("user").as(String)

    res = Engine.lookup(line, from, udic, user)
    res.to_json env.response
  end

  get "/api/hanviet" do |env|
    line = env.params.query.fetch("line", "")
    udic = env.params.query["udic"]?

    res = Engine.hanviet(line)
    res.to_json env.response
  end

  get "/api/books" do |env|
    page = env.params.query.fetch("page", "1")
    limit, offset = parse_page(page)
    sort = env.params.query.fetch("sort", "access")

    books = Kernel.serials.list(limit: limit, offset: offset, sort: sort)
    {items: books, total: Kernel.serials.total, sort: sort}.to_json env.response
  end

  get "/api/search" do |env|
    query = env.params.query.fetch("kw", "")
    books = Kernel.serials.glob(query)
    books.to_json env.response
  end

  get "/api/books/:slug" do |env|
    slug = env.params.url["slug"]
    book, site, bsid, chlist = Kernel.load_book(slug)

    halt env, status_code: 404, response: ({msg: "Book not found"}).to_json if book.nil?

    Kernel.serials.bump(book)
    {book: book, site: site, bsid: bsid, chlist: chlist}.to_json env.response
  end

  get "/api/books/:slug/:site" do |env|
    slug = env.params.url["slug"]
    site = env.params.url["site"]

    book, site, bsid, chlist = Kernel.load_book(slug, site)

    halt env, status_code: 404, response: ({msg: "Book not found"}).to_json if book.nil?
    halt env, status_code: 404, response: ({msg: "Site [#{site}] not found"}).to_json if bsid.empty?

    {book: book, site: site, bsid: bsid, chlist: chlist}.to_json env.response
  end

  get "/api/books/:slug/:site/:chap" do |env|
    user = env.get("user").as(String)

    slug = env.params.url["slug"]
    site = env.params.url["site"]

    book, site, bsid, chlist = Kernel.load_book(slug, site)

    halt env, status_code: 404, response: ({msg: "Book not found"}).to_json if book.nil?
    halt env, status_code: 404, response: ({msg: "Site not found"}).to_json if chlist.empty?

    csid = env.params.url["chap"]
    cidx = chlist.index(&.csid.==(csid))

    halt env, status_code: 404, response: ({msg: "Chap not found"}).to_json if cidx.nil?

    curr_chap = chlist[cidx]
    prev_chap = chlist[cidx - 1] if cidx > 0
    next_chap = chlist[cidx + 1] if cidx < chlist.size - 1

    {
      book_slug: book.vi_slug,
      book_name: book.vi_title,
      prev_slug: prev_chap.try(&.slug(site)),
      next_slug: next_chap.try(&.slug(site)),
      curr_slug: curr_chap.try(&.slug(site)),
      lines:     Kernel.load_text(site, bsid, csid, user),
      chidx:     cidx + 1,
      total:     chlist.size,
    }.to_json env.response
  end

  Kemal.run
end
