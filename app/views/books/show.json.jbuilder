json.partial! "books/book", book: @book

json.toc do
  json.array! @leaves do |leaf|
    json.partial! "leaves/leaf", leaf: leaf

    json.leafable do
      json.partial! toc_leafable_partial_path(leaf), **toc_leafable_partial_locals(leaf)
    end
  end
end
