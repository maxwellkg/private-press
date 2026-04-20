json.array! @books do |book|
  json.partial! "books/book", book: book
end
