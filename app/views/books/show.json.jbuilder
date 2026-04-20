json.partial! "books/book", book: @book

json.toc do
  json.array! @leaves do |leaf|
    json.id leaf.id
    json.leafable_type leaf.leafable_type

    json.leafable do
      json.id leaf.leafable_id
      json.title leaf.title
      json.status leaf.status
      json.position_score leaf.position_score      
    end
  end
end
