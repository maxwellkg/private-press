require "test_helper"

class BooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :kevin
  end

  test "index lists the current user's books" do
    get root_url

    assert_response :success
    assert_select "h2", text: "Handbook"
    assert_select "h2", text: "Manual", count: 0
  end

  test "index includes published books, even when the user does not have access" do
    books(:manual).update!(published: true)

    get root_url

    assert_response :success
    assert_select "h2", text: "Handbook"
    assert_select "h2", text: "Manual"
  end

  test "index shows published books when not logged in" do
    books(:manual).update!(published: true)

    sign_out
    get root_url

    assert_response :success
    assert_select "h2", text: "Handbook", count: 0
    assert_select "h2", text: "Manual"
  end

  test "index redirects to login if not signed in and no published books exist" do
    sign_out
    get root_url

    assert_redirected_to new_session_url
  end

  test "index JSON returns 200 with empty array when signed out and no published books" do
    sign_out

    get root_url(format: :json)

    assert_response :success
    assert_equal [], JSON.parse(response.body)
  end

  test "index JSON returns only published books when signed out" do
    books(:handbook).update!(published: true)
    books(:manual).update!(published: true)

    sign_out

    get root_url(format: :json)

    assert_response :success
    books = JSON.parse(response.body)
    assert_equal 2, books.size

    assert_equal [ "handbook", "manual" ], books.map { |book| book["slug"] }
  end

  test "index JSON returns accessible or published books when signed in" do
    books(:manual).update!(published: true)

    get root_url(format: :json), headers: authorization_headers_for_user(:kevin)

    assert_response :success
    books = JSON.parse(response.body)
    assert_equal 2, books.size
  end

  test "index JSON includes base fields for every book" do
    get root_url, as: :json, headers: authorization_headers_for_user(:jz)

    assert_response :success
    books = JSON.parse(response.body)

    base_keys = %w[ id title subtitle author slug created_at updated_at ]

    assert books.present?
    assert books.all? { |book| base_keys.sort == book.keys.sort }
  end

  test "index JSON includes editable attributes for editable books" do
    books(:manual).update!(published: true)

    get root_url, as: :json, headers: authorization_headers_for_user(:kevin)

    assert_response :success
    books = JSON.parse(response.body)
    handbook = books.find { |book| book["slug"] == "handbook" }
    manual = books.find { |book| book["slug"] == "manual" }

    assert_not_nil handbook
    assert_not_nil manual

    editable_keys = %w[ published everyone_access theme ]
    editable_keys.each do |key|
      assert_includes handbook.keys, key
      assert_not_includes manual.keys, key
    end
  end

  test "index JSON omits editable attributes for non-editable books" do
    books(:manual).update!(published: true)

    get root_url, as: :json, headers: authorization_headers_for_user(:jz)

    assert_response :success
    books = JSON.parse(response.body)
    handbook = books.find { |b| b["slug"] == "handbook" }
    manual = books.find { |b| b["slug"] == "manual" }

    assert_not_nil handbook
    assert_not_nil manual

    editable_keys = %w[ published everyone_access theme ]
    editable_keys.each do |key|
      assert_not_includes handbook.keys, key
      assert_not_includes manual.keys, key
    end
  end

  test "show JSON includes base fields" do
    get book_slug_path(books(:handbook)), as: :json, headers: authorization_headers_for_user(:jz)

    assert_response :success

    book = JSON.parse(response.body)
    base_keys = %w[ id title subtitle author slug created_at updated_at ]

    base_keys.each do |key|
      assert_includes book.keys, key
    end
  end

  test "show JSON includes editable attributes for editable books" do
    get book_slug_path(books(:handbook)), as: :json, headers: authorization_headers_for_user(:kevin)

    assert_response :success

    book = JSON.parse(response.body)
    editable_keys = %w[ published everyone_access theme ]

    assert editable_keys.all? { |key| key.in?(book.keys) }
  end

  test "show JSON omits editable attributes for non-editable books" do
    get book_slug_path(books(:handbook)), as: :json, headers: authorization_headers_for_user(:jz)

    assert_response :success

    book = JSON.parse(response.body)
    editable_keys = %w[ published everyone_access theme ]

    assert editable_keys.none? { |key| key.in?(book.keys) }
  end

  test "show JSON returns 404 for inaccessible book" do
    # Kevin has editor access to handbook, but NOT to manual
    # Manual is not published, so should return 404
    get book_slug_path(books(:manual)), as: :json, headers: authorization_headers_for_user(:kevin)

    assert_response :not_found
  end

  test "show JSON includes TOC with leaf and leafable metadata" do
    get book_slug_path(books(:handbook)), as: :json, headers: authorization_headers_for_user(:kevin)

    assert_response :success

    book = JSON.parse(response.body)
    toc = book.fetch("toc")

    first = toc.first
    expected_leaf = leaves(:welcome_section)

    assert_equal expected_leaf.id, first["id"]
    assert_equal expected_leaf.leafable_id, first["leafable_id"]
    assert_equal expected_leaf.leafable_type, first["leafable_type"]
    assert_equal expected_leaf.title, first["title"]
    assert_equal expected_leaf.status, first["status"]
    assert_equal expected_leaf.position_score, first["position_score"]
    assert_equal expected_leaf.book_id, first["book_id"]

    leafable = first["leafable"]
    assert_not_nil leafable
    assert_equal expected_leaf.leafable_id, leafable["id"]
    assert_equal expected_leaf.section.theme, leafable["theme"]
    assert_equal %w[ id theme ], leafable.keys.sort
  end

  test "show JSON TOC is in positioned order" do
    get book_slug_path(books(:handbook)), as: :json, headers: authorization_headers_for_user(:kevin)

    assert_response :success

    toc = JSON.parse(response.body).fetch("toc")
    position_scores = toc.map { |entry| entry.fetch("position_score") }

    assert_equal position_scores.sort, position_scores
  end

  test "create makes the current user an editor" do
    assert_difference -> { Book.count }, +1 do
      post books_url, params: { book: { title: "New Book", everyone_access: false } }
    end

    assert_redirected_to book_slug_url(Book.last)

    book = Book.last
    assert_equal "New Book", book.title
    assert_equal 1, Book.last.accesses.count

    assert book.editable?(user: users(:kevin))
  end

  test "create JSON returns 201 with book payload" do
    assert_difference -> { Book.count }, +1 do
      post books_path, as: :json, headers: authorization_headers_for_user(:kevin), params: {
        book: { title: "New Book", everyone_access: false }
      }
    end

    assert_response :created

    json = JSON.parse(response.body)

    assert_equal Book.last.id, json["id"]
    assert_equal "New Book", json["title"]
  end



  test "create JSON preserves access assignment for editor_ids and reader_ids" do
    assert_difference -> { Book.count }, +1 do
      post books_path, as: :json, headers: authorization_headers_for_user(:jason), params: {
        book: { title: "JSON Access Book", everyone_access: false },
        editor_ids: [ users(:jz).id ],
        reader_ids: [ users(:kevin).id ]
      }
    end

    assert_response :created

    book = Book.find_by!(title: "JSON Access Book")
    assert book.editable?(user: users(:jason))
    assert book.editable?(user: users(:jz))
    assert book.accessable?(user: users(:kevin))
    assert_not book.editable?(user: users(:kevin))
  end

  test "create sets additional accesses" do
    sign_in :jason
    assert_difference -> { Book.count }, +1 do
      post books_url, params: { book: { title: "New Book", everyone_access: false }, "editor_ids[]": users(:jz).id, "reader_ids[]": users(:kevin).id }
    end

    book = Book.last
    assert_equal "New Book", book.title
    assert_equal 3, Book.last.accesses.count

    assert book.editable?(user: users(:jz))

    assert book.accessable?(user: users(:kevin))
    assert_not book.editable?(user: users(:kevin))
  end

  test "update JSON returns 200 with book payload" do
    handbook = books(:handbook)
    new_title = "Updated Handbook"

    assert_changes -> { handbook.reload.title }, to: new_title do
      patch book_path(handbook), as: :json, headers: authorization_headers_for_user(:kevin), params: {
        book: { title: "Updated Handbook" }
      }
    end

    assert_response :success

    json = JSON.parse(response.body)

    assert_equal handbook.id, json["id"]
    assert_equal "Updated Handbook", json["title"]
  end



  test "update JSON returns 403 for non-editable user" do
    patch book_path(books(:handbook)), as: :json, headers: authorization_headers_for_user(:jz), params: {
      book: { title: "Nope" }
    }

    assert_response :forbidden
  end

  test "update JSON returns 404 for inaccessible book" do
    patch book_path(books(:manual)), as: :json, headers: authorization_headers_for_user(:kevin), params: {
      book: { title: "No Access" }
    }

    assert_response :not_found
  end

  test "update JSON applies editor_ids and reader_ids when provided" do
    patch book_path(books(:handbook)), as: :json, headers: authorization_headers_for_user(:jason), params: {
      book: { title: "Handbook" },
      editor_ids: [ users(:jz).id ],
      reader_ids: [ users(:kevin).id ]
    }

    assert_response :success

    book = books(:handbook).reload
    assert book.editable?(user: users(:jason))
    assert book.editable?(user: users(:jz))
    assert book.accessable?(user: users(:kevin))
    assert_not book.editable?(user: users(:kevin))
  end

  test "update JSON preserves access when editor_ids and reader_ids omitted" do
    patch book_path(books(:handbook)), as: :json, headers: authorization_headers_for_user(:kevin), params: {
      book: { title: "Updated" }
    }

    assert_response :success

    book = books(:handbook).reload

    # Kevin should still be an editor (access preserved)
    assert book.editable?(user: users(:kevin))
    # JZ should still be a reader (access preserved)
    assert book.accessable?(user: users(:jz))
    assert_not book.editable?(user: users(:jz))
  end

  test "destroy JSON returns 204" do
    assert_difference -> { Book.count }, -1 do
      delete book_path(books(:handbook)), as: :json, headers: authorization_headers_for_user(:kevin)
    end

    assert_response :no_content
  end

  test "destroy JSON returns 403 for non-editable user" do
    assert_no_difference -> { Book.count } do
      delete book_path(books(:handbook)), as: :json, headers: authorization_headers_for_user(:jz)
    end

    assert_response :forbidden
  end

  test "show only shows books the current user can access" do
    get book_slug_url(books(:manual))
    assert_response :not_found

    get book_slug_url(books(:handbook))
    assert_response :success
  end

  test "show includes OG metadata for public access" do
    get book_slug_url(books(:handbook))
    assert_response :success

    assert_select "meta[property='og:title'][content='Handbook']"
    assert_select "meta[property='og:url'][content='#{book_slug_url(books(:handbook))}']"
  end

  test "show with markdown format returns combined markables" do
    leaves(:welcome_page).leafable.update!(body: "# Welcome Content")
    leaves(:summary_page).leafable.update!(body: "# Summary Content")

    get book_slug_path(books(:handbook), format: :md)

    assert_response :success
    assert_in_body "# Welcome Content"
    assert_in_body "# Summary Content"
  end

  test "show with markdown format does not escape HTML" do
    leaves(:welcome_page).leafable.update!(body: "<div class='test'>HTML content</div>")

    get book_slug_path(books(:handbook), format: :md)

    assert_response :success
    assert_in_body "<div class='test'>"
    assert_not_in_body "&lt;"
  end

  test "show includes link to markdown format" do
    get book_slug_path(books(:handbook))

    assert_response :success
    assert_select "link[rel=\"alternate\"][type=\"text/markdown\"][href=\"#{book_slug_path(books(:handbook), format: :md)}\"]"
  end
end
