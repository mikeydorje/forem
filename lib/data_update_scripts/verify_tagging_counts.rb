# Verification script to check if taggings_count is actually mismatched
# Run with: rails runner lib/data_update_scripts/verify_tagging_counts.rb

puts "=== Verifying taggings_count accuracy ==="

# Get all tags with their counted vs actual taggings
mismatched_tags = Tag.all.select do |tag|
  actual_count = ActsAsTaggableOn::Tagging.where(tag_id: tag.id).count
  tag.taggings_count != actual_count
end

puts "\nTotal tags in database: #{Tag.count}"
puts "Tags with mismatched counts: #{mismatched_tags.length}"

if mismatched_tags.any?
  puts "\n=== Tags with mismatched counts ===" 
  puts "ID\tName\t\t\tStored Count\tActual Count\tDifference"
  puts "-" * 80
  
  mismatched_tags.each do |tag|
    actual = ActsAsTaggableOn::Tagging.where(tag_id: tag.id).count
    diff = actual - tag.taggings_count
    puts "#{tag.id}\t#{tag.name.truncate(20).ljust(20)}\t#{tag.taggings_count}\t\t#{actual}\t\t#{diff > 0 ? '+' : ''}#{diff}"
  end
  
  puts "\n✗ Issue CONFIRMED: #{mismatched_tags.length} tags have incorrect counts"
else
  puts "\n✓ No mismatched counts found - issue appears to be resolved or never occurred"
end
