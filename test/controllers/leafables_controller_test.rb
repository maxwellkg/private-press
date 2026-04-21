require "test_helper"

class LeafablesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :kevin
    @book = books(:handbook)
  end

  test "show" do
    get leafable_slug_path(leaves(:welcome_page))

    assert_response :success
    assert_select "p", "This is such a great handbook."
  end

  test "show with public access to a published book" do
    sign_out
    books(:handbook).update!(published: true)

    get leafable_slug_path(leaves(:welcome_page))

    assert_response :success
    assert_select "p", "This is such a great handbook."
  end

  test "show highlights search terms" do
    Leaf.reindex_all
    get leafable_slug_path(leaves(:welcome_page)), params: { search: "great" }

    assert_response :success
    assert_select "mark", "great"
  end

  test "show does not allow public access to an unpublished book" do
    sign_out

    get leafable_slug_path(leaves(:welcome_page))

    assert_response :not_found
  end

  test "show includes link to markdown format" do
    get leafable_slug_path(leaves(:welcome_page))

    assert_response :success
    assert_select "link[rel=\"alternate\"][type=\"text/markdown\"][href=\"#{leafable_slug_path(leaves(:welcome_page), format: :md)}\"]"
  end

  test "show with markdown format returns raw markdown content" do
    leaves(:welcome_page).leafable.update!(body: "## Hello\n\nThis is **bold** text.")

    get leafable_slug_path(leaves(:welcome_page), format: :md)

    assert_response :success
    assert_in_body "## Hello"
    assert_in_body "This is **bold** text."
    assert_in_body "title: \"Welcome to The Handbook!\""
  end

  test "show with markdown format for section returns body" do
    leaves(:welcome_section).leafable.update!(body: "Section Body Content")

    get leafable_slug_path(leaves(:welcome_section), format: :md)

    assert_response :success
    assert_in_body "Section Body Content"
    assert_in_body "title: \"The Welcome Section\""
  end

  test "show with markdown format for picture returns caption" do
    leaves(:reading_picture).leafable.update!(caption: "A beautiful picture")

    get leafable_slug_path(leaves(:reading_picture), format: :md)

    assert_response :success
    assert_in_body "A beautiful picture"
    assert_in_body "title: \"Reading\""
  end

  test "show with markdown format does not escape HTML entities" do
    leaves(:welcome_page).leafable.update!(body: "This has <a href='http://example.com'>a link</a>")

    get leafable_slug_path(leaves(:welcome_page), format: :md)

    assert_response :success
    assert_in_body "<a href='http://example.com'>"
    assert_not_in_body "&lt;"
  end

  test "create" do
    assert_changes -> { books(:handbook).leaves.count }, +1 do
      post book_pages_path(books(:handbook), format: :turbo_stream), params: {
        leaf: { title: "Another page" }, page: { body: "With interesting words." }
      }
    end

    assert_response :success
  end

  test "create requires editor access" do
    books(:handbook).access_for(user: users(:kevin)).update! level: :reader

    assert_no_changes -> { books(:handbook).leaves.count } do
      post book_pages_path(books(:handbook), format: :turbo_stream), params: {
        leaf: { title: "Another page" }, page: { body: "With interesting words." }
      }
    end

    assert_response :forbidden
  end

  test "json page show returns expected structure" do
    leaf = leaves(:welcome_page)
    get leafable_path(leaf, format: :json), headers: authorization_headers_for_user(:kevin)

    assert_response :ok
    json = JSON.parse(response.body)

    assert_json_leafable json, leaf
    assert_equal leaf.leafable_id, json["id"]
    assert_includes json, "body"
    assert_equal leaf.page.markable, json["body"]
  end

  test "json page create returns 201 and creates resource" do
    assert_changes -> { Page.count }, +1 do
      post book_pages_path(@book, format: :json),
        params: { leaf: { title: "New JSON Page" }, page: { body: "Page content" } },
        headers: authorization_headers_for_user(:kevin)

      assert_response :created
      json = JSON.parse(response.body)
      page = Page.find(json.fetch("id"))

      assert_equal page.id, json["id"]
      assert_equal "Page", json.dig("leaf", "leafable_type")
      assert_equal "New JSON Page", json.dig("leaf", "title")
      assert_equal "Page content", json["body"]
      assert_equal @book.id, json.dig("leaf", "book_id")
    end
  end

  test "json page update returns 200 and updates resource" do
    leaf = leaves(:welcome_page)

    assert_changes -> { leaf.reload.title }, to: "Updated Title" do
      patch leafable_path(leaf, format: :json),
        params: { leaf: { title: "Updated Title" }, page: { body: "Updated body" } },
        headers: authorization_headers_for_user(:kevin)
    end

    assert_response :ok
    json = JSON.parse(response.body)

    assert_equal leaf.page.id, json["id"]
    assert_equal "Updated Title", json.dig("leaf", "title")
    assert_equal "Updated body", json["body"]
  end

  test "json page destroy returns 204" do
    leaf = leaves(:welcome_page)

    assert_changes -> { leaf.reload.status }, from: "active", to: "trashed" do
      delete leafable_path(leaf, format: :json), headers: authorization_headers_for_user(:kevin)
    end

    assert_response :no_content
  end

  test "json section show returns expected structure" do
    leaf = leaves(:welcome_section)
    get leafable_path(leaf, format: :json), headers: authorization_headers_for_user(:kevin)

    assert_response :ok
    json = JSON.parse(response.body)

    assert_json_leafable json, leaf
    assert_equal leaf.leafable_id, json["id"]
    assert_includes json, "body"
    assert_includes json, "theme"
  end

  test "json section create returns 201" do
    assert_changes -> { Section.count }, +1 do
      post book_sections_path(@book, format: :json),
        params: { leaf: { title: "New Section" }, section: { body: "Section body", theme: "dark" } },
        headers: authorization_headers_for_user(:kevin)

      assert_response :created
      json = JSON.parse(response.body)
      section = Section.find(json.fetch("id"))

      assert_equal section.id, json["id"]
      assert_equal "Section", json.dig("leaf", "leafable_type")
      assert_equal "Section body", json["body"]
      assert_equal "dark", json["theme"]
    end
  end

  test "json section update returns 200 and updates resource" do
    leaf = leaves(:welcome_section)

    assert_changes -> { leaf.reload.title }, to: "Updated Section Title" do
      patch leafable_path(leaf, format: :json),
        params: { leaf: { title: "Updated Section Title" }, section: { body: "Updated section body", theme: "dark" } },
        headers: authorization_headers_for_user(:kevin)
    end

    assert_response :ok
    json = JSON.parse(response.body)

    assert_equal leaf.section.id, json["id"]
    assert_equal "Updated Section Title", json.dig("leaf", "title")
    assert_equal "Updated section body", json["body"]
    assert_equal "dark", json["theme"]
  end

  test "json section destroy returns 204" do
    leaf = leaves(:welcome_section)

    assert_changes -> { leaf.reload.status }, from: "active", to: "trashed" do
      delete leafable_path(leaf, format: :json), headers: authorization_headers_for_user(:kevin)
    end

    assert_response :no_content
  end

  test "json picture show returns expected structure" do
    leaf = leaves(:reading_picture)
    get leafable_path(leaf, format: :json), headers: authorization_headers_for_user(:kevin)

    assert_response :ok
    json = JSON.parse(response.body)

    assert_json_leafable json, leaf
    assert_equal leaf.leafable_id, json["id"]
    assert_includes json, "caption"
    assert_includes json, "image_attached"
  end

  test "json picture create returns 201" do
    assert_changes -> { Picture.count }, +1 do
      post book_pictures_path(@book, format: :json),
        params: { leaf: { title: "New Picture" }, picture: { caption: "A caption" } },
        headers: authorization_headers_for_user(:kevin)

      assert_response :created
      json = JSON.parse(response.body)
      picture = Picture.find(json.fetch("id"))

      assert_equal picture.id, json["id"]
      assert_equal "Picture", json.dig("leaf", "leafable_type")
      assert_equal "A caption", json["caption"]
      assert_equal false, json["image_attached"]
    end
  end

  test "json picture update returns 200 and updates resource" do
    leaf = leaves(:reading_picture)

    assert_changes -> { leaf.reload.picture.caption }, to: "Updated caption" do
      patch leafable_path(leaf, format: :json),
        params: { leaf: { title: "Updated Picture Title" }, picture: { caption: "Updated caption" } },
        headers: authorization_headers_for_user(:kevin)
    end

    assert_response :ok
    json = JSON.parse(response.body)

    assert_equal leaf.picture.id, json["id"]
    assert_equal "Updated Picture Title", json.dig("leaf", "title")
    assert_equal "Updated caption", json["caption"]
  end

  test "json picture destroy returns 204" do
    leaf = leaves(:reading_picture)

    assert_changes -> { leaf.reload.status }, from: "active", to: "trashed" do
      delete leafable_path(leaf, format: :json), headers: authorization_headers_for_user(:kevin)
    end

    assert_response :no_content
  end

  test "json unauthenticated request returns 401" do
    post book_pages_path(@book, format: :json), params: {
      leaf: { title: "Unauthenticated" },
      page: { body: "No token" }
    }

    assert_response :unauthorized
    json = JSON.parse(response.body)

    assert_equal "unauthenticated", json.dig("error", "code")
  end

  test "json non-editor mutation returns 403" do
    post book_pages_path(@book, format: :json),
      params: { leaf: { title: "Forbidden" }, page: { body: "No edit access" } },
      headers: authorization_headers_for_user(:jz)

    assert_response :forbidden
  end

  test "json missing leaf returns 404" do
    get book_page_path(@book, 999_999, format: :json), headers: authorization_headers_for_user(:kevin)

    assert_response :not_found
  end

  private
    def assert_json_leafable(json, leaf)
      assert_includes json, "id"

      assert_includes json, "leaf"
      leaf_json = json["leaf"]
      assert_equal leaf.id, leaf_json["id"]
      assert_equal leaf.leafable_id, leaf_json["leafable_id"]
      assert_equal leaf.leafable_type, leaf_json["leafable_type"]
      assert_equal leaf.title, leaf_json["title"]
      assert_equal leaf.status, leaf_json["status"]
      assert_equal leaf.position_score, leaf_json["position_score"]
      assert_equal leaf.book_id, leaf_json["book_id"]
    end
end
