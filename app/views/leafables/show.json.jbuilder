json.id @leaf.leafable_id

json.leaf do
  json.partial! "leaves/leaf", leaf: @leaf
end

if @leaf.page?
  json.partial! "pages/page", page: @leaf.page
elsif @leaf.section?
  json.partial! "sections/section", section: @leaf.section
elsif @leaf.picture?
  json.partial! "pictures/picture", picture: @leaf.picture
end
