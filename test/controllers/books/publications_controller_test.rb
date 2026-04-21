require "test_helper"

class Books::PublicationsTest < ActionDispatch::IntegrationTest
  setup do
    @book = books(:manual)
  end

  test "publish a book" do
    sign_in :david

    assert_changes -> { @book.reload.published? }, from: false, to: true do
      patch book_publication_url(@book), params: { book: { published: "1" } }
    end

    @book.reload
    assert_redirected_to book_slug_url(@book)
    assert_equal "manual", @book.slug
  end

  test "edit book slug" do
    sign_in :david

    @book.update! published: true

    get edit_book_publication_url(@book)
    assert_response :success

    patch book_publication_url(@book), params: { book: { slug: "new-slug" } }

    @book.reload
    assert_redirected_to book_slug_url(@book)
    assert_equal "new-slug", @book.slug
  end

  test "publication JSON returns 200 with book_id, published, and slug" do
    get book_publication_path(@book), as: :json, headers: authorization_headers_for_user(:david)

    assert_response :success

    json = JSON.parse(response.body)

    assert_equal @book.id, json["book_id"]
    refute json["published"]
    assert_equal "manual", json["slug"]
  end

  test "publication JSON allows editor to update and returns 200" do
    assert_changes -> { @book.reload.published }, from: false, to: true do
      assert_changes -> { @book.reload.slug }, from: "manual", to: "new-slug" do
        patch book_publication_path(@book),
              as: :json,
              headers: authorization_headers_for_user(:david),
              params: { book: { published: true, slug: "new-slug" } }
      end
    end

    assert_response :success

    json = JSON.parse(response.body)
    
    assert json["published"]
    assert_equal "new-slug", json["slug"]
  end

  test "publication JSON returns 403 for non-editor" do
    assert_no_changes -> { @book.reload.published } do
      patch book_publication_path(@book), as: :json, headers: authorization_headers_for_user(:jz), params: {
        book: { published: true }
      }
    end

    assert_response :forbidden
  end

  test "publication JSON returns 404 for inaccessible book" do
    get book_publication_path(books(:manual)), as: :json, headers: authorization_headers_for_user(:kevin)

    assert_response :not_found
  end
end
