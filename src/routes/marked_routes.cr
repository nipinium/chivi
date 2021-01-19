require "./_route_utils"
require "../filedb/marked"

module CV::Server
  get "/api/book-marks/:b_hash" do |env|
    unless uname = env.session.string?("u_dname").try(&.downcase)
      halt env, status_code: 403, response: "user not logged in"
    end

    b_hash = env.params.url["b_hash"]
    bmark = Marked.book_users(b_hash).fval(uname) || ""
    RouteUtils.json_res(env, {bmark: bmark})
  end

  put "/api/book-marks/:b_hash" do |env|
    unless u_name = env.session.string?("u_dname").try(&.downcase)
      halt env, status_code: 403, response: "user not logged in"
    end

    b_hash = env.params.url["b_hash"]
    nvmark = env.params.query["nvmark"]? || ""

    if nvmark.empty?
      Marked.unmark_book(u_name, b_hash)
    else
      Marked.mark_book(u_name, b_hash, nvmark)
    end

    RouteUtils.json_res(env, {nvmark: nvmark})
  end

  get "/api/user-books/:u_dname" do |env|
    u_uname = env.params.url["u_dname"].downcase
    nvmark = env.params.query["nvmark"]? || "reading"
    matched = Marked.all_user_books(u_uname, nvmark)

    matched.each do |b_hash|
      next if NvValues._index.has_key?(b_hash)
      # puts b_hash
      Marked.unmark_book(u_uname, b_hash)
      matched.delete(b_hash)
    end

    RouteUtils.books_res(env, matched)
  end
end
